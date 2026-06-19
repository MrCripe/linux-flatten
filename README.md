# linux-flatten

Linux kernel с патчем `sched/flat` от Peter Zijlstra + оптимизациями для десктопа.

**Универсальное ядро** — совместимо со всеми x86-64 процессорами (Intel Core 2+, AMD Athlon 64+). Не требует `-march=native`.

---

## Быстрая установка (из релизов)

Готовые сборки: [GitHub Releases](https://github.com/MrCripe/linux-flatten/releases)

### Скачать пакеты

```bash
# Через GitHub CLI
gh release download --repo MrCripe/linux-flatten --pattern "linux-flatten-*.pkg.tar.zst"

# Или вручную — замените VERSION на нужную
VERSION="7.1.0-1"
wget "https://github.com/MrCripe/linux-flatten/releases/download/${VERSION}/linux-flatten-${VERSION}-x86_64.pkg.tar.zst"
wget "https://github.com/MrCripe/linux-flatten/releases/download/${VERSION}/linux-flatten-${VERSION}-headers-x86_64.pkg.tar.zst"
```

### Установить

```bash
# Установить ядро + хедеры
sudo pacman -U linux-flatten-*.pkg.tar.zst

# Обновить initramfs
sudo mkinitcpio -p linux-flatten

# Обновить загрузчик (Limine)
sudo limine-scan /boot

# Перезагрузиться
sudo reboot
```

> **Примечание:** Пакет `linux-flatten` содержит ядро, все модули и firmware. Пакет `linux-flatten-headers` нужен только для сборки сторонних модулей (dkms, nvidia и т.д.). Если не собираете модули — можно установить только основной пакет.

### Проверка после загрузки

```bash
uname -r
# Вывод: 7.1.0-flatten

cat /proc/version
# Должен содержать "-flatten"

# Проверить что нужные оптимизации активны
zcat /proc/config.gz | grep -E "PREEMPT_LAZY|HZ_1000|BBR3"
```

---

## Сборка из исходников

Требования: Arch Linux с `base-devel`, `git`, `bc`

```bash
# Клонировать репозиторий
git clone https://github.com/MrCripe/linux-flatten.git
cd linux-flatten

# Собрать и установить
./linux-flatten.sh update
```

### Опции сборки

```bash
# Собрать с полными оптимизациями
./linux-flatten.sh build --optimizations full

# Оптимизировать под конкретный CPU (x86-64-v2 = Sandy Bridge+)
./linux-flatten.sh build --target x86-64-v2

# Собрать без установки
./linux-flatten.sh build --build-only

# Установить уже собранное
./linux-flatten.sh install

# Проверить текущее ядро
./linux-flatten.sh verify

# Откатить к оригинальному ядру
./linux-flatten.sh rollback
```

### Уровни оптимизаций

| Уровень | Что включает |
|---------|-------------|
| `safe` | O3, HZ=1000, PREEMPT_LAZY, BBR3, THP MADVISE, ZSTD модули, SHA256 подпись, отключение debug info и лишних LSM |
| `recommended` | Safe + CONFIG_MNATIVE, NR_CPUS=8, отключение MAXSMP |
| `full` | Recommended + ZSTD сжатие debug info |
| `none` | Только базовый конфиг + sched/flat |

### CPU Target

| Target | Совместимость |
|--------|--------------|
| `generic` | Все x86-64 процессоры (v1+) — по умолчанию |
| `x86-64-v2` | Sandy Bridge и новее (рекомендуется для большинства) |
| `x86-64-v3` | Haswell и новее |

---

## Что делает install-скрипт

После `pacman -U linux-flatten-*.pkg.tar.zst` автоматически:
- Создаёт `/etc/mkinitcpio.d/linux-flatten.preset`
- Генерирует initramfs (`mkinitcpio -p linux-flatten`)
- Добавляет/обновляет запись в Limine с `pcie_aspm=performance`

Никаких дополнительных действий не требуется — просто установил пакет и перезагрузился.

---

## Структура проекта

```
linux-flatten/
├── linux-flatten.sh          # Единый CLI (update/build/install/verify/rollback)
├── PKGBUILD                  # Arch Linux пакетная формула
├── linux-flatten.install     # Post-install скрипт (mkinitcpio + Limine)
├── Makefile                  # Цели сборки/чистки
├── .github/workflows/        # CI: сборка + GitHub Release
└── README.md
```

---

## Лицензия

GPLv2 — как и оригинальное ядро Linux.
