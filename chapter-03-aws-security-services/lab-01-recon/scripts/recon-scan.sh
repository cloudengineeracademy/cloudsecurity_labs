#!/bin/bash

# Lab 01: Recon Scan — Educational 5-Pillar Security Assessment
# Read-only scan with explanations for each check

echo ""
echo "=============================================="
echo "  RECON SCAN: 5-Pillar Security Assessment"
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
    echo "Run: aws configure"
    exit 1
fi

echo "Account: $ACCOUNT_ID"
echo "Region:  $(aws configure get region 2>/dev/null || echo 'not set')"
echo "Date:    $(date)"
echo ""
echo "This scan is READ-ONLY. No resources will be created."
echo ""

TOTAL_PASS=0
TOTAL_CHECKS=0

recon_check() {
    local pillar="$1"
    local name="$2"
    local status="$3"
    local why="$4"
    local fix="$5"

    ((TOTAL_CHECKS++))

    if [ "$status" = "pass" ]; then
        echo -e "  ${GREEN}[PASS]${NC} $name"
        ((TOTAL_PASS++))
    elif [ "$status" = "warn" ]; then
        echo -e "  ${YELLOW}[WARN]${NC} $name"
    else
        echo -e "  ${RED}[FAIL]${NC} $name"
    fi
    echo -e "         ${YELLOW}Why:${NC} $why"
    echo -e "         ${BLUE}Fix:${NC} $fix"
    echo ""
}

# ============================================================
# PILLAR 1: IDENTITY
# ============================================================
echo "=============================================="
echo -e "${BLUE}PILLAR 1: IDENTITY${NC}"
echo "=============================================="
echo ""
echo "  Identity controls determine WHO can access your account"
echo "  and WHAT they can do. Weak identity = open front door."
echo ""

# Password policy
MIN_LEN=$(aws iam get-account-password-policy --query 'PasswordPolicy.MinimumPasswordLength' --output text 2>/dev/null)
if [ -n "$MIN_LEN" ] && [ "$MIN_LEN" != "None" ] && [ "$MIN_LEN" -ge 14 ] 2>/dev/null; then
    recon_check "identity" "Password policy (min length $MIN_LEN)" "pass" \
        "Strong passwords are the first barrier against credential stuffing attacks." \
        "Already configured from Chapter 01."
else
    recon_check "identity" "Password policy (min length: ${MIN_LEN:-none})" "fail" \
        "Weak passwords are the #1 cause of credential compromise. The CIS Benchmark requires 14+." \
        "Set via IAM > Account settings > Password policy, or in the Project lab."
fi

# Root access keys
ROOT_KEYS=$(aws iam get-account-summary --query 'SummaryMap.AccountAccessKeysPresent' --output text 2>/dev/null || echo "1")
if [ "$ROOT_KEYS" = "0" ]; then
    recon_check "identity" "No root access keys" "pass" \
        "Root access keys grant unrestricted access. If leaked, the entire account is compromised." \
        "Already secured from Chapter 01."
else
    recon_check "identity" "Root access keys exist" "fail" \
        "Root access keys grant unrestricted access. The Capital One breach started with excessive permissions." \
        "Delete root access keys in IAM > Security credentials."
fi

# MFA on users
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
    recon_check "identity" "MFA on all IAM users ($USERS_WITH_MFA/$TOTAL_USERS)" "pass" \
        "MFA prevents account takeover even if passwords are stolen. Uber's breach exploited MFA fatigue." \
        "Already configured."
else
    recon_check "identity" "MFA on IAM users ($USERS_WITH_MFA/$TOTAL_USERS)" "fail" \
        "Without MFA, a stolen password = full account access. Uber's attacker exploited this." \
        "Enable MFA for each user in IAM, or in the Project lab."
fi

# Access Analyzer
ANALYZER_COUNT=$(aws accessanalyzer list-analyzers --query 'analyzers[?status==`ACTIVE`] | length(@)' --output text 2>/dev/null || echo "0")
if [ "$ANALYZER_COUNT" -gt 0 ] 2>/dev/null; then
    recon_check "identity" "IAM Access Analyzer active" "pass" \
        "Access Analyzer continuously monitors for resources shared with external entities." \
        "Already enabled."
