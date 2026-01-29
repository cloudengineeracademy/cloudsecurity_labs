#!/bin/bash

# Project: Generate Security Baseline Report

echo ""
echo "=============================================="
echo "  GENERATE: Security Baseline Report"
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
DATE=$(date '+%Y-%m-%d %H:%M:%S')

if [ -z "$ACCOUNT_ID" ]; then
    echo -e "${RED}ERROR: AWS credentials not configured${NC}"
    exit 1
fi

echo "Collecting security posture data..."
echo ""

# Collect scores
IDENTITY_SCORE=0
NETWORK_SCORE=0
DATA_SCORE=0
DETECTION_SCORE=0
COMPLIANCE_SCORE=0

# Identity checks
MIN_LEN=$(aws iam get-account-password-policy --query 'PasswordPolicy.MinimumPasswordLength' --output text 2>/dev/null)
if [ -n "$MIN_LEN" ] && [ "$MIN_LEN" != "None" ] && [ "$MIN_LEN" -ge 14 ] 2>/dev/null; then
    ((IDENTITY_SCORE += 5)); PWD_STATUS="PASS (min length $MIN_LEN)"
else
    PWD_STATUS="FAIL (min length: ${MIN_LEN:-not set})"
fi

ROOT_KEYS=$(aws iam get-account-summary --query 'SummaryMap.AccountAccessKeysPresent' --output text 2>/dev/null || echo "1")
if [ "$ROOT_KEYS" = "0" ]; then
    ((IDENTITY_SCORE += 5)); ROOT_STATUS="PASS"
else
    ROOT_STATUS="FAIL"
fi

TOTAL_USERS=$(aws iam list-users --query 'Users | length(@)' --output text 2>/dev/null || echo "0")
USERS_WITH_MFA=0
if [ "$TOTAL_USERS" -gt 0 ] 2>/dev/null; then
    for user in $(aws iam list-users --query 'Users[].UserName' --output text 2>/dev/null); do
        mfa=$(aws iam list-mfa-devices --user-name "$user" --query 'MFADevices[0]' --output text 2>/dev/null)
        if [ -n "$mfa" ] && [ "$mfa" != "None" ]; then ((USERS_WITH_MFA++)); fi
    done
fi
if [ "$TOTAL_USERS" -eq 0 ] || { [ "$TOTAL_USERS" -gt 0 ] && [ "$TOTAL_USERS" -eq "$USERS_WITH_MFA" ]; }; then
    ((IDENTITY_SCORE += 5)); MFA_STATUS="PASS ($USERS_WITH_MFA/$TOTAL_USERS)"
else
    MFA_STATUS="FAIL ($USERS_WITH_MFA/$TOTAL_USERS)"
fi

ANALYZER_COUNT=$(aws accessanalyzer list-analyzers --query 'analyzers[?status==`ACTIVE`] | length(@)' --output text 2>/dev/null || echo "0")
if [ "$ANALYZER_COUNT" -gt 0 ] 2>/dev/null; then
    ((IDENTITY_SCORE += 5)); ANALYZER_STATUS="PASS"
else
    ANALYZER_STATUS="FAIL"
fi

# Network checks
S3_BLOCK_STATUS=$(aws s3control get-public-access-block --account-id "$ACCOUNT_ID" --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]' --output text 2>/dev/null)
BLOCK_COUNT=0
if [ -n "$S3_BLOCK_STATUS" ]; then
    for val in $S3_BLOCK_STATUS; do
        if [ "$val" = "True" ]; then ((BLOCK_COUNT++)); fi
    done
fi
if [ "$BLOCK_COUNT" -eq 4 ]; then
    ((NETWORK_SCORE += 5)); S3BLOCK_STATUS="PASS (4/4)"
else
    S3BLOCK_STATUS="FAIL ($BLOCK_COUNT/4)"
fi

SSH_OPEN_SG=$(aws ec2 describe-security-groups \
    --query 'SecurityGroups[?IpPermissions[?FromPort==`22` && IpRanges[?CidrIp==`0.0.0.0/0`]]] | length(@)' \
    --output text 2>/dev/null || echo "0")
