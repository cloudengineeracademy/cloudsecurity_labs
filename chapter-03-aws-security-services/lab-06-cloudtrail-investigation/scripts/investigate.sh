#!/bin/bash

# Lab 06: Guided Investigation Exercise
# Walk through the suspicious events and piece together the attack

echo ""
echo "=============================================="
echo "  INCIDENT INVESTIGATION: CloudTrail Forensics"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Find evidence file
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVIDENCE_FILE="$SCRIPT_DIR/../evidence/suspicious-events.json"

if [ ! -f "$EVIDENCE_FILE" ]; then
    echo -e "${RED}ERROR: Evidence file not found at $EVIDENCE_FILE${NC}"
    exit 1
fi

EVENT_COUNT=$(python3 -c "import json; print(len(json.load(open('$EVIDENCE_FILE'))))" 2>/dev/null)

echo "A security alert has fired in account 938471625033."
echo "You've been given $EVENT_COUNT CloudTrail events to analyze."
echo ""
echo "Let's walk through them together."
echo ""
read -p "Press Enter to begin the investigation..."

# ============================================================
# Event 1: AssumeRole
# ============================================================
echo ""
echo "=============================================="
echo -e "${CYAN}EVENT 1 of $EVENT_COUNT${NC}"
echo "=============================================="