else
    recon_check "identity" "IAM Access Analyzer not enabled" "fail" \
        "Without Access Analyzer, you won't know if an S3 bucket or IAM role is publicly accessible." \
        "Lab 04 will enable this."
fi

# ============================================================
# PILLAR 2: NETWORK
# ============================================================
echo "=============================================="
echo -e "${BLUE}PILLAR 2: NETWORK${NC}"
echo "=============================================="
echo ""
echo "  Network controls limit WHERE traffic can flow."
echo "  An open security group is like an unlocked door."
echo ""

# S3 Block Public Access
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
    recon_check "network" "S3 Block Public Access (4/4 enabled)" "pass" \
        "Account-level S3 block prevents accidental public bucket exposure. Capital One lost 106M records via S3." \
        "Already configured from Chapter 01."
else
    recon_check "network" "S3 Block Public Access ($BLOCK_COUNT/4 enabled)" "fail" \
        "Without this, any S3 bucket can be made public accidentally. Capital One lost 106M records this way." \
        "Enable all 4 settings in S3 > Block Public Access, or in the Project lab."
fi

# SSH security groups
SSH_OPEN=$(aws ec2 describe-security-groups \
    --query 'SecurityGroups[?IpPermissions[?FromPort==`22` && IpRanges[?CidrIp==`0.0.0.0/0`]]] | length(@)' \
    --output text 2>/dev/null || echo "0")

if [ "$SSH_OPEN" = "0" ]; then
    recon_check "network" "No SSH open to 0.0.0.0/0" "pass" \
        "Open SSH ports are the first thing attackers scan for. Automated bots probe port 22 constantly." \
        "No open SSH security groups found."
else
    recon_check "network" "$SSH_OPEN SGs allow SSH from 0.0.0.0/0" "fail" \
        "Open SSH = anyone on the internet can attempt to brute-force your instances." \
        "Restrict SSH to your IP only, or remove the rules in the Project lab."
fi

# Default VPC
DEFAULT_VPC=$(aws ec2 describe-vpcs --query 'Vpcs[?IsDefault==`true`].VpcId' --output text 2>/dev/null)
if [ -z "$DEFAULT_VPC" ] || [ "$DEFAULT_VPC" = "None" ]; then
    recon_check "network" "Default VPC reviewed (deleted)" "pass" \
        "The default VPC has permissive settings. Deleting or reviewing it reduces attack surface." \
        "Default VPC already removed."
else
    DEFAULT_INSTANCES=$(aws ec2 describe-instances \
        --filters "Name=vpc-id,Values=$DEFAULT_VPC" \
        --query 'Reservations[].Instances | length(@)' \
        --output text 2>/dev/null || echo "0")
    if [ "$DEFAULT_INSTANCES" = "0" ]; then
        recon_check "network" "Default VPC exists but unused" "pass" \
            "The default VPC has permissive settings, but it has no resources in it." \
            "Consider deleting it or ensure no resources are launched into it."
    else
        recon_check "network" "Default VPC has $DEFAULT_INSTANCES instances" "fail" \
            "The default VPC has overly permissive settings and active resources." \
            "Migrate resources to a custom VPC, or review in the Project lab."
    fi
fi

# ============================================================
# PILLAR 3: DATA
# ============================================================
echo "=============================================="
echo -e "${BLUE}PILLAR 3: DATA${NC}"
echo "=============================================="
echo ""
echo "  Data controls protect information at rest and in transit."
echo "  Encryption is your last line of defence if other controls fail."
echo ""

# KMS CMK
CMK_COUNT=0
for key_id in $(aws kms list-keys --query 'Keys[].KeyId' --output text 2>/dev/null); do
    key_mgr=$(aws kms describe-key --key-id "$key_id" --query 'KeyMetadata.KeyManager' --output text 2>/dev/null)
    if [ "$key_mgr" = "CUSTOMER" ]; then
        ((CMK_COUNT++))
    fi
done

