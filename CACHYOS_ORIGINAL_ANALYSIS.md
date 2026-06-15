# CachyOS Kernel Repository — Comprehensive Analysis

## 1. Overview and Versions

- **Source:** https://github.com/CachyOS/linux-cachyos
- **Base kernel:** Linux 7.0.x (CachyOS fork of upstream)
- **Default variant:** `linux-cachyos` — EEVDF scheduler + BORE (Burst-Oriented Response Enhancer) patch
- **Maintainers:** Peter Jung (ptr1337), Piotr Gorski, Vasiliy Stelmachenok
- **License:** GPL-2.0-only
- **Architecture:** x86_64 only
- **Build system:** Arch Linux PKGBUILD (makepkg)

## 2. Repository Structure (10 Variants)

| Directory | Variant | Scheduler | Description |
|---|---|---|---|
| `linux-cachyos/` | Default | EEVDF + BORE | Main kernel with Clang ThinLTO, AutoFDO, Propeller |
| `linux-cachyos-bmq/` | BMQ | BMQ (BitMap Queue) | Throughput-oriented, Project C scheduler |
| `linux-cachyos-bore/` | BORE | BORE | Interactive/gaming focused |
| `linux-cachyos-deckify/` | Deckify | BORE | Handheld gaming (Steam Deck, MSI Claw) |
| `linux-cachyos-eevdf/` | EEVDF | EEVDF (stock) | Pure EEVDF without BORE |
| `linux-cachyos-hardened/` | Hardened | BORE | Security hardening + BORE scheduler |
| `linux-cachyos-lts/` | LTS | EEVDF | Long-term support (6.18) |
| `linux-cachyos-rc/` | RC | EEVDF | Release candidate (latest upstream) |
| `linux-cachyos-rt-bore/` | RT-BORE | BORE + PREEMPT_RT | Real-time kernel |
| `linux-cachyos-server/` | Server | EEVDF | Server-optimized, lazy preemption |

Each variant directory contains: `config`, `PKGBUILD`, `.SRCINFO`.

## 3. PKGBUILD Build Options Table

| Option | Default | Description |
|---|---|---|
| `_cachy_config` | `yes` | Enable CachyOS-specific sauce (sets `CONFIG_CACHY=y`) |
| `_cpusched` | `cachyos` | Scheduler: cachyos, bore, bmq, eevdf, hardened, rt, rt-bore |
| `_makenconfig` | `no` | Interactive nconfig tweak before build |
| `_makexconfig` | `no` | Interactive xconfig tweak before build |
| `_localmodcfg` | `no` | Use modprobed-db for localmodconfig |
| `_localmodcfg_path` | `~/.config/modprobed.db` | Path to modprobed database |
| `_use_current` | `no` | Use running kernel's .config |
| `_cc_harder` | `yes` | Enable `-O3` via `CC_OPTIMIZE_FOR_PERFORMANCE_O3` |
| `_per_gov` | `no` | Set performance governor as default |
| `_tcp_bbr3` | `no` | Enable BBR3 TCP congestion control (opt-in) |
| `_HZ_ticks` | `1000` | Timer frequency (100/250/300/500/600/750/1000) |
| `_tickrate` | `full` | Tickless mode: periodic, idle, or full |
| `_preempt` | `full` | Preemption: full (PREEMPT) or lazy (PREEMPT_LAZY) |
| `_hugepage` | `always` | THP mode: always or madvise |
| `_processor_opt` | `""` (native) | CPU optimization: native, zen4, generic, generic_v[1-4] |
| `_use_llvm_lto` | `thin` | LTO mode: none, thin, full, thin-dist |
| `_use_kcfi` | `no` | Enable Clang kCFI (Control Flow Integrity) |
| `_build_zfs` | `no` | Build ZFS module |
| `_build_nvidia_open` | `no` | Build NVIDIA open module |
| `_build_r8125` | `no` | Build r8125 ethernet module |
| `_build_debug` | `no` | Build debug package (unstripped vmlinux) |
| `_autofdo` | `no` | Enable AutoFDO (experimental) |
| `_autofdo_profile_name` | `""` | Path to AutoFDO profile |
| `_propeller` | `no` | Enable Propeller optimization (experimental) |
| `_propeller_profiles` | `no` | Use Propeller profiles |

### Build-time config overrides applied by PKGBUILD (prepare()):
- Enables `CONFIG_CACHY=y` (not set in base config)
- Sets CPU optimization: `X86_NATIVE_CPU=y` (default, unless overridden)
- Enables scheduler-specific options (`SCHED_BORE`, `SCHED_BMQ`, `PREEMPT_RT`)
- Sets LTO mode (`LTO_CLANG_THIN`, `LTO_CLANG_FULL`, or `LTO_NONE`)
- Overrides `HZ` from 300 (base config) to 1000
- Overrides `NO_HZ_FULL` (tickless full)
- Sets `PREEMPT` or `PREEMPT_LAZY`
- Sets `TRANSPARENT_HUGEPAGE_ALWAYS` or `MADVISE`
- Enables `CC_OPTIMIZE_FOR_PERFORMANCE_O3`
- Optionally enables `AUTOFDO_CLANG`, `PROPELLER_CLANG`
- Optionally enables BBR3 (`TCP_CONG_BBR3`, `DEFAULT_BBR`)

