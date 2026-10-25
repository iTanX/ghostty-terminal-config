#!/usr/bin/env bash
# 用法：bash 00-remove-unused-apps.sh；使用普通用户在 Debian 13 桌面终端运行。
# 删除指定应用及当前用户的专属数据，不备份；不扫描其他用户的主目录。

# ==============================================================================
# 准备配置
# ==============================================================================
set -euo pipefail

progress() {
    printf '\n==> %s\n' "$1"
}

# 1. 检查运行环境
if [ "$(id -u)" -eq 0 ]; then
    echo "错误：请使用普通用户运行本脚本，不要使用 sudo。" >&2
    exit 1
fi

. /etc/os-release
if [ "${ID:-}" != debian ] || [ "${VERSION_ID:-}" != 13 ]; then
    echo "错误：本脚本仅支持 Debian 13。" >&2
    exit 1
fi

for cmd in sudo python3 dconf xdg-user-dir; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "错误：未找到 $cmd，请先安装该依赖。" >&2
        exit 1
    fi
done

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
for dir in "$HOME" "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR" "$STATE_DIR"; do
    if [[ "$dir" != /* || "$dir" == / ]]; then
        echo "错误：用户目录必须为非根目录的绝对路径：$dir" >&2
        exit 1
    fi
done

CAMERA_DIRS=()
for kind in PICTURES VIDEOS; do
    media_dir="$(xdg-user-dir "$kind")"
    if [[ "$media_dir" != /* || "$media_dir" == / ]]; then
        echo "错误：无效的 $kind 用户目录：$media_dir" >&2
        exit 1
    fi
    CAMERA_DIRS+=("$media_dir/Camera")
done

# 2. 收集软件包
PACKAGE_QUERY="$(dpkg-query -W -f='${binary:Package}\t${db:Status-Abbrev}\n')"
mapfile -t PACKAGE_RECORDS <<< "$PACKAGE_QUERY"
PACKAGES=()
INSTALLED_PACKAGES=()
META_PACKAGES=(gnome gnome-core task-gnome-desktop task-desktop task-chinese-s-desktop task-chinese-s-gnome-desktop)

is_target() {
    case "${1%%:*}" in
        xterm|firefox*|libreoffice*|libevolution|libevolution-dev|evolution|evolution-common|evolution-dev|evolution-plugins*|evolution-plugin-*|evolution-ews|shotwell*|totem|totem-common|totem-plugins|libtotem0|libtotem-dev|gir1.2-totem-1.0|gnome-music|gnome-sound-recorder|gnome-snapshot|simple-scan|gnome-contacts|gnome-maps|gnome-weather|gnome-tour|goldendict-ng|malcontent-gui)
            return 0 ;;
        *) return 1 ;;
    esac
}

for record in "${PACKAGE_RECORDS[@]}"; do
    package="${record%%$'\t'*}"
    status="${record#*$'\t'}"
    if [[ "$status" == ii* ]]; then
        INSTALLED_PACKAGES+=("$package")
    fi
    # 同时清除仅剩配置文件的 rc 软件包。
    if [[ "$status" == ii* || "$status" == rc* ]] && is_target "$package"; then
        PACKAGES+=("$package")
    fi
done

# ==============================================================================
# 卸载桌面应用
# ==============================================================================
# 1. 关闭应用进程
progress "清理应用 / 关闭当前用户的应用进程"
PROCESS_PATTERN='^([^ ]*/)?(xterm|uxterm|firefox(-esr)?|soffice\.bin|oosplash|evolution|evolution-alarm-notify|evolution-source-registry|evolution-addressbook-factory|evolution-calendar-factory|evolution-user-prompter|shotwell|totem|gnome-music|gnome-sound-recorder|gnome-snapshot|snapshot|simple-scan|gnome-contacts|gnome-maps|gnome-weather|gnome-tour|goldendict|goldendict-ng|malcontent-control)([[:space:]]|$)'
if pgrep -u "$(id -u)" -f "$PROCESS_PATTERN" >/dev/null; then
    pkill -TERM -u "$(id -u)" -f "$PROCESS_PATTERN" || [ "$?" -eq 1 ]
    # 等待应用保存退出，避免退出时重新写回待删除的数据。
    for ((attempt = 0; attempt < 10; attempt++)); do
        if ! pgrep -u "$(id -u)" -f "$PROCESS_PATTERN" >/dev/null; then
            break
        fi
        sleep 1
    done
    if pgrep -u "$(id -u)" -f "$PROCESS_PATTERN" >/dev/null; then
        echo "错误：应用尚未退出，请关闭后重新运行。" >&2
        exit 1
    fi
fi

# 2. 保留其余桌面组件
progress "清理应用 / 保留其余桌面组件"
sudo -v
# 元包可能随应用移除，将其余已安装的直接依赖保留为手动安装。
DEPENDENCIES="$(LC_ALL=C apt-cache depends --installed --no-suggests --no-conflicts --no-breaks --no-replaces --no-enhances "${META_PACKAGES[@]}")"
KEEP_QUERY="$(python3 -I -c 'import re, sys
for line in sys.stdin:
    match = re.match(r"\s*\|?(?:PreDepends|Depends|Recommends): ([a-z0-9][a-z0-9+.:_-]*)$", line.rstrip())
    if match:
        print(match[1])' <<< "$DEPENDENCIES")"
mapfile -t KEEP_PACKAGES <<< "$KEEP_QUERY"
if [ "${#PACKAGES[@]}" -gt 0 ]; then
    KEEP_INSTALLED=()
    for package in "${KEEP_PACKAGES[@]}"; do
        if is_target "$package"; then
            continue
        fi
        case "${package%%:*}" in
            gnome|gnome-core|task-gnome-desktop|task-desktop|task-chinese-s-desktop|task-chinese-s-gnome-desktop) continue ;;
        esac
        for installed in "${INSTALLED_PACKAGES[@]}"; do
            if [ "${installed%%:*}" = "${package%%:*}" ]; then
                KEEP_INSTALLED+=("$installed")
                break
            fi
        done
    done
    if [ "${#KEEP_INSTALLED[@]}" -gt 0 ]; then
        sudo apt-mark manual "${KEEP_INSTALLED[@]}"
    fi

    # 3. 清除软件包与系统配置
    progress "清理应用 / 清除软件包与系统配置"
    printf '  %s\n' "${PACKAGES[@]}"
    # 核对 APT 计划，避免依赖关系变化时移除正在使用的桌面组件。
    REMOVE_REQUESTS=("${PACKAGES[@]/%/-}")
    REMOVE_PLAN="$(LC_ALL=C apt-get -s autoremove --purge -- "${REMOVE_REQUESTS[@]}")"
    python3 -I -c 'import sys
