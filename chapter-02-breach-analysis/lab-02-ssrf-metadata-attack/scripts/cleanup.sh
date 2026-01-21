#!/bin/bash

# Lab 02: Cleanup Script
# Removes all resources created by the SSRF lab

echo ""
echo "=============================================="
echo "  CLEANUP - Lab 02 SSRF Attack"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

STACK_NAME="lab02-ssrf-attack"

# Check if stack exists
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query 'Stacks[0].StackStatus' --output text 2>/dev/null)
if [ -z "$STACK_STATUS" ] || [ "$STACK_STATUS" = "None" ]; then
    echo -e "${YELLOW}Stack '$STACK_NAME' not found. Nothing to clean up.${NC}"
    exit 0
fi

echo "Stack status: $STACK_STATUS"
echo ""

# Get bucket name before deletion
BUCKET=$(aws s3 ls 2>/dev/null | grep lab02-ssrf-data | awk '{print $3}')

if [ -n "$BUCKET" ]; then
    echo -e "${YELLOW}Emptying S3 bucket: $BUCKET${NC}"
    aws s3 rm "s3://$BUCKET" --recursive 2>/dev/null
    echo -e "${GREEN}Bucket emptied${NC}"
    echo ""
fi

# Delete the stack
echo "Deleting CloudFormation stack..."
aws cloudformation delete-stack --stack-name $STACK_NAME

# Wait for deletion
echo ""
echo "Waiting for stack deletion (this may take a few minutes)..."
echo ""

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
        echo ""
        echo "Check for resources that couldn't be deleted:"
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

if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
    echo ""
    echo -e "${YELLOW}Timeout waiting for deletion. Check AWS Console for status.${NC}"
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

# Check bucket
BUCKET_CHECK=$(aws s3 ls 2>/dev/null | grep lab02-ssrf-data)
if [ -z "$BUCKET_CHECK" ]; then
    echo -e "${GREEN}[OK]${NC} S3 bucket deleted"
else
    echo -e "${YELLOW}[WARN]${NC} S3 bucket may still exist"
fi

echo ""
echo "=============================================="
echo -e "${GREEN}  CLEANUP COMPLETE${NC}"
echo "=============================================="
echo ""
echo "All Lab 02 resources have been removed."
echo ""
echo "Continue to Lab 03: Credential Security"
echo "  cd ../lab-03-credential-security"
echo ""
