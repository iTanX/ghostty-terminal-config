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

# ==============================================================================
# 配置开发工具链
# ==============================================================================
# 1. 安装 Python 命令入口
progress "AI 开发环境 / python-is-python3"
sudo apt install -y python-is-python3

# 2. 安装 uv
progress "AI 开发环境 / uv"
curl -LsSf https://astral.sh/uv/install.sh | sh

export PATH="$HOME/.local/bin:$PATH"

# 3. 安装 Node.js
progress "AI 开发环境 / Node.js"

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh | PROFILE="$HOME/.zshrc" bash

. "$HOME/.nvm/nvm.sh"

nvm install 24

node -v

npm -v

# 4. 安装 SDKMAN
progress "Java 开发环境 / SDKMAN"

# 4.1 安装依赖
sudo apt install -y zip unzip

# 4.2 安装并初始化 SDKMAN
curl -s "https://get.sdkman.io" | zsh

set +u
. "$HOME/.sdkman/bin/sdkman-init.sh"

SDKMAN_CONFIG="$HOME/.sdkman/etc/config"
if grep -q '^sdkman_auto_answer=' "$SDKMAN_CONFIG"; then
    sed -i 's/^sdkman_auto_answer=.*/sdkman_auto_answer=true/' "$SDKMAN_CONFIG"
else
    printf '\nsdkman_auto_answer=true\n' >> "$SDKMAN_CONFIG"
fi

# 5. 安装 JDK
progress "Java 开发环境 / JDK 25"
sdk install java 25-tem
sdk default java 25-tem

# 6. 安装 Maven
progress "Java 开发环境 / Maven 3.9.16"
sdk install maven 3.9.16
sdk default maven 3.9.16
set -u

# 6.1 部署 Maven 配置
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
npm install -g @anthropic-ai/claude-code@latest

# 2. 安装 Codex
progress "AI 工具 / Codex"
npm install -g @openai/codex

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
