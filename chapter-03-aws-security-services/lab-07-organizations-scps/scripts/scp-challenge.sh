#!/bin/bash

# Lab 07: SCP Challenge
# Interactive quiz on Service Control Policy scenarios

echo ""
echo "=============================================="
echo "  SCP CHALLENGE: Can They Do It?"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCORE=0
TOTAL=10

ask_question() {
    local question="$1"
    local correct="$2"
    local option_a="$3"
    local option_b="$4"
    local option_c="$5"
    local explanation="$6"

    echo ""
    echo -e "${BLUE}$question${NC}"
    echo ""
    echo "  A) $option_a"
    echo "  B) $option_b"
    echo "  C) $option_c"
    echo ""

    read -p "Your answer (A/B/C): " answer
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

echo "For each scenario, determine if the action is ALLOWED or DENIED."
echo ""
echo "Remember: Actual Permission = IAM Allows AND SCP Allows"
echo "          If either says NO, the action is DENIED."
echo ""
echo "----------------------------------------------"

# Q1: Basic SCP deny
ask_question \
    "Q1: User has IAM policy: Allow ec2:*
    SCP on their OU: Deny all actions outside eu-west-1
    Action: Launch EC2 in us-east-1" \
    "B" \
    "ALLOWED — IAM grants ec2:*" \
    "DENIED — SCP blocks non-eu-west-1 regions" \
    "DEPENDS — on the time of day" \
    "IAM says yes, SCP says no. SCP always wins on deny. The user cannot use us-east-1 regardless of their IAM permissions."

# Q2: Both allow
ask_question \
    "Q2: User has IAM policy: Allow s3:PutObject
    SCP on their OU: Deny all actions outside eu-west-1
    Action: Upload file to S3 in eu-west-1" \
    "A" \
    "ALLOWED — IAM grants it, SCP allows the region" \
    "DENIED — SCP blocks S3 actions" \
    "DENIED — SCP only allows EC2" \
    "IAM says yes (s3:PutObject). SCP says yes (eu-west-1 is approved). Both allow it, so the action succeeds."

# Q3: IAM denies
ask_question \
    "Q3: User has IAM policy: Allow ec2:* only
    SCP on their OU: FullAWSAccess (allow everything)
    Action: Create an S3 bucket" \
    "C" \
    "ALLOWED — SCP allows everything" \
    "ALLOWED — FullAWSAccess overrides IAM" \
    "DENIED — IAM doesn't grant S3 permissions" \
    "SCP says yes, but IAM says no. Both must say yes. SCPs set the ceiling but IAM must still grant the permission. FullAWSAccess doesn't grant permissions — it just doesn't block them."

# Q4: Management account
ask_question \
    "Q4: SCP on Root OU: Deny all actions outside eu-west-1
    User is in the MANAGEMENT account
    Action: Launch EC2 in ap-southeast-1" \
    "B" \
    "DENIED — SCP applies to all accounts" \
    "ALLOWED — SCPs never affect the management account" \
    "DENIED — Root OU applies to everything" \
    "SCPs NEVER apply to the management account. This is by design and cannot be changed. It's the primary reason you should never run workloads in the management account."

# Q5: Multiple SCPs
ask_question \
    "Q5: User has IAM policy: Allow s3:*
    SCP 1: Deny outside eu-west-1
    SCP 2: Deny s3:DeleteBucket
    Action: Delete an S3 bucket in eu-west-1" \
    "C" \
    "ALLOWED — eu-west-1 is approved and IAM allows s3:*" \
    "DEPENDS — on which SCP was created first" \
    "DENIED — SCP 2 blocks s3:DeleteBucket" \
    "Both SCPs must allow the action. SCP 1 allows (correct region), but SCP 2 explicitly denies s3:DeleteBucket. Any single deny wins, regardless of other allows."

# Q6: CloudTrail protection
ask_question \
    "Q6: Admin user has IAM policy: Allow * (full admin)
    SCP: Deny cloudtrail:StopLogging, cloudtrail:DeleteTrail
    Action: Delete the CloudTrail trail" \
    "A" \
    "DENIED — SCP deny overrides even full admin" \
    "ALLOWED — full admin overrides SCP" \
    "ALLOWED — only root can be affected by SCPs" \
    "SCPs override EVERYONE in member accounts, including full admins and even the root user of that member account. This is the whole point of SCPs — guardrails that nobody can bypass."

# Q7: Escape hatch role
ask_question \
    "Q7: SCP: Deny all outside eu-west-1 UNLESS caller is OrganizationAdmin role
    User assumes the OrganizationAdmin role
    Action: Launch EC2 in us-west-2" \
    "A" \
    "ALLOWED — the role is in the SCP exception" \
    "DENIED — SCP denies all regions except eu-west-1" \
    "DENIED — exceptions don't work in SCPs" \
    "The SCP has a Condition that exempts the OrganizationAdmin role. This is the 'escape hatch' pattern — always include one in case you need emergency access."

# Q8: Root user in member account
ask_question \
    "Q8: SCP: Deny iam:CreateUser
    The ROOT user of a MEMBER account tries to create an IAM user
    Is it allowed?" \
    "C" \
    "ALLOWED — root can do anything" \
    "ALLOWED — SCPs only affect IAM users" \
    "DENIED — SCPs apply to root in member accounts" \
    "Root in member accounts IS affected by SCPs. Only the management account's root is exempt. This is why SCPs are so powerful — even root can't bypass them in member accounts."

# Q9: SCP inheritance
ask_question \
    "Q9: SCP on Production OU: Deny outside eu-west-1
    Account 'prod-app-a' is in the Production OU
    No additional SCPs on the account itself
    Action from prod-app-a: Launch EC2 in us-east-1" \
    "B" \
    "ALLOWED — no SCP directly on the account" \
    "DENIED — account inherits OU's SCP" \
    "DEPENDS — on the account's IAM policies" \
    "SCPs are inherited. Accounts inherit all SCPs from their parent OUs. The account doesn't need its own SCP — the Production OU's SCP automatically applies."

# Q10: SCP direction
ask_question \
    "Q10: Production OU has strict SCPs
    Sandbox OU has FullAWSAccess (no restrictions)
    Does the Production OU's SCP affect the Sandbox OU?" \
    "A" \
    "NO — SCPs flow DOWN, not sideways" \
    "YES — SCPs flow across all OUs" \
    "YES — if they share a parent" \
    "SCPs flow down the hierarchy, never sideways. Production OU's SCPs only affect accounts IN the Production OU. The Sandbox OU is a separate branch and completely unaffected."

# Final score
echo ""
echo "=============================================="
echo "  SCP CHALLENGE SCORE"
echo "=============================================="
echo ""

PERCENTAGE=$((SCORE * 100 / TOTAL))

if [ $SCORE -eq $TOTAL ]; then
    echo -e "${GREEN}Perfect Score! $SCORE/$TOTAL (100%)${NC}"
    echo ""
    echo "  You understand SCPs deeply. Ready to design guardrails."
elif [ $SCORE -ge 8 ]; then
    echo -e "${GREEN}Excellent! $SCORE/$TOTAL ($PERCENTAGE%)${NC}"
    echo ""
    echo "  Strong understanding. Review the ones you missed."
elif [ $SCORE -ge 6 ]; then
    echo -e "${YELLOW}Good progress. $SCORE/$TOTAL ($PERCENTAGE%)${NC}"
    echo ""
    echo "  Re-read the SCP scenarios in the README."
elif [ $SCORE -ge 4 ]; then
    echo -e "${YELLOW}Keep studying. $SCORE/$TOTAL ($PERCENTAGE%)${NC}"
    echo ""
    echo "  Focus on the IAM + SCP interaction rule."
else
    echo -e "${RED}Needs work. $SCORE/$TOTAL ($PERCENTAGE%)${NC}"
    echo ""
    echo "  Start with Part 2 of the README — the permission scenarios."
fi

echo ""
echo "  The golden rules of SCPs:"
echo ""
echo "    1. SCP deny ALWAYS wins (even over full admin)"
echo "    2. Management account is NEVER affected by SCPs"
echo "    3. SCPs flow DOWN the hierarchy, never sideways"
echo "    4. Both IAM AND SCP must allow = actual permission"
echo "    5. Root in MEMBER accounts IS affected by SCPs"
echo "    6. Always include an escape hatch role"
echo ""
