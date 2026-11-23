#!/usr/bin/env bash
# 从 Arch 官方仓库安装 VLC 及常用解码、字幕插件。
set -euo pipefail

main() {
    # 1. 检查运行环境。
    if [[ "$EUID" -eq 0 || "$(uname -s)" != Linux ]]; then
        printf '请在 Arch Linux 上以普通用户运行。\n' >&2
        return 1
    fi

    # 2. 安装 VLC 和扩展插件，复用已安装的软件包。
    if pacman -Q vlc vlc-plugins-extra >/dev/null 2>&1; then
        printf 'VLC 和常用插件已安装。\n'
    else
        sudo pacman -S --needed --noconfirm vlc vlc-plugins-extra
    fi
}

main "$@"
