# Lab 03: Credential Security

## Overview

**Hardcoded credentials are time bombs waiting to explode.**

In this lab, you'll find and fix hardcoded secrets like those that enabled the Uber and LastPass breaches. You'll use secret scanning tools, learn to use AWS Secrets Manager, and set up git pre-commit hooks to prevent future credential leaks.

## Cost

| Resource | Type | Free Tier |
|----------|------|-----------|
| Secrets Manager | 1 secret | 30-day trial |
| Lambda | Testing | 1M requests/month |

**Estimated cost:** $0.00 (free tier eligible)

## Learning Objectives

1. Find hardcoded secrets using scanning tools
2. Understand why hardcoded credentials are dangerous
3. Store secrets securely in AWS Secrets Manager
4. Modify code to fetch secrets at runtime
5. Set up git pre-commit hooks to prevent leaks

---

## Part 1: The Problem with Hardcoded Secrets

### Why This Matters

In the Uber breach:
```powershell
# Found in a PowerShell script on a network share
$PAM_Server = "thycotic.uber.internal"
$PAM_Username = "admin"
$PAM_Password = "SuperSecretPassword123!"  # Hardcoded!
```

In the LastPass breach:
```python
# Found in development environment
AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

These hardcoded credentials gave attackers the "keys to the kingdom."

### Common Places Secrets Hide

| Location | Risk Level | Example |
|----------|------------|---------|
| Source code | Critical | `password = "secret123"` |
| Config files | Critical | `.env` files committed |
| Scripts | High | PowerShell/Bash with creds |
| CI/CD configs | High | `AWS_SECRET_KEY` in YAML |
| Log files | Medium | Credentials in error output |
| Docker images | High | Secrets in build layers |

---

## Part 2: Scan for Secrets

### Step 2.1: Create Sample Vulnerable Code

First, let's create some intentionally vulnerable files to scan:

```bash
cd chapter-02-breach-analysis/lab-03-credential-security

# Create a sample vulnerable file
mkdir -p sample-code
cat > sample-code/vulnerable-config.py << 'EOF'
# INTENTIONALLY VULNERABLE - For training purposes only
# This file demonstrates common credential mistakes

import boto3

# BAD: Hardcoded AWS credentials
AWS_ACCESS_KEY_ID = "AKIAIOSFODNN7EXAMPLE"
AWS_SECRET_ACCESS_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

# BAD: Database credentials in code
DB_HOST = "prod-database.company.internal"
DB_USER = "admin"
DB_PASSWORD = "P@ssw0rd123!"

# BAD: API keys inline
STRIPE_API_KEY = "sk_live_abcdefghijklmnopqrstuvwxyz"
GITHUB_TOKEN = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

def connect_to_aws():
    # This would actually work with real credentials!
    session = boto3.Session(
        aws_access_key_id=AWS_ACCESS_KEY_ID,
        aws_secret_access_key=AWS_SECRET_ACCESS_KEY
    )
    return session.client('s3')

def connect_to_database():
    # Credentials visible in code and potentially in logs
    connection_string = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:5432/prod"
    print(f"Connecting to: {connection_string}")  # BAD: Logging credentials!
    return connection_string
EOF

cat > sample-code/vulnerable-script.sh << 'EOF'
#!/bin/bash
# INTENTIONALLY VULNERABLE - For training purposes only

# BAD: Credentials in shell script
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"

# BAD: Passwords in variables
MYSQL_PASSWORD="SuperSecretPassword123!"
API_SECRET="api-secret-key-do-not-share"

# BAD: Inline credentials in commands
mysql -u root -p"$MYSQL_PASSWORD" -h database.internal

# BAD: Credentials in URLs
curl "https://user:password@api.company.com/data"
EOF

