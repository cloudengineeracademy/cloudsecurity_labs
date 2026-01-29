#!/bin/bash

# Chapter 03: Cleanup — Disable all services created in this chapter
# Removes resources in reverse order to avoid dependency issues

echo ""
echo "=============================================="
echo "  CHAPTER 03 CLEANUP"
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

echo "Account: $ACCOUNT_ID"
echo "Region:  $REGION"
echo ""

echo -e "${RED}WARNING: This will disable ALL security services created in Chapter 03.${NC}"
echo ""
read -p "Are you sure you want to proceed? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
ERRORS=0

# ============================================================
# Step 1: Delete exercise security group (if leftover)
# ============================================================
echo -e "${BLUE}Step 1: Cleaning up exercise resources...${NC}"

SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=ch03-noncompliant-sg" \
    --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
if [ -n "$SG_ID" ] && [ "$SG_ID" != "None" ]; then
    aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null
    echo -e "  ${GREEN}Deleted exercise SG: $SG_ID${NC}"
else
    echo "  No exercise SG found (already cleaned)"
fi
echo ""

# ============================================================
# Step 2: Delete IAM Access Analyzer
# ============================================================
echo -e "${BLUE}Step 2: Deleting IAM Access Analyzer...${NC}"

ANALYZER_NAME=$(aws accessanalyzer list-analyzers --query 'analyzers[?contains(name, `ch03`)].name' --output text 2>/dev/null)
if [ -n "$ANALYZER_NAME" ] && [ "$ANALYZER_NAME" != "None" ]; then
    aws accessanalyzer delete-analyzer --analyzer-name "$ANALYZER_NAME" 2>/dev/null
    echo -e "  ${GREEN}Deleted Access Analyzer: $ANALYZER_NAME${NC}"
else
    echo "  No ch03 Access Analyzer found"
fi
echo ""

# ============================================================
# Step 3: Delete Config rules and stop recorder
# ============================================================
echo -e "${BLUE}Step 3: Removing AWS Config...${NC}"

# Delete Config rules
for rule in ch03-restricted-ssh ch03-cloudtrail-encryption ch03-s3-encryption; do
    RULE_EXISTS=$(aws configservice describe-config-rules --config-rule-names "$rule" --query 'ConfigRules[0].ConfigRuleName' --output text 2>/dev/null)
    if [ "$RULE_EXISTS" = "$rule" ]; then
        aws configservice delete-config-rule --config-rule-name "$rule" 2>/dev/null
        echo "  Deleted Config rule: $rule"
    fi
done

# Stop recorder
CONFIG_RECORDER=$(aws configservice describe-configuration-recorders --query 'ConfigurationRecorders[0].name' --output text 2>/dev/null)
if [ -n "$CONFIG_RECORDER" ] && [ "$CONFIG_RECORDER" != "None" ]; then
    aws configservice stop-configuration-recorder --configuration-recorder-name "$CONFIG_RECORDER" 2>/dev/null
    echo "  Stopped Config recorder: $CONFIG_RECORDER"

    # Delete delivery channel first (required before deleting recorder)
    CHANNEL=$(aws configservice describe-delivery-channels --query 'DeliveryChannels[0].name' --output text 2>/dev/null)
    if [ -n "$CHANNEL" ] && [ "$CHANNEL" != "None" ]; then
        aws configservice delete-delivery-channel --delivery-channel-name "$CHANNEL" 2>/dev/null
        echo "  Deleted delivery channel: $CHANNEL"
    fi

    # Delete recorder
    aws configservice delete-configuration-recorder --configuration-recorder-name "$CONFIG_RECORDER" 2>/dev/null
    echo "  Deleted Config recorder: $CONFIG_RECORDER"
fi

# Delete Config IAM role
CONFIG_ROLE="ch03-config-role"
ROLE_EXISTS=$(aws iam get-role --role-name "$CONFIG_ROLE" --query 'Role.RoleName' --output text 2>/dev/null)
if [ "$ROLE_EXISTS" = "$CONFIG_ROLE" ]; then
    # Detach policies
    aws iam detach-role-policy --role-name "$CONFIG_ROLE" \
        --policy-arn "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole" 2>/dev/null
    aws iam delete-role-policy --role-name "$CONFIG_ROLE" \
        --policy-name "ch03-config-s3-delivery" 2>/dev/null
    aws iam delete-role --role-name "$CONFIG_ROLE" 2>/dev/null
    echo "  Deleted IAM role: $CONFIG_ROLE"
fi

# Delete Config S3 bucket
CONFIG_BUCKET="ch03-config-${ACCOUNT_ID}"
aws s3api head-bucket --bucket "$CONFIG_BUCKET" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "  Emptying Config bucket: $CONFIG_BUCKET"
    aws s3 rm "s3://$CONFIG_BUCKET" --recursive 2>/dev/null
    aws s3api delete-bucket --bucket "$CONFIG_BUCKET" 2>/dev/null
    echo -e "  ${GREEN}Deleted Config bucket: $CONFIG_BUCKET${NC}"
