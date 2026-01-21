# Technical Timeline Template

Use this template for detailed technical documentation of incident events.

---

## Incident Technical Timeline

**Incident ID:** [INC-YYYY-NNNN]
**Timeline Author:** [Name]
**Last Updated:** [Date/Time]
**Timezone:** All times in UTC unless noted

---

## Pre-Incident Context

**Environment State:**
- [Relevant configuration details]
- [Security controls in place]
- [Known vulnerabilities or technical debt]

**Relevant Recent Changes:**
- [Any changes in the weeks before the incident]

---

## Timeline of Events

### Day 1: [Date] - Initial Compromise

#### [HH:MM:SS] - First Malicious Activity

**Event:** [Description of what happened]

**Source:** [Log source - e.g., "CloudTrail", "Web server access logs"]

**Evidence:**
```json
{
  "eventTime": "YYYY-MM-DDTHH:MM:SSZ",
  "eventSource": "service.amazonaws.com",
  "eventName": "APICall",
  "sourceIPAddress": "x.x.x.x",
  "userAgent": "...",
  "requestParameters": {
    ...
  }
}
```

**Analysis:** [What this event indicates]

---

#### [HH:MM:SS] - [Event Title]

**Event:** [Description]

**Source:** [Log source]

**Evidence:**
```
[Log entry or command output]
```

**Analysis:** [Interpretation]

---

### Day 1: [Date] - Reconnaissance Phase

#### [HH:MM:SS] - [Event Title]

**Event:** [Description]

**Source:** [Log source]

**Evidence:**
```
[Log entry]
```

**Analysis:** [Interpretation]

**Related Events:**
- [Link to related event]
- [Link to related event]

---

### Day 1: [Date] - Credential Access

#### [HH:MM:SS] - [Event Title]

**Event:** [Description]

**Source:** [Log source]

**Evidence:**
```
[Log entry showing credential access]
```

**Credentials Obtained:**
| Credential Type | Scope | Valid Until |
|-----------------|-------|-------------|
| [Type] | [What it accesses] | [Expiration] |

**Analysis:** [How credentials were obtained and used]

---

### Day 1: [Date] - Data Access

#### [HH:MM:SS] - [Event Title]

**Event:** [Description]

**Source:** [Log source]

**Evidence:**
```
[Log entry showing data access]
```

**Data Accessed:**
| Resource | Action | Size/Count |
|----------|--------|------------|
| [Resource] | [Read/Write/Delete] | [Amount] |

**Analysis:** [Interpretation]

---

### Day N: [Date] - Detection

#### [HH:MM:SS] - Alert Triggered

**Event:** [What triggered detection]

**Source:** [Monitoring system]

**Alert Details:**
```
[Alert content]
```

**Initial Triage:**
- [ ] Alert acknowledged
- [ ] Initial assessment
- [ ] Escalation decision

---

#### [HH:MM:SS] - Incident Declared

**Event:** Incident formally declared

**Severity:** [Critical/High/Medium/Low]

**Initial Responders:**
- [Name/Role]
- [Name/Role]

---

### Day N: [Date] - Containment

#### [HH:MM:SS] - [Containment Action]

**Action:** [What was done]

**Executed By:** [Name/System]

**Command/Change:**
```bash
[Command executed or change made]
```

**Verification:**
```
[Output showing action was successful]
```

---

## Attack Flow Diagram

```
[ASCII diagram of the attack path]

                    ┌─────────────┐
                    │  Internet   │
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │  Web App    │ ← SSRF Vulnerability
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │  Metadata   │ ← IMDSv1 (no token required)
                    │  Service    │
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │  IAM Creds  │ ← Over-permissioned role
                    └──────┬──────┘
                           │
                           ▼
                    ┌─────────────┐
                    │  S3 Bucket  │ ← Sensitive data
                    └─────────────┘
```

---

## Evidence Index

| ID | Type | Location | Hash (SHA-256) | Collected By | Date |
|----|------|----------|----------------|--------------|------|
| E001 | CloudTrail logs | s3://evidence-bucket/ct/ | [hash] | [Name] | [Date] |
| E002 | Web server logs | s3://evidence-bucket/web/ | [hash] | [Name] | [Date] |
| E003 | EC2 memory dump | s3://evidence-bucket/memory/ | [hash] | [Name] | [Date] |

---

## Indicators of Compromise (IOCs)

### IP Addresses

| IP | First Seen | Last Seen | Activity |
|----|------------|-----------|----------|
| [IP] | [DateTime] | [DateTime] | [Description] |

### User Agents

```
[User agent strings observed]
```

### API Patterns

```
[Unusual API call patterns]
```

### File Hashes

| File | MD5 | SHA-256 |
|------|-----|---------|
| [filename] | [hash] | [hash] |

---

## Log Queries Used

### CloudTrail - Find attacker activity

```sql
SELECT eventtime, eventsource, eventname, sourceipaddress, useridentity.arn
FROM cloudtrail_logs
WHERE sourceipaddress = 'x.x.x.x'
  AND eventtime BETWEEN 'YYYY-MM-DD' AND 'YYYY-MM-DD'
ORDER BY eventtime
```

### CloudWatch Logs - Application errors

```
fields @timestamp, @message
| filter @message like /error|exception/
| sort @timestamp desc
| limit 1000
```

### VPC Flow Logs - Network connections

```sql
SELECT srcaddr, dstaddr, dstport, protocol, action
FROM vpc_flow_logs
WHERE dstaddr = '169.254.169.254'
  AND start BETWEEN 'YYYY-MM-DD' AND 'YYYY-MM-DD'
```

---

## Gap Analysis

### What We Had vs. What We Needed

| Area | Existing State | Ideal State | Gap |
|------|----------------|-------------|-----|
| Logging | [Current] | [Needed] | [Gap] |
| Alerting | [Current] | [Needed] | [Gap] |
| Access Control | [Current] | [Needed] | [Gap] |

---

## Technical Recommendations

### Immediate (Block the specific attack)

```bash
# Example: Require IMDSv2
aws ec2 modify-instance-metadata-options \
  --instance-id i-1234567890abcdef0 \
  --http-tokens required
```

### Short-term (Reduce attack surface)

```yaml
# Example: AWS Config rule for IMDSv2
Type: AWS::Config::ConfigRule
Properties:
  ConfigRuleName: ec2-imdsv2-check
  Source:
    Owner: AWS
    SourceIdentifier: EC2_IMDSV2_CHECK
```

### Long-term (Architectural improvements)

[Description of architectural changes needed]

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | [Date] | [Name] | Initial timeline draft |
| 0.2 | [Date] | [Name] | Added evidence links |
| 1.0 | [Date] | [Name] | Final version |
