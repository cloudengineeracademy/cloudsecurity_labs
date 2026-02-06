# Lab 07: Organizations & Service Control Policies

## Overview

**Guardrails that even admins can't override.**

Remember the breach investigation in Lab 06? The attacker tried to delete the CloudTrail trail and stop logging — but both attempts were **DENIED**. The error message said: *"explicit deny in a service control policy."* That SCP saved all the evidence. Without it, the attacker would have erased their tracks completely.

That's the power of Service Control Policies. In this lab, you'll learn how they work, analyze real SCP policies, solve permission scenarios where IAM and SCPs interact, write your own SCPs, and design a multi-account architecture for a real-world scenario.

No multi-account setup required. This is a policy analysis and design lab.

## Cost

This lab uses local files and policy analysis only. **Cost: $0**

## Learning Objectives

1. Understand SCP JSON structure and how it differs from IAM policies
2. Analyze common SCPs that protect production environments
3. Solve IAM + SCP permission scenarios (what's actually allowed?)
4. Write your own SCP from requirements
5. Design a multi-account architecture with appropriate guardrails

---

First, make sure you're in the lab directory:

```bash
cd chapter-03-aws-security-services/lab-07-organizations-scps
```

## Part 1: Understanding SCP Structure

SCPs look like IAM policies but work differently.

**IAM policy** = what you're granted (the floor)
**SCP** = what you're allowed to have (the ceiling)

You only get the **overlap**.

### The SCP JSON format

Open the first example policy:

```bash
cat policies/deny-outside-regions.json | python3 -m json.tool
```

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "DenyOutsideApprovedRegions",
            "Effect": "Deny",
            "Action": "*",
            "Resource": "*",
            "Condition": {
                "StringNotEquals": {
                    "aws:RequestedRegion": [
                        "eu-west-1",
                        "eu-west-2"
                    ]
                },
                "ArnNotLike": {
                    "aws:PrincipalARN": "arn:aws:iam::*:role/OrganizationAdmin"
                }
            }
        }
    ]
}
```

**Key points:**
- `Effect: Deny` — SCPs are almost always deny policies. Every account in an Organization starts with a default `FullAWSAccess` SCP that allows everything. You add deny SCPs on top of that to restrict specific actions.
- `Action: *` — Deny ALL actions...
- `Condition: StringNotEquals` — ...unless the request is in an approved region
- `ArnNotLike` exclusion — The OrganizationAdmin role is exempt (you always need an escape hatch)

### How this SCP works

1. Someone tries to launch an EC2 instance in `ap-southeast-1`
2. SCP checks: is `ap-southeast-1` in the approved list? No.
3. SCP checks: is the caller the OrganizationAdmin role? No.
4. **Result: DENIED** — even if IAM grants full EC2 access

### Read all the example policies

Review each policy in the `policies/` directory:

```bash
ls policies/
```

For each one, read it and answer:
- What does it deny?
- Why is this important for security?
- What escape hatch does it include?

| Policy File | Read It |
|-------------|---------|
| `deny-outside-regions.json` | `cat policies/deny-outside-regions.json \| python3 -m json.tool` |
| `deny-cloudtrail-stop.json` | `cat policies/deny-cloudtrail-stop.json \| python3 -m json.tool` |
| `deny-s3-public.json` | `cat policies/deny-s3-public.json \| python3 -m json.tool` |
| `deny-root-usage.json` | `cat policies/deny-root-usage.json \| python3 -m json.tool` |
| `deny-leave-org.json` | `cat policies/deny-leave-org.json \| python3 -m json.tool` |

---

## Part 2: IAM + SCP Permission Scenarios

This is where it gets practical. You have to determine the **actual** permissions when IAM and SCPs interact.

### The Rule

```
Actual Permission = IAM Allows  AND  SCP Allows
```

If IAM says yes but SCP says no → **DENIED**
If SCP says yes but IAM says no → **DENIED**
Both must allow the action.

### Scenario 1: Region Lock

**Setup:**
- IAM policy on user `alice`: `Allow ec2:* on Resource *`
- SCP on the Production OU: `deny-outside-regions.json` (only `eu-west-1`, `eu-west-2`)

**Questions:**
1. Can Alice launch an EC2 instance in `eu-west-1`?
2. Can Alice launch an EC2 instance in `us-east-1`?
3. Can Alice create an S3 bucket in `eu-west-1`?

<details>
<summary>Answers</summary>

1. **YES** — IAM allows ec2:*, SCP allows eu-west-1. Both say yes.
2. **NO** — IAM allows ec2:*, but SCP denies us-east-1. SCP wins.
3. **NO** — IAM only allows ec2:*. Alice has no S3 permissions. IAM says no, doesn't matter what SCP says.

</details>

### Scenario 2: CloudTrail Protection

**Setup:**
- IAM policy on role `DevOpsAdmin`: `Allow * on Resource *` (full admin)
- SCP on the Production OU: `deny-cloudtrail-stop.json`

**Questions:**
1. Can DevOpsAdmin create an EC2 instance?
2. Can DevOpsAdmin stop CloudTrail logging?
3. Can DevOpsAdmin delete the CloudTrail trail?
4. Can DevOpsAdmin delete CloudWatch log groups?

<details>
<summary>Answers</summary>

1. **YES** — IAM allows *, SCP doesn't deny ec2 actions. Both allow.
2. **NO** — IAM allows *, but SCP explicitly denies cloudtrail:StopLogging. SCP wins.
3. **NO** — SCP explicitly denies cloudtrail:DeleteTrail. Even full admin is blocked.
4. **YES** — The SCP only denies CloudTrail actions (StopLogging, DeleteTrail, UpdateTrail, PutEventSelectors). CloudWatch is not in the deny list.

</details>

### Scenario 3: Multiple SCPs

**Setup:**
- IAM policy on user `bob`: `Allow s3:* on Resource *`
- SCP 1 on Production OU: `deny-outside-regions.json` (eu-west-1, eu-west-2 only)
- SCP 2 on Production OU: `deny-s3-public.json`

**Questions:**
1. Can Bob upload a file to S3 in `eu-west-1`?
2. Can Bob make a bucket public via `PutBucketPublicAccessBlock`?
3. Can Bob upload a file to S3 in `ap-southeast-1`?

<details>
<summary>Answers</summary>

1. **YES** — IAM allows s3:*, both SCPs allow this (correct region, not a public access action).
2. **NO** — Even though IAM allows s3:* and the region is fine, SCP 2 denies public access changes.
3. **NO** — IAM allows s3:*, but SCP 1 denies outside approved regions.

Multiple SCPs ALL must allow. Any single deny wins.

</details>

### Scenario 4: The Management Account Exception

**Setup:**
- SCP on Root OU: `deny-outside-regions.json`
- User is in the **Management Account**

**Question:** Can this user launch EC2 in `us-west-2`?

<details>
<summary>Answer</summary>

**YES** — SCPs never apply to the management account. This is by design. It's also why you never run workloads in the management account.

</details>

---

## Part 3: SCP Challenge

Run the interactive SCP challenge:

```bash
bash scripts/scp-challenge.sh
```

This is a timed quiz that tests your understanding of how SCPs and IAM interact. Aim for 100%.

---

## Part 4: Write Your Own SCP

Now write an SCP from requirements. No peeking at the example policies.

### Requirement

Your company needs an SCP that:
1. Prevents anyone from **deleting KMS keys** (`kms:ScheduleKeyDeletion`, `kms:DisableKey`)
2. Prevents anyone from **disabling GuardDuty** (`guardduty:DeleteDetector`, `guardduty:StopMonitoringMembers`, `guardduty:DisassociateFromMasterAccount`)
3. Exempts a role called `SecurityBreakGlass` (for emergencies)

### Write it

Create a file called `policies/my-protection-scp.json` with your SCP.

**Hints:**
- Use `Effect: Deny`
- List all the denied actions in the `Action` array
- Use a `Condition` with `ArnNotLike` to exempt the break-glass role
- Follow the pattern from the example policies

### Validate your SCP

After writing it, run:

```bash
bash scripts/verify.sh
```

The verification script checks that your SCP has the correct structure, denies the right actions, and includes the escape hatch.

---

## Part 5: Design a Multi-Account Architecture

### Example: How a typical multi-account structure looks

Before you design your own, here's a common pattern:

```
Root (Management Account)
├── Security OU
│   ├── security-audit       ← CloudTrail logs, GuardDuty admin, Security Hub
│   └── security-tooling     ← SIEM, forensics, incident response tools
│
├── Infrastructure OU
│   ├── shared-services      ← DNS, networking, container registries
│   └── ci-cd-pipelines      ← Build/deploy pipelines only
│
├── Workloads OU
│   ├── Production OU
│   │   ├── prod-app-a       ← Customer-facing application
│   │   └── prod-data        ← Databases, data stores
│   │
│   └── Non-Production OU
│       ├── staging           ← Pre-production testing
│       └── dev               ← Development environment
│
└── Sandbox OU
    └── sandbox-experiments   ← Developer experimentation
