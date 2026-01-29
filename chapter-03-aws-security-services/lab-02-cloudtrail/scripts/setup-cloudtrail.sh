#!/bin/bash

# Lab 02: Setup CloudTrail
# Creates KMS key + S3 bucket + multi-region trail

echo ""
echo "=============================================="
echo "  CloudTrail Setup"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get account info
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    exit 1
fi

echo "Account: $ACCOUNT_ID"
echo "Region:  $REGION"
echo ""

TRAIL_NAME="ch03-security-trail"
BUCKET_NAME="ch03-cloudtrail-${ACCOUNT_ID}"
KEY_ALIAS="alias/ch03-cloudtrail-key"

# ============================================================
# Step 1: Create KMS Key
# ============================================================
echo -e "${BLUE}Step 1: Creating KMS customer-managed key...${NC}"

# Check if key already exists
EXISTING_KEY=$(aws kms describe-key --key-id "$KEY_ALIAS" --query 'KeyMetadata.KeyId' --output text 2>/dev/null)
if [ -n "$EXISTING_KEY" ] && [ "$EXISTING_KEY" != "None" ]; then
    echo -e "${YELLOW}KMS key already exists: $EXISTING_KEY${NC}"
    KMS_KEY_ID="$EXISTING_KEY"
else
    # Create the key with a policy that allows CloudTrail to use it
    KMS_KEY_ID=$(aws kms create-key \
        --description "CloudTrail encryption key for Chapter 03" \
        --policy "{
            \"Version\": \"2012-10-17\",
            \"Statement\": [
                {
                    \"Sid\": \"EnableRootAccountFullAccess\",
                    \"Effect\": \"Allow\",
                    \"Principal\": {
                        \"AWS\": \"arn:aws:iam::${ACCOUNT_ID}:root\"
                    },
                    \"Action\": \"kms:*\",
                    \"Resource\": \"*\"
                },
                {
                    \"Sid\": \"AllowCloudTrailEncrypt\",
                    \"Effect\": \"Allow\",
                    \"Principal\": {
                        \"Service\": \"cloudtrail.amazonaws.com\"
                    },
                    \"Action\": \"kms:GenerateDataKey*\",
                    \"Resource\": \"*\",
                    \"Condition\": {
                        \"StringEquals\": {
                            \"AWS:SourceArn\": \"arn:aws:cloudtrail:${REGION}:${ACCOUNT_ID}:trail/${TRAIL_NAME}\"
                        },
                        \"StringLike\": {
                            \"kms:EncryptionContext:aws:cloudtrail:arn\": \"arn:aws:cloudtrail:*:${ACCOUNT_ID}:trail/*\"
                        }
                    }
                },
                {
                    \"Sid\": \"AllowCloudTrailDescribeKey\",
                    \"Effect\": \"Allow\",
                    \"Principal\": {
                        \"Service\": \"cloudtrail.amazonaws.com\"
                    },
                    \"Action\": \"kms:DescribeKey\",
                    \"Resource\": \"*\"
                }
            ]
        }" \
        --query 'KeyMetadata.KeyId' --output text 2>/dev/null)

    if [ -z "$KMS_KEY_ID" ] || [ "$KMS_KEY_ID" = "None" ]; then
        echo -e "${RED}ERROR: Failed to create KMS key${NC}"
        exit 1
    fi

    # Create alias
    aws kms create-alias --alias-name "$KEY_ALIAS" --target-key-id "$KMS_KEY_ID" 2>/dev/null
    echo -e "${GREEN}KMS key created: $KMS_KEY_ID${NC}"
fi

KMS_KEY_ARN=$(aws kms describe-key --key-id "$KMS_KEY_ID" --query 'KeyMetadata.Arn' --output text 2>/dev/null)
echo ""

# ============================================================
# Step 2: Create S3 Bucket
# ============================================================
echo -e "${BLUE}Step 2: Creating S3 bucket for CloudTrail logs...${NC}"

# Check if bucket exists
aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${YELLOW}Bucket already exists: $BUCKET_NAME${NC}"
else
    # Create bucket (us-east-1 doesn't need LocationConstraint)
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket --bucket "$BUCKET_NAME" 2>/dev/null
    else
        aws s3api create-bucket --bucket "$BUCKET_NAME" \
            --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null
    fi

    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Failed to create S3 bucket${NC}"
        exit 1
    fi
    echo -e "${GREEN}Bucket created: $BUCKET_NAME${NC}"
