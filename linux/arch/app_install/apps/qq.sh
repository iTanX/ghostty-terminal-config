#!/usr/bin/env bash
# 通过 Gear Lever 安装或更新腾讯官网发布的 QQ AppImage。
set -euo pipefail

GEAR_LEVER_ID='it.mijorus.gearlever'
QQ_CONFIG_URL='https://qq-web.cdn-go.cn/im.qq.com_new/latest/rainbow/pcConfig.json'
QQ_SIGN_URL='https://im.qq.com/http2rpc/gotrpc/noauth/trpc.qqntv2.urlsign.UrlSign/GetSign'

find_qq_appimage() {
    /usr/bin/python3 -I - "$1" <<'PY'
from configparser import ConfigParser, Error
from pathlib import Path
import os
import sys

# 从 Gear Lever 写入的菜单入口识别 QQ 及其安装位置。
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
    if entry.get('X-AppImage-Name') != 'QQ':
        continue
    launcher = Path(entry.get('TryExec', ''))
    if launcher.is_absolute() and launcher.is_file() and os.access(launcher, os.X_OK):
        launchers.append((launcher, entry.get('Name')))

if len(launchers) > 1:
    sys.exit('已集成多个 QQ AppImage，请在 Gear Lever 中保留要更新的版本后重试。')
if launchers:
    launcher, name = launchers[0]
    if launcher.resolve().parent != appimages_dir or name != 'QQ':
        sys.exit(f'现有 QQ 菜单入口无法原位替换，请先在 Gear Lever 中处理该条目：{launcher}')
    print(launcher)
PY
}

install_qq() (
    local source_url="$1" state_file="$2" appimages_dir="$3" installed="$4"
    shift 4
    local signed_url temp_dir archive checksum integrated sign_payload

    # 4.1 为官网当前 AppImage 获取签名下载地址。
    sign_payload="$(jq -cn --arg url "$source_url" '{url: $url}')"
    if ! signed_url="$(curl --fail --silent --show-error --max-time 30 \
        -H 'Content-Type: application/json' \
        -H 'x-oidb: {"uint32_command":"0x9b8e","uint32_service_type":1}' \
        -H 'Origin: https://im.qq.com' -e 'https://im.qq.com/index/' \
        --data-binary "$sign_payload" "$QQ_SIGN_URL" |
        jq -er 'select(.retcode == 0) | .data.url | select(type == "string")')" ||
        [[ "${signed_url%%\?*}" != "$source_url" || "$signed_url" != *\?* ]]; then
        printf '无法获取 QQ AppImage 的签名下载地址。\n' >&2
        exit 1
    fi

    # 4.2 下载到 Gear Lever 可访问的临时目录。
    temp_dir="$(mktemp -d -- "${state_file%/*}/download.XXXXXXXX")"
    trap 'rm -rf -- "$temp_dir"' EXIT
    archive="$temp_dir/${source_url##*/}"
    printf '正在下载 %s……\n' "${archive##*/}"
    curl --fail --location --retry 3 --connect-timeout 15 --remove-on-error \
        --proto '=https' --proto-redir '=https' --output "$archive" "$signed_url"
    checksum="$(sha256sum < "$archive")"

    # 4.3 更新时应答 Gear Lever 的替换提示，以沿用旧版的应用和菜单路径。
    if [[ -n "$installed" ]]; then
        "$@" --integrate "$archive" --replace <<< $'y\nr'
    else
        "$@" --integrate "$archive" --replace --yes
    fi

    # 4.4 核对集成后的文件，再保存官网链接和文件校验值。
    integrated="$(find_qq_appimage "$appimages_dir")"
    if [[ -z "$integrated" || ( -n "$installed" && "$integrated" != "$installed" ) ]] ||
        [[ "$(sha256sum < "$integrated")" != "$checksum" ]]; then
        printf 'Gear Lever 集成后的 QQ AppImage 验证失败。\n' >&2
        exit 1
    fi
    printf '%s\n%s\n' "$source_url" "$checksum" > "$temp_dir/installed"
    mv -fT -- "$temp_dir/installed" "$state_file"
)

main() {
    local appimages_dir="${HOME}/.local/opt/AppImages"
    local state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/qq-appimage"
    local arch_key source_url state_file installed scope
    local -a gear_lever gear_settings dependencies=()

    # 1. 检查运行环境并安装依赖。
    if [[ "$EUID" -eq 0 || "$(uname -s)" != Linux ]]; then
        printf '请在 Arch Linux 上以普通用户运行。\n' >&2
        return 1
    fi
    case "$(uname -m)" in
        x86_64) arch_key=x64DownloadUrl ;;
        aarch64) arch_key=armDownloadUrl ;;
        *) printf '腾讯官网未提供当前架构的 QQ AppImage。\n' >&2; return 1 ;;
    esac
    command -v jq >/dev/null 2>&1 || dependencies+=(jq)
    pacman -Q fuse2 >/dev/null 2>&1 || dependencies+=(fuse2)
    [[ -x /usr/bin/python3 ]] || dependencies+=(python)
    if ((${#dependencies[@]})); then
        sudo pacman -S --needed --noconfirm "${dependencies[@]}"
    fi

    # 2. 串行查询官网当前 AppImage，并检查是否已经安装。
    mkdir -p -- "$state_dir"
    exec 9> "$state_dir/install.lock"
    flock 9
    state_file="$state_dir/installed"
    if ! source_url="$(curl --fail --silent --show-error --retry 3 --max-time 30 \
        "$QQ_CONFIG_URL" | jq -er --arg arch "$arch_key" \
        '.Linux[$arch].appimage | select(type == "string")')" ||
        [[ "$source_url" != https://qqdl.gtimg.cn/*/*.AppImage || "$source_url" == *[\?\#]* ]]; then
        printf '无法从腾讯官网获取当前架构的 QQ AppImage 地址。\n' >&2
        return 1
    fi
    installed="$(find_qq_appimage "$appimages_dir")"
    if [[ -n "$installed" && -f "$state_file" ]] &&
        [[ "$(<"$state_file")" == "$source_url"$'\n'"$(sha256sum < "$installed")" ]]; then
        printf 'QQ 已是官网当前版本：%s\n' "${source_url##*/}"
        return 0
    fi

    # 3. 复用 Gear Lever，或从已配置的 Flathub 安装。
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

    # 4. 下载并集成当前版本。
    install_qq "$source_url" "$state_file" "$appimages_dir" "$installed" "${gear_lever[@]}"
    printf 'QQ 已安装或更新：%s\n' "${source_url##*/}"
}

main "$@"
