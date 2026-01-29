# Lab 03: GuardDuty + Security Hub — Threat Detection

## Overview

**GuardDuty is watching.**

CloudTrail records what happened. GuardDuty tells you when something is wrong. Security Hub brings it all together. In this lab, you'll enable both services yourself, generate sample threat findings, explore them in the Console, and practice triaging security alerts.

## What You'll Learn

- How to enable and configure GuardDuty and Security Hub
- How GuardDuty detects threats using ML and threat intelligence
- How Security Hub aggregates findings from multiple services
- How to read and triage findings in the AWS Console
- How to categorise security alerts by severity

## Cost

**$0** — Both services offer a 30-day free trial.

| Service | Trial | After Trial |
|---------|-------|-------------|
| GuardDuty | 30 days free | ~$4/million events |
| Security Hub | 30 days free | ~$0.0010/check |

**Important:** Run the chapter cleanup script when done to disable both services.

## Prerequisites

- Completed Lab 02 (CloudTrail enabled)
- AWS CLI configured with admin permissions

## Steps

### Part 1: Enable GuardDuty

GuardDuty analyses three data sources automatically — CloudTrail events, VPC Flow Logs, and DNS logs. You don't need to configure any of these; GuardDuty reads them directly.

Enable GuardDuty:

```bash
GD_DETECTOR_ID=$(aws guardduty create-detector --enable \
    --finding-publishing-frequency FIFTEEN_MINUTES \
    --query 'DetectorId' --output text)

echo "Detector ID: $GD_DETECTOR_ID"
```

**Write down your Detector ID.** You'll need it later.

Verify it's running:

```bash
aws guardduty get-detector --detector-id $GD_DETECTOR_ID \
    --query '{Status:Status,FindingPublishingFrequency:FindingPublishingFrequency}' \
    --output table
```

You should see `Status: ENABLED` and `FindingPublishingFrequency: FIFTEEN_MINUTES`.

#### Console Checkpoint: GuardDuty

1. Open the AWS Console → **GuardDuty**
2. You should see the GuardDuty dashboard (not the "Get started" page)
3. Click **Settings** — verify:
   - **Detector status:** Enabled
   - **Updated findings:** Every 15 minutes
4. Click **Usage** — this shows your free trial status and estimated costs
5. Note: The **Findings** page will be empty — no threats detected yet. That's expected.

### Part 2: Enable Security Hub

Security Hub aggregates findings from GuardDuty, Config, and other services into a single dashboard. It also runs automated compliance checks.

Enable Security Hub with default standards:

```bash
aws securityhub enable-security-hub --enable-default-standards
```

Check which standards were enabled:

```bash
aws securityhub get-enabled-standards \
    --query 'StandardsSubscriptions[].{Standard:StandardsArn,Status:StandardsStatus}' \
    --output table
```

You should see the **AWS Foundational Security Best Practices** standard (and possibly CIS Benchmarks).

#### Console Checkpoint: Security Hub

1. Open the AWS Console → **Security Hub**
2. You should see the Security Hub dashboard
3. Click **Security standards** on the left:
   - **AWS Foundational Security Best Practices** should show as enabled
   - Note the compliance score — it will be low at first, since checks take time to run
4. Click **Findings** — you'll start seeing automated checks appear over the next 15-30 minutes
5. Click **Summary** — this gives you an overview of findings by severity

**Wait 5 minutes**, then refresh the Findings page. You should start seeing automated compliance checks from the enabled standards.

### Part 3: Generate Sample Findings

GuardDuty normally takes time to detect real threats. For learning, generate sample findings:

```bash
aws guardduty create-sample-findings --detector-id $GD_DETECTOR_ID
```

Wait 10 seconds, then list the sample findings:

```bash
aws guardduty list-findings --detector-id $GD_DETECTOR_ID \
    --finding-criteria '{"Criterion":{"service.additionalInfo.sample":{"Eq":["true"]}}}' \
    --query 'FindingIds | length(@)' --output text
```

You should see a number like 30-50 sample findings generated.

Look at a high-severity finding:

```bash
FINDING_ID=$(aws guardduty list-findings --detector-id $GD_DETECTOR_ID \
    --finding-criteria '{"Criterion":{"severity":{"Gte":7},"service.additionalInfo.sample":{"Eq":["true"]}}}' \
    --query 'FindingIds[0]' --output text)

aws guardduty get-findings --detector-id $GD_DETECTOR_ID \
    --finding-ids $FINDING_ID \
    --query 'Findings[0].{Type:Type,Severity:Severity,Title:Title,Description:Description}' \
    --output table
```

