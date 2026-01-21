# Lab 04: Breach Post-Mortem Report

## Overview

**Security knowledge means nothing if you can't communicate it effectively.**

In this final lab of Chapter 02, you'll synthesize everything you've learned into a professional breach post-mortem report. This is the document that executives read, regulators request, and teams use to prevent future incidents.

## Cost

This lab uses no AWS infrastructure. **Cost: $0**

## Learning Objectives

1. Structure a professional post-mortem report
2. Write executive summaries for non-technical audiences
3. Create detailed technical timelines
4. Develop prioritized remediation recommendations
5. Communicate security findings effectively

---

## Part 1: Choose Your Scenario

Select one of the following scenarios for your post-mortem:

### Option A: Capital One Simulation
Based on Lab 02, write a post-mortem as if you were the Capital One security team discovering the SSRF attack.

### Option B: Uber Simulation
Write a post-mortem analyzing the credential leak and MFA fatigue attack.

### Option C: LastPass Simulation
Document the engineer compromise and subsequent vault theft.

### Option D: Your Own Scenario
If you performed the Lab 02 SSRF attack, write a post-mortem based on your actual experience.

---

## Part 2: Post-Mortem Structure

Every good post-mortem follows a structure. Copy the template:

```bash
cd chapter-02-breach-analysis/lab-04-breach-postmortem
cp templates/postmortem-template.md my-postmortem.md
```

### The 7 Sections

