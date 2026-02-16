#!/bin/bash

# Lab 02: Assume Role Demo
# Demonstrates assuming a role and using temporary credentials

echo ""
echo "=============================================="
echo "  Lab 02: Assume Role Demo"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
REGION=$(aws configure get region 2>/dev/null)
if [ -z "$REGION" ]; then
    REGION="us-east-1"
fi
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/iam-lab-assumable-role"

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    exit 1
fi

# Check role exists
aws iam get-role --role-name iam-lab-assumable-role >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Role not found. Run setup first.${NC}"
    echo "  bash lab-02-roles-trust-policies/scripts/setup.sh"
    exit 1
fi

# ============================================================
# Show current identity
# ============================================================
echo -e "${BLUE}Your current identity:${NC}"
aws sts get-caller-identity --output table
echo ""

# ============================================================
# Assume the role
# ============================================================
echo -e "${BLUE}Assuming role: iam-lab-assumable-role...${NC}"
echo ""

CREDS=$(aws sts assume-role \
    --role-arn "$ROLE_ARN" \
    --role-session-name lab-demo-session \
    --query 'Credentials' --output json 2>&1)

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Failed to assume role.${NC}"
    echo "  $CREDS"
    exit 1
fi

# Extract credential components
TEMP_KEY=$(echo "$CREDS" | grep -o '"AccessKeyId": *"[^"]*"' | cut -d'"' -f4)
TEMP_SECRET=$(echo "$CREDS" | grep -o '"SecretAccessKey": *"[^"]*"' | cut -d'"' -f4)
TEMP_TOKEN=$(echo "$CREDS" | grep -o '"SessionToken": *"[^"]*"' | cut -d'"' -f4)
EXPIRATION=$(echo "$CREDS" | grep -o '"Expiration": *"[^"]*"' | cut -d'"' -f4)

echo -e "${GREEN}Role assumed successfully.${NC}"
echo ""
echo "  Temporary credentials received:"
echo "    AccessKeyId:     ${TEMP_KEY:0:8}...${TEMP_KEY: -4} (starts with ASIA = temporary)"
echo "    SecretAccessKey: ****...****"
echo "    SessionToken:    ${TEMP_TOKEN:0:20}... ($(echo "$TEMP_TOKEN" | wc -c | tr -d ' ') chars)"
echo "    Expiration:      $EXPIRATION"
echo ""
echo -e "  ${YELLOW}Notice: The key starts with ASIA, not AKIA.${NC}"
echo "  AKIA = long-lived access key (dangerous if leaked)"
echo "  ASIA = temporary credentials (expires automatically)"
echo ""

# ============================================================
# Test with temporary credentials
# ============================================================
echo -e "${BLUE}Testing with temporary credentials:${NC}"
echo ""

# Test 1: S3 list (should work — role has S3 read-only)
echo -n "  1. aws s3 ls (S3 read-only policy)  → "
OUTPUT=$(AWS_ACCESS_KEY_ID="$TEMP_KEY" AWS_SECRET_ACCESS_KEY="$TEMP_SECRET" \
    AWS_SESSION_TOKEN="$TEMP_TOKEN" AWS_DEFAULT_REGION="$REGION" \
    aws s3 ls 2>/dev/null)
if [ $? -eq 0 ]; then
    BUCKET_COUNT=$(echo "$OUTPUT" | wc -l | tr -d ' ')
    echo -e "${GREEN}SUCCESS${NC} ($BUCKET_COUNT buckets — role has S3 read)"
else
    echo -e "${RED}DENIED${NC}"
fi

# Test 2: IAM list (should fail — role only has S3 read)
echo -n "  2. aws iam list-users               → "
OUTPUT=$(AWS_ACCESS_KEY_ID="$TEMP_KEY" AWS_SECRET_ACCESS_KEY="$TEMP_SECRET" \
    AWS_SESSION_TOKEN="$TEMP_TOKEN" AWS_DEFAULT_REGION="$REGION" \
    aws iam list-users 2>/dev/null)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}SUCCESS${NC}"
else
    echo -e "${YELLOW}ACCESS DENIED${NC} (role doesn't have IAM permissions)"
fi

# Test 3: Get caller identity (shows the role session)
echo -n "  3. aws sts get-caller-identity      → "
IDENTITY=$(AWS_ACCESS_KEY_ID="$TEMP_KEY" AWS_SECRET_ACCESS_KEY="$TEMP_SECRET" \
    AWS_SESSION_TOKEN="$TEMP_TOKEN" AWS_DEFAULT_REGION="$REGION" \
    aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}SUCCESS${NC}"
    echo "     Identity: $IDENTITY"
    echo "     (Notice: assumed-role/iam-lab-assumable-role/lab-demo-session)"
fi

echo ""
echo "=============================================="
echo "  WHAT JUST HAPPENED"
echo "=============================================="
echo ""
echo "  1. You called STS (Security Token Service)"
echo "  2. STS checked the role's TRUST POLICY — are you allowed to assume it?"
echo "  3. STS issued TEMPORARY credentials (AccessKeyId, SecretAccessKey, SessionToken)"
echo "  4. Those credentials have the role's PERMISSION POLICY (S3 read-only)"
echo "  5. The credentials expire at: $EXPIRATION"
echo ""
echo "  After expiration, these credentials stop working automatically."
echo "  No manual rotation needed. No keys to store. No keys to leak."
echo ""
echo "  This is why roles are better than access keys."
echo ""
