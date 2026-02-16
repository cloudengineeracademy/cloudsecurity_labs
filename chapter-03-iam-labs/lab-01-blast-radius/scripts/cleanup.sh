#!/bin/bash

# Lab 01: Blast Radius — Cleanup
# Removes all resources created by this lab

echo ""
echo "=============================================="
echo "  Lab 01: Blast Radius — Cleanup"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
BUCKET_NAME="iam-lab-test-${ACCOUNT_ID}"
KEYS_FILE="/tmp/iam-lab-01-keys"

# ============================================================
# Clean up admin user
# ============================================================
echo -e "${BLUE}Cleaning up iam-lab-admin-user...${NC}"

# Delete access keys
ADMIN_KEYS=$(aws iam list-access-keys --user-name iam-lab-admin-user \
    --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null)
for KEY_ID in $ADMIN_KEYS; do
    aws iam delete-access-key --user-name iam-lab-admin-user --access-key-id "$KEY_ID" 2>/dev/null
done

# Detach policies
aws iam detach-user-policy --user-name iam-lab-admin-user \
    --policy-arn arn:aws:iam::aws:policy/AdministratorAccess 2>/dev/null

# Delete user
aws iam delete-user --user-name iam-lab-admin-user 2>/dev/null
echo -e "  ${GREEN}Deleted iam-lab-admin-user${NC}"

# ============================================================
# Clean up scoped user
# ============================================================
echo -e "${BLUE}Cleaning up iam-lab-scoped-user...${NC}"

# Delete access keys
SCOPED_KEYS=$(aws iam list-access-keys --user-name iam-lab-scoped-user \
    --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null)
for KEY_ID in $SCOPED_KEYS; do
    aws iam delete-access-key --user-name iam-lab-scoped-user --access-key-id "$KEY_ID" 2>/dev/null
done

# Delete inline policy
aws iam delete-user-policy --user-name iam-lab-scoped-user \
    --policy-name iam-lab-scoped-policy 2>/dev/null

# Delete user
aws iam delete-user --user-name iam-lab-scoped-user 2>/dev/null
echo -e "  ${GREEN}Deleted iam-lab-scoped-user${NC}"

# ============================================================
# Clean up backdoor user (in case test was interrupted)
# ============================================================
aws iam delete-user --user-name iam-lab-backdoor-test 2>/dev/null

# ============================================================
# Clean up S3 bucket
# ============================================================
echo -e "${BLUE}Cleaning up test bucket...${NC}"
aws s3 rm "s3://${BUCKET_NAME}" --recursive 2>/dev/null
aws s3api delete-bucket --bucket "$BUCKET_NAME" 2>/dev/null
echo -e "  ${GREEN}Deleted bucket: $BUCKET_NAME${NC}"

# ============================================================
# Clean up keys file
# ============================================================
if [ -f "$KEYS_FILE" ]; then
    rm -f "$KEYS_FILE"
    echo -e "  ${GREEN}Deleted keys file: $KEYS_FILE${NC}"
fi

echo ""
echo -e "${GREEN}Lab 01 cleanup complete.${NC}"
echo ""
