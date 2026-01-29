# Lab 04: AWS Config + Access Analyzer — Compliance Monitoring

## Overview

**From reactive to proactive.**

GuardDuty tells you when something bad happens. AWS Config tells you when something changes — and whether that change breaks your security rules. Access Analyzer finds resources shared outside your account. Together, they shift you from firefighting to continuous compliance.

In this lab, you'll:

1. Enable AWS Config to record all resource changes
2. Add Config rules that enforce security standards
3. Enable IAM Access Analyzer to find external access
4. Create a non-compliant security group yourself and watch Config flag it
5. Fix the violation yourself and watch it flip to COMPLIANT

## What You'll Learn

- How to set up AWS Config from scratch (recorder, delivery channel, rules)
- How Config rules provide continuous compliance checking
- How IAM Access Analyzer detects unintended external access
- The break-and-fix cycle of compliance monitoring
- How to verify compliance status in the AWS Console

## Cost

**~$0.01** — Config charges per configuration item recorded.

| Service             | Cost                         |
| ------------------- | ---------------------------- |
| AWS Config          | ~$0.003/configuration item   |
| Config Rules        | Included (AWS managed rules) |
| IAM Access Analyzer | Free                         |

## Prerequisites

- Completed Lab 03 (GuardDuty + Security Hub enabled)
- AWS CLI configured with admin permissions

## Steps

### Part 1: Set Up AWS Config

Config needs three things: an IAM role, an S3 bucket for delivery, and a recorder. You'll create each one.

Set your variables:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)
CONFIG_BUCKET="ch03-config-${ACCOUNT_ID}"
```

#### Create the S3 Bucket for Config

```bash
# If you're in us-east-1:
aws s3api create-bucket --bucket $CONFIG_BUCKET

# If you're in any OTHER region:
# aws s3api create-bucket --bucket $CONFIG_BUCKET \
#     --create-bucket-configuration LocationConstraint=$REGION
```

Enable encryption and block public access:

```bash
aws s3api put-bucket-encryption --bucket $CONFIG_BUCKET \
    --server-side-encryption-configuration '{
        "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
    }'

aws s3api put-public-access-block --bucket $CONFIG_BUCKET \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

Apply the bucket policy so Config can deliver snapshots:

```bash
aws s3api put-bucket-policy --bucket $CONFIG_BUCKET --policy '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSConfigBucketPermissionsCheck",
            "Effect": "Allow",
            "Principal": {"Service": "config.amazonaws.com"},
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::'"$CONFIG_BUCKET"'",
            "Condition": {"StringEquals": {"AWS:SourceAccount": "'"$ACCOUNT_ID"'"}}
        },
        {
            "Sid": "AWSConfigBucketExistenceCheck",
            "Effect": "Allow",
            "Principal": {"Service": "config.amazonaws.com"},
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::'"$CONFIG_BUCKET"'",
            "Condition": {"StringEquals": {"AWS:SourceAccount": "'"$ACCOUNT_ID"'"}}
        },
        {
            "Sid": "AWSConfigBucketDelivery",
            "Effect": "Allow",
            "Principal": {"Service": "config.amazonaws.com"},
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::'"$CONFIG_BUCKET"'/AWSLogs/'"$ACCOUNT_ID"'/Config/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control",
                    "AWS:SourceAccount": "'"$ACCOUNT_ID"'"
                }
            }
        }
    ]
}'
```

#### Create the IAM Role for Config

Config needs a role to read your resource configurations:

```bash
aws iam create-role --role-name ch03-config-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "config.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }'
```

Attach the AWS managed policy and add S3 delivery permissions:

```bash
aws iam attach-role-policy --role-name ch03-config-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWS_ConfigRole

aws iam put-role-policy --role-name ch03-config-role \
    --policy-name ch03-config-s3-delivery \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": ["s3:PutObject", "s3:GetBucketAcl"],
            "Resource": ["arn:aws:s3:::'"$CONFIG_BUCKET"'", "arn:aws:s3:::'"$CONFIG_BUCKET"'/*"]
        }]
    }'
```

Wait for the role to propagate:

```bash
echo "Waiting 10 seconds for IAM role propagation..."
sleep 10
```

#### Start the Config Recorder

```bash
CONFIG_ROLE_ARN=$(aws iam get-role --role-name ch03-config-role --query 'Role.Arn' --output text)

aws configservice put-configuration-recorder \
    --configuration-recorder "name=default,roleARN=${CONFIG_ROLE_ARN}" \
    --recording-group '{"allSupported":true,"includeGlobalResourceTypes":true}'

aws configservice put-delivery-channel \
    --delivery-channel "name=default,s3BucketName=${CONFIG_BUCKET}"

aws configservice start-configuration-recorder --configuration-recorder-name default
```