if [ "$CMK_COUNT" -gt 0 ]; then
    recon_check "data" "KMS customer-managed key(s) ($CMK_COUNT)" "pass" \
        "CMKs give you control over encryption key rotation, access policies, and audit logging." \
        "Already created."
else
    recon_check "data" "No KMS customer-managed keys" "fail" \
        "Without CMKs, you rely on AWS-managed keys which you can't control or audit." \
        "Lab 02 will create a CMK for CloudTrail encryption."
fi

# CloudTrail encryption
TRAIL_NAME=$(aws cloudtrail describe-trails --query 'trailList[0].Name' --output text 2>/dev/null)
if [ -n "$TRAIL_NAME" ] && [ "$TRAIL_NAME" != "None" ]; then
    TRAIL_KMS=$(aws cloudtrail describe-trails --query 'trailList[0].KmsKeyId' --output text 2>/dev/null)
    if [ -n "$TRAIL_KMS" ] && [ "$TRAIL_KMS" != "None" ]; then
        recon_check "data" "CloudTrail KMS encrypted" "pass" \
            "KMS encryption protects audit logs from tampering. Without it, logs are SSE-S3 only." \
            "Already encrypted."
    else
        recon_check "data" "CloudTrail not KMS encrypted" "warn" \
            "Trail exists but uses default encryption. KMS gives you key control and audit capability." \
            "Lab 02 will add KMS encryption."
    fi
else
    recon_check "data" "No CloudTrail configured" "fail" \
        "Without CloudTrail, there is ZERO visibility into API activity. You're flying blind." \
        "Lab 02 will create and configure CloudTrail."
fi

# CloudTrail log validation
if [ -n "$TRAIL_NAME" ] && [ "$TRAIL_NAME" != "None" ]; then
    LOG_VALIDATION=$(aws cloudtrail describe-trails --query 'trailList[0].LogFileValidationEnabled' --output text 2>/dev/null)
    if [ "$LOG_VALIDATION" = "True" ]; then
        recon_check "data" "CloudTrail log validation enabled" "pass" \
            "Log validation creates digest files that detect tampering. Critical for forensic integrity." \
            "Already enabled."
    else
        recon_check "data" "CloudTrail log validation disabled" "fail" \
            "Without validation, an attacker could modify logs to cover their tracks." \
            "Lab 02 will enable this."
    fi
else
    recon_check "data" "CloudTrail log validation (no trail)" "fail" \
        "Can't validate logs that don't exist. CloudTrail is the foundation of detection." \
        "Lab 02 will create CloudTrail with validation enabled."
fi

# S3 encryption
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
    recon_check "data" "S3 bucket encryption (no buckets)" "pass" \
        "No buckets to check." \
        "N/A"
elif [ "$BUCKET_COUNT" -eq "$ENCRYPTED_COUNT" ]; then
    recon_check "data" "S3 bucket encryption ($ENCRYPTED_COUNT/$BUCKET_COUNT)" "pass" \
        "All buckets have default encryption enabled. Data at rest is protected." \
        "Already encrypted."
else
    recon_check "data" "S3 bucket encryption ($ENCRYPTED_COUNT/$BUCKET_COUNT)" "fail" \
        "Unencrypted buckets expose data if access controls fail. Encryption is the last defence." \
        "Enable default encryption on each bucket, or fix in the Project lab."
fi

# ============================================================
# PILLAR 4: DETECTION
# ============================================================
echo "=============================================="
echo -e "${BLUE}PILLAR 4: DETECTION${NC}"
echo "=============================================="
echo ""
echo "  Detection tells you WHEN something bad happens."
echo "  Without it, breaches go unnoticed for months."
echo ""

# CloudTrail enabled
if [ -n "$TRAIL_NAME" ] && [ "$TRAIL_NAME" != "None" ]; then
    recon_check "detection" "CloudTrail enabled ($TRAIL_NAME)" "pass" \
        "CloudTrail records every AWS API call. It's the single most important security service." \
        "Already enabled."
else
    recon_check "detection" "CloudTrail not enabled" "fail" \
        "Without CloudTrail, you have ZERO audit trail. Attackers can operate undetected." \
        "Lab 02 will enable CloudTrail."