1. **Executive Summary** - 1 page max, business impact focus
2. **Incident Timeline** - Hour-by-hour breakdown
3. **Root Cause Analysis** - The 5 questions framework
4. **Impact Assessment** - What was affected
5. **Detection Analysis** - How it was found (or wasn't)
6. **Remediation Actions** - What was done immediately
7. **Recommendations** - What to do to prevent recurrence

---

## Part 3: Write the Executive Summary

The executive summary is for people who won't read the full report. It must answer:

- What happened? (one sentence)
- When? (date range)
- What was the impact? (business terms)
- Are we safe now? (current status)
- What are we doing about it? (high-level actions)

### Template

```markdown
## Executive Summary

On [DATE], [COMPANY] experienced a security incident involving [BRIEF DESCRIPTION].
The incident resulted in [IMPACT - data exposed, systems affected, business disruption].

### Key Facts
- **Duration:** [Start] to [End]
- **Data Affected:** [What data, how many records]
- **Systems Affected:** [Which systems]
- **Customer Impact:** [How customers were affected]
- **Current Status:** [Contained/Remediated/Ongoing]

### Immediate Actions Taken
1. [Action 1]
2. [Action 2]
3. [Action 3]

### Recommendations Summary
- [High-priority recommendation 1]
- [High-priority recommendation 2]
- [High-priority recommendation 3]
```

### Example (Capital One style)

```markdown
## Executive Summary

On July 19, 2019, Capital One discovered that an external attacker had
exploited a misconfigured web application firewall to access customer data
stored in Amazon S3. The incident affected approximately 106 million customers.

### Key Facts
- **Duration:** March 22-23, 2019 (exfiltration), discovered July 19, 2019
- **Data Affected:** 106 million customer records, including 140,000 SSNs
- **Systems Affected:** AWS S3 storage containing credit card applications
- **Customer Impact:** Personal data exposed, requiring notification
- **Current Status:** Contained. Attacker apprehended by FBI.

### Immediate Actions Taken
1. Disabled compromised IAM role
2. Enabled IMDSv2 on all EC2 instances
3. Engaged FBI and began customer notification

### Recommendations Summary
- Require IMDSv2 across all AWS accounts
- Implement least-privilege IAM policies
- Deploy SSRF protections in web applications
```

---

## Part 4: Create the Technical Timeline

The timeline helps investigators understand the attack sequence.

### Timeline Format

```markdown
## Incident Timeline

All times in UTC.

### [DATE] - Initial Compromise

| Time | Event | Source |
|------|-------|--------|
| HH:MM | [What happened] | [Log source] |
| HH:MM | [What happened] | [Log source] |

### [DATE] - Lateral Movement

| Time | Event | Source |
|------|-------|--------|
| HH:MM | [What happened] | [Log source] |

### [DATE] - Data Exfiltration

| Time | Event | Source |
|------|-------|--------|
| HH:MM | [What happened] | [Log source] |

### [DATE] - Detection

| Time | Event | Source |
|------|-------|--------|
| HH:MM | [What happened] | [Log source] |
```

### Example (Lab 02 simulation)

```markdown
## Incident Timeline

All times in UTC. Based on Lab 02 SSRF simulation.

### Day 1 - Initial Access

| Time | Event | Source |
|------|-------|--------|
| 10:00 | Attacker discovers /fetch endpoint | Web logs |
| 10:05 | First SSRF probe to metadata service | Web logs |
| 10:06 | IAM role name retrieved via SSRF | Web logs |
| 10:07 | IAM credentials extracted from IMDS | Web logs |

### Day 1 - Data Access

| Time | Event | Source |
|------|-------|--------|
| 10:10 | Attacker lists S3 buckets | CloudTrail |
| 10:11 | Attacker lists bucket contents | CloudTrail |
| 10:12 | Sensitive data downloaded | CloudTrail |

### Day 1 - Detection (Simulated)

| Time | Event | Source |
|------|-------|--------|
| 10:30 | Unusual S3 access pattern detected | CloudWatch alarm |
| 10:35 | Security team begins investigation | Incident log |
| 10:40 | Compromised role disabled | CloudTrail |
```

---

## Part 5: Apply the 5-Question Framework

Use the framework from Lab 01 for root cause analysis.

### Template

```markdown
## Root Cause Analysis

### 1. How did they get in? (Initial Access)

[Describe the entry point, vulnerability exploited, or access method]

**Evidence:**
- [Log entry or observation]
- [Technical detail]

### 2. What did they find? (Discovery)

[Describe what information or access the attacker gained]

**Evidence:**
- [API calls observed]
- [Data accessed]

### 3. How did they move? (Lateral Movement)

[Describe how initial access expanded]

**Evidence:**
- [Credential use]
- [Systems accessed]

### 4. What did they take? (Impact)

[Describe the actual damage]

**Evidence:**
- [Data exfiltrated]
- [Systems modified]

### 5. When could we have detected it? (Detection Gaps)

[Describe missed detection opportunities]

**Detection Opportunities:**
- [What could have alerted us]
- [Why it didn't]
```

---

## Part 6: Write Recommendations

Recommendations should be SMART: Specific, Measurable, Achievable, Relevant, Time-bound.

### Priority Levels

| Priority | Timeline | Criteria |
|----------|----------|----------|
| Critical | 24-48 hours | Active exploitation possible |
| High | 1-2 weeks | Significant risk reduction |
| Medium | 1-3 months | Important but not urgent |
| Low | 3-6 months | Good practice improvements |

### Recommendation Format

```markdown
## Recommendations

### Critical Priority

#### 1. [Short title]

**Risk:** [What risk this addresses]

**Action:** [Specific action to take]

**Owner:** [Team/Person responsible]

**Timeline:** [When it should be done]

**Verification:** [How to confirm it's done]

### High Priority

#### 2. [Short title]
...
```

### Example Recommendations

```markdown
## Recommendations

### Critical Priority

#### 1. Require IMDSv2 on All EC2 Instances

**Risk:** SSRF vulnerabilities can extract IAM credentials via IMDSv1

**Action:** Enable IMDSv2 requirement for all existing and new EC2 instances
using AWS Config rule and Organization SCP

**Owner:** Cloud Platform Team

**Timeline:** 48 hours for critical workloads, 2 weeks for all instances

**Verification:** AWS Config compliance report shows 100% IMDSv2

---

#### 2. Implement Least-Privilege IAM Roles

**Risk:** Over-permissioned roles allow attackers to access unrelated resources

**Action:** Review and scope down IAM roles for web-facing applications.
Remove wildcard permissions and limit to specific resources.

**Owner:** Security Engineering

**Timeline:** 2 weeks

**Verification:** IAM Access Analyzer shows no unused permissions

### High Priority

#### 3. Deploy SSRF Protection

**Risk:** Web applications can be exploited to access internal services

**Action:** Implement URL validation in /fetch endpoint. Block requests to:
- 169.254.169.254 (metadata)
- 10.0.0.0/8 (internal)
- 172.16.0.0/12 (internal)

**Owner:** Application Development

**Timeline:** 1 week

**Verification:** Penetration test confirms SSRF blocked
```

---

## Part 7: Verify Your Report

Run the checklist script:

```bash
chmod +x scripts/checklist.sh
./scripts/checklist.sh my-postmortem.md
```

### Manual Checklist

- [ ] Executive summary is under 1 page
- [ ] Timeline includes specific times and sources
- [ ] All 5 questions are answered with evidence
- [ ] Recommendations have owners and timelines
- [ ] Technical terms are explained for executives
- [ ] No sensitive data (real IPs, keys) included
- [ ] Action items are specific and measurable

---

## Part 8: Optional - Share Your Work

Consider sharing what you've learned:

### LinkedIn Post Ideas

1. "What I learned analyzing the Capital One breach..."
2. "The 5 questions every security professional should ask..."
3. "Why IMDSv2 matters: A hands-on breakdown"

### Template

```
Just completed a hands-on cloud security lab simulating
the Capital One breach.

Key takeaways:
- SSRF + IMDSv1 = credential theft
- Least privilege isn't optional
- Detection opportunities exist at every step

The 5-question framework for breach analysis:
1. How did they get in?
2. What did they find?
3. How did they move?
4. What did they take?
5. When could we have detected it?

#CloudSecurity #AWS #CyberSecurity #LearningInPublic
```

---

## Summary

| Section | Purpose |
|---------|---------|
| Executive Summary | Quick overview for leadership |
| Timeline | Detailed sequence of events |
| Root Cause | 5-question analysis |
| Impact | What was actually affected |
| Detection | How it was (or wasn't) found |
| Remediation | What was done immediately |
| Recommendations | What to do next |

## Key Takeaways

- **Know your audience** - Executives need business impact, engineers need technical details
- **Be specific** - Vague recommendations don't get implemented
- **Assign ownership** - Every recommendation needs an owner
- **Set timelines** - "Soon" means never
- **Follow up** - A post-mortem is only valuable if actions are completed

## Post-Mortem Anti-Patterns

Avoid these common mistakes:

| Anti-Pattern | Problem | Better Approach |
|--------------|---------|-----------------|
| Blame individuals | Creates defensive culture | Focus on systems and processes |
| Vague recommendations | Won't be implemented | Be specific with owners and dates |
| Missing timelines | No urgency | Assign priority levels |
| Technical jargon only | Executives won't understand | Write for multiple audiences |
| No follow-up | Recommendations ignored | Schedule review meetings |

---

## Chapter 02 Complete!

Congratulations! You've completed Chapter 02: Real-World Breach Analysis.

### What You Learned

1. **Lab 01:** The 5-question breach analysis framework
2. **Lab 02:** How SSRF + IMDSv1 led to the Capital One breach
3. **Lab 03:** Why hardcoded credentials are dangerous
4. **Lab 04:** How to communicate security findings professionally

### Next Steps

- Apply this knowledge to your own AWS environments
- Review your organization's IMDS settings
- Audit codebases for hardcoded secrets
- Practice writing post-mortems for tabletop exercises

Continue to the **Cloud Security Assessment Project** to put everything together!
