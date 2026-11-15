#!/usr/bin/env bash

# ==============================================================================
# 准备配置
# ==============================================================================
set -euo pipefail

progress() {
    printf '\n==> %s\n' "$1"
}

if [ "$(id -u)" -eq 0 ]; then
    echo "错误：请使用普通用户运行本脚本，不要使用 sudo。" >&2
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    echo "错误：未找到 sudo，请先为当前用户配置 sudo 权限。" >&2
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 1. 检查运行环境
if [ ! -r /etc/os-release ]; then
    echo "错误：无法识别当前操作系统。" >&2
    exit 1
fi
. /etc/os-release
if [ "${ID:-}" != "arch" ] || [ "$(uname -m)" != "x86_64" ]; then
    echo "错误：本脚本仅支持 x86_64 架构的 Arch Linux。" >&2
    exit 1
fi

MISE_SOURCE="$SCRIPT_DIR/assets/mise.toml"
MISE_TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/mise/config.toml"
if [ ! -f "$MISE_SOURCE" ]; then
    echo "错误：未找到 mise 配置文件：$MISE_SOURCE" >&2
    exit 1
fi

# ==============================================================================
# 配置开发工具链
# ==============================================================================
# 1. 安装 mise
progress "开发环境 / mise"

# 1.1 安装依赖
sudo pacman -Syu --needed --noconfirm ca-certificates curl git unzip

# 1.2 安装软件包
sudo pacman -S --needed --noconfirm mise

# 2. 部署 mise 配置
progress "开发环境 / mise config.toml"
mkdir -p "$(dirname "$MISE_TARGET")"
if [ -d "$MISE_TARGET" ] && [ ! -L "$MISE_TARGET" ]; then
    echo "错误：$MISE_TARGET 是目录，无法写入 mise 配置。" >&2
    exit 1
fi
if [ -f "$MISE_TARGET" ] && cmp -s "$MISE_SOURCE" "$MISE_TARGET"; then
    echo "mise 配置已是最新，跳过复制。"
else
    if [ -e "$MISE_TARGET" ] || [ -L "$MISE_TARGET" ]; then
        MISE_BACKUP_DIR="$HOME/.config-backup/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$MISE_BACKUP_DIR"
        cp -a "$MISE_TARGET" "$MISE_BACKUP_DIR/mise-config.toml"
        rm -f "$MISE_TARGET"
        echo "已备份原 mise 配置：$MISE_BACKUP_DIR/mise-config.toml"
    fi
    cp "$MISE_SOURCE" "$MISE_TARGET"
fi

# 3. 安装开发工具
progress "开发环境 / Python 3.14、uv、Node.js 24、Temurin JDK 25、Maven 3.9"
mise --cd "$HOME" --yes install

# 4. 初始化 Shell 环境
progress "开发环境 / mise ZSH"
if ! grep -Fxq 'eval "$(mise activate zsh)"' "$HOME/.zshrc" 2>/dev/null; then
    printf '\n# 初始化 mise 开发工具环境\neval "$(mise activate zsh)"\n' >> "$HOME/.zshrc"
fi

# 5. 启用工具自动更新
progress "开发环境 / 每 24 小时检查工具更新"
mise --cd "$HOME" --yes bootstrap services apply

# 6. 部署 Maven 配置
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

# ==============================================================================
# 配置 AI 工具
# ==============================================================================
# 1. 安装 Claude
progress "AI 工具 / Claude"
mise --cd "$HOME" exec -- npm install -g @anthropic-ai/claude-code@latest

# 2. 安装 Codex
progress "AI 工具 / Codex"
mise --cd "$HOME" exec -- npm install -g @openai/codex

# 3. 建立配置链接
progress "AI 配置 / 建立 AGENTS.md 链接"

mkdir -p "$HOME/.claude" "$HOME/.codex"

link() {
    if [ -d "$2" ] && [ ! -L "$2" ]; then
        echo "错误: $2 是目录，拒绝删除；请先手动处理后重试。" >&2
        exit 1
    fi
    rm -f "$2"
    ln -s "$1" "$2"
}

link "$HOME/.agents/AGENTS.md" "$HOME/.claude/CLAUDE.md"
link "$HOME/.agents/AGENTS.md" "$HOME/.codex/AGENTS.md"

# 3.1 验证配置链接
for p in "$HOME/.claude/CLAUDE.md" "$HOME/.codex/AGENTS.md"; do
    [ -L "$p" ] && echo "OK   $p -> $(readlink "$p")" || { echo "失败 $p" >&2; exit 1; }
done

# ==============================================================================
# 完成配置
# ==============================================================================
printf '\n开发环境配置完成。请注销后重新登录，使新安装工具的环境变量完全生效。\n'