fi

# CloudTrail multi-region
if [ -n "$TRAIL_NAME" ] && [ "$TRAIL_NAME" != "None" ]; then
    MULTI_REGION=$(aws cloudtrail describe-trails --query 'trailList[0].IsMultiRegionTrail' --output text 2>/dev/null)
    if [ "$MULTI_REGION" = "True" ]; then
        recon_check "detection" "CloudTrail multi-region" "pass" \
            "Multi-region trails catch activity in ANY region. Attackers often use unused regions." \
            "Already configured."
    else
        recon_check "detection" "CloudTrail single-region only" "fail" \
            "An attacker can operate in us-west-2 while you only monitor us-east-1." \
            "Lab 02 will enable multi-region logging."
    fi
else
    recon_check "detection" "CloudTrail multi-region (no trail)" "fail" \
        "Attackers deliberately use unusual regions to avoid detection." \
        "Lab 02 will create a multi-region trail."
fi

# CloudTrail logging status
if [ -n "$TRAIL_NAME" ] && [ "$TRAIL_NAME" != "None" ]; then
    IS_LOGGING=$(aws cloudtrail get-trail-status --name "$TRAIL_NAME" --query 'IsLogging' --output text 2>/dev/null)
    if [ "$IS_LOGGING" = "True" ]; then
        recon_check "detection" "CloudTrail actively logging" "pass" \
            "Trail is actively recording API calls right now." \
            "Already recording."
    else
        recon_check "detection" "CloudTrail not logging" "fail" \
            "Trail exists but is stopped. No events are being recorded." \
            "Start logging with: aws cloudtrail start-logging --name $TRAIL_NAME"
    fi
else
    recon_check "detection" "CloudTrail logging (no trail)" "fail" \
        "No trail means no logging. This is the #1 gap to close." \
        "Lab 02 will create and start CloudTrail."
fi

# GuardDuty
GD_DETECTORS=$(aws guardduty list-detectors --query 'DetectorIds' --output text 2>/dev/null)
if [ -n "$GD_DETECTORS" ] && [ "$GD_DETECTORS" != "None" ] && [ "$GD_DETECTORS" != "" ]; then
    GD_ID=$(echo "$GD_DETECTORS" | awk '{print $1}')
    GD_STATUS=$(aws guardduty get-detector --detector-id "$GD_ID" --query 'Status' --output text 2>/dev/null)
    if [ "$GD_STATUS" = "ENABLED" ]; then
        recon_check "detection" "GuardDuty enabled" "pass" \
            "GuardDuty uses ML and threat intelligence to detect compromised instances, credentials, and S3 access." \
            "Already enabled."
    else
        recon_check "detection" "GuardDuty disabled" "fail" \
            "Detector exists but is disabled. No threat analysis is running." \
            "Lab 03 will enable GuardDuty."
    fi
else
    recon_check "detection" "GuardDuty not enabled" "fail" \
        "GuardDuty would have detected the Capital One breach pattern (unusual S3 access from an instance)." \
        "Lab 03 will enable GuardDuty (30-day free trial)."
fi

# Security Hub
SH_STATUS=$(aws securityhub describe-hub --query 'HubArn' --output text 2>/dev/null)
if [ -n "$SH_STATUS" ] && [ "$SH_STATUS" != "None" ]; then
    recon_check "detection" "Security Hub enabled" "pass" \
        "Security Hub aggregates findings from GuardDuty, Config, and other services into one dashboard." \
        "Already enabled."
else
    recon_check "detection" "Security Hub not enabled" "fail" \
        "Without Security Hub, findings are scattered across services. You need a single pane of glass." \
        "Lab 03 will enable Security Hub (30-day free trial)."
fi

