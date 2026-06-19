#!/usr/bin/env bash
# linux-flatten.sh — Unified CLI for linux-flatten kernel
#
# Single entry point for all operations:
#   linux-flatten.sh update    — Check upstream, rebuild, install
#   linux-flatten.sh build     — Apply optimizations and build package
#   linux-flatten.sh install   — Install built package
#   linux-flatten.sh verify    — Verify running kernel
#   linux-flatten.sh rollback  — Restore original state
#
# Options for build:
#   --optimizations safe|recommended|full|none
#   --target generic|x86-64-v2|x86-64-v3
#   --scheduler flat|none

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ─── Defaults ──────────────────────────────────────────────────
KERNEL_BRANCH="sched/flat"
KERNEL_REPO="https://git.kernel.org/pub/scm/linux/kernel/git/peterz/queue.git"
SRC_DIR="src"
PKG_NAME="linux-flatten"
OPTIMIZATIONS="safe"
TARGET="generic"
SCHEDULER="flat"
BUILD_ONLY=false
NO_INSTALL=false

# ─── Color helpers ─────────────────────────────────────────────
info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; }
step()  { echo -e "${CYAN}==>${NC} $1"; }
header() {
    echo ""
    echo -e "${BOLD}=========================================${NC}"
    echo -e "${BOLD}  $1${NC}"
    echo -e "${BOLD}=========================================${NC}"
    echo ""
}

# ─── Usage ─────────────────────────────────────────────────────
usage() {
    cat <<EOF
${BOLD}linux-flatten.sh${NC} — Unified CLI for linux-flatten kernel

${BOLD}Commands:${NC}
  update      Check upstream, rebuild if new version found, install
  build       Apply optimizations and build package (no install)
  install     Install the built package
  verify      Verify running linux-flatten kernel
  rollback    Restore original kernel/config state
  help        Show this help

${BOLD}Build Options:${NC}
  --optimizations LEVEL   Optimization level:
                            safe         — Safe optimizations (default)
                            recommended  — Safe + recommended
                            full         — Everything including experimental
                            none         — No optimizations, just base config
  --target ARCH            CPU target:
                            generic      — x86-64 v1, works everywhere (default)
                            x86-64-v2    — Sandy Bridge+ features
                            x86-64-v3    — Haswell+ features
  --scheduler TYPE         Scheduler patch:
                            flat         — sched/flat (default)
                            none         — No scheduler patch
  --build-only             Build but don't install
  --no-install             Same as --build-only

${BOLD}Examples:${NC}
  ./linux-flatten.sh update                       # Full update cycle
  ./linux-flatten.sh build --optimizations full   # Build with all opts
  ./linux-flatten.sh build --target x86-64-v2     # Optimized for v2
  ./linux-flatten.sh install                      # Install existing build
  ./linux-flatten.sh verify                       # Check current kernel
  ./linux-flatten.sh rollback                     # Restore original

EOF
    exit 0
}

# ─── Parse arguments ───────────────────────────────────────────
COMMAND=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        update|build|install|verify|rollback|help)
            COMMAND="$1"
            shift
            ;;
        --optimizations)
            OPTIMIZATIONS="$2"
            shift 2
            ;;
        --target)
            TARGET="$2"
            shift 2
            ;;
        --scheduler)
            SCHEDULER="$2"
            shift 2
            ;;
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --no-install)
            NO_INSTALL=true
            shift
            ;;
        *)
            err "Unknown option: $1"
            echo "Run './linux-flatten.sh help' for usage."
            exit 1
            ;;
    esac
done

[ -z "$COMMAND" ] && usage
[ "$COMMAND" = "help" ] && usage

# ─── Prerequisites check ───────────────────────────────────────
check_prerequisites() {
    local missing=()
    for cmd in git make makepkg zcat gzip; do
        command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        err "Missing required tools: ${missing[*]}"
        echo "Install on Arch: sudo pacman -S base-devel git"
        exit 1
    fi
}

# ─── Get current installed version ─────────────────────────────
get_installed_version() {
    if pacman -Q "$PKG_NAME" 2>/dev/null | grep -q "$PKG_NAME"; then
        pacman -Q "$PKG_NAME" 2>/dev/null | awk '{print $2}'
    else
        echo "not_installed"
    fi
}

# ─── Get latest upstream version ───────────────────────────────
get_upstream_version() {
    local src_path="$SRC_DIR/linux-flatten"
    if [ ! -d "$src_path" ]; then
        echo "not_cloned"
        return
    fi
    cd "$src_path"
    local head
    head=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    cd "$SCRIPT_DIR"
    echo "$head"
}

