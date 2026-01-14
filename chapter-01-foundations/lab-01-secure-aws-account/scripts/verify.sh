#!/bin/bash

# Verification Script for Lab 01: Secure AWS Account
# Run this AFTER completing the lab to verify your work

echo "=============================================="
echo "  AWS Account Security Verification"
echo "=============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=4

# Get account info
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    exit 1
fi

echo "Verifying account: $ACCOUNT_ID"
echo ""
echo "----------------------------------------------"
echo "VERIFICATION RESULTS"
echo "----------------------------------------------"
echo ""

# Check 1: Root Access Keys (should be 0)
echo -n "[1/4] Root Access Keys: "
ROOT_KEYS=$(aws iam get-account-summary --query 'SummaryMap.AccountAccessKeysPresent' --output text 2>/dev/null)
if [ "$ROOT_KEYS" = "0" ]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC} - Delete root access keys in console"
    ((FAIL_COUNT++))
fi

# Check 2: Current User MFA
echo -n "[2/4] Your MFA Enabled: "
MFA_DEVICES=$(aws iam list-mfa-devices --query 'MFADevices[0].SerialNumber' --output text 2>/dev/null)
if [ -n "$MFA_DEVICES" ] && [ "$MFA_DEVICES" != "None" ]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC} - Enable MFA on your IAM user"
    ((FAIL_COUNT++))
fi

# Check 3: Password Policy
echo -n "[3/4] Password Policy: "
MIN_LENGTH=$(aws iam get-account-password-policy --query 'PasswordPolicy.MinimumPasswordLength' --output text 2>/dev/null)
if [ -n "$MIN_LENGTH" ] && [ "$MIN_LENGTH" -ge 14 ]; then
    echo -e "${GREEN}PASS${NC} (min length: $MIN_LENGTH)"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC} - Configure password policy with 14+ char minimum"
    ((FAIL_COUNT++))
fi

# Check 4: S3 Block Public Access
echo -n "[4/4] S3 Block Public Access: "
BLOCK_PUBLIC=$(aws s3control get-public-access-block --account-id "$ACCOUNT_ID" \
    --query 'PublicAccessBlockConfiguration.BlockPublicAcls' --output text 2>/dev/null)
if [ "$BLOCK_PUBLIC" = "True" ]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS_COUNT++))
else
    echo -e "${RED}FAIL${NC} - Enable S3 Block Public Access"
    ((FAIL_COUNT++))
fi

echo ""
echo "----------------------------------------------"
echo "FINAL SCORE: $PASS_COUNT / $TOTAL_CHECKS passed"
echo "----------------------------------------------"
echo ""

if [ "$PASS_COUNT" -eq "$TOTAL_CHECKS" ]; then
    echo -e "${GREEN}Congratulations! You've completed Lab 01!${NC}"
    echo ""
    echo "Your AWS account now has:"
    echo "  - Protected root account (no access keys)"
    echo "  - MFA enabled on your user"
    echo "  - Strong password policy"
    echo "  - S3 public access blocked by default"
    echo ""
    echo "Next: Move on to Lab 02 - Attack Surface Reconnaissance"
else
    echo -e "${YELLOW}Almost there! Fix the FAIL items above and run this script again.${NC}"
fi
echo ""