# Security Hub standards
if [ -n "$SH_STATUS" ] && [ "$SH_STATUS" != "None" ]; then
    STANDARDS_COUNT=$(aws securityhub get-enabled-standards --query 'StandardsSubscriptions | length(@)' --output text 2>/dev/null || echo "0")
    if [ "$STANDARDS_COUNT" -gt 0 ] 2>/dev/null; then
        recon_check "detection" "Security Hub standards ($STANDARDS_COUNT enabled)" "pass" \
            "Standards like CIS Benchmarks and AWS Foundational Best Practices run automated compliance checks." \
            "Already enabled."
    else
        recon_check "detection" "Security Hub no standards enabled" "fail" \
            "Security Hub is active but no standards are checking your configuration." \
            "Lab 03 will enable security standards."
    fi
else
    recon_check "detection" "Security Hub standards (hub not enabled)" "fail" \
        "Standards provide continuous automated security checks against industry benchmarks." \
        "Lab 03 will enable Security Hub with standards."
fi

# ============================================================
# PILLAR 5: COMPLIANCE
# ============================================================
echo "=============================================="
echo -e "${BLUE}PILLAR 5: COMPLIANCE${NC}"
echo "=============================================="
echo ""
echo "  Compliance ensures your security STAYS configured."
echo "  Without continuous monitoring, drift happens fast."
echo ""

# Config recorder
CONFIG_STATUS=$(aws configservice describe-configuration-recorder-status --query 'ConfigurationRecordersStatus[0].recording' --output text 2>/dev/null)
if [ "$CONFIG_STATUS" = "True" ]; then
    recon_check "compliance" "Config recorder running" "pass" \
        "AWS Config records every resource change. If someone modifies a security group, you'll know." \
        "Already running."
else
    recon_check "compliance" "Config recorder not running" "fail" \
        "Without Config, resource changes go untracked. Someone could open a security group and you'd never know." \
        "Lab 04 will enable AWS Config."
fi

# Config rules
CONFIG_RULES=$(aws configservice describe-config-rules --query 'ConfigRules | length(@)' --output text 2>/dev/null || echo "0")
if [ "$CONFIG_RULES" -ge 3 ] 2>/dev/null; then
    recon_check "compliance" "Config rules ($CONFIG_RULES active)" "pass" \
        "Config rules automatically flag non-compliant resources. This is proactive security." \
        "Already configured."
else
    recon_check "compliance" "Config rules ($CONFIG_RULES active, need 3+)" "fail" \
        "Without rules, Config records changes but doesn't evaluate compliance." \
        "Lab 04 will add rules for SSH, encryption, and CloudTrail."
fi

# Access Analyzer (also identity pillar)
if [ "$ANALYZER_COUNT" -gt 0 ] 2>/dev/null; then
    recon_check "compliance" "IAM Access Analyzer active" "pass" \
        "Access Analyzer finds resources shared outside your account (public S3, cross-account roles)." \
        "Already enabled."
else
    recon_check "compliance" "IAM Access Analyzer not enabled" "fail" \
        "Without Access Analyzer, publicly shared resources go undetected." \
        "Lab 04 will enable Access Analyzer."
fi

# ============================================================
# SUMMARY
# ============================================================
echo "=============================================="
echo "  RECON SUMMARY"
echo "=============================================="
echo ""
echo -e "  Checks passed: ${GREEN}$TOTAL_PASS${NC} / $TOTAL_CHECKS"
echo ""

if [ "$TOTAL_PASS" -eq "$TOTAL_CHECKS" ]; then
    echo -e "${GREEN}  All checks passing. Your account is well-secured.${NC}"
elif [ "$TOTAL_PASS" -ge 12 ]; then
    echo -e "${GREEN}  Strong posture. A few gaps remain.${NC}"
elif [ "$TOTAL_PASS" -ge 8 ]; then
    echo -e "${YELLOW}  Good start. Detection and compliance pillars need work.${NC}"
elif [ "$TOTAL_PASS" -ge 4 ]; then
    echo -e "${YELLOW}  Foundation set. Most security services still need enabling.${NC}"
else
    echo -e "${RED}  Significant gaps. Work through Labs 02-04 to close them.${NC}"
fi

echo ""
echo "  Next step: Run the mission status to see your score."
echo "    bash scripts/mission-status.sh"
echo ""

# Show badge
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../scripts/achievements.sh"
show_badge "recon"
