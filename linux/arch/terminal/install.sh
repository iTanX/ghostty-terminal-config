#!/bin/bash

# ==============================================================================
# 准备配置
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_DIR="$HOME/.config-backup/$(date +%Y%m%d_%H%M%S)"
TMP_DIR="$(mktemp -d)"
GHOSTTY_SOURCE="$SCRIPT_DIR/ghostty/config"
GHOSTTY_TARGET="$CONFIG_DIR/ghostty/config"
STARSHIP_SOURCE="$SCRIPT_DIR/starship/starship.toml"
STARSHIP_TARGET="$CONFIG_DIR/starship.toml"
FONT_SETUP_SCRIPT="$SCRIPT_DIR/configure-fonts.sh"
FONTCONFIG_SOURCE="$SCRIPT_DIR/fontconfig/99-maple-mono-nf-cn-ghostty.conf"
ZSH_SOURCE="$SCRIPT_DIR/zsh/.zshrc"
ZSH_MARKER_START="# >>> linux-ghostty-terminal-config >>>"
ZSH_MARKER_END="# <<< linux-ghostty-terminal-config <<<"
MAPLE_VERSION="v7.9"
MAPLE_RELEASE_URL="https://github.com/subframe7536/maple-font/releases/download/$MAPLE_VERSION"
MAPLE_ZIP_NAME="MapleMono-NF-CN.zip"
MAPLE_SHA_NAME="MapleMono-NF-CN.sha256"
FONT_DIR="$HOME/.local/share/fonts/maple-mono-nf-cn"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# 1. 检查运行环境
if [ "$(id -u)" -eq 0 ]; then
  echo "错误: 请使用普通用户运行本脚本，不要使用 root。"
  exit 1
fi

if [ ! -r /etc/os-release ]; then
  echo "错误: 无法识别当前操作系统。"
  exit 1
fi

. /etc/os-release
if [ "${ID:-}" != "arch" ]; then
  echo "错误: 本脚本仅支持 Arch Linux。"
  echo "当前系统: ${PRETTY_NAME:-未知}"
  exit 1
fi

case "$(uname -m)" in
  x86_64) ;;
  *)
    echo "错误: 本脚本仅支持 x86_64 架构。" >&2
    exit 1
    ;;
esac

if ! command -v sudo &> /dev/null; then
  echo "错误: 未检测到 sudo，请先为当前用户配置 sudo 权限。"
  exit 1
fi

if [ ! -f "$GHOSTTY_SOURCE" ] || [ ! -f "$STARSHIP_SOURCE" ] || [ ! -f "$ZSH_SOURCE" ]; then
  echo "错误: 未找到配置文件，请确认以下文件存在于 $SCRIPT_DIR 下: ghostty/config、starship/starship.toml、zsh/.zshrc"
  exit 1
fi
if [ ! -f "$FONT_SETUP_SCRIPT" ] || [ ! -f "$FONTCONFIG_SOURCE" ]; then
  echo "错误: 未找到 configure-fonts.sh 或 Fontconfig 规则，请保留完整的 terminal 目录。"
  exit 1
fi

# ==============================================================================
# 显示配置步骤
# ==============================================================================
echo ""
echo "======================================"
echo " 终端环境安装及更新"
echo "======================================"
echo ""
echo "本脚本将安装终端工具、字体和配置，设置默认终端字体与 Shell。"
echo "已有 Ghostty 和 Starship 配置将备份到: $BACKUP_DIR"
echo ""

# ==============================================================================
# 安装终端工具
# ==============================================================================
# 1. 安装依赖
echo "==> 安装基础依赖..."
sudo pacman -Syu --needed --noconfirm ca-certificates curl git file fontconfig unzip

# 2. 安装终端工具与插件
echo "==> 安装终端工具和 zsh 插件..."
sudo pacman -S --needed --noconfirm \
  zsh \
  zoxide \
  eza \
  bat \
  zsh-autosuggestions \
  zsh-syntax-highlighting \
  starship \
  fzf \
  ghostty \
  yazi \
  zsh-completions

# 2.1 隐藏 Yazi 应用图标
echo "==> 隐藏 Yazi 应用图标..."
YAZI_DESKTOP_SOURCE="/usr/share/applications/yazi.desktop"
YAZI_DESKTOP_TARGET="${XDG_DATA_HOME:-$HOME/.local/share}/applications/yazi.desktop"
if [ -f "$YAZI_DESKTOP_SOURCE" ]; then
  mkdir -p "$(dirname "$YAZI_DESKTOP_TARGET")"
  cp "$YAZI_DESKTOP_SOURCE" "$YAZI_DESKTOP_TARGET"
  sed -i '/^NoDisplay=/d; /^\[Desktop Entry\]$/a NoDisplay=true' "$YAZI_DESKTOP_TARGET"
fi

# ==============================================================================
# 配置字体
# ==============================================================================
# 1. 安装 Maple Mono NF CN
echo "==> 安装 Maple Mono NF CN 字体..."
if [ "$(cat "$FONT_DIR/.version" 2>/dev/null)" = "$MAPLE_VERSION" ] &&
   [ -f "$FONT_DIR/MapleMono-NF-CN-Regular.ttf" ]; then
  echo "    Maple Mono NF CN $MAPLE_VERSION 已安装，跳过下载。"
