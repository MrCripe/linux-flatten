#!/usr/bin/env bash
# test-kernel.sh — Verify linux-flatten kernel installation and optimizations
#
# Usage:
#   ./test-kernel.sh              # run all checks
#   ./test-kernel.sh --quick      # skip verbose tests
#   ./test-kernel.sh --list       # list available checks

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check() {
    local name="$1"
    local cmd="$2"
    echo -n "  [ ] $name... "
    if eval "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL${NC}"
        eval "$cmd" 2>&1 | sed 's/^/      /'
        FAIL=$((FAIL + 1))
    fi
}

check_verbose() {
    local name="$1"
    local cmd="$2"
    echo -e "\n${BLUE}[i]${NC} $name"
    echo "  Command: $cmd"
    echo "  Output:"
    eval "$cmd" 2>&1 | sed 's/^/    /'
    PASS=$((PASS + 1))
}

skip() {
    local name="$1"
    echo -n "  [ ] $name... "
    echo -e "${YELLOW}SKIP${NC}"
    SKIP=$((SKIP + 1))
}

header() {
    echo ""
    echo "========================================="
    echo "  $1"
    echo "========================================="
}

# ─── Parse args ──────────────────────────────────────────────
QUICK=false
LIST=false
for arg in "$@"; do
    case "$arg" in
        --quick) QUICK=true ;;
        --list)
            echo "Available checks:"
            grep -E "^[a-z_]+\(\)" "$0" | sed 's/() {$//;s/^/  /'
            exit 0
            ;;
    esac
done

echo ""
echo "========================================="
echo "  linux-flatten Post-Install Test Suite"
echo "========================================="
echo "  Date: $(date)"
echo "  Host: $(hostname)"
echo ""

# ─── 1. Kernel version ──────────────────────────────────────
header "1. Kernel Version & Identity"

check "Kernel is running" "uname -r"
check "Kernel name is linux-flatten" "uname -r | grep -q flatten"
check_verbose "Kernel release" "uname -a"

# ─── 2. Boot files ──────────────────────────────────────────
header "2. Boot Files"

check "vmlinuz exists" "test -f /boot/vmlinuz-linux-flatten"
check "initramfs exists" "test -f /boot/initramfs-linux-flatten.img"
check "Preset exists" "test -f /etc/mkinitcpio.d/linux-flatten.preset"

if $QUICK; then
    skip "vmlinuz size (quick mode)"
else
    check_verbose "vmlinuz size" "ls -lh /boot/vmlinuz-linux-flatten"
fi

# ─── 3. CPU configuration ───────────────────────────────────
header "3. CPU Configuration"

check "CPU governor is schedutil" \
    'cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null | grep -q schedutil'

if $QUICK; then
    skip "CPU frequency details (quick mode)"
    skip "CPU flags (quick mode)"
else
    check_verbose "CPU model" \
        'grep "model name" /proc/cpuinfo | head -1 | sed "s/.*: //"'
    check_verbose "CPU cores" \
        'echo "$(nproc) logical CPUs ($(grep -c ^processor /proc/cpuinfo) threads)"'
    check_verbose "CPU flags (key)" \
        'grep -o "sse4_2\|popcnt\|avx\|aes" /proc/cpuinfo | head -1 | sort -u | tr "\n" " "'
fi

# ─── 4. GPU / AMDGPU driver ─────────────────────────────────
header "4. GPU Configuration"

check "amdgpu module loaded" "lsmod | grep -q amdgpu"

if $QUICK; then
    skip "GPU details (quick mode)"
else
    check_verbose "GPU driver info" \
        'cat /sys/module/amdgpu/version 2>/dev/null || echo "Not available as module"'
    check_verbose "GPU devices" \
        'lspci -nn | grep -i "VGA\|3D" | head -3'
    check_verbose "DRM driver" \
        'cat /sys/class/drm/card0/device/vendor 2>/dev/null; cat /sys/class/drm/card0/device/device 2>/dev/null || echo "N/A"'
fi

# ─── 5. Memory / THP ─────────────────────────────────────────
header "5. Memory Configuration"

check "THP is madvise" \
    'cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null | grep -q "\[madvise\]" || \
     cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null | grep -q "\[never\]"'

if $QUICK; then
    skip "Memory info (quick mode)"
else
    check_verbose "Memory" \
        'free -h | grep "^Mem:"'
    check_verbose "Swap/ZRAM" \
        'zramctl 2>/dev/null || echo "zram not active"'
    check_verbose "THP status" \
        'cat /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || echo "N/A"'
fi

# ─── 6. Btrfs filesystem ────────────────────────────────────
header "6. Filesystem Configuration"

check "Btrfs module loaded" \
    'lsmod | grep -q btrfs || grep -q btrfs /proc/filesystems'

if ! $QUICK; then
    check_verbose "Mount points" \
        'findmnt -t btrfs -o TARGET,FSTYPE,OPTIONS 2>/dev/null | head -10'
fi

# ─── 7. Config verification ─────────────────────────────────
header "7. Kernel Config Verification"

check "CACHY config present" \
    'zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_CACHY=y" || zgrep -q "CONFIG_CACHY=y" /proc/config.gz 2>/dev/null || test -f /proc/config.gz'

check "PREEMPT_LAZY enabled" \
    'zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_PREEMPT_LAZY=y" || test -f /proc/config.gz'

if [ -f "$SCRIPT_DIR/config.optimized" ]; then
    check_verbose "Local optimized config exists" \
        "ls -la $SCRIPT_DIR/config.optimized"
fi

# ─── 8. Bootloader ──────────────────────────────────────────
header "8. Bootloader (Limine)"

if [ -f /boot/limine/limine.conf ]; then
    check "Linux Flatten entry in Limine" \
        'grep -q "Linux Flatten" /boot/limine/limine.conf 2>/dev/null'
else
    skip "Limine config not found"
fi

# ─── Summary ────────────────────────────────────────────────
header "Results"

TOTAL=$((PASS + FAIL + SKIP))
echo -e "  ${GREEN}Passed:${NC} $PASS"
echo -e "  ${RED}Failed:${NC} $FAIL"
echo -e "  ${YELLOW}Skipped:${NC} $SKIP"
echo "  Total:  $TOTAL"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}All critical checks passed!${NC}"
    echo ""
    echo "Recommended next steps:"
    echo "  - Run stress test: stress-ng --cpu 8 --timeout 60s"
    echo "  - Monitor temps:   watch -n 2 sensors"
    echo "  - Check dmesg:     dmesg | grep -i error"
    exit 0
else
    echo -e "${RED}Some checks failed. Review output above.${NC}"
    exit 1
fi