# ─── Command: update ──────────────────────────────────────────
cmd_update() {
    header "Update linux-flatten"

    check_prerequisites

    local installed
    installed=$(get_installed_version)
    info "Installed version: $installed"

    # Clone or fetch upstream
    local src_path="$SRC_DIR/linux-flatten"
    if [ ! -d "$src_path" ]; then
        step "Cloning kernel source..."
        mkdir -p "$SRC_DIR"
        git clone --depth=1 --single-branch -b "$KERNEL_BRANCH" \
            "$KERNEL_REPO" "$src_path"
        info "Cloned to $src_path"
    else
        step "Fetching latest from upstream..."
        cd "$src_path"
        local old_head
        old_head=$(git rev-parse --short HEAD)
        git fetch origin "$KERNEL_BRANCH" --depth=1 2>/dev/null
        git reset --hard "origin/$KERNEL_BRANCH" 2>/dev/null
        local new_head
        new_head=$(git rev-parse --short HEAD)
        cd "$SCRIPT_DIR"

        if [ "$old_head" = "$new_head" ]; then
            info "Already up-to-date (commit: $new_head)"
            if [ "$installed" != "not_installed" ]; then
                info "Installed package matches. No update needed."
                return 0
            fi
            info "Package not installed. Proceeding to build..."
        else
            info "New version found: $old_head → $new_head"
            info "Proceeding to build..."
        fi
    fi

    # Delegate to build
    cmd_build

    # Install unless --build-only
    if ! $BUILD_ONLY && ! $NO_INSTALL; then
        cmd_install
    else
        local pkg_file
        pkg_file=$(ls -t "$PKG_NAME"-*.pkg.tar.zst 2>/dev/null | head -1)
        if [ -n "$pkg_file" ]; then
            info "Build complete. Install manually:"
            echo "  sudo pacman -U $pkg_file"
        fi
    fi
}