echo "Sample vulnerable files created in sample-code/"
```

### Step 2.2: Run the Secret Scanner

```bash
chmod +x scripts/scan-secrets.sh
./scripts/scan-secrets.sh sample-code/
```

This will identify:
- AWS access keys
- Database passwords
- API tokens
- Other sensitive patterns

### Step 2.3: Review the Findings

The scanner should find several issues:

| File | Line | Secret Type | Severity |
|------|------|-------------|----------|
| vulnerable-config.py | 6 | AWS Access Key | Critical |
| vulnerable-config.py | 7 | AWS Secret Key | Critical |
| vulnerable-config.py | 11 | Database Password | High |
| vulnerable-config.py | 14 | Stripe API Key | Critical |
| vulnerable-script.sh | 5-6 | AWS Credentials | Critical |
| vulnerable-script.sh | 9 | Password | High |

---

## Part 3: Store Secrets Properly

### Step 3.1: Deploy Secrets Manager Infrastructure

```bash
aws cloudformation create-stack \
  --stack-name lab03-credential-security \
  --template-body file://templates/secrets-lab.yaml \
  --capabilities CAPABILITY_NAMED_IAM
```

Wait for completion:
```bash
aws cloudformation describe-stacks --stack-name lab03-credential-security --query 'Stacks[0].StackStatus' --output text
```

### Step 3.2: Create a Secret

```bash
# Create a secret in Secrets Manager
aws secretsmanager create-secret \
  --name lab03/database-credentials \
  --description "Database credentials for lab 03" \
  --secret-string '{"username":"app_user","password":"SecureRandomPassword!","host":"database.internal","port":"5432"}'
```

### Step 3.3: View the Secret

```bash
# Retrieve the secret (this would be done by your application)
aws secretsmanager get-secret-value \
  --secret-id lab03/database-credentials \
  --query SecretString \
  --output text
```

---

## Part 4: Fix the Vulnerable Code

### Step 4.1: The Secure Version

Create a secure version that fetches credentials at runtime:

```bash
cat > sample-code/secure-config.py << 'EOF'
# SECURE VERSION - Credentials fetched from Secrets Manager

import boto3
import json
from botocore.exceptions import ClientError

def get_secret(secret_name):
    """Fetch a secret from AWS Secrets Manager."""
    client = boto3.client('secretsmanager')

    try:
        response = client.get_secret_value(SecretId=secret_name)
        return json.loads(response['SecretString'])
    except ClientError as e:
        print(f"Error fetching secret: {e}")
        raise

def connect_to_database():
    """Connect to database using credentials from Secrets Manager."""
    # SECURE: Fetch credentials at runtime
    creds = get_secret('lab03/database-credentials')

    connection_string = (
        f"postgresql://{creds['username']}:{creds['password']}"
        f"@{creds['host']}:{creds['port']}/prod"
    )

    # SECURE: Don't log the connection string!
    print("Connecting to database...")
    return connection_string

def connect_to_aws():
    """Connect to AWS using IAM role (no credentials needed)."""
    # SECURE: Use IAM roles, not access keys
    # boto3 automatically uses the instance/Lambda role
    return boto3.client('s3')

if __name__ == "__main__":
    # This code uses Secrets Manager for credentials
    # and IAM roles for AWS access
    connect_to_database()
    connect_to_aws()
    print("Connections established securely!")
EOF

echo "Secure version created: sample-code/secure-config.py"
```

### Step 4.2: Compare the Approaches

| Aspect | Hardcoded | Secrets Manager |
|--------|-----------|-----------------|
| Credential location | In code | Encrypted service |
| Rotation | Manual code change | Automatic |
| Access control | Anyone with code access | IAM policies |
| Audit trail | None | CloudTrail |
| If code is leaked | Credentials exposed | Credentials safe |

### Step 4.3: Test the Secure Version

```bash
# The secure version needs IAM permissions to access Secrets Manager
# When running on EC2/Lambda with the right role, it would work automatically

