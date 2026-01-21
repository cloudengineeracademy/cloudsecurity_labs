# LastPass Breach (2022)

## The Headlines

**Password manager compromised. 25 million user vaults stolen.**

In August 2022, attackers compromised a LastPass engineer's personal computer, eventually gaining access to cloud storage containing encrypted customer vault backups. The breach was disclosed in stages, with the full impact revealed months later.

## Timeline

| Date | Event |
|------|-------|
| August 2022 | Initial breach via engineer's personal computer |
| August 25, 2022 | LastPass discloses "unauthorized access" to dev environment |
| November 2022 | Second incident - cloud storage accessed |
| December 22, 2022 | Full disclosure: customer vault backups stolen |
| February 2023 | Additional details about engineer compromise |

**Dwell time:** Months (attacker had persistent access while investigation was ongoing)

## Technical Details

### The Attack Chain

**Step 1: Initial Compromise**

The attacker targeted one of only four DevOps engineers who had access to critical infrastructure. They compromised the engineer's **personal home computer** through:

- Vulnerable third-party media software (Plex)
- Keylogger installation
- Credential theft

```
Personal Computer → Keylogger → Corporate Credentials → VPN Access
```

**Step 2: Development Environment Access**

Using stolen credentials, the attacker accessed LastPass development systems:
- Source code repositories
- Internal documentation
- Development infrastructure

This was the first disclosed breach (August 2022).

**Step 3: The Critical Discovery**

While in the development environment, the attacker found:
- **AWS access keys** (stored without encryption)
- **Decryption keys** for cloud storage
- **Documentation** describing backup locations

These secrets were stored in a way that the development environment could access them.

**Step 4: Cloud Storage Access**

With the discovered credentials, the attacker accessed S3 buckets containing:
- Customer vault backups (encrypted)
- Customer metadata (URLs, usernames - unencrypted)
- Company configuration data

**Step 5: Data Exfiltration**

The attacker downloaded:
- Encrypted vault data for ~25 million users
- Unencrypted vault metadata (site URLs, usernames)
- Internal company data

### What Was Encrypted vs. Unencrypted

| Data Type | Encrypted? | Risk |
|-----------|------------|------|
| Master passwords | Yes (hashed) | Brute-forceable with weak passwords |
| Website passwords | Yes | Requires master password |
| Site URLs | **No** | Reveals what sites you use |
| Usernames | **No** | Reveals your accounts |
| Email addresses | **No** | Enables targeted phishing |
| Billing info | Partially | Some data exposed |

The unencrypted metadata revealed:
- Which financial institutions users have accounts with
- What services they use
- Their usernames on those services

This is a goldmine for targeted phishing.

## What Went Wrong

### 1. Personal Device Compromise
A home computer with access to corporate resources became the entry point.

### 2. Unencrypted Secrets
AWS keys and decryption keys were accessible in the development environment.

### 3. Excessive Access
Only four engineers had this access, but that access was to everything.

### 4. Metadata Not Encrypted
Even though passwords were encrypted, the metadata revealed sensitive information.

### 5. Delayed Detection
The attacker maintained access across multiple months and incidents.

## The 5-Question Analysis

### 1. How did they get in?
**Engineer's personal computer** was compromised via vulnerable third-party software. The attacker installed a keylogger and captured corporate credentials.

### 2. What did they find?
**AWS access keys and decryption keys** stored in the development environment without proper encryption. Also found documentation about backup storage locations.

### 3. How did they move?
**Cloud storage access** - used the discovered credentials to access S3 buckets containing customer data backups.

### 4. What did they take?
**25 million customer vault backups** plus unencrypted metadata (URLs, usernames, email addresses). Vaults are encrypted but can be brute-forced if master passwords are weak.

### 5. When could they have detected it?
Multiple opportunities:
- **Unusual access from new device** (the compromised home computer)
- **Access to development resources outside normal patterns**
- **Large data transfers from S3** during exfiltration
- **First access to certain AWS resources** from development credentials

## The "Four Engineers" Problem

Only four people had access to this critical infrastructure. This seems secure (principle of least privilege, right?), but it created problems:

1. **High-value targets** - Attackers knew exactly who to compromise
2. **Single points of failure** - Compromising any one of four gave full access
3. **Detection difficulty** - Legitimate access was hard to distinguish from malicious

### Better Approaches

| Instead of | Consider |
|------------|----------|
| Four engineers with full access | Just-in-time access that expires |
| Persistent credentials | Break-glass procedures with approval |
| Dev environment sees prod secrets | Separate secret stores with no cross-access |
| Personal computers on network | Managed devices only |

## The Supply Chain Angle

This breach highlights the **software supply chain risk**:

1. Plex software on personal computer had a vulnerability
2. Vulnerability allowed initial compromise
3. Compromise led to corporate access
4. Corporate access led to customer data theft

```
Plex vulnerability → Home computer → Corporate VPN → Dev systems → AWS → Customer vaults
```

Every link in this chain is a potential security boundary that failed.

## Prevention Checklist

- [ ] Managed devices only for privileged access
- [ ] No corporate access from personal machines
- [ ] Secrets encrypted everywhere (including dev)
- [ ] Just-in-time access with automatic expiration
- [ ] Encrypt metadata, not just sensitive fields
- [ ] Aggressive monitoring for privileged users
- [ ] Zero trust: verify every access
- [ ] Regular access reviews

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

## Implications for Users

If you're a LastPass user:

1. **Assume your vault was stolen** - It likely was
2. **Change your master password** - Make it long (16+ characters) and unique
3. **Enable MFA everywhere** - Every site in your vault
4. **Consider credential rotation** - Especially for financial accounts
5. **Watch for phishing** - Attackers know what sites you use

## Lessons for Cloud Security

1. **Encrypt secrets everywhere** - Not just in production, but dev, backups, everywhere
2. **Personal devices are attack vectors** - Treat them as untrusted
3. **Metadata is sensitive** - Knowing what sites you use reveals a lot
4. **Supply chain matters** - Every software on privileged systems is a risk
5. **Detect anomalies on privileged accounts** - The four engineers should have had intense monitoring

## Further Reading

- [LastPass Security Incident Updates](https://blog.lastpass.com/2022/12/notice-of-recent-security-incident/)
- [Analysis of the LastPass Breach](https://www.wired.com/story/lastpass-breach-vaults-password-managers/)
