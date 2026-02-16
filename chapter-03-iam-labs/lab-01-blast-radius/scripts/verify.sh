#!/bin/bash

# Lab 01: Blast Radius — Verify

echo ""
echo "=============================================="
echo "  Lab 01: Blast Radius — Verification"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0
TOTAL=4

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
BUCKET_NAME="iam-lab-test-${ACCOUNT_ID}"

# Check 1: Overprivileged user exists
echo -n "  [1/4] iam-lab-admin-user exists... "
aws iam get-user --user-name iam-lab-admin-user >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Check 2: Admin user has AdministratorAccess
echo -n "  [2/4] Admin user has AdministratorAccess... "
POLICIES=$(aws iam list-attached-user-policies --user-name iam-lab-admin-user \
    --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null)
if echo "$POLICIES" | grep -q "AdministratorAccess"; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Check 3: Scoped user exists with inline policy
echo -n "  [3/4] iam-lab-scoped-user has scoped policy... "
INLINE=$(aws iam list-user-policies --user-name iam-lab-scoped-user \
    --query 'PolicyNames' --output text 2>/dev/null)
if echo "$INLINE" | grep -q "iam-lab-scoped-policy"; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Check 4: Test bucket exists with files
echo -n "  [4/4] Test bucket exists with data... "
FILE_COUNT=$(aws s3 ls "s3://${BUCKET_NAME}/" --recursive --query 'length(@)' 2>/dev/null | wc -l | tr -d ' ')
if [ "$FILE_COUNT" -gt 0 ] 2>/dev/null; then
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
    echo -e "  ${GREEN}Lab 01 setup verified successfully.${NC}"
else
    echo -e "  ${RED}Some checks failed. Run setup again:${NC}"
    echo "  bash lab-01-blast-radius/scripts/setup.sh"
fi
echo ""