fi

# Enable bucket encryption
echo "  Enabling default encryption with KMS..."
aws s3api put-bucket-encryption --bucket "$BUCKET_NAME" \
    --server-side-encryption-configuration "{
        \"Rules\": [{
            \"ApplyServerSideEncryptionByDefault\": {
                \"SSEAlgorithm\": \"aws:kms\",
                \"KMSMasterKeyID\": \"${KMS_KEY_ARN}\"
            },
            \"BucketKeyEnabled\": true
        }]
    }" 2>/dev/null

# Block public access on the bucket
echo "  Blocking public access..."
aws s3api put-public-access-block --bucket "$BUCKET_NAME" \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" 2>/dev/null

# Apply bucket policy
echo "  Applying bucket policy for CloudTrail delivery..."
BUCKET_POLICY=$(cat <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {"Service": "cloudtrail.amazonaws.com"},
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::${BUCKET_NAME}",
            "Condition": {
                "StringEquals": {
                    "AWS:SourceArn": "arn:aws:cloudtrail:${REGION}:${ACCOUNT_ID}:trail/${TRAIL_NAME}"
                }
            }
        },
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {"Service": "cloudtrail.amazonaws.com"},
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${BUCKET_NAME}/AWSLogs/${ACCOUNT_ID}/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control",
                    "AWS:SourceArn": "arn:aws:cloudtrail:${REGION}:${ACCOUNT_ID}:trail/${TRAIL_NAME}"
                }
            }
        },
        {
            "Sid": "DenyInsecureTransport",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::${BUCKET_NAME}",
                "arn:aws:s3:::${BUCKET_NAME}/*"
            ],
            "Condition": {
                "Bool": {"aws:SecureTransport": "false"}
            }
        }
    ]
}
EOF
)

aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy "$BUCKET_POLICY" 2>/dev/null
echo -e "${GREEN}Bucket configured${NC}"
echo ""

# ============================================================
# Step 3: Create CloudTrail
# ============================================================
echo -e "${BLUE}Step 3: Creating multi-region CloudTrail...${NC}"

# Check if trail already exists
EXISTING_TRAIL=$(aws cloudtrail describe-trails --trail-name-list "$TRAIL_NAME" --query 'trailList[0].Name' --output text 2>/dev/null)
if [ "$EXISTING_TRAIL" = "$TRAIL_NAME" ]; then
    echo -e "${YELLOW}Trail already exists: $TRAIL_NAME${NC}"
    echo "  Updating configuration..."
    aws cloudtrail update-trail \
        --name "$TRAIL_NAME" \
        --s3-bucket-name "$BUCKET_NAME" \
        --is-multi-region-trail \
        --enable-log-file-validation \
        --kms-key-id "$KMS_KEY_ARN" 2>/dev/null
else
    aws cloudtrail create-trail \
        --name "$TRAIL_NAME" \
        --s3-bucket-name "$BUCKET_NAME" \
        --is-multi-region-trail \
        --enable-log-file-validation \
        --kms-key-id "$KMS_KEY_ARN" 2>/dev/null

    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Failed to create CloudTrail${NC}"
        echo "  Check that the bucket policy and KMS key policy are correct."
        exit 1
    fi
fi

# Start logging
echo "  Starting logging..."
aws cloudtrail start-logging --name "$TRAIL_NAME" 2>/dev/null
echo -e "${GREEN}CloudTrail created and logging started${NC}"
echo ""

# ============================================================
# Summary
# ============================================================
echo "=============================================="
echo "  SETUP COMPLETE"
echo "=============================================="
echo ""
echo "  Resources created:"
echo "    KMS Key:     $KMS_KEY_ID"
echo "    S3 Bucket:   $BUCKET_NAME"
echo "    Trail:       $TRAIL_NAME"
echo ""
echo "  Configuration:"
echo "    Multi-region:     Yes"
echo "    KMS encrypted:    Yes"
echo "    Log validation:   Yes"
echo "    Bucket encrypted: Yes (KMS)"
echo "    Public access:    Blocked"
echo ""
echo "  Next steps:"
echo "    1. Verify: bash lab-02-cloudtrail/scripts/verify.sh"
echo "    2. Detective exercise: bash lab-02-cloudtrail/scripts/detective-exercise.sh"
echo "    3. Check score: bash scripts/mission-status.sh"
echo ""
