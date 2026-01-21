# Lab 04: Defence in Depth Audit

## Overview

In Chapter 1, you learned about the **6 Defence Layers**:

| Layer        | What It Protects                                   |
| ------------ | -------------------------------------------------- |
| 1. Perimeter | Traffic before it reaches your apps (WAF, DDoS)    |
| 2. Network   | What can reach what (VPC, Security Groups)         |
| 3. Identity  | Who can do what (IAM)                              |
| 4. Compute   | What runs your code (EC2, Lambda)                  |
| 5. Data      | What attackers want (S3, RDS)                      |
| 6. Detection | Knowing when something's wrong (GuardDuty, Config) |

In this lab, you'll deploy infrastructure with security gaps across multiple layers, audit it, and understand what needs fixing.

## Cost

- **EC2**: t2.micro (free tier eligible)
- **S3**: Minimal (empty bucket)
- **IAM**: Free

**Important**: Delete the stack when done to avoid charges.

## Learning Objectives

By the end of this lab, you will:

1. Deploy infrastructure with intentional security gaps
2. Run an automated security audit
3. Understand findings across all 6 defence layers
4. Know how to prioritize remediation

---

## Part 1: Deploy Audit Infrastructure

### Step 1.1: Deploy the Stack

```bash
aws cloudformation create-stack \
  --stack-name lab04-audit-infra \
  --template-body file://templates/audit-infra.yaml \
  --capabilities CAPABILITY_NAMED_IAM
```

### Step 1.2: Wait for Deployment

```bash
aws cloudformation describe-stacks \
  --stack-name lab04-audit-infra \
  --query 'Stacks[0].StackStatus' \
  --output text
```

Wait for `CREATE_COMPLETE` (2-3 minutes).

### Step 1.3: View What Was Created

```bash
aws cloudformation describe-stacks \
  --stack-name lab04-audit-infra \
  --query 'Stacks[0].Outputs' \
  --output table
```

You've deployed:

- VPC with only public subnets (no private)
- Security group with SSH open to 0.0.0.0/0
- EC2 instance with IMDSv1 and public IP
- S3 bucket without encryption
- IAM user with access key (no MFA)

Cross check everything in the AWS Console 1 by 1 - to make sure you understand what you are deploying.

---

## Part 2: Run the Security Audit

### Step 2.1: Run the Audit Script

```bash
chmod +x scripts/defence-audit.sh
./scripts/defence-audit.sh
```

The script checks each of the 6 defence layers and provides:

- A score for each layer
- A final percentage score
- Priority recommendations

### Step 2.2: Review Your Findings

You should see findings like:

| Layer    | Finding                          |
| -------- | -------------------------------- |
| Network  | Security groups allow 0.0.0.0/0  |
| Network  | Only public subnets (no private) |
| Identity | User without MFA                 |
| Compute  | IMDSv1 enabled                   |
| Compute  | EC2 has public IP                |
| Data     | S3 bucket not encrypted          |

---

## Part 3: Understand the Findings

### Network Layer Findings

**Open Security Groups**

```bash
aws ec2 describe-security-groups \
  --filters Name=group-name,Values=lab04-open-sg \
  --query 'SecurityGroups[0].IpPermissions[].{Port:FromPort,Source:IpRanges[0].CidrIp}' \
  --output table
```

Why it matters: Anyone on the internet can attempt to connect to port 22.

**No Private Subnets**

```bash
aws ec2 describe-subnets \
  --filters "Name=tag:Lab,Values=cloud-security-lab-04" \
  --query 'Subnets[].{Name:Tags[?Key==`Name`].Value|[0],Public:MapPublicIpOnLaunch}' \
  --output table
```

Why it matters: All resources are directly exposed to the internet.

---

### Identity Layer Findings

**IAM User Without MFA**

```bash
aws iam list-mfa-devices --user-name lab04-audit-user
```

Why it matters: If credentials are compromised, there's no second factor to stop attackers.

**User Has Access Key**

```bash
aws iam list-access-keys --user-name lab04-audit-user --output table
```

Why it matters: Long-lived credentials can leak and be used from anywhere.

---

### Compute Layer Findings

**IMDSv1 Enabled**

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Lab,Values=cloud-security-lab-04" \
  --query 'Reservations[].Instances[].{Id:InstanceId,IMDSv2:MetadataOptions.HttpTokens}' \
  --output table
```

Why it matters: SSRF attacks can steal IAM credentials from the metadata service. This caused the Capital One breach.

**Public IP Assigned**

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Lab,Values=cloud-security-lab-04" \
  --query 'Reservations[].Instances[].{Id:InstanceId,PublicIP:PublicIpAddress}' \
  --output table
```

Why it matters: Direct internet exposure increases attack surface.

---

### Data Layer Findings

**S3 Bucket Not Encrypted**

```bash
BUCKET=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `lab04`)].Name' --output text)
aws s3api get-bucket-encryption --bucket $BUCKET 2>&1 || echo "NOT ENCRYPTED"
```

Why it matters: Data at rest is readable if storage is compromised.

**Public Access Block Not Configured**

```bash
aws s3api get-public-access-block --bucket $BUCKET 2>&1
```

Why it matters: Misconfigured policies could expose data to the internet.

---

## Part 4: Prioritize Remediation

Based on the audit, here's how to prioritize:

### Critical (Fix Immediately)

- SSH open to 0.0.0.0/0
- Users without MFA
- Root access keys (if any)

### High (Fix This Week)

- IMDSv1 enabled on EC2
- Unencrypted S3 buckets
- Access keys on IAM users

### Medium (Plan For)

- Add private subnets
- Enable GuardDuty
- Implement WAF

---

## Part 5: Cleanup

Delete all resources to avoid charges:

```bash
# Empty the S3 bucket first (required before deletion)
BUCKET=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `lab04`)].Name' --output text)
aws s3 rm s3://$BUCKET --recursive 2>/dev/null

# Delete the stack
aws cloudformation delete-stack --stack-name lab04-audit-infra
```

Verify deletion:

```bash
aws cloudformation describe-stacks --stack-name lab04-audit-infra 2>&1 | grep -q "does not exist" && echo "Stack deleted" || echo "Still deleting..."
```

---

## Summary

Defence in Depth means **layered security**. No single control is perfect, so we use overlapping defences:

| If This Fails...             | These Catch It                   |
| ---------------------------- | -------------------------------- |
| Perimeter bypassed           | Network + Identity               |
| Security Group misconfigured | Identity + Encryption            |
| Credentials stolen           | Detection + Encryption           |
| Instance compromised         | Network segmentation + Detection |
| Data accessed                | Encryption (can't read it)       |

---

## Key Takeaways

1. **Audit regularly** - Security drift happens. Automate your audits.
2. **Prioritize by risk** - Not all findings are equal. Fix critical issues first.
3. **Layer your defences** - When one control fails, others should catch the attack.
4. **Understand the "why"** - Knowing why something is risky helps you prioritize.

---

## What's Next

You've completed Chapter 1 Labs! You now have:

1. A secured AWS account foundation (Lab 01)
2. Skills to find vulnerabilities (Lab 02)
3. Understanding of CIA controls (Lab 03)
4. A security posture assessment (Lab 04)

Continue to Chapter 2: IAM Deep Dive.
