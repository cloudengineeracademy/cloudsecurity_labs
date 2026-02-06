#!/bin/bash

# Lab 07: SCP Verification
# Validates the student's custom SCP policy

echo ""
echo "=============================================="
echo "  SCP VERIFICATION: Check Your Policy"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
POLICY_FILE="$SCRIPT_DIR/../policies/my-protection-scp.json"
SCORE=0
TOTAL=6

check() {
    local description="$1"
    local passed="$2"

    if [ "$passed" = "true" ]; then
        echo -e "  ${GREEN}PASS${NC}  $description"
        ((SCORE++))
    else
        echo -e "  ${RED}FAIL${NC}  $description"
    fi
}

# Check if policy file exists
if [ ! -f "$POLICY_FILE" ]; then
    echo -e "${RED}Policy file not found: policies/my-protection-scp.json${NC}"
    echo ""
    echo "Create your SCP as described in Part 4 of the README."
    echo "Save it to: policies/my-protection-scp.json"
    exit 1
fi

echo -e "${BLUE}Checking: policies/my-protection-scp.json${NC}"
echo ""

# Check 1: Valid JSON
VALID_JSON=$(python3 -c "import json; json.load(open('$POLICY_FILE')); print('true')" 2>/dev/null || echo "false")
check "Valid JSON format" "$VALID_JSON"

if [ "$VALID_JSON" != "true" ]; then
    echo ""
    echo -e "${RED}Fix the JSON syntax before continuing.${NC}"
    echo "Tip: Run: python3 -m json.tool $POLICY_FILE"
    exit 1
fi

# Check 2: Has Effect: Deny
HAS_DENY=$(python3 -c "
import json
policy = json.load(open('$POLICY_FILE'))
stmts = policy.get('Statement', [])
has_deny = any(s.get('Effect') == 'Deny' for s in stmts)
print('true' if has_deny else 'false')
" 2>/dev/null)
check "Uses Effect: Deny" "$HAS_DENY"

# Check 3: Denies KMS key deletion
HAS_KMS=$(python3 -c "
import json
policy = json.load(open('$POLICY_FILE'))
stmts = policy.get('Statement', [])
actions = []
for s in stmts:
    a = s.get('Action', [])
    if isinstance(a, str):
        a = [a]
    actions.extend([x.lower() for x in a])
has_schedule = any('kms:schedulekeydeletion' in a for a in actions)
has_disable = any('kms:disablekey' in a for a in actions)
print('true' if has_schedule and has_disable else 'false')
" 2>/dev/null)
check "Denies kms:ScheduleKeyDeletion and kms:DisableKey" "$HAS_KMS"

# Check 4: Denies GuardDuty changes
HAS_GD=$(python3 -c "
import json
policy = json.load(open('$POLICY_FILE'))
stmts = policy.get('Statement', [])
actions = []
for s in stmts:
    a = s.get('Action', [])
    if isinstance(a, str):
        a = [a]
    actions.extend([x.lower() for x in a])
has_delete = any('guardduty:deletedetector' in a for a in actions)
has_stop = any('guardduty:stopmonitoringmembers' in a for a in actions)
has_disassociate = any('guardduty:disassociatefrommasteraccount' in a for a in actions)
print('true' if has_delete and has_stop and has_disassociate else 'false')
" 2>/dev/null)
check "Denies GuardDuty actions (DeleteDetector, StopMonitoringMembers, DisassociateFromMasterAccount)" "$HAS_GD"

# Check 5: Has escape hatch condition
HAS_ESCAPE=$(python3 -c "
import json
policy = json.load(open('$POLICY_FILE'))
stmts = policy.get('Statement', [])
found = False
for s in stmts:
    cond = s.get('Condition', {})
    for key, val in cond.items():
        if 'ArnNotLike' in key or key == 'ArnNotLike':
            val_str = json.dumps(val).lower()
            if 'securitybreakglass' in val_str:
                found = True
        for subkey, subval in (val.items() if isinstance(val, dict) else []):
            subval_str = json.dumps(subval).lower() if not isinstance(subval, str) else subval.lower()
            if 'securitybreakglass' in subval_str:
                found = True
print('true' if found else 'false')
" 2>/dev/null)
check "Includes SecurityBreakGlass escape hatch" "$HAS_ESCAPE"

# Check 6: Has Version field
HAS_VERSION=$(python3 -c "
import json
policy = json.load(open('$POLICY_FILE'))
print('true' if policy.get('Version') == '2012-10-17' else 'false')
" 2>/dev/null)
check "Has correct Version: 2012-10-17" "$HAS_VERSION"

# Results
echo ""
echo "=============================================="
echo -e "${BLUE}VERIFICATION RESULTS${NC}"
echo "=============================================="
echo ""

PERCENTAGE=$((SCORE * 100 / TOTAL))

if [ $SCORE -eq $TOTAL ]; then
    echo -e "${GREEN}All checks passed! $SCORE/$TOTAL${NC}"
    echo ""
    echo "  Your SCP is well-structured and covers the requirements."
    echo "  It protects KMS keys and GuardDuty while maintaining"
    echo "  an escape hatch for emergencies."
elif [ $SCORE -ge 4 ]; then
    echo -e "${YELLOW}Almost there. $SCORE/$TOTAL ($PERCENTAGE%)${NC}"
    echo ""
    echo "  Check the failed items above and update your policy."
else
    echo -e "${RED}Needs work. $SCORE/$TOTAL ($PERCENTAGE%)${NC}"
    echo ""
    echo "  Review the example policies in the policies/ directory"
    echo "  and follow the same pattern."
fi

echo ""
echo "  Your policy:"
echo ""
python3 -m json.tool "$POLICY_FILE" 2>/dev/null
echo ""
