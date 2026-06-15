#!/usr/bin/env bash
# apply-optimizations.sh — Apply hardware-specific kernel optimizations
#
# Applies the following optimizations to config.gz:
#   ✅ Safe: MCORE2, NR_CPUS=8, MAXSMP off, ASPM PERFORMANCE,
#            DWARF ZSTD, EFI_MIXED off, SHA256, LSMs trimmed
#   ⚠️ Recommended: NUMA off, PREEMPT_LAZY, THP MADVISE,
#            NUMA_BALANCING off, SCHED_CLASS_EXT off
#
# Usage:
#   ./apply-optimizations.sh              # apply all optimizations
#   ./apply-optimizations.sh --dry-run    # show what would change
#   ./apply-optimizations.sh --restore    # restore from backup
#
# Hardware target: Intel Xeon E31270 (Sandy Bridge) + AMD RX 580

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONFIG_GZ="config.gz"
CONFIG_BACKUP="config.gz.backup"
CONFIG_PLAINTEXT="config.optimized"
CONFIG_TMP=$(mktemp /tmp/linux-flatten-config.XXXXXX)
trap 'rm -f "$CONFIG_TMP"' EXIT

# ─── Color output ───────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; }

# ─── Help ────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTION]

Apply hardware-optimized kernel config for Xeon E31270 + AMD RX 580.

Options:
  --dry-run    Show what would change without modifying files
  --restore    Restore config.gz from backup
  --help       Show this help
EOF
    exit 0
}

# ─── Parse args ──────────────────────────────────────────────
DRY_RUN=false
RESTORE=false

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --restore) RESTORE=true ;;
        --help) usage ;;
    esac
done

# ─── Restore mode ────────────────────────────────────────────
if $RESTORE; then
    if [ -f "$CONFIG_BACKUP" ]; then
        cp "$CONFIG_BACKUP" "$CONFIG_GZ"
        info "Restored $CONFIG_GZ from $CONFIG_BACKUP"
        exit 0
    else
        err "Backup not found: $CONFIG_BACKUP"
        exit 1
    fi
fi

# ─── Validate input ──────────────────────────────────────────
if [ ! -f "$CONFIG_GZ" ]; then
    err "config.gz not found in $SCRIPT_DIR"
    err "Copy from /proc/config.gz first: cp /proc/config.gz ./"
    exit 1
fi

# ─── Dry-run: show diff ──────────────────────────────────────
if $DRY_RUN; then
    if [ ! -f "$CONFIG_BACKUP" ]; then
        warn "No backup found. Run without --dry-run first."
        exit 0
    fi
    echo "=== Differences from backup ==="
    diff <(zcat "$CONFIG_BACKUP") <(zcat "$CONFIG_GZ") || true
    exit 0
fi

# ─── Backup ──────────────────────────────────────────────────
if [ ! -f "$CONFIG_BACKUP" ]; then
    cp "$CONFIG_GZ" "$CONFIG_BACKUP"
    info "Created backup: $CONFIG_BACKUP"
else
    warn "Backup already exists, skipping backup"
fi

# ─── Extract config ──────────────────────────────────────────
zcat "$CONFIG_GZ" > "$CONFIG_TMP"
info "Extracted $CONFIG_GZ"

# ─── Helper: enable config option ────────────────────────────
enable_opt() {
    local opt="$1"
    if grep -q "^$opt=y" "$CONFIG_TMP"; then
        return 0  # already enabled
    fi
    sed -i "s/^# $opt is not set\$/$opt=y/" "$CONFIG_TMP"
    sed -i "s/^$opt=m\$/$opt=y/" "$CONFIG_TMP"
    # If neither pattern matched, add it
    if ! grep -q "^$opt=y" "$CONFIG_TMP"; then
        echo "$opt=y" >> "$CONFIG_TMP"
    fi
}

disable_opt() {
    local opt="$1"
    if grep -q "^# $opt is not set" "$CONFIG_TMP"; then
        return 0  # already disabled
    fi
    sed -i "s/^$opt=y\$/# $opt is not set/" "$CONFIG_TMP"
    sed -i "s/^$opt=m\$/# $opt is not set/" "$CONFIG_TMP"
}

set_val() {
    local opt="$1"
    local val="$2"
    if grep -q "^$opt=" "$CONFIG_TMP"; then
        sed -i "s/^$opt=.*\$/$opt=$val/" "$CONFIG_TMP"
    else
        local line
        line=$(grep -n "^# $opt" "$CONFIG_TMP" | head -1 | cut -d: -f1)
        if [ -n "$line" ]; then
            sed -i "${line}s/.*/$opt=$val/" "$CONFIG_TMP"
        else
            echo "$opt=$val" >> "$CONFIG_TMP"
        fi
    fi
}

# ─── Apply optimizations ─────────────────────────────────────

echo ""
echo "Applying optimizations for Intel Xeon E31270 + AMD RX 580"
echo "========================================================"
echo ""

