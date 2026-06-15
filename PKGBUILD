# Maintainer: Your Name <your.email@example.com>
pkgname=linux-flatten
pkgver=7.2.0.flat
pkgrel=1
pkgdesc="Linux kernel with Peter Zijlstra's sched/flat patch + CachyOS-inspired optimizations"
arch=('x86_64')
url="https://git.kernel.org/pub/scm/linux/kernel/git/peterz/queue.git"
license=('GPL2')
depends=('mkinitcpio' 'coreutils' 'linux-firmware' 'kmod')
makedepends=('git' 'gcc' 'make' 'bc' 'kmod' 'inetutils' 'cpio' 'openssl' 'elfutils')
optdepends=('limine: bootloader support for auto-entry'
            'earlyoom: early OOM killer to prevent system freeze under memory pressure')
options=('!strip' '!debug')
source=('config.gz'
        'linux-flatten.install')
sha256sums=('SKIP'
            'SKIP')
validpgpkeys=()
install=linux-flatten.install

# Use a specific commit for reproducibility
_kernel_commit="sched/flat"

_config_opt() { scripts/config "$@"; }

prepare() {
    if [ ! -d "$srcdir/linux-flatten" ]; then
        git clone --depth=1 --single-branch -b "$_kernel_commit" \
            "https://git.kernel.org/pub/scm/linux/kernel/git/peterz/queue.git" \
            "$srcdir/linux-flatten"
    fi
    cd "$srcdir/linux-flatten"

    # Use config.gz from source array (copied to srcdir by makepkg)
    if [ -f "$srcdir/config.gz" ]; then
        zcat "$srcdir/config.gz" > .config
    else
        echo "ERROR: config.gz not found in \$srcdir. Please place config.gz in the package root."
        exit 1
    fi

    # ---- УЛУЧШЕНИЯ из CachyOS + оптимизации под Xeon E31270 ----
    _config_opt -d CC_OPTIMIZE_FOR_PERFORMANCE
    _config_opt -e CC_OPTIMIZE_FOR_PERFORMANCE_O3
    _config_opt -d HZ_300
    _config_opt -e HZ_1000
    _config_opt --set-val HZ 1000
    _config_opt -e PREEMPT_LAZY
    _config_opt -d PREEMPT
    _config_opt -m TCP_CONG_BBR3
    _config_opt -e TRANSPARENT_HUGEPAGE_MADVISE
    _config_opt -d TRANSPARENT_HUGEPAGE_ALWAYS
    _config_opt -d MODULE_COMPRESS_XZ
    _config_opt -e MODULE_COMPRESS_ZSTD
    _config_opt -d NUMA
    _config_opt -d NUMA_BALANCING
    _config_opt -d SCHED_CLASS_EXT
    _config_opt -d EFI_MIXED

    make olddefconfig
    scripts/config --set-str CONFIG_LOCALVERSION "-flatten"
    make kernelrelease > "$srcdir/kernelrelease.txt"
}

build() {
    cd "$srcdir/linux-flatten"
    make -j$(nproc) bzImage modules
}

package() {
    cd "$srcdir/linux-flatten"
    make INSTALL_MOD_PATH="$pkgdir/usr" modules_install
    install -Dm644 arch/x86/boot/bzImage "$pkgdir/boot/vmlinuz-$pkgname"
    install -Dm644 "$srcdir/kernelrelease.txt" "$pkgdir/usr/share/$pkgname/kernelrelease"
    mkdir -p "$pkgdir/etc/mkinitcpio.d"
    cat > "$pkgdir/etc/mkinitcpio.d/$pkgname.preset" <<FOO
ALL_kver="/boot/vmlinuz-$pkgname"
ALL_config="/etc/mkinitcpio.conf"
default_image="/boot/initramfs-$pkgname.img"
FOO
    # Install the install script
    install -Dm644 "$srcdir/linux-flatten.install" "$pkgdir/usr/share/libalpm/scripts/linux-flatten.install"
}