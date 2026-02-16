# Chapter: IAM Labs

## Identity Is the Perimeter

Every major cloud breach comes back to IAM. Capital One — overprivileged role. Uber — stolen credentials. LastPass — compromised keys. The network perimeter is gone. Identity IS the security boundary.

These 4 labs take you from understanding the blast radius problem to implementing least privilege in practice.

## Labs

| Lab | Title | What You'll Do | Time |
|-----|-------|----------------|------|
| 01 | [Blast Radius](./lab-01-blast-radius/) | Create overprivileged vs scoped users, see the damage difference | ~25 min |
| 02 | [Roles & Trust Policies](./lab-02-roles-trust-policies/) | Build groups, roles, trust policies, assume a role with STS | ~30 min |
| 03 | [ARN Scoping & Policy Writing](./lab-03-arn-scoping/) | Write 5 IAM policies, hit the S3 ARN trap, scope by prefix and region | ~30 min |
| 04 | [Least Privilege Lifecycle](./lab-04-least-privilege/) | Use permissions boundaries, scope down from broad to narrow | ~30 min |

## Prerequisites

- AWS CLI configured with admin-level permissions
- Completed Chapter 01 (Foundations) and the AWS Security Services chapter

Verify your setup:

```bash
aws sts get-caller-identity
```

## Cost

**$0** — All labs use IAM (free) and minimal S3 (free tier). Resources are cleaned up within each lab.

## How It Works

1. **Complete labs in order** — each one builds on concepts from the previous
2. **Each lab has setup + verify + cleanup scripts** — follow the README and run the scripts
3. **Clean up after each lab** or use the chapter cleanup:

```bash
bash scripts/chapter-cleanup.sh
```

## Learning Path

```
Lab 01: Blast Radius         → WHY least privilege matters
         ↓
Lab 02: Roles & Trust        → HOW identity works in AWS
         ↓
Lab 03: ARN Scoping          → HOW to write precise policies
         ↓
Lab 04: Least Privilege       → HOW to scope down and cap permissions
```

## Skills Gained

After completing these labs, you will be able to:

- Explain why overprivileged access is the #1 cloud security risk
- Create IAM users, groups, and roles from scratch
- Write trust policies and permission policies
- Assume a role and use temporary credentials
- Write IAM policies with precise ARN scoping
- Use conditions for region and prefix restrictions
- Implement permissions boundaries
- Scope down broad policies to least privilege
