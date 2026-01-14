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

- **EC2**: t3.micro (free tier eligible)
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

## How Cloud Security Engineers Think

Before diving in, understand the mindset:

**1. Assume Breach** - Don't ask "will we be attacked?" Ask "when we're attacked, what will they get?"

**2. Think in Layers** - No single control is perfect. If the firewall fails, does encryption save you? If credentials leak, does MFA stop them?

**3. Blast Radius** - When something goes wrong, how bad is it? A compromised instance with no IAM role is bad. A compromised instance with admin permissions is catastrophic.

**4. Evidence Over Assumptions** - Don't assume things are configured correctly. Query the actual state. Trust but verify.

---

## Part 1: Deploy Audit Infrastructure

### Step 1.1: Deploy the Stack

We're using CloudFormation to deploy a set of intentionally vulnerable resources. CloudFormation is AWS's Infrastructure as Code (IaC) service - it reads a YAML template and creates all the resources defined in it.

```bash
aws cloudformation create-stack \
  --stack-name lab04-audit-infra \
  --template-body file://templates/audit-infra.yaml \
  --capabilities CAPABILITY_NAMED_IAM
```

**What this does:**

- `create-stack` - Tells CloudFormation to create new resources
- `--stack-name lab04-audit-infra` - Names this deployment so we can reference it later
- `--template-body file://` - Points to our local YAML file that defines what to create
- `--capabilities CAPABILITY_NAMED_IAM` - Required because we're creating IAM resources. AWS makes you explicitly acknowledge this for security.

**Expected output:**

```
{
    "StackId": "arn:aws:cloudformation:us-east-1:123456789:stack/lab04-audit-infra/abc123"
}
```

**Security engineer mindset:** Before running any IaC, we'd normally review the template to understand what's being created. In production, this would go through a pull request with security review.

### Step 1.2: Wait for Deployment

CloudFormation creates resources in the background. This command checks the current status.

```bash
aws cloudformation describe-stacks \
  --stack-name lab04-audit-infra \
  --query 'Stacks[0].StackStatus' \
  --output text
```

**What this does:**

- `describe-stacks` - Gets information about a CloudFormation stack
- `--query 'Stacks[0].StackStatus'` - JMESPath query that extracts just the status field
- `--output text` - Returns plain text instead of JSON

**Expected output (run multiple times):**

```
CREATE_IN_PROGRESS    <- Resources still being created
CREATE_COMPLETE       <- Done! Move to next step
```

If you see `ROLLBACK_IN_PROGRESS` or `CREATE_FAILED`, something went wrong. Check the AWS Console under CloudFormation > Events to see which resource failed.

### Step 1.3: View What Was Created

```bash
aws cloudformation describe-stacks \
  --stack-name lab04-audit-infra \
  --query 'Stacks[0].Outputs' \
  --output table
```

**Expected output:**

```
-------------------------------------------------------------
|                      DescribeStacks                        |
+-------------+---------------------------------------------+
|  OutputKey  |                OutputValue                   |
+-------------+---------------------------------------------+
|  VPCId      |  vpc-0abc123def456                          |
|  InstanceId |  i-0abc123def456                            |
|  BucketName |  lab04-unencrypted-123456789012             |
|  IAMUser    |  lab04-audit-user                           |
+-------------+---------------------------------------------+
```

**You've deployed:**

- VPC with only public subnets (no private)
- Security group with SSH open to 0.0.0.0/0
- EC2 instance with IMDSv1 and public IP
- S3 bucket without encryption
- IAM user with access key (no MFA)

**Action:** Open the AWS Console and click through each service (VPC, EC2, S3, IAM) to see these resources. Understanding what you deployed is more important than running commands.

---

## Part 2: Run the Security Audit

### Step 2.1: Run the Audit Script

This bash script automates the security checks. In real environments, you'd use tools like Prowler, ScoutSuite, or AWS Security Hub - but understanding what they do under the hood makes you better at using them.

```bash
chmod +x scripts/defence-audit.sh
./scripts/defence-audit.sh
```

**What this does:**

- `chmod +x` - Makes the script executable (required on Unix/Mac)
- `./scripts/defence-audit.sh` - Runs the script

