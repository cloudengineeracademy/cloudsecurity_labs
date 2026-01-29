#!/bin/bash

# Lab 03: Finding Triage Exercise
# Interactive quiz on categorizing GuardDuty findings

echo ""
echo "=============================================="
echo "  TRIAGE EXERCISE: Categorize the Findings"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCORE=0
TOTAL=6

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

echo "You're the on-call security engineer. GuardDuty has flagged"
echo "these findings. For each one, pick the correct response."
echo ""
echo "----------------------------------------------"

# Question 1: CryptoCurrency finding
ask_question \
    "Q1: GuardDuty finding: CryptoCurrency:EC2/BitcoinTool.B!DNS
    Severity: HIGH (8.0)
    An EC2 instance is querying Bitcoin mining pool domains.
    What's the FIRST thing you do?" \
    "B" \
    "Delete the instance immediately" \
    "Isolate the instance (remove from SG, keep for forensics)" \
    "Ignore it — probably a false positive" \
    "Restart the instance" \
    "Isolate first, then investigate. Deleting destroys forensic evidence. Cryptocurrency mining indicates the instance is compromised — an attacker has code execution."

# Question 2: Recon finding
ask_question \
    "Q2: GuardDuty finding: Recon:EC2/PortProbeUnprotectedPort
    Severity: MEDIUM (5.0)
    External IPs are probing open ports on an EC2 instance.
    What does this finding indicate?" \
    "A" \
    "Someone is scanning your instance for vulnerabilities" \
    "Your instance is attacking other systems" \
    "An IAM credential was compromised" \
    "S3 data is being exfiltrated" \
    "Port probing is reconnaissance — attackers scan for open ports before attempting exploitation. Check which ports are exposed and whether they need to be."

# Question 3: Unauthorized access
ask_question \
    "Q3: GuardDuty finding: UnauthorizedAccess:IAMUser/ConsoleLoginSuccess.B
    Severity: MEDIUM (5.0)
    A console login from an unusual location.
    What's the most likely explanation?" \
    "C" \
    "The user is on vacation and logged in from a hotel" \
    "A bug in GuardDuty" \
    "Stolen credentials used from a different location" \
    "AWS internal testing" \
    "While the user could be traveling, this finding should always be verified. Contact the user to confirm. If they didn't log in, credentials are compromised — rotate immediately."

# Question 4: Severity classification
ask_question \
    "Q4: Which GuardDuty finding type is MOST critical and requires
    immediate incident response?" \
    "D" \
    "Recon:EC2/PortProbeUnprotectedPort (port scanning)" \
    "Policy:S3/AccountBlockPublicAccessDisabled (config change)" \
    "Behavior:EC2/NetworkPortUnusual (unusual port usage)" \
    "Exfiltration:S3/MaliciousIPCaller (data theft from known bad IP)" \
    "Data exfiltration from a known malicious IP is the highest severity — it means data is actively leaving your account to a confirmed threat actor. This requires immediate incident response."

# Question 5: Security Hub integration
ask_question \
    "Q5: Security Hub shows a FAILED check for:
    'CloudTrail should have encryption at rest enabled'
    What standard is this check from?" \
    "B" \
    "PCI DSS" \
    "AWS Foundational Security Best Practices" \
    "SOC 2 Type II" \
    "ISO 27001" \
    "The AWS Foundational Security Best Practices standard includes checks for CloudTrail encryption, among many other controls. It's enabled by default when you activate Security Hub."

# Question 6: Response priority
ask_question \
    "Q6: You have 3 GuardDuty findings. Which do you address FIRST?
    A) Recon:EC2/PortProbeUnprotectedPort — severity 5.0
    B) CryptoCurrency:EC2/BitcoinTool.B — severity 8.0
    C) Policy:S3/AccountBlockPublicAccessDisabled — severity 5.0" \
    "B" \
    "A — Port scanning could lead to exploitation" \
    "B — Crypto mining means the instance is already compromised" \
    "C — S3 public access could expose data" \
    "All three have equal priority" \
    "Severity 8.0 (crypto mining) indicates active compromise. The instance is already owned by an attacker. Port scanning (A) is reconnaissance. S3 policy (C) is a misconfiguration. Address active compromise first."

# Final score
echo ""
echo "=============================================="
echo "  TRIAGE SCORE"
echo "=============================================="
echo ""

PERCENTAGE=$((SCORE * 100 / TOTAL))

if [ $SCORE -eq $TOTAL ]; then
    echo -e "${GREEN}Perfect Score! $SCORE/$TOTAL (100%)${NC}"
    echo ""
    echo "You're ready for on-call duty."
elif [ $SCORE -ge 4 ]; then
    echo -e "${GREEN}Good work! $SCORE/$TOTAL ($PERCENTAGE%)${NC}"
    echo ""
    echo "Strong triage instincts. Review the ones you missed."
elif [ $SCORE -ge 2 ]; then
    echo -e "${YELLOW}Keep practicing. $SCORE/$TOTAL ($PERCENTAGE%)${NC}"
    echo ""
    echo "Review the GuardDuty finding types documentation."
else
    echo -e "${RED}Needs study. $SCORE/$TOTAL ($PERCENTAGE%)${NC}"
    echo ""
    echo "Re-read the Lab 03 README and try again."
fi

echo ""
echo "  Key takeaways:"
echo "    1. Higher severity = address first"
echo "    2. Active compromise > reconnaissance > misconfiguration"
echo "    3. Isolate before investigating (preserve evidence)"
echo "    4. Always verify unusual logins with the actual user"
echo ""
