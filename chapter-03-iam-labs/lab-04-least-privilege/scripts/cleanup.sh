#!/bin/bash

# Lab 04: Least Privilege — Cleanup

echo ""
echo "=============================================="
echo "  Lab 04: Least Privilege — Cleanup"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
BUCKET_NAME="iam-lab-lp-${ACCOUNT_ID}"

# ============================================================
# Clean up unbounded role
# ============================================================
echo -e "${BLUE}Cleaning up iam-lab-unbounded-role...${NC}"

aws iam detach-role-policy --role-name iam-lab-unbounded-role \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess 2>/dev/null

# Delete any inline policies
INLINE=$(aws iam list-role-policies --role-name iam-lab-unbounded-role \
    --query 'PolicyNames' --output text 2>/dev/null)
for POLICY in $INLINE; do
    aws iam delete-role-policy --role-name iam-lab-unbounded-role --policy-name "$POLICY" 2>/dev/null
done

aws iam delete-role --role-name iam-lab-unbounded-role 2>/dev/null
echo -e "  ${GREEN}Deleted: iam-lab-unbounded-role${NC}"

# ============================================================
# Clean up bounded role
# ============================================================
echo -e "${BLUE}Cleaning up iam-lab-bounded-role...${NC}"

aws iam detach-role-policy --role-name iam-lab-bounded-role \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess 2>/dev/null

# Delete any inline policies
INLINE=$(aws iam list-role-policies --role-name iam-lab-bounded-role \
    --query 'PolicyNames' --output text 2>/dev/null)
for POLICY in $INLINE; do
    aws iam delete-role-policy --role-name iam-lab-bounded-role --policy-name "$POLICY" 2>/dev/null
done

aws iam delete-role --role-name iam-lab-bounded-role 2>/dev/null
echo -e "  ${GREEN}Deleted: iam-lab-bounded-role${NC}"

# ============================================================
# Clean up boundary policy
# ============================================================
echo -e "${BLUE}Cleaning up boundary policy...${NC}"

BOUNDARY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/iam-lab-boundary"
aws iam delete-policy --policy-arn "$BOUNDARY_ARN" 2>/dev/null
echo -e "  ${GREEN}Deleted: iam-lab-boundary policy${NC}"

# ============================================================
# Clean up S3 bucket
# ============================================================
echo -e "${BLUE}Cleaning up test bucket...${NC}"
aws s3 rm "s3://${BUCKET_NAME}" --recursive 2>/dev/null
aws s3api delete-bucket --bucket "$BUCKET_NAME" 2>/dev/null
echo -e "  ${GREEN}Deleted: $BUCKET_NAME${NC}"

# Clean up config file
rm -f /tmp/iam-lab-04-config 2>/dev/null

echo ""
echo -e "${GREEN}Lab 04 cleanup complete.${NC}"
echo ""
