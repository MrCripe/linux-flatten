#!/usr/bin/env bash
# build-local.sh — Сборка linux-flatten под Xeon E31270 (Sandy Bridge)
# Запуск: ./build-local.sh
# Требования: Arch Linux, base-devel, git, bc

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
err()   { echo -e "${RED}[✗]${NC} $1"; }
step()  { echo -e "${CYAN}==>${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

KERNEL_BRANCH="sched/flat"
KERNEL_REPO="https://git.kernel.org/pub/scm/linux/kernel/git/peterz/queue.git"
SRC_DIR="src/linux-flatten"
NPROC=$(nproc)

header() {
    echo ""
    echo -e "${BOLD}=========================================${NC}"
    echo -e "${BOLD}  $1${NC}"
    echo -e "${BOLD}=========================================${NC}"
    echo ""
}

header "linux-flatten — сборка под Xeon E31270"

# ── Проверка зависимостей ──────────────────────────────────────
step "Проверка зависимостей..."
for cmd in git make gcc ld; do
    command -v "$cmd" >/dev/null 2>&1 || { err "Не найден: $cmd"; exit 1; }
done
info "Все зависимости на месте"

# ── Клонирование / обновление исходников ────────────────────────
step "Получение исходников ядра (ветка: $KERNEL_BRANCH)..."
if [ ! -d "$SRC_DIR" ]; then
    git clone --depth=1 --single-branch -b "$KERNEL_BRANCH" "$KERNEL_REPO" "$SRC_DIR"
    info "Репозиторий клонирован"
else
    cd "$SRC_DIR"
    OLD_HEAD=$(git rev-parse --short HEAD)
    git fetch origin "$KERNEL_BRANCH" --depth=1 2>/dev/null
    git reset --hard "origin/$KERNEL_BRANCH" 2>/dev/null
    NEW_HEAD=$(git rev-parse --short HEAD)
    if [ "$OLD_HEAD" = "$NEW_HEAD" ]; then
        info "Уже актуальная версия ($NEW_HEAD)"
    else
        info "Обновлено: $OLD_HEAD → $NEW_HEAD"
    fi
    cd "$SCRIPT_DIR"
fi

cd "$SRC_DIR"

# ── Определение версии ядра ─────────────────────────────────────
step "Определение версии ядра..."
make defconfig 2>/dev/null
KERNEL_VERSION=$(make kernelrelease)
LOCALVERSION=$(echo "$KERNEL_VERSION" | grep -oP '(?<=-)[a-f0-9]+' || echo "")
info "Версия ядра: $KERNEL_VERSION"

# ── Конфигурация ядра ───────────────────────────────────────────
step "Настройка конфигурации (Xeon E31270, Sandy Bridge)..."

# Базовый конфиг + все модули
make defconfig
make allmodconfig

# ── CPU: Xeon E31270 = Sandy Bridge ──
scripts/config -d GENERIC_CPU
scripts/config -e MCORE2
scripts/config -e MNATIVE
scripts/config -d X86_NATIVE_CPU
info "CPU: Sandy Bridge (MCORE2 + MNATIVE)"

# ── Компилятор: -O3 ──
scripts/config -d CC_OPTIMIZE_FOR_PERFORMANCE
scripts/config -e CC_OPTIMIZE_FOR_PERFORMANCE_O3
info "Компилятор: -O3"

# ── Таймер: 1000 Hz ──
scripts/config -d HZ_300
scripts/config -e HZ_1000
scripts/config --set-val HZ 1000
info "Таймер: HZ=1000"

# ── Preempt Lazy ──
scripts/config -e PREEMPT_LAZY
scripts/config -d PREEMPT
info "Preempt: LAZY"

# ── BBR3 ──
scripts/config -m TCP_CONG_BBR3
info "TCP: BBR3"

# ── THP: MADVISE ──
scripts/config -e TRANSPARENT_HUGEPAGE_MADVISE
scripts/config -d TRANSPARENT_HUGEPAGE_ALWAYS
info "THP: MADVISE"

# ── Модули: ZSTD сжатие ──
scripts/config -d MODULE_COMPRESS_XZ
scripts/config -e MODULE_COMPRESS_ZSTD
info "Модули: ZSTD сжатие"

# ── NUMA: off (single socket) ──
scripts/config -d NUMA
scripts/config -d NUMA_BALANCING
info "NUMA: отключена"

# ── Debug info: none ──
scripts/config -d DEBUG_INFO
scripts/config -d DEBUG_INFO_DWARF4
scripts/config -d DEBUG_INFO_DWARF5
scripts/config -e DEBUG_INFO_NONE
info "Debug info: отключен"

# ── Trim LSMs ──
scripts/config -d SECURITY_YAMA
scripts/config -d SECURITY_LANDLOCK
scripts/config -d SECURITY_SELINUX
scripts/config -d SECURITY_SMACK
scripts/config -d SECURITY_APPARMOR
info "LSM: обрезаны"

# ── Отключаем ненужное ──
scripts/config -d CONFIG_FTRACE
scripts/config -d CONFIG_KPROBES
scripts/config -d CONFIG_KGDB
scripts/config -d CONFIG_KEXEC
scripts/config -d CONFIG_CRASH_DUMP
scripts/config -d CONFIG_EFI_MIXED
scripts/config -d SCHED_CLASS_EXT
info "Отключено: ftrace, kprobes, kgdb, kexec, crash_dump, efi_mixed, sched_class_ext"

# ── Подпись модулей: SHA256 ──
scripts/config -d MODULE_SIG_SHA512
scripts/config -e MODULE_SIG_SHA256
info "Подпись модулей: SHA256"

# ── GCC плагины: отключены ──
scripts/config -d GCC_PLUGINS
scripts/config -d GCC_PLUGIN_LATENT_ENTROPY
info "GCC плагины: отключены"

# ── NR_CPUS: 8 (4 cores / 8 threads) ──
scripts/config --set-val CONFIG_NR_CPUS 8
scripts/config -d CONFIG_MAXSMP
info "NR_CPUS: 8"

# ── Local version ──
scripts/config --set-str CONFIG_LOCALVERSION "-flatten"

# ── Финализация ──
make olddefconfig

info "Конфигурация готова"

# ── Сборка ядра ─────────────────────────────────────────────────
header "Сборка ядра"
echo -e "  ${BOLD}Ядро:${NC}    $KERNEL_VERSION"
echo -e "  ${BOLD}Потоков:${NC} $NPROC"
echo -e "  ${BOLD}Начало:${NC}  $(date)"
echo ""

BUILD_START=$(date +%s)

make -j"$NPROC" all 2>&1 | tail -5

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))
MINUTES=$((BUILD_TIME / 60))
SECONDS=$((BUILD_TIME % 60))