else
  curl -fsSL "$MAPLE_RELEASE_URL/$MAPLE_ZIP_NAME" -o "$TMP_DIR/$MAPLE_ZIP_NAME"
  curl -fsSL "$MAPLE_RELEASE_URL/$MAPLE_SHA_NAME" -o "$TMP_DIR/$MAPLE_SHA_NAME"

  EXPECTED_SHA="$(tr -d '[:space:]' < "$TMP_DIR/$MAPLE_SHA_NAME")"
  ACTUAL_SHA="$(sha256sum "$TMP_DIR/$MAPLE_ZIP_NAME" | cut -d' ' -f1)"
  if [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
    echo "错误: 字体包校验失败，已中止安装。"
    echo "  期望: $EXPECTED_SHA"
    echo "  实际: $ACTUAL_SHA"
    exit 1
  fi

  rm -rf "$TMP_DIR/maple"
  mkdir -p "$FONT_DIR" "$TMP_DIR/maple"
  unzip -oq "$TMP_DIR/$MAPLE_ZIP_NAME" -d "$TMP_DIR/maple"
  if [ -z "$(find "$TMP_DIR/maple" -type f -name 'MapleMono-NF-CN-Regular.ttf' -print -quit)" ]; then
    echo "错误: 字体包中未找到 MapleMono-NF-CN-Regular.ttf。"
    exit 1
  fi
  rm -f "$FONT_DIR"/*.ttf
  find "$TMP_DIR/maple" -type f -name '*.ttf' -exec cp -f {} "$FONT_DIR/" \;

  printf '%s\n' "$MAPLE_VERSION" > "$FONT_DIR/.version"
  echo "    ✓ $FONT_DIR ($MAPLE_VERSION)"
fi

# 2. 配置字体匹配
bash "$FONT_SETUP_SCRIPT" "$BACKUP_DIR"

# ==============================================================================
# 部署终端配置
# ==============================================================================
# 1. 创建配置目录
echo "==> 安装配置文件..."
mkdir -p "$CONFIG_DIR"

# 2. 部署 Ghostty 配置
if [ -d "$GHOSTTY_TARGET" ] && [ ! -L "$GHOSTTY_TARGET" ]; then
  echo "错误: $GHOSTTY_TARGET 是目录，无法安装 Ghostty 配置。"
  exit 1
fi

if [ -f "$GHOSTTY_TARGET" ] && cmp -s "$GHOSTTY_SOURCE" "$GHOSTTY_TARGET"; then
  echo "    Ghostty 配置已是最新，跳过。"
else
  if [ -e "$GHOSTTY_TARGET" ] || [ -L "$GHOSTTY_TARGET" ]; then
    mkdir -p "$BACKUP_DIR"
    cp -a "$GHOSTTY_TARGET" "$BACKUP_DIR/ghostty-config"
    echo "    备份 $GHOSTTY_TARGET"
    rm -f "$GHOSTTY_TARGET"
  fi
  mkdir -p "$(dirname "$GHOSTTY_TARGET")"
  cp "$GHOSTTY_SOURCE" "$GHOSTTY_TARGET"
  echo "    ✓ $GHOSTTY_TARGET"
fi

# 3. 部署 Starship 配置
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

# 4. 部署 zsh 配置
if grep -Fq "$ZSH_MARKER_START" "$HOME/.zshrc" 2>/dev/null; then
  echo "    .zshrc 中已存在 Linux 配置，跳过。"
else
  {
    echo ""
    echo "$ZSH_MARKER_START"
    echo "# 部署终端 Shell 配置"
    echo "# 删除方法: 移除从 >>> 到 <<< 之间的所有内容"
    cat "$ZSH_SOURCE"
    echo "$ZSH_MARKER_END"
  } >> "$HOME/.zshrc"
  echo "    ✓ $HOME/.zshrc (已追加到尾部)"
fi

# ==============================================================================
# 设置默认 Shell
# ==============================================================================
# 1. 切换默认 Shell
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
# 完成配置
# ==============================================================================
echo ""
echo "======================================"
echo " 安装完成！"
echo "======================================"
echo ""
echo "请重新打开终端（或注销后重新登录）生效。"
echo "默认字体: Ghostty = Maple Mono NF CN Regular，10 号。"
echo "若 Ghostty 仍在运行，请完全退出旧进程后重新打开。"
echo ""
if [ -d "$BACKUP_DIR" ]; then
  echo "恢复旧配置:"
  if [ -e "$BACKUP_DIR/ghostty-config" ] || [ -L "$BACKUP_DIR/ghostty-config" ]; then
    echo "  rm -f $GHOSTTY_TARGET"
    echo "  cp -a $BACKUP_DIR/ghostty-config $GHOSTTY_TARGET"
  fi
  if [ -e "$BACKUP_DIR/starship.toml" ] || [ -L "$BACKUP_DIR/starship.toml" ]; then
    echo "  rm -f $STARSHIP_TARGET"
    echo "  cp -a $BACKUP_DIR/starship.toml $STARSHIP_TARGET"
  fi
  echo ""
fi
echo "卸载 zsh 配置:"
echo "  删除 $HOME/.zshrc 中 '>>> linux-ghostty-terminal-config >>>' 到 '<<< linux-ghostty-terminal-config <<<' 之间的所有内容"
echo ""
