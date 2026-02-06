# Lab 06: CloudTrail Log Investigation

## Overview

**CloudTrail recorded everything. Can you find it?**

In this lab, you'll play both sides. First, you'll simulate suspicious activity in your own AWS account — creating resources, opening ports, making users. Then you'll switch hats and hunt for that activity in CloudTrail Event History, just like a security analyst investigating a real incident.

Finally, you'll investigate a simulated breach using provided CloudTrail evidence and piece together an attack timeline.

## Cost

Resources created in Part 1 are cleaned up in Part 3. **Cost: $0** (free tier)

## Learning Objectives

1. Generate real AWS activity and see it appear in CloudTrail
2. Query CloudTrail Event History using the AWS CLI
3. Understand the anatomy of a CloudTrail event (userIdentity, eventName, sourceIPAddress)
4. Investigate a simulated breach by analyzing CloudTrail JSON events
5. Reconstruct an attack timeline from log evidence

## Prerequisites

- AWS CLI configured with admin permissions
- Completed Lab 02 (CloudTrail setup) — or at minimum, CloudTrail Event History is available (it's on by default)

---

First, make sure you're in the lab directory:

```bash
cd chapter-03-aws-security-services/lab-06-cloudtrail-investigation
```

## Part 1: Simulate Suspicious Activity

You're going to create resources that look suspicious — the kind of things an attacker would do. Then you'll hunt for this activity in CloudTrail.

### Run the simulation

```bash
bash scripts/generate-activity.sh
```

This script does the following (all safe, all cleaned up later):

1. **Reconnaissance** — lists S3 buckets, IAM users, CloudTrail trails
2. **Creates a security group** with SSH open to `0.0.0.0/0` (a red flag)
3. **Creates an IAM user** called `lab06-suspicious-user` (attacker creating persistence)
4. **Creates access keys** for that user (attacker establishing a backdoor)

Every one of these actions is now recorded in CloudTrail. Let's go find them.

> **Note:** CloudTrail Event History can take **5-15 minutes** to show new events. If your queries in Part 2 return empty results, wait a few minutes and try again. This delay is normal — it's the same in production, which is why real-time alerting (GuardDuty, CloudWatch) matters.

---

## Part 2: Hunt for Your Activity in CloudTrail

CloudTrail Event History records management events within minutes. Let's query it.

### Step 1: See your recent API calls

```bash
aws cloudtrail lookup-events \
    --max-results 10 \
    --query 'Events[].{Time:EventTime,Event:EventName,Source:EventSource}' \
    --output table
```

You should see the API calls from Part 1 — `ListBuckets`, `CreateSecurityGroup`, `CreateUser`, etc.

### Step 2: Find the security group creation

```bash
aws cloudtrail lookup-events \
    --lookup-attributes "AttributeKey=EventName,AttributeValue=CreateSecurityGroup" \
    --max-results 3 \
    --query 'Events[].{Time:EventTime,Event:EventName,User:Username}' \
    --output table
```

**You just caught yourself.** In a real investigation, seeing `CreateSecurityGroup` with ingress `0.0.0.0/0` is a red flag.

### Step 3: Find the IAM user creation

```bash
aws cloudtrail lookup-events \
    --lookup-attributes "AttributeKey=EventName,AttributeValue=CreateUser" \
    --max-results 3 \
    --query 'Events[].{Time:EventTime,Event:EventName,User:Username}' \
    --output table
```

**Red flag:** An unexpected `CreateUser` event could mean an attacker is creating a backdoor account.

### Step 4: Find the access key creation

```bash
aws cloudtrail lookup-events \
    --lookup-attributes "AttributeKey=EventName,AttributeValue=CreateAccessKey" \
    --max-results 3 \
    --query 'Events[].{Time:EventTime,Event:EventName,User:Username}' \
    --output table
```

**Red flag:** `CreateAccessKey` on a new user means someone is setting up persistent access.

### Step 5: Look at the full event JSON

Pull the full event for the `CreateUser` call:

```bash
aws cloudtrail lookup-events \
    --lookup-attributes "AttributeKey=EventName,AttributeValue=CreateUser" \
    --max-results 1 \
    --query 'Events[0].CloudTrailEvent' \
    --output text | python3 -m json.tool
```

Read through the JSON. Find these fields:

| Field | What You'll See | Why It Matters |
|-------|-----------------|----------------|
| `userIdentity.arn` | Your IAM identity | **WHO** did it |
| `eventName` | `CreateUser` | **WHAT** they did |
| `eventTime` | Timestamp from Part 1 | **WHEN** they did it |
| `sourceIPAddress` | Your IP address | **WHERE** they came from |
| `requestParameters.userName` | `lab06-suspicious-user` | **WHAT EXACTLY** — the user they created |
| `responseElements` | The created user's ARN | **WHAT HAPPENED** as a result |

This is the same event structure you'd analyze during a real incident.

### Step 6: Filter by your identity

See everything YOU did in one view:

```bash
USERNAME=$(aws sts get-caller-identity --query Arn --output text | awk -F'/' '{print $NF}')

aws cloudtrail lookup-events \
    --lookup-attributes "AttributeKey=Username,AttributeValue=$USERNAME" \
    --max-results 15 \
    --query 'Events[].{Time:EventTime,Event:EventName,Source:EventSource}' \
    --output table
```

If these were an attacker's actions, you'd now have their full activity log.

---

## Part 3: Clean Up the Suspicious Resources

Remove the resources you created in Part 1:

```bash
bash scripts/cleanup.sh
```

This deletes the `lab06-suspicious-user`, its access keys, and the open security group.

**After cleanup, run one more CloudTrail query:**

```bash
aws cloudtrail lookup-events \
    --lookup-attributes "AttributeKey=EventName,AttributeValue=DeleteUser" \
    --max-results 3 \
    --query 'Events[].{Time:EventTime,Event:EventName,User:Username}' \
    --output table
```

Even the cleanup is recorded. CloudTrail captures everything — creation AND deletion.

---

## Part 4: Anatomy of a CloudTrail Event

Now that you've seen real events, let's make sure you can read them fluently.

### Quick reference

| Field | What It Tells You | Why It Matters |
|-------|-------------------|----------------|
| `userIdentity.type` | How they authenticated | AssumedRole, IAMUser, Root, AWSService |
| `userIdentity.arn` | Exact identity | Which user or role |
| `sourceIPAddress` | Where the call came from | Unusual location = red flag |
| `userAgent` | What tool they used | Console vs CLI vs SDK |
| `eventName` | The API action | What they did |
| `errorCode` | If it failed | AccessDenied = they tried but couldn't |
| `awsRegion` | Which region | Unusual region = red flag |

### Red flags to watch for

- `sourceIPAddress` from a country nobody in your org works from
- `userIdentity.type` = `Root` (root account should rarely be used)
- `errorCode` = `AccessDenied` repeated many times (permission enumeration)
- `eventName` contains `Delete`, `Stop`, `Disable` for logging services
- `userAgent` = `aws-cli` when the user normally uses the console
- Activity in unusual `awsRegion` values
- `CreateUser` or `CreateAccessKey` at unusual times

---

## Part 5: Investigate the Breach

In Parts 1-3, you generated activity and hunted for it in your own account. You knew what to look for because you did it yourself. In real incident response, you don't have that luxury.

Now you'll investigate a breach where you **don't** know what happened. You've been given raw CloudTrail events extracted from a compromised account and need to piece together the attack from the evidence alone — the same way a security analyst would.

> **Why a provided evidence file?** Real breaches involve multiple accounts, assumed roles, and data events that wouldn't appear in CloudTrail Event History's free tier. The evidence file contains realistic events (same JSON structure you just analyzed) from a simulated breach in account `938471625033`. Every field is authentic — the same fields you learned in Part 4.

### Read the evidence

```bash
cat evidence/suspicious-events.json | python3 -m json.tool
```

There are 9 events. Read each one carefully — same structure as the events you just queried in Part 2.

### Run the guided investigation

```bash
bash scripts/investigate.sh
```

This walks you through each event with analysis and red flags.

### Investigation questions

After reviewing the evidence, answer these:

**Question 1: Initial Access**
- What identity did the attacker use?
- What was the attacker's source IP address?

**Question 2: Reconnaissance**
- What was the first thing the attacker did after gaining access?

**Question 3: Data Exfiltration**
- Which S3 bucket did they target?
- What files did they download?

**Question 4: Persistence**
- How did the attacker create a backdoor?

**Question 5: Covering Tracks**
- How did the attacker try to hide their activity?
- Did they succeed? Why not?

**Question 6: Timeline**
- How long did the entire attack take?

---

## Part 6: Build the Timeline

Using your answers, construct an attack timeline:

```
INCIDENT TIMELINE
=================

Account:    938471625033
Date:       [from events]
Duration:   [first event to last event]
Attacker IP: [from events]

TIME        | ACTION                    | RESULT     | EVIDENCE
------------|---------------------------|------------|------------------
[time]      | [what happened]           | [success?] | [eventName]
[time]      | [what happened]           | [success?] | [eventName]
...         | ...                       | ...        | ...

SEVERITY:   [Critical/High/Medium/Low]

EARLIEST DETECTION POINT:
[when and how this could have been caught]

RECOMMENDATIONS:
1. [immediate action]
2. [short-term fix]
3. [long-term prevention]
```

---

## Part 7: Verify Your Investigation

```bash
bash scripts/verify.sh
```

Interactive quiz based on the evidence. Tests whether you correctly analyzed the breach.

---

## Summary

| Concept | What You Learned |
|---------|-----------------|
| Live hunting | Generate activity, then find it in CloudTrail Event History |
| Event anatomy | userIdentity, eventName, sourceIPAddress, requestParameters |
| Red flags | New users, open security groups, access key creation, logging changes |
| Investigation | Reconstruct who/what/when/where from raw CloudTrail JSON |
| Timeline | Sequencing events to tell the story of an attack |

## Key Takeaways

- CloudTrail records EVERYTHING — creation, deletion, even failed attempts
- CloudTrail is useless if nobody reads the logs — Capital One had 4 months of evidence sitting unmonitored
- `errorCode: AccessDenied` events are gold — they show what the attacker TRIED but failed to do
- Attackers often try to disable logging (`StopLogging`, `DeleteTrail`) — SCPs should prevent this
- The first step of incident response is always: pull the CloudTrail logs

## What's Next

Next up: [Lab 07: Organizations & SCPs](../lab-07-organizations-scps/) — learn how multi-account architecture and Service Control Policies create guardrails that even admins can't override.
