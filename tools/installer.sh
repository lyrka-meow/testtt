#!/bin/bash
# Nemac DE Installer — safe version
# No set -e: we handle errors manually to avoid leaving system in broken state

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

NEMAC_REPO="lyrka-meow/testtt"
NEMAC_VERSION="1.0"
GITHUB_API="https://api.github.com/repos/$NEMAC_REPO/releases/latest"
NEMAC_BIN="/usr/local/bin/nemac"
NEMAC_DEV_BIN="/usr/local/bin/nemac-dev"
START_CMD="exec nemac-session"
LOGFILE="/tmp/nemac-install.log"

# Safe paths: tar extraction only allowed into these prefixes
SAFE_PREFIXES=(
    "usr/bin/"
    "usr/local/bin/"
    "usr/lib/qt/"
    "usr/lib/cmake/NemacUI"
    "usr/lib/libnemac"
    "usr/lib/libNemac"
    "usr/lib/systemd/user/"
    "usr/share/nemac"
    "usr/share/applications/"
    "usr/share/backgrounds/nemacde"
    "usr/share/icons/Crule"
    "usr/share/themes/Nemac"
    "usr/share/xsessions/"
    "usr/share/kwin/"
    "usr/share/kwin-wayland/"
    "usr/share/polkit-1/actions/org.nemac."
    "usr/share/polkit-1/actions/com.nemac."
    "opt/nemac-de"
    "etc/nemac"
    "etc/xdg/"
)

die() {
    echo -e "  ${RED}ОШИБКА: $1${NC}" >&2
    echo "[$(date)] FATAL: $1" >> "$LOGFILE"
    exit 1
}

warn() {
    echo -e "  ${YELLOW}ПРЕДУПРЕЖДЕНИЕ: $1${NC}"
    echo "[$(date)] WARN: $1" >> "$LOGFILE"
}

# Base Qt5 deps (no kwin/kf5 — those are resolved dynamically)
BASE_DEPS=(
    qt5-base qt5-declarative qt5-quickcontrols2 qt5-x11extras qt5-svg qt5-graphicaleffects
    qt5-sensors
    polkit polkit-qt5
    networkmanager-qt5
    libqt5xdg libdbusmenu-qt5
    libcanberra
    libxcb xcb-util xcb-util-wm xcb-util-keysyms
    libpulse
    bluez bluez-qt5
    xdg-utils
    freetype2 fontconfig
    syntax-highlighting5
    libxcrypt icu
    xclip
)

# KWin/KF deps resolved at runtime based on installed version
KWIN5_DEPS=(kwin kdecoration kwindowsystem5 kidletime5 kcoreaddons5 libkscreen5 kio5 solid5)
KWIN6_DEPS=(kdecoration kwindowsystem kidletime kcoreaddons libkscreen kio solid)

print_header() {
    clear
    echo -e "${CYAN}"
    echo '  _   _                            ____  _____ '
    echo ' | \ | | ___ _ __ ___   __ _  ___ |  _ \| ____|'
    echo ' |  \| |/ _ \ '\''_ ` _ \ / _` |/ __|| | | |  _|  '
    echo ' | |\  |  __/ | | | | | (_| | (__ | |_| | |___ '
    echo ' |_| \_|\___|_| |_| |_|\__,_|\___||____/|_____|'
    echo -e "${NC}"
    echo ""
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}  Запустите установщик с sudo:${NC}"
        echo -e "  ${YELLOW}sudo bash installer.sh${NC}"
        exit 1
    fi
}

check_arch() {
    if ! command -v pacman &> /dev/null; then
        echo -e "${RED}  Nemac DE работает только на Arch Linux.${NC}"
        exit 1
    fi
}

detect_kwin_version() {
    # Check what kwin is already installed
    if pacman -Qi kwin-x11 &>/dev/null; then
        local kwin_ver
        kwin_ver=$(pacman -Qi kwin-x11 2>/dev/null | grep "^Версия\|^Version" | awk '{print $3}' | cut -d. -f1)
        if [ "$kwin_ver" -ge 6 ] 2>/dev/null; then
            echo "6"
            return
        fi
    fi
    if pacman -Qi kwin &>/dev/null; then
        local kwin_ver
        kwin_ver=$(pacman -Qi kwin 2>/dev/null | grep "^Версия\|^Version" | awk '{print $3}' | cut -d. -f1)
        if [ "$kwin_ver" -ge 6 ] 2>/dev/null; then
            echo "6"
            return
        fi
    fi
    echo "5"
}