if [ "$SSH_OPEN_SG" = "0" ]; then
    ((NETWORK_SCORE += 5)); SSH_STATUS="PASS"
else
    SSH_STATUS="FAIL ($SSH_OPEN_SG open)"
fi

DEFAULT_VPC=$(aws ec2 describe-vpcs --query 'Vpcs[?IsDefault==`true`].VpcId' --output text 2>/dev/null)
if [ -z "$DEFAULT_VPC" ] || [ "$DEFAULT_VPC" = "None" ]; then
    ((NETWORK_SCORE += 5)); VPC_STATUS="PASS (deleted)"
else
    DEFAULT_INSTANCES=$(aws ec2 describe-instances \
        --filters "Name=vpc-id,Values=$DEFAULT_VPC" \
        --query 'Reservations[].Instances | length(@)' --output text 2>/dev/null || echo "0")
    if [ "$DEFAULT_INSTANCES" = "0" ]; then
        ((NETWORK_SCORE += 5)); VPC_STATUS="PASS (unused)"
    else
        VPC_STATUS="FAIL ($DEFAULT_INSTANCES instances)"
    fi
fi

# Data checks
CUSTOMER_KEYS=0
for key_id in $(aws kms list-keys --query 'Keys[].KeyId' --output text 2>/dev/null); do
    key_mgr=$(aws kms describe-key --key-id "$key_id" --query 'KeyMetadata.KeyManager' --output text 2>/dev/null)
    if [ "$key_mgr" = "CUSTOMER" ]; then ((CUSTOMER_KEYS++)); fi
done
if [ "$CUSTOMER_KEYS" -gt 0 ]; then
    ((DATA_SCORE += 5)); KMS_STATUS="PASS ($CUSTOMER_KEYS key(s))"
else
    KMS_STATUS="FAIL"
fi

TRAIL_NAME=$(aws cloudtrail describe-trails --query 'trailList[0].Name' --output text 2>/dev/null)
CLOUDTRAIL_STATUS="Disabled"
if [ -n "$TRAIL_NAME" ] && [ "$TRAIL_NAME" != "None" ]; then
    TRAIL_KMS=$(aws cloudtrail describe-trails --query 'trailList[0].KmsKeyId' --output text 2>/dev/null)
    if [ -n "$TRAIL_KMS" ] && [ "$TRAIL_KMS" != "None" ]; then
        ((DATA_SCORE += 5)); CT_ENC_STATUS="PASS"
    else
        CT_ENC_STATUS="FAIL"
    fi

    LOG_VAL=$(aws cloudtrail describe-trails --query 'trailList[0].LogFileValidationEnabled' --output text 2>/dev/null)
    if [ "$LOG_VAL" = "True" ]; then
        ((DATA_SCORE += 5)); CT_VAL_STATUS="PASS"
    else
        CT_VAL_STATUS="FAIL"
    fi
    CLOUDTRAIL_STATUS="Enabled"
else
    CT_ENC_STATUS="FAIL"
    CT_VAL_STATUS="FAIL"
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
    ((DATA_SCORE += 5)); S3ENC_STATUS="PASS ($ENCRYPTED_COUNT/$BUCKET_COUNT)"
else
    S3ENC_STATUS="FAIL ($ENCRYPTED_COUNT/$BUCKET_COUNT)"
fi

# Detection checks
if [ -n "$TRAIL_NAME" ] && [ "$TRAIL_NAME" != "None" ]; then
    ((DETECTION_SCORE += 5))
    MULTI_REGION=$(aws cloudtrail describe-trails --query 'trailList[0].IsMultiRegionTrail' --output text 2>/dev/null)
    if [ "$MULTI_REGION" = "True" ]; then ((DETECTION_SCORE += 5)); fi
    IS_LOGGING=$(aws cloudtrail get-trail-status --name "$TRAIL_NAME" --query 'IsLogging' --output text 2>/dev/null)
    if [ "$IS_LOGGING" = "True" ]; then ((DETECTION_SCORE += 5)); fi
fi

