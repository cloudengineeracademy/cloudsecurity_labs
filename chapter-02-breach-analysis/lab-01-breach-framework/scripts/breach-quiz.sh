#!/bin/bash

# Lab 01: Breach Analysis Quiz
# Test your knowledge of the three breaches

echo ""
echo "=============================================="
echo "  BREACH ANALYSIS QUIZ"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Score tracking
SCORE=0
TOTAL=10

# Function to ask a question
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

echo "Test your knowledge of the Capital One, Uber, and LastPass breaches."
echo "Enter A, B, C, or D for each question."
echo ""
echo "----------------------------------------------"

# Question 1
ask_question \
    "Q1: What vulnerability allowed the Capital One attacker to reach the metadata service?" \
    "B" \
    "SQL Injection" \
    "Server-Side Request Forgery (SSRF)" \
    "Cross-Site Scripting (XSS)" \
    "Buffer Overflow" \
    "SSRF allowed the attacker to make the server request internal URLs, including the metadata service at 169.254.169.254"

# Question 2
ask_question \
    "Q2: What AWS feature could have prevented the Capital One breach?" \
    "C" \
    "Security Groups" \
    "VPC Flow Logs" \
    "IMDSv2 (Instance Metadata Service version 2)" \
    "AWS WAF" \
    "IMDSv2 requires a session token obtained via a PUT request, which SSRF attacks typically can't perform"

# Question 3
ask_question \
    "Q3: How many customer records were exposed in the Capital One breach?" \
    "D" \
    "1 million" \
    "10 million" \
    "50 million" \
    "106 million" \
    "The breach exposed personal information of 106 million Capital One customers in the US and Canada"

# Question 4
ask_question \
    "Q4: What technique did the Uber attacker use to bypass MFA?" \
    "A" \
    "MFA fatigue (push notification spam)" \
    "SIM swapping" \
    "Session hijacking" \
    "Brute force" \
    "MFA fatigue involves spamming push notifications until the user accepts, combined with social engineering"

# Question 5
ask_question \
    "Q5: Where did the Uber attacker find privileged credentials?" \
    "B" \
    "In an AWS S3 bucket" \
    "Hardcoded in a PowerShell script" \
    "In the company's password manager" \
    "In plain text emails" \
    "The attacker found Thycotic PAM credentials hardcoded in a PowerShell script on a network share"

# Question 6
ask_question \
    "Q6: What type of system did the Uber attacker gain access to that provided credentials for everything?" \
    "C" \
    "Active Directory" \
    "AWS IAM" \
    "Privileged Access Management (PAM)" \
    "Single Sign-On (SSO)" \
    "The PAM system (Thycotic) stored credentials for AWS, Google Workspace, Slack, and other critical systems"

# Question 7
ask_question \
    "Q7: How was the LastPass DevOps engineer initially compromised?" \
    "D" \
    "Phishing email" \
    "Malicious browser extension" \
    "Public Wi-Fi attack" \
    "Vulnerable software on personal computer (Plex)" \
    "A vulnerability in Plex media software on the engineer's home computer allowed initial access and keylogger installation"

# Question 8
ask_question \
    "Q8: What type of LastPass data was NOT encrypted in the stolen backups?" \
    "A" \
    "Website URLs and usernames (metadata)" \
    "Master passwords" \
    "Website passwords" \
    "Credit card numbers" \
    "URLs and usernames were stored unencrypted, revealing which sites users have accounts on"

# Question 9
ask_question \
    "Q9: How many DevOps engineers at LastPass had access to the critical infrastructure?" \
    "B" \
    "2" \
    "4" \
    "10" \
    "25" \
    "Only 4 engineers had this access, making them high-value targets for attackers"

# Question 10
ask_question \
    "Q10: Which of these is a detection opportunity common to ALL THREE breaches?" \
    "C" \
    "Failed SSH attempts" \
    "Malware signatures" \
    "Unusual access patterns from legitimate credentials" \
    "Network port scanning" \
    "All three breaches involved legitimate credentials used in abnormal ways - off-hours access, first-time system access, or unusual data transfers"

# Final score
echo ""
echo "=============================================="
echo "  FINAL SCORE"
echo "=============================================="
echo ""

PERCENTAGE=$((SCORE * 100 / TOTAL))

if [ $SCORE -eq $TOTAL ]; then
    echo -e "${GREEN}Perfect Score! $SCORE/$TOTAL (100%)${NC}"
    echo ""
    echo "You've mastered the breach analysis framework."
    echo "Ready for Lab 02: SSRF and Metadata Attacks!"
elif [ $SCORE -ge 8 ]; then
    echo -e "${GREEN}Excellent! $SCORE/$TOTAL ($PERCENTAGE%)${NC}"
    echo ""
    echo "Strong understanding. Review the questions you missed,"
    echo "then proceed to Lab 02."
elif [ $SCORE -ge 6 ]; then
    echo -e "${YELLOW}Good effort! $SCORE/$TOTAL ($PERCENTAGE%)${NC}"
    echo ""
    echo "Review the case studies for the questions you missed:"
    echo "  - case-studies/capital-one.md"
    echo "  - case-studies/uber.md"
    echo "  - case-studies/lastpass.md"
elif [ $SCORE -ge 4 ]; then
    echo -e "${YELLOW}Keep studying! $SCORE/$TOTAL ($PERCENTAGE%)${NC}"
    echo ""
    echo "Re-read the case studies carefully and try again."
else
    echo -e "${RED}Needs work. $SCORE/$TOTAL ($PERCENTAGE%)${NC}"
    echo ""
    echo "Start with the Lab 01 README and work through each case study."
fi

echo ""
echo "=============================================="
