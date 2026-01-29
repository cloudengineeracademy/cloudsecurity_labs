#!/bin/bash

# Lab 04: Enable AWS Config + Config Rules + Access Analyzer

echo ""
echo "=============================================="
echo "  Enable Compliance Services"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    exit 1
fi

echo "Account: $ACCOUNT_ID"
echo "Region:  $REGION"
echo ""

CONFIG_BUCKET="ch03-config-${ACCOUNT_ID}"
CONFIG_ROLE_NAME="ch03-config-role"

# ============================================================
# Step 1: Create S3 bucket for Config
# ============================================================
echo -e "${BLUE}Step 1: Creating S3 bucket for Config delivery...${NC}"

aws s3api head-bucket --bucket "$CONFIG_BUCKET" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${YELLOW}Bucket already exists: $CONFIG_BUCKET${NC}"
else
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$CONFIG_BUCKET" 2>/dev/null
    else
        aws s3api create-bucket --bucket "$CONFIG_BUCKET" \
            --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null
    fi

    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Failed to create S3 bucket${NC}"
        exit 1
    fi
    echo -e "${GREEN}Bucket created: $CONFIG_BUCKET${NC}"
fi

# Enable encryption
aws s3api put-bucket-encryption --bucket "$CONFIG_BUCKET" \
    --server-side-encryption-configuration '{
        "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
    }' 2>/dev/null

# Block public access
aws s3api put-public-access-block --bucket "$CONFIG_BUCKET" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" 2>/dev/null

# Bucket policy for Config delivery
CONFIG_BUCKET_POLICY=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSConfigBucketPermissionsCheck",
            "Effect": "Allow",
            "Principal": {"Service": "config.amazonaws.com"},
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::${CONFIG_BUCKET}",
            "Condition": {"StringEquals": {"AWS:SourceAccount": "${ACCOUNT_ID}"}}
        },
        {
            "Sid": "AWSConfigBucketExistenceCheck",
            "Effect": "Allow",
            "Principal": {"Service": "config.amazonaws.com"},
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::${CONFIG_BUCKET}",
            "Condition": {"StringEquals": {"AWS:SourceAccount": "${ACCOUNT_ID}"}}
        },
        {
            "Sid": "AWSConfigBucketDelivery",
            "Effect": "Allow",
            "Principal": {"Service": "config.amazonaws.com"},
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${CONFIG_BUCKET}/AWSLogs/${ACCOUNT_ID}/Config/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control",
                    "AWS:SourceAccount": "${ACCOUNT_ID}"
                }
            }
        }
    ]
}
EOF
)

aws s3api put-bucket-policy --bucket "$CONFIG_BUCKET" --policy "$CONFIG_BUCKET_POLICY" 2>/dev/null
echo ""

# ============================================================
# Step 2: Create IAM Role for Config
# ============================================================
echo -e "${BLUE}Step 2: Creating IAM role for Config...${NC}"

EXISTING_ROLE=$(aws iam get-role --role-name "$CONFIG_ROLE_NAME" --query 'Role.Arn' --output text 2>/dev/null)
if [ -n "$EXISTING_ROLE" ] && [ "$EXISTING_ROLE" != "None" ]; then
    echo -e "${YELLOW}Role already exists: $CONFIG_ROLE_NAME${NC}"
    CONFIG_ROLE_ARN="$EXISTING_ROLE"
else
    TRUST_POLICY=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowConfigAssume",
            "Effect": "Allow",
            "Principal": {"Service": "config.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
    )

    CONFIG_ROLE_ARN=$(aws iam create-role \
        --role-name "$CONFIG_ROLE_NAME" \
        --assume-role-policy-document "$TRUST_POLICY" \
        --query 'Role.Arn' --output text 2>/dev/null)

    if [ -z "$CONFIG_ROLE_ARN" ] || [ "$CONFIG_ROLE_ARN" = "None" ]; then
        echo -e "${RED}ERROR: Failed to create IAM role${NC}"
        exit 1
    fi

    # Attach AWS managed policy for Config
    aws iam attach-role-policy --role-name "$CONFIG_ROLE_NAME" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole" 2>/dev/null

    # Add S3 delivery permission
    S3_POLICY=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["s3:PutObject", "s3:GetBucketAcl"],
            "Resource": [
                "arn:aws:s3:::${CONFIG_BUCKET}",
                "arn:aws:s3:::${CONFIG_BUCKET}/*"
            ]
        }
    ]
}
EOF
    )

    aws iam put-role-policy --role-name "$CONFIG_ROLE_NAME" \
        --policy-name "ch03-config-s3-delivery" \
        --policy-document "$S3_POLICY" 2>/dev/null

    echo -e "${GREEN}Role created: $CONFIG_ROLE_NAME${NC}"

    # Wait for role propagation
    echo "  Waiting for IAM role propagation..."
    sleep 10
fi
echo ""

# ============================================================
# Step 3: Enable Config Recorder
# ============================================================
echo -e "${BLUE}Step 3: Enabling AWS Config recorder...${NC}"

