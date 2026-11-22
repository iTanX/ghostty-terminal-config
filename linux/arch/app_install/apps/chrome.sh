#!/usr/bin/env bash
# 使用 Yay 从 AUR 安装 Google Chrome；可独立运行。
set -euo pipefail

main() {
    # 1. 检查运行身份。
    if [[ "$EUID" -eq 0 ]]; then
        printf '请以普通用户运行，不要使用 sudo。\n' >&2
        return 1
    fi

    # 2. 复用已安装的 Chrome，或使用 Yay 从 AUR 安装。
    if pacman -Q google-chrome >/dev/null 2>&1; then
        printf 'Google Chrome 已安装。\n'
        return
    fi
    if ! command -v yay >/dev/null 2>&1; then
        printf '缺少 yay，请先安装 yay 后重新运行。\n' >&2
        return 1
    fi
    yay -S --aur --needed --noconfirm google-chrome
    printf 'Google Chrome 安装完成。\n'
}

main "$@"
