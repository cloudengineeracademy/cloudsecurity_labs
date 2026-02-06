#!/bin/bash

# Lab 06: Investigation Verification Quiz
# Tests understanding of the breach evidence

echo ""
echo "=============================================="
echo "  INVESTIGATION QUIZ: Test Your Analysis"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCORE=0
TOTAL=8

ask_question() {
    local question="$1"
    local correct="$2"
    local option_a="$3"
    local option_b="$4"
    local option_c="$5"
    local option_d="$6"
    local explanation="$7"

    echo ""
    echo -e "${BLUE}$question${NC}"
    echo ""
    echo "  A) $option_a"
    echo "  B) $option_b"
    echo "  C) $option_c"
    echo "  D) $option_d"
    echo ""

    read -p "Your answer (A/B/C/D): " answer
    answer=$(echo "$answer" | tr '[:lower:]' '[:upper:]')

    if [ "$answer" = "$correct" ]; then
        echo -e "${GREEN}Correct!${NC}"
        ((SCORE++))
    else
        echo -e "${RED}Incorrect. The answer is $correct${NC}"
    fi
    echo -e "${YELLOW}$explanation${NC}"
    echo ""
    echo "----------------------------------------------"
}

echo "Based on the evidence in evidence/suspicious-events.json,"
echo "answer these questions about the breach."
echo ""
echo "----------------------------------------------"

# Q1: Initial access
ask_question \
    "Q1: What IAM identity did the attacker initially use?" \
    "C" \
    "root account" \
    "S3-DataAccess-Role" \
    "ci-deploy-bot (IAM user)" \
    "backup-admin" \
    "The first event shows IAM user 'ci-deploy-bot' calling AssumeRole. This service account's credentials were compromised — likely leaked or stolen."

# Q2: What role was assumed
ask_question \
    "Q2: What role did the attacker assume for the attack?" \
    "B" \
    "DevOps role" \
    "S3-DataAccess-Role" \
    "OrganizationAdmin" \
    "SecurityBreakGlass" \
    "The attacker assumed S3-DataAccess-Role, which gave them access to S3 data AND (mistakenly) IAM permissions. This role was over-permissioned."

# Q3: Source IP
ask_question \
    "Q3: What was the attacker's source IP address?" \
    "A" \
    "198.51.100.23" \
    "203.0.113.42" \
    "10.0.1.50" \
    "172.16.0.1" \
    "198.51.100.23 appeared consistently across all 9 events. This is the attacker's IP. In a real investigation, you'd geolocate this and check it against known employee locations."

# Q4: Data stolen
ask_question \
    "Q4: What sensitive data was exfiltrated?" \
    "D" \
    "Only financial projections" \
    "Only customer PII" \
    "Database backups" \
    "Financial projections AND customer PII" \
    "Two GetObject events: q4-revenue-projections.xlsx (financial data) and customer-pii-export.csv (PII). Both were downloaded from the acme-corp-financial-data bucket."

# Q5: Persistence
ask_question \
    "Q5: How did the attacker establish persistence (a way back in)?" \
    "B" \
    "Installed a backdoor on an EC2 instance" \
    "Created IAM user 'backup-admin' with access keys" \
    "Modified the S3 bucket policy" \
    "Added their SSH key to an EC2 instance" \
    "CreateUser + CreateAccessKey: the attacker created 'backup-admin' with active access keys. Even after revoking the original credentials, this backdoor user would still work."

# Q6: What was blocked
ask_question \
    "Q6: What stopped the attacker from destroying the evidence?" \
    "C" \
    "IAM policy denied the action" \
    "MFA was required" \
    "A Service Control Policy (SCP) blocked CloudTrail changes" \
    "The S3 bucket had versioning enabled" \
    "The error message explicitly says 'explicit deny in a service control policy'. The SCP prevented StopLogging and DeleteTrail. Without this SCP, the attacker would have deleted all evidence."

# Q7: Duration
ask_question \
    "Q7: How long did the entire attack take?" \
    "A" \
    "7 minutes (14:05 to 14:12)" \
    "About an hour" \
    "15 minutes" \
    "Several hours" \
    "First event: 14:05:00 (AssumeRole). Last event: 14:12:00 (DeleteTrail denied). Total: 7 minutes. Attacks are fast. If you're not watching in real-time, you'll miss them."

# Q8: Earliest detection
ask_question \
    "Q8: What would have been the EARLIEST way to detect this attack?" \
    "B" \
    "The CreateUser event at 14:10" \
    "GuardDuty alerting on the unusual source IP at 14:05" \
    "The StopLogging attempt at 14:11" \
    "A weekly log review would catch it" \
    "GuardDuty monitors CloudTrail events in real-time. An AssumeRole from an unusual IP would trigger a finding within minutes. By the time you notice CreateUser, the data is already stolen."

# Final score
echo ""
echo "=============================================="
echo "  INVESTIGATION SCORE"
echo "=============================================="
echo ""

PERCENTAGE=$((SCORE * 100 / TOTAL))

if [ $SCORE -eq $TOTAL ]; then
    echo -e "${GREEN}Perfect Score! $SCORE/$TOTAL (100%)${NC}"
    echo ""
    echo "  You're ready for incident response."
elif [ $SCORE -ge 6 ]; then
    echo -e "${GREEN}Strong work! $SCORE/$TOTAL ($PERCENTAGE%)${NC}"
    echo ""
    echo "  Good forensic instincts. Review the ones you missed."
elif [ $SCORE -ge 4 ]; then
    echo -e "${YELLOW}Getting there. $SCORE/$TOTAL ($PERCENTAGE%)${NC}"
    echo ""
    echo "  Re-read the evidence file and try the guided investigation."
else
    echo -e "${RED}Needs study. $SCORE/$TOTAL ($PERCENTAGE%)${NC}"
    echo ""
    echo "  Run: bash scripts/investigate.sh for a guided walkthrough."
fi

echo ""
echo "  Key lessons from this breach:"
echo ""
echo "    1. Attacks happen FAST — 7 minutes start to finish"
echo "    2. Service accounts (ci-deploy-bot) are high-value targets"
echo "    3. Over-permissioned roles enable escalation"
echo "       (S3 role should NOT have iam:CreateUser)"
echo "    4. SCPs saved the evidence — without them, logs would be gone"
echo "    5. Real-time detection (GuardDuty) beats log review"
echo ""