Or run the script for a more detailed breakdown:

```bash
bash lab-03-guardduty-security-hub/scripts/generate-findings.sh
```

#### Console Checkpoint: GuardDuty Findings

This is the most important Console checkpoint. Open **GuardDuty → Findings** and explore:

1. **Sort by severity** — Click the severity column header. HIGH findings are at the top.
2. **Click on a HIGH finding** (e.g., `CryptoCurrency:EC2/BitcoinTool.B!DNS`). Read:
   - **Title:** What happened
   - **Severity:** How bad is it (1-10 scale)
   - **Description:** Plain-language explanation
   - **Resource affected:** Which EC2 instance, IAM user, or S3 bucket
   - **Action:** Network connections or API calls involved
3. **Click on a MEDIUM finding** (e.g., `Recon:EC2/PortProbeUnprotectedPort`). Notice how the detail differs.
4. **Try the filter:** Filter by finding type containing "Unauthorized" — these are credential-related findings.

**Key question:** If you saw `CryptoCurrency:EC2/BitcoinTool.B!DNS` on a real instance, what would you do FIRST? (Answer: Isolate the instance — don't delete it, you need it for forensics.)

### Part 4: Explore Security Hub Findings

Open **Security Hub → Findings**:

1. Filter findings by **Product name = GuardDuty** — you should see the sample findings appear here too
2. Filter by **Compliance status = FAILED** — these are the automated checks from the security standards
3. Click on a FAILED finding — it will tell you:
   - Which resource is non-compliant
   - Which standard the check belongs to
   - Remediation guidance

**Try this:** Find a finding related to CloudTrail. Is it PASSED or FAILED? If you completed Lab 02 correctly, CloudTrail checks should be PASSED.

### Part 5: Triage Exercise

Practice categorising findings by severity and response:

```bash
bash lab-03-guardduty-security-hub/scripts/triage-exercise.sh
```

This is an interactive quiz — 6 questions about real GuardDuty finding types. You'll learn:
- Which severity level each finding type represents
- The correct first response for each type
- How to prioritise multiple simultaneous findings

Use `templates/triage-worksheet.md` to practice documenting a finding from the Console.

### Part 6: Verify and Score

```bash
bash lab-03-guardduty-security-hub/scripts/verify.sh
```

All 4 checks should pass. Then check your score:

```bash
bash scripts/mission-status.sh
```

**Expected score: ~65/100** (+25 from Detection pillar)

## Key Concepts

### GuardDuty Data Sources

GuardDuty analyses three data sources automatically:

| Source | What It Detects | Example Finding |
|--------|----------------|-----------------|
| CloudTrail Events | Unusual API calls, credential abuse | `UnauthorizedAccess:IAMUser/ConsoleLoginSuccess.B` |
| VPC Flow Logs | Network traffic patterns, port scans | `Recon:EC2/PortProbeUnprotectedPort` |
| DNS Logs | Communication with malicious domains | `CryptoCurrency:EC2/BitcoinTool.B!DNS` |

### Finding Severity Levels

| Severity | Range | Action | Example |
|----------|-------|--------|---------|
| Critical | 9.0-10.0 | Immediate incident response | Credential exfiltration |
| High | 7.0-8.9 | Investigate within hours | Bitcoin mining on EC2 |
| Medium | 4.0-6.9 | Investigate within 24 hours | Port scanning |
| Low | 1.0-3.9 | Review when time permits | DNS query anomaly |

### Response Priority

```
Active compromise (crypto mining, data exfil)  → Isolate NOW
      ↓
Credential abuse (unusual logins)              → Verify with user, rotate if unconfirmed
      ↓
Reconnaissance (port scanning)                 → Review security groups, monitor
      ↓
Configuration drift (policy changes)           → Review and revert if unauthorised
```

## Alternative: Run Enable Script

If you need to redo setup quickly:

```bash
bash lab-03-guardduty-security-hub/scripts/enable-detection.sh
```

## What's Next

Proceed to [Lab 04: Config + Access Analyzer](../lab-04-config-access-analyzer/) to enable compliance monitoring.