python3 sample-code/secure-config.py 2>/dev/null || echo "Expected: Need to run with Secrets Manager access"
```

---

## Part 5: Set Up Git Pre-Commit Hook

### Step 5.1: Create the Hook

```bash
chmod +x scripts/setup-precommit.sh
./scripts/setup-precommit.sh
```

This creates a git hook that scans for secrets before every commit.

### Step 5.2: Test the Hook

Try to commit the vulnerable file:

```bash
cd sample-code
git init
git add vulnerable-config.py
git commit -m "Adding config"
```

The commit should be **blocked** with a warning about detected secrets.

### Step 5.3: Hook Output Example

```
============================================
  PRE-COMMIT SECRET SCAN
============================================

Scanning staged files for secrets...

[BLOCKED] Potential secrets detected!

  vulnerable-config.py:6    AWS Access Key ID
  vulnerable-config.py:7    AWS Secret Access Key
  vulnerable-config.py:11   Password pattern
  vulnerable-config.py:14   API Key pattern

Commit blocked to prevent secret leakage.

To bypass (NOT RECOMMENDED):
  git commit --no-verify

To fix:
  1. Remove hardcoded credentials
  2. Use AWS Secrets Manager or environment variables
  3. Add sensitive files to .gitignore
```

---

## Part 6: MFA Fatigue and Phishing-Resistant Authentication

The Uber breach also used MFA fatigue. Let's discuss defense.

### The MFA Fatigue Attack

```
Traditional MFA flow:
  1. Attacker has stolen password
  2. Attacker attempts login
  3. User receives MFA push notification
  4. User denies (repeat 50+ times)
  5. Attacker contacts user: "IT here, please accept"
  6. Tired user accepts
  7. Attacker is in
```

### Phishing-Resistant MFA Options

| Method | Fatigue Resistant | Phishing Resistant | AWS Support |
|--------|-------------------|-------------------|-------------|
| Push notifications | No | No | Yes (via IdP) |
| SMS codes | No | No | Yes |
| TOTP codes | Partially | No | Yes |
| Hardware keys (FIDO2) | Yes | Yes | Yes |
| Passkeys | Yes | Yes | Yes |

### AWS IAM Identity Center Configuration

For production environments:
1. Use IAM Identity Center (SSO)
2. Require FIDO2 hardware keys for privileged access
3. Enable number matching for push notifications
4. Set short session durations

---

## Part 7: Cleanup

```bash
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh
```

Or manually:

```bash
# Delete the secret
aws secretsmanager delete-secret \
  --secret-id lab03/database-credentials \
  --force-delete-without-recovery

# Delete the CloudFormation stack
aws cloudformation delete-stack --stack-name lab03-credential-security

# Clean up sample files
rm -rf sample-code/
```

---

## Summary

| Topic | What You Learned |
|-------|------------------|
| Secret scanning | How to find hardcoded credentials |
| Secrets Manager | How to store credentials securely |
| Code remediation | How to fetch secrets at runtime |
| Pre-commit hooks | How to prevent credential commits |
| MFA fatigue | Why push MFA isn't enough |

## Key Takeaways

- **Never hardcode credentials** - Not even in "private" repos
- **Use Secrets Manager** - Centralized, encrypted, auditable
- **Automate scanning** - Pre-commit hooks catch mistakes early
- **Rotate regularly** - Secrets Manager can automate rotation
- **Use phishing-resistant MFA** - Hardware keys for privileged access
- **Assume credentials will leak** - Design systems to limit blast radius

## Credential Security Checklist

- [ ] No secrets in source code
- [ ] No secrets in environment files committed to git
- [ ] All secrets in Secrets Manager or Parameter Store
- [ ] Pre-commit hooks scan for secrets
- [ ] CI/CD pipeline scans for secrets
- [ ] Secrets rotated on a schedule
- [ ] Phishing-resistant MFA for privileged access
- [ ] IAM roles instead of access keys where possible

---

## Next Lab

Continue to [Lab 04: Breach Post-Mortem Report](../lab-04-breach-postmortem/) - where you'll synthesize everything into professional security documentation.