info "Сборка завершена за ${MINUTES}м ${SECONDS}с"

# ── Установка модулей ───────────────────────────────────────────
step "Установка модулей..."
rm -rf "$SCRIPT_DIR/pkg"
make INSTALL_MOD_PATH="$SCRIPT_DIR/pkg/usr" INSTALL_MOD_STRIP=1 \
    DEPMOD=/doesnt/exist modules_install 2>&1 | tail -3
info "Модули установлены"

# ── Установка ядра ──────────────────────────────────────────────
step "Установка образа ядра..."
install -Dm644 "arch/x86/boot/bzImage" "$SCRIPT_DIR/pkg/boot/vmlinuz-linux-flatten"
info "Образ ядра: $(ls -lh "$SCRIPT_DIR/pkg/boot/vmlinuz-linux-flatten" | awk '{print $5}')"

# ── Preset для mkinitcpio ───────────────────────────────────────
step "Создание preset для mkinitcpio..."
mkdir -p "$SCRIPT_DIR/pkg/etc/mkinitcpio.d"
cat > "$SCRIPT_DIR/pkg/etc/mkinitcpio.d/linux-flatten.preset" <<'EOF'
ALL_kver="/boot/vmlinuz-linux-flatten"
ALL_config="/etc/mkinitcpio.conf"
default_image="/boot/initramfs-linux-flatten.img"
EOF
info "Preset создан"

# ── Создание пакета ─────────────────────────────────────────────
step "Создание пакета..."
cd "$SCRIPT_DIR/pkg"

# Генерируем .PKGINFO
KERNEL_VER_LOCAL=$(echo "$KERNEL_VERSION" | sed 's/-flatten//')
cat > .PKGINFO <<EOF
pkgname = linux-flatten
pkgver = ${KERNEL_VER_LOCAL}-1
pkgdesc = Linux kernel with sched/flat patch + Xeon E31270 optimizations
url = https://github.com/MrCripe/linux-flatten
builddate = $(date +%s)
packager = build-local.sh
size = $(du -sb . | awk '{print $1}')
arch = x86_64
license = GPL2
depend = coreutils
depend = kmod
depend = mkinitcpio
EOF

# Генерируем .MTREE
find . -type f -o -type l | sort | while read -r f; do
    f="${f#./}"
    if [ -f "$f" ]; then
        sha=$(sha256sum "$f" | awk '{print $1}')
        size=$(stat -c%s "$f")
        echo "$f sha256=$sha size=$size"
    fi
done > .MTREE

# Упаковываем
cd "$SCRIPT_DIR/pkg"
PKG_FILE="$SCRIPT_DIR/linux-flatten-${KERNEL_VER_LOCAL}-1-x86_64.pkg.tar.zst"
tar -czf "$PKG_FILE" .PKGINFO .MTREE boot/ etc/ usr/ 2>/dev/null || \
    tar --zstd -cf "$PKG_FILE" .PKGINFO .MTREE boot/ etc/ usr/

info "Пакет создан: $(ls -lh "$PKG_FILE" | awk '{print $5, $9}')"

# ── Итог ────────────────────────────────────────────────────────
header "Готово!"
echo -e "  ${BOLD}Ядро:${NC}      $KERNEL_VERSION"
echo -e "  ${BOLD}Время:${NC}     ${MINUTES}м ${SECONDS}с"
echo -e "  ${BOLD}Модулей:${NC}   $(find "$SCRIPT_DIR/pkg/usr/lib/modules" -name '*.ko*' 2>/dev/null | wc -l)"
echo -e "  ${BOLD}Размер:${NC}    $(du -sh "$SCRIPT_DIR/pkg/usr/lib/modules" 2>/dev/null | awk '{print $1}')"
echo ""
echo -e "  ${BOLD}Установка:${NC}"
echo -e "    ${CYAN}sudo pacman -U $PKG_FILE${NC}"
echo -e "    ${CYAN}sudo mkinitcpio -p linux-flatten${NC}"
echo -e "    ${CYAN}sudo reboot${NC}"
echo ""
