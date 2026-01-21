#!/bin/bash

# Lab 05: Post-Mortem Report Checklist
# Verifies that a post-mortem report contains all required sections

echo ""
echo "=============================================="
echo "  POST-MORTEM REPORT CHECKLIST"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if file provided
REPORT_FILE="${1:-my-postmortem.md}"

if [ ! -f "$REPORT_FILE" ]; then
    echo -e "${RED}ERROR: Report file not found: $REPORT_FILE${NC}"
    echo ""
    echo "Usage: $0 [report-file.md]"
    echo ""
    echo "If you haven't created a report yet, start with:"
    echo "  cp templates/postmortem-template.md my-postmortem.md"
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
            echo -e "${RED}[FAIL]${NC} $section - Missing or incomplete"
            ((FAILED++))
        else
            echo -e "${YELLOW}[WARN]${NC} $section - Optional but recommended"
            ((WARNINGS++))
        fi
        return 1
    fi
}

# Function to check for content (not just header)
check_content() {
    local section="$1"
    local pattern="$2"
    local min_lines="$3"

    # Find the section and count non-empty lines after it
    local content_lines=$(awk "/$pattern/,/^## /{print}" "$REPORT_FILE" | grep -v "^$" | grep -v "^#" | wc -l)

    if [ "$content_lines" -ge "$min_lines" ]; then
        echo -e "${GREEN}[PASS]${NC} $section has content ($content_lines lines)"
        ((PASSED++))
        return 0
    else
        echo -e "${YELLOW}[WARN]${NC} $section may need more detail ($content_lines lines found)"
        ((WARNINGS++))
        return 1
    fi
}

echo "----------------------------------------------"
echo -e "${BLUE}Structure Checks${NC}"
echo "----------------------------------------------"
echo ""

# Check required sections
check_section "Executive Summary" "executive summary\|## 1\."
check_section "Incident Timeline" "timeline\|## 2\."
check_section "Root Cause Analysis" "root cause\|## 3\."
check_section "Impact Assessment" "impact\|what did they take"
check_section "Detection Analysis" "detection\|when could we have detected"
check_section "Recommendations" "recommendation\|## 5\.\|## 7\."

echo ""
echo "----------------------------------------------"
echo -e "${BLUE}5-Question Framework${NC}"
echo "----------------------------------------------"
echo ""

check_section "Q1: How did they get in?" "how did they get in\|initial access"
check_section "Q2: What did they find?" "what did they find\|discovery"
check_section "Q3: How did they move?" "how did they move\|lateral movement"
check_section "Q4: What did they take?" "what did they take\|impact"
check_section "Q5: Detection opportunities" "when could we have detected\|detection gap"

echo ""
echo "----------------------------------------------"
echo -e "${BLUE}Recommendation Quality${NC}"
echo "----------------------------------------------"
echo ""

# Check for recommendation components
check_section "Recommendations have owners" "owner:"
check_section "Recommendations have timelines" "timeline:\|due date:\|due:"
check_section "Recommendations have priorities" "critical\|high priority\|medium priority"
check_section "Recommendations have verification" "verification:\|success criteria:" "false"

echo ""
echo "----------------------------------------------"
echo -e "${BLUE}Content Quality${NC}"
echo "----------------------------------------------"
echo ""

# Check for evidence/specificity
if grep -qi "evidence:\|log\|cloudtrail\|api call" "$REPORT_FILE"; then
    echo -e "${GREEN}[PASS]${NC} Contains evidence references"
    ((PASSED++))
else
    echo -e "${YELLOW}[WARN]${NC} Consider adding specific evidence/log references"
    ((WARNINGS++))
fi

# Check for dates/times
if grep -qE "[0-9]{4}-[0-9]{2}-[0-9]{2}|[0-9]{2}:[0-9]{2}" "$REPORT_FILE"; then
    echo -e "${GREEN}[PASS]${NC} Contains specific dates/times"
    ((PASSED++))
else
    echo -e "${YELLOW}[WARN]${NC} Consider adding specific dates and times"
    ((WARNINGS++))
fi

# Check for placeholder text that should be replaced
if grep -qi "\[your\|\[insert\|\[describe\|\[list\|YYYY\|NNNN\|HH:MM" "$REPORT_FILE"; then
    echo -e "${YELLOW}[WARN]${NC} Contains unfilled placeholders"
    ((WARNINGS++))
else
    echo -e "${GREEN}[PASS]${NC} No obvious placeholder text"
    ((PASSED++))
fi

# Check document length
WORD_COUNT=$(wc -w < "$REPORT_FILE")
if [ "$WORD_COUNT" -ge 500 ]; then
    echo -e "${GREEN}[PASS]${NC} Report has substantial content ($WORD_COUNT words)"
    ((PASSED++))
else
    echo -e "${YELLOW}[WARN]${NC} Report may be too brief ($WORD_COUNT words)"
    ((WARNINGS++))
fi

echo ""
echo "----------------------------------------------"
echo -e "${BLUE}Security Best Practices${NC}"
echo "----------------------------------------------"
echo ""

# Check for sensitive data that shouldn't be in the report
if grep -qE "AKIA[0-9A-Z]{16}|[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}" "$REPORT_FILE"; then
    # Check if they look like real IPs or just examples
    if grep -qE "192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|127\." "$REPORT_FILE"; then
        echo -e "${GREEN}[PASS]${NC} IP addresses appear to be examples/internal"
        ((PASSED++))
    else
        echo -e "${YELLOW}[WARN]${NC} May contain real credentials or IP addresses - review carefully"
        ((WARNINGS++))
    fi
else
    echo -e "${GREEN}[PASS]${NC} No obvious sensitive data patterns"
    ((PASSED++))
fi

# Summary
echo ""
echo "=============================================="
echo "  CHECKLIST RESULTS"
echo "=============================================="
echo ""

TOTAL=$((PASSED + FAILED + WARNINGS))

echo -e "  ${GREEN}Passed:   $PASSED${NC}"
echo -e "  ${RED}Failed:   $FAILED${NC}"
echo -e "  ${YELLOW}Warnings: $WARNINGS${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}Excellent! Your post-mortem report is complete.${NC}"
    else
        echo -e "${GREEN}Good! Your report has all required sections.${NC}"
        echo -e "${YELLOW}Consider addressing the warnings to improve quality.${NC}"
    fi
else
    echo -e "${RED}Your report is missing required sections.${NC}"
    echo "Review the failures above and update your report."
fi

echo ""
echo "----------------------------------------------"
echo "Additional recommendations:"
echo "----------------------------------------------"
echo ""
echo "1. Have someone else review the report for clarity"
echo "2. Ensure technical terms are explained for executives"
echo "3. Verify all recommendations have clear owners"
echo "4. Schedule follow-up meetings for recommendation tracking"
echo ""

# Return appropriate exit code
if [ $FAILED -gt 0 ]; then
    exit 1
elif [ $WARNINGS -gt 3 ]; then
    exit 2
else
    exit 0
fi
