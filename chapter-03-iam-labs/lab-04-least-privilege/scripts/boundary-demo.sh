#!/bin/bash

# Lab 04: Permissions Boundary Demo
# Shows the difference between a bounded and unbounded role

echo ""
echo "=============================================="
echo "  Lab 04: Permissions Boundary Demo"
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

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    exit 1
fi

# Verify roles exist
aws iam get-role --role-name iam-lab-unbounded-role >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Roles not found. Run setup first.${NC}"
    echo "  bash lab-04-least-privilege/scripts/setup.sh"
    exit 1
fi

# Helper: assume role and run a command
assume_and_run() {
    local role_name="$1"
    shift
    local role_arn="arn:aws:iam::${ACCOUNT_ID}:role/${role_name}"

    CREDS=$(aws sts assume-role \
        --role-arn "$role_arn" \
        --role-session-name "boundary-test" \
        --query 'Credentials' --output json 2>/dev/null)

    if [ $? -ne 0 ]; then
        echo "ASSUME_FAILED"
        return 1
    fi

    local tk=$(echo "$CREDS" | grep -o '"AccessKeyId": *"[^"]*"' | cut -d'"' -f4)
    local ts=$(echo "$CREDS" | grep -o '"SecretAccessKey": *"[^"]*"' | cut -d'"' -f4)
    local tt=$(echo "$CREDS" | grep -o '"SessionToken": *"[^"]*"' | cut -d'"' -f4)

    AWS_ACCESS_KEY_ID="$tk" AWS_SECRET_ACCESS_KEY="$ts" \
        AWS_SESSION_TOKEN="$tt" AWS_DEFAULT_REGION="$REGION" "$@" 2>/dev/null
}

# ============================================================
# Test unbounded role
# ============================================================
echo -e "${RED}========================================${NC}"
echo -e "${RED}  ROLE: iam-lab-unbounded-role${NC}"
echo -e "${RED}  Policy: AdministratorAccess${NC}"
echo -e "${RED}  Boundary: NONE${NC}"
echo -e "${RED}========================================${NC}"
echo ""

UNBOUNDED_PASS=0

echo -n "  1. aws s3 ls                → "
assume_and_run iam-lab-unbounded-role aws s3 ls >/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}SUCCESS${NC}"
    UNBOUNDED_PASS=$((UNBOUNDED_PASS + 1))
else
    echo -e "${RED}DENIED${NC}"
fi

echo -n "  2. aws iam list-users       → "
assume_and_run iam-lab-unbounded-role aws iam list-users >/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}SUCCESS${NC}"
    UNBOUNDED_PASS=$((UNBOUNDED_PASS + 1))
else
    echo -e "${RED}DENIED${NC}"
fi

echo -n "  3. aws ec2 describe-vpcs    → "
assume_and_run iam-lab-unbounded-role aws ec2 describe-vpcs --region "$REGION" >/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}SUCCESS${NC}"
    UNBOUNDED_PASS=$((UNBOUNDED_PASS + 1))
else
    echo -e "${RED}DENIED${NC}"
fi

echo ""
echo -e "  ${RED}Result: $UNBOUNDED_PASS/3 — can do EVERYTHING${NC}"
echo ""

# ============================================================
# Test bounded role
# ============================================================
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ROLE: iam-lab-bounded-role${NC}"
echo -e "${GREEN}  Policy: AdministratorAccess${NC}"
echo -e "${GREEN}  Boundary: S3 + CloudWatch ONLY${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

BOUNDED_PASS=0

echo -n "  1. aws s3 ls                → "
assume_and_run iam-lab-bounded-role aws s3 ls >/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}SUCCESS${NC} (S3 is within boundary)"
    BOUNDED_PASS=$((BOUNDED_PASS + 1))
else
    echo -e "${YELLOW}DENIED${NC}"
fi

echo -n "  2. aws iam list-users       → "
assume_and_run iam-lab-bounded-role aws iam list-users >/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}SUCCESS${NC}"
    BOUNDED_PASS=$((BOUNDED_PASS + 1))
else
    echo -e "${YELLOW}DENIED${NC} (IAM is outside boundary)"
fi

echo -n "  3. aws ec2 describe-vpcs    → "
assume_and_run iam-lab-bounded-role aws ec2 describe-vpcs --region "$REGION" >/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}SUCCESS${NC}"
    BOUNDED_PASS=$((BOUNDED_PASS + 1))
else
    echo -e "${YELLOW}DENIED${NC} (EC2 is outside boundary)"
fi

echo ""
echo -e "  ${GREEN}Result: $BOUNDED_PASS/3 — boundary blocks IAM and EC2${NC}"
echo ""

# ============================================================
# Comparison
# ============================================================
echo "=============================================="
echo "  COMPARISON"
echo "=============================================="
echo ""
echo "  Both roles have AdministratorAccess attached."
echo "  Same permission policy. Different boundaries."
echo ""
echo -e "  ${RED}Unbounded: $UNBOUNDED_PASS/3 succeeded${NC}"
echo "    No boundary → AdministratorAccess means ADMIN"
echo ""
echo -e "  ${GREEN}Bounded:   $BOUNDED_PASS/3 succeeded${NC}"
echo "    Boundary caps it → AdministratorAccess means S3 + CloudWatch only"
echo ""
echo "  The boundary is the CEILING. No matter what policies you attach,"
echo "  the role can never exceed the boundary."
echo ""
echo "  In production, the security team sets the boundary."
echo "  Developers can attach whatever policies they want to their roles —"
echo "  but they can never exceed what the boundary allows."
echo ""
echo "  Next: Follow the README Part 3 for the scope-down workflow."
echo ""
