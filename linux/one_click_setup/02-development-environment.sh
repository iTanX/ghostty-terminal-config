#!/usr/bin/env bash
# Linux 开发环境：配置 Python、Node.js、Java 工具链、AI 工具与 .agents 配置。
# 请先完成 01-basic-config.sh。首次可执行：chmod +x 02-development-environment.sh。
# 随后以普通用户运行 ./02-development-environment.sh；不要使用 sudo 执行整个脚本。

set -euo pipefail

# 输出当前步骤，便于在终端中定位执行进度。
progress() {
    printf '\n==> %s\n' "$1"
}

# 避免将 npm、uv、SDKMAN 和用户目录配置写入 root 的 HOME。
if [ "$(id -u)" -eq 0 ]; then
    echo "错误：请使用普通用户运行本脚本，不要使用 sudo。" >&2
    exit 1
fi

# 仅 APT 安装需要 sudo；其余工具均安装到当前用户目录。
if ! command -v sudo >/dev/null 2>&1; then
    echo "错误：未找到 sudo，请先为当前用户配置 sudo 权限。" >&2
    exit 1
fi

# 脚本所在目录用于定位随仓库提供的 Maven settings.xml。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# AI 开发环境

## Git
# 一般内置 Git；01-basic-config.sh 安装终端配置时也会确保 Git 可用。

## Python
# 一般内置 Python，无需另外安装。这里需要安装一些辅助工具。

### python-is-python3
# 安装 python-is-python3，使 python 命令指向 python3。
progress "AI 开发环境 / python-is-python3"
sudo apt install -y python-is-python3

### uv
# 安装 Python 项目管理工具 uv。
progress "AI 开发环境 / uv"
curl -LsSf https://astral.sh/uv/install.sh | sh

# 让本次脚本也能找到 uv；安装器会负责持久化 shell 配置。
export PATH="$HOME/.local/bin:$PATH"

## Node.js
# 使用 nvm 安装 Node.js。
progress "AI 开发环境 / Node.js"

# Download and install nvm:
# 01 步骤已将默认 Shell 切换为 zsh，但当前会话的 $SHELL 可能仍是 bash，
# 而 nvm 安装器按 $SHELL 决定写哪个配置文件，因此显式指定写入 .zshrc。
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh | PROFILE="$HOME/.zshrc" bash

# in lieu of restarting the shell
. "$HOME/.nvm/nvm.sh"

# Download and install Node.js:
nvm install 24

# Verify the Node.js version:
node -v

# Verify npm version:
npm -v

# Java 开发环境

## SDKMAN
# 安装 Java SDK 管理工具 SDKMAN。
# SDKMAN 依赖 zip 与 unzip。
progress "Java 开发环境 / SDKMAN"
sudo apt install -y zip unzip

curl -s "https://get.sdkman.io" | zsh

# SDKMAN 初始化与 CLI 会读取未定义的可选变量，需在整个 SDKMAN 操作期间关闭 nounset。
set +u
. "$HOME/.sdkman/bin/sdkman-init.sh"

# SDKMAN 默认会询问是否设为默认版本；一键脚本启用自动确认。
SDKMAN_CONFIG="$HOME/.sdkman/etc/config"
if grep -q '^sdkman_auto_answer=' "$SDKMAN_CONFIG"; then
    sed -i 's/^sdkman_auto_answer=.*/sdkman_auto_answer=true/' "$SDKMAN_CONFIG"
else
    printf '\nsdkman_auto_answer=true\n' >> "$SDKMAN_CONFIG"
fi

## JDK
# 使用 SDKMAN 安装 JDK25。
progress "Java 开发环境 / JDK 25"
sdk install java 25-tem
sdk default java 25-tem

## Maven
# 使用 SDKMAN 安装 Maven。
progress "Java 开发环境 / Maven 3.9.16"
sdk install maven 3.9.16
sdk default maven 3.9.16
set -u

