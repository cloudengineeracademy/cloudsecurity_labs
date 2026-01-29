#!/bin/bash

# Mission Status — 100-Point Security Scoring Engine
# Tracks progress across 5 pillars: Identity, Network, Data, Detection, Compliance

echo ""
echo "=============================================="
echo "  MISSION STATUS: Secure the Account"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[1;36m'
NC='\033[0m'

# Get account info
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi

echo "Account: $ACCOUNT_ID"
echo "Date: $(date)"
echo ""

# Pillar scores
IDENTITY_SCORE=0
IDENTITY_MAX=20
NETWORK_SCORE=0
NETWORK_MAX=15
DATA_SCORE=0
DATA_MAX=20
DETECTION_SCORE=0
DETECTION_MAX=30
COMPLIANCE_SCORE=0
COMPLIANCE_MAX=15

# Score tracking helper
score_item() {
    local pillar=$1
    local name=$2
    local passed=$3
    local points=$4
    local message=$5

    if [ "$passed" = "true" ]; then
        echo -e "  ${GREEN}[+$points]${NC} $name: $message"
        case "$pillar" in
            identity)  ((IDENTITY_SCORE += points)) ;;
            network)   ((NETWORK_SCORE += points)) ;;
            data)      ((DATA_SCORE += points)) ;;
            detection) ((DETECTION_SCORE += points)) ;;
            compliance) ((COMPLIANCE_SCORE += points)) ;;
        esac
    else
        echo -e "  ${RED}[+0]${NC} $name: $message"
    fi
}

# ============================================================
# PILLAR 1: IDENTITY (20 points)
# ============================================================
echo "=============================================="
echo -e "${BLUE}IDENTITY (0/$IDENTITY_MAX)${NC}"
echo "=============================================="

# Check password policy minimum length >= 14
MIN_LEN=$(aws iam get-account-password-policy --query 'PasswordPolicy.MinimumPasswordLength' --output text 2>/dev/null)
if [ -n "$MIN_LEN" ] && [ "$MIN_LEN" != "None" ] && [ "$MIN_LEN" -ge 14 ] 2>/dev/null; then
    score_item "identity" "Password policy" "true" 5 "Min length $MIN_LEN (14+ required)"
else
    score_item "identity" "Password policy" "false" 5 "Need min length 14+ (current: ${MIN_LEN:-none})"
fi

# Check no root access keys
ROOT_KEYS=$(aws iam get-account-summary --query 'SummaryMap.AccountAccessKeysPresent' --output text 2>/dev/null || echo "1")
if [ "$ROOT_KEYS" = "0" ]; then
    score_item "identity" "No root access keys" "true" 5 "Root has no access keys"
else
    score_item "identity" "No root access keys" "false" 5 "Root access keys exist — DELETE THEM"
fi

# Check MFA on IAM users
TOTAL_USERS=$(aws iam list-users --query 'Users | length(@)' --output text 2>/dev/null || echo "0")
USERS_WITH_MFA=0
if [ "$TOTAL_USERS" -gt 0 ] 2>/dev/null; then
    for user in $(aws iam list-users --query 'Users[].UserName' --output text 2>/dev/null); do
        mfa=$(aws iam list-mfa-devices --user-name "$user" --query 'MFADevices[0]' --output text 2>/dev/null)
        if [ -n "$mfa" ] && [ "$mfa" != "None" ]; then
            ((USERS_WITH_MFA++))
        fi
    done
fi

if [ "$TOTAL_USERS" -eq 0 ] || { [ "$TOTAL_USERS" -gt 0 ] && [ "$TOTAL_USERS" -eq "$USERS_WITH_MFA" ]; }; then
    score_item "identity" "MFA on users" "true" 5 "$USERS_WITH_MFA/$TOTAL_USERS users have MFA"
else
    score_item "identity" "MFA on users" "false" 5 "$USERS_WITH_MFA/$TOTAL_USERS users have MFA"
fi

# Check IAM Access Analyzer
ANALYZER_COUNT=$(aws accessanalyzer list-analyzers --query 'analyzers[?status==`ACTIVE`] | length(@)' --output text 2>/dev/null || echo "0")
if [ "$ANALYZER_COUNT" -gt 0 ] 2>/dev/null; then
    score_item "identity" "Access Analyzer" "true" 5 "Active analyzer found"
else
    score_item "identity" "Access Analyzer" "false" 5 "No active analyzer (Lab 04)"
fi

echo ""

# ============================================================
# PILLAR 2: NETWORK (15 points)
# ============================================================
echo "=============================================="
echo -e "${BLUE}NETWORK (0/$NETWORK_MAX)${NC}"
echo "=============================================="

