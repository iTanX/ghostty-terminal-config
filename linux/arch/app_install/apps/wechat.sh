#!/usr/bin/env bash
# 通过 Gear Lever 安装或更新微信官网发布的 AppImage。
set -euo pipefail

GEAR_LEVER_ID='it.mijorus.gearlever'
WECHAT_DOWNLOAD_DIR='https://dldir1v6.qq.com/weixin/Universal/Linux'

find_wechat_appimage() {
    /usr/bin/python3 -I - "$1" <<'PY'
from configparser import ConfigParser, Error
from pathlib import Path
import os
import sys

# 同时识别 Gear Lever 在中英文会话中写入的应用名。
appimages_dir = Path(sys.argv[1]).resolve()
applications = Path.home() / '.local' / 'share' / 'applications'
launchers = []
for desktop_file in applications.glob('*.desktop'):
    parser = ConfigParser(interpolation=None)
    try:
        parser.read(desktop_file, encoding='utf-8')
    except (Error, UnicodeError):
        continue
    if not parser.has_section('Desktop Entry'):
        continue
    entry = parser['Desktop Entry']
    if entry.get('X-AppImage-Name', '').casefold() not in ('wechat', '微信'):
        continue
    launcher = Path(entry.get('TryExec', ''))
    if launcher.is_absolute() and launcher.is_file() and os.access(launcher, os.X_OK):
        launchers.append((launcher, entry))

if len(launchers) > 1:
    sys.exit('已集成多个微信 AppImage，请在 Gear Lever 中保留要更新的版本后重试。')
if launchers:
    launcher, entry = launchers[0]
    # 替换时 Gear Lever 按当前语言匹配菜单名，避免把改名条目当成新应用。
    if (launcher.resolve().parent != appimages_dir or entry.get('Name') != 'wechat'
            or entry.get('Name[zh_CN]') != '微信'):
        sys.exit(f'现有微信菜单入口无法原位替换，请先在 Gear Lever 中处理该条目：{launcher}')
    print(launcher)
elif any(p.name.casefold().startswith(('wechat', '微信')) and p.suffix.lower() == '.appimage'
         for p in appimages_dir.glob('*')):
    sys.exit('目标目录中有微信 AppImage，但没有有效的菜单入口。请先在 Gear Lever 中修复集成，避免重复安装。')
PY
}

integrate_wechat() {
    local archive="$1" installed="$2" appimages_dir="$3" scope
    local -a gear_lever gear_settings

    # 4.1 复用 Gear Lever，或从已配置的 Flathub 安装。
    if command -v gearlever >/dev/null 2>&1; then
        gear_lever=(gearlever)
        gear_settings=(gsettings)
    elif command -v flatpak >/dev/null 2>&1; then
        if ! flatpak info "$GEAR_LEVER_ID" >/dev/null 2>&1; then
            scope=--system
            if flatpak remotes --user --columns=name | grep -Fx flathub >/dev/null; then
                scope=--user
            fi
            flatpak install "$scope" --assumeyes flathub "$GEAR_LEVER_ID"
        fi
        gear_lever=(flatpak run "$GEAR_LEVER_ID")
        gear_settings=(flatpak run --command=gsettings "$GEAR_LEVER_ID")
    else
        printf '缺少 Gear Lever 和 Flatpak，请先完成系统的 Flatpak 设置。\n' >&2
        return 1
    fi
    mkdir -p -- "$appimages_dir"
    "${gear_settings[@]}" set "$GEAR_LEVER_ID" appimages-default-folder "$appimages_dir"

    # 4.2 更新时确认替换旧版，保留原有 AppImage 和菜单入口的路径。
    if [[ -n "$installed" ]]; then
        "${gear_lever[@]}" --integrate "$archive" --replace <<< $'y\nr'
    else
        "${gear_lever[@]}" --integrate "$archive" --replace --yes
    fi
}

main() (
    local appimages_dir="${HOME}/.local/opt/AppImages"
    local state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/wechat-appimage"
    local arch source_url state_file installed saved_date saved_sum installed_sum=''
    local response last_modified checksum integrated temp_dir archive message
    local -a dependencies=() curl_args=(--fail --location --retry 3 --connect-timeout 15
        --remove-on-error --proto '=https' --proto-redir '=https')

    # 1. 检查运行环境并安装依赖。
    if [[ "$EUID" -eq 0 || "$(uname -s)" != Linux ]]; then
        printf '请在 Arch Linux 上以普通用户运行。\n' >&2
        return 1
    fi
    case "$(uname -m)" in
        x86_64) arch=x86_64 ;;
        aarch64) arch=arm64 ;;
        *) printf '微信官网未提供当前架构的 AppImage。\n' >&2; return 1 ;;
    esac
    pacman -Q fuse2 >/dev/null 2>&1 || dependencies+=(fuse2)
    [[ -x /usr/bin/python3 ]] || dependencies+=(python)
    if ((${#dependencies[@]})); then
        sudo pacman -S --needed --noconfirm "${dependencies[@]}"
    fi

    # 2. 串行检查已安装文件，只在文件与安装记录一致时发送条件请求。
    mkdir -p -- "$state_dir"
    exec 9> "$state_dir/install.lock"
    flock 9
    state_file="$state_dir/installed"
    installed="$(find_wechat_appimage "$appimages_dir")"
    if [[ -n "$installed" ]]; then
        installed_sum="$(sha256sum < "$installed")"
        if [[ -f "$state_file" ]] &&
            { IFS= read -r saved_date && IFS= read -r saved_sum; } < "$state_file" &&
            [[ -n "$saved_date" && "$saved_sum" == "$installed_sum" ]]; then
            curl_args+=(-H "If-Modified-Since: $saved_date")
        fi
    fi

    # 3. 请求官网下载地址；服务器返回 304 时不下载 AppImage。
    source_url="$WECHAT_DOWNLOAD_DIR/WeChatLinux_${arch}.AppImage"
    temp_dir="$(mktemp -d -- "$state_dir/download.XXXXXXXX")"
    trap 'rm -rf -- "$temp_dir"' EXIT
    archive="$temp_dir/${source_url##*/}"
    printf '正在检查微信官网 AppImage……\n'
    response="$(curl "${curl_args[@]}" --output "$archive" \
        --write-out '%{http_code} %header{last-modified}' "$source_url")"
    case "${response%% *}" in
        304) printf '微信已是官网当前版本。\n'; return 0 ;;
        200) last_modified="${response#* }" ;;
        *) printf '微信官网下载未返回完整文件：HTTP %s\n' "${response%% *}" >&2; return 1 ;;
    esac
    checksum="$(sha256sum < "$archive")"

    # 4. 集成新文件，验证菜单入口和文件内容后才保存安装记录。
    if [[ "$checksum" != "$installed_sum" ]]; then
        integrate_wechat "$archive" "$installed" "$appimages_dir"
        integrated="$(find_wechat_appimage "$appimages_dir")"
        if [[ -z "$integrated" || ( -n "$installed" && "$installed" != "$integrated" ) ]] ||
            [[ "$(sha256sum < "$integrated")" != "$checksum" ]]; then
            printf 'Gear Lever 集成后的微信 AppImage 验证失败。\n' >&2
            return 1
        fi
        message='微信已安装或更新。'
    else
        message='微信已是官网当前版本。'
    fi
    printf '%s\n%s\n' "$last_modified" "$checksum" > "$temp_dir/installed"
    mv -fT -- "$temp_dir/installed" "$state_file"
    printf '%s\n' "$message"
)

main "$@"
