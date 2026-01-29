#!/bin/bash

# Project: Final Verification — Full 100-point check + victory condition

echo ""
echo "=============================================="
echo "  FINAL VERIFICATION: Mission Status"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[1;36m'
NC='\033[0m'

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    exit 1
fi

echo "Account: $ACCOUNT_ID"
echo "Date: $(date)"
echo ""

# Run the mission status engine to get the score
# We duplicate the logic here for the victory condition
IDENTITY_SCORE=0
NETWORK_SCORE=0
DATA_SCORE=0
DETECTION_SCORE=0
COMPLIANCE_SCORE=0

check_item() {
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

# === IDENTITY ===
echo -e "${BLUE}IDENTITY${NC}"
MIN_LEN=$(aws iam get-account-password-policy --query 'PasswordPolicy.MinimumPasswordLength' --output text 2>/dev/null)
if [ -n "$MIN_LEN" ] && [ "$MIN_LEN" != "None" ] && [ "$MIN_LEN" -ge 14 ] 2>/dev/null; then
    check_item "identity" "Password policy" "true" 5 "Min length $MIN_LEN"
else
    check_item "identity" "Password policy" "false" 5 "Need 14+ (current: ${MIN_LEN:-none})"
fi

ROOT_KEYS=$(aws iam get-account-summary --query 'SummaryMap.AccountAccessKeysPresent' --output text 2>/dev/null || echo "1")
if [ "$ROOT_KEYS" = "0" ]; then
    check_item "identity" "No root access keys" "true" 5 "Secure"
else
    check_item "identity" "No root access keys" "false" 5 "Root keys exist"
fi

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
    check_item "identity" "MFA on users" "true" 5 "$USERS_WITH_MFA/$TOTAL_USERS"
else
    check_item "identity" "MFA on users" "false" 5 "$USERS_WITH_MFA/$TOTAL_USERS"
fi

ANALYZER_COUNT=$(aws accessanalyzer list-analyzers --query 'analyzers[?status==`ACTIVE`] | length(@)' --output text 2>/dev/null || echo "0")
if [ "$ANALYZER_COUNT" -gt 0 ] 2>/dev/null; then
    check_item "identity" "Access Analyzer" "true" 5 "Active"
else
    check_item "identity" "Access Analyzer" "false" 5 "Not enabled"
fi
echo ""

# === NETWORK ===
echo -e "${BLUE}NETWORK${NC}"
S3_BLOCK_STATUS=$(aws s3control get-public-access-block --account-id "$ACCOUNT_ID" --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]' --output text 2>/dev/null)
BLOCK_COUNT=0
if [ -n "$S3_BLOCK_STATUS" ]; then
    for val in $S3_BLOCK_STATUS; do
        if [ "$val" = "True" ]; then ((BLOCK_COUNT++)); fi
    done
fi
if [ "$BLOCK_COUNT" -eq 4 ]; then
    check_item "network" "S3 Block Public Access" "true" 5 "4/4 blocks"
else
    check_item "network" "S3 Block Public Access" "false" 5 "$BLOCK_COUNT/4 blocks"
fi

SSH_OPEN_SG=$(aws ec2 describe-security-groups \
    --query 'SecurityGroups[?IpPermissions[?FromPort==`22` && IpRanges[?CidrIp==`0.0.0.0/0`]]] | length(@)' \
    --output text 2>/dev/null || echo "0")
if [ "$SSH_OPEN_SG" = "0" ]; then
    check_item "network" "No open SSH SGs" "true" 5 "Clean"
else
    check_item "network" "No open SSH SGs" "false" 5 "$SSH_OPEN_SG open"
fi

DEFAULT_VPC=$(aws ec2 describe-vpcs --query 'Vpcs[?IsDefault==`true`].VpcId' --output text 2>/dev/null)
if [ -z "$DEFAULT_VPC" ] || [ "$DEFAULT_VPC" = "None" ]; then
    check_item "network" "Default VPC reviewed" "true" 5 "Deleted"
else
    DEFAULT_INSTANCES=$(aws ec2 describe-instances \
        --filters "Name=vpc-id,Values=$DEFAULT_VPC" \
        --query 'Reservations[].Instances | length(@)' --output text 2>/dev/null || echo "0")
    if [ "$DEFAULT_INSTANCES" = "0" ]; then
        check_item "network" "Default VPC reviewed" "true" 5 "Unused"
    else
        check_item "network" "Default VPC reviewed" "false" 5 "$DEFAULT_INSTANCES instances"
    fi
fi
echo ""

# === DATA ===
echo -e "${BLUE}DATA${NC}"
CUSTOMER_KEYS=0
for key_id in $(aws kms list-keys --query 'Keys[].KeyId' --output text 2>/dev/null); do
    key_mgr=$(aws kms describe-key --key-id "$key_id" --query 'KeyMetadata.KeyManager' --output text 2>/dev/null)
    if [ "$key_mgr" = "CUSTOMER" ]; then ((CUSTOMER_KEYS++)); fi
done
if [ "$CUSTOMER_KEYS" -gt 0 ]; then
    check_item "data" "KMS CMK exists" "true" 5 "$CUSTOMER_KEYS key(s)"
else
    check_item "data" "KMS CMK exists" "false" 5 "None"
fi

TRAIL_NAME=$(aws cloudtrail describe-trails --query 'trailList[0].Name' --output text 2>/dev/null)
if [ -n "$TRAIL_NAME" ] && [ "$TRAIL_NAME" != "None" ]; then
    TRAIL_KMS=$(aws cloudtrail describe-trails --query 'trailList[0].KmsKeyId' --output text 2>/dev/null)
    if [ -n "$TRAIL_KMS" ] && [ "$TRAIL_KMS" != "None" ]; then
        check_item "data" "CloudTrail encrypted" "true" 5 "KMS"
    else
        check_item "data" "CloudTrail encrypted" "false" 5 "No KMS"
    fi

    LOG_VAL=$(aws cloudtrail describe-trails --query 'trailList[0].LogFileValidationEnabled' --output text 2>/dev/null)
    if [ "$LOG_VAL" = "True" ]; then
        check_item "data" "CloudTrail log validation" "true" 5 "Enabled"
    else
        check_item "data" "CloudTrail log validation" "false" 5 "Disabled"
    fi
else
    check_item "data" "CloudTrail encrypted" "false" 5 "No trail"
    check_item "data" "CloudTrail log validation" "false" 5 "No trail"
fi

BUCKETS=$(aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null)
BUCKET_COUNT=0
ENCRYPTED_COUNT=0
for bucket in $BUCKETS; do
    ((BUCKET_COUNT++))
    enc=$(aws s3api get-bucket-encryption --bucket "$bucket" 2>/dev/null)
    if [ $? -eq 0 ]; then ((ENCRYPTED_COUNT++)); fi
done
if [ "$BUCKET_COUNT" -eq 0 ] || [ "$BUCKET_COUNT" -eq "$ENCRYPTED_COUNT" ]; then
    check_item "data" "S3 bucket encryption" "true" 5 "$ENCRYPTED_COUNT/$BUCKET_COUNT"
else
    check_item "data" "S3 bucket encryption" "false" 5 "$ENCRYPTED_COUNT/$BUCKET_COUNT"
fi
echo ""

# === DETECTION ===
echo -e "${BLUE}DETECTION${NC}"
if [ -n "$TRAIL_NAME" ] && [ "$TRAIL_NAME" != "None" ]; then
    check_item "detection" "CloudTrail enabled" "true" 5 "$TRAIL_NAME"

    MULTI_REGION=$(aws cloudtrail describe-trails --query 'trailList[0].IsMultiRegionTrail' --output text 2>/dev/null)
    if [ "$MULTI_REGION" = "True" ]; then
        check_item "detection" "CloudTrail multi-region" "true" 5 "All regions"
    else
        check_item "detection" "CloudTrail multi-region" "false" 5 "Single region"
    fi

    IS_LOGGING=$(aws cloudtrail get-trail-status --name "$TRAIL_NAME" --query 'IsLogging' --output text 2>/dev/null)
    if [ "$IS_LOGGING" = "True" ]; then
        check_item "detection" "CloudTrail logging" "true" 5 "Active"
    else
        check_item "detection" "CloudTrail logging" "false" 5 "Stopped"
    fi
else
    check_item "detection" "CloudTrail enabled" "false" 5 "No trail"
    check_item "detection" "CloudTrail multi-region" "false" 5 "No trail"
    check_item "detection" "CloudTrail logging" "false" 5 "No trail"
fi

GD_DETECTORS=$(aws guardduty list-detectors --query 'DetectorIds' --output text 2>/dev/null)
if [ -n "$GD_DETECTORS" ] && [ "$GD_DETECTORS" != "None" ] && [ "$GD_DETECTORS" != "" ]; then
    GD_ID=$(echo "$GD_DETECTORS" | awk '{print $1}')
    GD_STATUS=$(aws guardduty get-detector --detector-id "$GD_ID" --query 'Status' --output text 2>/dev/null)
    if [ "$GD_STATUS" = "ENABLED" ]; then
        check_item "detection" "GuardDuty enabled" "true" 5 "Active"
    else
        check_item "detection" "GuardDuty enabled" "false" 5 "Disabled"
    fi
else
    check_item "detection" "GuardDuty enabled" "false" 5 "Not enabled"
fi

SH_STATUS=$(aws securityhub describe-hub --query 'HubArn' --output text 2>/dev/null)
if [ -n "$SH_STATUS" ] && [ "$SH_STATUS" != "None" ]; then
    check_item "detection" "Security Hub enabled" "true" 5 "Active"
    STANDARDS_COUNT=$(aws securityhub get-enabled-standards --query 'StandardsSubscriptions | length(@)' --output text 2>/dev/null || echo "0")
    if [ "$STANDARDS_COUNT" -gt 0 ] 2>/dev/null; then
        check_item "detection" "Security Hub standards" "true" 5 "$STANDARDS_COUNT standard(s)"
    else
        check_item "detection" "Security Hub standards" "false" 5 "None"
    fi
else
    check_item "detection" "Security Hub enabled" "false" 5 "Not enabled"
    check_item "detection" "Security Hub standards" "false" 5 "Hub not enabled"
fi
echo ""

# === COMPLIANCE ===
echo -e "${BLUE}COMPLIANCE${NC}"
CONFIG_STATUS=$(aws configservice describe-configuration-recorder-status --query 'ConfigurationRecordersStatus[0].recording' --output text 2>/dev/null)
if [ "$CONFIG_STATUS" = "True" ]; then
    check_item "compliance" "Config recorder" "true" 5 "Recording"
else
    check_item "compliance" "Config recorder" "false" 5 "Not recording"
fi

CONFIG_RULES=$(aws configservice describe-config-rules --query 'ConfigRules | length(@)' --output text 2>/dev/null || echo "0")
if [ "$CONFIG_RULES" -ge 3 ] 2>/dev/null; then
    check_item "compliance" "Config rules" "true" 5 "$CONFIG_RULES rules"
else
    check_item "compliance" "Config rules" "false" 5 "$CONFIG_RULES rules"
fi

if [ "$ANALYZER_COUNT" -gt 0 ] 2>/dev/null; then
    check_item "compliance" "Access Analyzer" "true" 5 "Active"
else
    check_item "compliance" "Access Analyzer" "false" 5 "Not enabled"
fi
echo ""

# ============================================================
# FINAL SCORE
# ============================================================
TOTAL_SCORE=$((IDENTITY_SCORE + NETWORK_SCORE + DATA_SCORE + DETECTION_SCORE + COMPLIANCE_SCORE))

echo "=============================================="
echo "  FINAL MISSION SCORE"
echo "=============================================="
echo ""
printf "  %-14s %s\n" "Identity:" "${IDENTITY_SCORE}/20"
printf "  %-14s %s\n" "Network:" "${NETWORK_SCORE}/15"
printf "  %-14s %s\n" "Data:" "${DATA_SCORE}/20"
printf "  %-14s %s\n" "Detection:" "${DETECTION_SCORE}/30"
printf "  %-14s %s\n" "Compliance:" "${COMPLIANCE_SCORE}/15"
echo "  ──────────────────────"
echo -e "  ${CYAN}TOTAL: $TOTAL_SCORE / 100${NC}"
echo ""

# Progress bar
BAR_WIDTH=40
FILLED=$((TOTAL_SCORE * BAR_WIDTH / 100))
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

# Victory condition
if [ "$TOTAL_SCORE" -eq 100 ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    source "$SCRIPT_DIR/../../scripts/achievements.sh"
    show_badge "mission_complete"

    echo ""
    echo "  Generate your Security Baseline Report:"
    echo "    bash project-baseline-lockdown/scripts/generate-report.sh"
elif [ "$TOTAL_SCORE" -ge 90 ]; then
    echo -e "${GREEN}Almost perfect. Review the gaps above for the final points.${NC}"
elif [ "$TOTAL_SCORE" -ge 75 ]; then
    echo -e "${YELLOW}Strong progress. Run the gap analysis for detailed hints:${NC}"
    echo "    bash project-baseline-lockdown/scripts/gap-analysis.sh"
else
    echo -e "${RED}Keep going. Complete the remaining labs and fix identified gaps.${NC}"
fi

echo ""