# 将随仓库提供的 settings.xml 写入 Maven 的用户级配置目录。
progress "Java 开发环境 / Maven settings.xml"
SETTINGS_SOURCE="$SCRIPT_DIR/assets/settings.xml"
SETTINGS_TARGET="$HOME/.m2/settings.xml"
if [ ! -f "$SETTINGS_SOURCE" ]; then
    echo "错误：未找到 Maven 配置文件：$SETTINGS_SOURCE" >&2
    exit 1
fi
mkdir -p "$HOME/.m2"
if [ -d "$SETTINGS_TARGET" ] && [ ! -L "$SETTINGS_TARGET" ]; then
    echo "错误：$SETTINGS_TARGET 是目录，无法写入 Maven 配置。" >&2
    exit 1
fi
if [ -e "$SETTINGS_TARGET" ] || [ -L "$SETTINGS_TARGET" ]; then
    SETTINGS_BACKUP_DIR="$HOME/.m2/settings-backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$SETTINGS_BACKUP_DIR"
    cp -a "$SETTINGS_TARGET" "$SETTINGS_BACKUP_DIR/settings.xml"
    rm -f "$SETTINGS_TARGET"
    echo "已备份原 Maven 配置：$SETTINGS_BACKUP_DIR/settings.xml"
fi
cp "$SETTINGS_SOURCE" "$SETTINGS_TARGET"

# AI 工具

## Claude
# npm 安装 Claude。
progress "AI 工具 / Claude"
npm install -g @anthropic-ai/claude-code@latest

## Codex
# npm 安装 Codex。
progress "AI 工具 / Codex"
npm install -g @openai/codex

## CC Switch
# 使用官方命令安装 CCSwitch-CLI。
# 暂时注释，不安装。
# progress "AI 工具 / CC Switch"
# curl -fsSL https://github.com/SaladDay/cc-switch-cli/releases/latest/download/install.sh | bash

# 同步 AI 配置

# 通过 WebDAV 把 .agents 目录同步到 ~/.agents，再把各工具入口链接到同一个 AGENTS.md
progress "AI 配置 / WebDAV 同步"

# WebDAV 连接信息全部在运行时输入，不写入脚本，避免泄露
read -r -p "WebDAV 地址（如 https://example.com:8443）: " WEBDAV_URL
read -r -p "WebDAV 用户名: " WEBDAV_USER
read -r -s -p "WebDAV 密码: " WEBDAV_PASS
echo

if [ -z "$WEBDAV_URL" ] || [ -z "$WEBDAV_USER" ] || [ -z "$WEBDAV_PASS" ]; then
    echo "错误：WebDAV 地址、用户名和密码均不能为空。" >&2
    exit 1
fi

# rclone 只用于本次同步：系统已有则直接使用，没有则临时安装、脚本结束时彻底卸载
# 用户级目录遵循 XDG 规范，与 rclone 自身的默认路径保持一致
RCLONE_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rclone"
RCLONE_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rclone"
RCLONE_HOME_CONFIG="$HOME/.rclone.conf"

RCLONE_TEMP_INSTALLED=0
# 分别记录三个用户级路径在运行前是否已存在，仅清理本次新建的
RCLONE_CONFIG_DIR_PREEXISTED=0
RCLONE_CACHE_DIR_PREEXISTED=0
RCLONE_HOME_CONFIG_PREEXISTED=0
[ -e "$RCLONE_CONFIG_DIR" ] && RCLONE_CONFIG_DIR_PREEXISTED=1
[ -e "$RCLONE_CACHE_DIR" ] && RCLONE_CACHE_DIR_PREEXISTED=1
[ -e "$RCLONE_HOME_CONFIG" ] && RCLONE_HOME_CONFIG_PREEXISTED=1
true

