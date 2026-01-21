#!/bin/bash

# Lab 02: Verify IMDSv2 Fix
# Confirms that the SSRF attack is blocked after enabling IMDSv2

echo ""
echo "=============================================="
echo "  VERIFY IMDSv2 FIX"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if stack exists
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name lab02-ssrf-attack --query 'Stacks[0].StackStatus' --output text 2>/dev/null)
if [ -z "$STACK_STATUS" ] || [ "$STACK_STATUS" = "None" ]; then
    echo -e "${RED}ERROR: Stack 'lab02-ssrf-attack' not found.${NC}"
    exit 1
fi

# Get instance details
INSTANCE_ID=$(aws cloudformation describe-stacks \
    --stack-name lab02-ssrf-attack \
    --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' \
    --output text)

EC2_IP=$(aws cloudformation describe-stacks \
    --stack-name lab02-ssrf-attack \
    --query 'Stacks[0].Outputs[?OutputKey==`InstancePublicIp`].OutputValue' \
    --output text)

echo "Instance ID: $INSTANCE_ID"
echo "Instance IP: $EC2_IP"
echo ""

# Check 1: IMDS Configuration
echo "----------------------------------------------"
echo -e "${BLUE}[Check 1] IMDS Configuration${NC}"
echo "----------------------------------------------"
echo ""

IMDS_STATUS=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].MetadataOptions.HttpTokens' \
    --output text 2>/dev/null)

echo -n "HttpTokens setting: "
if [ "$IMDS_STATUS" = "required" ]; then
    echo -e "${GREEN}required (IMDSv2 enforced)${NC}"
    IMDS_PASS=true
else
    echo -e "${RED}optional (IMDSv1 still enabled!)${NC}"
    IMDS_PASS=false
fi
echo ""

# Check 2: SSRF to metadata blocked
echo "----------------------------------------------"
echo -e "${BLUE}[Check 2] SSRF Attack Test${NC}"
echo "----------------------------------------------"
echo ""

echo "Attempting SSRF to metadata service..."
SSRF_RESULT=$(curl -s "http://$EC2_IP/fetch?url=http://169.254.169.254/latest/meta-data/" 2>/dev/null)

echo -n "Metadata access via SSRF: "
if [[ "$SSRF_RESULT" == *"ami-id"* ]] || [[ "$SSRF_RESULT" == *"hostname"* ]]; then
    echo -e "${RED}ACCESSIBLE (attack still works!)${NC}"
    SSRF_PASS=false
    echo ""
    echo "Response received:"
    echo "$SSRF_RESULT" | head -5
else
    echo -e "${GREEN}BLOCKED${NC}"
    SSRF_PASS=true
    echo ""
    echo "Response: $SSRF_RESULT"
fi
echo ""

# Check 3: Credential extraction blocked
echo "----------------------------------------------"
echo -e "${BLUE}[Check 3] Credential Extraction Test${NC}"
echo "----------------------------------------------"
echo ""

echo "Attempting to get IAM credentials via SSRF..."
CRED_RESULT=$(curl -s "http://$EC2_IP/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/" 2>/dev/null)

echo -n "Credential extraction via SSRF: "
if [[ "$CRED_RESULT" == *"lab02"* ]] || [[ "$CRED_RESULT" == *"role"* ]]; then
    echo -e "${RED}ACCESSIBLE (credentials exposed!)${NC}"
    CRED_PASS=false
else
    echo -e "${GREEN}BLOCKED${NC}"
    CRED_PASS=true
fi
echo ""

# Summary
echo "=============================================="
echo "  VERIFICATION RESULTS"
echo "=============================================="
echo ""

TOTAL_PASS=0
TOTAL_CHECKS=3

if [ "$IMDS_PASS" = true ]; then
    echo -e "${GREEN}[PASS]${NC} IMDSv2 is required"
    ((TOTAL_PASS++))
else
    echo -e "${RED}[FAIL]${NC} IMDSv2 is NOT required"
    echo "       Fix: aws ec2 modify-instance-metadata-options \\"
    echo "              --instance-id $INSTANCE_ID --http-tokens required"
fi

if [ "$SSRF_PASS" = true ]; then
    echo -e "${GREEN}[PASS]${NC} Metadata access blocked via SSRF"
    ((TOTAL_PASS++))
else
    echo -e "${RED}[FAIL]${NC} Metadata still accessible via SSRF"
fi

if [ "$CRED_PASS" = true ]; then
    echo -e "${GREEN}[PASS]${NC} Credential extraction blocked"
    ((TOTAL_PASS++))
else
    echo -e "${RED}[FAIL]${NC} Credentials still extractable via SSRF"
fi

echo ""

if [ $TOTAL_PASS -eq $TOTAL_CHECKS ]; then
    echo -e "${GREEN}All checks passed! The Capital One attack pattern is blocked.${NC}"
    echo ""
    echo "The fix works because:"
    echo "  - IMDSv2 requires a session token from a PUT request"
    echo "  - SSRF vulnerabilities typically can only make GET requests"
    echo "  - Without the token, metadata requests return 401 Unauthorized"
    echo ""
    echo "Run ./scripts/cleanup.sh when you're done."
else
    echo -e "${RED}Some checks failed. The system is still vulnerable.${NC}"
    echo ""
    echo "To fix, run:"
    echo ""
    echo "  aws ec2 modify-instance-metadata-options \\"
    echo "    --instance-id $INSTANCE_ID \\"
    echo "    --http-tokens required \\"
    echo "    --http-endpoint enabled"
    echo ""
    echo "Then run this script again."
fi

echo ""
echo "=============================================="
