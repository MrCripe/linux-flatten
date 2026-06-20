# linux-flatten-my

Linux kernel with `sched/flat` patch by Peter Zijlstra — **optimized for Intel Xeon E31270 (Sandy Bridge)**.

## Quick Install (from releases)

Pre-built packages: [GitHub Releases](https://github.com/MrCripe/linux-flatten-my/releases)

### Download & Install

```bash
# Download latest release
gh release download --repo MrCripe/linux-flatten-my --pattern "linux-flatten-*.pkg.tar.zst"

# Install kernel + headers
sudo pacman -U linux-flatten-*.pkg.tar.zst

# Update initramfs
sudo mkinitcpio -p linux-flatten

# Reboot
sudo reboot
```

### Verify

```bash
uname -r
cat /proc/version
zcat /proc/config.gz | grep -E "PREEMPT_LAZY|HZ_1000|BBR3|MCORE2"
```

## Build from source

```bash
git clone https://github.com/MrCripe/linux-flatten-my.git
cd linux-flatten-my
makepkg -sf
```

## Optimizations (Xeon E31270)

| Feature | Value |
|---------|-------|
| CPU | MCORE2 + MNATIVE (Sandy Bridge) |
| Compiler | -O3 |
| Timer | HZ=1000 |
| Preempt | PREEMPT_LAZY |
| TCP | BBR3 |
| THP | MADVISE |
| Modules | ZSTD compressed |
| NR_CPUS | 8 (4 cores / 8 threads) |
| Debug | None |
| Config | allmodconfig (ALL drivers as modules) |

## License

GPLv2
