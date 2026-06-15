#!/usr/bin/env bash
#
# sync-with-cachyos.sh — Sync linux-flatten with upstream CachyOS changes
#
# Usage:
#   ./sync-with-cachyos.sh            # Pull, show diff, copy new patches
#   ./sync-with-cachyos.sh --apply    # Also re-apply our optimizations
#   ./sync-with-cachyos.sh --build    # Apply + rebuild
#   ./sync-with-cachyos.sh --help     # Show this help
#
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHYOS_REPO="${SELF_DIR}/../linux-cachyos"
FLAT_DIR="${SELF_DIR}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
header(){ echo -e "\n${CYAN}==== $* ====${NC}"; }

show_help() {
    sed -n '2,11p' "$0"
    exit 0
}

# ---- Parse arguments ----
DO_APPLY=false
DO_BUILD=false
for arg in "$@"; do
    case "$arg" in
        --help) show_help ;;
        --apply) DO_APPLY=true ;;
        --build) DO_APPLY=true; DO_BUILD=true ;;
        *) error "Unknown argument: $arg"; show_help ;;
    esac
done

# ---- Step 0: Validate directories ----
if [ ! -d "$CACHYOS_REPO" ]; then
    error "CachyOS repo not found at $CACHYOS_REPO"
    info "Expected: linux-cachyos/ (sibling of linux-flatten-pkg/)"
    exit 1
fi

if [ ! -f "$FLAT_DIR/PKGBUILD" ]; then
    error "No PKGBUILD found in $FLAT_DIR — is this the linux-flatten package directory?"
    exit 1
fi

# ---- Step 1: Update CachyOS repo ----
header "Step 1: Updating CachyOS repository"

if [ -d "$CACHYOS_REPO/.git" ]; then
    git -C "$CACHYOS_REPO" fetch --all --tags
    git -C "$CACHYOS_REPO" pull --ff-only || {
        warn "Could not fast-forward CachyOS repo. Trying rebase..."
        git -C "$CACHYOS_REPO" pull --rebase || {
            error "Failed to update CachyOS repo. Check your git state."
            exit 1
        }
    }
    info "CachyOS repo updated to $(git -C "$CACHYOS_REPO" rev-parse --short HEAD)"
else
    warn "CachyOS repo has no .git — skipping pull"
fi

# ---- Step 2: Show diff between CachyOS PKGBUILD and ours ----
header "Step 2: Diff CachyOS PKGBUILD vs our PKGBUILD"

DEFAULT_CACHYOS_PKG="${CACHYOS_REPO}/linux-cachyos/PKGBUILD"
OUR_PKGBUILD="${FLAT_DIR}/PKGBUILD"

if [ -f "$DEFAULT_CACHYOS_PKG" ] && [ -f "$OUR_PKGBUILD" ]; then
    diff -u \
        --label "CachyOS PKGBUILD" \
        --label "linux-flatten PKGBUILD" \
        "$DEFAULT_CACHYOS_PKG" "$OUR_PKGBUILD" \
    || true  # diff returns non-zero when there are differences
else
    warn "Cannot compare PKGBUILD files (missing one)"
fi

# ---- Step 3: Copy any new patches from CachyOS ----
header "Step 3: Sync patches from CachyOS"

# CachyOS patches are fetched from GitHub at build time, not stored locally.
# However, if there are local patch files in the CachyOS repo, copy them.
CACHYOS_PATCH_DIR="${CACHYOS_REPO}/patches"
FLAT_PATCH_DIR="${FLAT_DIR}/patches"

if [ -d "$CACHYOS_PATCH_DIR" ]; then
    mkdir -p "$FLAT_PATCH_DIR"
    info "Copying patches from $CACHYOS_PATCH_DIR to $FLAT_PATCH_DIR"
    rsync -avh --ignore-existing "$CACHYOS_PATCH_DIR/" "$FLAT_PATCH_DIR/"
    info "Patches synced. Check for conflicts manually: diff -r $CACHYOS_PATCH_DIR $FLAT_PATCH_DIR"
