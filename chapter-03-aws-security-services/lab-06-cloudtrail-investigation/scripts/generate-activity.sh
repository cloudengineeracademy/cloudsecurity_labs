#!/bin/bash

# Lab 06: Generate Suspicious Activity
# Creates real AWS resources that simulate attacker behavior
# Everything is cleaned up by cleanup.sh

echo ""
echo "=============================================="
echo "  SIMULATE SUSPICIOUS ACTIVITY"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)
REGION=$(aws configure get region 2>/dev/null || echo "us-east-1")

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi

echo "Account:  $ACCOUNT_ID"
echo "Identity: $CALLER_ARN"
echo "Region:   $REGION"
echo ""
echo "You're about to simulate what an attacker would do."
echo "CloudTrail will record every action. Then you'll hunt for them."
echo ""
echo "----------------------------------------------"

# ============================================================
# Phase 1: Reconnaissance
# ============================================================
echo ""
echo -e "${BLUE}PHASE 1: RECONNAISSANCE${NC}"
echo "  An attacker's first move — map the environment."
echo ""

echo -n "  [1/3] Listing S3 buckets (s3:ListBuckets)... "
BUCKET_COUNT=$(aws s3api list-buckets --query 'Buckets | length(@)' --output text 2>/dev/null)
echo -e "${GREEN}done${NC} — found $BUCKET_COUNT buckets"

echo -n "  [2/3] Listing IAM users (iam:ListUsers)... "
USER_COUNT=$(aws iam list-users --query 'Users | length(@)' --output text 2>/dev/null)
echo -e "${GREEN}done${NC} — found $USER_COUNT users"

echo -n "  [3/3] Listing CloudTrail trails (cloudtrail:DescribeTrails)... "
TRAIL_COUNT=$(aws cloudtrail describe-trails --query 'trailList | length(@)' --output text 2>/dev/null)
echo -e "${GREEN}done${NC} — found $TRAIL_COUNT trails"

echo ""
echo -e "${YELLOW}  An attacker now knows: how many buckets, users, and trails exist.${NC}"

# ============================================================
# Phase 2: Open a backdoor port
# ============================================================
echo ""
echo -e "${BLUE}PHASE 2: OPEN A BACKDOOR PORT${NC}"
echo "  Creating a security group with SSH open to the world."
echo ""

# Get default VPC
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text 2>/dev/null)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
    echo -e "${YELLOW}  No default VPC found. Skipping security group creation.${NC}"
    SG_CREATED="false"
else
    echo -n "  Creating security group 'lab06-open-ssh'... "
    SG_ID=$(aws ec2 create-security-group \
        --group-name "lab06-open-ssh" \
        --description "Lab 06 - Suspicious open SSH" \
        --vpc-id "$VPC_ID" \
        --query 'GroupId' --output text 2>/dev/null)

    if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
        echo -e "${GREEN}done${NC} — $SG_ID"

        echo -n "  Opening SSH (port 22) to 0.0.0.0/0... "
        aws ec2 authorize-security-group-ingress \
            --group-id "$SG_ID" \
            --protocol tcp \
            --port 22 \
            --cidr "0.0.0.0/0" > /dev/null 2>&1
        echo -e "${RED}done${NC}"
        SG_CREATED="true"

        echo ""
        echo -e "${RED}  SSH open to the entire internet. This is a critical finding.${NC}"
        echo -e "${YELLOW}  CloudTrail just recorded: CreateSecurityGroup + AuthorizeSecurityGroupIngress${NC}"
    else
        echo -e "${YELLOW}skipped (may already exist)${NC}"
        SG_CREATED="false"
    fi
fi

# ============================================================
# Phase 3: Create a backdoor user
# ============================================================
echo ""
echo -e "${BLUE}PHASE 3: CREATE A BACKDOOR USER${NC}"
echo "  Attackers create IAM users for persistent access."
echo ""

echo -n "  Creating IAM user 'lab06-suspicious-user'... "
aws iam create-user --user-name "lab06-suspicious-user" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}done${NC}"
    USER_CREATED="true"
else
    echo -e "${YELLOW}skipped (may already exist)${NC}"
    USER_CREATED="false"
fi

echo -n "  Creating access keys for that user... "
KEY_OUTPUT=$(aws iam create-access-key --user-name "lab06-suspicious-user" 2>/dev/null)
if [ $? -eq 0 ]; then
    ACCESS_KEY_ID=$(echo "$KEY_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessKey']['AccessKeyId'])" 2>/dev/null)
    echo -e "${GREEN}done${NC} — key: $ACCESS_KEY_ID"
    echo ""
    echo -e "${RED}  Backdoor created. This user now has active access keys.${NC}"
    echo -e "${YELLOW}  CloudTrail just recorded: CreateUser + CreateAccessKey${NC}"
else
    echo -e "${YELLOW}skipped${NC}"
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "=============================================="
echo -e "${BLUE}ACTIVITY GENERATED${NC}"
echo "=============================================="
echo ""
echo "  CloudTrail is now recording all of this."
echo "  Events appear in Event History within minutes."
echo ""
echo "  What was recorded:"
echo "    - ListBuckets          (reconnaissance)"
echo "    - ListUsers            (reconnaissance)"
echo "    - DescribeTrails       (looking for logging)"
if [ "$SG_CREATED" = "true" ]; then
echo "    - CreateSecurityGroup  (opening backdoor port)"
echo "    - AuthorizeSecurityGroupIngress (SSH 0.0.0.0/0)"
fi
echo "    - CreateUser           (persistence)"
echo "    - CreateAccessKey      (persistence)"
echo ""
echo -e "${YELLOW}  Now go to Part 2 in the README to hunt for these events.${NC}"
echo ""
echo "  When you're done investigating, clean up with:"
echo -e "${GREEN}  bash scripts/cleanup.sh${NC}"
echo ""