# ─── Command: build ───────────────────────────────────────────
cmd_build() {
    header "Build linux-flatten"

    check_prerequisites

    # Ensure source exists
    local src_path="$SRC_DIR/linux-flatten"
    if [ ! -d "$src_path" ]; then
        step "Cloning kernel source..."
        mkdir -p "$SRC_DIR"
        git clone --depth=1 --single-branch -b "$KERNEL_BRANCH" \
            "$KERNEL_REPO" "$src_path"
    fi

    # Prepare working config
    step "Preparing kernel configuration..."
    local work_config="$SRC_DIR/.config"
    cp /proc/config.gz "$SRC_DIR/config.gz" 2>/dev/null || true

    if [ -f "$SRC_DIR/config.gz" ]; then
        zcat "$SRC_DIR/config.gz" > "$work_config"
    else
        cd "$src_path"
        make defconfig
        cp .config "$work_config"
        cd "$SCRIPT_DIR"
    fi

    # Apply base optimizations via scripts/config
    step "Applying optimizations (level: $OPTIMIZATIONS, target: $TARGET)..."

    # Always apply these
    cd "$src_path"

    # ── Safe optimizations ──────────────────────────────────────
    scripts/config -d CC_OPTIMIZE_FOR_PERFORMANCE 2>/dev/null || true
    scripts/config -e CC_OPTIMIZE_FOR_PERFORMANCE_O3 2>/dev/null || true
    scripts/config -d HZ_300 2>/dev/null || true
    scripts/config -e HZ_1000 2>/dev/null || true
    scripts/config --set-val HZ 1000 2>/dev/null || true
    scripts/config -e PREEMPT_LAZY 2>/dev/null || true
    scripts/config -d PREEMPT 2>/dev/null || true
    scripts/config -m TCP_CONG_BBR3 2>/dev/null || true
    scripts/config -e TRANSPARENT_HUGEPAGE_MADVISE 2>/dev/null || true
    scripts/config -d TRANSPARENT_HUGEPAGE_ALWAYS 2>/dev/null || true
    scripts/config -d MODULE_COMPRESS_XZ 2>/dev/null || true
    scripts/config -e MODULE_COMPRESS_ZSTD 2>/dev/null || true
    scripts/config -d NUMA 2>/dev/null || true
    scripts/config -d NUMA_BALANCING 2>/dev/null || true
    scripts/config -d DEBUG_INFO 2>/dev/null || true
    scripts/config -d DEBUG_INFO_DWARF4 2>/dev/null || true
    scripts/config -d DEBUG_INFO_DWARF5 2>/dev/null || true
    scripts/config -e DEBUG_INFO_NONE 2>/dev/null || true
    scripts/config -d SECURITY_YAMA 2>/dev/null || true
    scripts/config -d SECURITY_LANDLOCK 2>/dev/null || true
    scripts/config -d SECURITY_SELINUX 2>/dev/null || true
    scripts/config -d SECURITY_SMACK 2>/dev/null || true
    scripts/config -d SECURITY_APPARMOR 2>/dev/null || true
    scripts/config -d CONFIG_FTRACE 2>/dev/null || true
    scripts/config -d CONFIG_KPROBES 2>/dev/null || true
    scripts/config -d CONFIG_KGDB 2>/dev/null || true
    scripts/config -d CONFIG_KEXEC 2>/dev/null || true
    scripts/config -d CONFIG_CRASH_DUMP 2>/dev/null || true
    scripts/config -d CONFIG_EFI_MIXED 2>/dev/null || true
    scripts/config -d SCHED_CLASS_EXT 2>/dev/null || true
    scripts/config -d MODULE_SIG_SHA512 2>/dev/null || true
    scripts/config -e MODULE_SIG_SHA256 2>/dev/null || true
    scripts/config -d GCC_PLUGINS 2>/dev/null || true
    scripts/config -d GCC_PLUGIN_LATENT_ENTROPY 2>/dev/null || true

    # ── Recommended optimizations ───────────────────────────────
    if [ "$OPTIMIZATIONS" = "recommended" ] || [ "$OPTIMIZATIONS" = "full" ]; then
        scripts/config -d CONFIG_GENERIC_CPU 2>/dev/null || true
        scripts/config -e CONFIG_MNATIVE 2>/dev/null || true
        scripts/config --set-val CONFIG_NR_CPUS 8 2>/dev/null || true
        scripts/config -d CONFIG_MAXSMP 2>/dev/null || true
        scripts/config -d CONFIG_NUMA 2>/dev/null || true
        info "Recommended optimizations applied"
    fi

    # ── Full optimizations ──────────────────────────────────────
    if [ "$OPTIMIZATIONS" = "full" ]; then
        scripts/config -e CONFIG_DEBUG_INFO_COMPRESSED_ZSTD 2>/dev/null || true
        scripts/config -d CONFIG_DEBUG_INFO_COMPRESSED_NONE 2>/dev/null || true
        info "Full optimizations applied"
    fi

    # ── CPU target ─────────────────────────────────────────────
    case "$TARGET" in
        x86-64-v2)
            scripts/config --set-val CONFIG_X86_64_VERSION 2 2>/dev/null || true
            info "Target: x86-64-v2 (Sandy Bridge+)"
            ;;
        x86-64-v3)
            scripts/config --set-val CONFIG_X86_64_VERSION 3 2>/dev/null || true
            info "Target: x86-64-v3 (Haswell+)"
            ;;
        *)
            info "Target: generic x86-64 (works on all CPUs)"
            ;;
    esac

    # ── Finalize config ─────────────────────────────────────────
    scripts/config --set-str CONFIG_LOCALVERSION "-flatten" 2>/dev/null || true
    make olddefconfig

    # Build
    step "Building kernel (this may take 1-3 hours)..."
    local nproc_val
    nproc_val=$(nproc)
    info "Using $nproc_val parallel jobs"

    if make -j"$nproc_val" bzImage modules 2>&1 | tail -5; then
        info "Kernel build successful"
    else
        err "Kernel build failed!"
        exit 1
    fi

    # Get version
    local kernel_version
    kernel_version=$(make kernelrelease)
    info "Built kernel: $kernel_version"

    # Build package
    step "Building Arch package..."
    rm -rf pkg
    make INSTALL_MOD_PATH=pkg/usr modules_install 2>&1 | tail -3
    install -Dm644 arch/x86/boot/bzImage pkg/boot/vmlinuz-"$PKG_NAME"
    mkdir -p pkg/etc/mkinitcpio.d
    cat > "pkg/etc/mkinitcpio.d/$PKG_NAME.preset" <<PRESET
ALL_kver="/boot/vmlinuz-$PKG_NAME"
ALL_config="/etc/mkinitcpio.conf"
default_image="/boot/initramfs-$PKG_NAME.img"
PRESET
    install -Dm644 linux-flatten.install pkg/usr/share/libalpm/scripts/linux-flatten.install
    echo "$kernel_version" > pkg/usr/share/$PKG_NAME/kernelrelease

    # Create package
    cd pkg
    tar -czf "../${PKG_NAME}-${kernel_version}-x86_64.tar.gz" .
    cd ..

    # Also create pacman package via makepkg if PKGBUILD exists
    if [ -f PKGBUILD ]; then
        # Update PKGBUILD version
        sed -i "s/^pkgver=.*/pkgver=${kernel_version}/" PKGBUILD 2>/dev/null || true
        makepkg -sf --noconfirm 2>&1 | tail -5 || true
    fi

    local pkg_files
    pkg_files=$(ls -lh "$PKG_NAME"-*.* 2>/dev/null | grep -v "\.sha" | awk '{print $5, $9}')
    info "Package built!"
    echo ""
    echo "$pkg_files"
    echo ""
    info "Install with: sudo pacman -U $PKG_NAME-*.pkg.tar.zst"

    cd "$SCRIPT_DIR"
}

