#!/bin/bash

# Lab 06: Cleanup
# Removes resources created by generate-activity.sh

echo ""
echo "=============================================="
echo "  CLEANUP: Remove Lab 06 Resources"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0

# Delete access keys for lab06-suspicious-user
echo -n "  Deleting access keys for lab06-suspicious-user... "
KEYS=$(aws iam list-access-keys --user-name "lab06-suspicious-user" --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null)
if [ -n "$KEYS" ]; then
    for KEY in $KEYS; do
        aws iam delete-access-key --user-name "lab06-suspicious-user" --access-key-id "$KEY" 2>/dev/null
    done
    echo -e "${GREEN}done${NC}"
else
    echo -e "${YELLOW}none found${NC}"
fi

# Delete the IAM user
echo -n "  Deleting IAM user 'lab06-suspicious-user'... "
aws iam delete-user --user-name "lab06-suspicious-user" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}done${NC}"
else
    echo -e "${YELLOW}not found or already deleted${NC}"
fi

# Delete the security group
echo -n "  Deleting security group 'lab06-open-ssh'... "
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=lab06-open-ssh" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
    aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}done${NC} — $SG_ID"
    else
        echo -e "${RED}failed${NC}"
        ((ERRORS++))
    fi
else
    echo -e "${YELLOW}not found or already deleted${NC}"
fi

echo ""
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}Cleanup complete. All lab resources removed.${NC}"
else
    echo -e "${RED}Some resources could not be removed. Check manually.${NC}"
fi
echo ""
echo "  Note: The cleanup actions (DeleteUser, DeleteSecurityGroup)"
echo "  are ALSO recorded in CloudTrail. Everything is logged."
echo ""