GD_DETECTORS=$(aws guardduty list-detectors --query 'DetectorIds' --output text 2>/dev/null)
GUARDDUTY_STATUS="Disabled"
if [ -n "$GD_DETECTORS" ] && [ "$GD_DETECTORS" != "None" ] && [ "$GD_DETECTORS" != "" ]; then
    GD_ID=$(echo "$GD_DETECTORS" | awk '{print $1}')
    GD_STATUS=$(aws guardduty get-detector --detector-id "$GD_ID" --query 'Status' --output text 2>/dev/null)
    if [ "$GD_STATUS" = "ENABLED" ]; then
        ((DETECTION_SCORE += 5))
        GUARDDUTY_STATUS="Enabled"
    fi
fi

SH_ARN=$(aws securityhub describe-hub --query 'HubArn' --output text 2>/dev/null)
SECURITYHUB_STATUS="Disabled"
if [ -n "$SH_ARN" ] && [ "$SH_ARN" != "None" ]; then
    ((DETECTION_SCORE += 5))
    SECURITYHUB_STATUS="Enabled"
    STANDARDS_COUNT=$(aws securityhub get-enabled-standards --query 'StandardsSubscriptions | length(@)' --output text 2>/dev/null || echo "0")
    if [ "$STANDARDS_COUNT" -gt 0 ] 2>/dev/null; then ((DETECTION_SCORE += 5)); fi
fi

# Compliance checks
CONFIG_REC=$(aws configservice describe-configuration-recorder-status --query 'ConfigurationRecordersStatus[0].recording' --output text 2>/dev/null)
CONFIG_SVC_STATUS="Disabled"
if [ "$CONFIG_REC" = "True" ]; then
    ((COMPLIANCE_SCORE += 5))
    CONFIG_SVC_STATUS="Enabled"
fi

CONFIG_RULES=$(aws configservice describe-config-rules --query 'ConfigRules | length(@)' --output text 2>/dev/null || echo "0")
if [ "$CONFIG_RULES" -ge 3 ] 2>/dev/null; then ((COMPLIANCE_SCORE += 5)); fi

if [ "$ANALYZER_COUNT" -gt 0 ] 2>/dev/null; then ((COMPLIANCE_SCORE += 5)); fi

TOTAL_SCORE=$((IDENTITY_SCORE + NETWORK_SCORE + DATA_SCORE + DETECTION_SCORE + COMPLIANCE_SCORE))

# Determine statuses
pillar_status() {
    local score=$1
    local max=$2
    if [ "$score" -eq "$max" ]; then echo "PASS"; else echo "GAPS REMAIN"; fi
}

IDENTITY_STATUS=$(pillar_status $IDENTITY_SCORE 20)
NETWORK_STATUS=$(pillar_status $NETWORK_SCORE 15)
DATA_STATUS=$(pillar_status $DATA_SCORE 20)
DETECTION_STATUS=$(pillar_status $DETECTION_SCORE 30)
COMPLIANCE_STATUS=$(pillar_status $COMPLIANCE_SCORE 15)
if [ "$TOTAL_SCORE" -eq 100 ]; then OVERALL_STATUS="SECURED"; else OVERALL_STATUS="IN PROGRESS"; fi

# Generate the report
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPORT_DIR="$SCRIPT_DIR/.."
REPORT_FILE="$REPORT_DIR/security-baseline-report.md"

echo "Generating report..."
echo ""

cat > "$REPORT_FILE" <<EOF
# AWS Security Baseline Report

## Report Information

| Field | Value |
|-------|-------|
| **Account ID** | $ACCOUNT_ID |
| **Region** | $REGION |
| **Date** | $DATE |
| **Assessed By** | $CALLER_ARN |
| **Overall Score** | $TOTAL_SCORE/100 |

## Executive Summary

This report documents the security baseline configuration of AWS account $ACCOUNT_ID. The account has been assessed across 5 security pillars: Identity, Network, Data, Detection, and Compliance.

## Pillar Scores

