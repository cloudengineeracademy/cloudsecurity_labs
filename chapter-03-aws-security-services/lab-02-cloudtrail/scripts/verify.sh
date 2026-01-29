#!/bin/bash

# Lab 02: Verify CloudTrail Configuration

echo ""
echo "=============================================="
echo "  VERIFY: CloudTrail Configuration"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
TRAIL_NAME="ch03-security-trail"
BUCKET_NAME="ch03-cloudtrail-${ACCOUNT_ID}"
KEY_ALIAS="alias/ch03-cloudtrail-key"

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=7

# Check 1: KMS key exists
echo -n "[1/$TOTAL_CHECKS] KMS customer-managed key: "
KMS_KEY_ID=$(aws kms describe-key --key-id "$KEY_ALIAS" --query 'KeyMetadata.KeyId' --output text 2>/dev/null)
if [ -n "$KMS_KEY_ID" ] && [ "$KMS_KEY_ID" != "None" ]; then
    echo -e "${GREEN}PASS${NC} ($KMS_KEY_ID)"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC} — Key not found"
    ((FAIL_COUNT++))
fi

# Check 2: S3 bucket exists
echo -n "[2/$TOTAL_CHECKS] S3 bucket exists: "
aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS${NC} ($BUCKET_NAME)"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC} — Bucket not found"
    ((FAIL_COUNT++))
fi

# Check 3: S3 bucket encryption
echo -n "[3/$TOTAL_CHECKS] Bucket encryption (KMS): "
BUCKET_ENC=$(aws s3api get-bucket-encryption --bucket "$BUCKET_NAME" --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' --output text 2>/dev/null)
if [ "$BUCKET_ENC" = "aws:kms" ]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC} — Expected aws:kms, got: ${BUCKET_ENC:-none}"
    ((FAIL_COUNT++))
fi

# Check 4: Trail exists
echo -n "[4/$TOTAL_CHECKS] CloudTrail trail exists: "
TRAIL_EXISTS=$(aws cloudtrail describe-trails --trail-name-list "$TRAIL_NAME" --query 'trailList[0].Name' --output text 2>/dev/null)
if [ "$TRAIL_EXISTS" = "$TRAIL_NAME" ]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC} — Trail not found"
    ((FAIL_COUNT++))
fi

# Check 5: Multi-region
echo -n "[5/$TOTAL_CHECKS] Multi-region trail: "
MULTI_REGION=$(aws cloudtrail describe-trails --trail-name-list "$TRAIL_NAME" --query 'trailList[0].IsMultiRegionTrail' --output text 2>/dev/null)
if [ "$MULTI_REGION" = "True" ]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC} — Not multi-region"
    ((FAIL_COUNT++))
fi

# Check 6: Log file validation
echo -n "[6/$TOTAL_CHECKS] Log file validation: "
LOG_VAL=$(aws cloudtrail describe-trails --trail-name-list "$TRAIL_NAME" --query 'trailList[0].LogFileValidationEnabled' --output text 2>/dev/null)
if [ "$LOG_VAL" = "True" ]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC} — Validation not enabled"
    ((FAIL_COUNT++))
fi

# Check 7: Logging active
echo -n "[7/$TOTAL_CHECKS] Trail is logging: "
IS_LOGGING=$(aws cloudtrail get-trail-status --name "$TRAIL_NAME" --query 'IsLogging' --output text 2>/dev/null)
if [ "$IS_LOGGING" = "True" ]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC} — Not logging"
    ((FAIL_COUNT++))
fi

# Summary
echo ""
echo "=============================================="
echo "  RESULTS: $PASS_COUNT/$TOTAL_CHECKS passed"
echo "=============================================="
echo ""

if [ "$PASS_COUNT" -eq "$TOTAL_CHECKS" ]; then
    echo -e "${GREEN}All checks passed. CloudTrail is properly configured.${NC}"
    echo ""

    # Show badge
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    source "$SCRIPT_DIR/../../scripts/achievements.sh"
    show_badge "cloudtrail"
else
    echo -e "${RED}$FAIL_COUNT check(s) failed. Review the output above and re-run setup.${NC}"
fi

echo ""
