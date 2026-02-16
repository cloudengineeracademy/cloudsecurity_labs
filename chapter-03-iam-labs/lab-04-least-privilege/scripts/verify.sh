#!/bin/bash

# Lab 04: Least Privilege — Verify

echo ""
echo "=============================================="
echo "  Lab 04: Least Privilege — Verification"
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
BUCKET_NAME="iam-lab-lp-${ACCOUNT_ID}"

# Check 1: Unbounded role exists with AdministratorAccess
echo -n "  [1/4] Unbounded role has AdministratorAccess... "
POLICIES=$(aws iam list-attached-role-policies --role-name iam-lab-unbounded-role \
    --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null)
if echo "$POLICIES" | grep -q "AdministratorAccess"; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Check 2: Bounded role exists with AdministratorAccess
echo -n "  [2/4] Bounded role has AdministratorAccess... "
POLICIES=$(aws iam list-attached-role-policies --role-name iam-lab-bounded-role \
    --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null)
if echo "$POLICIES" | grep -q "AdministratorAccess"; then
    echo -e "${GREEN}PASS${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Check 3: Bounded role HAS a permissions boundary
echo -n "  [3/4] Bounded role has permissions boundary... "
BOUNDARY=$(aws iam get-role --role-name iam-lab-bounded-role \
    --query 'Role.PermissionsBoundary.PermissionsBoundaryArn' --output text 2>/dev/null)
if [ -n "$BOUNDARY" ] && [ "$BOUNDARY" != "None" ]; then
    echo -e "${GREEN}PASS${NC} ($BOUNDARY)"
    PASS=$((PASS + 1))
else
    echo -e "${RED}FAIL${NC}"
    FAIL=$((FAIL + 1))
fi

# Check 4: Test bucket exists
echo -n "  [4/4] Test bucket exists... "
aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null
if [ $? -eq 0 ]; then
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
    echo -e "  ${GREEN}Lab 04 verified successfully.${NC}"
else
    echo -e "  ${RED}Some checks failed. Run setup:${NC}"
    echo "  bash lab-04-least-privilege/scripts/setup.sh"
fi
echo ""
