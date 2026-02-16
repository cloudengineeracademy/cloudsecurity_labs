#!/bin/bash

# Lab 01: Blast Radius Test
# Runs the same 5 commands with both users and compares results

echo ""
echo "=============================================="
echo "  Lab 01: Blast Radius Test"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

KEYS_FILE="/tmp/iam-lab-01-keys"

if [ ! -f "$KEYS_FILE" ]; then
    echo -e "${RED}ERROR: Keys file not found at $KEYS_FILE${NC}"
    echo "  Run setup first: bash lab-01-blast-radius/scripts/setup.sh"
    exit 1
fi

source "$KEYS_FILE"

# Helper function: run command as a specific user
run_as() {
    local key="$1"
    local secret="$2"
    local region="$3"
    shift 3
    AWS_ACCESS_KEY_ID="$key" AWS_SECRET_ACCESS_KEY="$secret" AWS_DEFAULT_REGION="$region" "$@" 2>/dev/null
}

ADMIN_PASS=0
ADMIN_FAIL=0
SCOPED_PASS=0
SCOPED_FAIL=0

# ============================================================
# TEST 1: OVERPRIVILEGED USER
# ============================================================
echo -e "${RED}========================================${NC}"
echo -e "${RED}  TESTING: iam-lab-admin-user${NC}"
echo -e "${RED}  Policy:  AdministratorAccess${NC}"
echo -e "${RED}========================================${NC}"
echo ""

# Test 1: List all S3 buckets
echo -n "  1. aws s3 ls (list all buckets)            → "
OUTPUT=$(run_as "$ADMIN_KEY" "$ADMIN_SECRET" "$REGION" aws s3 ls)
if [ $? -eq 0 ]; then
    BUCKET_COUNT=$(echo "$OUTPUT" | wc -l | tr -d ' ')
    echo -e "${GREEN}SUCCESS${NC} ($BUCKET_COUNT buckets visible)"
    ADMIN_PASS=$((ADMIN_PASS + 1))
else
    echo -e "${RED}DENIED${NC}"
    ADMIN_FAIL=$((ADMIN_FAIL + 1))
fi

# Test 2: List IAM users
echo -n "  2. aws iam list-users                      → "
OUTPUT=$(run_as "$ADMIN_KEY" "$ADMIN_SECRET" "$REGION" aws iam list-users --query 'Users[].UserName' --output text)
if [ $? -eq 0 ]; then
    USER_COUNT=$(echo "$OUTPUT" | tr '\t' '\n' | wc -l | tr -d ' ')
    echo -e "${GREEN}SUCCESS${NC} ($USER_COUNT users visible)"
    ADMIN_PASS=$((ADMIN_PASS + 1))
else
    echo -e "${RED}DENIED${NC}"
    ADMIN_FAIL=$((ADMIN_FAIL + 1))
fi

# Test 3: Describe EC2 instances
echo -n "  3. aws ec2 describe-instances               → "
OUTPUT=$(run_as "$ADMIN_KEY" "$ADMIN_SECRET" "$REGION" aws ec2 describe-instances --query 'Reservations | length(@)' --output text)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}SUCCESS${NC} (can see all EC2 instances)"
    ADMIN_PASS=$((ADMIN_PASS + 1))
else
    echo -e "${RED}DENIED${NC}"
    ADMIN_FAIL=$((ADMIN_FAIL + 1))
fi

# Test 4: Create a backdoor user (then immediately delete it)
echo -n "  4. aws iam create-user (backdoor!)          → "
OUTPUT=$(run_as "$ADMIN_KEY" "$ADMIN_SECRET" "$REGION" aws iam create-user --user-name iam-lab-backdoor-test)
if [ $? -eq 0 ]; then
    echo -e "${RED}SUCCESS — BACKDOOR USER CREATED${NC}"
    # Immediately clean up the backdoor
    run_as "$ADMIN_KEY" "$ADMIN_SECRET" "$REGION" aws iam delete-user --user-name iam-lab-backdoor-test
    ADMIN_PASS=$((ADMIN_PASS + 1))
else
    echo -e "${RED}DENIED${NC}"
    ADMIN_FAIL=$((ADMIN_FAIL + 1))
fi

# Test 5: Read the scoped bucket
echo -n "  5. aws s3 ls s3://$BUCKET_NAME/  → "
OUTPUT=$(run_as "$ADMIN_KEY" "$ADMIN_SECRET" "$REGION" aws s3 ls "s3://${BUCKET_NAME}/")
if [ $? -eq 0 ]; then
    echo -e "${GREEN}SUCCESS${NC}"
    ADMIN_PASS=$((ADMIN_PASS + 1))
