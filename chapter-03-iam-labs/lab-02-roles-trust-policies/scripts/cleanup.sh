#!/bin/bash

# Lab 02: Roles & Trust Policies — Cleanup

echo ""
echo "=============================================="
echo "  Lab 02: Roles & Trust Policies — Cleanup"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================
# Clean up group and user
# ============================================================
echo -e "${BLUE}Cleaning up group and user...${NC}"

aws iam remove-user-from-group --group-name iam-lab-dev-group \
    --user-name iam-lab-group-user 2>/dev/null
aws iam delete-user --user-name iam-lab-group-user 2>/dev/null
echo -e "  ${GREEN}Deleted: iam-lab-group-user${NC}"

aws iam detach-group-policy --group-name iam-lab-dev-group \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess 2>/dev/null
aws iam delete-group --group-name iam-lab-dev-group 2>/dev/null
echo -e "  ${GREEN}Deleted: iam-lab-dev-group${NC}"

# ============================================================
# Clean up assumable role
# ============================================================
echo -e "${BLUE}Cleaning up assumable role...${NC}"

aws iam detach-role-policy --role-name iam-lab-assumable-role \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess 2>/dev/null
aws iam delete-role --role-name iam-lab-assumable-role 2>/dev/null
echo -e "  ${GREEN}Deleted: iam-lab-assumable-role${NC}"

# ============================================================
# Clean up EC2 role
# ============================================================
echo -e "${BLUE}Cleaning up EC2 role...${NC}"

aws iam detach-role-policy --role-name iam-lab-ec2-role \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess 2>/dev/null
aws iam delete-role --role-name iam-lab-ec2-role 2>/dev/null
echo -e "  ${GREEN}Deleted: iam-lab-ec2-role${NC}"

# ============================================================
# Clean up cross-account role
# ============================================================
echo -e "${BLUE}Cleaning up cross-account role...${NC}"

aws iam delete-role --role-name iam-lab-cross-account-role 2>/dev/null
echo -e "  ${GREEN}Deleted: iam-lab-cross-account-role${NC}"

echo ""
echo -e "${GREEN}Lab 02 cleanup complete.${NC}"
echo ""
