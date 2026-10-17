#!/usr/bin/env bash
# WSL 开发环境：对应《WSL 一键配置.md》中“AI 开发环境”及之后的章节。
# 请先完成 01-basic-config.sh。首次可执行：chmod +x 02-development-environment.sh。
# 随后以普通用户运行 ./02-development-environment.sh；不要使用 sudo 执行整个脚本。

set -euo pipefail

# 输出当前步骤，便于在终端中定位执行进度。
progress() {
    printf '\n==> %s\n' "$1"
}

# 避免将 npm、uv、SDKMAN 和用户目录配置写入 root 的 HOME。
if [ "$(id -u)" -eq 0 ]; then
    echo "错误：请使用普通 WSL 用户运行本脚本，不要使用 sudo。" >&2
    exit 1
fi

# 仅 APT 安装需要 sudo；其余工具均安装到当前用户目录。
if ! command -v sudo >/dev/null 2>&1; then
    echo "错误：未找到 sudo，请先为当前用户配置 sudo 权限。" >&2
    exit 1
fi

# 脚本所在目录用于定位随文档提供的 Maven settings.xml。
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# AI 开发环境

## Git
# 一般内置 Git，无需另外安装。

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

# 将随文档提供的 settings.xml 写入 Maven 的用户级配置目录。
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

# 互通 Windows

# 将 WSL 侧配置链接到 Windows 用户目录的 .agents。
# 依赖：WSL 与 Windows 互操作（wslpath + cmd.exe）。
progress "互通 Windows / 链接 AI 配置"

# ---------- 1. 动态解析 Windows 用户目录 ----------
# 优先用 WSL 注入的 USERPROFILE，回退到 cmd.exe 询问。
if [ -n "${USERPROFILE:-}" ]; then
    WINHOME="$(wslpath -u "$USERPROFILE")"
else
    WINHOME="$(wslpath -u "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r\n')")"
fi
AGENTS="$WINHOME/.agents"

# ---------- 2. 前置校验 ----------
[ -n "$WINHOME" ]          || { echo "错误: 无法解析 Windows 用户目录" >&2; exit 1; }
[ -d "$AGENTS" ]           || { echo "错误: $AGENTS 不存在" >&2; exit 1; }
[ -f "$AGENTS/AGENTS.md" ] || { echo "错误: $AGENTS/AGENTS.md 不存在" >&2; exit 1; }
[ -d "$AGENTS/skills" ]    || { echo "错误: $AGENTS/skills 不存在" >&2; exit 1; }

mkdir -p "$HOME/.claude" "$HOME/.codex"

# ---------- 3. 建链接（仅替换文件或软链接，可重复执行）----------
# 同名真实目录不会删除，避免覆盖已有用户配置。
link() {
    if [ -d "$2" ] && [ ! -L "$2" ]; then
        echo "错误: $2 是目录，拒绝删除；请先手动处理后重试。" >&2
        exit 1
    fi
    rm -f "$2"
    ln -s "$1" "$2"
}

link "$AGENTS"           "$HOME/.agents"             # 1. ~/.agents           -> .agents/
link "$AGENTS/AGENTS.md" "$HOME/.claude/CLAUDE.md"   # 2. ~/.claude/CLAUDE.md -> .agents/AGENTS.md
link "$AGENTS/skills"    "$HOME/.claude/skills"      # 3. ~/.claude/skills    -> .agents/skills/
link "$AGENTS/AGENTS.md" "$HOME/.codex/AGENTS.md"    # 4. ~/.codex/AGENTS.md  -> .agents/AGENTS.md

# ---------- 4. 验证 ----------
for p in "$HOME/.agents" "$HOME/.claude/CLAUDE.md" "$HOME/.claude/skills" "$HOME/.codex/AGENTS.md"; do
    [ -e "$p" ] && echo "OK   $p -> $(readlink "$p")" || { echo "失败 $p" >&2; exit 1; }
done

printf '\n开发环境配置完成。请重新打开 WSL 终端，使新安装工具的环境变量完全生效。\n'
