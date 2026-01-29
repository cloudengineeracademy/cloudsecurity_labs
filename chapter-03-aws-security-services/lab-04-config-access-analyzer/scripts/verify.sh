#!/bin/bash

# Lab 04: Verify Config + Access Analyzer

echo ""
echo "=============================================="
echo "  VERIFY: Config + Access Analyzer"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=5

# Check 1: Config recorder running
echo -n "[1/$TOTAL_CHECKS] Config recorder running: "
CONFIG_STATUS=$(aws configservice describe-configuration-recorder-status \
    --query 'ConfigurationRecordersStatus[0].recording' --output text 2>/dev/null)
if [ "$CONFIG_STATUS" = "True" ]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC} — Not recording"
    ((FAIL_COUNT++))
fi

# Check 2: Config delivery channel
echo -n "[2/$TOTAL_CHECKS] Config delivery channel: "
CHANNEL=$(aws configservice describe-delivery-channels \
    --query 'DeliveryChannels[0].name' --output text 2>/dev/null)
if [ -n "$CHANNEL" ] && [ "$CHANNEL" != "None" ]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC} — No delivery channel"
    ((FAIL_COUNT++))
fi

# Check 3: Config rules >= 3
echo -n "[3/$TOTAL_CHECKS] Config rules (need 3+): "
RULE_COUNT=$(aws configservice describe-config-rules \
    --query 'ConfigRules | length(@)' --output text 2>/dev/null || echo "0")
if [ "$RULE_COUNT" -ge 3 ] 2>/dev/null; then
    echo -e "${GREEN}PASS${NC} ($RULE_COUNT rules)"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC} — Only $RULE_COUNT rules"
    ((FAIL_COUNT++))
fi

# Check 4: Access Analyzer active
echo -n "[4/$TOTAL_CHECKS] IAM Access Analyzer: "
ANALYZER_STATUS=$(aws accessanalyzer list-analyzers \
    --query 'analyzers[?status==`ACTIVE`] | length(@)' --output text 2>/dev/null || echo "0")
if [ "$ANALYZER_STATUS" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC} — No active analyzer"
    ((FAIL_COUNT++))
fi

# Check 5: Config S3 bucket exists
echo -n "[5/$TOTAL_CHECKS] Config S3 bucket: "
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
CONFIG_BUCKET="ch03-config-${ACCOUNT_ID}"
aws s3api head-bucket --bucket "$CONFIG_BUCKET" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS${NC} ($CONFIG_BUCKET)"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC} — Bucket not found"
    ((FAIL_COUNT++))
fi

# Summary
echo ""
echo "=============================================="
echo "  RESULTS: $PASS_COUNT/$TOTAL_CHECKS passed"
echo "=============================================="
echo ""

if [ "$PASS_COUNT" -eq "$TOTAL_CHECKS" ]; then
    echo -e "${GREEN}All checks passed. Compliance monitoring is active.${NC}"
    echo ""

    # Show badge
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    source "$SCRIPT_DIR/../../scripts/achievements.sh"
    show_badge "compliance"
else
    echo -e "${RED}$FAIL_COUNT check(s) failed. Run enable-compliance.sh first.${NC}"
fi

echo ""
