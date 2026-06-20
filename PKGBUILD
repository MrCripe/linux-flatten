# Maintainer: linux-flatten contributors
pkgbase=linux-flatten
pkgname=(
  "$pkgbase"
  "$pkgbase-headers"
)
_major=7.1
_minor=0
pkgver=${_major}.${_minor}
pkgrel=1
arch=('x86_64')
url="https://git.kernel.org/pub/scm/linux/kernel/git/peterz/queue.git"
license=('GPL2')
depends=('coreutils' 'kmod' 'mkinitcpio')
makedepends=(
  bc
  binutils
  cpio
  fakeroot
  gettext
  glibc
  libelf
  libgcc
  openssl
  pahole
  perl
  python
  tar
  xxhash
  xz
  zlib
  zstd
)
optdepends=(
  'linux-firmware: firmware images needed for some devices'
  'limine: bootloader support'
  'wireless-regdb: to set the correct wireless channels of your country'
  'modprobed-db: Keeps track of EVERY kernel module that has ever been probed'
)
options=('!strip' '!debug' '!lto')
install=linux-flatten.install

_kernel_branch="sched/flat"
_kernel_repo="https://git.kernel.org/pub/scm/linux/kernel/git/peterz/queue.git"
_srcname="linux-flatten"

_die() { error "$@"; exit 1; }

prepare() {
    if [ ! -d "$_srcname" ]; then
        git clone --depth=1 --single-branch -b "$_kernel_branch" \
            "$_kernel_repo" "$_srcname"
    fi

    cd "$_srcname"

    # Detect version from kernel source and update pkgver
    local kver
    kver=$(make kernelrelease | sed 's/-flatten//')
    pkgver="$kver"
    pkgrel=1

    echo "Building version: ${pkgbase}-${pkgver}"

    echo "Setting version..."
    echo "-$pkgrel" > localversion.10-pkgrel
    echo "${pkgbase#linux}" > localversion.20-pkgname

    echo "Setting config..."

    # Start with defconfig then enable ALL modules
    make defconfig
    make allmodconfig

    # ── CPU target: Xeon E31270 (Sandy Bridge) ──
    # MCORE2 = Sandy Bridge, MNATIVE = auto-detect CPU features
    scripts/config -d GENERIC_CPU
    scripts/config -e MCORE2
    scripts/config -e MNATIVE
    scripts/config -d X86_NATIVE_CPU
    info "CPU: Xeon E31270 (Sandy Bridge, MCORE2 + MNATIVE)"

    # ── Compiler: -O3 ──
    scripts/config -d CC_OPTIMIZE_FOR_PERFORMANCE
    scripts/config -e CC_OPTIMIZE_FOR_PERFORMANCE_O3

    # ── Timer: 1000 Hz ──
    scripts/config -d HZ_300
    scripts/config -e HZ_1000
    scripts/config --set-val HZ 1000

    # ── Preempt Lazy ──
    scripts/config -e PREEMPT_LAZY
    scripts/config -d PREEMPT

    # ── BBR3 ──
    scripts/config -m TCP_CONG_BBR3

    # ── THP: MADVISE ──
    scripts/config -e TRANSPARENT_HUGEPAGE_MADVISE
    scripts/config -d TRANSPARENT_HUGEPAGE_ALWAYS

    # ── Module compression: ZSTD ──
    scripts/config -d MODULE_COMPRESS_XZ
    scripts/config -e MODULE_COMPRESS_ZSTD

    # ── NUMA: off ──
    scripts/config -d NUMA
    scripts/config -d NUMA_BALANCING

    # ── Debug info: none ──
    scripts/config -d DEBUG_INFO
    scripts/config -d DEBUG_INFO_DWARF4
    scripts/config -d DEBUG_INFO_DWARF5
    scripts/config -e DEBUG_INFO_NONE

    # ── Trim LSMs ──
    scripts/config -d SECURITY_YAMA
    scripts/config -d SECURITY_LANDLOCK
    scripts/config -d SECURITY_SELINUX
    scripts/config -d SECURITY_SMACK
    scripts/config -d SECURITY_APPARMOR

    # ── Disable unnecessary features ──
    scripts/config -d CONFIG_FTRACE
    scripts/config -d CONFIG_KPROBES
    scripts/config -d CONFIG_KGDB
    scripts/config -d CONFIG_KEXEC
    scripts/config -d CONFIG_CRASH_DUMP
    scripts/config -d CONFIG_EFI_MIXED
    scripts/config -d SCHED_CLASS_EXT

    # ── Module signature: SHA256 ──
    scripts/config -d MODULE_SIG_SHA512
    scripts/config -e MODULE_SIG_SHA256

    # ── Disable GCC plugins (latent_entropy incompatible with new GCC) ──
    scripts/config -d GCC_PLUGINS
    scripts/config -d GCC_PLUGIN_LATENT_ENTROPY

    # ── NR_CPUS: 8 (4 cores / 8 threads on Xeon E31270) ──
    scripts/config --set-val CONFIG_NR_CPUS 8
    scripts/config -d CONFIG_MAXSMP
    info "NR_CPUS: 8, MAXSMP: off"

    # ── Local version ──
    scripts/config --set-str CONFIG_LOCALVERSION "-flatten"

    # Finalize
    make olddefconfig

    # Show version
    make -s kernelrelease > version
    echo "Prepared $pkgbase version $(<version)"
}

