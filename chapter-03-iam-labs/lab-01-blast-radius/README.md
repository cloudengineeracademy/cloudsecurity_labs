# Lab 01: The Blast Radius Lab

## Overview

**Same credentials. Different permissions. Completely different damage.**

You're going to create two IAM users — one with full admin access, one scoped to a single S3 bucket. Then you'll run the exact same commands with both and see what happens.

This is the blast radius problem. If either credential gets leaked on GitHub, posted in a Slack message, or stolen via SSRF — the overprivileged one gives an attacker your entire account. The scoped one gives them one bucket, read-only.

## Cost

**$0** — Uses IAM (free) and a small S3 test bucket (free tier).

## Prerequisites

- AWS CLI configured with admin permissions
- Completed Chapter 01 (secure account basics)

## Steps

First, make sure you're in the chapter directory:

```bash
cd cloud-security-labs/chapter-03-iam-labs
```

### Part 1: Set Up the Two Users

Run the setup script to create both users with their policies and access keys:

```bash
bash lab-01-blast-radius/scripts/setup.sh
```

This creates:
- `iam-lab-admin-user` — attached to `AdministratorAccess` (full account access)
- `iam-lab-scoped-user` — custom inline policy (read-only on one test bucket)
- A test S3 bucket with sample files
- Access keys for both users (saved to a temporary file)

**Important:** The access keys are saved to `/tmp/iam-lab-01-keys`. This file is deleted during cleanup.

### Part 2: The Blast Radius Test

Now run the same 5 commands with both users and watch the difference:

```bash
bash lab-01-blast-radius/scripts/blast-radius-test.sh
```

The script runs these commands with each user:

| # | Command | What It Tests |
|---|---------|--------------|
| 1 | `aws s3 ls` | Can they see all your S3 buckets? |
| 2 | `aws iam list-users` | Can they enumerate IAM users? |
| 3 | `aws ec2 describe-instances` | Can they see your EC2 instances? |
| 4 | `aws iam create-user` | Can they create a backdoor user? |
| 5 | `aws s3 ls s3://test-bucket/` | Can they read the scoped bucket? |

**Expected results:**

```
OVERPRIVILEGED USER: 5/5 commands succeeded
  - Listed all buckets
  - Enumerated all IAM users
  - Described EC2 instances
  - CREATED A BACKDOOR USER (!)
  - Read the test bucket

SCOPED USER: 1/5 commands succeeded
  - Listed test bucket contents ONLY
  - Everything else: Access Denied
```

The overprivileged user could create a backdoor and own your account. The scoped user can read files from one bucket. That's it.

### Part 3: The Capital One Connection

Remember the Capital One breach from Chapter 02?

The IAM role on that EC2 instance had `s3:*` on `Resource: *`. When the attacker stole the role credentials via SSRF, they could list every S3 bucket in the account and download 100 million customer records.

If that role had been scoped — `s3:GetObject` on the one bucket the application actually needed — the attacker gets the role credentials, tries `aws s3 ls`, gets **Access Denied**, and the breach doesn't happen.

That's the difference you just saw in this lab.

**Key question:** Look at the IAM roles in YOUR account. How many of them have `*` in the Resource field?

### Part 4: Verify

```bash
bash lab-01-blast-radius/scripts/verify.sh
```

All 4 checks should pass.

### Part 5: Clean Up

```bash
bash lab-01-blast-radius/scripts/cleanup.sh
```

This removes both users, their access keys, the test bucket, and the temporary keys file.

## Key Concepts

### Blast Radius = Permissions × Credential Lifetime

| Factor | Overprivileged | Scoped |
|--------|---------------|--------|
| Permissions | Everything | 1 bucket, read-only |
| If compromised | Full account takeover | Read one bucket |
| Blast radius | Catastrophic | Contained |

### The Three IAM Mistakes

1. **Human users with long-lived access keys** — Keys don't expire. If leaked, they work until someone revokes them.
2. **Overprivileged roles** — `AdministratorAccess` on an EC2 instance or Lambda function.
3. **No credential rotation** — Keys that haven't been rotated in months or years.

You just demonstrated mistake #1 and #2 in this lab.

## What's Next

Proceed to [Lab 02: Roles & Trust Policies](../lab-02-roles-trust-policies/) to learn the difference between users, groups, and roles — and why roles are almost always the right answer.
