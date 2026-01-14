#!/bin/bash

# Defence in Depth Audit Script
# Checks each of the 6 defence layers

echo "=============================================="
echo "  Defence in Depth Audit"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get account info
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    exit 1
fi

echo "Account: $ACCOUNT_ID"
echo "Date: $(date)"
echo ""

# Score tracking
TOTAL_SCORE=0
MAX_SCORE=0

score_item() {
    local name=$1
    local passed=$2
    local points=$3
    local message=$4

    ((MAX_SCORE += points))

    if [ "$passed" = "true" ]; then
        echo -e "  ${GREEN}[+$points]${NC} $name: $message"
        ((TOTAL_SCORE += points))
    else
        echo -e "  ${RED}[+0]${NC} $name: $message"
    fi
}

echo "=============================================="
echo -e "${BLUE}LAYER 1: PERIMETER${NC}"
echo "=============================================="

# Check for WAF (Web ACLs)
WAF_COUNT=$(aws wafv2 list-web-acls --scope REGIONAL --query 'WebACLs | length(@)' --output text 2>/dev/null || echo "0")
if [ "$WAF_COUNT" -gt 0 ]; then
    score_item "WAF Web ACLs" "true" 2 "$WAF_COUNT WAF rules configured"
else
    score_item "WAF Web ACLs" "false" 2 "No WAF configured (OK if no public apps)"
fi

echo ""
echo "=============================================="
echo -e "${BLUE}LAYER 2: NETWORK${NC}"
echo "=============================================="

# Check for open security groups
OPEN_SG=$(aws ec2 describe-security-groups \
    --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]] | length(@)' \
    --output text 2>/dev/null || echo "0")

if [ "$OPEN_SG" -eq 0 ]; then
    score_item "No open Security Groups" "true" 2 "No SGs allow 0.0.0.0/0 ingress"
else
    score_item "No open Security Groups" "false" 2 "$OPEN_SG SGs have 0.0.0.0/0 ingress"
fi

# Check for private subnets
PRIVATE_SUBNETS=$(aws ec2 describe-subnets \
    --query 'Subnets[?MapPublicIpOnLaunch==`false`] | length(@)' \
    --output text 2>/dev/null || echo "0")
PUBLIC_SUBNETS=$(aws ec2 describe-subnets \
    --query 'Subnets[?MapPublicIpOnLaunch==`true`] | length(@)' \
    --output text 2>/dev/null || echo "0")

if [ "$PRIVATE_SUBNETS" -gt 0 ]; then
    score_item "Private subnets exist" "true" 1 "$PRIVATE_SUBNETS private, $PUBLIC_SUBNETS public"
else
    score_item "Private subnets exist" "false" 1 "Only public subnets found"
fi

echo ""
echo "=============================================="
echo -e "${BLUE}LAYER 3: IDENTITY${NC}"
echo "=============================================="

# Check MFA on all users
TOTAL_USERS=$(aws iam list-users --query 'Users | length(@)' --output text 2>/dev/null || echo "0")
USERS_WITH_MFA=0
for user in $(aws iam list-users --query 'Users[].UserName' --output text 2>/dev/null); do
    mfa=$(aws iam list-mfa-devices --user-name "$user" --query 'MFADevices[0]' --output text 2>/dev/null)
    if [ -n "$mfa" ] && [ "$mfa" != "None" ]; then
        ((USERS_WITH_MFA++))
    fi
done

if [ "$TOTAL_USERS" -eq "$USERS_WITH_MFA" ] && [ "$TOTAL_USERS" -gt 0 ]; then
    score_item "All users have MFA" "true" 2 "$USERS_WITH_MFA/$TOTAL_USERS users"
else
    score_item "All users have MFA" "false" 2 "$USERS_WITH_MFA/$TOTAL_USERS users have MFA"
fi

# Check for password policy
PASSWORD_POLICY=$(aws iam get-account-password-policy 2>/dev/null)
if [ $? -eq 0 ]; then
    MIN_LEN=$(echo "$PASSWORD_POLICY" | grep -o '"MinimumPasswordLength": [0-9]*' | grep -o '[0-9]*')
    if [ "$MIN_LEN" -ge 14 ]; then
        score_item "Strong password policy" "true" 1 "Min length: $MIN_LEN"
    else
        score_item "Strong password policy" "false" 1 "Min length only $MIN_LEN (need 14+)"
    fi
else
    score_item "Strong password policy" "false" 1 "No policy configured"
fi

# Check for root access keys
ROOT_KEYS=$(aws iam get-account-summary --query 'SummaryMap.AccountAccessKeysPresent' --output text 2>/dev/null || echo "1")
if [ "$ROOT_KEYS" -eq 0 ]; then
    score_item "No root access keys" "true" 1 "Root has no access keys"
else
    score_item "No root access keys" "false" 1 "Root has $ROOT_KEYS access key(s) - DELETE!"
fi

echo ""
echo "=============================================="
echo -e "${BLUE}LAYER 4: COMPUTE${NC}"
echo "=============================================="

# Check for IMDSv2
IMDSV1_COUNT=$(aws ec2 describe-instances \
    --query 'Reservations[].Instances[?MetadataOptions.HttpTokens==`optional`] | length(@)' \
    --output text 2>/dev/null || echo "0")
