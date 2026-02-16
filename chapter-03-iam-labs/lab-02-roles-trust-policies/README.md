# Lab 02: Roles & Trust Policies

## Overview

**Users are for humans. Roles are for everything else.**

In Lab 01 you saw the danger of long-lived access keys. Roles solve this — they issue temporary credentials that expire automatically. In this lab, you'll create IAM groups, users, and roles from scratch, assume a role with STS, and see temporary credentials appear with an expiration timestamp.

By the end, you'll understand the difference between trust policies (WHO can assume) and permission policies (WHAT they can do).

## Cost

**$0** — IAM is free.

## Prerequisites

- AWS CLI configured with admin permissions
- Completed Lab 01 (Blast Radius)

## Steps

First, make sure you're in the chapter directory:

```bash
cd cloud-security-labs/chapter-03-iam-labs
```

### Part 1: Groups — Permission Inheritance

Groups are containers for users. Attach a policy to the group, every user in the group gets it.

Create a group with S3 read-only access:

```bash
aws iam create-group --group-name iam-lab-dev-group
```

Attach a policy to the group:

```bash
aws iam attach-group-policy --group-name iam-lab-dev-group \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
```

Create a user and add them to the group:

```bash
aws iam create-user --user-name iam-lab-group-user

aws iam add-user-to-group \
    --group-name iam-lab-dev-group \
    --user-name iam-lab-group-user
```

Verify the user inherited the group's policy:

```bash
aws iam list-groups-for-user --user-name iam-lab-group-user \
    --query 'Groups[].GroupName' --output text
```

You should see `iam-lab-dev-group`. The user now has S3 read access — not because of a directly attached policy, but because of group membership.

**Key point:** When a new developer joins, you add them to the group. When they leave, you remove them. The permissions stay consistent. No copying policies between users.

### Part 2: Roles — The Trust Boundary

This is the critical part. A role has TWO policies:

1. **Trust policy** — WHO can assume this role (the door)
2. **Permission policy** — WHAT the role can do once assumed (the room)

#### Create a Role

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws iam create-role --role-name iam-lab-assumable-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"AWS": "arn:aws:iam::'"$ACCOUNT_ID"':root"},
            "Action": "sts:AssumeRole"
        }]
    }'
```

That trust policy says: "Any principal in account `$ACCOUNT_ID` can assume this role."

Attach a permission policy — what the role can actually do:

```bash
aws iam attach-role-policy --role-name iam-lab-assumable-role \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
```

#### Assume the Role

This is the moment. Run `sts assume-role` and watch temporary credentials appear:

```bash
aws sts assume-role \
    --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/iam-lab-assumable-role" \
    --role-session-name lab-session
```

**Look at the output.** You'll see three things:

```json
{
    "Credentials": {
        "AccessKeyId": "ASIA...",
        "SecretAccessKey": "...",
        "SessionToken": "...",
        "Expiration": "2026-02-16T17:30:00+00:00"
    }
}
```

Notice:
- **AccessKeyId starts with `ASIA`** — not `AKIA`. Temporary credentials always start with `ASIA`. Long-lived keys start with `AKIA`. This is how you tell them apart.
- **SessionToken** — temporary credentials include a session token. Long-lived keys don't.
- **Expiration** — these credentials die in 1 hour. An attacker who steals them has a window, not a forever-key.

#### Use the Temporary Credentials

Or run the demo script to see it automated:

```bash
bash lab-02-roles-trust-policies/scripts/assume-role-demo.sh
```

The script assumes the role, uses the temporary credentials to list S3 buckets (works — role has S3 read), then tries to list IAM users (denied — role only has S3 read).

### Part 3: EC2 Trust Policy

When you attach a role to an EC2 instance, the instance gets temporary credentials automatically via the metadata service. The trust policy looks different:

```bash
aws iam create-role --role-name iam-lab-ec2-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "ec2.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }'

aws iam attach-role-policy --role-name iam-lab-ec2-role \
    --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
```

Notice the trust policy says `"Service": "ec2.amazonaws.com"` — not an account ID. Only the EC2 service can assume this role.

**This is the role Capital One should have scoped.** The EC2 instance had a role like this, but with `s3:*` on `Resource: *` instead of read-only on one bucket.

Examine the trust policy:

```bash
aws iam get-role --role-name iam-lab-ec2-role \
    --query 'Role.AssumeRolePolicyDocument' --output json
```

### Part 4: Cross-Account Role Pattern

In production, you'll create roles that other AWS accounts can assume. This is how multi-account architectures work.

```bash
aws iam create-role --role-name iam-lab-cross-account-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"AWS": "arn:aws:iam::123456789012:root"},
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "sts:ExternalId": "unique-external-id-here"
                }
            }
        }]
    }'
```

This role trusts account `123456789012` (a fake account for this exercise). Note the **ExternalId condition** — this prevents the "confused deputy" problem where a third-party service could assume your role without authorization.

Examine the trust policy:

```bash
aws iam get-role --role-name iam-lab-cross-account-role \
    --query 'Role.AssumeRolePolicyDocument' --output json
```

You can't assume this role (the trusted account doesn't exist), but you've seen the pattern.

### Part 5: Decision Framework

When should you use each identity type?

| Scenario | Use | Why |
|----------|-----|-----|
| Developer needs AWS Console access | IAM user in a group | Human, needs password + MFA |
| EC2 instance needs S3 access | EC2 instance role | No stored credentials, auto-rotated |
| Lambda function needs DynamoDB access | Lambda execution role | Same as EC2 — service role |
| Third-party SaaS needs read access | Cross-account role with ExternalId | Scoped trust, no shared keys |
| CI/CD pipeline (GitHub Actions) | OIDC federated role | No long-lived keys in CI |
| Hundreds of employees | IAM Identity Center (SSO) | Federated, centralized |

**Rule of thumb:** If it's not a human sitting at a keyboard, use a role.

### Part 6: Verify

```bash
bash lab-02-roles-trust-policies/scripts/verify.sh
```

All 5 checks should pass.

### Part 7: Clean Up

```bash
bash lab-02-roles-trust-policies/scripts/cleanup.sh
```

## Key Concepts

### Trust Policy vs Permission Policy

```
Trust Policy (AssumeRolePolicyDocument):
  "WHO can walk through this door?"
  → Principals: accounts, services, federated users

Permission Policy (attached managed/inline policy):
  "WHAT can they do once inside?"
  → Actions: s3:GetObject, ec2:DescribeInstances, etc.
```

Both must be present. A role with a permissive trust policy but no permission policy can be assumed but can't do anything. A role with broad permissions but a restrictive trust policy can't be assumed by unauthorized principals.

### Temporary vs Long-Lived Credentials

| | Long-Lived (Access Keys) | Temporary (STS) |
|---|---|---|
| Prefix | `AKIA...` | `ASIA...` |
| Expires | Never (until manually rotated) | 1-12 hours |
| Session Token | No | Yes |
| Use for | CI/CD (legacy), CLI users | Roles, federation, cross-account |
| Risk if leaked | Permanent access until revoked | Time-limited window |

## What's Next

Proceed to [Lab 03: ARN Scoping & Policy Writing](../lab-03-arn-scoping/) to practice writing precise IAM policies.