# 1.1 CPU: x86-64-v2 + native CPU tuning
disable_opt CONFIG_GENERIC_CPU
enable_opt CONFIG_X86_NATIVE_CPU
set_val CONFIG_X86_64_VERSION 2
info "CPU: x86-64-v2 + native tuning (Sandy Bridge)"

# 1.2 NR_CPUS: 8192 → 8 (4 cores / 8 threads)
set_val CONFIG_NR_CPUS 8
set_val CONFIG_NR_CPUS_RANGE_BEGIN 2
set_val CONFIG_NR_CPUS_RANGE_END 8
set_val CONFIG_NR_CPUS_DEFAULT 8
info "NR_CPUS: 8192 → 8"

# 1.3 MAXSMP → disable (not needed for <8 CPUs)
disable_opt CONFIG_MAXSMP
info "MAXSMP disabled"

# 1.4 PCIe ASPM: DEFAULT → PERFORMANCE
disable_opt CONFIG_PCIEASPM_DEFAULT
enable_opt CONFIG_PCIEASPM_PERFORMANCE
info "PCIe ASPM: PERFORMANCE mode (lower GPU/NVMe latency)"

# 1.5 DEBUG_INFO: ZSTD compression
disable_opt CONFIG_DEBUG_INFO_COMPRESSED_NONE
enable_opt CONFIG_DEBUG_INFO_COMPRESSED_ZSTD
info "Debug info: ZSTD compressed (saves ~250MB)"

# 1.6 EFI_MIXED → disable (pure 64-bit UEFI)
disable_opt CONFIG_EFI_MIXED
info "EFI_MIXED disabled"

# 1.7 Module signature: SHA256 (faster on Sandy Bridge)
disable_opt CONFIG_MODULE_SIG_SHA512
enable_opt CONFIG_MODULE_SIG_SHA256
set_val CONFIG_MODULE_SIG_HASH "\"sha256\""
info "Module signature: SHA256 (2x faster, no SHA-NI)"

# 1.8 Disable unnecessary Security LSMs
disable_opt CONFIG_SECURITY_SMACK
disable_opt CONFIG_SECURITY_SMACK_BRINGUP
disable_opt CONFIG_SECURITY_SMACK_NETFILTER
disable_opt CONFIG_SECURITY_SMACK_APPEND_SIGNALS
disable_opt CONFIG_SECURITY_TOMOYO
disable_opt CONFIG_SECURITY_LOADPIN
disable_opt CONFIG_SECURITY_LOADPIN_ENFORCE
disable_opt CONFIG_SECURITY_SAFESETID
disable_opt CONFIG_SECURITY_IPE
set_val CONFIG_LSM '"landlock,lockdown,yama,integrity,bpf"'
info "Unnecessary LSMs disabled (kept: landlock,lockdown,yama,integrity,bpf)"

# 2.1 NUMA → disable (single-socket system)
disable_opt CONFIG_NUMA
disable_opt CONFIG_ACPI_NUMA
info "NUMA disabled"

# 2.2 PREEMPT → PREEMPT_LAZY
disable_opt CONFIG_PREEMPT
enable_opt CONFIG_PREEMPT_LAZY
info "PREEMPT_LAZY (better throughput + low latency)"

# 2.3 THP: ALWAYS → MADVISE
disable_opt CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS
enable_opt CONFIG_TRANSPARENT_HUGEPAGE_MADVISE
info "THP: MADVISE (more stable latency)"

# 2.4 NUMA_BALANCING → disable (depends on NUMA)
disable_opt CONFIG_NUMA_BALANCING
disable_opt CONFIG_NUMA_BALANCING_DEFAULT_ENABLED
info "NUMA_BALANCING disabled"

# 2.5 SCHED_CLASS_EXT → disable (not using custom sched_ext)
disable_opt CONFIG_SCHED_CLASS_EXT
info "SCHED_CLASS_EXT disabled"

# ─── Save optimized config ──────────────────────────────────
gzip -c "$CONFIG_TMP" > "$CONFIG_GZ"
cp "$CONFIG_TMP" "$CONFIG_PLAINTEXT"
info "Saved optimized config to $CONFIG_GZ"
info "Plain-text reference: $CONFIG_PLAINTEXT"

echo ""
echo "========================================================"
echo "All optimizations applied successfully!"
echo ""
echo "Next steps:"
echo "  1. Build: makepkg -sf"
echo "  2. Install: sudo pacman -U linux-flatten-*.pkg.tar.zst"
echo "  3. The install script will automatically:"
echo "     - Create /etc/mkinitcpio.d/linux-flatten.preset"
echo "     - Generate initramfs via mkinitcpio -p linux-flatten"
echo "     - Add/update Limine entry with pcie_aspm=performance"
echo "  4. Reboot and select 'Linux Flatten' in Limine"
echo "  5. Verify: ./test-kernel.sh"
echo ""
echo "NOTE: The kernel parameter pcie_aspm=performance is"
echo "automatically added to the Limine cmdline by the install"
echo "script. This ensures PCIe ASPM is in performance mode"
echo "even on motherboards where the kernel default is ignored."
echo "========================================================"