# ─── Command: install ─────────────────────────────────────────
cmd_install() {
    header "Install linux-flatten"

    local pkg_file
    pkg_file=$(ls -t "$PKG_NAME"-*.pkg.tar.zst 2>/dev/null | head -1)

    if [ -z "$pkg_file" ]; then
        err "No package found. Run './linux-flatten.sh build' first."
        exit 1
    fi

    info "Installing: $pkg_file"

    if [ "$(id -u)" -ne 0 ]; then
        sudo pacman -U --noconfirm "$pkg_file"
    else
        pacman -U --noconfirm "$pkg_file"
    fi

    info "Package installed successfully!"
    echo ""
    info "Next steps:"
    echo "  1. Reboot: sudo reboot"
    echo "  2. Select 'Linux Flatten' in bootloader"
    echo "  3. Verify: ./linux-flatten.sh verify"
}

# ─── Command: verify ──────────────────────────────────────────
cmd_verify() {
    header "Verify linux-flatten"

    local current
    current=$(uname -r)
    info "Running kernel: $current"

    if echo "$current" | grep -q "flatten"; then
        info "✓ Running linux-flatten kernel"
    else
        err "✗ Not running linux-flatten kernel"
        echo "  Current: $current"
        echo "  Expected: *-flatten"
    fi

    # Check boot files
    echo ""
    info "Boot files:"
    if [ -f "/boot/vmlinuz-$PKG_NAME" ]; then
        info "  ✓ /boot/vmlinuz-$PKG_NAME"
    else
        err "  ✗ /boot/vmlinuz-$PKG_NAME missing"
    fi

    if [ -f "/boot/initramfs-$PKG_NAME.img" ]; then
        info "  ✓ /boot/initramfs-$PKG_NAME.img"
    else
        err "  ✗ /boot/initramfs-$PKG_NAME.img missing"
    fi

    if [ -f "/etc/mkinitcpio.d/$PKG_NAME.preset" ]; then
        info "  ✓ /etc/mkinitcpio.d/$PKG_NAME.preset"
    else
        err "  ✗ /etc/mkinitcpio.d/$PKG_NAME.preset missing"
    fi

    # Check kernel config
    echo ""
    info "Kernel config:"
    if [ -f /proc/config.gz ]; then
        if zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_PREEMPT_LAZY=y"; then
            info "  ✓ PREEMPT_LAZY=y"
        else
            warn "  ✗ PREEMPT_LAZY not enabled"
        fi

        if zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_TCP_CONG_BBR3=m"; then
            info "  ✓ TCP_CONG_BBR3=m"
        else
            warn "  ✗ BBR3 not enabled"
        fi

        if zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_HZ_1000=y"; then
            info "  ✓ HZ=1000"
        else
            local hz
            hz=$(zcat /proc/config.gz 2>/dev/null | grep CONFIG_HZ= | head -1)
            warn "  ✗ HZ not 1000 ($hz)"
        fi
    else
        warn "  /proc/config.gz not available (cannot verify runtime config)"
    fi

    # Check install script ran
    echo ""
    info "Install script:"
    if [ -f "/usr/share/libalpm/scripts/linux-flatten.install" ]; then
        info "  ✓ Install script present"
    else
        warn "  ✗ Install script not found (package may be older)"
    fi

    echo ""
    info "All checks complete."
}

# ─── Command: rollback ─────────────────────────────────────────
cmd_rollback() {
    header "Rollback linux-flatten"

    if pacman -Q "$PKG_NAME" 2>/dev/null | grep -q "$PKG_NAME"; then
        step "Removing $PKG_NAME package..."
        if [ "$(id -u)" -ne 0 ]; then
            sudo pacman -Rns --noconfirm "$PKG_NAME"
        else
            pacman -Rns --noconfirm "$PKG_NAME"
        fi
        info "Package removed"
    else
        info "Package not installed, nothing to remove"
    fi

    # Clean up
    step "Cleaning up..."
    rm -rf pkg/ src/ "$PKG_NAME"-*.* *.log
    info "Cleanup done"

    echo ""
    info "Rollback complete. Reboot to use previous kernel."
}

# ─── Execute command ───────────────────────────────────────────
case "$COMMAND" in
    update)   cmd_update ;;
    build)    cmd_build ;;
    install)  cmd_install ;;
    verify)   cmd_verify ;;
    rollback)  cmd_rollback ;;
    *)        usage ;;
esac
