#!/bin/bash

# Lab 03: Generate Sample GuardDuty Findings

echo ""
echo "=============================================="
echo "  Generate Sample GuardDuty Findings"
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
    echo "Run first: bash lab-03-guardduty-security-hub/scripts/enable-detection.sh"
    exit 1
fi

echo "Detector: $GD_DETECTOR_ID"
echo ""

# ============================================================
# Generate sample findings
# ============================================================
echo -e "${BLUE}Generating sample findings...${NC}"
echo ""
echo "  This creates SAMPLE findings (not real threats) for learning."
echo "  Sample findings are clearly marked as '[SAMPLE]' in GuardDuty."
echo ""

aws guardduty create-sample-findings --detector-id "$GD_DETECTOR_ID" 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Sample findings generated.${NC}"
else
    echo -e "${RED}Failed to generate sample findings.${NC}"
    exit 1
fi

echo ""
echo "  Waiting 10 seconds for findings to populate..."
sleep 10
echo ""

# ============================================================
# Display findings summary
# ============================================================
echo -e "${BLUE}Sample findings by severity:${NC}"
echo ""

# Get HIGH severity findings
echo -e "${RED}HIGH SEVERITY:${NC}"
aws guardduty list-findings --detector-id "$GD_DETECTOR_ID" \
    --finding-criteria '{"Criterion":{"severity":{"Gte":7},"service.additionalInfo.sample":{"Eq":["true"]}}}' \
    --query 'FindingIds' --output text 2>/dev/null | tr '\t' '\n' | head -5 | while read -r finding_id; do
    if [ -n "$finding_id" ] && [ "$finding_id" != "None" ]; then
        TYPE=$(aws guardduty get-findings --detector-id "$GD_DETECTOR_ID" --finding-ids "$finding_id" \
            --query 'Findings[0].Type' --output text 2>/dev/null)
        SEVERITY=$(aws guardduty get-findings --detector-id "$GD_DETECTOR_ID" --finding-ids "$finding_id" \
            --query 'Findings[0].Severity' --output text 2>/dev/null)
        echo "  - $TYPE (severity: $SEVERITY)"
    fi
done

echo ""
echo -e "${YELLOW}MEDIUM SEVERITY:${NC}"
aws guardduty list-findings --detector-id "$GD_DETECTOR_ID" \
    --finding-criteria '{"Criterion":{"severity":{"Gte":4,"Lt":7},"service.additionalInfo.sample":{"Eq":["true"]}}}' \
    --query 'FindingIds' --output text 2>/dev/null | tr '\t' '\n' | head -5 | while read -r finding_id; do
    if [ -n "$finding_id" ] && [ "$finding_id" != "None" ]; then
        TYPE=$(aws guardduty get-findings --detector-id "$GD_DETECTOR_ID" --finding-ids "$finding_id" \
            --query 'Findings[0].Type' --output text 2>/dev/null)
        SEVERITY=$(aws guardduty get-findings --detector-id "$GD_DETECTOR_ID" --finding-ids "$finding_id" \
            --query 'Findings[0].Severity' --output text 2>/dev/null)
        echo "  - $TYPE (severity: $SEVERITY)"
    fi
done

echo ""

# Total count
TOTAL_FINDINGS=$(aws guardduty list-findings --detector-id "$GD_DETECTOR_ID" \
    --finding-criteria '{"Criterion":{"service.additionalInfo.sample":{"Eq":["true"]}}}' \
    --query 'FindingIds | length(@)' --output text 2>/dev/null || echo "0")
echo "  Total sample findings: $TOTAL_FINDINGS"
echo ""

echo "=============================================="
echo "  WHAT THESE FINDINGS MEAN"
echo "=============================================="
echo ""
echo "  In a real environment, GuardDuty would generate these"
echo "  findings when it detects actual threats. Examples:"
echo ""
echo "  - Recon:EC2/PortProbeUnprotectedPort"
echo "    An EC2 instance has an unprotected port being probed"
echo ""
echo "  - UnauthorizedAccess:EC2/MaliciousIPCaller.Custom"
echo "    API calls from a known malicious IP address"
echo ""
echo "  - CryptoCurrency:EC2/BitcoinTool.B!DNS"
echo "    An EC2 instance is communicating with Bitcoin mining pools"
echo ""
echo "  Next step: bash lab-03-guardduty-security-hub/scripts/triage-exercise.sh"
echo ""
