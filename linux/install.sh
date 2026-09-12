#!/bin/bash

# ==============================================================================
# WSL Ubuntu Shell Config 一键安装脚本
# ==============================================================================
# 用法:
#   bash linux/install.sh
#
# 说明:
#   1. 启用 universe 并安装终端工具和 zsh 插件
#   2. 添加 Yazi 官方 APT 源并安装 Yazi
#   3. 备份已有 Starship 配置到 ~/.config-backup/YYYYMMDD_HHMMSS/
#   4. 安装 Starship 和 zsh 配置，并将默认 Shell 切换为 zsh
#
# 恢复备份:
#   rm -f ~/.config/starship.toml
#   cp -a ~/.config-backup/<时间戳>/starship.toml ~/.config/starship.toml
#
# 卸载 zsh 配置:
#   删除 ~/.zshrc 中 ">>> wsl-ubuntu-shell-config >>>" 到 "<<< wsl-ubuntu-shell-config <<<" 之间的内容
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.config-backup/$(date +%Y%m%d_%H%M%S)"
TMP_DIR="$(mktemp -d)"
STARSHIP_SOURCE="$SCRIPT_DIR/starship/starship.toml"
STARSHIP_TARGET="$HOME/.config/starship.toml"
ZSH_SOURCE="$SCRIPT_DIR/zsh/.zshrc"
ZSH_COMPLETIONS_DIR="$HOME/.local/share/zsh-completions"
ZSH_MARKER_START="# >>> wsl-ubuntu-shell-config >>>"
ZSH_MARKER_END="# <<< wsl-ubuntu-shell-config <<<"
YAZI_KEY_URL="https://yazi-rs.github.io/builds/yazi-keyring.gpg"
YAZI_KEYRING="/usr/share/keyrings/yazi-keyring.gpg"
YAZI_SOURCE_LIST="/etc/apt/sources.list.d/yazi.list"
YAZI_APT_SOURCE="deb [signed-by=$YAZI_KEYRING] https://yazi-rs.github.io/builds/ stable main"

# 清理下载 Yazi 密钥时使用的临时目录
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# ==============================================================================
# 检查环境
# ==============================================================================
if [ "$(id -u)" -eq 0 ]; then
  echo "错误: 请使用普通 WSL 用户运行本脚本，不要使用 root。"
  exit 1
fi

if [ ! -r /etc/os-release ]; then
  echo "错误: 无法识别当前操作系统。"
  exit 1
fi

# os-release 是 Ubuntu 提供的系统版本信息
. /etc/os-release
if [ "${ID:-}" != "ubuntu" ] || [ "${VERSION_ID:-}" != "26.04" ]; then
  echo "错误: 本脚本仅支持 WSL Ubuntu 26.04 LTS。"
  echo "当前系统: ${PRETTY_NAME:-未知}"
  exit 1
fi

if ! grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
  echo "警告: 未检测到 WSL 标识，将按普通 Ubuntu 26.04 环境继续。"
  echo ""
fi

if ! command -v sudo &> /dev/null; then
  echo "错误: 未检测到 sudo，请先为当前用户配置 sudo 权限。"
  exit 1
fi

if [ ! -f "$STARSHIP_SOURCE" ] || [ ! -f "$ZSH_SOURCE" ]; then
  echo "错误: 未找到 Linux 配置文件，请在仓库根目录运行 bash linux/install.sh。"
  exit 1
fi

# ==============================================================================
# 用户确认
# ==============================================================================
echo ""
echo "======================================"
echo " WSL Ubuntu Shell Config 安装脚本"
echo "======================================"
echo ""
echo "本脚本将执行以下操作:"
echo "  1. 启用 universe 并通过 APT 安装终端工具和 zsh 插件"
echo "  2. 添加 Yazi 官方签名 APT 源"
echo "  3. 备份并安装 Starship 和 zsh 配置"
echo "  4. 将当前用户的默认 Shell 切换为 zsh"
echo ""
echo "已有 Starship 配置将备份到: $BACKUP_DIR"
echo ""
read -r -p "是否继续？(y/n) " -n 1 REPLY < /dev/tty
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "已取消安装。"
  exit 0
fi
echo ""

# ==============================================================================
# 安装 APT 依赖
# ==============================================================================
echo "==> 安装 APT 基础依赖..."
sudo apt-get update
sudo apt-get install -y software-properties-common ca-certificates curl gnupg git

# add-apt-repository 可重复执行；--no-update 避免在添加 Yazi 源前重复刷新索引
sudo add-apt-repository -y --no-update universe

# ==============================================================================
# 添加 Yazi 官方 APT 源
# ==============================================================================
echo "==> 配置 Yazi 官方 APT 源..."
curl -fsSL "$YAZI_KEY_URL" -o "$TMP_DIR/yazi-keyring.gpg"
if ! sudo cmp -s "$TMP_DIR/yazi-keyring.gpg" "$YAZI_KEYRING"; then
  sudo install -m 0644 "$TMP_DIR/yazi-keyring.gpg" "$YAZI_KEYRING"
  echo "    ✓ $YAZI_KEYRING"
else
  echo "    Yazi 密钥已是最新，跳过。"
fi

