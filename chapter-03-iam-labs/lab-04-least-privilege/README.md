# Lab 04: Least Privilege Lifecycle

## Overview

**Permissions boundaries are the ceiling. IAM policies are the floor. You get the overlap.**

In the real world, you can't just give developers zero permissions and call it "least privilege." They need to do their jobs. The challenge is giving them exactly what they need — and nothing more.

In this lab, you'll use **permissions boundaries** to cap what a role can ever do, regardless of what policies are attached. You'll see a role with `AdministratorAccess` get blocked by a boundary. Then you'll practice the scope-down workflow: start broad, test, narrow, verify.

## Cost

**$0** — IAM is free.

## Prerequisites

- AWS CLI configured with admin permissions
- Completed Lab 03 (ARN Scoping)

## Steps

First, make sure you're in the chapter directory:

```bash
cd cloud-security-labs/chapter-03-iam-labs
```

### Part 1: The Problem — AdministratorAccess Everywhere

Run the setup to create the lab resources:

```bash
bash lab-04-least-privilege/scripts/setup.sh
```

This creates:
- A role with `AdministratorAccess` and NO boundary (the "before")
- A role with `AdministratorAccess` AND a permissions boundary (the "after")
- A test S3 bucket

### Part 2: Permissions Boundaries — The Ceiling

A permissions boundary limits the maximum permissions a role can ever have. Even if you attach `AdministratorAccess`, the boundary caps what's allowed.

Run the boundary demo:

```bash
bash lab-04-least-privilege/scripts/boundary-demo.sh
```

The script assumes two roles and runs the same commands:

**Role WITHOUT boundary (iam-lab-unbounded-role):**
```
aws s3 ls                    → SUCCESS
aws iam list-users           → SUCCESS
aws ec2 describe-instances   → SUCCESS
```

**Role WITH boundary (iam-lab-bounded-role):**
```
aws s3 ls                    → SUCCESS  (S3 is within boundary)
aws iam list-users           → DENIED   (IAM is outside boundary)
aws ec2 describe-instances   → DENIED   (EC2 is outside boundary)
```

Both roles have `AdministratorAccess`. But the bounded role can only use S3 and CloudWatch — everything else hits the ceiling.

#### How the Boundary Works

The boundary policy allows ONLY S3 and CloudWatch:

```json
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Action": [
            "s3:*",
            "cloudwatch:*",
            "logs:*"
        ],
        "Resource": "*"
    }]
}
```

The role's permission policy (`AdministratorAccess`) allows everything. But effective permissions = permission policy INTERSECT boundary. The role gets S3 + CloudWatch, not admin.

```
Permission Policy:  [  S3  |  IAM  |  EC2  |  Lambda  |  CloudWatch  | ... ]
                     ████████████████████████████████████████████████████████

Boundary:           [  S3  |                           |  CloudWatch  |     ]
                     ███████                             ██████████████

Effective:          [  S3  |                           |  CloudWatch  |     ]
                     ███████                             ██████████████
```

#### Console Checkpoint

1. Open **IAM → Roles → iam-lab-bounded-role**
2. Look at the **Permissions boundary** section — you'll see the boundary policy listed
3. Click on the boundary policy to see what it allows
4. Compare with the **Permissions policies** tab (AdministratorAccess)
5. The role has admin attached but the boundary caps it

### Part 3: The Scope-Down Workflow

In production, you scope down permissions over time:

**Step 1: Start with what the application needs (broad)**

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="iam-lab-lp-${ACCOUNT_ID}"

aws iam put-role-policy --role-name iam-lab-bounded-role \
    --policy-name app-broad-policy \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::'"$BUCKET_NAME"'",
                "arn:aws:s3:::'"$BUCKET_NAME"'/*"
            ]
        }]
    }'