**Take action:** Before running, open `scripts/defence-audit.sh` in your editor and read through it. Every check is an AWS CLI command you could run yourself. The script just automates them.

**Expected output:**

```
==============================================
  Defence in Depth Audit
==============================================

Account: 123456789012
Date: Tue Jan 14 12:00:00 UTC 2025

==============================================
LAYER 2: NETWORK
==============================================
  [+0] No open Security Groups: 1 SGs have 0.0.0.0/0 ingress
  [+0] Private subnets exist: Only public subnets found

==============================================
LAYER 3: IDENTITY
==============================================
  [+0] All users have MFA: 0/1 users have MFA
  ...
```

**Security engineer mindset:** We run automated scans to catch obvious issues quickly, but we don't blindly trust them. False positives happen. False negatives happen. The scan is a starting point, not the final answer.

### Step 2.2: Review Your Findings

You should see findings like:

| Layer    | Finding                         | Why It's Bad                   |
| -------- | ------------------------------- | ------------------------------ |
| Network  | Security groups allow 0.0.0.0/0 | Anyone can try to connect      |
| Network  | Only public subnets             | Everything is internet-exposed |
| Identity | User without MFA                | Password = full access         |
| Compute  | IMDSv1 enabled                  | SSRF = credential theft        |
| Compute  | EC2 has public IP               | Direct attack target           |
| Data     | S3 bucket not encrypted         | Data readable if stolen        |

---

## Part 3: Understand the Findings

Now we manually investigate each finding. This teaches you the AWS CLI commands security tools use - and more importantly, how to interpret the results.

### Network Layer Findings

#### Open Security Groups

Security groups are virtual firewalls that control traffic to your resources.

```bash
aws ec2 describe-security-groups \
  --filters Name=group-name,Values=lab04-open-sg \
  --query 'SecurityGroups[0].IpPermissions[].{Port:FromPort,Source:IpRanges[0].CidrIp}' \
  --output table
```

**What this does:**

- `describe-security-groups` - Lists firewall rules
- `--filters` - Only shows our specific security group
- `IpPermissions` - Inbound rules (what can connect TO this resource)

**Expected output:**

```
-------------------
|  Port  | Source      |
+--------+-------------+
|  22    | 0.0.0.0/0   |
|  80    | 0.0.0.0/0   |
-------------------
```

**What to look for:**

- `0.0.0.0/0` means "any IP on the internet"
- Port 22 is SSH - remote shell access
- Port 3389 is RDP - Windows remote desktop

**The security question:** Does this resource NEED to be accessible from the entire internet? Usually the answer is no. SSH should be restricted to your IP or accessed via a bastion host.

**Real-world impact:** Attackers constantly scan the internet for open ports. An SSH server exposed to 0.0.0.0/0 will see brute-force login attempts within minutes of being deployed.

---

#### No Private Subnets

```bash
aws ec2 describe-subnets \
  --filters "Name=tag:Lab,Values=cloud-security-lab-04" \
  --query 'Subnets[].{Name:Tags[?Key==`Name`].Value|[0],Public:MapPublicIpOnLaunch}' \
  --output table
```

**What this does:**

- `describe-subnets` - Lists network segments in your VPC
- `MapPublicIpOnLaunch` - If true, instances here automatically get public IPs

**Expected output:**

```
--------------------------------
|  Name                | Public |
+-----------------------+--------+
|  lab04-public-subnet  | True   |
--------------------------------
```

**What to look for:**

- `Public: True` = public subnet (internet-accessible)
- `Public: False` = private subnet (no direct internet access)

**The security question:** Does this workload need to be directly accessible from the internet? Databases, internal APIs, and backend services should be in private subnets.

**Real-world impact:** Putting a database in a public subnet means any vulnerability in that database is directly exploitable from the internet. In a private subnet, attackers would need to first compromise something with internet access.

---

### Identity Layer Findings

#### IAM User Without MFA

```bash
aws iam list-mfa-devices --user-name lab04-audit-user
```

**What this does:**

- `list-mfa-devices` - Shows MFA devices (authenticator apps, hardware tokens) linked to a user