fi

echo ""

# ============================================================
# Step 4: Disable Security Hub
# ============================================================
echo -e "${BLUE}Step 4: Disabling Security Hub...${NC}"

SH_ARN=$(aws securityhub describe-hub --query 'HubArn' --output text 2>/dev/null)
if [ -n "$SH_ARN" ] && [ "$SH_ARN" != "None" ]; then
    # Disable standards first
    for sub_arn in $(aws securityhub get-enabled-standards --query 'StandardsSubscriptions[].StandardsSubscriptionArn' --output text 2>/dev/null); do
        if [ -n "$sub_arn" ] && [ "$sub_arn" != "None" ]; then
            aws securityhub batch-disable-standards --standards-subscription-arns "$sub_arn" 2>/dev/null
        fi
    done

    aws securityhub disable-security-hub 2>/dev/null
    echo -e "  ${GREEN}Security Hub disabled${NC}"
else
    echo "  Security Hub not enabled"
fi
echo ""

# ============================================================
# Step 5: Disable GuardDuty
# ============================================================
echo -e "${BLUE}Step 5: Disabling GuardDuty...${NC}"

GD_DETECTOR_ID=$(aws guardduty list-detectors --query 'DetectorIds[0]' --output text 2>/dev/null)
if [ -n "$GD_DETECTOR_ID" ] && [ "$GD_DETECTOR_ID" != "None" ] && [ "$GD_DETECTOR_ID" != "" ]; then
    aws guardduty delete-detector --detector-id "$GD_DETECTOR_ID" 2>/dev/null
    echo -e "  ${GREEN}GuardDuty detector deleted: $GD_DETECTOR_ID${NC}"
else
    echo "  GuardDuty not enabled"
fi
echo ""

# ============================================================
# Step 6: Delete CloudTrail
# ============================================================
echo -e "${BLUE}Step 6: Removing CloudTrail...${NC}"

TRAIL_NAME="ch03-security-trail"
EXISTING_TRAIL=$(aws cloudtrail describe-trails --trail-name-list "$TRAIL_NAME" --query 'trailList[0].Name' --output text 2>/dev/null)
if [ "$EXISTING_TRAIL" = "$TRAIL_NAME" ]; then
    aws cloudtrail stop-logging --name "$TRAIL_NAME" 2>/dev/null
    aws cloudtrail delete-trail --name "$TRAIL_NAME" 2>/dev/null
    echo -e "  ${GREEN}Deleted trail: $TRAIL_NAME${NC}"
else
    echo "  Trail not found: $TRAIL_NAME"
fi

# Delete CloudTrail S3 bucket
CT_BUCKET="ch03-cloudtrail-${ACCOUNT_ID}"
aws s3api head-bucket --bucket "$CT_BUCKET" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "  Emptying CloudTrail bucket: $CT_BUCKET"
    aws s3 rm "s3://$CT_BUCKET" --recursive 2>/dev/null
    aws s3api delete-bucket --bucket "$CT_BUCKET" 2>/dev/null
    echo -e "  ${GREEN}Deleted CloudTrail bucket: $CT_BUCKET${NC}"
fi
echo ""

# ============================================================
# Step 7: Schedule KMS key deletion
# ============================================================
echo -e "${BLUE}Step 7: Scheduling KMS key deletion...${NC}"

KEY_ALIAS="alias/ch03-cloudtrail-key"
KMS_KEY_ID=$(aws kms describe-key --key-id "$KEY_ALIAS" --query 'KeyMetadata.KeyId' --output text 2>/dev/null)
if [ -n "$KMS_KEY_ID" ] && [ "$KMS_KEY_ID" != "None" ]; then
    aws kms delete-alias --alias-name "$KEY_ALIAS" 2>/dev/null
    aws kms schedule-key-deletion --key-id "$KMS_KEY_ID" --pending-window-in-days 7 2>/dev/null
    echo -e "  ${GREEN}KMS key scheduled for deletion in 7 days: $KMS_KEY_ID${NC}"
    echo "  (KMS keys have a mandatory waiting period before deletion)"
else
    echo "  No ch03 KMS key found"
fi
echo ""

# ============================================================
# Summary
# ============================================================
echo "=============================================="
echo "  CLEANUP COMPLETE"
echo "=============================================="
echo ""
echo "  Removed:"
echo "    - Exercise security group"
echo "    - IAM Access Analyzer"
echo "    - AWS Config (recorder + rules + delivery channel + role)"
echo "    - Security Hub (hub + standards)"
echo "    - GuardDuty (detector)"
echo "    - CloudTrail (trail + S3 bucket)"
echo "    - KMS key (scheduled for deletion in 7 days)"
echo "    - S3 buckets (ch03-cloudtrail, ch03-config)"
echo ""
echo "  Note: KMS keys have a mandatory 7-day waiting period"
echo "  before final deletion. You can cancel this with:"
echo "    aws kms cancel-key-deletion --key-id $KMS_KEY_ID"
echo ""
