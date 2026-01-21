# Uber Breach (2022)

## The Headlines

**Internal systems fully compromised. Attacker posts screenshots to Slack.**

In September 2022, an 18-year-old hacker gained access to Uber's internal systems, including Slack, AWS, Google Workspace, and their vulnerability reports in HackerOne. The attacker used social engineering and hardcoded credentials to achieve near-total compromise.

## Timeline

| Date | Event |
|------|-------|
| September 15, 2022 | Attacker purchases stolen credentials |
| September 15, 2022 | MFA fatigue attack on employee |
| September 15, 2022 | Attacker accesses VPN |
| September 15, 2022 | Discovers hardcoded PAM credentials |
| September 15, 2022 | Posts screenshots to Slack |
| September 16, 2022 | Uber confirms breach |

**Dwell time:** Hours (attacker announced themselves)

## Technical Details

### The Attack Chain

**Step 1: Credential Purchase**

The attacker bought employee credentials from a dark web marketplace. These credentials were likely stolen via:
- Previous data breaches (password reuse)
- Infostealer malware
- Phishing campaigns

**Step 2: MFA Fatigue Attack**

The employee had MFA enabled, but the attacker used a simple but effective technique:

```
Attacker: Attempts login
System: Sends MFA push to employee's phone
Employee: Denies

Attacker: Attempts login again
System: Sends another MFA push
Employee: Denies

[Repeat for over an hour]

Attacker: Contacts employee on WhatsApp
Attacker: "Hi, I'm from Uber IT. We're having issues with your account.
          Please accept the next MFA prompt to fix it."

Employee: Accepts
Attacker: In
```

This is called **MFA fatigue** or **MFA bombing**.

**Step 3: Internal Reconnaissance**

Once on the VPN, the attacker scanned internal resources and found a network share containing PowerShell scripts.

**Step 4: The Critical Find**

Inside a PowerShell script, the attacker found **hardcoded credentials** for Thycotic (a Privileged Access Management system):

```powershell
# Simplified example of what was found
$PAM_Server = "thycotic.uber.internal"
$PAM_Username = "admin"
$PAM_Password = "SuperSecretPassword123!"  # Hardcoded!
```

**Step 5: Total Compromise**

The PAM system contained credentials for everything:
- AWS accounts
- Google Workspace admin
- Slack admin
- VMware vSphere
- HackerOne vulnerability reports

The attacker now had the "keys to the kingdom."

**Step 6: Announcement**

Instead of quietly exfiltrating data, the attacker posted in Uber's Slack:

> "I announce I am a hacker and Uber has suffered a data breach."

They shared screenshots of internal dashboards, source code, and vulnerability reports.

## What Went Wrong

### 1. Password Reuse
Employee credentials were available on dark web from previous breaches.

### 2. MFA Vulnerable to Fatigue
Push-based MFA can be bypassed through persistence and social engineering.

### 3. Hardcoded Credentials
PAM credentials were stored in plaintext in scripts on a network share.

### 4. Over-Privileged PAM Access
One set of credentials provided access to all critical systems.

### 5. No Anomaly Detection
Unusual access patterns weren't detected until the attacker announced themselves.

## The 5-Question Analysis

### 1. How did they get in?
**Purchased credentials + MFA fatigue**. The attacker bought stolen credentials and then socially engineered an employee into accepting an MFA push notification.

### 2. What did they find?
**Hardcoded PAM credentials** in a PowerShell script on an internal network share. This script contained admin credentials for the Privileged Access Management system.

### 3. How did they move?
**PAM system access** - The stolen PAM credentials provided access to stored credentials for AWS, Google Workspace, Slack, and other critical systems.

### 4. What did they take?
**Internal system access** - Source code, Slack messages, vulnerability reports, financial dashboards. The full extent is still not fully disclosed.

### 5. When could they have detected it?
Multiple opportunities:
- **Multiple failed MFA attempts** followed by acceptance
- **Off-hours VPN connection** from unusual location
- **Unusual access to PAM system** (first-time access pattern)
- **Access to sensitive systems** that this employee wouldn't normally touch

## The MFA Fatigue Problem

### How It Works

```
Traditional MFA: "Something you know + something you have"
Reality: "Something you know + something you'll click when annoyed enough"
```

Push-based MFA relies on users making good decisions. After 50+ notifications, many will accept just to make it stop.

### Better Alternatives

| MFA Type | Fatigue Resistant? | Why |
|----------|-------------------|-----|
| Push notifications | No | Users approve to stop spam |
| SMS codes | No | Can be SIM swapped |
| TOTP (6-digit codes) | Partially | Must manually enter, but can be phished |
| Hardware keys (FIDO2) | Yes | Requires physical presence, cryptographic binding |
| Passkeys | Yes | Device-bound, phishing-resistant |

## Prevention Checklist

- [ ] Never store credentials in code or scripts
- [ ] Use secrets management (AWS Secrets Manager, HashiCorp Vault)
- [ ] Implement phishing-resistant MFA (FIDO2/WebAuthn)
- [ ] Monitor for MFA fatigue patterns
- [ ] Alert on unusual access patterns
- [ ] Implement zero-trust architecture
- [ ] Regular credential rotation
- [ ] Git pre-commit hooks for secret scanning

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

## Lessons for Cloud Security

1. **Credentials in code are a time bomb** - Uber stored PAM credentials in scripts. This is equivalent to leaving a master key under the doormat.

2. **MFA is not a silver bullet** - Push-based MFA can be defeated through persistence. Use phishing-resistant methods.

3. **Monitor for the anomalies** - First-time access to PAM, unusual hours, multiple MFA failures - all detectable signals.

4. **Assume breach** - If the attacker hadn't announced themselves, how long until detection?

## Further Reading

- [Uber Security Update](https://www.uber.com/newsroom/security-update/)
- [Lapsus$ Group Analysis](https://www.microsoft.com/security/blog/2022/03/22/dev-0537-criminal-actor-targeting-organizations-for-data-exfiltration-and-destruction/)