# Check if recorder exists
EXISTING_RECORDER=$(aws configservice describe-configuration-recorders --query 'ConfigurationRecorders[0].name' --output text 2>/dev/null)
if [ -n "$EXISTING_RECORDER" ] && [ "$EXISTING_RECORDER" != "None" ]; then
    echo -e "${YELLOW}Config recorder already exists: $EXISTING_RECORDER${NC}"
else
    aws configservice put-configuration-recorder \
        --configuration-recorder "name=default,roleARN=${CONFIG_ROLE_ARN}" \
        --recording-group '{"allSupported":true,"includeGlobalResourceTypes":true}' 2>/dev/null

    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Failed to create Config recorder${NC}"
        exit 1
    fi
    echo -e "${GREEN}Config recorder created${NC}"
fi

# Set up delivery channel
EXISTING_CHANNEL=$(aws configservice describe-delivery-channels --query 'DeliveryChannels[0].name' --output text 2>/dev/null)
if [ -z "$EXISTING_CHANNEL" ] || [ "$EXISTING_CHANNEL" = "None" ]; then
    aws configservice put-delivery-channel \
        --delivery-channel "name=default,s3BucketName=${CONFIG_BUCKET}" 2>/dev/null
    echo -e "${GREEN}Delivery channel configured${NC}"
else
    echo -e "${YELLOW}Delivery channel already exists${NC}"
fi

# Start recorder
aws configservice start-configuration-recorder --configuration-recorder-name default 2>/dev/null
echo -e "${GREEN}Config recorder started${NC}"
echo ""

# ============================================================
# Step 4: Add Config Rules
# ============================================================
echo -e "${BLUE}Step 4: Adding Config rules...${NC}"

# Rule 1: restricted-ssh
echo -n "  Adding restricted-ssh rule... "
aws configservice put-config-rule --config-rule '{
    "ConfigRuleName": "ch03-restricted-ssh",
    "Description": "Checks whether security groups allow unrestricted SSH traffic",
    "Source": {
        "Owner": "AWS",
        "SourceIdentifier": "INCOMING_SSH_DISABLED"
    },
    "Scope": {
        "ComplianceResourceTypes": ["AWS::EC2::SecurityGroup"]
    }
}' 2>/dev/null
echo -e "${GREEN}done${NC}"

# Rule 2: cloud-trail-encryption-enabled
echo -n "  Adding cloud-trail-encryption rule... "
aws configservice put-config-rule --config-rule '{
    "ConfigRuleName": "ch03-cloudtrail-encryption",
    "Description": "Checks whether CloudTrail uses KMS encryption",
    "Source": {
        "Owner": "AWS",
        "SourceIdentifier": "CLOUD_TRAIL_ENCRYPTION_ENABLED"
    }
}' 2>/dev/null
echo -e "${GREEN}done${NC}"

# Rule 3: s3-bucket-server-side-encryption-enabled
echo -n "  Adding s3-encryption rule... "
aws configservice put-config-rule --config-rule '{
    "ConfigRuleName": "ch03-s3-encryption",
    "Description": "Checks whether S3 buckets have default encryption enabled",
    "Source": {
        "Owner": "AWS",
        "SourceIdentifier": "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
    },
    "Scope": {
        "ComplianceResourceTypes": ["AWS::S3::Bucket"]
    }
}' 2>/dev/null
echo -e "${GREEN}done${NC}"
echo ""

# ============================================================
# Step 5: Enable IAM Access Analyzer
# ============================================================
echo -e "${BLUE}Step 5: Enabling IAM Access Analyzer...${NC}"

EXISTING_ANALYZER=$(aws accessanalyzer list-analyzers --query 'analyzers[0].name' --output text 2>/dev/null)
if [ -n "$EXISTING_ANALYZER" ] && [ "$EXISTING_ANALYZER" != "None" ]; then
    echo -e "${YELLOW}Access Analyzer already exists: $EXISTING_ANALYZER${NC}"
else
    aws accessanalyzer create-analyzer \
        --analyzer-name "ch03-access-analyzer" \
        --type ACCOUNT 2>/dev/null

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Access Analyzer created: ch03-access-analyzer${NC}"
    else
        echo -e "${RED}Failed to create Access Analyzer${NC}"
    fi
fi
echo ""

# ============================================================
# Summary
# ============================================================
echo "=============================================="
echo "  COMPLIANCE SERVICES ENABLED"
echo "=============================================="
echo ""
echo "  AWS Config:"
echo "    - Recorder: running"
echo "    - Delivery: $CONFIG_BUCKET"
echo "    - Rules: 3 (restricted-ssh, cloudtrail-encryption, s3-encryption)"
echo ""
echo "  IAM Access Analyzer:"
echo "    - Type: ACCOUNT"
echo "    - Monitors: S3, IAM, KMS, Lambda, SQS"
echo ""
echo "  Next steps:"
echo "    1. Exercise: bash lab-04-config-access-analyzer/scripts/compliance-exercise.sh"
echo "    2. Fix: bash lab-04-config-access-analyzer/scripts/fix-and-verify.sh"
echo "    3. Verify: bash lab-04-config-access-analyzer/scripts/verify.sh"
echo ""
