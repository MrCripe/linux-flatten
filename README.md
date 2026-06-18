# linux-flatten

Linux kernel с патчем `sched/flat` от Peter Zijlstra + оптимизациями CachyOS.

**Цель:** Минимальная задержка планировщика (`sched/flat` + `PREEMPT_LAZY`) + агрессивные настройки для десктопа (BBR3, HZ_1000, O3).

**Универсальное ядро** — совместимо со **всеми** x86-64 процессорами (Intel Core 2+, AMD Athlon 64+). Не требует `-march=native`, работает на любом x86-64 v1 и выше.

---

## Содержание

- [Загрузка из релизов](#загрузка-из-релизов)
- [Быстрая установка](#быстрая-установка)
- [Сборка из исходников](#сборка-из-исходников)
- [Оптимизация под оборудование](#оптимизация-под-оборудование)
- [Файлы проекта](#файлы-проекта)
- [Makefile цели](#makefile-цели)
- [CI/CD](#cicd)
- [Тестирование](#тестирование)
- [Откат](#откат)
- [Устранение проблем](#устранение-проблем)

---

## Загрузка из релизов

Готовые сборки ядра доступны на [GitHub Releases](https://github.com/${{GITHUB_REPOSITORY}}/releases).

Каждый релиз создаётся автоматически при пуше в `main`. Имя тега = версии ядра (например `7.2.0.flatten`).

### Скачивание через GitHub CLI
```bash
# Последний релиз
gh release download --repo <owner>/linux-flatten --pattern "linux-flatten-*-x86_64.tar.gz"

# Конкретная версия
gh release download v7.2.0.flatten --repo <owner>/linux-flatten
```

### Скачивание вручную
```bash
# Замените VERSION на нужную версию
VERSION="7.2.0.flatten"
wget "https://github.com/${{GITHUB_REPOSITORY}}/releases/download/${VERSION}/linux-flatten-${VERSION}-x86_64.tar.gz"
wget "https://github.com/${{GITHUB_REPOSITORY}}/releases/download/${VERSION}/linux-flatten-${VERSION}-x86_64.tar.gz.sha256"

# Проверить целостность
sha256sum -c linux-flatten-${VERSION}-x86_64.tar.gz.sha256
```

### Установка из релиза
```bash
# Распаковать в корень системы
sudo tar -xzf linux-flatten-*-x86_64.tar.gz -C /

# Обновить initramfs
sudo mkinitcpio -p linux-flatten

# Обновить загрузчик (Limine)
sudo limine-scan /boot

# Перезагрузиться
sudo reboot
```

### Проверка после загрузки
```bash
uname -r
# Вывод: 7.2.0-flatten

cat /proc/version
# Должен содержать "-flatten"

# Проверить что ядро работает с нужными оптимизациями
zcat /proc/config.gz | grep -E "PREEMPT_LAZY|HZ_1000|BBR3|O3"
```

---

## Быстрая установка

```bash
# Если есть готовый пакет
sudo pacman -U linux-flatten-*.pkg.tar.zst

# После установки — перезагрузка и выбор "Linux Flatten" в Limine
```

## Сборка из исходников

### Требования

- `base-devel`, `git`, `bc`, `kmod`, `inetutils`, `cpio`, `openssl`, `elfutils`
- Конфигурация ядра: `/proc/config.gz` (скопировать в корень пакета как `config.gz`)

### Сборка

```bash
# Скопировать текущий конфиг
cp /proc/config.gz ./

# Собрать пакет
make build
# или вручную:
makepkg -sf

# Установить
make install
```

### Сборка с оптимизациями

```bash
# 1. Применить все оптимизации (safe + recommended):
./apply-optimizations.sh

# 2. Собрать:
makepkg -sf

# 3. Установить:
sudo pacman -U linux-flatten-*.pkg.tar.zst

# 4. Перезагрузиться и проверить:
./test-kernel.sh
```

---

## Сравнение с оригинальным CachyOS

Этот проект основан на [CachyOS Kernel](https://github.com/CachyOS/linux-cachyos), но использует **sched/flat** патч Peter Zijlstra вместо стандартного EEVDF + BORE планировщика CachyOS.

Ключевые отличия от CachyOS:

| Что | CachyOS | linux-flatten |
|-----|---------|---------------|
| Планировщик | EEVDF + BORE | sched/flat (flattened runqueue) |
| PREEMPT | full (PREEMPT) | PREEMPT_LAZY |
| CPU tuning | GENERIC (x86-64-v1) | x86-64 (generic, совместим со всеми) |
| NUMA | Включён | Отключён (single socket) |
| PCIe ASPM | DEFAULT | PERFORMANCE |
| THP | ALWAYS | MADVISE |
| NR_CPUS | 8192 | 8 |
| Debug info | DWARF5 несжатый | DWARF5 + ZSTD сжатие |
| LSMs | Все (10) | Отключены 5 лишних |
| Модульная подпись | SHA512 | SHA256 |

Подробнее: [`COMPARISON.md`](COMPARISON.md) и [`CACHYOS_ORIGINAL_ANALYSIS.md`](CACHYOS_ORIGINAL_ANALYSIS.md)

---

## Оптимизация под оборудование

Проект включает файлы с анализом и предложениями:

| Файл | Описание |
|------|----------|
| `ANALYSIS.md` | Глубокий анализ текущей конфигурации ядра |
| `PROPOSED_OPTIMIZATIONS.md` | Предложения по оптимизации (8 safe, 5 recommended, 5 experimental) |

Оптимизации разделены на категории:
- ✅ **Безопасные** — можно применять сразу
- ⚠️ **Рекомендуемые** — нужно тестирование
- 🧪 **Экспериментальные** — риск нестабильности
- ❌ **Не рекомендуются** — не подходят для железа

---

## Скрипты

| Скрипт | Назначение |
|--------|-----------|
| `apply-optimizations.sh` | Применить оптимизации к config.gz (--dry-run / --restore) |
| `test-kernel.sh` | Проверка установки ядра (--quick / --list) |
| `auto-update.sh` | Автообновление + сборка + установка (--check / --build-only) |
| `rollback.sh` | Откат всех изменений (--config-only / --uninstall / --list) |

### apply-optimizations.sh
```bash
# Применить все оптимизации
./apply-optimizations.sh

# Посмотреть diff (без применения)
./apply-optimizations.sh --dry-run

# Откатить config.gz из backup
./apply-optimizations.sh --restore
```

### test-kernel.sh
```bash
# Полная проверка
./test-kernel.sh

# Быстрая проверка
./test-kernel.sh --quick

# Список всех проверок
./test-kernel.sh --list
```

### auto-update.sh
```bash
# Проверить новые коммиты
./auto-update.sh --check

# Обновить + собрать (без установки)
./auto-update.sh --build-only

# Полное обновление + сборка + установка
./auto-update.sh
```

### rollback.sh
```bash
# Список доступных backup
./rollback.sh --list

# Вернуть все файлы из backup
./rollback.sh

# Вернуть только config.gz
./rollback.sh --config-only

# Откат + удаление пакета
./rollback.sh --uninstall
```

---

## Файлы проекта

| Файл | Назначение |
|------|------------|
| `PKGBUILD` | Arch Linux пакетная формула |
| `config.gz` | Конфигурация ядра (оптимизированная) |
| `config.gz.backup` | Резервная копия оригинального конфига |
| `config.optimized` | Оптимизированный config в plain-text |
| `linux-flatten.install` | Post-install скрипты (Limine + initramfs) |
| `Makefile` | Цели сборки/линта/чистки |
| `.lint.sh` | Скрипт линтинга (shellcheck, namcap, bash -n) |
| `.github/workflows/ci.yml` | GitHub Actions CI |
| `.opencode/agents/` | Субагенты для opencode |
| `ANALYSIS.md` | Анализ конфигурации ядра |
| `PROPOSED_OPTIMIZATIONS.md` | Предложения по оптимизации |
| `APPLIED_OPTIMIZATIONS.md` | Отчёт о применённых оптимизациях |
| `AUDIT_REPORT.md` | Отчёт аудита пакета |
| `src/` | Исходники ядра (git clone) |
| `pkg/` | Собранный пакет |

---

## Makefile цели

```bash
make help       # Показать все цели
make lint       # Запустить линтеры
make test       # Запустить тесты
make build      # Собрать пакет
make clean      # Очистить артефакты
make install    # Установить (требует pacman)
make uninstall  # Удалить пакет
```

---

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`):

- **Lint** — shellcheck, namcap, syntax check
- **Build** — полная сборка пакета в Arch Linux контейнере
- **Shellcheck** — multi-platform shell analysis

---

## Тестирование

```bash
# Линтинг
make lint
# или детально:
bash -n PKGBUILD
bash -n linux-flatten.install

# namcap (если установлен)
namcap PKGBUILD
namcap linux-flatten-*.pkg.tar.zst

# shellcheck (если установлен)
shellcheck linux-flatten.install
```

### После установки

```bash
# Проверить версию ядра
uname -r

# Проверить конфиг
zcat /proc/config.gz | grep CACHY

# Проверить загрузчик
ls -la /boot/vmlinuz-linux-flatten
ls -la /boot/initramfs-linux-flatten.img
```

---

## Откат

```bash
# Полный откат (восстановить файлы + удалить пакет):
./rollback.sh --uninstall

# Или поэтапно:
./rollback.sh                          # восстановить файлы из backup
./rollback.sh --config-only            # вернуть оригинальный config.gz
./rollback.sh --list                   # список доступных backup
```

---

## Устранение проблем

### "mkinitcpio preset not found"
Начиная с версии install-скрипта, пресет создаётся автоматически. Если возникла проблема:

```bash
# Вручную создать пресет
sudo mkdir -p /etc/mkinitcpio.d
cat | sudo tee /etc/mkinitcpio.d/linux-flatten.preset <<EOF
ALL_kver="/boot/vmlinuz-linux-flatten"
ALL_config="/etc/mkinitcpio.conf"
default_image="/boot/initramfs-linux-flatten.img"
EOF

# Собрать initramfs
sudo mkinitcpio -p linux-flatten
```

### "Limine entry missing" или нет записи для linux-flatten
Если скрипт `.install` не добавил запись в `/boot/limine.conf`:

```bash
# 1. Определить root UUID
ROOT_UUID=$(findmnt -n -o UUID /)
CMDLINE=$(cat /proc/cmdline | sed 's/BOOT_IMAGE=[^ ]* //')

# 2. Добавить запись с параметром pcie_aspm=performance
sudo bash -c 'cat >> /boot/limine/limine.conf <<LIMINE

:Linux Flatten
    PROTOCOL=linux
    KERNEL_PATH=boot:///vmlinuz-linux-flatten
    MODULE_PATH=boot:///initramfs-linux-flatten.img
    KERNEL_CMDLINE="root=UUID='$ROOT_UUID' '$CMDLINE' add_efi_memmap pcie_aspm=performance"
LIMINE'
```

### PCIe ASPM не в режиме performance
Проверить текущий режим:
```bash
cat /sys/module/pcie_aspm/parameters/policy
```
Ожидается: `[performance] default powersave powersupersave`

Если `[default]` активен — параметр ядра `pcie_aspm=performance` не был передан загрузчиком. Добавьте его в `KERNEL_CMDLINE` строку для linux-flatten в `/boot/limine/limine.conf`.

Скрипт `.install` теперь добавляет этот параметр автоматически при установке/обновлении пакета.

### "Limine config not found"
```bash
# Убедиться, что Limine установлен
sudo limine --install /boot
```

### "config.gz not found"
```bash
cp /proc/config.gz ./
```

---

## Лицензия

GPLv2 — как и оригинальное ядро Linux.

## Поддержка

- [Peter Zijlstra's sched/flat queue](https://git.kernel.org/pub/scm/linux/kernel/git/peterz/queue.git)
- [CachyOS kernel](https://github.com/CachyOS/linux-cachyos)
