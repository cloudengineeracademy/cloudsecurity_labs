#!/bin/bash

# Cleanup Script for Lab 03: CIA Triad S3
# Removes the lab bucket and all its contents

echo "=============================================="
echo "  Lab 03 Cleanup"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get bucket name
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
BUCKET_NAME="cia-lab-${ACCOUNT_ID}"

echo "Checking for bucket: $BUCKET_NAME"

# Check if bucket exists
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo -e "${YELLOW}Bucket $BUCKET_NAME does not exist. Nothing to clean up.${NC}"
    exit 0
fi

echo -e "${YELLOW}Found bucket: $BUCKET_NAME${NC}"
echo ""

# Confirm deletion
read -p "Delete bucket and all contents? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "Deleting all object versions..."

# Delete all versions
aws s3api list-object-versions --bucket "$BUCKET_NAME" --output json 2>/dev/null | \
jq -r '.Versions[]? | .Key + " " + .VersionId' | \
while read key version; do
    if [ -n "$key" ] && [ -n "$version" ]; then
        aws s3api delete-object --bucket "$BUCKET_NAME" --key "$key" --version-id "$version" 2>/dev/null
        echo "  Deleted version: $key ($version)"
    fi
done

echo "Deleting delete markers..."

# Delete delete markers
aws s3api list-object-versions --bucket "$BUCKET_NAME" --output json 2>/dev/null | \
jq -r '.DeleteMarkers[]? | .Key + " " + .VersionId' | \
while read key version; do
    if [ -n "$key" ] && [ -n "$version" ]; then
        aws s3api delete-object --bucket "$BUCKET_NAME" --key "$key" --version-id "$version" 2>/dev/null
        echo "  Deleted marker: $key ($version)"
    fi
done

echo "Deleting bucket..."

# Delete the bucket
if aws s3 rb "s3://$BUCKET_NAME" 2>/dev/null; then
    echo -e "${GREEN}Successfully deleted bucket: $BUCKET_NAME${NC}"
else
    echo -e "${RED}Failed to delete bucket. It may have remaining objects.${NC}"
    echo "Try: aws s3 rb s3://$BUCKET_NAME --force"
fi

echo ""
echo "Cleanup complete!"
