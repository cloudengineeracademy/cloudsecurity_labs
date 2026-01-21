# Remediation Runbook

**Assessment Date:** [DATE]
**Created By:** [YOUR NAME]
**Last Updated:** [DATE]

---

## Overview

This runbook provides step-by-step instructions to remediate findings from the security assessment. Each remediation includes pre-requisites, commands, verification, and rollback procedures.

---

## Pre-Requisites

Before starting remediation:

- [ ] AWS CLI installed and configured
- [ ] Appropriate IAM permissions (see each section)
- [ ] Change management approval (if required)
- [ ] Backup/snapshot of affected resources (recommended)

---

## Remediation 1: [Finding Title]

**Severity:** [Critical/High/Medium/Low]
**Affected Resources:** [List resources]
**Estimated Time:** [Minutes]

### Required Permissions

```json
{
  "Effect": "Allow",
  "Action": [
    "[Required permissions]"
  ],
  "Resource": "[Resource ARN]"
}
```

### Pre-Check

Verify current state before making changes:

```bash
# Check current configuration
[Command to check current state]
```

Expected output showing the vulnerability:
```
[Example of vulnerable output]
```

### Remediation Steps

**Step 1:** [Description]

```bash
[Command]
```

**Step 2:** [Description]

```bash
[Command]
```

### Verification

Confirm the fix was applied:

```bash
# Verify remediation
[Command to verify]
```

Expected output showing secure configuration:
```
[Example of secure output]
```

### Rollback (If Needed)

If issues occur, revert the change:

```bash
# Rollback command
[Command to rollback]
```

### Completion Checklist

- [ ] Pre-check completed
- [ ] Remediation applied
- [ ] Verification passed
- [ ] Documented in change log

---

## Remediation 2: Enable IMDSv2 on EC2 Instances

**Severity:** Critical
**Affected Resources:** EC2 instances with IMDSv1
**Estimated Time:** 5 minutes per instance

### Required Permissions

```json
{
  "Effect": "Allow",
  "Action": [
    "ec2:DescribeInstances",
    "ec2:ModifyInstanceMetadataOptions"
  ],
  "Resource": "*"
}
```

### Pre-Check

```bash
# List instances with IMDSv1 enabled
aws ec2 describe-instances \
  --query 'Reservations[].Instances[?MetadataOptions.HttpTokens==`optional`].{ID:InstanceId,Name:Tags[?Key==`Name`].Value|[0],IMDS:MetadataOptions.HttpTokens}' \
  --output table
```

### Remediation Steps

**Step 1:** Enable IMDSv2 for each instance

```bash
# Replace INSTANCE_ID with actual instance ID
INSTANCE_ID="i-0abc123def456"

aws ec2 modify-instance-metadata-options \
  --instance-id $INSTANCE_ID \
  --http-tokens required \
  --http-endpoint enabled
```

**Step 2:** For multiple instances, use a loop

```bash
# Get all vulnerable instances and fix them
aws ec2 describe-instances \
  --query 'Reservations[].Instances[?MetadataOptions.HttpTokens==`optional`].InstanceId' \
  --output text | tr '\t' '\n' | while read id; do
    echo "Fixing instance: $id"
    aws ec2 modify-instance-metadata-options \
      --instance-id $id \
      --http-tokens required \
      --http-endpoint enabled
done
```

### Verification

```bash
# Verify IMDSv2 is required
aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].MetadataOptions.HttpTokens' \
  --output text
```

Expected output: `required`

### Rollback

```bash
# Revert to IMDSv1 (NOT RECOMMENDED)
aws ec2 modify-instance-metadata-options \
  --instance-id $INSTANCE_ID \
  --http-tokens optional
```

---

## Remediation 3: Enable S3 Public Access Block

**Severity:** High
**Affected Resources:** S3 buckets without public access block
**Estimated Time:** 2 minutes per bucket

### Required Permissions

```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetBucketPublicAccessBlock",
    "s3:PutBucketPublicAccessBlock"
  ],
  "Resource": "arn:aws:s3:::*"
}
```

### Pre-Check

```bash
# List buckets without public access block
aws s3 ls | awk '{print $3}' | while read bucket; do
  BLOCK=$(aws s3api get-public-access-block --bucket $bucket 2>&1)
  if echo "$BLOCK" | grep -q "NoSuchPublicAccessBlockConfiguration"; then
    echo "[VULNERABLE] $bucket"
  fi
done
```

### Remediation Steps

```bash
# Replace BUCKET_NAME with actual bucket name
BUCKET_NAME="my-bucket"

aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration '{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }'
```

### Verification

```bash
aws s3api get-public-access-block --bucket $BUCKET_NAME
```

Expected output shows all four settings as `true`.

### Rollback

```bash
# Remove public access block (NOT RECOMMENDED)
aws s3api delete-public-access-block --bucket $BUCKET_NAME
```

---

## Remediation 4: Delete IAM User Access Keys

**Severity:** High
**Affected Resources:** IAM users with access keys
**Estimated Time:** 5 minutes per user

### Pre-Check

```bash
# List users with access keys
aws iam list-users --query 'Users[].UserName' --output text | tr '\t' '\n' | while read user; do
  KEYS=$(aws iam list-access-keys --user-name $user --query 'AccessKeyMetadata[].AccessKeyId' --output text)
  if [ -n "$KEYS" ]; then
    echo "User: $user - Keys: $KEYS"
  fi
done
```

### Remediation Steps

**Before deleting, ensure:**
- User has console access OR
- Access key is replaced with IAM role OR
- Application using the key is updated

```bash
USER_NAME="example-user"
KEY_ID="AKIAIOSFODNN7EXAMPLE"

# Delete the access key
aws iam delete-access-key \
  --user-name $USER_NAME \
  --access-key-id $KEY_ID
```

### Verification

```bash
aws iam list-access-keys --user-name $USER_NAME
```

Expected output: Empty (no access keys)

### Rollback

Access keys cannot be recovered once deleted. If needed:
1. Create a new access key: `aws iam create-access-key --user-name $USER_NAME`
2. Update applications with new credentials

---

## Remediation 5: Restrict Security Group Ingress

**Severity:** Critical
**Affected Resources:** Security groups with 0.0.0.0/0
**Estimated Time:** 10 minutes per security group

### Pre-Check

```bash
# List security groups with open ingress
aws ec2 describe-security-groups \
  --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]].{ID:GroupId,Name:GroupName}' \
  --output table
```

### Remediation Steps

```bash
SG_ID="sg-0abc123def456"

# Remove SSH access from internet (example)
aws ec2 revoke-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

# Add SSH access from specific IP only
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr YOUR_IP/32
```

### Verification

```bash
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --query 'SecurityGroups[0].IpPermissions' \
  --output json
```

---

## Completion Summary

| # | Finding | Status | Completed By | Date |
|---|---------|--------|--------------|------|
| 1 | [Finding] | [ ] Pending / [x] Complete | | |
| 2 | [Finding] | [ ] Pending / [x] Complete | | |
| 3 | [Finding] | [ ] Pending / [x] Complete | | |
| 4 | [Finding] | [ ] Pending / [x] Complete | | |
| 5 | [Finding] | [ ] Pending / [x] Complete | | |

---

## Post-Remediation Verification

After all remediations are complete:

```bash
# Re-run the security scan to verify all issues resolved
./scripts/security-scan.sh
```

All findings should now show as PASS.