| Pillar | Score | Max | Status |
|--------|-------|-----|--------|
| Identity | $IDENTITY_SCORE | 20 | $IDENTITY_STATUS |
| Network | $NETWORK_SCORE | 15 | $NETWORK_STATUS |
| Data | $DATA_SCORE | 20 | $DATA_STATUS |
| Detection | $DETECTION_SCORE | 30 | $DETECTION_STATUS |
| Compliance | $COMPLIANCE_SCORE | 15 | $COMPLIANCE_STATUS |
| **Total** | **$TOTAL_SCORE** | **100** | **$OVERALL_STATUS** |

## Identity Controls ($IDENTITY_SCORE/20)

- [$([[ "$PWD_STATUS" == PASS* ]] && echo "x" || echo " ")] Password policy minimum length 14+ — $PWD_STATUS
- [$([[ "$ROOT_STATUS" == PASS* ]] && echo "x" || echo " ")] No root account access keys — $ROOT_STATUS
- [$([[ "$MFA_STATUS" == PASS* ]] && echo "x" || echo " ")] MFA enabled on all IAM users — $MFA_STATUS
- [$([[ "$ANALYZER_STATUS" == PASS* ]] && echo "x" || echo " ")] IAM Access Analyzer active — $ANALYZER_STATUS

## Network Controls ($NETWORK_SCORE/15)

- [$([[ "$S3BLOCK_STATUS" == PASS* ]] && echo "x" || echo " ")] S3 Block Public Access enabled account-wide — $S3BLOCK_STATUS
- [$([[ "$SSH_STATUS" == PASS* ]] && echo "x" || echo " ")] No security groups with SSH open to 0.0.0.0/0 — $SSH_STATUS
- [$([[ "$VPC_STATUS" == PASS* ]] && echo "x" || echo " ")] Default VPC reviewed/deleted — $VPC_STATUS

## Data Protection ($DATA_SCORE/20)

- [$([[ "$KMS_STATUS" == PASS* ]] && echo "x" || echo " ")] KMS customer-managed key created — $KMS_STATUS
- [$([[ "$CT_ENC_STATUS" == PASS* ]] && echo "x" || echo " ")] CloudTrail encrypted with KMS — $CT_ENC_STATUS
- [$([[ "$CT_VAL_STATUS" == PASS* ]] && echo "x" || echo " ")] CloudTrail log file validation enabled — $CT_VAL_STATUS
- [$([[ "$S3ENC_STATUS" == PASS* ]] && echo "x" || echo " ")] S3 buckets have default encryption — $S3ENC_STATUS

## Detection Services ($DETECTION_SCORE/30)

- CloudTrail: $CLOUDTRAIL_STATUS
- GuardDuty: $GUARDDUTY_STATUS
- Security Hub: $SECURITYHUB_STATUS

## Compliance Monitoring ($COMPLIANCE_SCORE/15)

- AWS Config: $CONFIG_SVC_STATUS
- Config Rules: $CONFIG_RULES active
- Access Analyzer: $ANALYZER_STATUS

## Services Summary

| Service | Status | Configuration |
|---------|--------|---------------|
| CloudTrail | $CLOUDTRAIL_STATUS | Multi-region, KMS encrypted, log validation |
| GuardDuty | $GUARDDUTY_STATUS | Threat detection |
| Security Hub | $SECURITYHUB_STATUS | AWS Best Practices standard |
| AWS Config | $CONFIG_SVC_STATUS | $CONFIG_RULES compliance rules |
| Access Analyzer | $ANALYZER_STATUS | Account-level analysis |

## Recommendations

1. Review and rotate IAM credentials regularly
2. Enable CloudTrail Insights for anomaly detection
3. Configure SNS notifications for GuardDuty HIGH findings
4. Add custom Config rules for organization-specific policies
5. Set up automated remediation for common violations

---

*Report generated by Cloud Security Labs — Chapter 03*
*Date: $DATE*
EOF

echo -e "${GREEN}Report generated: $REPORT_FILE${NC}"
echo ""
echo "  Score: $TOTAL_SCORE/100"
echo ""
echo "  You can view the report at:"
echo "    $REPORT_FILE"
echo ""
echo "  This report documents your security baseline and can be"
echo "  included in your portfolio to demonstrate AWS security skills."
echo ""