INSTANCE_COUNT=$(aws ec2 describe-instances \
    --query 'Reservations[].Instances | length(@)' \
    --output text 2>/dev/null || echo "0")

if [ "$IMDSV1_COUNT" -eq 0 ]; then
    score_item "IMDSv2 enforced" "true" 2 "All $INSTANCE_COUNT instances use IMDSv2"
elif [ "$INSTANCE_COUNT" -eq 0 ]; then
    score_item "IMDSv2 enforced" "true" 2 "No EC2 instances (N/A)"
else
    score_item "IMDSv2 enforced" "false" 2 "$IMDSV1_COUNT instances still allow IMDSv1"
fi

# Check for public IPs on instances
PUBLIC_INSTANCES=$(aws ec2 describe-instances \
    --query 'Reservations[].Instances[?PublicIpAddress!=null] | length(@)' \
    --output text 2>/dev/null || echo "0")

if [ "$PUBLIC_INSTANCES" -eq 0 ]; then
    score_item "No public EC2 IPs" "true" 1 "No instances have public IPs"
else
    score_item "No public EC2 IPs" "false" 1 "$PUBLIC_INSTANCES instances have public IPs"
fi

echo ""
echo "=============================================="
echo -e "${BLUE}LAYER 5: DATA${NC}"
echo "=============================================="

# Check S3 Block Public Access at account level
S3_BLOCK=$(aws s3control get-public-access-block --account-id "$ACCOUNT_ID" 2>/dev/null)
if [ $? -eq 0 ]; then
    BLOCK_COUNT=$(echo "$S3_BLOCK" | grep -c "true")
    if [ "$BLOCK_COUNT" -eq 4 ]; then
        score_item "S3 Block Public Access" "true" 2 "All blocks enabled account-wide"
    else
        score_item "S3 Block Public Access" "false" 2 "Partially configured"
    fi
else
    score_item "S3 Block Public Access" "false" 2 "Not configured"
fi

# Check S3 bucket encryption
BUCKETS=$(aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null)
BUCKET_COUNT=0
ENCRYPTED_COUNT=0
for bucket in $BUCKETS; do
    ((BUCKET_COUNT++))
    enc=$(aws s3api get-bucket-encryption --bucket "$bucket" 2>/dev/null)
    if [ $? -eq 0 ]; then
        ((ENCRYPTED_COUNT++))
    fi
done

if [ "$BUCKET_COUNT" -eq 0 ]; then
    score_item "S3 buckets encrypted" "true" 1 "No buckets (N/A)"
elif [ "$BUCKET_COUNT" -eq "$ENCRYPTED_COUNT" ]; then
    score_item "S3 buckets encrypted" "true" 1 "$ENCRYPTED_COUNT/$BUCKET_COUNT encrypted"
else
    score_item "S3 buckets encrypted" "false" 1 "$ENCRYPTED_COUNT/$BUCKET_COUNT encrypted"
fi

echo ""
echo "=============================================="
echo -e "${BLUE}LAYER 6: DETECTION${NC}"
echo "=============================================="

# Check GuardDuty
GD_DETECTORS=$(aws guardduty list-detectors --query 'DetectorIds | length(@)' --output text 2>/dev/null || echo "0")
if [ "$GD_DETECTORS" -gt 0 ]; then
    score_item "GuardDuty enabled" "true" 1 "Detector active"
else
    score_item "GuardDuty enabled" "false" 1 "Not enabled (30-day free trial available)"
fi

echo ""
echo "=============================================="
echo "  FINAL SCORE"
echo "=============================================="
echo ""

# Calculate percentage
if [ "$MAX_SCORE" -gt 0 ]; then
    PERCENTAGE=$((TOTAL_SCORE * 100 / MAX_SCORE))
else
    PERCENTAGE=0
fi

echo -e "Score: ${BLUE}$TOTAL_SCORE / $MAX_SCORE${NC} ($PERCENTAGE%)"
echo ""

if [ "$PERCENTAGE" -ge 80 ]; then
    echo -e "${GREEN}Excellent! Your account has strong defence in depth.${NC}"
elif [ "$PERCENTAGE" -ge 60 ]; then
    echo -e "${YELLOW}Good progress! Address the gaps identified above.${NC}"
elif [ "$PERCENTAGE" -ge 40 ]; then
    echo -e "${YELLOW}Needs work. Focus on Critical and High priority items.${NC}"
else
    echo -e "${RED}Significant gaps exist. Prioritize security improvements.${NC}"
fi

echo ""
echo "----------------------------------------------"
echo "Priority Recommendations:"
echo "----------------------------------------------"

if [ "$ROOT_KEYS" -gt 0 ]; then
    echo -e "${RED}[CRITICAL]${NC} Delete root access keys immediately"
fi

if [ "$USERS_WITH_MFA" -lt "$TOTAL_USERS" ]; then
    echo -e "${RED}[CRITICAL]${NC} Enable MFA for all IAM users"
fi

if [ "$IMDSV1_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}[HIGH]${NC} Enforce IMDSv2 on all EC2 instances"
fi

if [ "$GD_DETECTORS" -eq 0 ]; then
    echo -e "${YELLOW}[MEDIUM]${NC} Enable GuardDuty (30-day free trial)"
fi

echo ""
