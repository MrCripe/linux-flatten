# linux-flatten

Linux kernel with `sched/flat` patch by Peter Zijlstra — **universal x86-64, works on all CPUs** (Intel, AMD, no vendor lock-in).

Based on [`sched/flat` branch](https://git.kernel.org/pub/scm/linux/kernel/git/peterz/queue.git) from kernel.org.

## Quick Install (from releases)

Pre-built packages: [GitHub Releases](https://github.com/MrCripe/linux-flatten/releases)

### Arch Linux

```bash
# Download latest release
gh release download --repo MrCripe/linux-flatten --pattern "linux-flatten-*.pkg.tar.zst"

# Install kernel + headers
sudo pacman -U linux-flatten-*.pkg.tar.zst

# Update initramfs (automatic via install hook, but manual if needed)
sudo mkinitcpio -p linux-flatten

# Reboot
sudo reboot
```

### Other distros

```bash
# Download release tarball from GitHub Releases
tar xf linux-flatten-*.pkg.tar.zst -C /

# Copy kernel and generate initramfs
cp /usr/lib/modules/*/vmlinuz /boot/vmlinuz-linux-flatten
mkinitcpio -p linux-flatten   # or: dracut --regenerate-all

# Add bootloader entry (systemd-boot / GRUB / Limine)
# linux /vmlinuz-linux-flatten root=UUID=<your-root-uuid> rw
# initrd /initramfs-linux-flatten.img

sudo reboot
```

### Verify

```bash
uname -r
# Should show: <version>-flatten

cat /proc/version
# Should contain "flatten"

# Verify sched/flat is active
cat /sys/kernel/debug/sched/features

# Verify config
zcat /proc/config.gz | grep -E "SCHED_FLATTEN|GENERIC_CPU|PREEMPT_LAZY"
```

## Build from source

```bash
git clone https://github.com/MrCripe/linux-flatten.git
cd linux-flatten
makepkg -sf
```

## Features

| Feature | Value | Notes |
|---------|-------|-------|
| CPU | GENERIC_CPU | Works on all x86-64 (Intel, AMD) |
| Scheduler | sched/flat | Flattened runqueue by Peter Zijlstra |
| Compiler | -O3 | Maximum optimization |
| Timer | HZ=1000 | High frequency for responsive desktop |
| Preempt | PREEMPT_LAZY | Minimal latency switching |
| TCP | BBR | Modern congestion control |
| THP | MADVISE | Safe huge pages (not forced) |
| Modules | ZSTD compressed | Fast loading |
| SMP | MAXSMP | Up to 8192 CPUs supported |
| Debug | None | Minimal size |
| Config | allmodconfig | All drivers as modules |

## Compatibility

- **Intel**: Core 2 and newer, Xeon, Atom — all generations
- **AMD**: Ryzen, EPYC, Athlon — all generations
- **Arch Linux**: fully supported, install hook included
- **Other distros**: manual installation (see above)

## License

GPLv2
