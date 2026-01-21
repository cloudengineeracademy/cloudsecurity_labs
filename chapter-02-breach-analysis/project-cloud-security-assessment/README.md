# Project: Cloud Security Assessment

## Overview

**Put everything together. Assess a real AWS environment.**

In this capstone project, you'll conduct a comprehensive security assessment of an AWS environment using everything you've learned in Chapters 01 and 02. You'll identify vulnerabilities, analyze them through the breach framework lens, and produce a professional security report.

## Project Goal

Conduct a security assessment that:
1. Identifies misconfigurations and vulnerabilities
2. Maps findings to real-world breach patterns
3. Provides actionable recommendations
4. Communicates effectively to both technical and executive audiences


## What You'll Deliver

1. **Security Assessment Report** - Professional document with findings
2. **Executive Summary** - 1-page brief for leadership
3. **Remediation Runbook** - Step-by-step fix instructions

---

## Part 1: Choose Your Assessment Target

### Option A: Deploy the Sample Environment (Recommended)

Deploy an intentionally vulnerable environment for assessment:

```bash
cd project-cloud-security-assessment

aws cloudformation create-stack \
  --stack-name security-assessment-target \
  --template-body file://sample-environment/vulnerable-environment.yaml \
  --capabilities CAPABILITY_NAMED_IAM
```

This creates a realistic environment with:
- Multiple EC2 instances with varying security postures
- S3 buckets with different configurations
- IAM users and roles with various permission levels
- Security groups with mixed rule sets

### Option B: Assess Your Own Environment

If you have an existing AWS account you'd like to assess:

1. Ensure you have appropriate permissions
2. Get written authorization if it's a work account
3. Start with non-production environments

### Option C: Assess a Colleague's Lab

Partner with someone who has completed the Chapter 02 labs:
- They deploy Lab 02 (SSRF) or Lab 03 (Credentials) infrastructure
- You assess it without knowing the specific vulnerabilities
- Compare your findings to the actual issues

---

## Part 2: Conduct the Assessment

### 2.1 Reconnaissance

Start by understanding what exists:

```bash
# Run the reconnaissance script
chmod +x scripts/recon.sh
./scripts/recon.sh
```

Or manually gather information:

```bash
# List EC2 instances
aws ec2 describe-instances --query 'Reservations[].Instances[].{ID:InstanceId,Type:InstanceType,State:State.Name,PublicIP:PublicIpAddress}' --output table

# List S3 buckets
aws s3 ls

# List IAM users
aws iam list-users --query 'Users[].UserName' --output table

# List security groups
aws ec2 describe-security-groups --query 'SecurityGroups[].{Name:GroupName,ID:GroupId,VPC:VpcId}' --output table
```

### 2.2 Vulnerability Scanning

Check each resource category:

```bash
# Run the full security scan
chmod +x scripts/security-scan.sh
./scripts/security-scan.sh
```

**Manual checks to perform:**

#### Identity (IAM)
```bash
# Users without MFA
aws iam list-users --query 'Users[].UserName' --output text | while read user; do
  MFA=$(aws iam list-mfa-devices --user-name $user --query 'MFADevices[0]' --output text)
  if [ "$MFA" = "None" ] || [ -z "$MFA" ]; then
    echo "[FINDING] $user has no MFA"
  fi
done

# Users with access keys
aws iam list-users --query 'Users[].UserName' --output text | while read user; do
  KEYS=$(aws iam list-access-keys --user-name $user --query 'length(AccessKeyMetadata)')
  if [ "$KEYS" -gt 0 ]; then
    echo "[FINDING] $user has $KEYS access key(s)"
  fi
done
```

#### Network (Security Groups)
```bash
# Security groups with 0.0.0.0/0 ingress
aws ec2 describe-security-groups \
  --query 'SecurityGroups[?IpPermissions[?IpRanges[?CidrIp==`0.0.0.0/0`]]].{Name:GroupName,ID:GroupId}' \
  --output table
```

#### Data (S3)
```bash
# Buckets without public access block
aws s3 ls | awk '{print $3}' | while read bucket; do
  BLOCK=$(aws s3api get-public-access-block --bucket $bucket 2>&1)
  if echo "$BLOCK" | grep -q "NoSuchPublicAccessBlockConfiguration"; then
    echo "[FINDING] $bucket has no public access block"
  fi
done
```

#### Compute (EC2)
```bash
# Instances with IMDSv1 enabled
aws ec2 describe-instances \
  --query 'Reservations[].Instances[?MetadataOptions.HttpTokens==`optional`].{ID:InstanceId,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table
```

### 2.3 Apply the 5-Question Framework

For each finding, ask:

1. **How could an attacker exploit this?**
2. **What would they discover after exploitation?**
3. **How could they expand their access?**
4. **What data or systems could they compromise?**
5. **What logs or alerts would we see?**

### 2.4 Map to Real Breaches

Connect your findings to the breaches you studied:

| Finding | Similar to | Real-World Impact |
|---------|------------|-------------------|
| IMDSv1 enabled | Capital One | Credential theft via SSRF |
| Hardcoded secrets | Uber | Direct system access |
| Excessive IAM permissions | Capital One | Lateral movement |
| Missing MFA | Uber | Account compromise |