**Expected output:**

```json
{
  "MFADevices": []
}
```

**What to look for:**

- Empty array `[]` = NO MFA configured
- If MFA exists, you'd see a `SerialNumber` for each device

**The security question:** If this user's password is phished, stolen from a breach, or guessed - what stops an attacker from logging in?

**Real-world impact:** Password-only accounts are the #1 way attackers get into cloud environments. MFA stops over 99% of credential-based attacks. No exceptions - every human user needs MFA.

---

#### User Has Access Key

```bash
aws iam list-access-keys --user-name lab04-audit-user --output table
```

**What this does:**

- `list-access-keys` - Shows programmatic credentials for a user
- Access keys = Access Key ID + Secret Access Key (like username + password for the API)

**Expected output:**

```
-----------------------------------------------------------------
|                        ListAccessKeys                          |
+---------------+-----------------------+------------------------+
| AccessKeyId   | CreateDate            | Status                 |
+---------------+-----------------------+------------------------+
| AKIA...       | 2025-01-14T12:00:00Z  | Active                 |
+---------------+-----------------------+------------------------+
```

**What to look for:**

- `Status: Active` = key is usable
- `CreateDate` = how old is this key? (older = more time to have been leaked)

**The security question:** Where is this key stored? Who has access to it? Has it ever been in a git repo, log file, or screenshot?

**Real-world impact:** Access keys don't expire by default and can be used from anywhere. They leak constantly - in code commits, CI/CD logs, error messages, screenshots shared in Slack. Once leaked, attackers can use them within minutes.

---

### Compute Layer Findings

#### IMDSv1 Enabled

This is one of the most important checks. IMDS (Instance Metadata Service) is how EC2 instances get information about themselves - including IAM credentials.

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Lab,Values=cloud-security-lab-04" \
  --query 'Reservations[].Instances[].{Id:InstanceId,IMDSv2:MetadataOptions.HttpTokens}' \
  --output table
```

**What this does:**

- `MetadataOptions.HttpTokens` shows which IMDS version is allowed

**Expected output:**

```
-------------------------------
|  Id                | IMDSv2   |
+--------------------+----------+
|  i-0abc123...      | optional |
-------------------------------
```

**What to look for:**

- `optional` = IMDSv1 is allowed = **VULNERABLE**
- `required` = Only IMDSv2 allowed = Secure

**The security question:** If an attacker finds an SSRF vulnerability in an application on this instance, can they steal IAM credentials?

**Real-world impact:** This exact issue caused the 2019 Capital One breach. An SSRF vulnerability in a WAF allowed attackers to query the metadata service and steal IAM credentials, leading to 100+ million customer records being stolen. The fix took AWS minutes - require IMDSv2.

**How IMDSv1 attack works:**

1. Attacker finds SSRF vulnerability (e.g., image URL fetch feature)
2. Attacker submits URL: `http://169.254.169.254/latest/meta-data/iam/security-credentials/role-name`
3. Server fetches URL and returns IAM credentials to attacker
4. Attacker uses credentials from anywhere

IMDSv2 requires a token obtained via PUT request, which SSRF attacks typically can't do.

---

#### Public IP Assigned

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Lab,Values=cloud-security-lab-04" \
  --query 'Reservations[].Instances[].{Id:InstanceId,PublicIP:PublicIpAddress}' \
  --output table
```

**Expected output:**

```
-------------------------------
|  Id                | PublicIP      |
+--------------------+---------------+
|  i-0abc123...      | 54.123.45.67  |
-------------------------------
```

**What to look for:**

- An IP address = instance is directly accessible from internet
- `None` = no public IP (good for internal workloads)

**The security question:** Does this instance need to be directly reachable from the internet? Or could it sit behind a load balancer / bastion host?

---

### Data Layer Findings

#### S3 Bucket Not Encrypted

```bash
BUCKET=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `lab04`)].Name' --output text)
echo "Checking bucket: $BUCKET"
aws s3api get-bucket-encryption --bucket $BUCKET
```

**What this does:**

- Line 1: Finds our bucket name and stores it in a variable
- Line 3: Checks if default encryption is configured

**Expected output (when NOT encrypted):**

```
Checking bucket: lab04-unencrypted-123456789012

