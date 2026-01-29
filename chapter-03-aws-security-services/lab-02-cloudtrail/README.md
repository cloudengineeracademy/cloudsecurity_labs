# Lab 02: CloudTrail — The Flight Recorder

## Overview

**Every API call. Every region. Every time.**

CloudTrail is AWS's flight recorder. It logs every API call made in your account — who did what, when, and from where. Without it, you're flying blind. If a breach happens, CloudTrail is how you piece together what occurred.

In this lab, you'll build CloudTrail from scratch:

1. Create a KMS customer-managed key for encryption
2. Create an S3 bucket with proper policies for log delivery
3. Create a multi-region CloudTrail with encryption and log validation
4. Search your own API calls in the logs
5. Verify everything in the AWS Console

## What You'll Learn

- Why CloudTrail is the single most important security service
- How to create and configure KMS keys
- How S3 bucket policies work for service delivery
- How to query CloudTrail logs for forensic investigation
- How to verify security configurations in the AWS Console

## Cost

**$0** — The first CloudTrail trail per account is free. KMS has 20,000 free requests/month.

## Prerequisites

- AWS CLI configured with admin permissions
- Completed Lab 01 (recon scan)

## Steps

### Part 1: Create a KMS Key

CloudTrail logs contain sensitive information (who accessed what). Encrypting them with a customer-managed key gives you control over who can read the logs.

First, get your account ID and region — you'll need these throughout:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)
echo "Account: $ACCOUNT_ID"
echo "Region: $REGION"
```

Now create a KMS key. This key will encrypt your CloudTrail logs:

```bash
KMS_KEY_ID=$(aws kms create-key \
    --description "CloudTrail encryption key for Chapter 03" \
    --query 'KeyMetadata.KeyId' --output text)

echo "Key ID: $KMS_KEY_ID"
```

**Write down your Key ID.** You'll need it later.

Give the key a human-readable alias:

```bash
aws kms create-alias \
    --alias-name alias/ch03-cloudtrail-key \
    --target-key-id $KMS_KEY_ID
```

Now update the key policy so CloudTrail can use it for encryption. This is critical — without this policy, CloudTrail won't be able to encrypt logs with your key:

```bash
KMS_KEY_ARN=$(aws kms describe-key --key-id $KMS_KEY_ID --query 'KeyMetadata.Arn' --output text)

aws kms put-key-policy --key-id $KMS_KEY_ID --policy-name default --policy '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "EnableRootAccountFullAccess",
            "Effect": "Allow",
            "Principal": {"AWS": "arn:aws:iam::'"$ACCOUNT_ID"':root"},
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Sid": "AllowCloudTrailEncrypt",
            "Effect": "Allow",
            "Principal": {"Service": "cloudtrail.amazonaws.com"},
            "Action": "kms:GenerateDataKey*",
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "AWS:SourceArn": "arn:aws:cloudtrail:'"$REGION"':'"$ACCOUNT_ID"':trail/ch03-security-trail"
                },
                "StringLike": {
                    "kms:EncryptionContext:aws:cloudtrail:arn": "arn:aws:cloudtrail:*:'"$ACCOUNT_ID"':trail/*"
                }
            }
        },
        {
            "Sid": "AllowCloudTrailDescribeKey",
            "Effect": "Allow",
            "Principal": {"Service": "cloudtrail.amazonaws.com"},
            "Action": "kms:DescribeKey",
            "Resource": "*"
        }
    ]
}'
```

**Understand the policy:** Look at each statement. The first gives your account full key access. The second lets CloudTrail generate data keys (for encryption). The third lets CloudTrail describe the key. Without statements 2 and 3, CloudTrail can't encrypt anything.

#### Console Checkpoint: KMS

1. Open the AWS Console → **KMS → Customer managed keys**
2. You should see your new key with alias `ch03-cloudtrail-key`
3. Click on it — review the key policy. Can you see the three statements you just created?
4. Note the key state: it should be `Enabled`

### Part 2: Create the S3 Bucket

CloudTrail needs an S3 bucket to deliver log files. The bucket needs a specific policy that allows the CloudTrail service to write to it.

Create the bucket:

```bash
BUCKET_NAME="ch03-cloudtrail-${ACCOUNT_ID}"

# If you're in us-east-1:
aws s3api create-bucket --bucket $BUCKET_NAME

# If you're in any OTHER region, use this instead:
# aws s3api create-bucket --bucket $BUCKET_NAME \
#     --create-bucket-configuration LocationConstraint=$REGION
```

Enable default encryption on the bucket using your KMS key:

```bash
aws s3api put-bucket-encryption --bucket $BUCKET_NAME \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "aws:kms",
                "KMSMasterKeyID": "'"$KMS_KEY_ARN"'"
            },
            "BucketKeyEnabled": true
        }]
    }'
```

Block public access on the bucket:

```bash
aws s3api put-public-access-block --bucket $BUCKET_NAME \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

Apply the bucket policy that allows CloudTrail to deliver logs:

```bash
aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {"Service": "cloudtrail.amazonaws.com"},
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::'"$BUCKET_NAME"'",
            "Condition": {
                "StringEquals": {
                    "AWS:SourceArn": "arn:aws:cloudtrail:'"$REGION"':'"$ACCOUNT_ID"':trail/ch03-security-trail"
                }
            }
        },
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {"Service": "cloudtrail.amazonaws.com"},
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::'"$BUCKET_NAME"'/AWSLogs/'"$ACCOUNT_ID"'/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control",
                    "AWS:SourceArn": "arn:aws:cloudtrail:'"$REGION"':'"$ACCOUNT_ID"':trail/ch03-security-trail"
                }
            }
        },
        {
            "Sid": "DenyInsecureTransport",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::'"$BUCKET_NAME"'",
                "arn:aws:s3:::'"$BUCKET_NAME"'/*"
            ],
            "Condition": {
                "Bool": {"aws:SecureTransport": "false"}
            }
        }
    ]
}'
```

