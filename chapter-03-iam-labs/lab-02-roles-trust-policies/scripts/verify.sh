#!/bin/bash

# Lab 02: Roles & Trust Policies — Verify

echo ""
echo "=============================================="
echo "  Lab 02: Roles & Trust Policies — Verification"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0
TOTAL=5

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

# Check 1: Group exists with policy
echo -n "  [1/5] iam-lab-dev-group exists with S3 policy... "
POLICIES=$(aws iam list-attached-group-policies --group-name iam-lab-dev-group \
    --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null)
if echo "$POLICIES" | grep -q "AmazonS3ReadOnlyAccess"; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Check 2: User is in group
echo -n "  [2/5] iam-lab-group-user is in dev group... "
GROUPS=$(aws iam list-groups-for-user --user-name iam-lab-group-user \
    --query 'Groups[].GroupName' --output text 2>/dev/null)
if echo "$GROUPS" | grep -q "iam-lab-dev-group"; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Check 3: Assumable role exists with correct trust
echo -n "  [3/5] iam-lab-assumable-role trusts this account... "
TRUST=$(aws iam get-role --role-name iam-lab-assumable-role \
    --query 'Role.AssumeRolePolicyDocument.Statement[0].Principal.AWS' --output text 2>/dev/null)
if echo "$TRUST" | grep -q "$ACCOUNT_ID"; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Check 4: EC2 role exists with EC2 trust
echo -n "  [4/5] iam-lab-ec2-role trusts ec2.amazonaws.com... "
EC2_TRUST=$(aws iam get-role --role-name iam-lab-ec2-role \
    --query 'Role.AssumeRolePolicyDocument.Statement[0].Principal.Service' --output text 2>/dev/null)
if [ "$EC2_TRUST" = "ec2.amazonaws.com" ]; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Check 5: Cross-account role exists with ExternalId condition
echo -n "  [5/5] iam-lab-cross-account-role has ExternalId... "
EXTERNAL_ID=$(aws iam get-role --role-name iam-lab-cross-account-role \
    --query 'Role.AssumeRolePolicyDocument.Statement[0].Condition.StringEquals."sts:ExternalId"' \
    --output text 2>/dev/null)
if [ -n "$EXTERNAL_ID" ] && [ "$EXTERNAL_ID" != "None" ]; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "=============================================="
echo "  Result: $PASS/$TOTAL checks passed"
echo "=============================================="
echo ""

if [ "$PASS" -eq "$TOTAL" ]; then
    echo -e "  ${GREEN}Lab 02 verified successfully.${NC}"
else
    echo -e "  ${RED}Some checks failed. Run setup:${NC}"
    echo "  bash lab-02-roles-trust-policies/scripts/setup.sh"
fi
echo ""
