#!/bin/bash

# Lab 02: Detective Exercise
# Generate API calls, then find them in CloudTrail logs

echo ""
echo "=============================================="
echo "  DETECTIVE EXERCISE: Find Your API Calls"
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
CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)
TRAIL_NAME="ch03-security-trail"

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    exit 1
fi

# Check CloudTrail is active
IS_LOGGING=$(aws cloudtrail get-trail-status --name "$TRAIL_NAME" --query 'IsLogging' --output text 2>/dev/null)
if [ "$IS_LOGGING" != "True" ]; then
    echo -e "${RED}ERROR: CloudTrail '$TRAIL_NAME' is not logging.${NC}"
    echo "Run setup first: bash lab-02-cloudtrail/scripts/setup-cloudtrail.sh"
    exit 1
fi

echo "Your identity: $CALLER_ARN"
echo ""

# ============================================================
# Part 1: Generate some API calls
# ============================================================
echo -e "${BLUE}Part 1: Generating API calls for CloudTrail to record...${NC}"
echo ""

echo "  Making API calls:"
echo -n "  [1/4] Listing S3 buckets... "
aws s3api list-buckets --query 'Buckets | length(@)' --output text 2>/dev/null
echo -n "  [2/4] Describing EC2 instances... "
aws ec2 describe-instances --query 'Reservations | length(@)' --output text 2>/dev/null
echo -n "  [3/4] Listing IAM users... "
aws iam list-users --query 'Users | length(@)' --output text 2>/dev/null
echo -n "  [4/4] Describing security groups... "
aws ec2 describe-security-groups --query 'SecurityGroups | length(@)' --output text 2>/dev/null

echo ""
echo -e "${GREEN}4 API calls made.${NC}"
echo ""

# ============================================================
# Part 2: Look up recent events
# ============================================================
echo -e "${BLUE}Part 2: Querying CloudTrail for recent events...${NC}"
echo ""
echo "  CloudTrail delivers events within ~15 minutes."
echo "  Let's check what's already recorded from your session."
echo ""

echo -e "${YELLOW}Your most recent 10 API calls:${NC}"
echo ""

aws cloudtrail lookup-events \
    --lookup-attributes "AttributeKey=Username,AttributeValue=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null | awk -F'/' '{print $NF}')" \
    --max-results 10 \
    --query 'Events[].{Time:EventTime,Event:EventName,Source:EventSource}' \
    --output table 2>/dev/null

echo ""

# ============================================================
# Part 3: Investigate specific event types
# ============================================================
echo -e "${BLUE}Part 3: Investigating specific event types...${NC}"
echo ""

echo -e "${YELLOW}Recent IAM events (credential-related activity):${NC}"
echo ""
aws cloudtrail lookup-events \
    --lookup-attributes "AttributeKey=EventSource,AttributeValue=iam.amazonaws.com" \
    --max-results 5 \
    --query 'Events[].{Time:EventTime,Event:EventName,User:Username}' \
    --output table 2>/dev/null

echo ""
echo -e "${YELLOW}Recent S3 events (data access activity):${NC}"
echo ""
aws cloudtrail lookup-events \
    --lookup-attributes "AttributeKey=EventSource,AttributeValue=s3.amazonaws.com" \
    --max-results 5 \
    --query 'Events[].{Time:EventTime,Event:EventName,User:Username}' \
    --output table 2>/dev/null

echo ""

# ============================================================
# Part 4: Key takeaways
# ============================================================
echo "=============================================="
echo -e "${BLUE}KEY TAKEAWAYS${NC}"
echo "=============================================="
echo ""
echo "  1. CloudTrail records WHO did WHAT and WHEN"
echo "  2. lookup-events lets you search recent activity"
echo "  3. For deeper forensics, query S3 log files directly"
echo "  4. Every API call — even read-only ones — is recorded"
echo ""
echo "  In the Capital One breach, CloudTrail would have shown:"
echo "    - Unusual ListBuckets calls from an EC2 instance role"
echo "    - GetObject calls for 700+ S3 objects in minutes"
echo "    - Activity from an unusual source IP"
echo ""
echo "  CloudTrail turns an invisible breach into a visible one."
echo ""
