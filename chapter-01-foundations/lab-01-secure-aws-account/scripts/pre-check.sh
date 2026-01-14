#!/bin/bash

# Pre-Check Script for Lab 01: Secure AWS Account
# This script shows your current security status BEFORE making changes

echo "=============================================="
echo "  AWS Account Security Pre-Check"
echo "=============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get account info
echo "Getting account information..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
USER_ARN=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi

echo "Account ID: $ACCOUNT_ID"
echo "User ARN: $USER_ARN"
echo ""

echo "----------------------------------------------"
echo "SECURITY CHECK RESULTS"
echo "----------------------------------------------"
echo ""

# Check 1: Root Access Keys
echo -n "1. Root Access Keys: "
ROOT_KEYS=$(aws iam get-account-summary --query 'SummaryMap.AccountAccessKeysPresent' --output text 2>/dev/null)
if [ "$ROOT_KEYS" = "0" ]; then
    echo -e "${GREEN}PASS${NC} - No root access keys exist"
else
    echo -e "${RED}FAIL${NC} - Root has $ROOT_KEYS access key(s) - DELETE IMMEDIATELY"
fi

# Check 2: MFA on Current User
echo -n "2. Your MFA Status: "
MFA_DEVICES=$(aws iam list-mfa-devices --query 'MFADevices' --output text 2>/dev/null)
if [ -n "$MFA_DEVICES" ]; then
    echo -e "${GREEN}PASS${NC} - MFA is enabled"
else
    echo -e "${RED}FAIL${NC} - MFA is NOT enabled on your user"
fi

# Check 3: Password Policy
echo -n "3. Password Policy: "
PASSWORD_POLICY=$(aws iam get-account-password-policy 2>/dev/null)
if [ $? -eq 0 ]; then
    MIN_LENGTH=$(echo "$PASSWORD_POLICY" | grep -o '"MinimumPasswordLength": [0-9]*' | grep -o '[0-9]*')
    if [ "$MIN_LENGTH" -ge 14 ]; then
        echo -e "${GREEN}PASS${NC} - Policy exists (min length: $MIN_LENGTH)"
    else
        echo -e "${YELLOW}WARN${NC} - Policy exists but min length is only $MIN_LENGTH (should be 14+)"
    fi
else
    echo -e "${RED}FAIL${NC} - No password policy configured"
fi

# Check 4: S3 Block Public Access
echo -n "4. S3 Block Public Access: "
S3_BLOCK=$(aws s3control get-public-access-block --account-id "$ACCOUNT_ID" 2>/dev/null)
if [ $? -eq 0 ]; then
    BLOCK_ALL=$(echo "$S3_BLOCK" | grep -c "true")
    if [ "$BLOCK_ALL" -eq 4 ]; then
        echo -e "${GREEN}PASS${NC} - All public access blocked"
    else
        echo -e "${YELLOW}WARN${NC} - Partially configured"
    fi
else
    echo -e "${RED}FAIL${NC} - Not configured"
fi

# Check 5: Number of IAM Users
echo -n "5. IAM Users: "
USER_COUNT=$(aws iam list-users --query 'Users | length(@)' --output text 2>/dev/null)
echo -e "${NC}INFO - $USER_COUNT IAM user(s) exist"

# Check 6: Users Without MFA
echo -n "6. Users Without MFA: "
# This requires credential report, which may not be immediately available
USERS_NO_MFA=0
for user in $(aws iam list-users --query 'Users[].UserName' --output text 2>/dev/null); do
    USER_MFA=$(aws iam list-mfa-devices --user-name "$user" --query 'MFADevices' --output text 2>/dev/null)
    if [ -z "$USER_MFA" ]; then
        ((USERS_NO_MFA++))
    fi
done
if [ "$USERS_NO_MFA" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC} - All users have MFA"
else
    echo -e "${YELLOW}WARN${NC} - $USERS_NO_MFA user(s) without MFA"
fi

echo ""
echo "----------------------------------------------"
echo "SUMMARY"
echo "----------------------------------------------"
echo ""
echo "Review any FAIL or WARN items above."
echo "Follow the lab instructions to fix them."
echo ""
