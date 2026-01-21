#!/bin/bash

# Cloud Security Assessment - Report Checker
# Validates that an assessment report meets quality standards

echo ""
echo "=============================================="
echo "  ASSESSMENT REPORT CHECKER"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if file provided
REPORT_FILE="${1:-my-assessment-report.md}"

if [ ! -f "$REPORT_FILE" ]; then
    echo -e "${RED}ERROR: Report file not found: $REPORT_FILE${NC}"
    echo ""
    echo "Usage: $0 [report-file.md]"
    echo ""
    echo "If you haven't created a report yet, start with:"
    echo "  cp templates/assessment-report-template.md my-assessment-report.md"
    exit 1
fi

echo "Checking report: $REPORT_FILE"
echo ""

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Function to check for section
check_section() {
    local section="$1"
    local pattern="$2"
    local required="${3:-true}"

    if grep -qi "$pattern" "$REPORT_FILE"; then
        echo -e "${GREEN}[PASS]${NC} $section"
        ((PASSED++))
        return 0
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}[FAIL]${NC} $section - Missing"
            ((FAILED++))
        else
            echo -e "${YELLOW}[WARN]${NC} $section - Optional but recommended"
            ((WARNINGS++))
        fi
        return 1
    fi
}

echo "----------------------------------------------"
echo -e "${BLUE}Report Structure${NC}"
echo "----------------------------------------------"
echo ""

check_section "Executive Summary" "executive summary"
check_section "Scope section" "scope\|in scope"
check_section "Findings section" "findings"
check_section "Recommendations section" "recommendation"

echo ""
echo "----------------------------------------------"
echo -e "${BLUE}Finding Quality${NC}"
echo "----------------------------------------------"
echo ""

# Count findings
FINDING_COUNT=$(grep -ci "### finding" "$REPORT_FILE" || echo "0")
echo "Findings documented: $FINDING_COUNT"

if [ "$FINDING_COUNT" -ge 3 ]; then
    echo -e "${GREEN}[PASS]${NC} At least 3 findings documented"
    ((PASSED++))
else
    echo -e "${RED}[FAIL]${NC} Need at least 3 findings"
    ((FAILED++))
fi

check_section "Severity ratings" "severity.*critical\|severity.*high\|critical\|high"
check_section "Evidence included" "evidence:\|command output"
check_section "Recommendations for findings" "recommendation:\|remediation"

echo ""
echo "----------------------------------------------"
echo -e "${BLUE}Breach Analysis${NC}"
echo "----------------------------------------------"
echo ""

check_section "Capital One reference" "capital one"
check_section "Uber reference" "uber" "false"
check_section "LastPass reference" "lastpass" "false"
check_section "Breach pattern mapping" "breach parallel\|similar.*breach\|pattern"

echo ""
echo "----------------------------------------------"
echo -e "${BLUE}Content Quality${NC}"
echo "----------------------------------------------"
echo ""

# Check word count
WORD_COUNT=$(wc -w < "$REPORT_FILE")
echo "Word count: $WORD_COUNT"

if [ "$WORD_COUNT" -ge 750 ]; then
    echo -e "${GREEN}[PASS]${NC} Sufficient detail ($WORD_COUNT words)"
    ((PASSED++))
elif [ "$WORD_COUNT" -ge 500 ]; then
    echo -e "${YELLOW}[WARN]${NC} Could use more detail ($WORD_COUNT words)"
    ((WARNINGS++))
else
    echo -e "${RED}[FAIL]${NC} Report too brief ($WORD_COUNT words)"
    ((FAILED++))
fi

# Check for placeholders
if grep -qi "\[your\|\[insert\|\[describe\|\[list\|YYYY\|EXAMPLE" "$REPORT_FILE"; then
    echo -e "${YELLOW}[WARN]${NC} Contains unfilled placeholders"
    ((WARNINGS++))
else
    echo -e "${GREEN}[PASS]${NC} No obvious placeholders"
    ((PASSED++))
fi

# Check for AWS commands/evidence
if grep -q "aws " "$REPORT_FILE"; then
    echo -e "${GREEN}[PASS]${NC} Contains AWS CLI evidence"
    ((PASSED++))
else
    echo -e "${YELLOW}[WARN]${NC} Consider adding AWS CLI command outputs"
    ((WARNINGS++))
fi

echo ""

# Calculate score
echo "=============================================="
echo "  ASSESSMENT SCORE"
echo "=============================================="
echo ""

# Scoring
STRUCTURE_SCORE=$((PASSED * 5))
MAX_SCORE=$(( (PASSED + FAILED + WARNINGS) * 5 ))

if [ $MAX_SCORE -gt 0 ]; then
    PERCENTAGE=$((STRUCTURE_SCORE * 100 / MAX_SCORE))
else
    PERCENTAGE=0
fi

echo -e "  ${GREEN}Passed:   $PASSED${NC}"
echo -e "  ${RED}Failed:   $FAILED${NC}"
echo -e "  ${YELLOW}Warnings: $WARNINGS${NC}"
echo ""

if [ $FAILED -eq 0 ] && [ $WARNINGS -le 2 ]; then
    echo -e "${GREEN}Excellent! Your assessment report is complete.${NC}"
    RATING="Excellent"
elif [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}Good! Consider addressing the warnings.${NC}"
    RATING="Good"
elif [ $FAILED -le 2 ]; then
    echo -e "${YELLOW}Satisfactory. Fix the failed items before submission.${NC}"
    RATING="Satisfactory"
else
    echo -e "${RED}Needs Work. Review the assessment guidelines.${NC}"
    RATING="Needs Work"
fi

echo ""
echo "Rating: $RATING"
echo ""

# Scoring rubric reminder
echo "----------------------------------------------"
echo "Scoring Rubric Reminder:"
echo "----------------------------------------------"
echo ""
echo "  Findings Quality:     40 points"
echo "  Breach Analysis:      20 points"
echo "  Report Quality:       25 points"
echo "  Remediation Runbook:  15 points"
echo "  ─────────────────────────────"
echo "  Total:               100 points"
echo ""

exit $FAILED