```

**SCPs applied:**
- **Root OU**: `deny-leave-org`, `deny-root-usage`
- **Security OU**: `deny-cloudtrail-stop` (protect the logs)
- **Production OU**: `deny-outside-regions`, `deny-s3-public`, `deny-cloudtrail-stop`
- **Sandbox OU**: `FullAWSAccess` (no restrictions beyond root-level SCPs)

**Key principles:**
- Security logs live in a dedicated account that workload teams can't access
- Production has strict guardrails; sandbox has freedom
- SCPs get stricter as you move toward production
- Each OU can have different policies — sandbox devs aren't blocked by production rules

### The Scenario

**MedTech Solutions** is a healthcare startup with 45 employees. They process patient data (HIPAA regulated) and need to design their AWS account structure.

**Current state:** Everything runs in one AWS account. Dev, staging, production, and CI/CD pipelines all share the same account.

**Requirements:**
- Patient data must be isolated from all non-production environments
- Developers need freedom to experiment without risking production
- All accounts must log to a central location
- No resources should be created outside `us-east-1` and `us-west-2` (HIPAA compliance)
- Security team needs visibility across all accounts
- CI/CD needs access to deploy to production (but nothing else)

### Your task

Fill in the template:

```bash
cp templates/account-design-template.md my-design.md
```

Edit `my-design.md` to design:

1. **Account structure** — Which accounts and OUs do you need?
2. **SCP assignments** — Which SCPs go on which OUs?
3. **Security services** — Where does CloudTrail, GuardDuty, and Security Hub run?
4. **Justification** — Why did you make these choices?

There's no single right answer. But there are wrong ones (like running patient data in the sandbox account).

---

## Summary

| Concept | What You Learned |
|---------|-----------------|
| SCP structure | JSON deny policies with conditions and escape hatches |
| IAM + SCP interaction | Actual permission = overlap of IAM allows and SCP allows |
| Multiple SCPs | All must allow — any single deny wins |
| Management account | Never affected by SCPs, never run workloads there |
| Multi-account design | Isolation by environment, central security, SCPs as guardrails |

## Key Takeaways

- SCPs are the ceiling. IAM is the floor. You get the overlap.
- SCPs apply to everyone in the OU — including admin users and root in member accounts
- The management account is NEVER affected by SCPs. Keep it clean.
- Always include an escape hatch role in your SCPs (break-glass for emergencies)
- Common SCPs: deny outside regions, protect logging, block public access, deny root
- Multi-account architecture = blast radius reduction. Compromise one account, the others are safe.

## What's Next

You've investigated CloudTrail logs and designed organizational guardrails.

Next: **Chapter 4 — IAM Mastery.** The pillar where 90% of security problems live.
