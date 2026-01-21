# Cloud Security Assessment Report

**Assessment Date:** [DATE]
**Assessor:** [YOUR NAME]
**Environment:** [AWS Account ID / Description]
**Classification:** [Confidential/Internal]

---

## Executive Summary

[1-2 paragraphs summarizing the assessment for leadership]

### Key Metrics

| Metric | Value |
|--------|-------|
| Total Findings | [NUMBER] |
| Critical | [NUMBER] |
| High | [NUMBER] |
| Medium | [NUMBER] |
| Low | [NUMBER] |

### Overall Risk Rating

**[CRITICAL / HIGH / MEDIUM / LOW]**

[Brief justification for the rating]

### Top 3 Priorities

1. [Most critical finding - brief description]
2. [Second priority - brief description]
3. [Third priority - brief description]

---

## Scope

### In Scope

- [ ] IAM Users and Roles
- [ ] EC2 Instances
- [ ] Security Groups
- [ ] S3 Buckets
- [ ] [Other resources assessed]

### Out of Scope

- [Resources not assessed and why]

### Methodology

This assessment followed the breach analysis framework:
1. Reconnaissance - Inventory all resources
2. Vulnerability Scan - Check each category
3. Risk Analysis - Map to real breach patterns
4. Recommendations - Prioritized remediation

---

## Findings

### Critical Findings

#### Finding 1: [Title]

**Severity:** Critical

**Category:** [Identity / Network / Data / Compute]

**Affected Resource(s):**
- [Resource ID/Name]

**Description:**
[Clear description of the issue]

**Evidence:**
```
[Command output or screenshot description]
```

**Risk:**
[What could happen if exploited - connect to real breach]

**Breach Parallel:**
[Capital One / Uber / LastPass] - [Brief explanation]

**Recommendation:**
[Specific action to take]

**Remediation:**
```bash
[Exact command to fix]
```

**Verification:**
```bash
[Command to verify fix]
```

---

#### Finding 2: [Title]

[Same format as above]

---

### High Findings

#### Finding 3: [Title]

[Same format]

---

### Medium Findings

#### Finding 4: [Title]

[Same format]

---

### Low Findings

#### Finding 5: [Title]

[Same format]

---

## Positive Observations

List security controls that ARE properly configured:

- [Good practice observed]
- [Good practice observed]
- [Good practice observed]

---

## Recommendations Summary

| Priority | Finding | Recommendation | Owner | Due Date |
|----------|---------|----------------|-------|----------|
| Critical | [Finding 1] | [Action] | [Team] | [Date] |
| Critical | [Finding 2] | [Action] | [Team] | [Date] |
| High | [Finding 3] | [Action] | [Team] | [Date] |
| Medium | [Finding 4] | [Action] | [Team] | [Date] |
| Low | [Finding 5] | [Action] | [Team] | [Date] |

---

## Breach Pattern Analysis

### How These Findings Connect to Real Breaches

| Finding | Similar Breach | Attack Path |
|---------|----------------|-------------|
| [Finding] | Capital One | SSRF → IMDS → Credentials → S3 |
| [Finding] | Uber | Leaked creds → MFA bypass → PAM → Full access |
| [Finding] | LastPass | Compromised endpoint → Dev access → Cloud keys |

### If Exploited Together

[Describe how multiple findings could chain together for a larger attack]

---

## Appendix A: Resources Scanned

| Resource Type | Count | Issues Found |
|---------------|-------|--------------|
| EC2 Instances | [N] | [N] |
| Security Groups | [N] | [N] |
| S3 Buckets | [N] | [N] |
| IAM Users | [N] | [N] |
| IAM Roles | [N] | [N] |

---

## Appendix B: Tools Used

- AWS CLI
- [Any other tools]

---

## Appendix C: Commands Reference

```bash
# Reconnaissance
aws ec2 describe-instances
aws s3 ls
aws iam list-users

# Scanning
[Commands used for scanning]
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | [Date] | [Name] | Initial assessment |
