#!/bin/bash

# Lab 01: Blast Radius — Setup
# Creates two IAM users (overprivileged + scoped) with access keys

echo ""
echo "=============================================="
echo "  Lab 01: Blast Radius — Setup"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

KEYS_FILE="/tmp/iam-lab-01-keys"

# ============================================================
# Pre-flight checks
# ============================================================
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    exit 1
fi

REGION=$(aws configure get region 2>/dev/null)
if [ -z "$REGION" ]; then
    REGION="us-east-1"
fi

echo "  Account:  $ACCOUNT_ID"
echo "  Region:   $REGION"
echo ""

BUCKET_NAME="iam-lab-test-${ACCOUNT_ID}"

# ============================================================
# Check for existing resources (idempotency)
# ============================================================
EXISTING_USER=$(aws iam get-user --user-name iam-lab-admin-user 2>/dev/null)
if [ $? -eq 0 ]; then
    echo -e "${YELLOW}WARNING: Lab resources already exist.${NC}"
    echo "  Run cleanup first: bash lab-01-blast-radius/scripts/cleanup.sh"
    echo ""
    exit 1
fi

# ============================================================
# Step 1: Create the test S3 bucket
# ============================================================
echo -e "${BLUE}Step 1: Creating test S3 bucket...${NC}"

if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" 2>/dev/null
else
    aws s3api create-bucket --bucket "$BUCKET_NAME" \
        --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null
fi

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Failed to create bucket $BUCKET_NAME${NC}"
    echo "  The bucket name may already be taken. Try running cleanup first."
    exit 1
fi

# Upload test files
echo "sample-data-file-1" | aws s3 cp - "s3://${BUCKET_NAME}/data/file1.txt" 2>/dev/null
echo "sample-data-file-2" | aws s3 cp - "s3://${BUCKET_NAME}/data/file2.txt" 2>/dev/null
echo "confidential-report" | aws s3 cp - "s3://${BUCKET_NAME}/reports/report.txt" 2>/dev/null

echo -e "  ${GREEN}Created bucket: $BUCKET_NAME (3 test files)${NC}"
echo ""

# ============================================================
# Step 2: Create overprivileged user
# ============================================================
echo -e "${BLUE}Step 2: Creating overprivileged user...${NC}"

aws iam create-user --user-name iam-lab-admin-user >/dev/null 2>&1

aws iam attach-user-policy --user-name iam-lab-admin-user \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

ADMIN_KEYS=$(aws iam create-access-key --user-name iam-lab-admin-user \
    --query 'AccessKey.{Key:AccessKeyId,Secret:SecretAccessKey}' --output text)

ADMIN_KEY=$(echo "$ADMIN_KEYS" | awk '{print $1}')
ADMIN_SECRET=$(echo "$ADMIN_KEYS" | awk '{print $2}')

echo -e "  ${GREEN}Created: iam-lab-admin-user (AdministratorAccess)${NC}"
echo ""

# ============================================================
# Step 3: Create scoped user
# ============================================================
echo -e "${BLUE}Step 3: Creating scoped user...${NC}"

aws iam create-user --user-name iam-lab-scoped-user >/dev/null 2>&1

# Inline policy: read-only on the test bucket only
aws iam put-user-policy --user-name iam-lab-scoped-user \
    --policy-name iam-lab-scoped-policy \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "AllowListTestBucket",
                "Effect": "Allow",
                "Action": "s3:ListBucket",
                "Resource": "arn:aws:s3:::'"$BUCKET_NAME"'"
            },
            {
                "Sid": "AllowReadTestBucketObjects",
                "Effect": "Allow",
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::'"$BUCKET_NAME"'/*"
            }
        ]
    }'

SCOPED_KEYS=$(aws iam create-access-key --user-name iam-lab-scoped-user \
    --query 'AccessKey.{Key:AccessKeyId,Secret:SecretAccessKey}' --output text)

SCOPED_KEY=$(echo "$SCOPED_KEYS" | awk '{print $1}')
SCOPED_SECRET=$(echo "$SCOPED_KEYS" | awk '{print $2}')

echo -e "  ${GREEN}Created: iam-lab-scoped-user (S3 read on $BUCKET_NAME only)${NC}"
echo ""

# ============================================================
# Step 4: Save keys to temp file
# ============================================================
cat > "$KEYS_FILE" <<EOF
ADMIN_KEY=$ADMIN_KEY
ADMIN_SECRET=$ADMIN_SECRET
SCOPED_KEY=$SCOPED_KEY
SCOPED_SECRET=$SCOPED_SECRET
BUCKET_NAME=$BUCKET_NAME
ACCOUNT_ID=$ACCOUNT_ID
REGION=$REGION
EOF
chmod 600 "$KEYS_FILE"

echo -e "${BLUE}Step 4: Saved access keys to $KEYS_FILE${NC}"
echo ""

# ============================================================
# Wait for IAM propagation
# ============================================================
echo "  Waiting 10 seconds for IAM policy propagation..."
sleep 10
echo ""

# ============================================================
# Summary
# ============================================================
echo "=============================================="
echo "  Setup Complete"
echo "=============================================="
echo ""
echo "  Two users created:"
echo ""
echo -e "  ${RED}iam-lab-admin-user${NC}"
echo "    Policy: AdministratorAccess"
echo "    Access: EVERYTHING in your account"
echo ""
echo -e "  ${GREEN}iam-lab-scoped-user${NC}"
echo "    Policy: S3 read-only on $BUCKET_NAME"
echo "    Access: One bucket, read-only"
echo ""
echo "  Next step:"
echo "    bash lab-01-blast-radius/scripts/blast-radius-test.sh"
echo ""
