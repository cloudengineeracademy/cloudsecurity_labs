#!/bin/bash

# Cloud Security Assessment - Security Scan Script
# Checks for common misconfigurations and vulnerabilities

echo ""
echo "=============================================="
echo "  SECURITY SCAN - Cloud Security Assessment"
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
LOW=0
PASSED=0

echo "Scanning for security issues..."
echo ""

# Category 1: Identity (IAM)
echo "----------------------------------------------"
echo -e "${BLUE}[1/4] IDENTITY (IAM)${NC}"
echo "----------------------------------------------"
echo ""

# Check for users without MFA
echo -n "IAM Users with MFA: "
USERS=$(aws iam list-users --query 'Users[].UserName' --output text 2>/dev/null)
MFA_ISSUES=0
for user in $USERS; do
    MFA=$(aws iam list-mfa-devices --user-name "$user" --query 'MFADevices[0]' --output text 2>/dev/null)
    if [ -z "$MFA" ] || [ "$MFA" = "None" ]; then
        ((MFA_ISSUES++))
    fi
done

if [ $MFA_ISSUES -gt 0 ]; then
    echo -e "${RED}[HIGH] $MFA_ISSUES user(s) without MFA${NC}"
    ((HIGH++))
else
    echo -e "${GREEN}[PASS] All users have MFA${NC}"
    ((PASSED++))
fi

# Check for users with access keys
echo -n "IAM Access Keys: "
KEY_USERS=0
for user in $USERS; do
    KEYS=$(aws iam list-access-keys --user-name "$user" --query 'length(AccessKeyMetadata)' --output text 2>/dev/null)
    if [ "$KEYS" -gt 0 ]; then
        ((KEY_USERS++))
    fi
done

if [ $KEY_USERS -gt 0 ]; then
    echo -e "${YELLOW}[MEDIUM] $KEY_USERS user(s) have access keys${NC}"
    ((MEDIUM++))
else
    echo -e "${GREEN}[PASS] No users have access keys${NC}"
    ((PASSED++))
fi

# Check for old access keys (>90 days)
echo -n "Old Access Keys (>90 days): "
OLD_KEYS=0
for user in $USERS; do
    KEY_DATES=$(aws iam list-access-keys --user-name "$user" --query 'AccessKeyMetadata[].CreateDate' --output text 2>/dev/null)
    for date in $KEY_DATES; do
        if [ -n "$date" ]; then
            KEY_AGE=$(( ($(date +%s) - $(date -d "$date" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "${date%+*}" +%s 2>/dev/null)) / 86400 ))
            if [ "$KEY_AGE" -gt 90 ] 2>/dev/null; then
                ((OLD_KEYS++))
            fi
        fi
    done
done

if [ $OLD_KEYS -gt 0 ]; then
    echo -e "${YELLOW}[MEDIUM] $OLD_KEYS old access key(s) found${NC}"
    ((MEDIUM++))
else
    echo -e "${GREEN}[PASS] No old access keys${NC}"
    ((PASSED++))
fi

echo ""

# Category 2: Network
echo "----------------------------------------------"
echo -e "${BLUE}[2/4] NETWORK (Security Groups)${NC}"
echo "----------------------------------------------"
echo ""

# Check for 0.0.0.0/0 ingress
echo -n "Open Security Groups (0.0.0.0/0): "
OPEN_SG=$(aws ec2 describe-security-groups \
    --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]].GroupId' \
    --output text 2>/dev/null | wc -w)

if [ $OPEN_SG -gt 0 ]; then
    echo -e "${RED}[CRITICAL] $OPEN_SG security group(s) allow traffic from 0.0.0.0/0${NC}"
    ((CRITICAL++))

    # Show which ports are open
    aws ec2 describe-security-groups \
        --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]].{ID:GroupId,Name:GroupName}' \
        --output table 2>/dev/null
else
    echo -e "${GREEN}[PASS] No security groups open to 0.0.0.0/0${NC}"
    ((PASSED++))
fi

# Check for SSH (22) open to internet
echo -n "SSH Open to Internet: "
SSH_OPEN=$(aws ec2 describe-security-groups \
    --query 'SecurityGroups[?IpPermissions[?FromPort==`22` && IpRanges[?CidrIp==`0.0.0.0/0`]]].GroupId' \
    --output text 2>/dev/null | wc -w)

if [ $SSH_OPEN -gt 0 ]; then
    echo -e "${RED}[CRITICAL] $SSH_OPEN security group(s) have SSH open to internet${NC}"
    ((CRITICAL++))
else
    echo -e "${GREEN}[PASS] SSH not open to internet${NC}"
    ((PASSED++))
fi

# Check for RDP (3389) open to internet
echo -n "RDP Open to Internet: "
RDP_OPEN=$(aws ec2 describe-security-groups \
    --query 'SecurityGroups[?IpPermissions[?FromPort==`3389` && IpRanges[?CidrIp==`0.0.0.0/0`]]].GroupId' \
    --output text 2>/dev/null | wc -w)

