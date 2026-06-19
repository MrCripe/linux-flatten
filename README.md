# linux-flatten

Linux kernel с патчем `sched/flat` от Peter Zijlstra + оптимизациями для десктопа.

**Универсальное ядро** — совместимо со всеми x86-64 процессорами (Intel Core 2+, AMD Athlon 64+). Не требует `-march=native`.

---

## Быстрая установка (из релизов)

Готовые сборки: [GitHub Releases](https://github.com/MrCripe/linux-flatten/releases)

```bash
# Скачать последний релиз
gh release download --repo MrCripe/linux-flatten --pattern "linux-flatten-*-x86_64.tar.gz"

# Установить
sudo tar -xzf linux-flatten-*-x86_64.tar.gz -C /

# Обновить initramfs
sudo mkinitcpio -p linux-flatten

# Обновить загрузчик (Limine)
sudo limine-scan /boot

# Перезагрузиться
sudo reboot
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