Verify it's recording:

```bash
aws configservice describe-configuration-recorder-status \
    --query 'ConfigurationRecordersStatus[0].{Recording:recording,LastStatus:lastStatus}' \
    --output table
```

You should see `Recording: True`.

#### Console Checkpoint: AWS Config

1. Open the AWS Console → **Config**
2. You should see the Config dashboard (not the setup wizard)
3. Click **Settings** — verify:
   - **Recording is on**
   - **Delivery channel:** Your S3 bucket
   - **IAM role:** `ch03-config-role`
4. Click **Resources** — you should start seeing resources being discovered (this takes a few minutes)

### Part 2: Add Config Rules

Config rules automatically evaluate resources against compliance checks. You'll add three rules:

#### Rule 1: No SSH Open to the Internet

```bash
aws configservice put-config-rule --config-rule '{
    "ConfigRuleName": "ch03-restricted-ssh",
    "Description": "Checks whether security groups allow unrestricted SSH traffic",
    "Source": {
        "Owner": "AWS",
        "SourceIdentifier": "INCOMING_SSH_DISABLED"
    },
    "Scope": {
        "ComplianceResourceTypes": ["AWS::EC2::SecurityGroup"]
    }
}'
```

#### Rule 2: CloudTrail Must Use KMS Encryption

```bash
aws configservice put-config-rule --config-rule '{
    "ConfigRuleName": "ch03-cloudtrail-encryption",
    "Description": "Checks whether CloudTrail uses KMS encryption",
    "Source": {
        "Owner": "AWS",
        "SourceIdentifier": "CLOUD_TRAIL_ENCRYPTION_ENABLED"
    }
}'
```

#### Rule 3: S3 Buckets Must Be Encrypted

```bash
aws configservice put-config-rule --config-rule '{
    "ConfigRuleName": "ch03-s3-encryption",
    "Description": "Checks whether S3 buckets have default encryption enabled",
    "Source": {
        "Owner": "AWS",
        "SourceIdentifier": "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
    },
    "Scope": {
        "ComplianceResourceTypes": ["AWS::S3::Bucket"]
    }
}'
```

Verify all three rules exist:

```bash
aws configservice describe-config-rules \
    --config-rule-names ch03-restricted-ssh ch03-cloudtrail-encryption ch03-s3-encryption \
    --query 'ConfigRules[].{Name:ConfigRuleName,State:ConfigRuleState}' \
    --output table
```

#### Console Checkpoint: Config Rules

1. Open **Config → Rules**
2. You should see your three rules listed
3. Click on `ch03-restricted-ssh` — it should show compliance results (may take a few minutes to evaluate)
4. Click on `ch03-cloudtrail-encryption` — if Lab 02 was done correctly, this should show **COMPLIANT**

### Part 3: Enable IAM Access Analyzer

Access Analyzer monitors for resources shared outside your account:

```bash
aws accessanalyzer create-analyzer \
    --analyzer-name ch03-access-analyzer \
    --type ACCOUNT
```

Check for any existing findings:

```bash
aws accessanalyzer list-findings \
    --analyzer-arn $(aws accessanalyzer list-analyzers --query 'analyzers[0].arn' --output text) \
    --query 'findings | length(@)' --output text
```

#### Console Checkpoint: Access Analyzer

1. Open **IAM → Access Analyzer** (in the left sidebar)
2. You should see `ch03-access-analyzer` listed
3. Click **Findings** — if you have any publicly shared resources, they'll appear here
4. If there are no findings, that's good — nothing is publicly shared

### Part 4: Break It — Create a Non-Compliant Security Group

Now for the hands-on part. You'll intentionally create a security group that violates the `restricted-ssh` rule, and watch Config catch it.

Find a VPC to use:

```bash
VPC_ID=$(aws ec2 describe-vpcs --query 'Vpcs[0].VpcId' --output text)
echo "Using VPC: $VPC_ID"
```

Create a security group with SSH open to the entire internet:

```bash
SG_ID=$(aws ec2 create-security-group \
    --group-name ch03-noncompliant-sg \
    --description "Intentionally non-compliant for Config exercise" \
    --vpc-id $VPC_ID \
    --query 'GroupId' --output text)

echo "Security Group: $SG_ID"
```

Add the non-compliant rule — SSH from 0.0.0.0/0:

```bash
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0
```

**You just opened SSH to the entire internet.** In a real environment, automated bots would start probing this port within minutes.

#### Console Checkpoint: Security Groups

