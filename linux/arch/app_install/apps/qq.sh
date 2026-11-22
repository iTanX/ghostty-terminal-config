#!/usr/bin/env bash
# 从 Flathub 安装或更新 QQ。
set -euo pipefail

QQ_REF='com.qq.QQ//stable'

main() {
    local scope

    # 1. 检查运行环境和 Flatpak 依赖。
    if [[ "$EUID" -eq 0 || "$(uname -s)" != Linux ]]; then
        printf '请在 Arch Linux 上以普通用户运行。\n' >&2
        return 1
    fi
    if ! command -v flatpak >/dev/null 2>&1; then
        printf '缺少 Flatpak，请先安装 Flatpak 并配置 Flathub。\n' >&2
        return 1
    fi

    # 2. 在已安装的范围内更新，避免重复安装用户版和系统版。
    if flatpak info --user "$QQ_REF" >/dev/null 2>&1; then
        flatpak update --user --assumeyes "$QQ_REF"
        return
    fi
    if flatpak info --system "$QQ_REF" >/dev/null 2>&1; then
        flatpak update --system --assumeyes "$QQ_REF"
        return
    fi

    # 3. 首次安装时使用已配置的 Flathub，优先使用用户级远端。
    if flatpak remotes --user --columns=name | grep -Fx flathub >/dev/null; then
        scope=--user
    elif flatpak remotes --system --columns=name | grep -Fx flathub >/dev/null; then
        scope=--system
    else
        printf '未配置 Flathub，请先添加 Flathub 软件源。\n' >&2
        return 1
    fi
    flatpak install "$scope" --assumeyes flathub "$QQ_REF"
}

main "$@"
