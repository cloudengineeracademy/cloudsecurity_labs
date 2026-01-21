#!/bin/bash

# Lab 03: Cleanup Script
# Removes all resources created by the credential security lab

echo ""
echo "=============================================="
echo "  CLEANUP - Lab 03 Credential Security"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

STACK_NAME="lab03-credential-security"

# Check if stack exists
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query 'Stacks[0].StackStatus' --output text 2>/dev/null)

# Delete manually created secrets
echo "Deleting manually created secrets..."
aws secretsmanager delete-secret \
    --secret-id lab03/database-credentials \
    --force-delete-without-recovery 2>/dev/null && echo -e "${GREEN}Deleted lab03/database-credentials${NC}" || echo "Secret not found or already deleted"

echo ""

# Delete the CloudFormation stack (which includes the auto-generated secret)
if [ -n "$STACK_STATUS" ] && [ "$STACK_STATUS" != "None" ]; then
    echo "Stack status: $STACK_STATUS"
    echo ""
    echo "Deleting CloudFormation stack: $STACK_NAME"
    aws cloudformation delete-stack --stack-name $STACK_NAME

    echo ""
    echo "Waiting for stack deletion..."

    WAIT_COUNT=0
    MAX_WAIT=60

    while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        STATUS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query 'Stacks[0].StackStatus' --output text 2>/dev/null)

        if [ -z "$STATUS" ] || [[ "$STATUS" == *"does not exist"* ]]; then
            echo ""
            echo -e "${GREEN}Stack deleted successfully!${NC}"
            break
        fi

        if [ "$STATUS" = "DELETE_FAILED" ]; then
            echo ""
            echo -e "${RED}Stack deletion failed!${NC}"
            aws cloudformation describe-stack-events \
                --stack-name $STACK_NAME \
                --query 'StackEvents[?ResourceStatus==`DELETE_FAILED`].[LogicalResourceId,ResourceStatusReason]' \
                --output table
            exit 1
        fi

        echo -n "."
        sleep 5
        ((WAIT_COUNT++))
    done
else
    echo -e "${YELLOW}Stack '$STACK_NAME' not found.${NC}"
fi

# Clean up sample code directory
echo ""
echo "Cleaning up sample code..."
if [ -d "sample-code" ]; then
    rm -rf sample-code
    echo -e "${GREEN}Removed sample-code directory${NC}"
else
    echo "No sample-code directory found"
fi

# Remove pre-commit hook if it exists
if [ -f ".git/hooks/pre-commit" ]; then
    echo ""
    echo -e "${YELLOW}Pre-commit hook found at .git/hooks/pre-commit${NC}"
    echo "Would you like to remove it? (y/n)"
    read -r REMOVE_HOOK

    if [ "$REMOVE_HOOK" = "y" ] || [ "$REMOVE_HOOK" = "Y" ]; then
        rm .git/hooks/pre-commit
        echo -e "${GREEN}Pre-commit hook removed${NC}"
    else
        echo "Pre-commit hook kept"
    fi
fi

# Final verification
echo ""
echo "----------------------------------------------"
echo "Verifying cleanup..."
echo "----------------------------------------------"
echo ""

# Check stack
FINAL_STATUS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME 2>&1)
if [[ "$FINAL_STATUS" == *"does not exist"* ]]; then
    echo -e "${GREEN}[OK]${NC} CloudFormation stack deleted"
else
    echo -e "${YELLOW}[WARN]${NC} Stack may still be deleting"
fi

# Check secrets
SECRET_CHECK=$(aws secretsmanager describe-secret --secret-id lab03/database-credentials 2>&1)
if [[ "$SECRET_CHECK" == *"ResourceNotFoundException"* ]]; then
    echo -e "${GREEN}[OK]${NC} Manual secret deleted"
else
    echo -e "${YELLOW}[WARN]${NC} Secret may still exist"
fi

SECRET_CHECK2=$(aws secretsmanager describe-secret --secret-id lab03/application-credentials 2>&1)
if [[ "$SECRET_CHECK2" == *"ResourceNotFoundException"* ]]; then
    echo -e "${GREEN}[OK]${NC} Application secret deleted"
else
    echo -e "${YELLOW}[WARN]${NC} Application secret may still exist (scheduled for deletion)"
fi

echo ""
echo "=============================================="
echo -e "${GREEN}  CLEANUP COMPLETE${NC}"
echo "=============================================="
echo ""
echo "All Lab 03 resources have been removed."
echo ""
echo "Continue to Lab 04: Detection and CloudTrail"
echo "  cd ../lab-04-detection-cloudtrail"
echo ""