```

This gives the role all S3 actions on one bucket. It works, but it's broader than needed.

**Step 2: Test what the application actually uses**

```bash
# Assume the role
CREDS=$(aws sts assume-role \
    --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/iam-lab-bounded-role" \
    --role-session-name scope-test \
    --query 'Credentials' --output json)

TEMP_KEY=$(echo "$CREDS" | grep -o '"AccessKeyId": *"[^"]*"' | cut -d'"' -f4)
TEMP_SECRET=$(echo "$CREDS" | grep -o '"SecretAccessKey": *"[^"]*"' | cut -d'"' -f4)
TEMP_TOKEN=$(echo "$CREDS" | grep -o '"SessionToken": *"[^"]*"' | cut -d'"' -f4)

# Simulate what the app actually does (only reads):
AWS_ACCESS_KEY_ID="$TEMP_KEY" AWS_SECRET_ACCESS_KEY="$TEMP_SECRET" \
    AWS_SESSION_TOKEN="$TEMP_TOKEN" \
    aws s3 ls "s3://${BUCKET_NAME}/"

AWS_ACCESS_KEY_ID="$TEMP_KEY" AWS_SECRET_ACCESS_KEY="$TEMP_SECRET" \
    AWS_SESSION_TOKEN="$TEMP_TOKEN" \
    aws s3 cp "s3://${BUCKET_NAME}/data/file1.txt" -
```

The app only reads. It doesn't need `s3:PutObject`, `s3:DeleteObject`, or any other write actions.

**Step 3: Scope down to what's actually used**

```bash
aws iam put-role-policy --role-name iam-lab-bounded-role \
    --policy-name app-scoped-policy \
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

# Remove the broad policy
aws iam delete-role-policy --role-name iam-lab-bounded-role --policy-name app-broad-policy
```

**Step 4: Verify the scoped policy still works**

```bash
# Re-assume the role
CREDS=$(aws sts assume-role \
    --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/iam-lab-bounded-role" \
    --role-session-name scope-verify \
    --query 'Credentials' --output json)

TEMP_KEY=$(echo "$CREDS" | grep -o '"AccessKeyId": *"[^"]*"' | cut -d'"' -f4)
TEMP_SECRET=$(echo "$CREDS" | grep -o '"SecretAccessKey": *"[^"]*"' | cut -d'"' -f4)
TEMP_TOKEN=$(echo "$CREDS" | grep -o '"SessionToken": *"[^"]*"' | cut -d'"' -f4)

# Read still works
AWS_ACCESS_KEY_ID="$TEMP_KEY" AWS_SECRET_ACCESS_KEY="$TEMP_SECRET" \
    AWS_SESSION_TOKEN="$TEMP_TOKEN" \
    aws s3 cp "s3://${BUCKET_NAME}/data/file1.txt" -

# Write is now denied
echo "malicious" > /tmp/iam-lab-write-test.txt
AWS_ACCESS_KEY_ID="$TEMP_KEY" AWS_SECRET_ACCESS_KEY="$TEMP_SECRET" \
    AWS_SESSION_TOKEN="$TEMP_TOKEN" \
    aws s3 cp /tmp/iam-lab-write-test.txt "s3://${BUCKET_NAME}/hacked.txt"
rm -f /tmp/iam-lab-write-test.txt
```

Same functionality for the application. But if this role gets compromised, the attacker can read one bucket — they can't write, delete, or access anything else.

### Part 4: Verify

```bash
bash lab-04-least-privilege/scripts/verify.sh
```

All 4 checks should pass.

### Part 5: Clean Up

```bash
bash lab-04-least-privilege/scripts/cleanup.sh
```

## Key Concepts

### Permissions Boundary vs Permission Policy

| | Permission Policy | Permissions Boundary |
|---|---|---|
| What it does | Grants permissions (the floor) | Limits maximum permissions (the ceiling) |
| Attached as | Managed or inline policy | Boundary on the role/user |
| Effect | "You CAN do these things" | "You can NEVER exceed these things" |
| Who sets it | Role creator or admin | Account admin or security team |

### The Scope-Down Lifecycle

```
Day 1:   Broad permissions (get the app working)
            ↓
Day 7:   Check CloudTrail — what did the role actually use?
            ↓
Day 14:  Write scoped policy based on actual usage
            ↓
Day 21:  Apply scoped policy, test, verify
            ↓
Ongoing: Access Analyzer flags unused permissions
```

In production, **Access Analyzer** (which you enabled in Chapter 03) can generate scoped policies automatically by analyzing CloudTrail data. It watches what a role actually does and suggests a policy that allows only those actions.

### Defence in Depth with IAM

```
Layer 1: SCP (Organization level)    — "No one can do X"
Layer 2: Permissions Boundary         — "This role can never exceed Y"
Layer 3: Permission Policy            — "This role can do Z"
Layer 4: Resource Policy              — "This bucket only allows W"

Effective = SCP ∩ Boundary ∩ Permission Policy ∩ Resource Policy
```

Each layer narrows the blast radius further.

## What You've Learned

Across these 4 labs, you've built the complete IAM skill set:

1. **Blast Radius** — Why overprivileged access is dangerous
2. **Roles & Trust** — The building blocks of IAM architecture
3. **ARN Scoping** — How to write precise policies
4. **Least Privilege** — How to cap and scope down permissions

You now know more about IAM than most cloud engineers who've been working with AWS for years. The difference is: you've done it hands-on.
