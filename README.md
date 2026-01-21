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
| EC2 | Free tier (t2.micro, 750 hrs/month) |
| Secrets Manager | 30-day free trial |
| VPC/Security Groups | Always free |

**Important:** Always run the cleanup steps at the end of each lab to avoid charges.

---

## Learning Path

```
Chapter 01: Foundations
    ↓
Chapter 02: Real-World Breach Analysis
    ↓
Project: Cloud Security Assessment
```

---

## Chapter 01: Foundations

Learn the core concepts every cloud security engineer needs.

| Lab | What You'll Learn |
|-----|-------------------|
| [Lab 01: Secure AWS Account](./chapter-01-foundations/lab-01-secure-aws-account/) | Account hardening, IAM basics, MFA |
| [Lab 02: Attack Surface Recon](./chapter-01-foundations/lab-02-attack-surface-recon/) | Deploy vulnerable infra, scan it, fix it |
| [Lab 03: CIA Triad with S3](./chapter-01-foundations/lab-03-cia-triad-s3/) | Confidentiality, Integrity, Availability |
| [Lab 04: Defence Layers Audit](./chapter-01-foundations/lab-04-defence-layers-audit/) | 6 defence layers, security auditing |
| [Lab 05: Share Your Journey](./chapter-01-foundations/lab-05-share-your-journey/) | Write a LinkedIn article, build your brand |

---

## Chapter 02: Real-World Breach Analysis

Learn from the failures that cost companies billions. Analyze Capital One, Uber, and LastPass breaches, then simulate attack patterns in a safe environment.

| Lab | What You'll Learn |
|-----|-------------------|
| [Lab 01: Breach Analysis Framework](./chapter-02-breach-analysis/lab-01-breach-framework/) | The 5-question methodology for analyzing any breach |
| [Lab 02: SSRF and Metadata Attacks](./chapter-02-breach-analysis/lab-02-ssrf-metadata-attack/) | Simulate the Capital One attack (SSRF + IMDSv1) |
| [Lab 03: Credential Security](./chapter-02-breach-analysis/lab-03-credential-security/) | Find hardcoded secrets, use Secrets Manager |
| [Lab 04: Breach Post-Mortem Report](./chapter-02-breach-analysis/lab-04-breach-postmortem/) | Write professional security documentation |

### Capstone Project

| Project | What You'll Do |
|---------|----------------|
| [Cloud Security Assessment](./chapter-02-breach-analysis/project-cloud-security-assessment/) | Conduct a full security assessment of an AWS environment |

---

## How to Use These Labs

1. **Clone this repository**
   ```bash
   git clone <your-repo-url>
   cd cloud-security-labs
   ```

2. **Complete chapters in order**
   - Chapter 01 → Chapter 02 → Project
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

## The 5-Question Framework

Every breach can be analyzed with five questions:

1. **How did they get in?** (Initial access)
2. **What did they find?** (Discovery)
3. **How did they move?** (Lateral movement)
4. **What did they take?** (Impact)
5. **When could we have detected it?** (Detection gaps)

You'll master this framework in Chapter 02.

---

## Getting Help

If you get stuck:

1. Re-read the instructions carefully
2. Check the expected output in the lab
3. Verify in the AWS Console
4. Search the error message

---

## What You'll Achieve

After completing these labs, you'll have:

- A secured AWS account foundation
- Skills to find and fix cloud vulnerabilities
- Understanding of real breach patterns (Capital One, Uber, LastPass)
- Experience simulating attacks and implementing fixes
- Ability to write professional security reports
- A portfolio project demonstrating your skills

---

## Start Learning

Begin with [Chapter 01: Foundations](./chapter-01-foundations/)
