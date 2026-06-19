# linux-flatten

Linux kernel with `sched/flat` patch by Peter Zijlstra + desktop optimizations.

**Universal kernel** — compatible with all x86-64 processors (Intel Core 2+, AMD Athlon 64+). Does not require `-march=native`.

---

## Quick Install (from releases)

Pre-built packages: [GitHub Releases](https://github.com/MrCripe/linux-flatten/releases)

### Download packages

```bash
# Via GitHub CLI
gh release download --repo MrCripe/linux-flatten --pattern "linux-flatten-*.pkg.tar.zst"

# Or manually — replace VERSION with the desired one
VERSION="7.1.0-1"
wget "https://github.com/MrCripe/linux-flatten/releases/download/${VERSION}/linux-flatten-${VERSION}-x86_64.pkg.tar.zst"
wget "https://github.com/MrCripe/linux-flatten/releases/download/${VERSION}/linux-flatten-${VERSION}-headers-x86_64.pkg.tar.zst"
```

### Install

```bash
# Install kernel + headers
sudo pacman -U linux-flatten-*.pkg.tar.zst

# Update initramfs
sudo mkinitcpio -p linux-flatten

# Update bootloader (Limine)
sudo limine-scan /boot

# Reboot
sudo reboot
```

> **Note:** The `linux-flatten` package contains the kernel, all modules, and firmware. The `linux-flatten-headers` package is only needed for building external modules (dkms, nvidia, etc.). If you don't build modules — you can install only the main package.

### Verify after boot

```bash
uname -r
# Output: 7.1.0-flatten

cat /proc/version
# Should contain "-flatten"

# Check that optimizations are active
zcat /proc/config.gz | grep -E "PREEMPT_LAZY|HZ_1000|BBR3"
```

---

## Build from source

Requirements: Arch Linux with `base-devel`, `git`, `bc`

```bash
# Clone repository
git clone https://github.com/MrCripe/linux-flatten.git
cd linux-flatten

# Build and install
./linux-flatten.sh update
```

### Build Options

```bash
# Build with full optimizations
./linux-flatten.sh build --optimizations full

# Optimize for specific CPU (x86-64-v2 = Sandy Bridge+)
./linux-flatten.sh build --target x86-64-v2

# Build without installing
./linux-flatten.sh build --build-only

# Install already built
./linux-flatten.sh install

# Verify current kernel
./linux-flatten.sh verify

# Rollback to original kernel
./linux-flatten.sh rollback
```

### Optimization Levels

| Level | What's included |
|-------|----------------|
| `safe` | O3, HZ=1000, PREEMPT_LAZY, BBR3, THP MADVISE, ZSTD modules, SHA256 signature, no debug info, trimmed LSMs |
| `recommended` | Safe + CONFIG_MNATIVE, NR_CPUS=8, MAXSMP off |
| `full` | Recommended + ZSTD debug info compression |
| `none` | Base config + sched/flat only |

### CPU Target

| Target | Compatibility |
|--------|--------------|
| `generic` | All x86-64 CPUs (v1+) — default |
| `x86-64-v2` | Sandy Bridge and newer (recommended for most) |
| `x86-64-v3` | Haswell and newer |

---

## What the install script does

After `pacman -U linux-flatten-*.pkg.tar.zst` automatically:
- Creates `/etc/mkinitcpio.d/linux-flatten.preset`
- Generates initramfs (`mkinitcpio -p linux-flatten`)
- Adds/updates Limine entry with `pcie_aspm=performance`

No additional actions needed — just install the package and reboot.

---

## Project Structure

```
linux-flatten/
├── linux-flatten.sh          # Unified CLI (update/build/install/verify/rollback)
├── PKGBUILD                  # Arch Linux package formula
├── linux-flatten.install     # Post-install script (mkinitcpio + Limine)
├── Makefile                  # Build/clean targets
├── .github/workflows/        # CI: build + GitHub Release
└── README.md
```

---

## License

GPLv2 — same as the original Linux kernel.
