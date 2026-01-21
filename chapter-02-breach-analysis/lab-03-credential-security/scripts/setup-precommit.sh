#!/bin/bash

# Lab 03: Setup Git Pre-commit Hook
# Installs a hook to scan for secrets before commits

echo ""
echo "=============================================="
echo "  SETTING UP PRE-COMMIT HOOK"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}Not in a git repository root.${NC}"
    echo ""
    echo "Would you like to initialize a git repository here? (y/n)"
    read -r INIT_GIT

    if [ "$INIT_GIT" = "y" ] || [ "$INIT_GIT" = "Y" ]; then
        git init
        echo -e "${GREEN}Git repository initialized.${NC}"
    else
        echo "Please run this from a git repository root."
        exit 1
    fi
fi

HOOKS_DIR=".git/hooks"
HOOK_FILE="$HOOKS_DIR/pre-commit"

echo "Creating pre-commit hook at: $HOOK_FILE"
echo ""

# Create the pre-commit hook
cat > "$HOOK_FILE" << 'HOOKEOF'
#!/bin/bash

# Pre-commit hook: Scan for secrets
# This hook prevents commits that contain potential secrets

echo ""
echo "=============================================="
echo "  PRE-COMMIT SECRET SCAN"
echo "=============================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get list of staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED_FILES" ]; then
    echo "No files staged for commit."
    exit 0
fi

echo "Scanning staged files for secrets..."
echo ""

ISSUES_FOUND=0
BLOCKED_FILES=""

for FILE in $STAGED_FILES; do
    # Skip binary files
    if file "$FILE" 2>/dev/null | grep -q "binary"; then
        continue
    fi

    # Skip files that don't exist (deleted)
    if [ ! -f "$FILE" ]; then
        continue
    fi

    FILE_ISSUES=""

    # Check for AWS Access Key
    if grep -n "AKIA[0-9A-Z]\{16\}" "$FILE" 2>/dev/null; then
        FILE_ISSUES+="  AWS Access Key ID\n"
        ((ISSUES_FOUND++))
    fi

    # Check for private keys
    if grep -n "BEGIN.*PRIVATE KEY" "$FILE" 2>/dev/null; then
        FILE_ISSUES+="  Private Key\n"
        ((ISSUES_FOUND++))
    fi

    # Check for password assignments
    PASS_CHECK=$(grep -in "password[[:space:]]*=[[:space:]]*['\"][^'\"]\+['\"]" "$FILE" 2>/dev/null | grep -v "example\|sample\|placeholder\|<your")
    if [ -n "$PASS_CHECK" ]; then
        FILE_ISSUES+="  Password pattern\n"
        ((ISSUES_FOUND++))
    fi

    # Check for API keys
    if grep -in "api[_-]*key[[:space:]]*=[[:space:]]*['\"][A-Za-z0-9]\{20,\}['\"]" "$FILE" 2>/dev/null | grep -qv "example\|sample"; then
        FILE_ISSUES+="  API Key pattern\n"
        ((ISSUES_FOUND++))
    fi

    # Check for GitHub tokens
    if grep -n "ghp_[A-Za-z0-9]\{36\}" "$FILE" 2>/dev/null; then
        FILE_ISSUES+="  GitHub Token\n"
        ((ISSUES_FOUND++))
    fi

    # Check for Stripe keys
    if grep -n "sk_live_\|rk_live_" "$FILE" 2>/dev/null; then
        FILE_ISSUES+="  Stripe API Key\n"
        ((ISSUES_FOUND++))
    fi

    # Check for connection strings with passwords
    if grep -in "://[^:]*:[^@]*@" "$FILE" 2>/dev/null | grep -qv "example\|sample\|localhost"; then
        FILE_ISSUES+="  Connection string with credentials\n"
        ((ISSUES_FOUND++))
    fi

    if [ -n "$FILE_ISSUES" ]; then
        BLOCKED_FILES+="  $FILE\n$FILE_ISSUES\n"
    fi
done

if [ $ISSUES_FOUND -gt 0 ]; then
    echo -e "${RED}[BLOCKED] Potential secrets detected!${NC}"
    echo ""
    echo -e "$BLOCKED_FILES"
    echo ""
    echo "Commit blocked to prevent secret leakage."
    echo ""
    echo "To bypass (NOT RECOMMENDED):"
    echo "  git commit --no-verify"
    echo ""
    echo "To fix:"
    echo "  1. Remove hardcoded credentials"
    echo "  2. Use AWS Secrets Manager or environment variables"
    echo "  3. Add sensitive files to .gitignore"
    echo ""
    exit 1
else
    echo -e "${GREEN}No secrets detected in staged files.${NC}"
    echo ""
fi

exit 0
HOOKEOF

# Make the hook executable
chmod +x "$HOOK_FILE"

echo -e "${GREEN}Pre-commit hook installed successfully!${NC}"
echo ""
echo "The hook will scan for:"
echo "  - AWS Access Keys"
echo "  - Private keys"
echo "  - Hardcoded passwords"
echo "  - API keys"
echo "  - GitHub tokens"
echo "  - Stripe keys"
echo "  - Connection strings with credentials"
echo ""
echo "To test the hook, try committing a file with secrets:"
echo ""
echo "  echo 'password=\"secret123\"' > test-secret.txt"
echo "  git add test-secret.txt"
echo "  git commit -m 'test'"
echo ""
echo "The commit should be blocked!"
echo ""
echo "----------------------------------------------"
echo ""
echo "For more robust secret scanning, consider:"
echo ""
echo "  1. TruffleHog (https://github.com/trufflesecurity/trufflehog)"
echo "     trufflehog git file://. --only-verified"
echo ""
echo "  2. Gitleaks (https://github.com/gitleaks/gitleaks)"
echo "     gitleaks detect --source ."
echo ""
echo "  3. AWS git-secrets (https://github.com/awslabs/git-secrets)"
echo "     git secrets --scan"
echo ""
echo "=============================================="