**Understand the policy:** The first statement lets CloudTrail check bucket permissions. The second lets CloudTrail write log files. The third denies all non-HTTPS access — defence in depth.

#### Console Checkpoint: S3

1. Open the AWS Console → **S3**
2. Find your bucket `ch03-cloudtrail-XXXX`
3. Click **Properties** — verify default encryption is set to `aws:kms` with your key
4. Click **Permissions** → **Block public access** — all 4 should be ON
5. Click **Permissions** → **Bucket policy** — you should see the three statements

### Part 3: Create the CloudTrail

Now create the trail itself. This single command does a lot:

```bash
aws cloudtrail create-trail \
    --name ch03-security-trail \
    --s3-bucket-name $BUCKET_NAME \
    --is-multi-region-trail \
    --enable-log-file-validation \
    --kms-key-id $KMS_KEY_ARN
```

**Understand the flags:**
- `--is-multi-region-trail` — Records API calls in ALL regions, not just your home region. Attackers deliberately use unused regions.
- `--enable-log-file-validation` — Creates digest files that detect log tampering. If an attacker deletes or modifies logs, the digest chain breaks.
- `--kms-key-id` — Encrypts logs with your CMK instead of default S3 encryption.

Start logging:

```bash
aws cloudtrail start-logging --name ch03-security-trail
```

Verify it's running:

```bash
aws cloudtrail get-trail-status --name ch03-security-trail \
    --query '{IsLogging:IsLogging,LatestDeliveryTime:LatestDeliveryTime}' --output table
```

#### Console Checkpoint: CloudTrail

1. Open the AWS Console → **CloudTrail → Trails**
2. Click on `ch03-security-trail`
3. Verify these settings:
   - **Multi-region trail:** Yes
   - **Log file validation:** Enabled
   - **SSE-KMS encryption:** Enabled (with your key alias)
   - **S3 bucket:** Your bucket name
   - **Status:** Logging
4. Click **Event history** on the left — you should start seeing API calls appear (may take a few minutes)

### Part 4: Detective Exercise — Find Your Own API Calls

Now that CloudTrail is recording, let's generate some activity and find it.

Make some API calls:

```bash
aws s3api list-buckets --query 'Buckets | length(@)' --output text
aws ec2 describe-instances --query 'Reservations | length(@)' --output text
aws iam list-users --query 'Users | length(@)' --output text
```

Query CloudTrail for your recent activity:

```bash
aws cloudtrail lookup-events \
    --max-results 10 \
    --query 'Events[].{Time:EventTime,Event:EventName,Source:EventSource}' \
    --output table
```

Search for IAM-specific events:

```bash
aws cloudtrail lookup-events \
    --lookup-attributes "AttributeKey=EventSource,AttributeValue=iam.amazonaws.com" \
    --max-results 5 \
    --query 'Events[].{Time:EventTime,Event:EventName,User:Username}' \
    --output table
```

**Think about it:** In the Capital One breach, CloudTrail would have shown unusual `ListBuckets` and `GetObject` calls from an EC2 instance role — hundreds of S3 reads in minutes. With CloudTrail, an invisible breach becomes a visible one.

Or run the full detective exercise script:

```bash
bash lab-02-cloudtrail/scripts/detective-exercise.sh
```

#### Console Checkpoint: Event History

1. Open **CloudTrail → Event history**
2. Find the `ListBuckets`, `DescribeInstances`, and `ListUsers` calls you just made
3. Click on one event — look at the JSON detail. Notice:
   - `userIdentity` — WHO made the call
   - `sourceIPAddress` — WHERE they called from
   - `eventTime` — WHEN it happened
   - `requestParameters` — WHAT they asked for

### Part 5: Verify and Score

Run the verification script:

```bash
bash lab-02-cloudtrail/scripts/verify.sh
```

All 7 checks should pass. Then check your score:

```bash
bash scripts/mission-status.sh
```

**Expected score: ~40/100** (+25 from Data and Detection pillars)

## Key Concepts

### Why KMS Encryption?

| Without KMS | With KMS |
|-------------|----------|
| Logs encrypted with SSE-S3 (AWS manages key) | You control the encryption key |
| Anyone with S3 access can read logs | Key policy restricts who can decrypt |
| No audit trail of who read logs | CloudTrail logs every key usage |

### Why Multi-Region?

An attacker who compromises your account might operate in `ap-southeast-1` while you only monitor `us-east-1`. A single-region trail would miss this entirely.

### Why Log Validation?

Log validation creates digest files (hashes of log files). If an attacker modifies or deletes logs to cover their tracks, the digest chain breaks and you know logs were tampered with.

## Alternative: Run Setup Script

If you want to skip the manual steps or need to redo setup quickly:

```bash
bash lab-02-cloudtrail/scripts/setup-cloudtrail.sh
```

This script does everything in Part 1-3 automatically.

## What's Next

Proceed to [Lab 03: GuardDuty + Security Hub](../lab-03-guardduty-security-hub/) to enable threat detection.