# Check S3 Block Public Access at account level
S3_BLOCK_STATUS=$(aws s3control get-public-access-block --account-id "$ACCOUNT_ID" --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]' --output text 2>/dev/null)
BLOCK_COUNT=0
if [ -n "$S3_BLOCK_STATUS" ]; then
    for val in $S3_BLOCK_STATUS; do
        if [ "$val" = "True" ]; then
            ((BLOCK_COUNT++))
        fi
    done
fi

if [ "$BLOCK_COUNT" -eq 4 ]; then
    score_item "network" "S3 Block Public Access" "true" 5 "All 4 blocks enabled account-wide"
else
    score_item "network" "S3 Block Public Access" "false" 5 "$BLOCK_COUNT/4 blocks enabled"
fi

# Check no 0.0.0.0/0 SSH security groups
SSH_OPEN_SG=$(aws ec2 describe-security-groups \
    --query 'SecurityGroups[?IpPermissions[?FromPort==`22` && IpRanges[?CidrIp==`0.0.0.0/0`]]] | length(@)' \
    --output text 2>/dev/null || echo "0")

if [ "$SSH_OPEN_SG" = "0" ]; then
    score_item "network" "No open SSH SGs" "true" 5 "No SGs allow SSH from 0.0.0.0/0"
else
    score_item "network" "No open SSH SGs" "false" 5 "$SSH_OPEN_SG SGs allow SSH from 0.0.0.0/0"
fi

# Check default VPC reviewed (no resources in default VPC or no default VPC)
DEFAULT_VPC=$(aws ec2 describe-vpcs --query 'Vpcs[?IsDefault==`true`].VpcId' --output text 2>/dev/null)
if [ -z "$DEFAULT_VPC" ] || [ "$DEFAULT_VPC" = "None" ]; then
    score_item "network" "Default VPC reviewed" "true" 5 "No default VPC (deleted)"
else
    # Check if default VPC has any instances
    DEFAULT_INSTANCES=$(aws ec2 describe-instances \
        --filters "Name=vpc-id,Values=$DEFAULT_VPC" \
        --query 'Reservations[].Instances | length(@)' \
        --output text 2>/dev/null || echo "0")
    if [ "$DEFAULT_INSTANCES" = "0" ]; then
        score_item "network" "Default VPC reviewed" "true" 5 "Default VPC exists but unused"
    else
        score_item "network" "Default VPC reviewed" "false" 5 "Default VPC has $DEFAULT_INSTANCES instances"
    fi
fi

echo ""

# ============================================================
# PILLAR 3: DATA (20 points)
# ============================================================
echo "=============================================="
echo -e "${BLUE}DATA (0/$DATA_MAX)${NC}"
echo "=============================================="

# Check KMS CMK exists
CMK_COUNT=$(aws kms list-keys --query 'Keys | length(@)' --output text 2>/dev/null || echo "0")
# Filter to customer-managed keys (exclude AWS-managed)
CUSTOMER_KEYS=0
if [ "$CMK_COUNT" -gt 0 ] 2>/dev/null; then
    for key_id in $(aws kms list-keys --query 'Keys[].KeyId' --output text 2>/dev/null); do
        key_mgr=$(aws kms describe-key --key-id "$key_id" --query 'KeyMetadata.KeyManager' --output text 2>/dev/null)
        if [ "$key_mgr" = "CUSTOMER" ]; then
            ((CUSTOMER_KEYS++))
        fi
    done
fi

if [ "$CUSTOMER_KEYS" -gt 0 ]; then
    score_item "data" "KMS CMK exists" "true" 5 "$CUSTOMER_KEYS customer-managed key(s)"
else
    score_item "data" "KMS CMK exists" "false" 5 "No customer-managed KMS keys (Lab 02)"
fi

# Check CloudTrail encrypted with KMS
TRAIL_NAME=$(aws cloudtrail describe-trails --query 'trailList[0].Name' --output text 2>/dev/null)
if [ -n "$TRAIL_NAME" ] && [ "$TRAIL_NAME" != "None" ]; then
    TRAIL_KMS=$(aws cloudtrail describe-trails --query 'trailList[0].KmsKeyId' --output text 2>/dev/null)
    if [ -n "$TRAIL_KMS" ] && [ "$TRAIL_KMS" != "None" ]; then
        score_item "data" "CloudTrail encrypted" "true" 5 "KMS encryption enabled"
    else
        score_item "data" "CloudTrail encrypted" "false" 5 "Trail exists but no KMS encryption"
    fi
else
    score_item "data" "CloudTrail encrypted" "false" 5 "No CloudTrail configured (Lab 02)"
fi

