# Comparison: CachyOS vs linux-flatten

## Main Comparison Table

| Parameter | CachyOS (base config) | CachyOS (PKGBUILD applied) | Our linux-flatten (optimized) | Notes |
|---|---|---|---|---|
| **CPU tuning** | `GENERIC_CPU=y`, x86-64-v1 | `X86_NATIVE_CPU=y` (auto) | `X86_NATIVE_CPU=y`, x86-64-v2 | Our tuned for Sandy Bridge |
| **Scheduler** | EEVDF (stock) | EEVDF + BORE (`SCHED_BORE`) | sched/flat (Peter Zijlstra) | Different scheduler approach |
| **PREEMPT** | `PREEMPT=y` | `PREEMPT=y` (full) | `PREEMPT_LAZY=y` | We use lazy preempt |
| **THP** | `TRANSPARENT_HUGEPAGE_ALWAYS=y` | `ALWAYS` (via PKGBUILD) | `TRANSPARENT_HUGEPAGE_MADVISE=y` | We prefer stable latency |
| **NUMA** | `NUMA=y` | On | Off (`# NUMA is not set`) | Single-socket system |
| **NR_CPUS** | 8192 | 8192 | 8 | 4 cores only |
| **MAXSMP** | `MAXSMP=y` | On | Off | Single-socket |
| **PCIe ASPM** | `PCIEASPM_DEFAULT=y` | Default | `PCIEASPM_PERFORMANCE=y` | Lower GPU latency |
| **EFI_MIXED** | `EFI_MIXED=y` | On | Off (`# EFI_MIXED is not set`) | 64-bit UEFI only |
| **Module sig** | `MODULE_SIG_HASH="sha512"` | SHA512 | SHA256 | Faster without SHA-NI |
| **LSM** | `"landlock,lockdown,yama,integrity,bpf"` (SELINUX+SMACK+TOMOYO+APPARMOR+LOADPIN+IPE built in) | All included | Trimmed: `"landlock,lockdown,yama,integrity,bpf"` (SELINUX, SMACK, TOMOYO, APPARMOR, IPE removed) | Desktop-optimized |
| **BBR3** | `TCP_CONG_BBR3=m` | Module (m) | Module (m) | Same |
| **ZSWAP** | ZSTD default | Same | ZSTD | Same |
| **Module compr** | `MODULE_COMPRESS_ZSTD=y` | Same | ZSTD | Same |
| **CONFIG_CACHY** | Not set | `CACHY=y` | `CACHY=y` | Same after build |
| **Debug info** | DWARF5 uncompressed | Same | DWARF5 ZSTD compressed | Saves ~250MB |
| **SCHED_CLASS_EXT** | `SCHED_CLASS_EXT=y` | On | Off | Not using sched_ext |
| **HZ** | `HZ=300` (base) | `HZ=1000` (PKGBUILD override) | `HZ=1000` | Same after PKGBUILD |
| **Tickless** | `NO_HZ_FULL=y` | Full | Full | Same |
| **Optimization** | `CC_OPTIMIZE_FOR_PERFORMANCE=y` (-O2) | `CC_OPTIMIZE_FOR_PERFORMANCE_O3=y` (-O3) | `CC_OPTIMIZE_FOR_PERFORMANCE_O3=y` (-O3) | Same after PKGBUILD |
| **LTO** | `LTO_NONE=y` | `LTO_CLANG_THIN=y` | `LTO_CLANG_THIN=y` | Same after PKGBUILD |
| **NUMA_BALANCING** | `NUMA_BALANCING=y` | On | Off | Single-socket |
| **Debug compress** | `DEBUG_INFO_COMPRESSED_NONE=y` | Uncompressed | `DEBUG_INFO_COMPRESSED_ZSTD=y` | Smaller packages |

## Summary

### 1. What we did the same (inherited from CachyOS philosophy)
- **BBR3**: Both ship `TCP_CONG_BBR3=m` as a loadable module
- **ZSWAP with ZSTD**: Same `ZSWAP_COMPRESSOR_DEFAULT_ZSTD` choice
- **Module compression**: Both use `MODULE_COMPRESS_ZSTD` (CachyOS also compresses all)
- **HZ_1000**: Both use 1000Hz timer frequency
- **Tickless full**: `NO_HZ_FULL=y` in both
- **CC_OPTIMIZE_FOR_PERFORMANCE_O3**: Both compile with -O3
- **Clang ThinLTO**: Both use `LTO_CLANG_THIN`
- **CONFIG_CACHY=y**: Both set this downstream
- **Kernel compression**: Both use `KERNEL_ZSTD`
- **ZSWAP shrinker**: Both enable `ZSWAP_SHRINKER_DEFAULT_ON`

### 2. What we improved (diverged from CachyOS defaults)
- **CPU tuning**: `X86_NATIVE_CPU=y` + x86-64-v2 (tuned for our Sandy Bridge, vs CachyOS's auto-detect)
- **NR_CPUS**: 8 vs 8192 (saves memory and initialization time on 4-core system)
- **MAXSMP**: Off vs On (unnecessary for single-socket <8 CPUs)
- **NUMA**: Off vs On (single-socket, no NUMA benefit)
- **NUMA_BALANCING**: Off vs On (no NUMA hardware, saves overhead)
- **PCIe ASPM**: Performance vs Default (lower GPU/NVMe latency)
- **EFI_MIXED**: Off vs On (64-bit only UEFI, no 32-bit EFI needed)
- **Module signature hash**: SHA256 vs SHA512 (faster without SHA-NI instructions)
- **LSM**: Trimmed 5 modules (SELINUX, SMACK, TOMOYO, APPARMOR, IPE removed) vs all-included
- **Debug info compression**: ZSTD vs uncompressed (saves ~250MB in package size)
- **SCHED_CLASS_EXT**: Off vs On (not using sched_ext schedulers)

### 3. What we changed differently (conscious trade-offs)
- **PREEMPT_LAZY** (ours) vs **PREEMPT full** (CachyOS): We chose lazy preemption for better throughput. CachyOS defaults to full preemption for lower latency. CachyOS server variant does use lazy, but desktop variants use full.
- **THP MADVISE** (ours) vs **THP ALWAYS** (CachyOS): We chose MADVISE for more predictable memory allocation. CachyOS defaults to ALWAYS for potential performance gains at cost of occasional higher memory usage.
- **Different scheduler**: We use Peter Zijlstra's `sched/flat` instead of EEVDF + BORE. This is a completely different approach to the scheduler, not just a config tweak.

### 4. What CachyOS has that we don't
- **BORE scheduler patches**: CachyOS applies BORE (Burst-Oriented Response Enhancer) patches on top of EEVDF for desktop interactivity
- **BMQ scheduler support**: Alternative bitmap-queue scheduler
- **AutoFDO/Propeller**: Profile-guided optimization pipeline (experimental, two-pass build)
- **modprobed-db support**: `localmodconfig` integration for reduced module builds
- **Hardened variant**: Full security hardening patches
- **RT (real-time) variants**: PREEMPT_RT support (rt and rt-bore)
- **ZFS/NVIDIA/r8125 modules**: Pre-built out-of-tree module integration
- **PRJC patches**: Project C scheduler patches for BMQ variant
- **POC Selector**: Piece-Of-Cake idle CPU selector
- **AMD P-State enhancements**: Preferred Core and linux-next updates
- **Multiple µarch builds**: x86-64-v3, x86-64-v4, znver4 optimized packages
- **kCFI**: Clang Control Flow Integrity support (optional)
- **ACS Override**: VFIO/GPU passthrough patches
- **Steam Deck/Handheld patches**: Deckify variant specific hardware support
