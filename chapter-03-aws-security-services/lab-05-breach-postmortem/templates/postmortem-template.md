# Security Incident Post-Mortem Report

**Incident ID:** [INC-YYYY-NNNN]
**Date:** [Report Date]
**Author:** [Your Name]
**Classification:** [Confidential/Internal/Public]

---

## 1. Executive Summary

[Write 1-3 paragraphs summarizing the incident for executive leadership. Focus on business impact, not technical details.]

### Key Facts

| Attribute | Value |
|-----------|-------|
| **Incident Date(s)** | [Start date] - [End date] |
| **Detection Date** | [When discovered] |
| **Time to Detection** | [Hours/Days] |
| **Data Affected** | [Type and quantity] |
| **Systems Affected** | [List systems] |
| **Customer Impact** | [Description] |
| **Current Status** | [Contained/Remediated/Ongoing] |

### Immediate Actions Taken

1. [First containment action]
2. [Second containment action]
3. [Third containment action]

### Top Recommendations

1. [Highest priority recommendation]
2. [Second priority recommendation]
3. [Third priority recommendation]

---

## 2. Incident Timeline

All times in [UTC/Local timezone].

### Phase 1: Initial Compromise

| Date/Time | Event | Evidence Source |
|-----------|-------|-----------------|
| [YYYY-MM-DD HH:MM] | [Description] | [Log/System] |
| [YYYY-MM-DD HH:MM] | [Description] | [Log/System] |

### Phase 2: Discovery/Reconnaissance

| Date/Time | Event | Evidence Source |
|-----------|-------|-----------------|
| [YYYY-MM-DD HH:MM] | [Description] | [Log/System] |
| [YYYY-MM-DD HH:MM] | [Description] | [Log/System] |

### Phase 3: Lateral Movement

| Date/Time | Event | Evidence Source |
|-----------|-------|-----------------|
| [YYYY-MM-DD HH:MM] | [Description] | [Log/System] |
| [YYYY-MM-DD HH:MM] | [Description] | [Log/System] |

### Phase 4: Data Access/Exfiltration

| Date/Time | Event | Evidence Source |
|-----------|-------|-----------------|
| [YYYY-MM-DD HH:MM] | [Description] | [Log/System] |
| [YYYY-MM-DD HH:MM] | [Description] | [Log/System] |

### Phase 5: Detection and Response

| Date/Time | Event | Evidence Source |
|-----------|-------|-----------------|
| [YYYY-MM-DD HH:MM] | [Description] | [Log/System] |
| [YYYY-MM-DD HH:MM] | [Description] | [Log/System] |

---

## 3. Root Cause Analysis

### 3.1 How Did They Get In? (Initial Access)

[Describe the vulnerability, misconfiguration, or method used to gain initial access]

**Technical Details:**
```
[Include relevant code, configuration, or log snippets]
```

**Contributing Factors:**
- [Factor 1]
- [Factor 2]

---

### 3.2 What Did They Find? (Discovery)

[Describe what information or access the attacker discovered after initial compromise]

**Information Gathered:**
- [Data point 1]
- [Data point 2]
- [Data point 3]

**Evidence:**
```
[Relevant log entries or API calls]
```

---

### 3.3 How Did They Move? (Lateral Movement)

[Describe how the attacker expanded their access beyond the initial foothold]

**Movement Path:**
```
[Initial Access] → [System 2] → [System 3] → [Target Data]
```

**Credentials/Access Used:**
- [Credential or access method 1]
- [Credential or access method 2]

---

### 3.4 What Did They Take? (Impact)

[Describe the actual damage - data exfiltrated, systems modified, business impact]

**Data Impact:**

| Data Type | Records Affected | Sensitivity |
|-----------|------------------|-------------|
| [Type 1] | [Count] | [High/Medium/Low] |
| [Type 2] | [Count] | [High/Medium/Low] |

**System Impact:**
- [System 1]: [Impact description]
- [System 2]: [Impact description]

**Business Impact:**
- [Financial impact if known]
- [Regulatory implications]
- [Reputation considerations]

---

### 3.5 When Could We Have Detected It? (Detection Gaps)

[Describe the missed opportunities to detect the attack earlier]

**Detection Opportunities:**

| Point in Attack | Potential Detection | Why Missed |
|-----------------|---------------------|------------|
| [Phase 1] | [What could have detected] | [Reason] |
| [Phase 2] | [What could have detected] | [Reason] |
| [Phase 3] | [What could have detected] | [Reason] |

**Logging Gaps:**
- [Gap 1]
- [Gap 2]

**Alerting Gaps:**
- [Gap 1]
- [Gap 2]

---

## 4. Containment and Remediation

### Immediate Actions (Completed)

| Action | Date | Owner | Status |
|--------|------|-------|--------|
| [Action 1] | [Date] | [Name] | Complete |
| [Action 2] | [Date] | [Name] | Complete |
| [Action 3] | [Date] | [Name] | Complete |

### Short-term Actions (In Progress)

| Action | Due Date | Owner | Status |
|--------|----------|-------|--------|
| [Action 1] | [Date] | [Name] | In Progress |
| [Action 2] | [Date] | [Name] | Not Started |

---

## 5. Recommendations

### Critical Priority (24-48 hours)

#### 5.1 [Recommendation Title]

**Risk Addressed:** [What risk this mitigates]

**Specific Action:** [Exactly what needs to be done]

**Owner:** [Team or person responsible]

**Due Date:** [Specific date]

**Success Criteria:** [How to verify completion]

**Estimated Effort:** [Hours/Days]

---

#### 5.2 [Recommendation Title]

**Risk Addressed:** [What risk this mitigates]

**Specific Action:** [Exactly what needs to be done]

**Owner:** [Team or person responsible]

**Due Date:** [Specific date]

**Success Criteria:** [How to verify completion]

**Estimated Effort:** [Hours/Days]

---

### High Priority (1-2 weeks)

#### 5.3 [Recommendation Title]

[Same format as above]

---

#### 5.4 [Recommendation Title]

[Same format as above]

---

### Medium Priority (1-3 months)

#### 5.5 [Recommendation Title]

[Same format as above]

---

### Low Priority (3-6 months)

#### 5.6 [Recommendation Title]

[Same format as above]

---

## 6. Lessons Learned

### What Went Well

- [Positive aspect 1]
- [Positive aspect 2]

### What Could Be Improved

- [Improvement area 1]
- [Improvement area 2]

### Process Changes

- [Change 1]
- [Change 2]

---

## 7. Appendices

### A. Indicators of Compromise (IOCs)

| Type | Value | Context |
|------|-------|---------|
| IP Address | [IP] | [Where seen] |
| User Agent | [UA string] | [Where seen] |
| File Hash | [Hash] | [File name] |

### B. Affected Systems

| System | Role | Impact |
|--------|------|--------|
| [System 1] | [Role] | [Impact] |
| [System 2] | [Role] | [Impact] |

### C. Evidence Preservation

| Evidence | Location | Retention |
|----------|----------|-----------|
| [Log type] | [Where stored] | [How long] |
| [Image/Snapshot] | [Where stored] | [How long] |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | [Date] | [Name] | Initial draft |
| 1.1 | [Date] | [Name] | [Changes] |

---

## Distribution

This document is classified as [Classification Level].

**Approved Recipients:**
- [Name/Role 1]
- [Name/Role 2]
- [Name/Role 3]
