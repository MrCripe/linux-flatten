# Анализ конфигурации ядра linux-flatten

> **Дата:** 2026-06-15
> **Цель:** Анализ текущего .config для оптимизации под оборудование (Intel Xeon E31270 / AMD RX 580)

---

## 1. Общая информация

| Параметр | Значение |
|----------|----------|
| Ядро | Linux 7.0.11 (на основе sched/flat ветки Peter Zijlstra) |
| Компилятор | Clang 22.1.6 |
| Линковщик | LLD 22.1.6 |
| Оптимизация | `-O3` (CC_OPTIMIZE_FOR_PERFORMANCE_O3) |
| LTO | ThinLTO (CONFIG_LTO_CLANG_THIN) |
| База | CachyOS (`CONFIG_CACHY=y`) |
| BTF | Включён (DWARF5, несжатый) |

---

## 2. Текущие оптимизации CachyOS (уже применены)

### Процессор/Планировщик
- **PREEMPT** (активная вытесняемость, низкая задержка)
- **SCHED_CLASS_EXT** (sched_ext — кастомные планировщики через BPF)
- **HZ_1000** (1000 тиков/сек — минимальная задержка)
- **SCHED_HRTICK** (высокоточный тик планировщика)
- **SCHED_CORE** (core scheduling)
- **SCHED_MC_PRIO** (приоритет multi-core)

### Память
- **Transparent Hugepages: ALWAYS** (агрессивное использование huge pages)
- **ZSWAP** + ZSTD компрессия (сжатие страниц в RAM)
- **ZRAM** как модуль (сжатый RAM-диск для swap)
- **CMA** (7 областей, 0 MB по умолчанию)

### Файловые системы
- **Btrfs** встроен (y), с ACL
- **XFS** как модуль (m), с online scrub/repaire
- **ext4** встроен (y), без дебага
- **F2FS** как модуль (m)

### Сеть
- **BBR3** как модуль (m) — современный congestion control
- **FQ_CODEL** планировщик (y) — по умолчанию
- **RPS/XPS/BQL** включены

### Безопасность
- SELinux, AppArmor, Smack, Tomoyo, Yama, Landlock, IPE
- Модульная подпись: ECDSA + SHA512
- `CONFIG_SECURITY_LOCKDOWN_LSM=y`

### GPU/DRM
- **AMDGPU** как модуль (m), поддежка SI/CIK/Polaris
- AMD DC (Display Core) включён
- HSA (Heterogeneous System Architecture) — для AMD GPGPU
- amdgpu, i915, nouveau, radeon — все как модули

---

## 3. Проблемы и избыточность

### 🔴 CPU: GENERIC (не оптимизирован под Sandy Bridge)

```config
CONFIG_GENERIC_CPU=y
```

Вместо этого нужно `CONFIG_MCORE2=y` или `CONFIG_MATOM=y`. Sandy Bridge — Core 2-подобная архитектура (нет AVX2, нет AVX-512). `GENERIC_CPU` даёт самый консервативный код без учёта особенностей CPU.

### 🔴 NR_CPUS: 8192 (гигантский overkill)

```config
CONFIG_NR_CPUS=8192
CONFIG_MAXSMP=y
```

Для 4 ядер / 8 потоков достаточно `NR_CPUS=8`. Текущее значение выделяет структуры на 8192 CPU, что тратит память на scheduler bitmap и per-CPU данные.

### 🔴 NUMA включён

```config
CONFIG_NUMA=y
CONFIG_NUMA_BALANCING=y
```

Sandy Bridge Xeon **однопроцессорный** — нет NUMA. NUMA балансинг добавляет накладные расходы без выгоды.

### 🟡 DEBUG_INFO и размер ядра

```config
CONFIG_DEBUG_INFO=y
CONFIG_DEBUG_INFO_DWARF5=y
CONFIG_DEBUG_INFO_COMPRESSED_NONE=y
CONFIG_DEBUG_INFO_BTF=y
```

BTF + DWARF5 существенно увеличивают размер vmlinux. BTF нужен для modern BPF (рекомендуется оставить), но DWARF5 можно сжать (ZSTD) или отключить.

### 🟡 PCIe ASPM: DEFAULT (не PERFORMANCE)

```config
CONFIG_PCIEASPM_DEFAULT=y
```

ASPM в режиме PERFORMANCE отключает энергосбережение PCIe, что снижает latency для GPU и NVMe. На десктопе это даёт прирост.

### 🟡 PREEMPT vs PREEMPT_LAZY

Текущий: `PREEMPT` (полная вытесняемость)
Альтернатива: `PREEMPT_LAZY` — ниже latency для интерактива, но выше пропускная способность для CPU-bound задач.

`PREEMPT` хорош для десктопа, `PREEMPT_LAZY` — компромисс.

### 🟡 THP: ALWAYS vs MADVISE

`TRANSPARENT_HUGEPAGE_ALWAYS=y` — ядро пытается всегда использовать 2MB страницы. На некоторых workload (базы данных, Rust-программы) это может увеличивать latency из-за необходимости дефрагментации памяти. Рекомендуется `MADVISE` для серверных/смешанных нагрузок.

### 🟡 Множество ненужных Security LSM

SELinux, AppArmor, Smack, Tomoyo, Landlock, IPE, Yama, LoadPin, SafeSetID — **все встроены**. Для домашнего ПК достаточно AppArmor или Landlock + Yama. Остальные тратят память и замедляют загрузку.

### 🟡 EFI_MIXED

