# Cloud Security Labs

Hands-on labs for learning AWS cloud security. Build real skills by deploying infrastructure, finding vulnerabilities, and fixing them.

## Who This Is For

- Developers wanting to understand cloud security
- DevOps engineers moving into security
- Anyone preparing for cloud security roles

## Prerequisites

Before starting, ensure you have:

- AWS Account (free tier eligible)
- AWS CLI installed and configured
- Terminal access (Mac/Linux/WSL)
- Basic command line familiarity

**Verify your setup:**

```bash
aws sts get-caller-identity
```

You should see your Account ID and ARN. If you get an error, run `aws configure` first.

## Cost

**These labs are designed to stay within AWS Free Tier.**

| Resource | Cost |
|----------|------|
| IAM | Always free |
| S3 | Free tier (5GB storage) |
| EC2 | Free tier (t2.micro) |
| VPC/Security Groups | Always free |

**Important:** Always run the cleanup steps at the end of each lab to avoid charges.

---

## Chapter 1: Foundations

Learn the core concepts every cloud security engineer needs.

| Lab | What You'll Learn |
|-----|-------------------|
| [Lab 01: Secure AWS Account](./chapter-01-foundations/lab-01-secure-aws-account/) | Account hardening, IAM basics, MFA |
| [Lab 02: Attack Surface Recon](./chapter-01-foundations/lab-02-attack-surface-recon/) | Deploy vulnerable infra, scan it, fix it |
| [Lab 03: CIA Triad with S3](./chapter-01-foundations/lab-03-cia-triad-s3/) | Confidentiality, Integrity, Availability |
| [Lab 04: Defence Layers Audit](./chapter-01-foundations/lab-04-defence-layers-audit/) | 6 defence layers, security auditing |

**Complete the labs in order.** Each builds on concepts from the previous one.

---

## How to Use These Labs

1. **Clone this repository**
   ```bash
   git clone <your-repo-url>
   cd cloudsecurity_labs
   ```

2. **Complete labs in order**
   - Lab 01 → 02 → 03 → 04
   - Each lab has a README with step-by-step instructions

3. **Don't just copy-paste**
   - Read what each command does
   - Understand the "why" behind each check
   - Verify results in the AWS Console

4. **Clean up after each lab**
   - Delete resources to avoid charges
   - Each lab has cleanup instructions at the end

---

## The Security Engineer Mindset

As you work through these labs, think like a security engineer:

**1. Assume Breach**
Don't ask "will we be attacked?" Ask "when we're attacked, what will they get?"

**2. Think in Layers**
No single control is perfect. If the firewall fails, does encryption save you?

**3. Blast Radius**
When something goes wrong, how bad is it? A compromised instance with no IAM role is bad. With admin permissions? Catastrophic.

**4. Evidence Over Assumptions**
Don't assume things are configured correctly. Query the actual state. Trust but verify.

---

## Getting Help

If you get stuck:

1. Re-read the instructions carefully
2. Check the expected output in the lab
3. Verify in the AWS Console
4. Search the error message

---

## What's Next

After completing Chapter 1, you'll have:

- A secured AWS account foundation
- Skills to find and fix vulnerabilities
- Understanding of CIA controls
- Experience with security auditing

Continue to Chapter 2: IAM Deep Dive (coming soon).
