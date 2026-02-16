# Lab 03: ARN Scoping & Policy Writing

## Overview

**Every wildcard you add multiplies the blast radius.**

ARNs (Amazon Resource Names) are the language of IAM policies. Get the ARN wrong, and your policy either blocks legitimate access or allows too much. In this lab, you'll write 5 IAM policies from scratch, apply them to a test user, and verify each one works correctly.

You'll hit the most common traps — including the infamous S3 bucket-vs-objects ARN mistake that trips up even experienced engineers.

## Cost

**$0** — Uses IAM (free) and a small S3 test bucket (free tier).

## Prerequisites

- AWS CLI configured with admin permissions
- Completed Lab 02 (Roles & Trust Policies)

## Steps

First, make sure you're in the chapter directory:

```bash
cd cloud-security-labs/chapter-03-iam-labs
```

### Part 1: Setup

Run the setup script to create a test user and test bucket:

```bash
bash lab-03-arn-scoping/scripts/setup.sh
```

This creates:
- `iam-lab-policy-user` — a test user with NO permissions (you'll add them)
- An S3 bucket with test files in two prefixes: `public/` and `confidential/`
- Access keys saved to `/tmp/iam-lab-03-keys`

### Part 2: The S3 ARN Trap (Challenge 1)

This is the #1 policy mistake in AWS.

**Task:** Write a policy that lets the user list the contents of the test bucket.

The action you need is `s3:ListBucket`. Try this policy:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="iam-lab-arn-${ACCOUNT_ID}"

aws iam put-user-policy --user-name iam-lab-policy-user \
    --policy-name challenge-1 \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::'"$BUCKET_NAME"'"
        }]
    }'
```

Wait 10 seconds for propagation, then test:

```bash
sleep 10
source /tmp/iam-lab-03-keys
AWS_ACCESS_KEY_ID="$POLICY_KEY" AWS_SECRET_ACCESS_KEY="$POLICY_SECRET" \
    aws s3 ls "s3://${BUCKET_NAME}/"
```

You should see the folder listing. Now try to **read** a file:

```bash
AWS_ACCESS_KEY_ID="$POLICY_KEY" AWS_SECRET_ACCESS_KEY="$POLICY_SECRET" \
    aws s3 cp "s3://${BUCKET_NAME}/public/readme.txt" -
