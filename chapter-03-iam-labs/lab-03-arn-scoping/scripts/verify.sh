#!/bin/bash

# Lab 03: ARN Scoping — Verify
# Tests that the student's environment is set up correctly and key concepts work

echo ""
echo "=============================================="
echo "  Lab 03: ARN Scoping — Verification"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
TOTAL=5

KEYS_FILE="/tmp/iam-lab-03-keys"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
REGION=$(aws configure get region 2>/dev/null)
if [ -z "$REGION" ]; then
    REGION="us-east-1"
fi
BUCKET_NAME="iam-lab-arn-${ACCOUNT_ID}"

if [ ! -f "$KEYS_FILE" ]; then
    echo -e "${RED}ERROR: Keys file not found. Run setup first.${NC}"
    echo "  bash lab-03-arn-scoping/scripts/setup.sh"
    exit 1
fi

source "$KEYS_FILE"

# Helper function
run_as() {
    AWS_ACCESS_KEY_ID="$POLICY_KEY" AWS_SECRET_ACCESS_KEY="$POLICY_SECRET" \
        AWS_DEFAULT_REGION="$REGION" "$@" 2>/dev/null
}

echo "  Running 5 concept checks..."
echo ""

# Clean any leftover challenge policies from the user
EXISTING=$(aws iam list-user-policies --user-name iam-lab-policy-user \
    --query 'PolicyNames' --output text 2>/dev/null)
for P in $EXISTING; do
    aws iam delete-user-policy --user-name iam-lab-policy-user --policy-name "$P" 2>/dev/null
done

# Temporarily apply a comprehensive test policy
aws iam put-user-policy --user-name iam-lab-policy-user \
    --policy-name verify-test-policy \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "BucketLevel",
                "Effect": "Allow",
                "Action": "s3:ListBucket",
                "Resource": "arn:aws:s3:::'"$BUCKET_NAME"'",
                "Condition": {"StringLike": {"s3:prefix": "public/*"}}
            },
            {
                "Sid": "ObjectLevel",
                "Effect": "Allow",
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::'"$BUCKET_NAME"'/public/*"
            },
            {
                "Sid": "RegionRestricted",
                "Effect": "Allow",
                "Action": "ec2:DescribeVpcs",
                "Resource": "*",
                "Condition": {"StringEquals": {"aws:RequestedRegion": "'"$REGION"'"}}
            }
        ]
    }'

sleep 10

# Check 1: User exists
echo -n "  [1/5] Test user exists... "
aws iam get-user --user-name iam-lab-policy-user >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Check 2: Test bucket has files
echo -n "  [2/5] Test bucket has public/ and confidential/ files... "
PUBLIC_COUNT=$(aws s3 ls "s3://${BUCKET_NAME}/public/" 2>/dev/null | wc -l | tr -d ' ')
CONF_COUNT=$(aws s3 ls "s3://${BUCKET_NAME}/confidential/" 2>/dev/null | wc -l | tr -d ' ')
if [ "$PUBLIC_COUNT" -ge 2 ] && [ "$CONF_COUNT" -ge 2 ]; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC} (public: $PUBLIC_COUNT, confidential: $CONF_COUNT)"
    FAIL=$((FAIL + 1))
fi

# Check 3: Scoped user CAN read public prefix
echo -n "  [3/5] Scoped policy allows public/ read... "
OUTPUT=$(run_as aws s3 cp "s3://${BUCKET_NAME}/public/readme.txt" -)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Check 4: Scoped user CANNOT read confidential prefix
echo -n "  [4/5] Scoped policy denies confidential/ read... "
OUTPUT=$(run_as aws s3 cp "s3://${BUCKET_NAME}/confidential/secret.txt" -)
if [ $? -ne 0 ]; then
    echo -e "${GREEN}PASS${NC} (correctly denied)"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC} (should have been denied)"
    FAIL=$((FAIL + 1))
fi

# Check 5: Region restriction works
echo -n "  [5/5] Region restriction blocks other regions... "
# Pick a different region for the deny test
if [ "$REGION" = "us-west-1" ]; then
    DENY_REGION="eu-west-1"
else
    DENY_REGION="us-west-1"
fi
OUTPUT=$(run_as aws ec2 describe-vpcs --region "$DENY_REGION")
if [ $? -ne 0 ]; then
    echo -e "${GREEN}PASS${NC} (correctly denied in $DENY_REGION)"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC} (should have been denied in $DENY_REGION)"
    FAIL=$((FAIL + 1))
fi

# Clean up test policy
aws iam delete-user-policy --user-name iam-lab-policy-user \
    --policy-name verify-test-policy 2>/dev/null

echo ""
echo "=============================================="
echo "  Result: $PASS/$TOTAL checks passed"
echo "=============================================="
echo ""

if [ "$PASS" -eq "$TOTAL" ]; then
    echo -e "  ${GREEN}Lab 03 verified successfully.${NC}"
else
    echo -e "  ${RED}Some checks failed.${NC}"
    echo "  Make sure setup was run and IAM has propagated (wait 10s)."
fi
echo ""
