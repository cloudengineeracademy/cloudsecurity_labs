#!/bin/bash

# Lab 03: Enable GuardDuty + Security Hub

echo ""
echo "=============================================="
echo "  Enable Detection Services"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    exit 1
fi

echo "Account: $ACCOUNT_ID"
echo "Region:  $REGION"
echo ""

# ============================================================
# Step 1: Enable GuardDuty
# ============================================================
echo -e "${BLUE}Step 1: Enabling GuardDuty...${NC}"

GD_DETECTORS=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text 2>/dev/null)
if [ -n "$GD_DETECTORS" ] && [ "$GD_DETECTORS" != "None" ] && [ "$GD_DETECTORS" != "" ]; then
    echo -e "${YELLOW}GuardDuty already enabled. Detector: $GD_DETECTORS${NC}"
    GD_DETECTOR_ID="$GD_DETECTORS"
else
    GD_DETECTOR_ID=$(aws guardduty create-detector --enable \
        --finding-publishing-frequency FIFTEEN_MINUTES \
        --query 'DetectorId' --output text 2>/dev/null)

    if [ -z "$GD_DETECTOR_ID" ] || [ "$GD_DETECTOR_ID" = "None" ]; then
        echo -e "${RED}ERROR: Failed to enable GuardDuty${NC}"
        exit 1
    fi
    echo -e "${GREEN}GuardDuty enabled. Detector: $GD_DETECTOR_ID${NC}"
fi

echo ""
echo "  GuardDuty will now analyze:"
echo "    - CloudTrail management events"
echo "    - VPC Flow Logs (automatically)"
echo "    - DNS query logs (automatically)"
echo ""

# ============================================================
# Step 2: Enable Security Hub
# ============================================================
echo -e "${BLUE}Step 2: Enabling Security Hub...${NC}"

SH_STATUS=$(aws securityhub describe-hub --query 'HubArn' --output text 2>/dev/null)
if [ -n "$SH_STATUS" ] && [ "$SH_STATUS" != "None" ]; then
    echo -e "${YELLOW}Security Hub already enabled.${NC}"
else
    aws securityhub enable-security-hub \
        --enable-default-standards 2>/dev/null

    if [ $? -ne 0 ]; then
        echo -e "${RED}ERROR: Failed to enable Security Hub${NC}"
        echo "  This may require the correct IAM permissions."
        exit 1
    fi
    echo -e "${GREEN}Security Hub enabled with default standards.${NC}"
fi

echo ""

# ============================================================
# Step 3: Verify Standards
# ============================================================
echo -e "${BLUE}Step 3: Checking enabled standards...${NC}"
echo ""

STANDARDS=$(aws securityhub get-enabled-standards \
    --query 'StandardsSubscriptions[].{Standard:StandardsArn,Status:StandardsStatus}' \
    --output table 2>/dev/null)

if [ -n "$STANDARDS" ]; then
    echo "$STANDARDS"
else
    echo "  No standards found yet. They may take a moment to activate."
    echo "  The AWS Foundational Security Best Practices standard should enable automatically."
fi

echo ""

# ============================================================
# Summary
# ============================================================
echo "=============================================="
echo "  DETECTION SERVICES ENABLED"
echo "=============================================="
echo ""
echo "  GuardDuty:"
echo "    - Detector ID: $GD_DETECTOR_ID"
echo "    - Analyzes: CloudTrail, VPC Flow Logs, DNS"
echo "    - Publishing: Every 15 minutes"
echo ""
echo "  Security Hub:"
echo "    - Aggregates findings from GuardDuty + Config"
echo "    - AWS Foundational Best Practices standard enabled"
echo "    - Automated compliance scoring"
echo ""
echo "  Next steps:"
echo "    1. Generate findings: bash lab-03-guardduty-security-hub/scripts/generate-findings.sh"
echo "    2. Triage exercise: bash lab-03-guardduty-security-hub/scripts/triage-exercise.sh"
echo "    3. Verify: bash lab-03-guardduty-security-hub/scripts/verify.sh"
echo ""
