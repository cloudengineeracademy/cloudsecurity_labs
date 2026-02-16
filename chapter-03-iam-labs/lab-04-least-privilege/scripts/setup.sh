#!/bin/bash

# Lab 04: Least Privilege — Setup
# Creates two roles (bounded and unbounded) and a test bucket

echo ""
echo "=============================================="
echo "  Lab 04: Least Privilege — Setup"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    exit 1
fi

REGION=$(aws configure get region 2>/dev/null)
if [ -z "$REGION" ]; then
    REGION="us-east-1"
fi

BUCKET_NAME="iam-lab-lp-${ACCOUNT_ID}"

echo "  Account: $ACCOUNT_ID"
echo "  Region:  $REGION"
echo ""

# Check for existing resources
aws iam get-role --role-name iam-lab-unbounded-role >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${YELLOW}WARNING: Lab resources already exist.${NC}"
    echo "  Run cleanup first: bash lab-04-least-privilege/scripts/cleanup.sh"
    exit 1
fi

TRUST_POLICY='{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Principal": {"AWS": "arn:aws:iam::'"$ACCOUNT_ID"':root"},
        "Action": "sts:AssumeRole"
    }]
}'

# ============================================================
# Step 1: Create permissions boundary policy
# ============================================================
echo -e "${BLUE}Step 1: Creating permissions boundary policy...${NC}"

BOUNDARY_ARN=$(aws iam create-policy \
    --policy-name iam-lab-boundary \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": [
                "s3:*",
                "cloudwatch:*",
                "logs:*"
            ],
            "Resource": "*"
        }]
    }' \
    --query 'Policy.Arn' --output text 2>&1)

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Failed to create boundary policy.${NC}"
    echo "  $BOUNDARY_ARN"
    exit 1
fi

echo -e "  ${GREEN}Created: iam-lab-boundary (allows S3 + CloudWatch only)${NC}"
echo ""

# ============================================================
# Step 2: Create unbounded role (AdministratorAccess, no boundary)
# ============================================================
echo -e "${BLUE}Step 2: Creating unbounded role (no boundary)...${NC}"

aws iam create-role --role-name iam-lab-unbounded-role \
    --assume-role-policy-document "$TRUST_POLICY" >/dev/null 2>&1

aws iam attach-role-policy --role-name iam-lab-unbounded-role \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

echo -e "  ${GREEN}Created: iam-lab-unbounded-role (AdministratorAccess, NO boundary)${NC}"
echo ""

# ============================================================
# Step 3: Create bounded role (AdministratorAccess + boundary)
# ============================================================
echo -e "${BLUE}Step 3: Creating bounded role (with boundary)...${NC}"

aws iam create-role --role-name iam-lab-bounded-role \
    --assume-role-policy-document "$TRUST_POLICY" \
    --permissions-boundary "$BOUNDARY_ARN" >/dev/null 2>&1

aws iam attach-role-policy --role-name iam-lab-bounded-role \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

echo -e "  ${GREEN}Created: iam-lab-bounded-role (AdministratorAccess + S3/CW boundary)${NC}"
echo ""

# ============================================================
# Step 4: Create test bucket
# ============================================================
echo -e "${BLUE}Step 4: Creating test bucket...${NC}"

if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$BUCKET_NAME" 2>/dev/null
else
    aws s3api create-bucket --bucket "$BUCKET_NAME" \
        --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null
fi

echo "test-data-for-scope-down" | aws s3 cp - "s3://${BUCKET_NAME}/data/file1.txt" 2>/dev/null
echo "more-test-data" | aws s3 cp - "s3://${BUCKET_NAME}/data/file2.txt" 2>/dev/null

echo -e "  ${GREEN}Created: $BUCKET_NAME (2 test files)${NC}"
echo ""

# ============================================================
# Save config
# ============================================================
cat > /tmp/iam-lab-04-config <<EOF
ACCOUNT_ID=$ACCOUNT_ID
REGION=$REGION
BUCKET_NAME=$BUCKET_NAME
BOUNDARY_ARN=$BOUNDARY_ARN
EOF
chmod 600 /tmp/iam-lab-04-config

echo "=============================================="
echo "  Setup Complete"
echo "=============================================="
echo ""
echo "  Two roles created (both have AdministratorAccess):"
echo ""
echo -e "  ${RED}iam-lab-unbounded-role${NC}"
echo "    Permission policy: AdministratorAccess"
echo "    Boundary: NONE"
echo "    Effective: Can do ANYTHING"
echo ""
echo -e "  ${GREEN}iam-lab-bounded-role${NC}"
echo "    Permission policy: AdministratorAccess"
echo "    Boundary: S3 + CloudWatch only"
echo "    Effective: Can only use S3 and CloudWatch"
echo ""
echo "  Next step:"
echo "    bash lab-04-least-privilege/scripts/boundary-demo.sh"
echo ""
