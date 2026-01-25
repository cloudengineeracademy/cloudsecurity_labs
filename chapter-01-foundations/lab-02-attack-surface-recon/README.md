# Lab 02: Attack Surface Reconnaissance

## Overview

**Think like an attacker. Then fix what you find.**

In this lab, you'll deploy intentionally vulnerable infrastructure, scan it to discover security issues, and then fix each vulnerability one by one. This is exactly how security assessments work in the real world.

## What You'll Deploy

| Resource | Vulnerability | Risk |
|----------|--------------|------|
| Security Group | SSH (22) open to 0.0.0.0/0 | Critical |
| S3 Bucket | No public access block | High |
| EC2 Instance | Public IP + IMDSv1 enabled | High |
| IAM User | No MFA, has access keys | High |

## Cost

- **EC2**: t3.micro (free tier eligible)
- **S3**: Minimal (empty bucket)
- **IAM**: Free

**Important**: Delete the stack when done to avoid charges.

## Learning Objectives

1. Deploy vulnerable infrastructure with CloudFormation
2. Run a security scan to identify issues
3. Fix each vulnerability and verify it's resolved
4. Understand why each misconfiguration is dangerous

---

## Part 1: Deploy Vulnerable Infrastructure

### Step 1.1: Deploy the Stack

```bash
aws cloudformation create-stack \
  --stack-name lab02-vulnerable-infra \
  --template-body file://templates/vulnerable-infra.yaml \
  --capabilities CAPABILITY_NAMED_IAM
```

### Step 1.2: Wait for Deployment

```bash
# Check status (wait for CREATE_COMPLETE)
aws cloudformation describe-stacks --stack-name lab02-vulnerable-infra --query 'Stacks[0].StackStatus' --output text
```

This takes 2-3 minutes.

### Step 1.3: View What Was Created

```bash
aws cloudformation describe-stacks --stack-name lab02-vulnerable-infra --query 'Stacks[0].Outputs' --output table
```

---

## Part 2: Scan for Vulnerabilities

Run the vulnerability scanner to see what's exposed.

### Step 2.1: Run the Scanner

```bash
chmod +x scripts/scan-vulnerabilities.sh
./scripts/scan-vulnerabilities.sh
```

You should see output like:

```
[1/4] IDENTITY
IAM User MFA: [HIGH] NO MFA ENABLED
IAM Access Keys: [HIGH] ACCESS KEY EXISTS

[2/4] NETWORK
Security Group SSH: [CRITICAL] SSH OPEN TO INTERNET

[3/4] DATA
S3 Public Access Block: [HIGH] NO PUBLIC ACCESS BLOCK
S3 Encryption: [PASS] Encryption enabled (AWS default since Jan 2023)

[4/4] COMPUTE
EC2 IMDS Version: [HIGH] IMDSv1 ENABLED (SSRF VULNERABLE)
```

**This is your attack surface.** Now let's fix each issue.

---

## Part 3: Fix Each Vulnerability

For each issue: **Find it → Understand the risk → Fix it → Verify it's gone**

---

### Issue 1: SSH Open to Internet (CRITICAL)

#### Find It

```bash
aws ec2 describe-security-groups --group-names lab02-insecure-sg \
  --query 'SecurityGroups[0].IpPermissions[].{Port:FromPort,Source:IpRanges[0].CidrIp}' \
  --output table
```

You'll see port 22 with source `0.0.0.0/0` - anyone on the internet can try to SSH in.

#### Why It's Dangerous

- Attackers constantly scan for open SSH ports
- Brute force attacks can compromise weak passwords
- SSH vulnerabilities can give direct shell access

#### Fix It

```bash
SG_ID=$(aws ec2 describe-security-groups --group-names lab02-insecure-sg --query 'SecurityGroups[0].GroupId' --output text)

aws ec2 revoke-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
```

#### Verify It's Gone

```bash
aws ec2 describe-security-groups --group-names lab02-insecure-sg \
  --query 'SecurityGroups[0].IpPermissions[].{Port:FromPort,Source:IpRanges[0].CidrIp}' \
  --output table
```

Port 22 with `0.0.0.0/0` should no longer appear.

---

### Issue 2: S3 Bucket Not Protected (HIGH)

#### Find It

```bash
BUCKET=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `lab02`)].Name' --output text)
aws s3api get-public-access-block --bucket $BUCKET 2>&1
```

You'll see `NoSuchPublicAccessBlockConfiguration` - no protection against public exposure.

#### Why It's Dangerous

- A misconfigured bucket policy could expose all data to the internet
- This is how major breaches happen (Twitch, Capital One, etc.)

#### Fix It

```bash
BUCKET=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `lab02`)].Name' --output text)

aws s3api put-public-access-block --bucket $BUCKET --public-access-block-configuration '{
  "BlockPublicAcls": true,
  "IgnorePublicAcls": true,
  "BlockPublicPolicy": true,
  "RestrictPublicBuckets": true
}'
```

#### Verify It's Gone

```bash
aws s3api get-public-access-block --bucket $BUCKET
```

Should show all four settings as `true`.

---

### Issue 3: S3 Bucket Using Default Encryption (INFO)

> **Note:** Since January 2023, AWS automatically encrypts all new S3 buckets with SSE-S3 (AES256). This is a good default, but you should verify it's in place and understand when to use stronger encryption (KMS).

