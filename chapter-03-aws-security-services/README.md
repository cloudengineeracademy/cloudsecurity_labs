# Chapter 03: AWS Security Services

## Mission: Secure the Account

**You've just been hired as a Cloud Security Engineer. Your first day, you get the alert:**

> *"Your AWS account has been flagged as HIGH RISK by the security team. No CloudTrail. No GuardDuty. No Config. You have 5 labs to get this account to a 100/100 security score."*

This chapter takes you from a bare account to a fully instrumented security baseline. You'll enable the core AWS security services that every account needs, and you'll understand exactly why each one matters.

## The 5 Security Pillars

Your score is tracked across 5 pillars:

| Pillar | Points | What It Covers |
|--------|--------|----------------|
| Identity | 20 | Password policy, root keys, MFA, Access Analyzer |
| Network | 15 | S3 block public access, SSH security groups, default VPC |
| Data | 20 | KMS keys, CloudTrail encryption, log validation, S3 encryption |
| Detection | 30 | CloudTrail, GuardDuty, Security Hub |
| Compliance | 15 | Config recorder, Config rules, Access Analyzer |

**Starting score: ~15/100** (from Chapter 01 work)
**Target: 100/100**

## Labs in This Chapter

| Lab | Title | What You'll Do | Score After |
|-----|-------|----------------|-------------|
| 01 | [Recon Scan](./lab-01-recon/) | Scan your account across all 5 pillars | ~15 |
| 02 | [CloudTrail](./lab-02-cloudtrail/) | Enable CloudTrail with KMS encryption | ~40 |
| 03 | [GuardDuty + Security Hub](./lab-03-guardduty-security-hub/) | Enable threat detection services | ~65 |
| 04 | [Config + Access Analyzer](./lab-04-config-access-analyzer/) | Enable compliance monitoring | ~85 |
| Project | [Baseline Lockdown](./project-baseline-lockdown/) | Close all remaining gaps | 100 |

## How It Works

1. **Run the mission status** at any time to see your score:
   ```bash
   bash scripts/mission-status.sh
   ```

2. **Complete labs in order** — each one builds on the previous

3. **Services stay running between labs** — your score persists as you progress

4. **One cleanup script** at the end removes everything:
   ```bash
   bash scripts/chapter-cleanup.sh
   ```

## Estimated Cost

All labs combined: **under $1 if cleaned up same day**

| Service | Cost | Notes |
|---------|------|-------|
| CloudTrail | Free | First trail is free |
| GuardDuty | Free | 30-day free trial |
| Security Hub | Free | 30-day free trial |
| AWS Config | ~$0.01 | Per configuration item recorded |
| KMS | Free | First 20,000 requests/month free |
| S3 | Free | Free tier (5GB) |

**Important:** Run `bash scripts/chapter-cleanup.sh` when you're done to avoid ongoing charges.

## Prerequisites

Before starting this chapter:

1. Completed [Chapter 01: Foundations](../chapter-01-foundations/) and [Chapter 02: Breach Analysis](../chapter-02-breach-analysis/)
2. AWS CLI configured with admin-level permissions
3. Account-level S3 Block Public Access enabled (from Chapter 01)

Verify your setup:
```bash
aws sts get-caller-identity
```

## Learning Path

```
Lab 01: Recon Scan      → See where you stand across 5 pillars
         ↓
Lab 02: CloudTrail      → Record every API call in every region
         ↓
Lab 03: Detection       → Enable GuardDuty + Security Hub
         ↓
Lab 04: Compliance      → Enable Config + Access Analyzer
         ↓
   Project: Baseline Lockdown → Close every gap, reach 100/100
```

## Start the Mission

Begin with [Lab 01: Recon Scan](./lab-01-recon/)