```config
CONFIG_EFI_MIXED=y
```

Включает поддержку 32-битного EFI (для совместимости). На 64-битном UEFI не нужно.

---

## 4. Что уже хорошо

✅ **Clang + ThinLTO** — современный быстрый компилятор
✅ **O3 оптимизация** — агрессивная оптимизация кода
✅ **BBR3** — лучший congestion control для современных сетей
✅ **FQ_CODEL** — хороший сетевой планировщик для десктопа
✅ **ZSTD** для модулей и zswap — быстрый алгоритм с хорошим сжатием
✅ **AMDGPU DC** — правильный Display Core для Polaris
✅ **Btrfs без дебага** — оптимально
✅ **ZSWAP + ZSTD** — хорошая стратегия для 16GB RAM
✅ **IOMMU DMA LAZY** — лучшая производительность для GPU passthrough
✅ **DEVTMPFS + MOUNT** — современная /dev без devtmpfsd
✅ **intel_pstate** — энергоэффективный frequency scaling
✅ **PCIEASPM DEFAULT** — разумный компромисс (хотя можно PERFORMANCE)

---

## 5. Сводка текущих настроек под оборудование

### Sandy Bridge (Xeon E31270)
- `CONFIG_GENERIC_CPU=y` — ❌ слишком общий
- `CONFIG_CPU_SUP_INTEL=y` — ✅ поддержка Intel
- `CONFIG_INTEL_PSTATE=y` — ✅ частотный драйвер
- `CONFIG_INTEL_IDLE=y` — ✅ C-state драйвер
- `CONFIG_X86_INTEL_MEMORY_PROTECTION_KEYS=y` — PKU support
- `CONFIG_MICROCODE=y` (без late loading) — ✅ микрокод
- ❌ Нет архитектурной оптимизации под Sandy Bridge

### AMD Polaris (RX 580)
- `CONFIG_DRM_AMDGPU=m` — ✅ модуль amdgpu
- `CONFIG_DRM_AMDGPU_SI=y` — ✅ поддержка Southern Islands
- `CONFIG_DRM_AMDGPU_CIK=y` — ✅ поддержка Sea Islands
- `CONFIG_DRM_AMD_DC=y` — ✅ Display Core (нужен для Polaris)
- `CONFIG_DRM_AMD_DC_FP=y` — ✅ DC floating point
- `CONFIG_HSA_AMD=y` — ✅ AMD GPGPU (OpenCL/RadeonOpenCompute)
- `CONFIG_AGP=y` — ✅ AGP support
- ❌ `CONFIG_IOMMU_DEFAULT_DMA_LAZY` — лучше passthrough для GPU

### Btrfs (основная ФС)
- `CONFIG_BTRFS_FS=y` — ✅ встроен
- `CONFIG_BTRFS_FS_POSIX_ACL=y` — ✅
- `CONFIG_BTRFS_DEBUG=n` — ✅ дебаг выключен
- `CONFIG_LZ4_COMPRESS` — ✅ аппаратное ускорение
- ❌ Отсутствует настройка Btrfs zoned или send stream v2

### Память (16GB DDR3)
- `CONFIG_ZSWAP=y` + ZSTD — ✅ сжатие swap
- `CONFIG_ZRAM=m` + ZSTD — ✅ сжатый RAM-диск
- `CONFIG_TRANSPARENT_HUGEPAGE_ALWAYS=y` — 🟡 может быть overhead
- `CONFIG_COMPACTION=y` — ✅ дефрагментация памяти
- `CONFIG_CMA=y` — ✅ contiguous memory allocator
- `CONFIG_NR_CPUS=8192` — ❌ **критический overkill**

---

## 6. Kconfig — неиспользуемые возможности

### Включено, но не используется на данном железе:
- **KVM (Intel/AMD)** — модули, на десктопе без ВМ не нужны
- **XFS, F2FS** — модули, если не используются
- **Множество звуковых кодеков** (Realtek, HDMI, USB, SOC)
- **Драйверы GPU** i915, nouveau, radeon, vmwgfx, qxl, bochs
- **SATA/IDE драйверы** для старого железа
- **FireWire** — неактуально
- **Множество сетевых драйверов** (беспроводные, старые ethernet)
- **Множество security LSM** — SELinux + AppArmor + Smack + Tomoyo
- **MAXSMP + NR_CPUS=8192** — 4-ядерный CPU
- **NUMA** — однопроцессорная система

---

## 7. Файл конфигурации

- **Источник:** `config.gz` в корне пакета
- **Режим:** gzip-сжатый
- **Размер:** 69,740 байт (несжатый ~200KB)
- **Формат:** CachyOS config (`CONFIG_CACHY=y`)
- **Модификация в PKGBUILD:** CachyOS enhancements применяются через `scripts/config`
- **LOCALVERSION:** `-flatten`

---

## 8. Компиляторные флаги

| Параметр | Значение |
|----------|----------|
| CC | Clang 22.1.6 |
| LD | LLD 22.1.6 |
| Оптимизация | `-O3` |
| LTO | ThinLTO |
| BTF | pahole 1.31 |
| Stack validation | `OBJTOOL=y` |

**Замечание:** PKGBUILD использует `make -j$(nproc)` без явных CFLAGS. Clang сам выбирает флаги под `GENERIC_CPU`. Можно добавить `march=native` или `-march=sandybridge` для GCC (или `-march=x86-64-v2`).

---

*Конец анализа. Следующий шаг: PROPOSED_OPTIMIZATIONS.md с конкретными предложениями.*
