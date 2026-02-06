# Multi-Account Architecture Design

## Company: MedTech Solutions

### Requirements (from the brief)

- 45 employees, healthcare startup
- HIPAA regulated (patient data)
- Must isolate patient data from non-production
- Developers need freedom to experiment
- Central logging required
- Regions restricted to us-east-1 and us-west-2
- Security team needs cross-account visibility
- CI/CD needs production deploy access

---

## 1. Account Structure

Draw your OU and account hierarchy below:

```
Management Account (Root)
│
├── [OU NAME]
│   ├── [Account Name] — [Purpose]
│   └── [Account Name] — [Purpose]
│
├── [OU NAME]
│   └── [Account Name] — [Purpose]
│
├── [OU NAME]
│   ├── [Account Name] — [Purpose]
│   └── [Account Name] — [Purpose]
│
└── [OU NAME]
    └── [Account Name] — [Purpose]
```

**Total accounts:** [number]
**Total OUs:** [number]

---

## 2. SCP Assignments

For each OU, list which SCPs you would attach:

| OU | SCPs Applied | Why |
|----|-------------|-----|
| [OU Name] | [SCP names] | [justification] |
| [OU Name] | [SCP names] | [justification] |
| [OU Name] | [SCP names] | [justification] |
| [OU Name] | [SCP names] | [justification] |

---

## 3. Security Services Placement

Where does each security service run?

| Service | Runs In (Account) | Covers |
|---------|-------------------|--------|
| CloudTrail (org trail) | [account] | [scope] |
| GuardDuty | [account] | [scope] |
| Security Hub | [account] | [scope] |
| AWS Config | [account] | [scope] |
| IAM Access Analyzer | [account] | [scope] |

---

## 4. Patient Data Isolation

How is patient data protected?

- **Which account holds patient data?** [answer]
- **What SCPs protect it?** [answer]
- **Who has access?** [answer]
- **How is access audited?** [answer]

---

## 5. Developer Freedom vs Security

How do you balance developer experimentation with security guardrails?

- **Where do developers experiment?** [answer]
- **What restrictions apply?** [answer]
- **What's different from production?** [answer]

---

## 6. CI/CD Access

How does the CI/CD pipeline deploy to production?

- **Where does CI/CD run?** [answer]
- **How does it access production?** [answer]
- **What limits its access?** [answer]

---

## 7. Justification

Why did you design it this way? List the top 3 security decisions:

1. [Decision and rationale]
2. [Decision and rationale]
3. [Decision and rationale]

---

## Self-Check

Before submitting, verify:

- [ ] Patient data is in a dedicated account, NOT shared with dev/staging
- [ ] Management account runs no workloads
- [ ] Security services are centralized (not scattered across accounts)
- [ ] Region restrictions are enforced via SCP
- [ ] CloudTrail protection SCP is in place
- [ ] There's an escape hatch role for emergencies
- [ ] CI/CD has minimal required access to production
- [ ] Developers can break things in sandbox without affecting production