printf '%s\n' "$YAZI_APT_SOURCE" > "$TMP_DIR/yazi.list"
if [ -e "$YAZI_SOURCE_LIST" ]; then
  if ! sudo cmp -s "$TMP_DIR/yazi.list" "$YAZI_SOURCE_LIST"; then
    echo "错误: $YAZI_SOURCE_LIST 已存在且内容不同。"
    echo "请先检查该文件，确认无用后删除，再重新运行本脚本。"
    exit 1
  fi
  echo "    Yazi 软件源已存在，跳过。"
else
  sudo install -m 0644 "$TMP_DIR/yazi.list" "$YAZI_SOURCE_LIST"
  echo "    ✓ $YAZI_SOURCE_LIST"
fi

echo "==> 安装终端工具和 zsh 插件..."
sudo apt-get update
sudo apt-get install -y \
  file \
  zsh \
  starship \
  fzf \
  zoxide \
  eza \
  bat \
  yazi \
  zsh-autosuggestions \
  zsh-syntax-highlighting

# ==============================================================================
# 安装 zsh-completions
# ==============================================================================
echo "==> 安装 zsh-completions..."
if [ -d "$ZSH_COMPLETIONS_DIR/.git" ] && [ -d "$ZSH_COMPLETIONS_DIR/src" ]; then
  echo "    zsh-completions 已安装，跳过。"
elif [ -e "$ZSH_COMPLETIONS_DIR" ] || [ -L "$ZSH_COMPLETIONS_DIR" ]; then
  echo "错误: $ZSH_COMPLETIONS_DIR 已存在，但不是有效的 zsh-completions 仓库。"
  echo "请先检查或移走该路径，再重新运行本脚本。"
  exit 1
else
  mkdir -p "$(dirname "$ZSH_COMPLETIONS_DIR")"
  git clone --depth 1 https://github.com/zsh-users/zsh-completions.git "$ZSH_COMPLETIONS_DIR"
  echo "    ✓ $ZSH_COMPLETIONS_DIR"
fi

# ==============================================================================
# 安装配置文件
# ==============================================================================
echo "==> 安装配置文件..."
mkdir -p "$HOME/.config"

if [ -d "$STARSHIP_TARGET" ] && [ ! -L "$STARSHIP_TARGET" ]; then
  echo "错误: $STARSHIP_TARGET 是目录，无法安装 Starship 配置。"
  exit 1
fi

if [ -f "$STARSHIP_TARGET" ] && cmp -s "$STARSHIP_SOURCE" "$STARSHIP_TARGET"; then
  echo "    Starship 配置已是最新，跳过。"
else
  if [ -e "$STARSHIP_TARGET" ] || [ -L "$STARSHIP_TARGET" ]; then
    mkdir -p "$BACKUP_DIR"
    cp -a "$STARSHIP_TARGET" "$BACKUP_DIR/starship.toml"
    echo "    备份 $STARSHIP_TARGET"
    rm -f "$STARSHIP_TARGET"
  fi
  cp "$STARSHIP_SOURCE" "$STARSHIP_TARGET"
  echo "    ✓ $STARSHIP_TARGET"
fi

# .zshrc 追加到用户已有配置尾部（不覆盖 marker 外的内容）
if grep -Fq "$ZSH_MARKER_START" "$HOME/.zshrc" 2>/dev/null; then
  echo "    .zshrc 中已存在 WSL Ubuntu 配置，跳过。"
else
  {
    echo ""
    echo "$ZSH_MARKER_START"
    echo "# 以下内容由 WSL Ubuntu shell 配置安装脚本自动追加"
    echo "# 删除方法: 移除从 >>> 到 <<< 之间的所有内容"
    cat "$ZSH_SOURCE"
    echo "$ZSH_MARKER_END"
  } >> "$HOME/.zshrc"
  echo "    ✓ $HOME/.zshrc (已追加到尾部)"
fi

# ==============================================================================
# 设置默认 Shell
# ==============================================================================
ZSH_PATH="$(command -v zsh)"
CURRENT_SHELL="$(getent passwd "$(id -un)" | cut -d: -f7)"
if [ "$CURRENT_SHELL" = "$ZSH_PATH" ]; then
  echo "    默认 Shell 已是 zsh，跳过。"
else
  echo "==> 将默认 Shell 切换为 zsh..."
  sudo chsh -s "$ZSH_PATH" "$(id -un)"
  echo "    ✓ $ZSH_PATH"
fi

# ==============================================================================
# 完成
# ==============================================================================
echo ""
echo "======================================"
echo " 安装完成！"
echo "======================================"
echo ""
echo "请关闭并重新打开 WSL 终端生效。"
echo ""
if [ -d "$BACKUP_DIR" ]; then
  echo "恢复旧 Starship 配置:"
  echo "  rm -f $STARSHIP_TARGET"
  echo "  cp -a $BACKUP_DIR/starship.toml $STARSHIP_TARGET"
  echo ""
fi
echo "卸载 zsh 配置:"
echo "  删除 $HOME/.zshrc 中 '>>> wsl-ubuntu-shell-config >>>' 到 '<<< wsl-ubuntu-shell-config <<<' 之间的所有内容"
echo ""
