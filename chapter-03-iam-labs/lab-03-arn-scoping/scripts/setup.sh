#!/bin/bash

# Lab 03: ARN Scoping — Setup
# Creates test user and S3 bucket with test files

echo ""
echo "=============================================="
echo "  Lab 03: ARN Scoping — Setup"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

KEYS_FILE="/tmp/iam-lab-03-keys"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    exit 1
fi

REGION=$(aws configure get region 2>/dev/null)
if [ -z "$REGION" ]; then
    REGION="us-east-1"
fi

BUCKET_NAME="iam-lab-arn-${ACCOUNT_ID}"

echo "  Account: $ACCOUNT_ID"
echo "  Region:  $REGION"
echo "  Bucket:  $BUCKET_NAME"
echo ""

# Check for existing resources
aws iam get-user --user-name iam-lab-policy-user >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${YELLOW}WARNING: Lab resources already exist.${NC}"
    echo "  Run cleanup first: bash lab-03-arn-scoping/scripts/cleanup.sh"
    exit 1
fi

# ============================================================
# Step 1: Create test S3 bucket
# ============================================================
echo -e "${BLUE}Step 1: Creating test bucket with sample files...${NC}"

if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" 2>/dev/null
else
    aws s3api create-bucket --bucket "$BUCKET_NAME" \
        --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null
fi

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Failed to create bucket.${NC}"
    exit 1
fi

# Upload test files to two prefixes
echo "This is a public readme file." | aws s3 cp - "s3://${BUCKET_NAME}/public/readme.txt" 2>/dev/null
echo "Public document #2." | aws s3 cp - "s3://${BUCKET_NAME}/public/docs.txt" 2>/dev/null
echo "CONFIDENTIAL: Internal salary data." | aws s3 cp - "s3://${BUCKET_NAME}/confidential/secret.txt" 2>/dev/null
echo "CONFIDENTIAL: Customer PII." | aws s3 cp - "s3://${BUCKET_NAME}/confidential/pii.txt" 2>/dev/null

echo -e "  ${GREEN}Created bucket with 4 files in public/ and confidential/ prefixes${NC}"
echo ""

# ============================================================
# Step 2: Create test user with NO permissions
# ============================================================
echo -e "${BLUE}Step 2: Creating test user (no permissions)...${NC}"

aws iam create-user --user-name iam-lab-policy-user >/dev/null 2>&1

POLICY_KEYS=$(aws iam create-access-key --user-name iam-lab-policy-user \
    --query 'AccessKey.{Key:AccessKeyId,Secret:SecretAccessKey}' --output text)

POLICY_KEY=$(echo "$POLICY_KEYS" | awk '{print $1}')
POLICY_SECRET=$(echo "$POLICY_KEYS" | awk '{print $2}')

echo -e "  ${GREEN}Created: iam-lab-policy-user (no policies attached)${NC}"
echo ""

# ============================================================
# Step 3: Save keys
# ============================================================
cat > "$KEYS_FILE" <<EOF
POLICY_KEY=$POLICY_KEY
POLICY_SECRET=$POLICY_SECRET
BUCKET_NAME=$BUCKET_NAME
ACCOUNT_ID=$ACCOUNT_ID
REGION=$REGION
EOF
chmod 600 "$KEYS_FILE"

echo "  Waiting 10 seconds for IAM propagation..."
sleep 10
echo ""

# ============================================================
# Summary
# ============================================================
echo "=============================================="
echo "  Setup Complete"
echo "=============================================="
echo ""
echo "  Test user: iam-lab-policy-user (no permissions)"
echo "  Test bucket: $BUCKET_NAME"
echo "    - public/readme.txt"
echo "    - public/docs.txt"
echo "    - confidential/secret.txt"
echo "    - confidential/pii.txt"
echo ""
echo "  Keys saved to: $KEYS_FILE"
echo ""
echo "  Follow the README to complete the 5 challenges."
echo ""