# 清理函数同时挂到 EXIT trap，保证中途失败或中断时也不会留下 rclone
cleanup_rclone() {
    [ "$RCLONE_TEMP_INSTALLED" -eq 1 ] || return 0
    RCLONE_TEMP_INSTALLED=0
    echo ""
    echo "==> 清理临时安装的 rclone"
    # 卸载 rclone，再由包管理器按依赖图清理不再被任何包需要的自动安装包
    sudo apt-get purge -y rclone || true
    sudo apt-get autoremove --purge -y || true
    # 删除本次安装留下的 apt 包缓存
    sudo sh -c 'rm -f /var/cache/apt/archives/rclone_*.deb' || true
    # 仅删除本次运行前不存在的用户级配置与缓存，避免影响原有 rclone 数据
    if [ "$RCLONE_CONFIG_DIR_PREEXISTED" -eq 0 ]; then
        rm -rf "$RCLONE_CONFIG_DIR"
    fi
    if [ "$RCLONE_CACHE_DIR_PREEXISTED" -eq 0 ]; then
        rm -rf "$RCLONE_CACHE_DIR"
    fi
    if [ "$RCLONE_HOME_CONFIG_PREEXISTED" -eq 0 ]; then
        rm -f "$RCLONE_HOME_CONFIG"
    fi
    echo "    ✓ rclone 已卸载"
}
trap cleanup_rclone EXIT

if command -v rclone >/dev/null 2>&1; then
    echo "    检测到系统已安装 rclone，直接使用，不做安装或卸载。"
else
    echo "    系统未安装 rclone，临时安装。"
    sudo apt-get install -y --no-install-recommends rclone
    RCLONE_TEMP_INSTALLED=1
fi

# rclone 的 WebDAV 密码参数必须使用 rclone obscure 处理后的值
RCLONE_PASS="$(rclone obscure "$WEBDAV_PASS")"

# 排除 Syncthing 的同步状态文件，避免把 .stfolder*、.stignore、#SyncVersion 带到本地
if ! rclone copy \
    ":webdav,url=$WEBDAV_URL,user=$WEBDAV_USER,pass=$RCLONE_PASS:/swap/AI/.agents" \
    "$HOME/.agents" \
    --create-empty-src-dirs \
    --exclude '/.stfolder*/**' \
    --exclude '/.stignore' \
    --exclude '/#SyncVersion/**'; then
    echo "错误：从 WebDAV 下载 .agents 失败，请检查网络、证书和账号密码。" >&2
    exit 1
fi

# 前置校验
[ -f "$HOME/.agents/AGENTS.md" ] || { echo "错误: $HOME/.agents/AGENTS.md 不存在" >&2; exit 1; }

mkdir -p "$HOME/.claude" "$HOME/.codex"

# ---------- 建链接（仅替换文件或软链接，可重复执行）----------
# 同名真实目录不会删除，避免覆盖已有用户配置。
link() {
    if [ -d "$2" ] && [ ! -L "$2" ]; then
        echo "错误: $2 是目录，拒绝删除；请先手动处理后重试。" >&2
        exit 1
    fi
    rm -f "$2"
    ln -s "$1" "$2"
}

link "$HOME/.agents/AGENTS.md" "$HOME/.claude/CLAUDE.md"   # 1. ~/.claude/CLAUDE.md -> ~/.agents/AGENTS.md
link "$HOME/.agents/AGENTS.md" "$HOME/.codex/AGENTS.md"    # 2. ~/.codex/AGENTS.md  -> ~/.agents/AGENTS.md

# ---------- 验证 ----------
for p in "$HOME/.claude/CLAUDE.md" "$HOME/.codex/AGENTS.md"; do
    [ -e "$p" ] && echo "OK   $p -> $(readlink "$p")" || { echo "失败 $p" >&2; exit 1; }
done

# rclone 用完即卸（若系统原本没有）
cleanup_rclone

printf '\n开发环境配置完成。请注销后重新登录，使新安装工具的环境变量完全生效。\n'
