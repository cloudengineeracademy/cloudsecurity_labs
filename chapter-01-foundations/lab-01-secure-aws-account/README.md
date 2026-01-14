# Lab 01: Secure Your AWS Account

## Overview

Before you can secure anything in AWS, you need to secure the account itself. This lab walks you through the foundational security controls that every AWS account should have.

**This is not optional.** These are baseline security requirements.

## Cost

**FREE** - All actions use AWS Free Tier

## Learning Objectives

By the end of this lab, you will:

1. Protect the root account with MFA
2. Remove any root access keys
3. Create a proper IAM admin user
4. Enforce a strong password policy
5. Block public S3 access at the account level

---

## Part 1: Check Your Current Status

Before fixing anything, see where you stand.

### Step 1.1: Run the Pre-Check Script

```bash
cd cloud-security-labs/chapter-01-foundations/lab-01-secure-aws-account
chmod +x scripts/pre-check.sh
./scripts/pre-check.sh
```

Note any items that show FAIL - you'll fix these in this lab.

---

## Part 2: Secure the Root Account

The root account has unlimited power over your entire AWS account. If compromised, an attacker owns everything.

### Step 2.1: Enable MFA on Root Account

This must be done in the AWS Console:

1. Go to https://console.aws.amazon.com/
2. Sign in as **ROOT USER** (not IAM user)
3. Click your account name (top right) → Security credentials
4. Find "Multi-factor authentication (MFA)"
5. Click "Assign MFA device"
6. Select "Authenticator app"
7. Scan the QR code with your phone (Google Authenticator, Authy, etc.)
8. Enter two consecutive codes from your phone
9. Click "Add MFA"

**Why this matters**: Even if an attacker steals your root password, they can't get in without your phone.

### Step 2.2: Verify Root Has NO Access Keys

```bash
aws iam get-account-summary --query 'SummaryMap.AccountAccessKeysPresent'
```

**Expected result**: `0`

If you see `1` or `2`, you have root access keys that need immediate deletion:
- Go to AWS Console → Security Credentials → Delete any access keys

**Rule**: Root should NEVER have programmatic access keys. Ever.

---

## Part 3: Set Up Your Admin IAM User

Never use root for daily work. Create an IAM admin user instead.

### Step 3.1: Check Existing Users

```bash
aws iam list-users --query 'Users[].UserName'
```

If you already have an admin user, skip to Step 3.3.

### Step 3.2: Create an Admin User (if needed)

Replace `YOUR_NAME` with your actual name:

```bash
# Create the user
aws iam create-user --user-name YOUR_NAME-admin

# Attach admin policy
aws iam attach-user-policy \
  --user-name YOUR_NAME-admin \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Create login password (change immediately on first login)
aws iam create-login-profile \
  --user-name YOUR_NAME-admin \
  --password 'TempPassword123!' \
  --password-reset-required
```

### Step 3.3: Enable MFA on Your IAM User

Check if you have MFA:

```bash
aws iam list-mfa-devices
```

If empty, set up MFA:
1. AWS Console → IAM → Users → [Your User]
2. Security credentials tab
3. Assign MFA device
4. Follow the same QR code process as root

### Step 3.4: Set a Strong Password Policy

```bash
aws iam update-account-password-policy \
  --minimum-password-length 14 \
  --require-symbols \
  --require-numbers \
  --require-uppercase-characters \
  --require-lowercase-characters \
  --max-password-age 90 \
  --password-reuse-prevention 12
```

Verify it worked:

```bash
aws iam get-account-password-policy
```

---

## Part 4: Block Public S3 Access

This prevents accidental data leaks by blocking public access at the account level.

### Step 4.1: Enable S3 Block Public Access

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws s3control put-public-access-block \
  --account-id ${ACCOUNT_ID} \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### Step 4.2: Verify It's Enabled

```bash
aws s3control get-public-access-block --account-id ${ACCOUNT_ID}
```

All four settings should show `true`.

---

## Part 5: Verify Your Work

Run the verification script to confirm everything is secure:

```bash
chmod +x scripts/verify.sh
./scripts/verify.sh
```

**Target**: 4/4 PASSED

| Check | Expected |
|-------|----------|
| Root Access Keys | PASS (no keys exist) |
| Your MFA Enabled | PASS |
| Password Policy | PASS (14+ chars) |
| S3 Block Public Access | PASS |

---

## Checklist

Before moving to Lab 02:

- [ ] Root account has MFA enabled
- [ ] Root account has NO access keys
- [ ] You have an IAM admin user (not using root daily)
- [ ] IAM admin user has MFA enabled
- [ ] Password policy requires 14+ characters
- [ ] S3 Block Public Access is enabled account-wide
- [ ] Verification script shows 4/4 PASS

---

## What You Learned

| Concept | What You Did |
|---------|--------------|
| **Authentication** | Added MFA - second layer beyond passwords |
| **Least Privilege** | Created IAM user instead of using root |
| **Defence in Depth** | Multiple layers: MFA + IAM + password policy + S3 protection |

---

## Key Takeaways

- **Root is sacred** - MFA required, no access keys, never use for daily work
- **MFA everything** - Passwords alone aren't enough
- **Account-level controls** - S3 Block Public Access prevents entire classes of mistakes
- **Verify your work** - Always confirm security controls are actually in place

---

## Next Lab

Continue to [Lab 02: Attack Surface Reconnaissance](../lab-02-attack-surface-recon/)
