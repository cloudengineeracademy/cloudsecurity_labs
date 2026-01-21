# Lab 01: Breach Analysis Framework

## Overview

**Before you can prevent breaches, you need to understand how they happen.**

In this lab, you'll learn a systematic approach to analyzing security breaches. You'll apply the 5-question framework to three major cloud breaches: Capital One, Uber, and LastPass. By the end, you'll think like both an attacker and a defender.

## Cost

This lab uses no AWS infrastructure. **Cost: $0**

## Learning Objectives

1. Master the 5-question breach analysis framework
2. Understand the Capital One SSRF attack chain
3. Analyze how hardcoded credentials enabled the Uber breach
4. Examine the LastPass engineer compromise
5. Create a reusable "breach pattern cheat sheet"

---

## Part 1: The 5-Question Framework

Every security breach, no matter how complex, can be broken down into five questions:

### Question 1: How did they get in?

**Initial Access** - The first foothold

This is about finding the door. Attackers need a way in:
- Exploited vulnerability (unpatched software, SSRF, SQL injection)
- Stolen credentials (phishing, password reuse, leaked secrets)
- Misconfiguration (open ports, public buckets, weak permissions)
- Social engineering (MFA fatigue, pretexting)

**What to look for:** The entry point that started everything.

### Question 2: What did they find?

**Discovery** - Mapping the environment

Once inside, attackers explore:
- What services are running?
- What credentials are accessible?
- What data exists and where?
- What permissions does this access grant?

**What to look for:** Information gathering that enabled the next steps.

### Question 3: How did they move?

**Lateral Movement** - Expanding access

Attackers rarely stop at their initial access:
- Privilege escalation (getting more permissions)
- Pivoting (using one system to access others)
- Credential harvesting (collecting more access tokens)

**What to look for:** How initial access became broader compromise.

### Question 4: What did they take?

**Impact** - The actual damage

This is what makes headlines:
- Data exfiltration (customer records, intellectual property)
- System compromise (backdoors, ransomware)
- Business disruption (downtime, recovery costs)
- Regulatory consequences (fines, lawsuits)

**What to look for:** The tangible harm caused by the breach.

### Question 5: When could we have detected it?

**Detection Gaps** - Missed opportunities

The most important question for defenders:
- What logs existed but weren't monitored?
- What alerts could have fired but didn't exist?
- What behavior was anomalous but went unnoticed?
- How long did the attacker have undetected access?

**What to look for:** The moments where detection was possible but failed.

---

## Part 2: Analyze the Capital One Breach (2019)

Read the case study: [case-studies/capital-one.md](./case-studies/capital-one.md)

Then answer the 5 questions:

### Your Analysis

Open the case study file and fill in your answers:

**1. How did they get in?**
```
Your answer: _______________________________________________
```

**2. What did they find?**
```
Your answer: _______________________________________________
```

**3. How did they move?**
```
Your answer: _______________________________________________
```

**4. What did they take?**
```
Your answer: _______________________________________________
```

**5. When could they have detected it?**
```
Your answer: _______________________________________________
```

### Key Pattern: SSRF + IMDS + Over-Permissioned Role

```
SSRF Vulnerability     →    Metadata Service     →    IAM Credentials    →    S3 Access
(Application bug)           (IMDSv1 exposed)          (Over-permissioned)     (106M records)
```

This attack chain is why:
- IMDSv2 was created (requires tokens)
- AWS recommends least-privilege roles
- SSRF is now in OWASP Top 10

---

## Part 3: Analyze the Uber Breach (2022)

Read the case study: [case-studies/uber.md](./case-studies/uber.md)

### Your Analysis

**1. How did they get in?**
```
Your answer: _______________________________________________
```

**2. What did they find?**
```
Your answer: _______________________________________________
```

**3. How did they move?**
```
Your answer: _______________________________________________
```

**4. What did they take?**
```
Your answer: _______________________________________________
```

**5. When could they have detected it?**
```
Your answer: _______________________________________________
```

### Key Pattern: Credential Leak + MFA Fatigue

```
Hardcoded Credentials    →    MFA Fatigue    →    PAM Access    →    Full Compromise
(In private repo)             (Push spam)         (Admin creds)      (Slack, AWS, etc.)
```

This attack shows why:
- Secrets should never be in code (even private repos)
- MFA fatigue attacks bypass "secure" authentication
- Privileged access management (PAM) is critical

---

## Part 4: Analyze the LastPass Breach (2022)

Read the case study: [case-studies/lastpass.md](./case-studies/lastpass.md)

### Your Analysis

**1. How did they get in?**
```
Your answer: _______________________________________________
```

**2. What did they find?**
```
Your answer: _______________________________________________
```

**3. How did they move?**
```
Your answer: _______________________________________________
```

**4. What did they take?**
```
Your answer: _______________________________________________
```

**5. When could they have detected it?**
```
Your answer: _______________________________________________
```

### Key Pattern: Supply Chain + Unencrypted Secrets

```
Engineer Compromise    →    Development Access    →    Cloud Keys    →    Vault Backup
(Personal machine)          (Source code repos)        (Unencrypted)       (25M users)
```

This attack reveals why:
- Developer endpoints are high-value targets
- "Internal" doesn't mean secure
- Encryption at rest must include secrets

---

## Part 5: Build Your Breach Pattern Cheat Sheet

Create a quick reference for common breach patterns:

### Fill in this template:

| Attack Pattern | Real Example | How to Detect | How to Prevent |
|----------------|--------------|---------------|----------------|
| SSRF to IMDS | Capital One | | |
| Hardcoded credentials | Uber | | |
| MFA fatigue | Uber | | |
| Supply chain compromise | LastPass | | |
| Over-permissioned roles | Capital One | | |

### Recommended answers:

| Attack Pattern | Real Example | How to Detect | How to Prevent |
|----------------|--------------|---------------|----------------|
| SSRF to IMDS | Capital One | Metadata API calls, unusual S3 access | IMDSv2, WAF, least privilege |
| Hardcoded credentials | Uber | Secret scanning, repo audits | Secrets Manager, pre-commit hooks |
| MFA fatigue | Uber | Multiple failed MFA, off-hours auth | Phishing-resistant MFA (FIDO2) |
| Supply chain compromise | LastPass | Unusual engineer access patterns | Zero trust, endpoint protection |
| Over-permissioned roles | Capital One | Policy analysis, access reviews | Least privilege, SCPs |

---

## Part 6: Test Your Knowledge

Run the interactive quiz to test your understanding:

```bash
chmod +x scripts/breach-quiz.sh
./scripts/breach-quiz.sh
```

Try to score 100% before moving to the next lab.

---

## Summary

| Breach | Root Cause | Key Lesson |
|--------|------------|------------|
| Capital One | SSRF + IMDSv1 | Require IMDSv2, use least privilege |
| Uber | Hardcoded creds + MFA fatigue | Never store secrets in code |
| LastPass | Engineer compromise | Assume breach, encrypt everything |

## Key Takeaways

- Every breach follows a pattern: access → discovery → movement → impact
- The 5-question framework helps you analyze any breach systematically
- Most breaches involve **preventable misconfigurations**
- Detection opportunities exist throughout the attack chain
- Studying breaches makes you a better defender

## What's Next

Now that you understand how these breaches happened, you'll simulate them safely:

Continue to [Lab 02: SSRF and Metadata Attacks](../lab-02-ssrf-metadata-attack/) - where you'll recreate the Capital One attack pattern.
