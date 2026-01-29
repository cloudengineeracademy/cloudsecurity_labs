#!/bin/bash

# Lab 04: Fix the non-compliant SG and watch Config flip to COMPLIANT

echo ""
echo "=============================================="
echo "  FIX AND VERIFY: Compliance Remediation"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SG_NAME="ch03-noncompliant-sg"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    exit 1
fi

# ============================================================
# Step 1: Find the non-compliant SG
# ============================================================
echo -e "${BLUE}Step 1: Finding the non-compliant security group...${NC}"

SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SG_NAME" \
    --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)

if [ -z "$SG_ID" ] || [ "$SG_ID" = "None" ]; then
    echo -e "${YELLOW}Security group '$SG_NAME' not found.${NC}"
    echo "  Run the compliance exercise first:"
    echo "    bash lab-04-config-access-analyzer/scripts/compliance-exercise.sh"
    exit 0
fi

echo "  Found: $SG_ID ($SG_NAME)"
echo ""

# Show current rules
echo -e "${BLUE}Current inbound rules:${NC}"
aws ec2 describe-security-groups \
    --group-ids "$SG_ID" \
    --query 'SecurityGroups[0].IpPermissions[].{Protocol:IpProtocol,Port:FromPort,Source:IpRanges[0].CidrIp}' \
    --output table 2>/dev/null
echo ""

# ============================================================
# Step 2: Remove the non-compliant rule
# ============================================================
echo -e "${BLUE}Step 2: Removing the SSH 0.0.0.0/0 rule...${NC}"

aws ec2 revoke-security-group-ingress \
    --group-id "$SG_ID" \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Removed SSH rule from $SG_ID${NC}"
else
    echo -e "${YELLOW}Rule may already be removed.${NC}"
fi
echo ""

# Show updated rules
echo -e "${BLUE}Updated inbound rules:${NC}"
RULES=$(aws ec2 describe-security-groups \
    --group-ids "$SG_ID" \
    --query 'SecurityGroups[0].IpPermissions | length(@)' \
    --output text 2>/dev/null || echo "0")

if [ "$RULES" = "0" ]; then
    echo "  (no inbound rules — secure)"
else
    aws ec2 describe-security-groups \
        --group-ids "$SG_ID" \
        --query 'SecurityGroups[0].IpPermissions[].{Protocol:IpProtocol,Port:FromPort,Source:IpRanges[0].CidrIp}' \
        --output table 2>/dev/null
fi
echo ""

# ============================================================
# Step 3: Trigger re-evaluation
# ============================================================
echo -e "${BLUE}Step 3: Triggering Config re-evaluation...${NC}"
echo ""

aws configservice start-config-rules-evaluation --config-rule-names "ch03-restricted-ssh" 2>/dev/null

echo "  Waiting for Config to re-evaluate (checking every 15 seconds)..."
WAIT_COUNT=0
MAX_WAIT=8

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
    # Check if our specific SG is now compliant
    NON_COMPLIANT=$(aws configservice get-compliance-details-by-config-rule \
        --config-rule-name "ch03-restricted-ssh" \
        --compliance-types NON_COMPLIANT \
        --query 'EvaluationResults[?EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId==`'"$SG_ID"'`] | length(@)' \
        --output text 2>/dev/null || echo "1")

    if [ "$NON_COMPLIANT" = "0" ]; then
        echo ""
        echo -e "${GREEN}  Config has re-evaluated: $SG_ID is now COMPLIANT!${NC}"
        break
    fi

    echo -n "  ."
    sleep 15
    ((WAIT_COUNT++))
done

if [ $WAIT_COUNT -eq $MAX_WAIT ]; then
    echo ""
    echo -e "${YELLOW}  Re-evaluation still in progress.${NC}"
    echo "  Config may take a few minutes. Check manually:"
    echo "    aws configservice get-compliance-details-by-config-rule \\"
    echo "      --config-rule-name ch03-restricted-ssh \\"
    echo "      --compliance-types COMPLIANT"
fi

echo ""

# ============================================================
# Step 4: Clean up the exercise SG
# ============================================================
echo -e "${BLUE}Step 4: Cleaning up exercise security group...${NC}"

aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Deleted security group: $SG_ID${NC}"
else
    echo -e "${YELLOW}Could not delete SG (may be in use). Delete manually if needed.${NC}"
fi
echo ""

# ============================================================
# Summary
# ============================================================
echo "=============================================="
echo -e "${BLUE}COMPLIANCE CYCLE COMPLETE${NC}"
echo "=============================================="
echo ""
echo "  You just completed the full compliance cycle:"
echo ""
echo "    1. BREAK:  Created SG with SSH open to 0.0.0.0/0"
echo "    2. DETECT: Config rule flagged it as NON_COMPLIANT"
echo "    3. FIX:    Removed the offending rule"
echo "    4. VERIFY: Config re-evaluated and confirmed COMPLIANT"
echo "    5. CLEAN:  Deleted the exercise security group"
echo ""
echo "  This is how continuous compliance works in production:"
echo "    - Config watches for changes"
echo "    - Rules evaluate compliance"
echo "    - Non-compliant resources get flagged"
echo "    - Teams remediate (or automation does it)"
echo ""
echo "  Next: bash lab-04-config-access-analyzer/scripts/verify.sh"
echo ""
