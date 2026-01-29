#!/bin/bash

# Lab 04: Compliance Exercise — Break and Watch Config Flag It

echo ""
echo "=============================================="
echo "  COMPLIANCE EXERCISE: Break and Fix"
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

SG_NAME="ch03-noncompliant-sg"

# ============================================================
# Step 1: Create a non-compliant security group
# ============================================================
echo -e "${BLUE}Step 1: Creating a non-compliant security group...${NC}"
echo ""
echo "  This security group will have SSH (port 22) open to 0.0.0.0/0."
echo "  This is the exact misconfiguration that AWS Config rule"
echo "  'restricted-ssh' is designed to catch."
echo ""

# Get default VPC
DEFAULT_VPC=$(aws ec2 describe-vpcs --query 'Vpcs[?IsDefault==`true`].VpcId' --output text 2>/dev/null)
if [ -z "$DEFAULT_VPC" ] || [ "$DEFAULT_VPC" = "None" ]; then
    # Use any VPC
    DEFAULT_VPC=$(aws ec2 describe-vpcs --query 'Vpcs[0].VpcId' --output text 2>/dev/null)
fi

if [ -z "$DEFAULT_VPC" ] || [ "$DEFAULT_VPC" = "None" ]; then
    echo -e "${RED}ERROR: No VPC found. Cannot create security group.${NC}"
    exit 1
fi

# Check if SG already exists
EXISTING_SG=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SG_NAME" \
    --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)

if [ -n "$EXISTING_SG" ] && [ "$EXISTING_SG" != "None" ]; then
    echo -e "${YELLOW}Security group already exists: $EXISTING_SG${NC}"
    SG_ID="$EXISTING_SG"
else
    SG_ID=$(aws ec2 create-security-group \
        --group-name "$SG_NAME" \
        --description "Non-compliant SG for Config exercise (SSH open to 0.0.0.0/0)" \
        --vpc-id "$DEFAULT_VPC" \
        --query 'GroupId' --output text 2>/dev/null)

    if [ -z "$SG_ID" ] || [ "$SG_ID" = "None" ]; then
        echo -e "${RED}ERROR: Failed to create security group${NC}"
        exit 1
    fi

    # Add the non-compliant rule: SSH from 0.0.0.0/0
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 2>/dev/null

    echo -e "${RED}Created non-compliant SG: $SG_ID${NC}"
    echo -e "${RED}  Rule: SSH (port 22) open to 0.0.0.0/0${NC}"
fi
echo ""

# ============================================================
# Step 2: Show what Config sees
# ============================================================
echo -e "${BLUE}Step 2: Checking Config compliance status...${NC}"
echo ""
echo "  Config evaluates rules when resources change."
echo "  This may take 1-2 minutes for the first evaluation."
echo ""

# Trigger rule evaluation
echo "  Triggering evaluation of restricted-ssh rule..."
aws configservice start-config-rules-evaluation --config-rule-names "ch03-restricted-ssh" 2>/dev/null
echo ""

echo "  Waiting for Config to evaluate (checking every 15 seconds)..."
WAIT_COUNT=0
MAX_WAIT=8

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    COMPLIANCE=$(aws configservice get-compliance-details-by-config-rule \
        --config-rule-name "ch03-restricted-ssh" \
        --compliance-types NON_COMPLIANT \
        --query 'EvaluationResults | length(@)' \
        --output text 2>/dev/null || echo "0")

    if [ "$COMPLIANCE" -gt 0 ] 2>/dev/null; then
        echo ""
        echo -e "${RED}  Config found NON_COMPLIANT resources!${NC}"
        echo ""
        echo "  Non-compliant security groups:"
        aws configservice get-compliance-details-by-config-rule \
            --config-rule-name "ch03-restricted-ssh" \
            --compliance-types NON_COMPLIANT \
            --query 'EvaluationResults[].EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId' \
            --output text 2>/dev/null | tr '\t' '\n' | while read -r resource; do
            echo -e "    ${RED}[NON_COMPLIANT]${NC} $resource"
        done
        break
    fi

    echo -n "  ."
    sleep 15
    ((WAIT_COUNT++))
done

if [ $WAIT_COUNT -eq $MAX_WAIT ]; then
    echo ""
    echo -e "${YELLOW}  Config evaluation still in progress.${NC}"
    echo "  This is normal — Config can take a few minutes for new resources."
    echo "  Check manually with:"
    echo "    aws configservice get-compliance-details-by-config-rule \\"
    echo "      --config-rule-name ch03-restricted-ssh \\"
    echo "      --compliance-types NON_COMPLIANT"
fi

echo ""

# ============================================================
# Step 3: Explain what happened
# ============================================================
echo "=============================================="
echo -e "${BLUE}WHAT HAPPENED${NC}"
echo "=============================================="
echo ""
echo "  1. You created SG $SG_ID with SSH open to 0.0.0.0/0"
echo "  2. AWS Config recorded the new security group configuration"
echo "  3. Config rule 'restricted-ssh' evaluated the SG"
echo "  4. The rule flagged it as NON_COMPLIANT"
echo ""
echo "  In a real environment, this could trigger:"
echo "    - SNS notification to the security team"
echo "    - Automatic remediation (Lambda function to close the port)"
echo "    - Security Hub finding visible in the dashboard"
echo ""
echo "  Next: Fix the violation:"
echo "    bash lab-04-config-access-analyzer/scripts/fix-and-verify.sh"
echo ""
