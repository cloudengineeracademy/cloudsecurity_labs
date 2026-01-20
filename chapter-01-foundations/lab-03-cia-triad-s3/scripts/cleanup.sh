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

# Delete all versions (no jq required)
aws s3api list-object-versions --bucket "$BUCKET_NAME" --query 'Versions[].{Key:Key,VersionId:VersionId}' --output text 2>/dev/null | \
while read key version; do
    if [ -n "$key" ] && [ "$key" != "None" ] && [ -n "$version" ] && [ "$version" != "None" ]; then
        if aws s3api delete-object --bucket "$BUCKET_NAME" --key "$key" --version-id "$version" 2>/dev/null; then
            echo "  Deleted version: $key ($version)"
        fi
    fi
done

echo "Deleting delete markers..."

# Delete delete markers (no jq required)
aws s3api list-object-versions --bucket "$BUCKET_NAME" --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' --output text 2>/dev/null | \
while read key version; do
    if [ -n "$key" ] && [ "$key" != "None" ] && [ -n "$version" ] && [ "$version" != "None" ]; then
        if aws s3api delete-object --bucket "$BUCKET_NAME" --key "$key" --version-id "$version" 2>/dev/null; then
            echo "  Deleted marker: $key ($version)"
        fi
    fi
done

echo "Deleting bucket..."

# Delete the bucket
if aws s3 rb "s3://$BUCKET_NAME" 2>/dev/null; then
    echo -e "${GREEN}Successfully deleted bucket: $BUCKET_NAME${NC}"
else
    echo -e "${RED}Failed to delete bucket. Trying force delete...${NC}"
    if aws s3 rb "s3://$BUCKET_NAME" --force 2>/dev/null; then
        echo -e "${GREEN}Successfully force-deleted bucket: $BUCKET_NAME${NC}"
    else
        echo -e "${RED}Could not delete bucket. Try manually in AWS Console.${NC}"
    fi
fi

echo ""
echo "Cleanup complete!"
