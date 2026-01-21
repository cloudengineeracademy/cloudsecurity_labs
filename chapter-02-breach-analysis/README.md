# Chapter 02: Real-World Breach Analysis

## Overview

**Learn from the failures that cost companies billions.**

In this chapter, you'll analyze three major cloud security breaches—Capital One, Uber, and LastPass—and understand exactly how they happened. More importantly, you'll simulate attack patterns in a safe environment and learn how to prevent them.

## Why Study Breaches?

Every major breach teaches us something:

| Breach | Year | Records Exposed | Root Cause |
|--------|------|-----------------|------------|
| Capital One | 2019 | 106 million | SSRF + IMDSv1 + over-permissioned role |
| Uber | 2022 | 57 million | Hardcoded credentials + MFA fatigue |
| LastPass | 2022 | 25 million vaults | Unencrypted secrets + compromised engineer |

The common thread? **Preventable misconfigurations that you'll learn to identify and fix.**

## The 5-Question Framework

Every breach can be analyzed with five questions:

1. **How did they get in?** (Initial access)
2. **What did they find?** (Discovery)
3. **How did they move?** (Lateral movement)
4. **What did they take?** (Impact)
5. **When could we have detected it?** (Detection gaps)

## Labs in This Chapter

| Lab | Title | What You'll Do | AWS Infra? |
|-----|-------|----------------|------------|
| 01 | [Breach Analysis Framework](./lab-01-breach-framework/) | Learn the 5-question methodology | No |
| 02 | [SSRF and Metadata Attacks](./lab-02-ssrf-metadata-attack/) | Simulate the Capital One attack | Yes |
| 03 | [Credential Security](./lab-03-credential-security/) | Find and fix hardcoded secrets | Yes |
| 04 | [Breach Post-Mortem Report](./lab-04-breach-postmortem/) | Write professional security reports | No |

## Estimated Cost

All labs combined: **~$0.00** (free tier eligible)

| Resource | Labs Used | Free Tier Coverage |
|----------|-----------|-------------------|
| EC2 t2.micro | Lab 02 | 750 hours/month |
| S3 | Lab 02 | 5GB storage |
| Secrets Manager | Lab 03 | 30-day free trial |

**Important:** Always run cleanup scripts after each lab to avoid charges.

## Prerequisites

Before starting this chapter:

1. Completed [Chapter 01: Foundations](../chapter-01-foundations/) (recommended)
2. AWS CLI configured with appropriate permissions
3. Basic understanding of:
   - IAM roles and policies
   - EC2 instances and security groups
   - S3 buckets and access controls

## Learning Path

```
Lab 01: Framework    → Understand how to analyze breaches
         ↓
Lab 02: SSRF Attack  → Simulate Capital One attack pattern
         ↓
Lab 03: Credentials  → Prevent Uber/LastPass patterns
         ↓
Lab 04: Post-Mortem  → Communicate findings professionally
         ↓
   Project: Cloud Security Assessment
```

## Key Concepts Covered

- **SSRF (Server-Side Request Forgery)** - Making servers request internal resources
- **Instance Metadata Service (IMDS)** - How EC2 exposes credentials
- **IMDSv1 vs IMDSv2** - The difference that prevents breaches
- **Credential hygiene** - Secrets management best practices
- **Security communication** - Writing for technical and executive audiences

## Start Learning

Begin with [Lab 01: Breach Analysis Framework](./lab-01-breach-framework/)