if [ $RDP_OPEN -gt 0 ]; then
    echo -e "${RED}[CRITICAL] $RDP_OPEN security group(s) have RDP open to internet${NC}"
    ((CRITICAL++))
else
    echo -e "${GREEN}[PASS] RDP not open to internet${NC}"
    ((PASSED++))
fi

echo ""

# Category 3: Data (S3)
echo "----------------------------------------------"
echo -e "${BLUE}[3/4] DATA (S3)${NC}"
echo "----------------------------------------------"
echo ""

BUCKETS=$(aws s3 ls 2>/dev/null | awk '{print $3}')

# Check for buckets without public access block
echo -n "S3 Public Access Block: "
NO_BLOCK=0
for bucket in $BUCKETS; do
    BLOCK=$(aws s3api get-public-access-block --bucket "$bucket" 2>&1)
    if echo "$BLOCK" | grep -q "NoSuchPublicAccessBlockConfiguration"; then
        ((NO_BLOCK++))
    fi
done

if [ $NO_BLOCK -gt 0 ]; then
    echo -e "${RED}[HIGH] $NO_BLOCK bucket(s) without public access block${NC}"
    ((HIGH++))
else
    echo -e "${GREEN}[PASS] All buckets have public access block${NC}"
    ((PASSED++))
fi

# Check for buckets without encryption
echo -n "S3 Encryption: "
NO_ENCRYPT=0
for bucket in $BUCKETS; do
    ENCRYPT=$(aws s3api get-bucket-encryption --bucket "$bucket" 2>&1)
    if echo "$ENCRYPT" | grep -q "ServerSideEncryptionConfigurationNotFoundError"; then
        ((NO_ENCRYPT++))
    fi
done

if [ $NO_ENCRYPT -gt 0 ]; then
    echo -e "${YELLOW}[MEDIUM] $NO_ENCRYPT bucket(s) without default encryption${NC}"
    ((MEDIUM++))
else
    echo -e "${GREEN}[PASS] All buckets have encryption${NC}"
    ((PASSED++))
fi

echo ""

# Category 4: Compute (EC2)
echo "----------------------------------------------"
echo -e "${BLUE}[4/4] COMPUTE (EC2)${NC}"
echo "----------------------------------------------"
echo ""

# Check for IMDSv1 enabled
echo -n "EC2 IMDS Version: "
IMDSV1=$(aws ec2 describe-instances \
    --query 'Reservations[].Instances[?MetadataOptions.HttpTokens==`optional`].InstanceId' \
    --output text 2>/dev/null | wc -w)

if [ $IMDSV1 -gt 0 ]; then
    echo -e "${RED}[CRITICAL] $IMDSV1 instance(s) have IMDSv1 enabled (SSRF vulnerable)${NC}"
    ((CRITICAL++))

    echo "    Affected instances:"
    aws ec2 describe-instances \
        --query 'Reservations[].Instances[?MetadataOptions.HttpTokens==`optional`].{ID:InstanceId,Name:Tags[?Key==`Name`].Value|[0]}' \
        --output table 2>/dev/null
else
    echo -e "${GREEN}[PASS] All instances require IMDSv2${NC}"
    ((PASSED++))
fi

# Check for instances with public IPs
echo -n "EC2 Public IPs: "
PUBLIC_IP=$(aws ec2 describe-instances \
    --query 'Reservations[].Instances[?PublicIpAddress!=null].InstanceId' \
    --output text 2>/dev/null | wc -w)

if [ $PUBLIC_IP -gt 0 ]; then
    echo -e "${YELLOW}[INFO] $PUBLIC_IP instance(s) have public IPs${NC}"
else
    echo -e "${GREEN}[PASS] No instances with public IPs${NC}"
    ((PASSED++))
fi

echo ""

# Summary
echo "=============================================="
echo "  SCAN RESULTS"
echo "=============================================="
echo ""

TOTAL_ISSUES=$((CRITICAL + HIGH + MEDIUM + LOW))

echo -e "  ${RED}Critical: $CRITICAL${NC}"
echo -e "  ${RED}High:     $HIGH${NC}"
echo -e "  ${YELLOW}Medium:   $MEDIUM${NC}"
echo -e "  ${BLUE}Low:      $LOW${NC}"
echo -e "  ${GREEN}Passed:   $PASSED${NC}"
echo ""

if [ $CRITICAL -gt 0 ]; then
    echo -e "${RED}▶ CRITICAL issues require immediate remediation${NC}"
    echo "  These match patterns from real breaches (Capital One, Uber)"
fi

if [ $HIGH -gt 0 ]; then
    echo -e "${RED}▶ HIGH issues should be fixed within 1 week${NC}"
fi

echo ""
echo "=============================================="
echo ""
echo "Next steps:"
echo "  1. Document findings in assessment report"
echo "  2. Map findings to breach patterns"
echo "  3. Create remediation runbook"
echo ""