install_dependencies() {
    echo ""
    echo -e "  ${BLUE}[1/5]${NC} Проверяю систему..."

    # Verify pacman database is OK before we touch anything
    if ! pacman -Qk 2>/dev/null | tail -1 > /dev/null; then
        warn "Не удалось проверить базу pacman"
    fi

    echo -e "  ${BLUE}[2/5]${NC} Устанавливаю зависимости..."

    local deps=("${BASE_DEPS[@]}")

    # Detect KWin version and add correct deps
    local kwin_ver
    kwin_ver=$(detect_kwin_version)

    # Nemac DE bundles KWin 5.27 in /opt/nemac-de/kwin — always use KF5 deps regardless of system KWin
    if [ "$kwin_ver" = "6" ]; then
        echo -e "  ${YELLOW}  Обнаружен KWin 6 — используем встроенный KWin 5.27 (/opt/nemac-de/kwin)${NC}"
    fi
    deps+=("${KWIN5_DEPS[@]}")

    if ! pacman -Qi xorg-server &>/dev/null; then
        deps+=(xorg-server)
    fi
    if ! pacman -Qi xorg-xinit &>/dev/null; then
        deps+=(xorg-xinit)
    fi
    if ! pacman -Qi xorg-xrdb &>/dev/null; then
        deps+=(xorg-xrdb)
    fi
    if ! pacman -Qi pipewire-pulse &>/dev/null && ! pacman -Qi pulseaudio &>/dev/null; then
        deps+=(pipewire-pulse)
    fi

    # Filter out packages that conflict with already installed ones
    local safe_deps=()
    for pkg in "${deps[@]}"; do
        # Check if installing this package would cause conflicts
        if pacman -Si "$pkg" &>/dev/null; then
            safe_deps+=("$pkg")
        else
            warn "Пакет '$pkg' не найден в репозиториях, пропускаю"
        fi
    done

    if [ ${#safe_deps[@]} -gt 0 ]; then
        echo "[$(date)] Installing: ${safe_deps[*]}" >> "$LOGFILE"
        if ! pacman -S --needed --noconfirm "${safe_deps[@]}" >> "$LOGFILE" 2>&1; then
            die "Не удалось установить зависимости. Лог: $LOGFILE"
        fi
    fi

    echo -e "  ${GREEN}[2/5]${NC} Зависимости установлены  ${GREEN}✓${NC}"
}

# Check if a path from tar archive is safe to extract
is_safe_path() {
    local path="$1"

    # Block absolute paths and path traversal
    if [[ "$path" == /* ]] || [[ "$path" == *..* ]]; then
        return 1
    fi

    # Block overwriting critical system dirs/files
    local blocked=(
        "etc/pacman" "etc/resolv" "etc/NetworkManager" "etc/systemd/system"
        "etc/passwd" "etc/shadow" "etc/group" "etc/sudoers" "etc/fstab"
        "etc/hostname" "etc/hosts" "etc/locale" "etc/mkinitcpio"
        "usr/lib/modules" "usr/lib/firmware" "usr/lib/systemd/system"
        "var/" "boot/" "root/" "home/"
    )
    for b in "${blocked[@]}"; do
        if [[ "$path" == ${b}* ]]; then
            return 1
        fi
    done

    # Must match at least one safe prefix
    for prefix in "${SAFE_PREFIXES[@]}"; do
        if [[ "$path" == ${prefix}* ]]; then
            return 0
        fi
    done

    return 1
}

download_and_install() {
    echo -e "  ${BLUE}[3/5]${NC} Скачиваю Nemac DE..."

    local release_info download_url remote_tag

    release_info=$(curl -fsSL "$GITHUB_API" 2>/dev/null) || true

    if [ -z "$release_info" ]; then
        die "Не удалось получить информацию о релизе. Проверьте интернет."
    fi

    remote_tag=$(echo "$release_info" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
    download_url=$(echo "$release_info" | grep '"browser_download_url"' | grep '\.tar\.gz"' | head -1 | sed 's/.*"\(https[^"]*\)".*/\1/')

    if [ -z "$download_url" ]; then
        die "Бинарный пакет не найден в релизе $remote_tag. Установите из исходников: nemac-dev build"
    fi

    echo -ne "         Скачиваю $remote_tag...\r"
    local tmpfile="/tmp/nemac-install-${remote_tag}.tar.gz"

    if ! curl -fSL "$download_url" -o "$tmpfile" 2>/dev/null; then
        die "Ошибка скачивания"
    fi

    # --- SAFE EXTRACTION ---
    # 1. List archive contents and verify every file is safe
    echo -ne "         Проверяю содержимое архива...\r"
    local bad_files=0
    while IFS= read -r filepath; do
        # Skip directory entries
        [[ "$filepath" == */ ]] && continue
        if ! is_safe_path "$filepath"; then
            warn "Опасный путь в архиве: $filepath"
            echo "BLOCKED: $filepath" >> "$LOGFILE"
            bad_files=$((bad_files + 1))
        fi
    done < <(tar tzf "$tmpfile" 2>/dev/null)

    if [ "$bad_files" -gt 0 ]; then
        die "Архив содержит $bad_files опасных путей. Установка отменена. См. $LOGFILE"
    fi

    # 2. Extract only to safe locations, preserve no ownership from archive
    echo -ne "         Устанавливаю...\r"
    if ! tar xzf "$tmpfile" -C / --no-same-owner 2>>"$LOGFILE"; then
        die "Ошибка распаковки архива"
    fi

    # 3. Fix permissions on extracted nemac binaries
    for f in /usr/bin/nemac-* /usr/bin/chotkeys /usr/bin/cupdatecursor /usr/bin/ccheckpass; do
        [ -f "$f" ] && chmod 755 "$f"
    done

    rm -f "$tmpfile"
    echo -e "  ${GREEN}[3/5]${NC} Nemac DE $remote_tag установлен  ${GREEN}✓${NC}"
}

install_config() {
    echo -e "  ${BLUE}[4/5]${NC} Настраиваю систему..."

    rm -f /usr/share/applications/cutefish-*.desktop 2>/dev/null

    # Ensure management scripts from repo are available
    local repo_dir="/opt/nemac-de"
    if [ -d "$repo_dir" ]; then
        [ -f "$repo_dir/nemac" ] && cp "$repo_dir/nemac" "$NEMAC_BIN" && chmod 755 "$NEMAC_BIN"
        [ -f "$repo_dir/nemac-dev" ] && cp "$repo_dir/nemac-dev" "$NEMAC_DEV_BIN" && chmod 755 "$NEMAC_DEV_BIN"
    fi

    cat > /etc/nemac << CONF
[General]
Version=$NEMAC_VERSION
CONF
    chmod 644 /etc/nemac

    cat > /etc/nemacde << CONF
[General]
NemacDE=true
CONF
    chmod 644 /etc/nemacde

    echo -e "  ${GREEN}[4/5]${NC} Конфигурация готова  ${GREEN}✓${NC}"
}

setup_xinitrc() {
    echo -e "  ${BLUE}[5/5]${NC} Настраиваю автозапуск..."

    local real_user="${SUDO_USER:-$USER}"
    local real_home
    real_home=$(eval echo "~$real_user")
    local target="$real_home/.xinitrc"

    if [ ! -f "$target" ]; then
        echo "$START_CMD" > "$target"
        chown "$real_user":"$real_user" "$target"
        chmod 644 "$target"
    else
        if ! grep -q "nemac-session" "$target"; then
            # Backup existing xinitrc
            cp "$target" "${target}.bak.$(date +%s)"
            sed -i 's/^exec /#exec /g' "$target"
            echo "$START_CMD" >> "$target"
            echo -e "         ${YELLOW}Бэкап старого .xinitrc сохранён${NC}"
        fi
    fi

    echo -e "  ${GREEN}[5/5]${NC} Файл ~/.xinitrc настроен  ${GREEN}✓${NC}"
}

uninstall_nemac() {
    print_header
    echo -e "  ${RED}Удаление Nemac DE...${NC}"
    echo ""

    # Binaries
    local bins=(
        nemac-session nemac-settings-daemon nemac-statusbar nemac-dock
        nemac-launcher nemac-filemanager nemac-notificationd nemac-powerman
        nemac-clipboard nemac-xembedsniproxy nemac-gmenuproxy chotkeys
        cupdatecursor nemac-screenshot nemac-terminal nemac-settings
        nemac-screenlocker nemac-shutdown nemac-screen-brightness
        nemac-cpufreq nemac-polkit-agent nemac-texteditor nemac-calculator
        ccheckpass nemac-updator
    )
    for bin in "${bins[@]}"; do
        rm -f "/usr/bin/$bin" 2>/dev/null
    done

    rm -f "$NEMAC_BIN" "$NEMAC_DEV_BIN"
    rm -f /etc/nemac /etc/nemacde
    rm -rf /usr/share/backgrounds/nemacde
    rm -rf /usr/share/icons/nemac-light /usr/share/icons/nemac-dark
    rm -rf /usr/share/icons/Crule /usr/share/icons/Crule-dark
    rm -rf /usr/share/themes/Nemac /usr/share/themes/Nemac-light /usr/share/themes/Nemac-dark
    rm -f /usr/share/xsessions/nemac.desktop
    rm -f /usr/share/applications/nemac-*.desktop
    rm -rf /usr/share/nemac-*
    rm -rf /usr/share/kwin/scripts/nemaclauncher
    rm -rf /usr/share/kwin/effects/nemac_*
    rm -rf /usr/share/kwin/tabbox/nemac_*
    rm -f /etc/xdg/autostart/nemac-polkit-agent.desktop
    rm -f /usr/lib/systemd/user/nemac-gmenuproxy.service
    rm -f /etc/nemac-dock-list.conf
    rm -rf /opt/nemac-de

    # QML plugins
    local qml_dir
    qml_dir=$(qmake -query QT_INSTALL_QML 2>/dev/null || echo "/usr/lib/qt/qml")
    rm -rf "$qml_dir/Nemac" "$qml_dir/NemacUI"
    rm -rf "$qml_dir/QtQuick/Controls.2/fish-style"

    # Qt plugins
    local qt_plugins
    qt_plugins=$(qmake -query QT_INSTALL_PLUGINS 2>/dev/null || echo "/usr/lib/qt/plugins")
    rm -f "$qt_plugins/styles/libnemacstyle.so"
    rm -f "$qt_plugins/platformthemes/libnemacplatformtheme.so"
    rm -f "$qt_plugins/kwin/effects/plugins/libroundedwindow.so"
    rm -f "$qt_plugins/org.kde.kdecoration2/libnemacdecoration.so"

    rm -rf /usr/lib/cmake/NemacUI

    # xinitrc
    local real_user="${SUDO_USER:-$USER}"
    local real_home
    real_home=$(eval echo "~$real_user")
    local target="$real_home/.xinitrc"

    if [ -f "$target" ]; then
        sed -i '/nemac-session/d' "$target"
        sed -i 's/^#exec /exec /g' "$target"
    fi

    echo -e "  ${GREEN}Nemac DE полностью удалён.${NC}"
    echo ""
}

do_install() {
    check_root
    check_arch

    # Start log
    echo "[$(date)] Nemac DE installer v${NEMAC_VERSION} started" > "$LOGFILE"
    echo "[$(date)] System: $(uname -r), pacman: $(pacman --version 2>/dev/null | head -1)" >> "$LOGFILE"

    print_header
    echo -e "  ${BOLD}Установка Nemac DE v${NEMAC_VERSION}${NC}"
    echo -e "  ${CYAN}—————————————————————————————————${NC}"

    install_dependencies
    download_and_install
    install_config
    setup_xinitrc

    # Verify pacman is still OK
    if ! pacman -Qi coreutils &>/dev/null; then
        die "Проверка pacman после установки провалилась! Система может быть повреждена."
    fi

    echo ""
    echo -e "  ${CYAN}—————————————————————————————————${NC}"
    echo -e "  ${GREEN}${BOLD}Готово! Nemac DE установлен.${NC}"
    echo -e "  Лог: ${YELLOW}$LOGFILE${NC}"
    echo ""
    echo -e "  Для запуска выполните:"
    echo -e "  ${YELLOW}${BOLD}startx${NC}"
    echo ""
    echo -e "  Для управления (обновить, удалить):"
    echo -e "  ${YELLOW}nemac${NC}"
    echo ""
}

if [ "$1" = "--uninstall" ]; then
    check_root
    uninstall_nemac
    exit 0
fi

do_install
