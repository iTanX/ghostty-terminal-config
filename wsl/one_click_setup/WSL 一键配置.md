# 安装 WSL

安装命令：

```powershell
wsl --install -d Ubuntu-26.04 --name Agul --location D:\5-Virtual\WSL\Agul
```

# 基础配置

## ZSH

在本目录（`wsl/one_click_setup`）执行：

```sh
bash 01-basic-config.sh
```

> [!IMPORTANT]
>
> ZSH 配置完成后需要重启 WSL 实例使其生效！！！

# AI 开发环境

本章及「AI 工具」「链接 Windows」章节的全部步骤已整合到同目录的 `02-development-environment.sh`，可直接运行：

```sh
bash 02-development-environment.sh
```

以下为手动步骤，供参考。

## Git

一般内置 Git，无需另外安装。

## Python

一般内置 Python，无需另外安装。这里需要安装一些辅助工具。

### python-is-python3

安装 ​`python-is-python3`​ 使得 ​`python`​ 命令指向 ​`python3`：

```sh
sudo apt install -y python-is-python3
```

### uv

安装 Python 项目管理工具 `uv`：

```sh
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Node.js

使用 `nvm` 安装 `Node.js`：

```sh
# Download and install nvm:
# 默认 Shell 已是 zsh，但当前会话的 $SHELL 可能仍是 bash，
# nvm 安装器按 $SHELL 决定写哪个配置文件，因此显式指定写入 .zshrc。
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh | PROFILE="$HOME/.zshrc" bash

# in lieu of restarting the shell
\. "$HOME/.nvm/nvm.sh"

# Download and install Node.js:
nvm install 24

# Verify the Node.js version:
node -v

# Verify npm version:
npm -v
```

# Java 开发环境

## SDKMAN

安装 Java SDK 管理工具 ​`SDKMAN`：

```sh
# SDKMAN 依赖 zip 与 unzip。
sudo apt install -y zip unzip

curl -s "https://get.sdkman.io" | zsh

# SDKMAN 安装器运行在子 shell 中；加载后才能在当前终端调用 sdk。
. "$HOME/.sdkman/bin/sdkman-init.sh"
```

## JDK

使用 ​`SDKMAN`​ 安装 ​`JDK25`：

```sh
sdk install java 25-tem
sdk default java 25-tem
```

## Maven

使用 ​`SDKMAN`​ 安装 ​`Maven`：

```sh
sdk install maven 3.9.16
sdk default maven 3.9.16
```

将 [settings.xml](assets/settings.xml) 写入 `~/.m2/settings.xml`。

# AI 工具

## Claude

`npm`​ 安装 ​`Claude`：

```sh
npm install -g @anthropic-ai/claude-code@latest
```

## Codex

`npm`​安装 ​`Codex`：

```sh
npm install -g @openai/codex
```

## CCSwitch

使用官方命令安装 ​`CCSwitch CLI`：

```sh
# 暂时注释，不安装（与 02-development-environment.sh 保持一致）
# curl -fsSL https://github.com/SaladDay/cc-switch-cli/releases/latest/download/install.sh | bash
```

## 链接 Windows

WSL 链接使用 Windows 已有 AI 配置（该步骤已包含在 `02-development-environment.sh` 中）：

```sh
#!/usr/bin/env bash
# 将 WSL 侧配置链接到 Windows 用户目录的 .agents
# 依赖：WSL 与 Windows 互操作（wslpath + cmd.exe）
set -euo pipefail

# ---------- 1. 动态解析 Windows 用户目录 ----------
# 优先用 WSL 注入的 USERPROFILE，回退到 cmd.exe 询问
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
```

‍
