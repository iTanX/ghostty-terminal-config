#!/usr/bin/env bash
# Linux 基础配置：安装 Ghostty、Maple Mono NF CN 字体与 ZSH 配置。
# 自动设置 Ptyxis Regular 10 和 Ghostty 10 号，并修复 Ubuntu 中文字体匹配。
# 适用于 Ubuntu 26.04 LTS 桌面版（Ghostty 官方软件包自 26.04 起提供）。
# 首次可执行：chmod +x 01-basic-config.sh；随后以普通用户运行 ./01-basic-config.sh。
# 不要使用 sudo 执行整个脚本。

set -euo pipefail

# 输出当前步骤，便于在终端中定位执行进度。
progress() {
    printf '\n==> %s\n' "$1"
}

# 安装脚本会自行调用 sudo，且明确拒绝由 root 用户运行。
if [ "$(id -u)" -eq 0 ]; then
    echo "错误：请使用普通用户运行本脚本，不要使用 sudo。" >&2
    exit 1
fi

# 本脚本与安装器都需要 sudo 来执行系统级安装。
if ! command -v sudo >/dev/null 2>&1; then
    echo "错误：未找到 sudo，请先为当前用户配置 sudo 权限。" >&2
    exit 1
fi

progress "基础配置 / ZSH"

# 终端配置已随仓库提供，直接运行本地安装脚本，不再从远端拉取
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TERMINAL_INSTALL="$SCRIPT_DIR/../terminal/install.sh"

if [ ! -f "$TERMINAL_INSTALL" ]; then
    echo "错误：未找到终端配置安装脚本：$TERMINAL_INSTALL" >&2
    exit 1
fi

# 执行设置脚本。该脚本会在需要时请求 sudo 密码。
bash "$TERMINAL_INSTALL"

printf '\n基础配置完成。请注销后重新登录，使 ZSH 配置生效。\n'