build() {
    cd "$_srcname"
    make -j"$(nproc)" all
}

_package() {
    pkgdesc="Linux kernel with sched/flat patch + desktop optimizations"
    provides=(VIRTUALBOX-GUEST-MODULES WIREGUARD-MODULE KSMBD-MODULE V4L2LOOPBACK-MODULE NTSYNC-MODULE VHBA-MODULE)

    cd "$_srcname"

    local modulesdir="$pkgdir/usr/lib/modules/$(<version)"

    echo "Installing boot image..."
    install -Dm644 "$(make -s image_name)" "$modulesdir/vmlinuz"

    echo "$pkgbase" | install -Dm644 /dev/stdin "$modulesdir/pkgbase"

    echo "Installing modules..."
    ZSTD_CLEVEL=19 make INSTALL_MOD_PATH="$pkgdir/usr" INSTALL_MOD_STRIP=1 \
        DEPMOD=/doesnt/exist modules_install

    # Remove build links
    rm "$modulesdir"/build 2>/dev/null || true
}

_package-headers() {
    pkgdesc="Headers and scripts for building modules for the $pkgbase kernel"
    depends=(binutils glibc libelf libgcc openssl pahole xxhash zlib zstd "$pkgbase")
    provides=(LINUX-HEADERS)

    cd "$_srcname"
    local builddir="$pkgdir/usr/lib/modules/$(<version)/build"

    echo "Installing build files..."
    install -Dt "$builddir" -m644 .config Makefile Module.symvers System.map \
        localversion.* version vmlinux

    install -Dt "$builddir/kernel" -m644 kernel/Makefile
    install -Dt "$builddir/arch/x86" -m644 arch/x86/Makefile
    cp -t "$builddir" -a scripts
    ln -srt "$builddir" "$builddir/scripts/gdb/vmlinux-gdb.py"

    install -Dt "$builddir/tools/objtool" tools/objtool/objtool

    if [ -f tools/bpf/resolve_btfids/resolve_btfids ]; then
        install -Dt "$builddir/tools/bpf/resolve_btfids" tools/bpf/resolve_btfids/resolve_btfids
    fi

    echo "Installing headers..."
    cp -t "$builddir" -a include
    cp -t "$builddir/arch/x86" -a arch/x86/include
    install -Dt "$builddir/arch/x86/kernel" -m644 arch/x86/kernel/asm-offsets.s

    install -Dt "$builddir/drivers/md" -m644 drivers/md/*.h
    install -Dt "$builddir/net/mac80211" -m644 net/mac80211/*.h
    install -Dt "$builddir/drivers/media/i2c" -m644 drivers/media/i2c/msp3400-driver.h
    install -Dt "$builddir/drivers/media/usb/dvb-usb" -m644 drivers/media/usb/dvb-usb/*.h
    install -Dt "$builddir/drivers/media/dvb-frontends" -m644 drivers/media/dvb-frontends/*.h
    install -Dt "$builddir/drivers/media/tuners" -m644 drivers/media/tuners/*.h
    install -Dt "$builddir/drivers/iio/common/hid-sensors" -m644 drivers/iio/common/hid-sensors/*.h

    echo "Installing KConfig files..."
    find . -name 'Kconfig*' -exec install -Dm644 {} "$builddir/{}" \;

    if ls rust/*.rmeta 1>/dev/null 2>&1; then
        install -Dt "$builddir/rust" -m644 rust/*.rmeta
    fi

    if ls rust/*.so 1>/dev/null 2>&1; then
        install -Dt "$builddir/rust" rust/*.so
    fi

    echo "Installing unstripped VDSO..."
    make INSTALL_MOD_PATH="$pkgdir/usr" vdso_install link=

    echo "Removing unneeded architectures..."
    local arch
    for arch in "$builddir"/arch/*/; do
        [[ $arch = */x86/ ]] && continue
        rm -r "$arch"
    done

    rm -r "$builddir/Documentation"

    find -L "$builddir" -type l -printf 'Removing %P\n' -delete

    find "$builddir" -type f -name '*.o' -printf 'Removing %P\n' -delete

    echo "Stripping build tools..."
    local file
    while read -rd '' file; do
        case "$(file -Sib "$file")" in
            application/x-sharedlib\;*)      strip -v $STRIP_SHARED "$file" ;;
            application/x-archive\;*)        strip -v $STRIP_STATIC "$file" ;;
            application/x-executable\;*)     strip -v $STRIP_BINARIES "$file" ;;
            application/x-pie-executable\;*) strip -v $STRIP_SHARED "$file" ;;
        esac
    done < <(find "$builddir" -type f -perm -u+x ! -name vmlinux -print0)

    strip -v $STRIP_STATIC "$builddir/vmlinux"

    echo "Adding symlink..."
    mkdir -p "$pkgdir/usr/src"
    ln -sr "$builddir" "$pkgdir/usr/src/$pkgbase"
}

for _p in "${pkgname[@]}"; do
    eval "package_$_p() {
    $(declare -f "_package${_p#$pkgbase}")
    _package${_p#$pkgbase}
    }"
done

source=()
sha256sums=()
