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

GENERATE_OUTPUT=$(aws guardduty create-sample-findings --detector-id "$GD_DETECTOR_ID" 2>&1)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Sample findings generated.${NC}"
else
    echo -e "${RED}Failed to generate sample findings.${NC}"
    echo "  Error: $GENERATE_OUTPUT"
    echo ""
    echo "  Troubleshooting:"
    echo "    - Check your detector ID: aws guardduty list-detectors"
    echo "    - Check your region: aws configure get region"
    echo "    - Check permissions: your IAM user needs guardduty:CreateSampleFindings"
    exit 1
fi

echo ""
echo "  Waiting 30 seconds for findings to populate..."
echo "  (AWS needs time to create findings across all protection plans)"
sleep 30
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

if [ "$TOTAL_FINDINGS" = "0" ]; then
    echo -e "${YELLOW}  No findings returned yet. This can happen if AWS needs more time.${NC}"
    echo "  Wait 60 seconds and run this command to check:"
    echo ""
    echo "  aws guardduty list-findings --detector-id $GD_DETECTOR_ID \\"
    echo "      --finding-criteria '{\"Criterion\":{\"service.additionalInfo.sample\":{\"Eq\":[\"true\"]}}}' \\"
    echo "      --query 'FindingIds | length(@)' --output text"
    echo ""
fi

echo "=============================================="
echo "  WHAT THESE FINDINGS MEAN"
echo "=============================================="
echo ""
echo "  AWS generates sample findings across ALL GuardDuty protection"
echo "  plans: EC2, S3, EKS, ECS, Lambda, IAM, Malware, and more."
echo "  Seeing hundreds of findings is NORMAL and expected."
echo ""
echo "  These are FAKE findings with placeholder resources like:"
echo "    - i-99999999 (fake EC2 instance)"
echo "    - GeneratedFindingContainerId (fake container)"
echo "    - GeneratedFindingEKSClusterName (fake EKS cluster)"
echo ""
echo -e "  ${GREEN}Sample findings are completely FREE. No cost.${NC}"
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
echo "  Next steps:"
echo "    1. Triage exercise: bash lab-03-guardduty-security-hub/scripts/triage-exercise.sh"
echo "    2. Clean up samples: bash lab-03-guardduty-security-hub/scripts/cleanup-samples.sh"
echo ""
