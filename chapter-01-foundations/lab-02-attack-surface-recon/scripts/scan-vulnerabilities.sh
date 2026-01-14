#!/bin/bash

# Lab 02: Vulnerability Scanner
# Scans the deployed infrastructure for security issues

echo ""
echo "=============================================="
echo "  VULNERABILITY SCAN - Lab 02 Infrastructure"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
CRITICAL=0
HIGH=0
MEDIUM=0
PASSED=0

# Check if stack exists
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name lab02-vulnerable-infra --query 'Stacks[0].StackStatus' --output text 2>/dev/null)
if [ -z "$STACK_STATUS" ] || [ "$STACK_STATUS" = "None" ]; then
    echo -e "${RED}ERROR: Stack 'lab02-vulnerable-infra' not found.${NC}"
    echo "Deploy it first with: aws cloudformation create-stack ..."
    exit 1
fi

if [ "$STACK_STATUS" != "CREATE_COMPLETE" ] && [ "$STACK_STATUS" != "UPDATE_COMPLETE" ]; then
    echo -e "${YELLOW}WARNING: Stack status is $STACK_STATUS - wait for CREATE_COMPLETE${NC}"
    exit 1
fi

echo "Scanning resources..."
echo ""

echo "----------------------------------------------"
echo -e "${BLUE}[1/4] IDENTITY${NC}"
echo "----------------------------------------------"

# Check IAM User MFA
echo -n "IAM User MFA: "
MFA=$(aws iam list-mfa-devices --user-name lab02-insecure-user --query 'MFADevices[0]' --output text 2>/dev/null)
if [ -z "$MFA" ] || [ "$MFA" = "None" ]; then
    echo -e "${RED}[HIGH] NO MFA ENABLED${NC}"
    echo "        └─ User 'lab02-insecure-user' has no MFA protection"
    echo "        └─ Risk: Password-only authentication can be brute-forced or phished"
    ((HIGH++))
else
    echo -e "${GREEN}[PASS] MFA enabled${NC}"
    ((PASSED++))
fi

# Check Access Keys
echo -n "IAM Access Keys: "
KEY_COUNT=$(aws iam list-access-keys --user-name lab02-insecure-user --query 'AccessKeyMetadata | length(@)' --output text 2>/dev/null)
if [ "$KEY_COUNT" -gt 0 ]; then
    echo -e "${RED}[HIGH] ACCESS KEY EXISTS${NC}"
    echo "        └─ User has $KEY_COUNT active access key(s)"
    echo "        └─ Risk: Long-lived credentials can leak via code repos, logs, or breaches"
    ((HIGH++))
else
    echo -e "${GREEN}[PASS] No access keys${NC}"
    ((PASSED++))
fi

echo ""
echo "----------------------------------------------"
echo -e "${BLUE}[2/4] NETWORK${NC}"
echo "----------------------------------------------"

# Check Security Group
echo -n "Security Group SSH: "
SSH_OPEN=$(aws ec2 describe-security-groups --group-names lab02-insecure-sg \
    --query 'SecurityGroups[0].IpPermissions[?FromPort==`22` && IpRanges[?CidrIp==`0.0.0.0/0`]]' \
    --output text 2>/dev/null)

if [ -n "$SSH_OPEN" ]; then
    echo -e "${RED}[CRITICAL] SSH OPEN TO INTERNET${NC}"
    echo "        └─ Port 22 accessible from 0.0.0.0/0 (entire internet)"
    echo "        └─ Risk: Attackers can brute-force SSH or exploit vulnerabilities"
    ((CRITICAL++))
else
    echo -e "${GREEN}[PASS] SSH not exposed to internet${NC}"
    ((PASSED++))
fi

echo ""
echo "----------------------------------------------"
echo -e "${BLUE}[3/4] DATA${NC}"
echo "----------------------------------------------"

BUCKET=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `lab02`)].Name' --output text 2>/dev/null)

if [ -z "$BUCKET" ]; then
    echo -e "${YELLOW}No lab02 bucket found${NC}"