# Check CloudTrail log file validation
if [ -n "$TRAIL_NAME" ] && [ "$TRAIL_NAME" != "None" ]; then
    LOG_VALIDATION=$(aws cloudtrail describe-trails --query 'trailList[0].LogFileValidationEnabled' --output text 2>/dev/null)
    if [ "$LOG_VALIDATION" = "True" ]; then
        score_item "data" "CloudTrail log validation" "true" 5 "Log integrity validation enabled"
    else
        score_item "data" "CloudTrail log validation" "false" 5 "Log validation not enabled"
    fi
else
    score_item "data" "CloudTrail log validation" "false" 5 "No CloudTrail configured (Lab 02)"
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
    score_item "data" "S3 bucket encryption" "true" 5 "No buckets (N/A)"
elif [ "$BUCKET_COUNT" -eq "$ENCRYPTED_COUNT" ]; then
    score_item "data" "S3 bucket encryption" "true" 5 "$ENCRYPTED_COUNT/$BUCKET_COUNT buckets encrypted"
else
    score_item "data" "S3 bucket encryption" "false" 5 "$ENCRYPTED_COUNT/$BUCKET_COUNT buckets encrypted"
fi

echo ""

# ============================================================
# PILLAR 4: DETECTION (30 points)
# ============================================================
echo "=============================================="
echo -e "${BLUE}DETECTION (0/$DETECTION_MAX)${NC}"
echo "=============================================="

# Check CloudTrail enabled
if [ -n "$TRAIL_NAME" ] && [ "$TRAIL_NAME" != "None" ]; then
    score_item "detection" "CloudTrail enabled" "true" 5 "Trail: $TRAIL_NAME"
else
    score_item "detection" "CloudTrail enabled" "false" 5 "No trail configured (Lab 02)"
fi

# Check CloudTrail multi-region
if [ -n "$TRAIL_NAME" ] && [ "$TRAIL_NAME" != "None" ]; then
    MULTI_REGION=$(aws cloudtrail describe-trails --query 'trailList[0].IsMultiRegionTrail' --output text 2>/dev/null)
    if [ "$MULTI_REGION" = "True" ]; then
        score_item "detection" "CloudTrail multi-region" "true" 5 "Recording all regions"
    else
        score_item "detection" "CloudTrail multi-region" "false" 5 "Single-region only"
    fi
else
    score_item "detection" "CloudTrail multi-region" "false" 5 "No trail configured (Lab 02)"
fi

# Check CloudTrail is logging (status)
if [ -n "$TRAIL_NAME" ] && [ "$TRAIL_NAME" != "None" ]; then
    IS_LOGGING=$(aws cloudtrail get-trail-status --name "$TRAIL_NAME" --query 'IsLogging' --output text 2>/dev/null)
    if [ "$IS_LOGGING" = "True" ]; then
        score_item "detection" "CloudTrail logging" "true" 5 "Actively recording"
    else
        score_item "detection" "CloudTrail logging" "false" 5 "Trail exists but not logging"
    fi
else
    score_item "detection" "CloudTrail logging" "false" 5 "No trail configured (Lab 02)"
fi

# Check GuardDuty enabled
GD_DETECTORS=$(aws guardduty list-detectors --query 'DetectorIds' --output text 2>/dev/null)
if [ -n "$GD_DETECTORS" ] && [ "$GD_DETECTORS" != "None" ] && [ "$GD_DETECTORS" != "" ]; then
    GD_ID=$(echo "$GD_DETECTORS" | awk '{print $1}')
    GD_STATUS=$(aws guardduty get-detector --detector-id "$GD_ID" --query 'Status' --output text 2>/dev/null)
    if [ "$GD_STATUS" = "ENABLED" ]; then
        score_item "detection" "GuardDuty enabled" "true" 5 "Detector active"
    else
        score_item "detection" "GuardDuty enabled" "false" 5 "Detector exists but disabled"
    fi
else
    score_item "detection" "GuardDuty enabled" "false" 5 "Not enabled (Lab 03)"
fi

# Check Security Hub enabled
SH_STATUS=$(aws securityhub describe-hub --query 'HubArn' --output text 2>/dev/null)
if [ -n "$SH_STATUS" ] && [ "$SH_STATUS" != "None" ]; then
    score_item "detection" "Security Hub enabled" "true" 5 "Hub active"
else
    score_item "detection" "Security Hub enabled" "false" 5 "Not enabled (Lab 03)"
fi

