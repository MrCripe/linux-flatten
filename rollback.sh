#!/usr/bin/env bash
# rollback.sh — Roll back all changes to original state
#
# Restores:
#   - config.gz from backup
#   - PKGBUILD from backup
#   - linux-flatten.install from backup
#   - Removes optimized config files
#   - Optionally removes the installed package
#
# Usage:
#   ./rollback.sh                  # restore all backed-up files
#   ./rollback.sh --uninstall      # also remove linux-flatten package
#   ./rollback.sh --config-only    # restore only config.gz
#   ./rollback.sh --list           # list available backups
#   ./rollback.sh --help           # show this help

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ─── Parse args ──────────────────────────────────────────────
UNINSTALL=false
CONFIG_ONLY=false
LIST=false

for arg in "$@"; do
    case "$arg" in
        --uninstall) UNINSTALL=true ;;
        --config-only) CONFIG_ONLY=true ;;
        --list) LIST=true ;;
        --help)
            cat <<EOF
Usage: $(basename "$0") [OPTION]

Roll back linux-flatten package changes.

Options:
  --uninstall    Also remove the installed package (sudo)
  --config-only  Restore only config.gz from backup
  --list         List available backup files
  --help         Show this help
EOF
            exit 0
            ;;
    esac
done

# ─── List backups mode ──────────────────────────────────────
if $LIST; then
    echo "Available backups and config files:"
    echo ""
    for f in config.gz.backup PKGBUILD.backup linux-flatten.install.backup config.optimized; do
        if [ -f "$f" ]; then
            size=$(ls -lh "$f" | awk '{print $5}')
            modified=$(ls -lh "$f" | awk '{print $6, $7, $8}')
            echo "  $f  (${size}, ${modified})"
        else
            echo "  $f  (not found)"
        fi
    done
    echo ""
    echo "Use:"
    echo "  ./rollback.sh              - restore all files from backup"
    echo "  ./rollback.sh --config-only - restore config only"
    echo "  ./rollback.sh --uninstall   - restore + remove package"
    exit 0
fi

# ─── Config only mode ───────────────────────────────────────
if $CONFIG_ONLY; then
    if [ -f "config.gz.backup" ]; then
        cp "config.gz.backup" "config.gz"
        info "Restored config.gz from backup"
        # Remove optimized plain-text reference
        rm -f config.optimized
        info "Removed config.optimized"
        exit 0
    else
        err "Backup not found: config.gz.backup"
        exit 1
    fi
fi

# ─── Full rollback ──────────────────────────────────────────
echo ""
echo "========================================="
echo "  Rolling back linux-flatten changes"
echo "========================================="
echo ""

# 1. Restore config.gz
if [ -f "config.gz.backup" ]; then
    cp "config.gz.backup" "config.gz"
    info "Restored config.gz from backup"
    rm -f config.optimized
    info "Removed config.optimized"
else
    warn "Backup not found: config.gz.backup (keeping current config)"
fi

# 2. Restore PKGBUILD
if [ -f "PKGBUILD.backup" ]; then
    cp "PKGBUILD.backup" "PKGBUILD"
    info "Restored PKGBUILD from backup"
else
    warn "Backup not found: PKGBUILD.backup (keeping current)"
fi

# 3. Restore install script
if [ -f "linux-flatten.install.backup" ]; then
    cp "linux-flatten.install.backup" "linux-flatten.install"
    info "Restored linux-flatten.install from backup"
else
    warn "Backup not found: linux-flatten.install.backup (keeping current)"
fi

# 4. Clean up optimized config if present
rm -f .config .config.orig
info "Cleaned up temporary config files"

# 5. Uninstall package (optional)
if $UNINSTALL; then
    echo ""
    info "Checking if linux-flatten is installed..."
    if pacman -Q linux-flatten 2>/dev/null; then
        warn "Removing linux-flatten package..."
        if [ "$(id -u)" -ne 0 ]; then
            sudo pacman -Rns --noconfirm linux-flatten 2>&1 | sed 's/^/  /'
        else
            pacman -Rns --noconfirm linux-flatten 2>&1 | sed 's/^/  /'
        fi
        info "Package linux-flatten removed"
    else
        info "Package linux-flatten is not installed"
    fi
fi

# 6. If booted into linux-flatten, warn user
CURRENT_KERNEL=$(uname -r)
if echo "$CURRENT_KERNEL" | grep -q "flatten"; then
    warn "You are currently running linux-flatten kernel!"
    warn "Rollback to backup kernel in bootloader to complete rollback."
fi

echo ""
echo "========================================="
echo "  Rollback complete!"
echo "========================================="
echo ""
echo "  Files restored from backup."
if $UNINSTALL; then
    echo "  Package removed."
fi
echo ""
echo "  Next steps:"
echo "    1. If you want to rebuild without optimizations:"
echo "       makepkg -sf"
echo "    2. Reboot to apply changes"
echo "========================================="
