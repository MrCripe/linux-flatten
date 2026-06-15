#!/usr/bin/env bash
# auto-update.sh — Automatically update linux-flatten kernel from upstream
#
# Fetches latest sched/flat from Peter Zijlstra's queue.git,
# applies CachyOS optimizations and local hardware tuning,
# then builds and installs the package.
#
# Usage:
#   ./auto-update.sh              # update, build, install
#   ./auto-update.sh --check      # check for new commits only
#   ./auto-update.sh --build-only # update sources + build, no install
#   ./auto-update.sh --help       # show this help

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; }
step()  { echo -e "${CYAN}==>${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ─── Config ──────────────────────────────────────────────────
KERNEL_BRANCH="sched/flat"
KERNEL_REPO="https://git.kernel.org/pub/scm/linux/kernel/git/peterz/queue.git"
SRC_DIR="src"
CONFIG_GZ="config.gz"
CONFIG_BACKUP="config.gz.backup"
PKGBUILD="PKGBUILD"

# ─── Parse args ──────────────────────────────────────────────
CHECK_ONLY=false
BUILD_ONLY=false

for arg in "$@"; do
    case "$arg" in
        --check) CHECK_ONLY=true ;;
        --build-only) BUILD_ONLY=true ;;
        --help)
            echo "Usage: $(basename "$0") [--check|--build-only|--help]"
            echo "  --check       Check for new upstream commits (no build)"
            echo "  --build-only  Update sources + build, skip install"
            exit 0
            ;;
    esac
done

# ─── Prerequisites ──────────────────────────────────────────
step "Checking prerequisites..."
command -v makepkg >/dev/null 2>&1 || { err "makepkg not found. Run on Arch Linux."; exit 1; }
command -v git >/dev/null 2>&1 || { err "git not found."; exit 1; }
command -v pacman >/dev/null 2>&1 || { warn "pacman not found, install step will be skipped."; BUILD_ONLY=true; }
info "All prerequisites met"

# ─── Check upstream ─────────────────────────────────────────
step "Checking upstream kernel repository..."

if [ ! -d "$SRC_DIR/linux-flatten" ]; then
    warn "Source directory not found. Will clone."
    CLONE_NEEDED=true
else
    CLONE_NEEDED=false
    cd "$SRC_DIR/linux-flatten"
    # Save current HEAD
    OLD_HEAD=$(git rev-parse HEAD)
    cd "$SCRIPT_DIR"
fi

if $CLONE_NEEDED; then
    step "Cloning $KERNEL_BRANCH branch..."
    git clone --depth=1 --single-branch -b "$KERNEL_BRANCH" "$KERNEL_REPO" "$SRC_DIR/linux-flatten"
    info "Repository cloned"
else
    step "Fetching latest changes..."
    cd "$SRC_DIR/linux-flatten"
    git fetch origin "$KERNEL_BRANCH" --depth=1 2>&1 | sed 's/^/  /'
    git reset --hard "origin/$KERNEL_BRANCH" 2>&1 | sed 's/^/  /'
    NEW_HEAD=$(git rev-parse HEAD)
    cd "$SCRIPT_DIR"

    if [ "$OLD_HEAD" = "$NEW_HEAD" ]; then
        info "Already up-to-date (commit: ${NEW_HEAD:0:12})"
        if $CHECK_ONLY; then
            exit 0
        fi
    else
        info "Updated: ${OLD_HEAD:0:12} → ${NEW_HEAD:0:12}"
    fi
fi

if $CHECK_ONLY; then
    exit 0
fi

# ─── Backup config ──────────────────────────────────────────
step "Backing up current config.gz..."
if [ ! -f "$CONFIG_BACKUP" ]; then
    cp "$CONFIG_GZ" "$CONFIG_BACKUP"
    info "Backup created: $CONFIG_BACKUP"
else
    warn "Backup already exists, skipping"
fi

# ─── Apply optimizations ────────────────────────────────────
step "Applying hardware optimizations..."
if [ -f "./apply-optimizations.sh" ]; then
    bash ./apply-optimizations.sh
    info "Optimizations applied"
else
    warn "apply-optimizations.sh not found. Building with current config."
fi

# ─── Build ──────────────────────────────────────────────────
step "Building package..."
makepkg -sf --noconfirm 2>&1 | sed 's/^/  /'
info "Package built successfully"

PKG_FILE=$(ls -t linux-flatten-*.pkg.tar.zst 2>/dev/null | head -1)
if [ -z "$PKG_FILE" ]; then
    err "Package file not found after build"
    exit 1
fi
info "Package: $PKG_FILE"

if $BUILD_ONLY; then
    info "Build complete. Install manually: sudo pacman -U $PKG_FILE"
    exit 0
fi

# ─── Install ────────────────────────────────────────────────
step "Installing package..."
if command -v pacman >/dev/null 2>&1; then
    if [ "$(id -u)" -ne 0 ]; then
        warn "Not running as root. Trying sudo..."
        sudo pacman -U --noconfirm "$PKG_FILE" 2>&1 | sed 's/^/  /'
    else
        pacman -U --noconfirm "$PKG_FILE" 2>&1 | sed 's/^/  /'
    fi
    info "Package installed. Reboot to use the new kernel."
else
    err "pacman not found. Install manually: sudo pacman -U $PKG_FILE"
    exit 1
fi

# ─── Done ───────────────────────────────────────────────────
echo ""
echo "========================================="
echo "  Auto-update complete!"
echo "========================================="
echo ""
echo "  New kernel: $(uname -r)"
echo "  Package:    $PKG_FILE"
echo ""
echo "  Next steps:"
echo "    1. Reboot"
echo "    2. Select 'Linux Flatten' in Limine"
echo "    3. Run ./test-kernel.sh to verify"
echo "========================================="