## 4. Base Config Analysis

- **File:** `linux-cachyos/config`
- **CONFIG_ options:** 9,773 (automatically generated, based on Linux 7.0.3 with gcc)
- **CONFIG_CACHY:** Not set in base config (set by PKGBUILD via `scripts/config -e CACHY`)

### Key Base Config Values:

| Option | Value | Notes |
|---|---|---|
| `CONFIG_GENERIC_CPU` | y | x86-64-v1 generic |
| `CONFIG_X86_64_VERSION` | 1 | Minimum x86-64-v1 |
| `CONFIG_PREEMPT` | y | Full preemption (PKGBUILD sets this) |
| `CONFIG_PREEMPT_LAZY` | n | Not set (PKGBUILD can override) |
| `CONFIG_PREEMPT_DYNAMIC` | y | Runtime switchable |
| `CONFIG_HZ_300` | y | Base config uses 300Hz |
| `CONFIG_HZ` | 300 | PKGBUILD overrides to 1000 |
| `CONFIG_NO_HZ_FULL` | y | Full tickless |
| `CONFIG_NUMA` | y | Enabled |
| `CONFIG_NUMA_BALANCING` | y | Enabled |
| `CONFIG_NR_CPUS` | 8192 | Maximum CPUs |
| `CONFIG_MAXSMP` | y | Large SMP support |
| `CONFIG_EFI_MIXED` | y | 32-bit EFI support |
| `CONFIG_PCIEASPM_DEFAULT` | y | Default ASPM policy |
| `CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS` | y | Always use THP |
| `CONFIG_MODULE_SIG_HASH` | sha512 | Module signing |
| `CONFIG_MODULE_COMPRESS_ZSTD` | y | ZSTD module compression |
| `CONFIG_ZSWAP` | y | ZSTD compression |
| `CONFIG_DEBUG_INFO_DWARF5` | y | DWARF5 debug info |
| `CONFIG_DEBUG_INFO_COMPRESSED_NONE` | y | Uncompressed debug info |
| `CONFIG_DEBUG_INFO_BTF` | y | BTF for BPF |
| `CONFIG_LSM` | `"landlock,lockdown,yama,integrity,bpf"` | LSM order |
| `CONFIG_SCHED_CLASS_EXT` | y | sched_ext framework |
| `CONFIG_SCHED_BORE` | n | Not set (PKGBUILD enables for cachyos/bore variants) |
| `CONFIG_KERNEL_ZSTD` | y | Kernel compression |
| `CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE` | y | -O2 base (PKGBUILD overrides to -O3) |
| `CONFIG_LTO_NONE` | y | Base has no LTO (PKGBUILD overrides to LTO_CLANG_THIN) |

### Security Modules built in (base config):
`SELINUX`, `SMACK`, `TOMOYO`, `APPARMOR`, `LOADPIN`, `YAMA`, `SAFESETID`, `LOCKDOWN`, `LANDLOCK`, `IPE`

## 5. CachyOS-Specific Patches

Patches are fetched from `https://raw.githubusercontent.com/cachyos/kernel-patches/master/${_major}`

### Patch Categories:

| Patch | Source | Applied for |
|---|---|---|
| `0001-bore-cachy.patch` | `sched/` | bore, rt-bore, hardened, cachyos (default) |
| `0001-prjc-cachy.patch` | `sched/` | bmq (Project C / PRJC scheduler) |
| `0001-hardened.patch` | `misc/` | hardened variant |
| `0001-rt-i915.patch` | `misc/` | rt, rt-bore variants |
| `dkms-clang.patch` | `misc/` | All LTO builds (for DKMS compatibility) |

### Source kernel tree:
Downloaded from `https://github.com/CachyOS/linux/releases` as `${_srcname}.tar.gz`
Currently: `cachyos-7.0.12-2`

## 6. Compiler and LTO Configuration

### Default: Clang/LLVM with ThinLTO
- `_use_llvm_lto=thin` (default)
- Uses `CC=clang`, `LD=ld.lld`, `LLVM=1`, `LLVM_IAS=1`
- makedepends include: `clang`, `llvm`, `lld`

### LTO Options:
| Option | Config flag | Description |
|---|---|---|
| `thin` (default) | `LTO_CLANG_THIN` | Multi-threaded, fast, recommended |
| `thin-dist` | `LTO_CLANG_THIN_DIST` | Distributed ThinLTO |
| `full` | `LTO_CLANG_FULL` | Single-threaded, highest theoretical gain |
| `none` | `LTO_NONE` | GCC-style build, no LTO |

### AutoFDO + Propeller (Experimental):
- `_autofdo=yes` → `CONFIG_AUTOFDO_CLANG=y`
- `_propeller=yes` → `CONFIG_PROPELLER_CLANG=y`
- Two-pass profiling: compile → profile → recompile with profiles

### Package suffix logic:
- LTO kernels → `linux-cachyos-lto` (with `_use_lto_suffix=yes`)
- Non-LTO → `linux-cachyos-gcc`
- Kernel uname: `pkgver-cachyos` (or `cachyos-lto`/`cachyos-gcc`)