#### Find It

```bash
BUCKET=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `lab02`)].Name' --output text)
aws s3api get-bucket-encryption --bucket $BUCKET
```

You'll see `SSEAlgorithm: AES256` - AWS applied default encryption automatically.

#### Why This Matters

- **SSE-S3 (AES256)**: AWS manages keys, good baseline protection
- **SSE-KMS**: You control keys, better for compliance (HIPAA, PCI-DSS)
- **SSE-KMS with CMK**: Full control, audit trail via CloudTrail

For sensitive data, organizations often require KMS encryption with customer-managed keys for audit and access control.

#### Upgrade to KMS (Optional Exercise)

```bash
BUCKET=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `lab02`)].Name' --output text)

aws s3api put-bucket-encryption --bucket $BUCKET --server-side-encryption-configuration '{
  "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "aws:kms"}}]
}'
```

#### Verify

```bash
aws s3api get-bucket-encryption --bucket $BUCKET
```

Should show `aws:kms` if you upgraded, or `AES256` if using the AWS default.

---

### Issue 4: EC2 IMDSv1 Enabled (HIGH)

#### Find It

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Lab,Values=cloud-security-lab-02" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,IMDSv2:MetadataOptions.HttpTokens}' \
  --output table
```

You'll see `HttpTokens: optional` - IMDSv1 is enabled.

#### Why It's Dangerous

- SSRF vulnerabilities can reach the metadata service
- IMDSv1 returns credentials without authentication
- **This is exactly how the Capital One breach happened** - 100+ million records stolen

#### Fix It

```bash
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Lab,Values=cloud-security-lab-02" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)

aws ec2 modify-instance-metadata-options \
  --instance-id $INSTANCE_ID \
  --http-tokens required \
  --http-endpoint enabled
```

#### Verify It's Gone

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Lab,Values=cloud-security-lab-02" \
  --query 'Reservations[].Instances[].{InstanceId:InstanceId,IMDSv2:MetadataOptions.HttpTokens}' \
  --output table
```

Should show `HttpTokens: required`.

---

### Issue 5: IAM User Has Access Key (HIGH)

#### Find It

```bash
aws iam list-access-keys --user-name lab02-insecure-user --output table
```

You'll see an active access key.

#### Why It's Dangerous

- Access keys are long-lived credentials
- They leak via: git commits, logs, screenshots, compromised laptops
- No MFA protection means leaked key = immediate access

#### Fix It

```bash
KEY_ID=$(aws iam list-access-keys --user-name lab02-insecure-user --query 'AccessKeyMetadata[0].AccessKeyId' --output text)

aws iam delete-access-key --user-name lab02-insecure-user --access-key-id $KEY_ID
```

#### Verify It's Gone

```bash
aws iam list-access-keys --user-name lab02-insecure-user
```

Should return empty (no access keys).

---

## Part 4: Final Scan - Verify All Fixed

Run the scanner again to confirm everything is resolved:

```bash
./scripts/scan-vulnerabilities.sh
```

**Expected output:**

```
[1/4] IDENTITY
IAM User MFA: [HIGH] NO MFA ENABLED     ← Can't fix via CLI
IAM Access Keys: [PASS] No access keys

[2/4] NETWORK
Security Group SSH: [PASS] SSH not exposed to internet

[3/4] DATA
S3 Public Access Block: [PASS] Public access blocked
S3 Encryption: [PASS] Encryption enabled

[4/4] COMPUTE
EC2 IMDS Version: [PASS] IMDSv2 required
```

You reduced the attack surface from **5 vulnerabilities** to **1** (MFA requires console access).

---

## Part 5: Cleanup

Delete everything to avoid charges:

```bash
aws cloudformation delete-stack --stack-name lab02-vulnerable-infra
```

Verify deletion:

```bash
aws cloudformation describe-stacks --stack-name lab02-vulnerable-infra 2>&1
```

Should return "Stack does not exist" when complete.

> **If deletion fails** (bucket not empty):
> ```bash
> BUCKET=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `lab02`)].Name' --output text)
> aws s3 rm s3://$BUCKET --recursive
> aws cloudformation delete-stack --stack-name lab02-vulnerable-infra
> ```

---

## Summary

| Issue | Risk | What You Did |
|-------|------|--------------|
| SSH open to 0.0.0.0/0 | Critical | Removed the ingress rule |
| S3 no public access block | High | Enabled all 4 block settings |
| S3 encryption | Info | Verified AWS default encryption (optionally upgraded to KMS) |
| EC2 IMDSv1 enabled | High | Required IMDSv2 tokens |
| IAM user has access key | High | Deleted the access key |

---

## What You Learned

1. **Scanning** - How to identify vulnerabilities in cloud infrastructure
2. **Risk Assessment** - Why each misconfiguration is dangerous
3. **Remediation** - How to fix common security issues
4. **Verification** - Always confirm fixes actually worked
5. **Iterative Security** - Find → Fix → Verify, one issue at a time

---

## Key Takeaways

- **Scan before and after** - Know your starting point, confirm your fixes
- **One fix at a time** - Verify each change worked before moving on
- **Understand the "why"** - Knowing the risk helps you prioritize
- **Attackers use the same tools** - These AWS CLI commands are reconnaissance 101

---

## Next Lab

Continue to [Lab 03: CIA Triad with S3](../lab-03-cia-triad-s3/)