else
    info "No local patch directory in CachyOS repo (patches are fetched at build time from GitHub)"
    info "See: https://raw.githubusercontent.com/cachyos/kernel-patches/master/"
fi

# ---- Step 4: Show config diff ----
header "Step 4: Config changes from upstream"

CACHYOS_CONFIG="${CACHYOS_REPO}/linux-cachyos/config"
OUR_CONFIG="${FLAT_DIR}/config.optimized"

if [ -f "$CACHYOS_CONFIG" ] && [ -f "$OUR_CONFIG" ]; then
    # Compare a few key options
    info "Key config differences (CachyOS base config -> our optimized):"
    echo ""
    echo "  Option                        CachyOS          linux-flatten  "
    echo "  ────────────────────────────  ───────────────  ───────────────"
    for opt in \
        "CONFIG_GENERIC_CPU" \
        "CONFIG_X86_NATIVE_CPU" \
        "CONFIG_PREEMPT" \
        "CONFIG_PREEMPT_LAZY" \
        "CONFIG_NUMA" \
        "CONFIG_NR_CPUS" \
        "CONFIG_MAXSMP" \
        "CONFIG_EFI_MIXED" \
        "CONFIG_PCIEASPM_DEFAULT" \
        "CONFIG_PCIEASPM_PERFORMANCE" \
        "CONFIG_SCHED_CLASS_EXT" \
        "CONFIG_MODULE_SIG_HASH" \
        "CONFIG_DEBUG_INFO_COMPRESSED" \
        "CONFIG_HZ" \
        "CONFIG_CACHY" \
    ; do
        c_val=$(rg "^${opt}=" "$CACHYOS_CONFIG" 2>/dev/null || echo "(not set)")
        f_val=$(rg "^${opt}=" "$OUR_CONFIG" 2>/dev/null || echo "(not set)")
        # Trim to 16 chars for alignment
        c_short="${c_val:0:16}"
        f_short="${f_val:0:16}"
        printf "  %-30s %-17s %s\n" "$opt" "$c_short" "$f_short"
    done
    echo ""
fi

# ---- Step 5: Re-apply our optimizations (if --apply or --build) ----
if [ "$DO_APPLY" = true ]; then
    header "Step 5: Re-applying our optimizations"

    APPLY_SCRIPT="${FLAT_DIR}/apply-optimizations.sh"
    if [ -f "$APPLY_SCRIPT" ]; then
        info "Running: $APPLY_SCRIPT"
        bash "$APPLY_SCRIPT"
        info "Optimizations re-applied."
    else
        warn "apply-optimizations.sh not found at $APPLY_SCRIPT"
        info "You may need to run the optimization steps manually:"
        echo "  cd ${FLAT_DIR}"
        echo "  # Review and apply config changes"
    fi
else
    info "Skipping re-apply (use --apply or --build to run)"
fi

# ---- Step 6: Optionally rebuild ----
if [ "$DO_BUILD" = true ]; then
    header "Step 6: Building kernel"

    if command -v makepkg &>/dev/null; then
        info "Running: makepkg -s --cleanbuild"
        cd "$FLAT_DIR"
        makepkg -s --cleanbuild
        info "Build complete."
    else
        error "makepkg not found — are you on Arch Linux?"
        error "Manual build: cd $FLAT_DIR && makepkg -s"
        exit 1
    fi
else
    info "Skipping build (use --build to rebuild)"
fi

# ---- Summary ----
header "Summary"
echo "  CachyOS repo:   $CACHYOS_REPO ($(git -C "$CACHYOS_REPO" rev-parse --short HEAD 2>/dev/null || echo "N/A"))"
echo "  Flat package:   $FLAT_DIR"
echo ""
echo "Next steps:"
echo "  - Review the diff between the PKGBUILD files (above)"
echo "  - Check for new CachyOS features to adopt"
echo "  - Run with --apply to re-apply optimizations"
echo "  - Run with --build to rebuild after sync"
echo ""
info "Sync complete."
