#!/usr/bin/env bash
# 从已配置的 Flathub 安装 Google Chrome；可独立运行。
set -euo pipefail

main() {
    local app_id='com.google.Chrome' scope=--system

    # 1. 检查运行身份和 Flatpak。
    if [[ "$EUID" -eq 0 ]]; then
        printf '请以普通用户运行，不要使用 sudo。\n' >&2
        return 1
    fi
    if ! command -v flatpak >/dev/null 2>&1; then
        printf '缺少 Flatpak，请先完成系统的 Flatpak 设置。\n' >&2
        return 1
    fi

    # 2. 复用已安装的 Chrome，或从已有的 Flathub 安装。
    if flatpak info "$app_id" >/dev/null 2>&1; then
        printf 'Google Chrome 已安装。\n'
        return
    fi
    if flatpak remotes --user --columns=name | grep -Fx flathub >/dev/null; then
        scope=--user
    fi
    flatpak install "$scope" --assumeyes flathub "$app_id"
    printf 'Google Chrome 安装完成。\n'
}

main "$@"