protected = {"gnome-shell", "gnome-session", "gdm3", "gnome-terminal", "nautilus",
             "network-manager", "pipewire-audio", "evolution-data-server"}
removed = {line.split()[1].split(":")[0] for line in sys.stdin
           if line.startswith(("Remv ", "Purg "))}
if removed & protected:
    sys.exit("错误：APT 计划移除桌面组件：" + ", ".join(sorted(removed & protected)))' <<< "$REMOVE_PLAN"
    sudo apt-get purge -y -- "${PACKAGES[@]}"
fi

# 4. 清除孤立依赖
progress "清理应用 / 清除孤立依赖及其配置"
sudo apt-get autoremove --purge -y

# ==============================================================================
# 清除用户数据
# ==============================================================================
# 1. 重置应用设置
progress "清理数据 / 重置应用设置"
for prefix in \
    /org/gnome/evolution/ \
    /org/gnome/evolution-data-server/ \
    /org/yorba/shotwell/ \
    /org/gnome/shotwell/ \
    /org/gnome/Totem/ \
    /org/gnome/Music/ \
    /org/gnome/SoundRecorder/ \
    /org/gnome/Snapshot/ \
    /org/gnome/simple-scan/ \
    /org/gnome/Contacts/ \
    /org/gnome/maps/ \
    /org/gnome/Weather/ \
    /org/gnome/Tour/; do
    dconf reset -f "$prefix"
