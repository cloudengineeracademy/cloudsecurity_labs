#!/bin/bash

# Lab 03: ARN Scoping — Cleanup

echo ""
echo "=============================================="
echo "  Lab 03: ARN Scoping — Cleanup"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
BUCKET_NAME="iam-lab-arn-${ACCOUNT_ID}"
KEYS_FILE="/tmp/iam-lab-03-keys"

# ============================================================
# Clean up test user
# ============================================================
echo -e "${BLUE}Cleaning up iam-lab-policy-user...${NC}"

# Delete access keys
USER_KEYS=$(aws iam list-access-keys --user-name iam-lab-policy-user \
    --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null)
for KEY_ID in $USER_KEYS; do
    aws iam delete-access-key --user-name iam-lab-policy-user --access-key-id "$KEY_ID" 2>/dev/null
done

# Delete any inline policies (in case challenges weren't cleaned up)
POLICIES=$(aws iam list-user-policies --user-name iam-lab-policy-user \
    --query 'PolicyNames' --output text 2>/dev/null)
for POLICY in $POLICIES; do
    aws iam delete-user-policy --user-name iam-lab-policy-user --policy-name "$POLICY" 2>/dev/null
done

aws iam delete-user --user-name iam-lab-policy-user 2>/dev/null
echo -e "  ${GREEN}Deleted: iam-lab-policy-user${NC}"

# Clean up provisioned-test-user (in case challenge 5 wasn't cleaned up)
PROV_KEYS=$(aws iam list-access-keys --user-name provisioned-test-user \
    --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null)
for KEY_ID in $PROV_KEYS; do
    aws iam delete-access-key --user-name provisioned-test-user --access-key-id "$KEY_ID" 2>/dev/null
done
aws iam delete-user --user-name provisioned-test-user 2>/dev/null

# ============================================================
# Clean up S3 bucket
# ============================================================
echo -e "${BLUE}Cleaning up test bucket...${NC}"
aws s3 rm "s3://${BUCKET_NAME}" --recursive 2>/dev/null
aws s3api delete-bucket --bucket "$BUCKET_NAME" 2>/dev/null
echo -e "  ${GREEN}Deleted: $BUCKET_NAME${NC}"

# ============================================================
# Clean up keys file
# ============================================================
if [ -f "$KEYS_FILE" ]; then
    rm -f "$KEYS_FILE"
    echo -e "  ${GREEN}Deleted: $KEYS_FILE${NC}"
fi

echo ""
echo -e "${GREEN}Lab 03 cleanup complete.${NC}"
echo ""
