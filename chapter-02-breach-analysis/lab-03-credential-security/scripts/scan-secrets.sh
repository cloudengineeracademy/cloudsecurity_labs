#!/bin/bash

# Lab 03: Secret Scanner
# Scans files for hardcoded credentials and secrets

echo ""
echo "=============================================="
echo "  SECRET SCANNER"
echo "  Finding hardcoded credentials"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Target directory
TARGET_DIR="${1:-.}"

if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}ERROR: Directory '$TARGET_DIR' not found${NC}"
    echo "Usage: $0 [directory]"
    exit 1
fi

echo "Scanning directory: $TARGET_DIR"
echo ""

# Counters
CRITICAL=0
HIGH=0
MEDIUM=0
TOTAL_FILES=0

# Function to scan a file
scan_file() {
    local file="$1"
    local findings=""
    local file_has_issues=false

    # Skip binary files
    if file "$file" | grep -q "binary"; then
        return
    fi

    ((TOTAL_FILES++))

    # Pattern 1: AWS Access Key ID
    while IFS=: read -r line_num content; do
        if [ -n "$line_num" ]; then
            findings+="  ${RED}[CRITICAL]${NC} Line $line_num: AWS Access Key ID\n"
            ((CRITICAL++))
            file_has_issues=true
        fi
    done < <(grep -n "AKIA[0-9A-Z]\{16\}" "$file" 2>/dev/null)

    # Pattern 2: AWS Secret Access Key (40 char base64-ish)
    while IFS=: read -r line_num content; do
        if [ -n "$line_num" ]; then
            # Check if it looks like a secret key context
            if grep -q -i "secret\|key\|aws" <<< "$content"; then
                findings+="  ${RED}[CRITICAL]${NC} Line $line_num: AWS Secret Access Key\n"
                ((CRITICAL++))
                file_has_issues=true
            fi
        fi
    done < <(grep -n "['\"][A-Za-z0-9/+=]\{40\}['\"]" "$file" 2>/dev/null)

    # Pattern 3: Generic password patterns
    while IFS=: read -r line_num content; do
        if [ -n "$line_num" ]; then
            # Skip comments that are just documentation
            if ! echo "$content" | grep -q "^[[:space:]]*#.*example\|^[[:space:]]*//.*example"; then
                findings+="  ${YELLOW}[HIGH]${NC} Line $line_num: Password pattern\n"
                ((HIGH++))
                file_has_issues=true
            fi
        fi
    done < <(grep -in "password[[:space:]]*=[[:space:]]*['\"][^'\"]\+['\"]" "$file" 2>/dev/null)

    # Pattern 4: API keys
    while IFS=: read -r line_num content; do
        if [ -n "$line_num" ]; then
            findings+="  ${YELLOW}[HIGH]${NC} Line $line_num: API Key pattern\n"
            ((HIGH++))
            file_has_issues=true
        fi
    done < <(grep -in "api[_-]*key[[:space:]]*=[[:space:]]*['\"][^'\"]\+['\"]" "$file" 2>/dev/null)

    # Pattern 5: Private keys
    while IFS=: read -r line_num content; do
        if [ -n "$line_num" ]; then
            findings+="  ${RED}[CRITICAL]${NC} Line $line_num: Private key header\n"
            ((CRITICAL++))
            file_has_issues=true
        fi
    done < <(grep -n "BEGIN.*PRIVATE KEY" "$file" 2>/dev/null)

    # Pattern 6: GitHub tokens
    while IFS=: read -r line_num content; do
        if [ -n "$line_num" ]; then
            findings+="  ${RED}[CRITICAL]${NC} Line $line_num: GitHub Token\n"
            ((CRITICAL++))
            file_has_issues=true
        fi
    done < <(grep -n "ghp_[A-Za-z0-9]\{36\}\|github_pat_[A-Za-z0-9]\{22\}_[A-Za-z0-9]\{59\}" "$file" 2>/dev/null)

    # Pattern 7: Stripe keys
    while IFS=: read -r line_num content; do
        if [ -n "$line_num" ]; then
            findings+="  ${RED}[CRITICAL]${NC} Line $line_num: Stripe API Key\n"
            ((CRITICAL++))
            file_has_issues=true
        fi
    done < <(grep -n "sk_live_[A-Za-z0-9]\{24\}\|rk_live_[A-Za-z0-9]\{24\}" "$file" 2>/dev/null)

    # Pattern 8: Generic secrets
    while IFS=: read -r line_num content; do
        if [ -n "$line_num" ]; then
            findings+="  ${BLUE}[MEDIUM]${NC} Line $line_num: Secret pattern\n"
            ((MEDIUM++))
            file_has_issues=true
        fi
    done < <(grep -in "secret[[:space:]]*=[[:space:]]*['\"][^'\"]\{8,\}['\"]" "$file" 2>/dev/null)

    # Pattern 9: Connection strings with credentials
    while IFS=: read -r line_num content; do
        if [ -n "$line_num" ]; then
            findings+="  ${YELLOW}[HIGH]${NC} Line $line_num: Connection string with credentials\n"
            ((HIGH++))
            file_has_issues=true
        fi
    done < <(grep -in "://[^:]*:[^@]*@" "$file" 2>/dev/null)

    # Print findings for this file
    if [ "$file_has_issues" = true ]; then
        echo "----------------------------------------------"
        echo -e "${YELLOW}File: $file${NC}"
        echo "----------------------------------------------"
        echo -e "$findings"
    fi
}

# Scan all files
echo "Scanning files..."
echo ""

while IFS= read -r -d '' file; do
    scan_file "$file"
done < <(find "$TARGET_DIR" -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.sh" -o -name "*.bash" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.env" -o -name "*.config" -o -name "*.conf" -o -name "*.xml" -o -name "*.properties" -o -name "*.tf" -o -name "*.go" -o -name "*.java" -o -name "*.rb" -o -name "*.php" \) -print0 2>/dev/null)

# Summary
echo ""
echo "=============================================="
echo "  SCAN RESULTS"
echo "=============================================="
echo ""
echo "Files scanned: $TOTAL_FILES"
echo ""

TOTAL_ISSUES=$((CRITICAL + HIGH + MEDIUM))

if [ $TOTAL_ISSUES -eq 0 ]; then
    echo -e "${GREEN}No secrets detected!${NC}"
    echo ""
    echo "This doesn't guarantee there are no secrets - consider using"
    echo "dedicated tools like:"
    echo "  - TruffleHog: https://github.com/trufflesecurity/trufflehog"
    echo "  - Gitleaks: https://github.com/gitleaks/gitleaks"
    echo "  - AWS git-secrets: https://github.com/awslabs/git-secrets"
else
    echo -e "  ${RED}Critical: $CRITICAL${NC}"
    echo -e "  ${YELLOW}High:     $HIGH${NC}"
    echo -e "  ${BLUE}Medium:   $MEDIUM${NC}"
    echo ""
    echo -e "${RED}Total issues found: $TOTAL_ISSUES${NC}"
    echo ""
    echo "Remediation steps:"
    echo "  1. Remove hardcoded credentials from code"
    echo "  2. Store secrets in AWS Secrets Manager"
    echo "  3. Use IAM roles instead of access keys"
    echo "  4. Add .env files to .gitignore"
    echo "  5. Set up pre-commit hooks to prevent future leaks"
fi

echo ""
echo "=============================================="

# Exit with error if critical issues found
if [ $CRITICAL -gt 0 ]; then
    exit 1
fi

exit 0
