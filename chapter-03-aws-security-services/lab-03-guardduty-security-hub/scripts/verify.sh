#!/bin/bash

# Lab 03: Verify GuardDuty + Security Hub

echo ""
echo "=============================================="
echo "  VERIFY: GuardDuty + Security Hub"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=4

# Check 1: GuardDuty detector exists
echo -n "[1/$TOTAL_CHECKS] GuardDuty detector exists: "
GD_DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text 2>/dev/null)
if [ -n "$GD_DETECTOR_ID" ] && [ "$GD_DETECTOR_ID" != "None" ] && [ "$GD_DETECTOR_ID" != "" ]; then
    echo -e "${GREEN}PASS${NC} ($GD_DETECTOR_ID)"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC} — No detector found"
    ((FAIL_COUNT++))
fi

# Check 2: GuardDuty enabled
echo -n "[2/$TOTAL_CHECKS] GuardDuty status ENABLED: "
if [ -n "$GD_DETECTOR_ID" ] && [ "$GD_DETECTOR_ID" != "None" ] && [ "$GD_DETECTOR_ID" != "" ]; then
    GD_STATUS=$(aws guardduty get-detector --detector-id "$GD_DETECTOR_ID" --query 'Status' --output text 2>/dev/null)
    if [ "$GD_STATUS" = "ENABLED" ]; then
        echo -e "${GREEN}PASS${NC}"
        ((PASS_COUNT++))
    else
        echo -e "${RED}FAIL${NC} — Status: $GD_STATUS"
        ((FAIL_COUNT++))
    fi
else
    echo -e "${RED}FAIL${NC} — No detector"
    ((FAIL_COUNT++))
fi

# Check 3: Security Hub enabled
echo -n "[3/$TOTAL_CHECKS] Security Hub enabled: "
SH_ARN=$(aws securityhub describe-hub --query 'HubArn' --output text 2>/dev/null)
if [ -n "$SH_ARN" ] && [ "$SH_ARN" != "None" ]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC} — Not enabled"
    ((FAIL_COUNT++))
fi

# Check 4: Security Hub standards
echo -n "[4/$TOTAL_CHECKS] Security Hub standards enabled: "
STANDARDS_COUNT=$(aws securityhub get-enabled-standards --query 'StandardsSubscriptions | length(@)' --output text 2>/dev/null || echo "0")
if [ "$STANDARDS_COUNT" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}PASS${NC} ($STANDARDS_COUNT standard(s))"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC} — No standards enabled"
    ((FAIL_COUNT++))
fi

# Summary
echo ""
echo "=============================================="
echo "  RESULTS: $PASS_COUNT/$TOTAL_CHECKS passed"
echo "=============================================="
echo ""

if [ "$PASS_COUNT" -eq "$TOTAL_CHECKS" ]; then
    echo -e "${GREEN}All checks passed. Detection services are active.${NC}"
    echo ""

    # Show badge
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    source "$SCRIPT_DIR/../../scripts/achievements.sh"
    show_badge "guardduty"
else
    echo -e "${RED}$FAIL_COUNT check(s) failed. Run enable-detection.sh first.${NC}"
fi

echo ""