# Check Security Hub standards enabled
if [ -n "$SH_STATUS" ] && [ "$SH_STATUS" != "None" ]; then
    STANDARDS_COUNT=$(aws securityhub get-enabled-standards --query 'StandardsSubscriptions | length(@)' --output text 2>/dev/null || echo "0")
    if [ "$STANDARDS_COUNT" -gt 0 ] 2>/dev/null; then
        score_item "detection" "Security Hub standards" "true" 5 "$STANDARDS_COUNT standard(s) enabled"
    else
        score_item "detection" "Security Hub standards" "false" 5 "No standards enabled"
    fi
else
    score_item "detection" "Security Hub standards" "false" 5 "Security Hub not enabled (Lab 03)"
fi

echo ""

# ============================================================
# PILLAR 5: COMPLIANCE (15 points)
# ============================================================
echo "=============================================="
echo -e "${BLUE}COMPLIANCE (0/$COMPLIANCE_MAX)${NC}"
echo "=============================================="

# Check Config recorder running
CONFIG_STATUS=$(aws configservice describe-configuration-recorder-status --query 'ConfigurationRecordersStatus[0].recording' --output text 2>/dev/null)
if [ "$CONFIG_STATUS" = "True" ]; then
    score_item "compliance" "Config recorder" "true" 5 "Recording resource changes"
else
    score_item "compliance" "Config recorder" "false" 5 "Not recording (Lab 04)"
fi

# Check Config rules >= 3
CONFIG_RULES=$(aws configservice describe-config-rules --query 'ConfigRules | length(@)' --output text 2>/dev/null || echo "0")
if [ "$CONFIG_RULES" -ge 3 ] 2>/dev/null; then
    score_item "compliance" "Config rules" "true" 5 "$CONFIG_RULES rules active (need 3+)"
else
    score_item "compliance" "Config rules" "false" 5 "$CONFIG_RULES rules (need 3+, Lab 04)"
fi

# Check Access Analyzer (reuse from identity pillar)
if [ "$ANALYZER_COUNT" -gt 0 ] 2>/dev/null; then
    score_item "compliance" "Access Analyzer" "true" 5 "Active analyzer found"
else
    score_item "compliance" "Access Analyzer" "false" 5 "No active analyzer (Lab 04)"
fi

echo ""

# ============================================================
# FINAL SCORE
# ============================================================
TOTAL_SCORE=$((IDENTITY_SCORE + NETWORK_SCORE + DATA_SCORE + DETECTION_SCORE + COMPLIANCE_SCORE))
MAX_SCORE=100

echo "=============================================="
echo "  MISSION SCORE"
echo "=============================================="
echo ""

# Pillar breakdown
printf "  %-14s %s\n" "Identity:" "${IDENTITY_SCORE}/${IDENTITY_MAX}"
printf "  %-14s %s\n" "Network:" "${NETWORK_SCORE}/${NETWORK_MAX}"
printf "  %-14s %s\n" "Data:" "${DATA_SCORE}/${DATA_MAX}"
printf "  %-14s %s\n" "Detection:" "${DETECTION_SCORE}/${DETECTION_MAX}"
printf "  %-14s %s\n" "Compliance:" "${COMPLIANCE_SCORE}/${COMPLIANCE_MAX}"
echo "  ──────────────────────"
echo -e "  ${CYAN}TOTAL: $TOTAL_SCORE / $MAX_SCORE${NC}"
echo ""

# Progress bar
BAR_WIDTH=40
FILLED=$((TOTAL_SCORE * BAR_WIDTH / MAX_SCORE))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
if [ "$FILLED" -gt 0 ]; then
    BAR=$(printf '%0.s█' $(seq 1 $FILLED))
fi
SPACE=""
if [ "$EMPTY" -gt 0 ]; then
    SPACE=$(printf '%0.s░' $(seq 1 $EMPTY))
fi
echo -e "  [${GREEN}${BAR}${NC}${SPACE}] ${TOTAL_SCORE}%"
echo ""

# Status message
if [ "$TOTAL_SCORE" -eq 100 ]; then
    echo -e "${GREEN}MISSION COMPLETE. Account fully secured.${NC}"
elif [ "$TOTAL_SCORE" -ge 80 ]; then
    echo -e "${GREEN}Almost there. A few gaps remain.${NC}"
elif [ "$TOTAL_SCORE" -ge 60 ]; then
    echo -e "${YELLOW}Good progress. Keep enabling security services.${NC}"
elif [ "$TOTAL_SCORE" -ge 40 ]; then
    echo -e "${YELLOW}Halfway there. Detection and compliance are next.${NC}"
elif [ "$TOTAL_SCORE" -ge 20 ]; then
    echo -e "${RED}Early stages. Complete Lab 02 to build momentum.${NC}"
else
    echo -e "${RED}Account is at risk. Start with Lab 01 to assess your baseline.${NC}"
fi

echo ""
