#!/bin/bash

# Project: Gap Analysis — Detailed report with hints (not answers)

echo ""
echo "=============================================="
echo "  GAP ANALYSIS: What's Still Missing?"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    exit 1
fi

echo "Account: $ACCOUNT_ID"
echo "Date: $(date)"
echo ""
echo "This analysis shows remaining gaps with hints."
echo "The goal: fix each gap to reach 100/100."
echo ""

GAPS=0

show_gap() {
    local pillar="$1"
    local name="$2"
    local why="$3"
    local hint="$4"

    ((GAPS++))
    echo -e "  ${RED}GAP $GAPS:${NC} [$pillar] $name"
    echo -e "    ${YELLOW}Why:${NC}  $why"
    echo -e "    ${BLUE}Hint:${NC} $hint"
    echo ""
}

show_pass() {
    local pillar="$1"
    local name="$2"

    echo -e "  ${GREEN}[PASS]${NC} [$pillar] $name"
}

# ============================================================
# IDENTITY PILLAR
# ============================================================
echo "=============================================="
echo -e "${BLUE}IDENTITY (20 points)${NC}"
echo "=============================================="
echo ""

# Password policy
MIN_LEN=$(aws iam get-account-password-policy --query 'PasswordPolicy.MinimumPasswordLength' --output text 2>/dev/null)
if [ -n "$MIN_LEN" ] && [ "$MIN_LEN" != "None" ] && [ "$MIN_LEN" -ge 14 ] 2>/dev/null; then
    show_pass "IDENTITY" "Password policy (min $MIN_LEN)"
else
    show_gap "IDENTITY" "Password policy needs min length 14+" \
        "CIS Benchmark requires 14+ character minimum. Current: ${MIN_LEN:-not set}" \
        "Look at the 'aws iam update-account-password-policy' command. Set --minimum-password-length to 14 or higher."
fi

# Root access keys
ROOT_KEYS=$(aws iam get-account-summary --query 'SummaryMap.AccountAccessKeysPresent' --output text 2>/dev/null || echo "1")
if [ "$ROOT_KEYS" = "0" ]; then
    show_pass "IDENTITY" "No root access keys"
else
    show_gap "IDENTITY" "Root access keys exist" \
        "Root keys grant unrestricted access. If leaked, the entire account is compromised." \
        "Log in as root to the AWS Console. Navigate to Security Credentials. Delete the access keys."
fi

# MFA on users
TOTAL_USERS=$(aws iam list-users --query 'Users | length(@)' --output text 2>/dev/null || echo "0")
USERS_WITH_MFA=0
USERS_WITHOUT_MFA=""
if [ "$TOTAL_USERS" -gt 0 ] 2>/dev/null; then
    for user in $(aws iam list-users --query 'Users[].UserName' --output text 2>/dev/null); do
        mfa=$(aws iam list-mfa-devices --user-name "$user" --query 'MFADevices[0]' --output text 2>/dev/null)
        if [ -n "$mfa" ] && [ "$mfa" != "None" ]; then
            ((USERS_WITH_MFA++))
        else
            USERS_WITHOUT_MFA="$USERS_WITHOUT_MFA $user"
        fi
    done
fi

if [ "$TOTAL_USERS" -eq 0 ] || { [ "$TOTAL_USERS" -gt 0 ] && [ "$TOTAL_USERS" -eq "$USERS_WITH_MFA" ]; }; then
    show_pass "IDENTITY" "MFA on all users ($USERS_WITH_MFA/$TOTAL_USERS)"
else
    show_gap "IDENTITY" "MFA missing on some users ($USERS_WITH_MFA/$TOTAL_USERS)" \
        "Without MFA, a stolen password = full access. Users without MFA:$USERS_WITHOUT_MFA" \
        "Enable MFA for each user via the IAM Console or use 'aws iam enable-mfa-device'."
fi

# Access Analyzer
ANALYZER_COUNT=$(aws accessanalyzer list-analyzers --query 'analyzers[?status==`ACTIVE`] | length(@)' --output text 2>/dev/null || echo "0")
if [ "$ANALYZER_COUNT" -gt 0 ] 2>/dev/null; then
    show_pass "IDENTITY" "Access Analyzer active"
else
    show_gap "IDENTITY" "Access Analyzer not enabled" \
        "Without it, publicly shared resources go undetected." \
        "Lab 04's enable-compliance.sh should have created this. Re-run it."
fi

echo ""

# ============================================================
# NETWORK PILLAR
# ============================================================
echo "=============================================="
echo -e "${BLUE}NETWORK (15 points)${NC}"
echo "=============================================="
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
    show_pass "NETWORK" "S3 Block Public Access (4/4)"
else
    show_gap "NETWORK" "S3 Block Public Access ($BLOCK_COUNT/4)" \
        "Without all 4 blocks, S3 buckets can be made public accidentally." \
        "Use 'aws s3control put-public-access-block' with all four settings set to true."
fi

# SSH security groups
SSH_OPEN=$(aws ec2 describe-security-groups \
    --query 'SecurityGroups[?IpPermissions[?FromPort==`22` && IpRanges[?CidrIp==`0.0.0.0/0`]]].{ID:GroupId,Name:GroupName}' \
    --output text 2>/dev/null)

if [ -z "$SSH_OPEN" ] || [ "$SSH_OPEN" = "None" ]; then
    show_pass "NETWORK" "No open SSH security groups"