else
    echo -e "${RED}DENIED${NC}"
    ADMIN_FAIL=$((ADMIN_FAIL + 1))
fi

echo ""
echo -e "  ${RED}Result: $ADMIN_PASS/5 commands succeeded${NC}"
echo ""

# ============================================================
# TEST 2: SCOPED USER
# ============================================================
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  TESTING: iam-lab-scoped-user${NC}"
echo -e "${GREEN}  Policy:  S3 read on $BUCKET_NAME only${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Test 1: List all S3 buckets
echo -n "  1. aws s3 ls (list all buckets)            → "
OUTPUT=$(run_as "$SCOPED_KEY" "$SCOPED_SECRET" "$REGION" aws s3 ls)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}SUCCESS${NC}"
    SCOPED_PASS=$((SCOPED_PASS + 1))
else
    echo -e "${YELLOW}ACCESS DENIED${NC}"
    SCOPED_FAIL=$((SCOPED_FAIL + 1))
fi

# Test 2: List IAM users
echo -n "  2. aws iam list-users                      → "
OUTPUT=$(run_as "$SCOPED_KEY" "$SCOPED_SECRET" "$REGION" aws iam list-users)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}SUCCESS${NC}"
    SCOPED_PASS=$((SCOPED_PASS + 1))
else
    echo -e "${YELLOW}ACCESS DENIED${NC}"
    SCOPED_FAIL=$((SCOPED_FAIL + 1))
fi

# Test 3: Describe EC2 instances
echo -n "  3. aws ec2 describe-instances               → "
OUTPUT=$(run_as "$SCOPED_KEY" "$SCOPED_SECRET" "$REGION" aws ec2 describe-instances)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}SUCCESS${NC}"
    SCOPED_PASS=$((SCOPED_PASS + 1))
else
    echo -e "${YELLOW}ACCESS DENIED${NC}"
    SCOPED_FAIL=$((SCOPED_FAIL + 1))
fi

# Test 4: Create a backdoor user
echo -n "  4. aws iam create-user (backdoor!)          → "
OUTPUT=$(run_as "$SCOPED_KEY" "$SCOPED_SECRET" "$REGION" aws iam create-user --user-name iam-lab-backdoor-test)
if [ $? -eq 0 ]; then
    echo -e "${RED}SUCCESS — BACKDOOR USER CREATED${NC}"
    run_as "$SCOPED_KEY" "$SCOPED_SECRET" "$REGION" aws iam delete-user --user-name iam-lab-backdoor-test
    SCOPED_PASS=$((SCOPED_PASS + 1))
else
    echo -e "${YELLOW}ACCESS DENIED${NC}"
    SCOPED_FAIL=$((SCOPED_FAIL + 1))
fi

# Test 5: Read the scoped bucket
echo -n "  5. aws s3 ls s3://$BUCKET_NAME/  → "
OUTPUT=$(run_as "$SCOPED_KEY" "$SCOPED_SECRET" "$REGION" aws s3 ls "s3://${BUCKET_NAME}/")
if [ $? -eq 0 ]; then
    echo -e "${GREEN}SUCCESS${NC}"
    SCOPED_PASS=$((SCOPED_PASS + 1))
else
    echo -e "${RED}DENIED${NC}"
    SCOPED_FAIL=$((SCOPED_FAIL + 1))
fi

echo ""
echo -e "  ${GREEN}Result: $SCOPED_PASS/5 commands succeeded${NC}"
echo ""

# ============================================================
# COMPARISON
# ============================================================
echo "=============================================="
echo "  BLAST RADIUS COMPARISON"
echo "=============================================="
echo ""
echo -e "  ${RED}Overprivileged user: $ADMIN_PASS/5 succeeded${NC}"
echo "    Can: list all buckets, enumerate users, see EC2,"
echo "         CREATE BACKDOOR USERS, read any data"
echo "    Blast radius: FULL ACCOUNT COMPROMISE"
echo ""
echo -e "  ${GREEN}Scoped user: $SCOPED_PASS/5 succeeded${NC}"
echo "    Can: read files from one S3 bucket"
echo "    Blast radius: ONE BUCKET (read-only)"
echo ""
echo "  Same credential type (access keys)."
echo "  Same risk of being leaked."
echo "  Completely different damage."
echo ""
echo "  This is why least privilege matters."
echo ""
echo "  Next steps:"
echo "    1. Verify:  bash lab-01-blast-radius/scripts/verify.sh"
echo "    2. Cleanup: bash lab-01-blast-radius/scripts/cleanup.sh"
echo ""