---

## Part 3: Document Your Findings

### 3.1 Use the Assessment Template

```bash
cp templates/assessment-report-template.md my-assessment-report.md
```

### 3.2 Finding Format

For each finding, document:

```markdown
### Finding [NUMBER]: [Title]

**Severity:** Critical / High / Medium / Low

**Category:** Identity / Network / Data / Compute

**Description:**
[What the issue is]

**Evidence:**
[Commands run and output]

**Risk:**
[What could happen if exploited]

**Breach Parallel:**
[Which real breach used a similar vulnerability]

**Recommendation:**
[Specific steps to fix]

**Remediation Command:**
```bash
[Exact command to fix the issue]
```
```

### 3.3 Write the Executive Summary

Use the template:

```bash
cp templates/executive-summary-template.md my-executive-summary.md
```

Focus on:
- Business risk, not technical details
- Number and severity of findings
- Overall security posture rating
- Top 3 priorities

---

## Part 4: Create Remediation Runbook

Document step-by-step fix instructions:

```bash
cp templates/remediation-runbook-template.md my-remediation-runbook.md
```

For each fix:
1. Pre-requisites
2. Exact commands
3. Verification steps
4. Rollback procedure (if applicable)

---

## Part 5: Verify Your Work

### 5.1 Run the Assessment Checker

```bash
chmod +x scripts/check-assessment.sh
./scripts/check-assessment.sh my-assessment-report.md
```

### 5.2 Quality Checklist

- [ ] All resource categories scanned (IAM, Network, Data, Compute)
- [ ] Each finding has severity, evidence, and recommendation
- [ ] Findings mapped to real breach patterns
- [ ] Executive summary is non-technical and under 1 page
- [ ] Remediation runbook has testable commands
- [ ] No sensitive data (real keys, passwords) in report

---

## Part 6: Cleanup

If you deployed the sample environment:

```bash
aws cloudformation delete-stack --stack-name security-assessment-target
```

---

## Scoring Rubric

### Findings Quality (40 points)
- Identified all critical issues: 15 points
- Identified all high issues: 10 points
- Identified medium/low issues: 5 points
- Proper severity ratings: 5 points
- Clear evidence for each: 5 points

### Breach Analysis (20 points)
- Correctly mapped to real breaches: 10 points
- Explained attack scenarios: 10 points

### Report Quality (25 points)
- Professional formatting: 5 points
- Clear recommendations: 10 points
- Executive summary quality: 10 points

### Remediation Runbook (15 points)
- Accurate fix commands: 10 points
- Includes verification steps: 5 points

**Total: 100 points**

| Score | Rating |
|-------|--------|
| 90-100 | Excellent - Ready for professional assessments |
| 80-89 | Good - Minor improvements needed |
| 70-79 | Satisfactory - Review methodology |
| <70 | Needs Work - Revisit Chapter 01-02 labs |

---

## Example Finding

```markdown
### Finding 1: EC2 Instance Vulnerable to SSRF Credential Theft

**Severity:** Critical

**Category:** Compute

**Description:**
EC2 instance i-0abc123def456 has IMDSv1 enabled (HttpTokens: optional).
This allows any SSRF vulnerability in applications on this instance to
retrieve IAM credentials from the metadata service without authentication.

**Evidence:**
```
$ aws ec2 describe-instances --instance-ids i-0abc123def456 \
    --query 'Reservations[0].Instances[0].MetadataOptions'

{
    "State": "applied",
    "HttpTokens": "optional",    ← VULNERABLE
    "HttpPutResponseHopLimit": 1,
    "HttpEndpoint": "enabled"
}
```

**Risk:**
An attacker who finds any SSRF vulnerability in applications running on
this instance can steal IAM credentials and use them to access AWS
resources. This is the exact attack pattern used in the Capital One
breach, which exposed 106 million customer records.

**Breach Parallel:**
Capital One (2019) - SSRF + IMDSv1 enabled credential theft

**Recommendation:**
Require IMDSv2 by setting HttpTokens to "required". This forces
applications to obtain a session token via a PUT request before
accessing metadata, which SSRF attacks typically cannot perform.

**Remediation Command:**
```bash
aws ec2 modify-instance-metadata-options \
  --instance-id i-0abc123def456 \
  --http-tokens required \
  --http-endpoint enabled
```
```

---

## What You've Accomplished

By completing this project, you've demonstrated:

1. **Technical Skills** - Ability to scan and identify AWS misconfigurations
2. **Analytical Thinking** - Connecting findings to real-world attack patterns
3. **Communication** - Writing for both technical and executive audiences
4. **Practical Security** - Creating actionable remediation steps

This is exactly what cloud security professionals do in real assessments.

---

## Next Steps

- Apply this methodology to your production environments
- Automate recurring assessments with AWS Config or third-party tools
- Study for AWS Security Specialty certification
- Continue to Chapter 03 for advanced topics

**Congratulations on completing Chapter 02!**