1. Open **EC2 → Security Groups**
2. Find `ch03-noncompliant-sg`
3. Click the **Inbound rules** tab — you should see:
   - Type: SSH, Port: 22, Source: 0.0.0.0/0
4. This is exactly what Config rule `restricted-ssh` is designed to catch

Now trigger Config to evaluate the rule:

```bash
aws configservice start-config-rules-evaluation \
    --config-rule-names ch03-restricted-ssh
```

Wait for Config to flag it (this can take 1-2 minutes):

```bash
echo "Waiting for Config evaluation..."
sleep 30

aws configservice get-compliance-details-by-config-rule \
    --config-rule-name ch03-restricted-ssh \
    --compliance-types NON_COMPLIANT \
    --query 'EvaluationResults[].EvaluationResultIdentifier.EvaluationResultQualifier.ResourceId' \
    --output text
```

You should see your security group ID in the non-compliant list.

#### Console Checkpoint: Non-Compliant Resource

1. Open **Config → Rules → ch03-restricted-ssh**
2. You should see **Noncompliant** resources listed
3. Click on your security group — Config shows you:
   - **Resource type:** AWS::EC2::SecurityGroup
   - **Compliance status:** NON_COMPLIANT
   - **Timeline:** When the resource was created and evaluated

### Part 5: Fix It — Watch Config Flip to Compliant

Remove the offending SSH rule:

```bash
aws ec2 revoke-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0
```

Verify the rule is gone:

```bash
aws ec2 describe-security-groups \
    --group-ids $SG_ID \
    --query 'SecurityGroups[0].IpPermissions' \
    --output text
```

This should return nothing (no inbound rules).

Trigger re-evaluation:

```bash
aws configservice start-config-rules-evaluation \
    --config-rule-names ch03-restricted-ssh
```

Wait and check:

```bash
echo "Waiting for re-evaluation..."
sleep 30

aws configservice get-compliance-details-by-config-rule \
    --config-rule-name ch03-restricted-ssh \
    --compliance-types NON_COMPLIANT \
    --query 'EvaluationResults | length(@)' --output text
```

If this returns `0`, your security group is no longer non-compliant.

#### Console Checkpoint: Compliant Resource

1. Open **Config → Rules → ch03-restricted-ssh**
2. The non-compliant count should have decreased
3. Click on your security group — it should now show **COMPLIANT** (or no longer appear in the non-compliant list)

Clean up the exercise security group:

```bash
aws ec2 delete-security-group --group-id $SG_ID
echo "Deleted: $SG_ID"
```

### Part 6: Verify and Score

```bash
bash lab-04-config-access-analyzer/scripts/verify.sh
```

All 5 checks should pass. Then check your score:

```bash
bash scripts/mission-status.sh
```

**Expected score: ~85/100** (+20 from Compliance and Identity pillars)

## What You Just Learned

You completed the full compliance lifecycle:

```
CREATE non-compliant resource
    ↓
Config DETECTS the violation
    ↓
You FIX the violation
    ↓
Config CONFIRMS compliance
    ↓
You DELETE the test resource
```

In production, this cycle happens automatically:
- Config watches for changes
- Rules evaluate compliance in real-time
- Non-compliant resources trigger alerts (SNS, EventBridge)
- Automated remediation can fix issues without human intervention

## Key Concepts

### AWS Config vs CloudTrail

| Feature | CloudTrail                          | Config                                     |
| ------- | ----------------------------------- | ------------------------------------------ |
| Records | API calls (who did what)            | Resource state (how things are configured) |
| Focus   | Activity audit                      | Configuration compliance                   |
| Example | "User X called ModifySecurityGroup" | "SG sg-123 allows SSH from 0.0.0.0/0"      |

Both are needed: CloudTrail tells you WHO made a change, Config tells you if the RESULT is compliant.

### Config Rules

AWS managed rules are pre-built compliance checks:

- `restricted-ssh` — No SSH from 0.0.0.0/0
- `cloud-trail-encryption-enabled` — CloudTrail uses KMS
- `s3-bucket-server-side-encryption-enabled` — S3 buckets encrypted

When a resource changes, Config evaluates it against all active rules and marks it COMPLIANT or NON_COMPLIANT.

### IAM Access Analyzer

Access Analyzer continuously monitors:

- S3 buckets shared publicly or cross-account
- IAM roles assumable by external entities
- KMS keys accessible from outside the account
- Lambda functions with external invocation policies
- SQS queues with external access

## Alternative: Run Setup Script

If you need to redo setup quickly:

```bash
bash lab-04-config-access-analyzer/scripts/enable-compliance.sh
```

## What's Next

Proceed to [Project: Baseline Lockdown](../project-baseline-lockdown/) to close all remaining gaps and reach 100/100.
