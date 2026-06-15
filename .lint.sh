#!/usr/bin/env bash
# Linting script for linux-flatten package
# Runs all available checks on PKGBUILD and install scripts

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================="
echo "  linux-flatten Package Linter"
echo "========================================="
echo

FAILED=0

# Function to run a check
run_check() {
    local name="$1"
    local cmd="$2"
    echo -n "Running $name... "
    if eval "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
    else
        echo -e "${RED}FAIL${NC}"
        echo "  Command: $cmd"
        eval "$cmd" 2>&1 | sed 's/^/  /'
        FAILED=1
    fi
}

# Function to run a check with output
run_check_verbose() {
    local name="$1"
    local cmd="$2"
    echo "Running $name..."
    if eval "$cmd"; then
        echo -e "${GREEN}PASS${NC}"
        echo
    else
        echo -e "${RED}FAIL${NC}"
        echo
        FAILED=1
    fi
}

# 1. Check PKGBUILD syntax
run_check "PKGBUILD syntax" "bash -n PKGBUILD"

# 2. Check install script syntax
run_check "Install script syntax" "bash -n linux-flatten.install"

# 3. Check with namcap (if available)
if command -v namcap >/dev/null 2>&1; then
    run_check_verbose "namcap PKGBUILD" "namcap PKGBUILD"
else
    echo -e "${YELLOW}SKIP${NC} namcap (not installed)"
    echo
fi

# 4. Check with shellcheck (if available)
if command -v shellcheck >/dev/null 2>&1; then
    run_check_verbose "shellcheck linux-flatten.install" "shellcheck linux-flatten.install"
    run_check_verbose "shellcheck PKGBUILD" "shellcheck PKGBUILD"
else
    echo -e "${YELLOW}SKIP${NC} shellcheck (not installed)"
    echo
fi

# 5. Check for common PKGBUILD issues
run_check "PKGBUILD has maintainer" "grep -q '^# Maintainer: ' PKGBUILD && ! grep -q 'your_name' PKGBUILD"
run_check "PKGBUILD has source array" "grep -q '^source=(' PKGBUILD"
run_check "PKGBUILD has sha256sums" "grep -q '^sha256sums=(' PKGBUILD"
run_check "PKGBUILD has valid arch" "grep -q \"arch=('x86_64')\" PKGBUILD"
run_check "Install script referenced in PKGBUILD" "grep -q '^install=' PKGBUILD"

# 6. Check install script for dangerous patterns
run_check "No sudo in install script" "! grep -q 'sudo' linux-flatten.install"
run_check "No hardcoded /tmp without mktemp" "! grep -q '/tmp/' linux-flatten.install || grep -q 'mktemp' linux-flatten.install"
run_check "Backup before modifying system files" "grep -q '\.bak' linux-flatten.install"

# 7. Check for required functions in install script
run_check "Has post_install" "grep -q '^post_install()' linux-flatten.install"
run_check "Has post_upgrade" "grep -q '^post_upgrade()' linux-flatten.install"
run_check "Has pre_remove" "grep -q '^pre_remove()' linux-flatten.install"
run_check "Has post_remove" "grep -q '^post_remove()' linux-flatten.install"

echo "========================================="
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
else
    echo -e "${RED}Some checks failed!${NC}"
    exit 1
fi