python3 -c "
import json
events = json.load(open('$EVIDENCE_FILE'))
e = events[0]
print(f\"  Time:      {e['eventTime']}\")
print(f\"  Action:    {e['eventName']}\")
print(f\"  Service:   {e['eventSource']}\")
print(f\"  Source IP: {e['sourceIPAddress']}\")
print(f\"  Identity:  {e['userIdentity']['arn']}\")
print(f\"  Target:    {e['requestParameters']['roleArn']}\")
print(f\"  Session:   {e['requestParameters']['roleSessionName']}\")
print(f\"  Error:     {e.get('errorCode', 'None')}\")
" 2>/dev/null

echo ""
echo -e "${BLUE}ANALYSIS:${NC}"
echo "  The user 'ci-deploy-bot' assumed the 'S3-DataAccess-Role'."
echo "  This is the initial access point. A CI/CD service account"
echo "  is being used to get S3 data access credentials."
echo ""
echo -e "${YELLOW}  RED FLAG: Is this a normal time for CI/CD to run?${NC}"
echo -e "${YELLOW}  RED FLAG: Note the session name — 'maintenance-session'${NC}"
echo -e "${YELLOW}  RED FLAG: Note the source IP — 198.51.100.23${NC}"
echo ""
read -p "Press Enter for the next event..."

# ============================================================
# Event 2: ListBuckets
# ============================================================
echo ""
echo "=============================================="
echo -e "${CYAN}EVENT 2 of $EVENT_COUNT${NC}"
echo "=============================================="

python3 -c "
import json
events = json.load(open('$EVIDENCE_FILE'))
e = events[1]
print(f\"  Time:      {e['eventTime']}\")
print(f\"  Action:    {e['eventName']}\")
print(f\"  Service:   {e['eventSource']}\")
print(f\"  Source IP: {e['sourceIPAddress']}\")
print(f\"  Identity:  {e['userIdentity']['arn']}\")
print(f\"  Error:     {e.get('errorCode', 'None')}\")
" 2>/dev/null

echo ""
echo -e "${BLUE}ANALYSIS:${NC}"
echo "  ListBuckets — the attacker is doing RECONNAISSANCE."
echo "  They're listing every S3 bucket in the account to find targets."
echo ""
echo -e "${YELLOW}  This is exactly what happened in the Capital One breach.${NC}"
echo -e "${YELLOW}  The attacker listed buckets to find where sensitive data lived.${NC}"
echo ""
read -p "Press Enter for the next event..."

# ============================================================
# Event 3: ListObjects
# ============================================================
echo ""
echo "=============================================="
echo -e "${CYAN}EVENT 3 of $EVENT_COUNT${NC}"
echo "=============================================="

python3 -c "
import json
events = json.load(open('$EVIDENCE_FILE'))
e = events[2]
print(f\"  Time:      {e['eventTime']}\")
print(f\"  Action:    {e['eventName']}\")
print(f\"  Service:   {e['eventSource']}\")
print(f\"  Source IP: {e['sourceIPAddress']}\")
print(f\"  Bucket:    {e['requestParameters']['bucketName']}\")
print(f\"  Prefix:    {e['requestParameters']['prefix']}\")
print(f\"  Error:     {e.get('errorCode', 'None')}\")
" 2>/dev/null

echo ""
echo -e "${BLUE}ANALYSIS:${NC}"
echo "  They found the target: 'acme-corp-financial-data'"
echo "  Now they're listing files in the 'reports/2025/' folder."
echo "  This is targeted — they know what they're looking for."
echo ""
read -p "Press Enter for the next events..."

# ============================================================
# Events 4-5: GetObject (Data Exfiltration)
# ============================================================
echo ""
echo "=============================================="
echo -e "${CYAN}EVENTS 4-5 of $EVENT_COUNT — DATA EXFILTRATION${NC}"
echo "=============================================="

python3 -c "
import json
events = json.load(open('$EVIDENCE_FILE'))
for i in [3, 4]:
    e = events[i]
    print(f\"  [{i+1}] Time:   {e['eventTime']}\")
    print(f\"      Action: {e['eventName']}\")
    print(f\"      File:   {e['requestParameters']['key']}\")
    print(f\"      Error:  {e.get('errorCode', 'None')}\")
    print()
" 2>/dev/null

echo -e "${RED}ANALYSIS:${NC}"
echo "  Two files downloaded:"
echo "    1. q4-revenue-projections.xlsx — financial data"
echo "    2. customer-pii-export.csv — CUSTOMER PII"
echo ""
echo -e "${RED}  This is data exfiltration. Customer PII has been stolen.${NC}"
echo ""
read -p "Press Enter for the next events..."

# ============================================================
# Events 6-7: Privilege Escalation
# ============================================================
echo ""
echo "=============================================="
echo -e "${CYAN}EVENTS 6-7 of $EVENT_COUNT — PRIVILEGE ESCALATION${NC}"
echo "=============================================="

python3 -c "
import json
events = json.load(open('$EVIDENCE_FILE'))
for i in [5, 6]:
    e = events[i]
    print(f\"  [{i+1}] Time:   {e['eventTime']}\")
    print(f\"      Action: {e['eventName']}\")
    print(f\"      Target: {e['requestParameters']['userName']}\")
    print(f\"      Error:  {e.get('errorCode', 'None')}\")
    print()
" 2>/dev/null

echo -e "${RED}ANALYSIS:${NC}"
echo "  The attacker created a new IAM user 'backup-admin'"
echo "  and generated access keys for it."
echo ""
echo "  This is PERSISTENCE. Even if you revoke the original"
echo "  credentials, the attacker can come back through"
echo "  the 'backup-admin' user."
echo ""
echo -e "${RED}  Both succeeded — the role had IAM permissions!${NC}"
echo -e "${YELLOW}  Lesson: S3-DataAccess-Role should NOT have iam:CreateUser${NC}"
echo ""
read -p "Press Enter for the final events..."

# ============================================================
# Events 8-9: Covering Tracks
# ============================================================
echo ""
echo "=============================================="
echo -e "${CYAN}EVENTS 8-9 of $EVENT_COUNT — COVERING TRACKS${NC}"
echo "=============================================="

python3 -c "
import json
events = json.load(open('$EVIDENCE_FILE'))
for i in [7, 8]:
    e = events[i]
    print(f\"  [{i+1}] Time:   {e['eventTime']}\")
    print(f\"      Action: {e['eventName']}\")
    print(f\"      Target: {e['requestParameters']['name']}\")
    print(f\"      Error:  {e.get('errorCode', 'AccessDeniedException')}\")
    if e.get('errorMessage'):
        # Wrap long error message
        msg = e['errorMessage']
        print(f\"      Reason: {msg[:80]}\")
        if len(msg) > 80:
            print(f\"              {msg[80:]}\")
    print()
" 2>/dev/null

echo -e "${GREEN}ANALYSIS:${NC}"
echo "  The attacker tried to STOP LOGGING and DELETE the trail."
echo "  Both FAILED."
echo ""
echo -e "${GREEN}  Why? An SCP (Service Control Policy) blocked it!${NC}"
echo ""
echo "  The error message says: 'explicit deny in a service control policy'"
echo "  This is AWS Organizations protecting the trail."
echo ""
echo "  Without that SCP, the attacker would have deleted all evidence."
echo ""

# ============================================================
# Summary
# ============================================================
echo "=============================================="
echo -e "${BLUE}INVESTIGATION SUMMARY${NC}"
echo "=============================================="
echo ""
echo "  TIMELINE (7 minutes total):"
echo ""
echo "  14:05:00  AssumeRole          → Got S3 access credentials"
echo "  14:06:12  ListBuckets         → Found target buckets"
echo "  14:07:45  ListObjects         → Browsed financial data folder"
echo "  14:08:30  GetObject           → Stole revenue projections"
echo "  14:09:15  GetObject           → Stole customer PII"
echo "  14:10:02  CreateUser          → Created backdoor account"
echo "  14:10:45  CreateAccessKey     → Created backdoor credentials"
echo "  14:11:30  StopLogging         → DENIED by SCP"
echo "  14:12:00  DeleteTrail         → DENIED by SCP"
echo ""
echo "  ATTACKER: Used ci-deploy-bot credentials from 198.51.100.23"
echo "  IMPACT:   Customer PII and financial data exfiltrated"
echo "  SAVED BY: SCP preventing CloudTrail tampering"
echo ""
echo -e "${YELLOW}  EARLIEST DETECTION POINT:${NC}"
echo "  The AssumeRole at 14:05 from an unusual IP."
echo "  If GuardDuty was watching, the unusual source IP"
echo "  would have triggered a finding immediately."
echo ""
echo -e "${YELLOW}  IMMEDIATE ACTIONS NEEDED:${NC}"
echo "  1. Revoke the assumed role session"
echo "  2. Delete the 'backup-admin' user and its access key"
echo "  3. Rotate ci-deploy-bot credentials"
echo "  4. Scope the S3 data exposure"
echo "  5. Remove IAM permissions from the S3-DataAccess-Role"
echo ""