else
    show_gap "NETWORK" "Security groups with SSH open to 0.0.0.0/0" \
        "Open SSH ports are the #1 target for automated attacks." \
        "Use 'aws ec2 revoke-security-group-ingress' to remove the 0.0.0.0/0 SSH rules. SGs: $SSH_OPEN"
fi

# Default VPC
DEFAULT_VPC=$(aws ec2 describe-vpcs --query 'Vpcs[?IsDefault==`true`].VpcId' --output text 2>/dev/null)
if [ -z "$DEFAULT_VPC" ] || [ "$DEFAULT_VPC" = "None" ]; then
    show_pass "NETWORK" "Default VPC reviewed (deleted)"
else
    DEFAULT_INSTANCES=$(aws ec2 describe-instances \
        --filters "Name=vpc-id,Values=$DEFAULT_VPC" \
        --query 'Reservations[].Instances | length(@)' \
        --output text 2>/dev/null || echo "0")
    if [ "$DEFAULT_INSTANCES" = "0" ]; then
        show_pass "NETWORK" "Default VPC exists but unused"
    else
        show_gap "NETWORK" "Default VPC has $DEFAULT_INSTANCES instances" \
            "The default VPC has overly permissive settings." \
            "Migrate resources to a custom VPC, or review security groups in the default VPC."
    fi
fi

echo ""

# ============================================================
# DATA PILLAR
# ============================================================
echo "=============================================="
echo -e "${BLUE}DATA (20 points)${NC}"
echo "=============================================="
echo ""

# KMS CMK
CUSTOMER_KEYS=0
for key_id in $(aws kms list-keys --query 'Keys[].KeyId' --output text 2>/dev/null); do
    key_mgr=$(aws kms describe-key --key-id "$key_id" --query 'KeyMetadata.KeyManager' --output text 2>/dev/null)
    if [ "$key_mgr" = "CUSTOMER" ]; then
        ((CUSTOMER_KEYS++))
    fi
done

if [ "$CUSTOMER_KEYS" -gt 0 ]; then
    show_pass "DATA" "KMS customer-managed key ($CUSTOMER_KEYS)"
else
    show_gap "DATA" "No KMS customer-managed keys" \
        "CMKs give you encryption key control and audit capability." \
        "Lab 02's setup-cloudtrail.sh should have created this. Re-run it."
fi

# CloudTrail checks
TRAIL_NAME=$(aws cloudtrail describe-trails --query 'trailList[0].Name' --output text 2>/dev/null)
if [ -n "$TRAIL_NAME" ] && [ "$TRAIL_NAME" != "None" ]; then
    # Encryption
    TRAIL_KMS=$(aws cloudtrail describe-trails --query 'trailList[0].KmsKeyId' --output text 2>/dev/null)
    if [ -n "$TRAIL_KMS" ] && [ "$TRAIL_KMS" != "None" ]; then
        show_pass "DATA" "CloudTrail KMS encrypted"
    else
        show_gap "DATA" "CloudTrail not KMS encrypted" \
            "Without KMS, you can't control or audit who reads the logs." \
            "Re-run Lab 02 setup or use 'aws cloudtrail update-trail --kms-key-id <key-arn>'."
    fi

    # Log validation
    LOG_VAL=$(aws cloudtrail describe-trails --query 'trailList[0].LogFileValidationEnabled' --output text 2>/dev/null)
    if [ "$LOG_VAL" = "True" ]; then
        show_pass "DATA" "CloudTrail log validation"
    else
        show_gap "DATA" "CloudTrail log validation disabled" \
            "Without validation, tampered logs are undetectable." \
            "Use 'aws cloudtrail update-trail --enable-log-file-validation'."
    fi
else
    show_gap "DATA" "No CloudTrail configured" \
        "CloudTrail is the foundation of all detection." \
        "Run Lab 02's setup-cloudtrail.sh."
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

if [ "$BUCKET_COUNT" -eq 0 ] || [ "$BUCKET_COUNT" -eq "$ENCRYPTED_COUNT" ]; then
    show_pass "DATA" "S3 bucket encryption ($ENCRYPTED_COUNT/$BUCKET_COUNT)"
else
    show_gap "DATA" "S3 bucket encryption ($ENCRYPTED_COUNT/$BUCKET_COUNT)" \
        "Unencrypted buckets expose data if access controls fail." \
        "Use 'aws s3api put-bucket-encryption' to enable default encryption on each bucket."
fi

echo ""

# ============================================================
# DETECTION + COMPLIANCE (check but don't detail — should be done from labs)
# ============================================================
echo "=============================================="
echo -e "${BLUE}DETECTION + COMPLIANCE (checked by labs)${NC}"
echo "=============================================="
echo ""
echo "  If Labs 02-04 were completed, these should be green."
echo "  Run 'bash scripts/mission-status.sh' for the full breakdown."
echo ""

# ============================================================
# SUMMARY
# ============================================================
echo "=============================================="
echo "  GAP ANALYSIS SUMMARY"
echo "=============================================="
echo ""

if [ "$GAPS" -eq 0 ]; then
    echo -e "  ${GREEN}No gaps found. You may be ready for 100/100.${NC}"
    echo "  Run final verification to confirm:"
    echo "    bash project-baseline-lockdown/scripts/final-verification.sh"
else
    echo -e "  ${RED}$GAPS gap(s) found.${NC}"
    echo ""
    echo "  Fix each gap using the hints above, then run:"
    echo "    bash project-baseline-lockdown/scripts/final-verification.sh"
fi
echo ""
