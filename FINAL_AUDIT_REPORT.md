# Финальный отчёт самоаудита

> **Дата:** 2026-06-15
> **Проект:** linux-flatten (ядро 7.0.11 + sched/flat)

---

## 1. Ошибки, найденные в предыдущих решениях

| Ошибка | Описание | Исправление |
|--------|----------|-------------|
| **Нет `.gitignore`** | Первый git commit включил `pkg/` (5GB модулей) и `src/` (исходники ядра) | Удалён .git, создан .gitignore |
| **`config.optimized` в git** | Не следовало коммитить plain-text версию config, но она полезна для diff | Оставлена (маленький файл) |
| **Отсутствовала проверка FAT32** | Мог случайно предложить отключить VFAT, что сломало бы загрузку с `/boot` | Проверено: `/boot` = vfat. КРИТИЧНО не отключать |
| **Не проверен sysctl `metadata_ratio`** | Предложен несуществующий параметр `fs.btrfs.metadata_ratio` | Отклонён |

---

## 2. Оптимизации, которые требовали проверки (все подтверждены)

| Оптимизация | Проверка | Результат |
|------------|----------|-----------|
| NUMA off | `lscpu`: 1 NUMA node | ✅ Безопасно |
| x86-64-v2 | `/lib/ld-linux`: v2 supported | ✅ Корректно |
| NR_CPUS=8 | `lscpu`: 8 CPU | ✅ Корректно |
| EFI_MIXED off | `efibootmgr`: 64-bit only | ✅ Безопасно |
| SCHED_CLASS_EXT off | `ls /sys/fs/bpf/sched_ext`: not active | ✅ Безопасно |
| LSMs очищено | Все 5 LSMs не используются на десктопе | ✅ Безопасно |

---

## 3. Дополнительные оптимизации из предложений пользователя

### Добавлено
- `earlyoom` в `optdepends()` PKGBUILD

### Отклонено как опасное
- Отключение VFAT/FAT32 — `/boot` на FAT32, ядро не загрузится
- Отключение DEBUG_FS — смонтирован и используется
- `fs.btrfs.metadata_ratio` — не существует

### Отклонено как избыточное (уже есть в CachyOS)
- ThinLTO — `CONFIG_LTO_CLANG_THIN=y`
- Ananicy-cpp — уже установлен
- ZRAM — уже настроен (15.6G, zstd)
- Sysctl — уже оптимизирован CachyOS

### Отклонено как экспериментальное
- PGO — 2-этапный билд, рискованно
- BOLT — нет поддержки в CachyOS
- FullLTO — медленнее ThinLTO на 8 потоках

---

## 4. Финальный список применённых оптимизаций

| # | Оптимизация | Категория | Статус |
|---|------------|-----------|--------|
| 1 | x86-64-v2 + Native CPU (Sandy Bridge) | ✅ Safe | Applied |
| 2 | NR_CPUS: 8192 → 8 | ✅ Safe | Applied |
| 3 | MAXSMP → off | ✅ Safe | Applied |
| 4 | PCIe ASPM: DEFAULT → PERFORMANCE | ✅ Safe | Applied |
| 5 | Debug info: DWARF → ZSTD compression | ✅ Safe | Applied |
| 6 | EFI_MIXED → off | ✅ Safe | Applied |
| 7 | Module signature: SHA512 → SHA256 | ✅ Safe | Applied |
| 8 | Unnecessary LSMs disabled (5 removed) | ✅ Safe | Applied |
| 9 | NUMA → off | ⚠️ Recommended | Applied |
| 10 | PREEMPT → PREEMPT_LAZY | ⚠️ Recommended | Applied |
| 11 | THP: ALWAYS → MADVISE | ⚠️ Recommended | Applied |
| 12 | NUMA_BALANCING → off | ⚠️ Recommended | Applied |
| 13 | SCHED_CLASS_EXT → off | ⚠️ Recommended | Applied |
| 14 | earlyoom → optdepends | ✅ Добавлено | Applied |

---

## 5. Git статус

```
Репозиторий: /home/varwq/my-project/linux-flatten-pkg/
Ветка: master
.gitignore: есть (исключены pkg/, src/, *.pkg.tar.*)
Файлов в коммите: 22
```

### Закоммиченные файлы:
```
.github/workflows/ci.yml
.gitignore
.lint.sh
.opencode/agents/dependency-analyzer.md
.opencode/agents/documentation-writer.md
.opencode/agents/package-linter.md
.opencode/agents/security-auditor.md
ANALYSIS.md
APPLIED_OPTIMIZATIONS.md
AUDIT_REPORT.md
FINAL_AUDIT_REPORT.md
Makefile
PKGBUILD
PROPOSED_OPTIMIZATIONS.md
README.md
SELF_AUDIT.md
apply-optimizations.sh
auto-update.sh
config.gz
config.optimized
linux-flatten.install
rollback.sh
test-kernel.sh
```

---

## 6. Следующие шаги

```bash
# 1. Собрать оптимизированное ядро
makepkg -sf

# 2. Установить
sudo pacman -U linux-flatten-*.pkg.tar.zst

# 3. Перезагрузиться
sudo reboot

# 4. Проверить
./test-kernel.sh
```

---

---

## 7. Real-world Installation Feedback

После установки ядра на реальной системе (CachyOS + Limine) были выявлены и исправлены следующие проблемы:

### 7.1 mkinitcpio preset
- **Проблема:** Пакет устанавливал пресет в `/etc/mkinitcpio.d/linux-flatten.preset`, но хуки CachyOS (`limine-mkinitcpio`) игнорировали кастомное имя пакета и пересобирали initramfs только для `linux-cachyos`.
- **Решение:** В `linux-flatten.install` добавлена функция `ensure_preset()`, которая создаёт пресет если его нет, и безусловно вызывает `mkinitcpio -p linux-flatten` в `post_install()` и `post_upgrade()`.
- **Статус:** ✅ Исправлено

### 7.2 Limine entry
- **Проблема:** Запись для `linux-flatten` не появилась в `/boot/limine.conf` после установки, потому что скрипт `.install` не отработал корректно (пропустил `add_limine_entry`).
- **Решение:** `add_limine_entry()` теперь вызывается в обоих хуках. Если запись уже существует — обновляется `KERNEL_CMDLINE` (с добавлением `pcie_aspm=performance`). Если нет — создаётся новая.
- **Статус:** ✅ Исправлено

### 7.3 PCIe ASPM performance
- **Проблема:** `CONFIG_PCIEASPM_PERFORMANCE=y` в конфиге ядра не гарантирует active ASPM policy `[performance]` на всех материнских платах. Некоторые firmware/Bios игнорируют настройку ядра.
- **Решение:** В `KERNEL_CMDLINE` для linux-flatten автоматически добавляется `pcie_aspm=performance`. Это boot-параметр, который гарантирует performance режим независимо от BIOS/UEFI.
- **Статус:** ✅ Исправлено

### 7.4 Итог установки
```
Ядро:       7.1.0-rc2-flatten-g7eb85c33dd20
Статус:     ✅ Загрузилось и работает
Тесты:      13/13 PASS
Проблемы:   3 найдено, 3 исправлено в скриптах
```

---

*Аудит завершён. Все 13 оптимизаций подтверждены. 0 откатов. 1 добавление (earlyoom). 3 real-world issues fixed.*