An error occurred (ServerSideEncryptionConfigurationNotFoundError) when calling the GetBucketEncryption operation: The server side encryption configuration was not found
```

**What to look for:**

- Error message = NO encryption configured
- JSON response with `SSEAlgorithm` = encryption IS configured

**The security question:** If someone gains access to this bucket (misconfigured policy, leaked credentials, insider threat) - can they read the data?

**Real-world impact:** Encryption at rest protects against physical theft of storage media and some classes of insider threats. It's free, has no performance impact, and should be enabled everywhere.

---

#### Public Access Block Not Configured

```bash
aws s3api get-public-access-block --bucket $BUCKET
```

**Expected output (when NOT blocked):**

```json
{
  "PublicAccessBlockConfiguration": {
    "BlockPublicAcls": false,
    "IgnorePublicAcls": false,
    "BlockPublicPolicy": false,
    "RestrictPublicBuckets": false
  }
}
```

**What to look for:**

- All `false` = bucket CAN be made public
- All `true` = bucket is protected from accidental public exposure

**The security question:** If someone accidentally adds a public bucket policy, what stops them?

**Real-world impact:** S3 bucket misconfigurations have caused countless breaches. Public access block is a safety net that prevents accidental exposure even if someone misconfigures a bucket policy.

---

## Part 4: Prioritize Remediation

Security engineers don't fix everything at once. We prioritize by risk.

### Critical (Fix Today)

These can be exploited RIGHT NOW by anyone on the internet:

- SSH open to 0.0.0.0/0 - Attackers are scanning for this constantly
- Users without MFA - One phished password = full account access
- Root access keys - Game over if compromised

### High (Fix This Week)

These significantly increase blast radius if something else goes wrong:

- IMDSv1 enabled - Turns any SSRF into credential theft
- Unencrypted S3 buckets - Data readable if access is gained
- Long-lived access keys - Every day they exist is another day they could leak

### Medium (Plan For)

These improve overall security posture:

- Add private subnets - Reduce internet exposure
- Enable GuardDuty - Detect suspicious activity
- Implement WAF - Filter malicious requests

---

## Part 5: Cleanup

Delete all resources to avoid charges.

First, empty the S3 bucket (CloudFormation can't delete buckets with objects):

```bash
BUCKET=$(aws s3api list-buckets --query 'Buckets[?contains(Name, `lab04`)].Name' --output text)
aws s3 rm s3://$BUCKET --recursive 2>/dev/null
```

Now delete the CloudFormation stack:

```bash
aws cloudformation delete-stack --stack-name lab04-audit-infra
```

Verify it's gone:

```bash
aws cloudformation describe-stacks --stack-name lab04-audit-infra 2>&1
```

**Expected output when deleted:**

```
An error occurred (ValidationError) when calling the DescribeStacks operation: Stack with id lab04-audit-infra does not exist
```

If you still see the stack, wait a minute and try again - deletion takes time.

---

## Summary

Defence in Depth means **layered security**. When one control fails, others catch the attack:

| If This Fails...             | These Should Catch It            |
| ---------------------------- | -------------------------------- |
| Perimeter bypassed           | Network + Identity               |
| Security Group misconfigured | Identity + Encryption            |
| Credentials stolen           | MFA + Detection                  |
| Instance compromised         | Network segmentation + Detection |
| Data accessed                | Encryption (can't read it)       |

---

## Key Takeaways

1. **Query, don't assume** - Check the actual configuration. "I think it's configured" isn't good enough.
2. **Understand blast radius** - What's the worst case if this is exploited?
3. **Prioritize by risk** - Not all findings are equal. Fix critical issues first.
4. **Layer your defences** - When one control fails, others should catch the attack.
5. **Read the commands** - Don't copy-paste blindly. Understand what you're running.

---

## What's Next

You've completed Chapter 1 Labs! You now have:

1. A secured AWS account foundation (Lab 01)
2. Skills to find vulnerabilities (Lab 02)
3. Understanding of CIA controls (Lab 03)
4. A security posture assessment (Lab 04)
