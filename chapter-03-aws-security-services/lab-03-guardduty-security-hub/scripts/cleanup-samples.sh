#!/bin/bash

# Lab 03: Clean Up Sample GuardDuty Findings
# Archives all sample findings so they don't clutter your dashboard

echo ""
echo "=============================================="
echo "  Clean Up Sample GuardDuty Findings"
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

# Get detector ID
GD_DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text 2>/dev/null)
if [ -z "$GD_DETECTOR_ID" ] || [ "$GD_DETECTOR_ID" = "None" ]; then
    echo -e "${RED}ERROR: GuardDuty not enabled.${NC}"
    exit 1
fi

echo "Detector: $GD_DETECTOR_ID"
echo ""

# Count sample findings first
SAMPLE_COUNT=$(aws guardduty list-findings --detector-id "$GD_DETECTOR_ID" \
    --finding-criteria '{"Criterion":{"service.additionalInfo.sample":{"Eq":["true"]}}}' \
    --query 'FindingIds | length(@)' --output text 2>/dev/null || echo "0")

echo "  Found $SAMPLE_COUNT sample findings to archive."
echo ""

if [ "$SAMPLE_COUNT" = "0" ]; then
    echo -e "${GREEN}No sample findings to clean up.${NC}"
    echo ""
    exit 0
fi

echo -e "${BLUE}Archiving sample findings...${NC}"
echo "  (This only removes SAMPLE findings. Real findings are untouched.)"
echo ""

# Archive in batches of 50 (API limit)
ARCHIVED=0
while true; do
    FINDING_IDS=$(aws guardduty list-findings --detector-id "$GD_DETECTOR_ID" \
        --finding-criteria '{"Criterion":{"service.additionalInfo.sample":{"Eq":["true"]}}}' \
        --max-results 50 \
        --query 'FindingIds' --output json 2>/dev/null)

    # Check if we got any findings
    COUNT=$(echo "$FINDING_IDS" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

    if [ "$COUNT" = "0" ] || [ "$COUNT" = "" ]; then
        break
    fi

    # Archive this batch
    aws guardduty archive-findings --detector-id "$GD_DETECTOR_ID" \
        --finding-ids $(echo "$FINDING_IDS" | python3 -c "import sys,json; print(' '.join(json.load(sys.stdin)))" 2>/dev/null) \
        2>/dev/null

    ARCHIVED=$((ARCHIVED + COUNT))
    echo "  Archived $ARCHIVED findings..."
done

echo ""
echo -e "${GREEN}Done. Archived $ARCHIVED sample findings.${NC}"
echo ""
echo "  These findings are now hidden from your GuardDuty and Security Hub dashboards."
echo "  Archived findings can still be viewed with the 'Archived' filter if needed."
echo ""
