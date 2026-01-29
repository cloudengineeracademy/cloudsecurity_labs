# Lab 01: Recon Scan

## Overview

**You can't fix what you can't see.**

Before enabling any services, you need to know where you stand. In this lab, you'll manually query each security pillar using the AWS CLI, verify what you find in the AWS Console, and build a mental map of what's missing.

## What You'll Learn

- The 5 security pillars every AWS account needs
- How to query AWS security service status using the CLI
- How to navigate the AWS Console to verify security settings
- Which gaps each subsequent lab will close

## Cost

**$0** — This lab is completely read-only.

## Steps

### Step 1: Check Your Starting Point

Run the mission status to see your baseline score:

```bash
bash scripts/mission-status.sh
```

If you completed Chapter 01, you should see ~15/100 from:

- Password policy (if set to 14+)
- No root access keys (if deleted)
- S3 Block Public Access (if enabled)

Write down your starting score: **______ / 100**

### Step 2: Query Each Pillar Yourself

Don't just run the scan script — run these commands yourself and understand what each one tells you.

#### Identity Pillar

Check your password policy:

```bash
aws iam get-account-password-policy --query 'PasswordPolicy.MinimumPasswordLength' --output text
```

**What to look for:** Is the minimum length 14 or higher? If it says "None" or less than 14, that's a gap.

Check for root access keys:

```bash
aws iam get-account-summary --query 'SummaryMap.AccountAccessKeysPresent' --output text
```

**What to look for:** This should return `0`. If it returns `1` or `2`, root has access keys — a critical risk.

Check MFA on your IAM users:

```bash
aws iam list-users --query 'Users[].UserName' --output table
```

For each user, check if they have MFA:

```bash
aws iam list-mfa-devices --user-name YOUR_USERNAME --query 'MFADevices' --output table
```

**What to look for:** Every user should have at least one MFA device listed.

#### Detection Pillar

Check if CloudTrail exists:

```bash
aws cloudtrail describe-trails --query 'trailList[].Name' --output text
```

**What to look for:** If this returns nothing, you have zero visibility into API activity. This is the #1 gap to close.

Check if GuardDuty is enabled:

```bash
aws guardduty list-detectors --query 'DetectorIds' --output text
```

**What to look for:** If empty, no threat detection is running. GuardDuty would have caught the Capital One breach pattern.

Check if Security Hub is enabled:

```bash
aws securityhub describe-hub --query 'HubArn' --output text
```

**What to look for:** If you get an error, Security Hub isn't enabled. No centralised findings view.

#### Compliance Pillar

Check if AWS Config is recording:

```bash
aws configservice describe-configuration-recorder-status --query 'ConfigurationRecordersStatus[0].recording' --output text
```

**What to look for:** Should return `True`. If not, resource changes are going untracked.

### Step 3: Console Checkpoint

Open the AWS Console and verify what you found. Navigate to each service:

1. **IAM → Account settings** — Can you see the password policy? Does it match what the CLI told you?
2. **IAM → Users** — Click on each user. Is the MFA column showing "Virtual" or "Not enabled"?
3. **CloudTrail → Trails** — Is there a trail listed? What region is it in?
4. **GuardDuty** — Does it say "Get started" (not enabled) or show a dashboard?
5. **Security Hub** — Is it enabled or showing a setup page?
6. **Config** — Does it show a recorder status? Any rules?

**Write down what you see for each service.** This builds the habit of verifying CLI output against the Console — a skill you'll use daily as a security engineer.

### Step 4: Run the Full Recon Scan

Now that you understand what each check does, run the automated scan for a complete picture:

```bash
bash lab-01-recon/scripts/recon-scan.sh
```

Compare the scan output against your manual findings. Everything should match.

### Step 5: Map Your Gaps to Labs

Fill in this table based on your scan:

| Gap | Which Lab Fixes It |
|-----|--------------------|
| No CloudTrail | Lab 02 |
| No KMS key | Lab 02 |
| No GuardDuty | Lab 03 |
| No Security Hub | Lab 03 |
| No Config | Lab 04 |
| No Access Analyzer | Lab 04 |
| Password policy / MFA / SSH | Project |

## What's Next

Proceed to [Lab 02: CloudTrail](../lab-02-cloudtrail/) to start enabling the flight recorder.
