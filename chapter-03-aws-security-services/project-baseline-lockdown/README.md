# Project: Baseline Lockdown — Reach 100/100

## Overview

**This is your final mission. Close every gap. Secure the account.**

You've enabled CloudTrail, GuardDuty, Security Hub, Config, and Access Analyzer. Your score should be around 85/100. The remaining points come from Identity and Network hardening that only YOU can do — no script will do it for you.

This project is intentionally less guided. You know the tools. Now use them.

## What You'll Do

1. Run the gap analysis to identify remaining weaknesses
2. Fix each gap yourself using what you've learned
3. Verify each fix in the AWS Console
4. Run final verification to confirm 100/100
5. Generate a professional Security Baseline Report

## Cost

**$0** — No new resources are created.

## Steps

### Step 1: Run the Gap Analysis

```bash
bash project-baseline-lockdown/scripts/gap-analysis.sh
```

This shows each remaining gap with hints (not exact commands). Write down every gap.

### Step 2: Fix Each Gap

Work through each gap. Here's what you might need to fix and where to look:

#### Password Policy (Identity — 5 points)

**The gap:** Password minimum length needs to be 14 or higher.

**Your task:** Update the account password policy. You'll need the `aws iam update-account-password-policy` command. Look at `aws iam update-account-password-policy help` for the flags.

**Verify in Console:** IAM → Account settings → Password policy. Confirm minimum length shows 14+.

#### MFA on IAM Users (Identity — 5 points)

**The gap:** One or more IAM users don't have MFA enabled.

**Your task:** Enable MFA for each user. You can do this in the AWS Console:

1. Go to **IAM → Users**
2. Click on each user without MFA
3. Click **Security credentials** tab
4. Under **Multi-factor authentication**, click **Assign MFA device**
5. Follow the wizard to set up a virtual MFA device (use an authenticator app)

**Verify in Console:** The MFA column should show "Virtual" for every user.

**Verify with CLI:**
```bash
aws iam list-mfa-devices --user-name YOUR_USERNAME
```

#### Open SSH Security Groups (Network — 5 points)

**The gap:** Security groups exist with SSH (port 22) open to 0.0.0.0/0.

**Your task:** Find them and fix them.

First, find the offending security groups:
```bash
aws ec2 describe-security-groups \
    --query 'SecurityGroups[?IpPermissions[?FromPort==`22` && IpRanges[?CidrIp==`0.0.0.0/0`]]].{ID:GroupId,Name:GroupName}' \
    --output table
```

For each one, decide: remove the rule entirely, or restrict to your IP only. To remove:
```bash
aws ec2 revoke-security-group-ingress \
    --group-id sg-XXXX \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0
```

**Verify in Console:** EC2 → Security Groups → check inbound rules. No SSH from 0.0.0.0/0 should remain.

#### Default VPC (Network — 5 points)

**The gap:** Default VPC has active resources (instances, etc.).

**Your task:** Check what's in the default VPC:

```bash
DEFAULT_VPC=$(aws ec2 describe-vpcs --query 'Vpcs[?IsDefault==`true`].VpcId' --output text)

aws ec2 describe-instances \
    --filters "Name=vpc-id,Values=$DEFAULT_VPC" \
    --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name,Type:InstanceType}' \
    --output table
```

If there are running instances, either:
- Terminate them if they're from old labs
- Migrate them to a custom VPC if they're needed

If the VPC is empty but exists, that's fine — the scoring engine gives you the points.

**Verify in Console:** VPC → Your VPCs. Check if the default VPC has any resources.

#### S3 Block Public Access (Network — 5 points)

**The gap:** Account-level S3 Block Public Access isn't fully enabled.

**Your task:**
```bash
aws s3control put-public-access-block \
    --account-id $(aws sts get-caller-identity --query Account --output text) \
    --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

**Verify in Console:** S3 → Block Public Access settings for this account. All 4 settings should be ON.

### Step 3: Verify Each Fix

After fixing each gap, re-run the gap analysis to confirm:

```bash
bash project-baseline-lockdown/scripts/gap-analysis.sh
```

Each gap should now show as PASS.

### Step 4: Final Verification

Once all gaps are closed:

```bash
bash project-baseline-lockdown/scripts/final-verification.sh
```

If you hit 100/100, you'll see the victory banner.

**If you're not at 100**, the output shows exactly which checks are still failing. Fix them and run again.

### Step 5: Verify in the Console — Full Walkthrough

Before generating your report, do a final Console walkthrough. Open each service and confirm:

| Service | What to Check | Where |
|---------|---------------|-------|
| IAM | Password policy 14+, all users have MFA | IAM → Account settings, IAM → Users |
| S3 | Block Public Access all 4 ON | S3 → Block Public Access settings |
| EC2 | No SSH from 0.0.0.0/0 | EC2 → Security Groups |
| KMS | Customer managed key exists | KMS → Customer managed keys |
| CloudTrail | Trail logging, multi-region, KMS encrypted | CloudTrail → Trails |
| GuardDuty | Detector enabled | GuardDuty → Settings |
| Security Hub | Hub enabled, standards active | Security Hub → Security standards |
| Config | Recorder on, 3+ rules | Config → Settings, Config → Rules |
| Access Analyzer | Analyzer active | IAM → Access Analyzer |

This is exactly what a security auditor would check. You should be comfortable navigating to each of these.

### Step 6: Generate Your Report

```bash
bash project-baseline-lockdown/scripts/generate-report.sh
```

This creates a professional Security Baseline Report at `project-baseline-lockdown/security-baseline-report.md`.

Open the report and review it. This documents:
- All 5 pillar scores
- Services enabled and their configuration
- The security controls in place
- Date and account information

**Use this report in your portfolio** to demonstrate your AWS security skills.

## What You've Accomplished

By completing this project, you've:

1. **Scanned** an AWS account for security gaps across 5 pillars
2. **Created** a KMS encryption key and configured key policies
3. **Built** a CloudTrail with encryption, multi-region logging, and validation
4. **Enabled** GuardDuty and triaged threat findings
5. **Configured** Security Hub with compliance standards
6. **Set up** AWS Config with compliance rules
7. **Broke** a security group and **watched** Config catch it
8. **Fixed** the violation and **verified** compliance
9. **Enabled** IAM Access Analyzer for external access monitoring
10. **Hardened** identity and network controls
11. **Generated** a professional security baseline report

You went from 15/100 to 100/100. Every point was earned.
