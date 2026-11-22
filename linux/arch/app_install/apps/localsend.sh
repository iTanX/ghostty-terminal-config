#!/usr/bin/env bash
# 使用 Yay 从 AUR 安装或更新 LocalSend 的预编译包。
set -euo pipefail

main() {
    # 1. 检查运行身份及 Yay 依赖。
    if [[ "$EUID" -eq 0 ]]; then
        printf '请以普通用户运行，不要使用 sudo。\n' >&2
        return 1
    fi
    if ! command -v yay >/dev/null 2>&1; then
        printf '缺少 yay，请先安装 yay 后重新运行。\n' >&2
        return 1
    fi

    # 2. 安装 AUR 当前版本；已是同版本时跳过重新安装。
    yay -S --aur --needed --noconfirm localsend-bin
}

main "$@"