```

**This fails.** Why?

`s3:ListBucket` operates on the **bucket** (`arn:aws:s3:::bucket-name`).
`s3:GetObject` operates on **objects** (`arn:aws:s3:::bucket-name/*`).

The bucket and its objects are different resources with different ARNs.

Remove the policy before the next challenge:

```bash
aws iam delete-user-policy --user-name iam-lab-policy-user --policy-name challenge-1
```

### Part 3: Bucket + Objects (Challenge 2)

**Task:** Write a policy that lets the user list AND read objects from the test bucket.

You need both ARN forms:

```bash
aws iam put-user-policy --user-name iam-lab-policy-user \
    --policy-name challenge-2 \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "AllowListBucket",
                "Effect": "Allow",
                "Action": "s3:ListBucket",
                "Resource": "arn:aws:s3:::'"$BUCKET_NAME"'"
            },
            {
                "Sid": "AllowReadObjects",
                "Effect": "Allow",
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::'"$BUCKET_NAME"'/*"
            }
        ]
    }'
```

Test after 10 seconds:

```bash
sleep 10

# List works
AWS_ACCESS_KEY_ID="$POLICY_KEY" AWS_SECRET_ACCESS_KEY="$POLICY_SECRET" \
    aws s3 ls "s3://${BUCKET_NAME}/"

# Read works now
AWS_ACCESS_KEY_ID="$POLICY_KEY" AWS_SECRET_ACCESS_KEY="$POLICY_SECRET" \
    aws s3 cp "s3://${BUCKET_NAME}/public/readme.txt" -
```

Both should work. Remove the policy:

```bash
aws iam delete-user-policy --user-name iam-lab-policy-user --policy-name challenge-2
```

### Part 4: Prefix Scoping (Challenge 3)

**Task:** Write a policy that lets the user read objects ONLY from the `public/` prefix — not `confidential/`.

```bash
aws iam put-user-policy --user-name iam-lab-policy-user \
    --policy-name challenge-3 \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "AllowListPublicOnly",
                "Effect": "Allow",
                "Action": "s3:ListBucket",
                "Resource": "arn:aws:s3:::'"$BUCKET_NAME"'",
                "Condition": {
                    "StringLike": {
                        "s3:prefix": "public/*"
                    }
                }
            },
            {
                "Sid": "AllowReadPublicOnly",
                "Effect": "Allow",
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::'"$BUCKET_NAME"'/public/*"
            }
        ]
    }'
```

Test after 10 seconds:

```bash
sleep 10

# Read public file — should work
AWS_ACCESS_KEY_ID="$POLICY_KEY" AWS_SECRET_ACCESS_KEY="$POLICY_SECRET" \
    aws s3 cp "s3://${BUCKET_NAME}/public/readme.txt" -

# Read confidential file — should be DENIED
AWS_ACCESS_KEY_ID="$POLICY_KEY" AWS_SECRET_ACCESS_KEY="$POLICY_SECRET" \
    aws s3 cp "s3://${BUCKET_NAME}/confidential/secret.txt" -
```

Public file works. Confidential file is denied. You just scoped access to a prefix.

Remove the policy:

```bash
aws iam delete-user-policy --user-name iam-lab-policy-user --policy-name challenge-3
```

### Part 5: Region Restriction (Challenge 4)

**Task:** Write a policy that allows EC2 describe actions ONLY in your current region.

```bash
REGION=$(aws configure get region)

aws iam put-user-policy --user-name iam-lab-policy-user \
    --policy-name challenge-4 \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeVpcs"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "aws:RequestedRegion": "'"$REGION"'"
                }
            }
        }]
    }'
```

Test after 10 seconds:

```bash
sleep 10

# In your region — should work
AWS_ACCESS_KEY_ID="$POLICY_KEY" AWS_SECRET_ACCESS_KEY="$POLICY_SECRET" \
    aws ec2 describe-vpcs --region "$REGION" --query 'Vpcs | length(@)' --output text

# In a different region — should be DENIED
AWS_ACCESS_KEY_ID="$POLICY_KEY" AWS_SECRET_ACCESS_KEY="$POLICY_SECRET" \
    aws ec2 describe-vpcs --region us-west-1 --query 'Vpcs | length(@)' --output text
```

Your region works. Other regions are denied. This is how you enforce region restrictions without SCPs.

> **Note:** If your current region IS `us-west-1`, use `eu-west-1` for the deny test instead.

Remove the policy:

```bash
aws iam delete-user-policy --user-name iam-lab-policy-user --policy-name challenge-4
```

### Part 6: Action Scoping (Challenge 5)

**Task:** Write a policy that allows the user to create IAM users but NOT create access keys. This simulates a "user provisioning" role that can onboard people but can't create long-lived credentials.

```bash
aws iam put-user-policy --user-name iam-lab-policy-user \
    --policy-name challenge-5 \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "AllowCreateUser",
                "Effect": "Allow",
                "Action": [
                    "iam:CreateUser",
                    "iam:DeleteUser",
                    "iam:GetUser"
                ],
                "Resource": "arn:aws:iam::'"$ACCOUNT_ID"':user/provisioned-*"
            },
            {
                "Sid": "DenyCreateAccessKey",
                "Effect": "Deny",
                "Action": "iam:CreateAccessKey",
                "Resource": "*"
            }
        ]
    }'
```

Test after 10 seconds:

```bash
sleep 10

# Create a user — should work (matches provisioned-* pattern)
AWS_ACCESS_KEY_ID="$POLICY_KEY" AWS_SECRET_ACCESS_KEY="$POLICY_SECRET" \
    aws iam create-user --user-name provisioned-test-user

# Try to create access keys — should be DENIED
AWS_ACCESS_KEY_ID="$POLICY_KEY" AWS_SECRET_ACCESS_KEY="$POLICY_SECRET" \
    aws iam create-access-key --user-name provisioned-test-user

# Try to create a non-matching user — should be DENIED
AWS_ACCESS_KEY_ID="$POLICY_KEY" AWS_SECRET_ACCESS_KEY="$POLICY_SECRET" \
    aws iam create-user --user-name backdoor-admin
```

User creation works (for `provisioned-*` names only). Access key creation is explicitly denied. Non-matching usernames are denied.

Clean up the test user and remove the policy:

```bash
aws iam delete-user --user-name provisioned-test-user
aws iam delete-user-policy --user-name iam-lab-policy-user --policy-name challenge-5
```

### Part 7: Verify

Run the automated test to confirm all concepts:

```bash
bash lab-03-arn-scoping/scripts/verify.sh
```

All 5 checks should pass.

### Part 8: Clean Up

```bash
bash lab-03-arn-scoping/scripts/cleanup.sh
```

## Key Concepts

### The Two S3 ARN Forms

```
Bucket-level actions (ListBucket, GetBucketLocation):
  Resource: arn:aws:s3:::my-bucket
                                    ^ no trailing /*

Object-level actions (GetObject, PutObject, DeleteObject):
  Resource: arn:aws:s3:::my-bucket/*
                                    ^ with /*
```

Getting this wrong is the most common IAM policy mistake. You'll see it in production constantly.

### ARN Format

```
arn:aws:service:region:account-id:resource-type/resource-id

Examples:
  arn:aws:s3:::my-bucket              (S3 bucket — no region, no account)
  arn:aws:s3:::my-bucket/*            (S3 objects)
  arn:aws:iam::123456789012:user/bob  (IAM user — no region, global)
  arn:aws:ec2:eu-west-2:123456789012:instance/i-abc123  (EC2 — regional)
```

### Wildcard Hierarchy

```
"Resource": "*"                    ← everything in the account
"Resource": "arn:aws:s3:::*"       ← all S3 buckets
"Resource": "arn:aws:s3:::my-*"    ← buckets starting with "my-"
"Resource": "arn:aws:s3:::my-bucket/*"  ← objects in one bucket
"Resource": "arn:aws:s3:::my-bucket/public/*"  ← objects in one prefix
```

Each step down reduces the blast radius.

## What's Next

Proceed to [Lab 04: Least Privilege Lifecycle](../lab-04-least-privilege/) to learn permissions boundaries and how to scope down overprivileged access.
