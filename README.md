# Cloud Security Labs - Chapter 1: Foundations

Welcome to the hands-on labs for the Cloud Security Accelerator program.

## Prerequisites

Before starting these labs, ensure you have:

- [ ] AWS Account (free tier eligible)
- [ ] AWS CLI installed and configured
- [ ] Terminal/Command Line access
- [ ] A code editor (VS Code, Cursor, etc.)

## Verify Your Setup

Run this command to verify your AWS CLI is configured:

```bash
aws sts get-caller-identity
```

You should see your Account ID and User ARN.

## Cost Warning

**These labs are designed to be 100% FREE** using AWS Free Tier services only.

What's FREE:

- IAM (Identity and Access Management) - Always free
- S3 (within free tier: 5GB storage, 20,000 GET requests, 2,000 PUT requests)
- VPC and Security Groups - Always free
- CloudTrail (1 trail for management events) - Always free

What we AVOID:

- AWS Config (costs per rule evaluation)
- GuardDuty (only 30-day trial)
- Multiple CloudTrail trails or data events

## Lab Overview

| Lab                                                                                   | Duration  | Skills                        |
| ------------------------------------------------------------------------------------- | --------- | ----------------------------- |
| [Lab 01: Secure AWS Account](./chapter-01-foundations/lab-01-secure-aws-account/)     | 30-45 min | Account hardening, IAM, MFA   |
| [Lab 02: Attack Surface Recon](./chapter-01-foundations/lab-02-attack-surface-recon/) | 45 min    | CLI mastery, attacker mindset |
| [Lab 03: CIA Triad with S3](./chapter-01-foundations/lab-03-cia-triad-s3/)            | 30 min    | S3 security, encryption       |
| [Lab 04: Defence Layers Audit](./chapter-01-foundations/lab-04-defence-layers-audit/) | 20 min    | Gap analysis, assessment      |

## Exercises

| Exercise                                                               | Duration | Type                  |
| ---------------------------------------------------------------------- | -------- | --------------------- |
| [Breach Analysis](./chapter-01-foundations/exercises/breach-analysis/) | 20 min   | Case study            |
| [Threat Modeling](./chapter-01-foundations/exercises/threat-modeling/) | 30 min   | Architecture analysis |

## Mini Project

| Project                                                                        | Duration | Skills                     |
| ------------------------------------------------------------------------------ | -------- | -------------------------- |
| [Security Audit Script](./chapter-01-foundations/mini-project-security-audit/) | 60 min   | Bash scripting, automation |

## How to Use These Labs

1. Clone this repository
2. Complete labs in order (Lab 01 → 02 → 03 → 04)
3. Each lab has a `README.md` with step-by-step instructions
4. Run the verification scripts to check your work
5. Complete the exercises after finishing the labs

## Getting Help

If you get stuck:

1. Re-read the instructions carefully
2. Check AWS documentation
3. Google the error message
4. Ask in the course community

Let's build your Cloud Security Skills!