else
    # Check Public Access Block
    echo -n "S3 Public Access Block: "
    PUBLIC_BLOCK=$(aws s3api get-public-access-block --bucket "$BUCKET" 2>&1)
    if echo "$PUBLIC_BLOCK" | grep -q "NoSuchPublicAccessBlockConfiguration"; then
        echo -e "${RED}[HIGH] NO PUBLIC ACCESS BLOCK${NC}"
        echo "        └─ Bucket '$BUCKET' has no public access protection"
        echo "        └─ Risk: Bucket could be made public by misconfigured policy"
        ((HIGH++))
    else
        echo -e "${GREEN}[PASS] Public access blocked${NC}"
        ((PASSED++))
    fi

    # Check Encryption
    echo -n "S3 Encryption: "
    ENCRYPTION=$(aws s3api get-bucket-encryption --bucket "$BUCKET" 2>&1)
    if echo "$ENCRYPTION" | grep -q "ServerSideEncryptionConfigurationNotFoundError"; then
        echo -e "${YELLOW}[MEDIUM] NOT ENCRYPTED${NC}"
        echo "        └─ Bucket '$BUCKET' does not have default encryption"
        echo "        └─ Risk: Data at rest is unprotected if storage is compromised"
        ((MEDIUM++))
    else
        echo -e "${GREEN}[PASS] Encryption enabled${NC}"
        ((PASSED++))
    fi
fi

echo ""
echo "----------------------------------------------"
echo -e "${BLUE}[4/4] COMPUTE${NC}"
echo "----------------------------------------------"

# Check IMDS Version
echo -n "EC2 IMDS Version: "
IMDS=$(aws ec2 describe-instances \
    --filters "Name=tag:Lab,Values=cloud-security-lab-02" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].MetadataOptions.HttpTokens' \
    --output text 2>/dev/null)

if [ "$IMDS" = "optional" ]; then
    echo -e "${RED}[HIGH] IMDSv1 ENABLED (SSRF VULNERABLE)${NC}"
    echo "        └─ Instance allows IMDSv1 (HttpTokens: optional)"
    echo "        └─ Risk: SSRF attacks can steal IAM credentials from metadata service"
    echo "        └─ Real-world: This caused the Capital One breach (100M+ records)"
    ((HIGH++))
elif [ "$IMDS" = "required" ]; then
    echo -e "${GREEN}[PASS] IMDSv2 required${NC}"
    ((PASSED++))
else
    echo -e "${YELLOW}Instance not running or not found${NC}"
fi

# Check Public IP
echo -n "EC2 Public IP: "
PUBLIC_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Lab,Values=cloud-security-lab-02" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text 2>/dev/null)

if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ]; then
    echo -e "${YELLOW}[INFO] Public IP: $PUBLIC_IP${NC}"
    echo "        └─ Instance is directly accessible from internet"
else
    echo -e "${GREEN}[PASS] No public IP${NC}"
    ((PASSED++))
fi

# Summary
echo ""
echo "=============================================="
echo "  SCAN RESULTS"
echo "=============================================="
echo ""

TOTAL_ISSUES=$((CRITICAL + HIGH + MEDIUM))

if [ "$TOTAL_ISSUES" -eq 0 ]; then
    echo -e "${GREEN}All checks passed! No vulnerabilities found.${NC}"
else
    echo -e "  ${RED}Critical: $CRITICAL${NC}"
    echo -e "  ${RED}High:     $HIGH${NC}"
    echo -e "  ${YELLOW}Medium:   $MEDIUM${NC}"
    echo -e "  ${GREEN}Passed:   $PASSED${NC}"
    echo ""

    if [ "$CRITICAL" -gt 0 ]; then
        echo -e "${RED}▶ CRITICAL issues require immediate remediation${NC}"
    fi
    if [ "$HIGH" -gt 0 ]; then
        echo -e "${RED}▶ HIGH issues should be fixed before production use${NC}"
    fi
fi

echo ""
echo "=============================================="