done

# 2. 删除配置、个人数据与缓存
progress "清理数据 / 删除配置、个人数据与缓存"
for base in "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR" "$STATE_DIR"; do
    rm -rf -- \
        "$base/mozilla/firefox" \
        "$base/libreoffice" \
        "$base/evolution" \
        "$base/shotwell" \
        "$base/totem" \
        "$base/gnome-music" \
        "$base/gnome-sound-recorder" \
        "$base/gnome-snapshot" \
        "$base/simple-scan" \
        "$base/gnome-contacts" \
        "$base/gnome-maps" \
        "$base/gnome-weather" \
        "$base/gnome-tour" \
        "$base/goldendict" \
        "$base/org.gnome.Shotwell" \
        "$base/org.gnome.Totem" \
        "$base/org.gnome.Music" \
        "$base/org.gnome.SoundRecorder" \
        "$base/org.gnome.Snapshot" \
        "$base/org.gnome.SimpleScan" \
        "$base/org.gnome.Contacts" \
        "$base/org.gnome.Maps" \
        "$base/org.gnome.Weather" \
        "$base/org.gnome.Tour"
done
rm -rf -- "$HOME/.mozilla/firefox" "$HOME/.libreoffice" "$HOME/.openoffice.org" \
    "$HOME/.evolution" "$HOME/.shotwell" "$HOME/.gnome2/totem" \
    "$HOME/.gnome2/accels/totem" "$HOME/.gnome2/shotwell" "$HOME/.xterm" "$HOME/.uxterm" \
    "$HOME/.goldendict"
rm -f -- "$DATA_DIR/maps-places.json"
rm -rf -- "${CAMERA_DIRS[@]}"

# 3. 清除终端资源设置
progress "清理数据 / 清除 XTerm 与 UXTerm 资源设置"
python3 -I - "$HOME" <<'PY'
from pathlib import Path
import re
import sys

for name in ('.Xresources', '.Xdefaults'):
    path = Path(sys.argv[1]) / name
    if not path.is_file():
        continue
    # 只移除目标终端的资源项及续行，其他 X 应用设置保留。
    lines = path.read_text().splitlines(keepends=True)
    kept = []
    removing = False
    for line in lines:
        target = re.match(r'^\s*[.*]?(?:xterm|uxterm)(?=[.*:])', line, re.I)
        if removing or target:
            removing = line.rstrip('\r\n').endswith('\\')
        else:
            kept.append(line)
    if kept != lines:
        path.write_text(''.join(kept))
PY

# 4. 删除自定义应用入口
progress "清理数据 / 删除自定义应用入口"
shopt -s nullglob
for base in "$DATA_DIR/applications" "$CONFIG_DIR/autostart"; do
    rm -f -- \
        "$base"/*firefox*.desktop \
        "$base"/libreoffice*.desktop \
        "$base"/evolution*.desktop \
        "$base"/org.gnome.Evolution*.desktop \
        "$base"/shotwell*.desktop \
        "$base"/org.gnome.Shotwell*.desktop \
        "$base"/totem*.desktop \
        "$base"/org.gnome.Totem*.desktop \
        "$base"/org.gnome.Music.desktop \
        "$base"/org.gnome.SoundRecorder.desktop \
        "$base"/org.gnome.Snapshot.desktop \
        "$base"/simple-scan.desktop \
        "$base"/org.gnome.SimpleScan.desktop \
        "$base"/org.gnome.Contacts.desktop \
        "$base"/org.gnome.Maps.desktop \
        "$base"/org.gnome.Weather.desktop \
        "$base"/org.gnome.Tour.desktop \
        "$base"/io.github.xiaoyifang.goldendict_ng.desktop \
        "$base"/org.freedesktop.MalcontentControl.desktop \
        "$base"/debian-xterm.desktop \
        "$base"/debian-uxterm.desktop
done

# ==============================================================================
# 完成配置
# ==============================================================================
printf '\n指定应用的软件包、配置、当前用户数据及缓存已清除。请注销后重新登录以刷新应用列表。\n'
