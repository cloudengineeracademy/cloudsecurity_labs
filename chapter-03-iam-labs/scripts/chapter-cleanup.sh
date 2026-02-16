#!/bin/bash

# Chapter: IAM Labs — Full Cleanup
# Removes ALL resources created by all 4 labs

echo ""
echo "=============================================="
echo "  IAM Labs — Chapter Cleanup"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    exit 1
fi

echo "  Account: $ACCOUNT_ID"
echo ""
echo -e "${YELLOW}This will remove ALL resources from all 4 IAM labs.${NC}"
echo ""

# ============================================================
# Helper function: delete IAM user
# ============================================================
delete_user() {
    local username="$1"
    aws iam get-user --user-name "$username" >/dev/null 2>&1 || return

    # Delete access keys
    local keys=$(aws iam list-access-keys --user-name "$username" \
        --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null)
    for key in $keys; do
        aws iam delete-access-key --user-name "$username" --access-key-id "$key" 2>/dev/null
    done

    # Delete inline policies
    local policies=$(aws iam list-user-policies --user-name "$username" \
        --query 'PolicyNames' --output text 2>/dev/null)
    for policy in $policies; do
        aws iam delete-user-policy --user-name "$username" --policy-name "$policy" 2>/dev/null
    done

    # Detach managed policies
    local managed=$(aws iam list-attached-user-policies --user-name "$username" \
        --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null)
    for arn in $managed; do
        aws iam detach-user-policy --user-name "$username" --policy-arn "$arn" 2>/dev/null
    done

    # Remove from groups
    local groups=$(aws iam list-groups-for-user --user-name "$username" \
        --query 'Groups[].GroupName' --output text 2>/dev/null)
    for group in $groups; do
        aws iam remove-user-from-group --group-name "$group" --user-name "$username" 2>/dev/null
    done

    aws iam delete-user --user-name "$username" 2>/dev/null
    echo -e "  ${GREEN}Deleted user: $username${NC}"
}

# ============================================================
# Helper function: delete IAM role
# ============================================================
delete_role() {
    local rolename="$1"
    aws iam get-role --role-name "$rolename" >/dev/null 2>&1 || return

    # Delete inline policies
    local policies=$(aws iam list-role-policies --role-name "$rolename" \
        --query 'PolicyNames' --output text 2>/dev/null)
    for policy in $policies; do
        aws iam delete-role-policy --role-name "$rolename" --policy-name "$policy" 2>/dev/null
    done

    # Detach managed policies
    local managed=$(aws iam list-attached-role-policies --role-name "$rolename" \
        --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null)
    for arn in $managed; do
        aws iam detach-role-policy --role-name "$rolename" --policy-arn "$arn" 2>/dev/null
    done

    aws iam delete-role --role-name "$rolename" 2>/dev/null
    echo -e "  ${GREEN}Deleted role: $rolename${NC}"
}

# ============================================================
# Helper function: delete S3 bucket
# ============================================================
delete_bucket() {
    local bucket="$1"
    aws s3api head-bucket --bucket "$bucket" 2>/dev/null || return
    aws s3 rm "s3://${bucket}" --recursive 2>/dev/null
    aws s3api delete-bucket --bucket "$bucket" 2>/dev/null
    echo -e "  ${GREEN}Deleted bucket: $bucket${NC}"
}

# ============================================================
# Lab 01: Blast Radius
# ============================================================
echo -e "${BLUE}Lab 01: Blast Radius...${NC}"
delete_user "iam-lab-admin-user"
delete_user "iam-lab-scoped-user"
delete_user "iam-lab-backdoor-test"
delete_bucket "iam-lab-test-${ACCOUNT_ID}"

# ============================================================
# Lab 02: Roles & Trust Policies
# ============================================================
echo -e "${BLUE}Lab 02: Roles & Trust Policies...${NC}"
delete_user "iam-lab-group-user"

# Delete group
aws iam detach-group-policy --group-name iam-lab-dev-group \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess 2>/dev/null
aws iam delete-group --group-name iam-lab-dev-group 2>/dev/null && \
    echo -e "  ${GREEN}Deleted group: iam-lab-dev-group${NC}"

delete_role "iam-lab-assumable-role"
delete_role "iam-lab-ec2-role"
delete_role "iam-lab-cross-account-role"

# ============================================================
# Lab 03: ARN Scoping
# ============================================================
echo -e "${BLUE}Lab 03: ARN Scoping...${NC}"
delete_user "iam-lab-policy-user"
delete_user "provisioned-test-user"
delete_bucket "iam-lab-arn-${ACCOUNT_ID}"

# ============================================================
# Lab 04: Least Privilege
# ============================================================
echo -e "${BLUE}Lab 04: Least Privilege...${NC}"
delete_role "iam-lab-unbounded-role"
delete_role "iam-lab-bounded-role"
delete_bucket "iam-lab-lp-${ACCOUNT_ID}"

# Delete boundary policy
BOUNDARY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/iam-lab-boundary"
aws iam delete-policy --policy-arn "$BOUNDARY_ARN" 2>/dev/null && \
    echo -e "  ${GREEN}Deleted policy: iam-lab-boundary${NC}"

# ============================================================
# Clean up temp files
# ============================================================
echo -e "${BLUE}Cleaning up temp files...${NC}"
rm -f /tmp/iam-lab-01-keys /tmp/iam-lab-03-keys /tmp/iam-lab-04-config 2>/dev/null
echo -e "  ${GREEN}Deleted temp files${NC}"

echo ""
echo "=============================================="
echo -e "  ${GREEN}All IAM lab resources cleaned up.${NC}"
echo "=============================================="
echo ""
