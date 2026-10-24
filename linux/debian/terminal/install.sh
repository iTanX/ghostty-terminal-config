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
ZSH_COMPLETIONS_DIR="$HOME/.local/share/zsh-completions"
ZSH_MARKER_START="# >>> linux-ghostty-terminal-config >>>"
ZSH_MARKER_END="# <<< linux-ghostty-terminal-config <<<"
GHOSTTY_KEY_URL="https://deb-free.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc"
GHOSTTY_KEYRING="/etc/apt/keyrings/deb-free.griffo.io.gpg"
GHOSTTY_SOURCE_LIST="/etc/apt/sources.list.d/deb-free.griffo.io.list"
GHOSTTY_APT_SOURCE="deb [signed-by=$GHOSTTY_KEYRING] https://deb-free.griffo.io/apt trixie main"
YAZI_KEY_URL="https://yazi-rs.github.io/builds/yazi-keyring.gpg"
YAZI_KEYRING="/usr/share/keyrings/yazi-keyring.gpg"
YAZI_SOURCE_LIST="/etc/apt/sources.list.d/yazi.list"
YAZI_APT_SOURCE="deb [signed-by=$YAZI_KEYRING] https://yazi-rs.github.io/builds/ stable main"
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
if [ "${ID:-}" != "debian" ] || [ "${VERSION_ID:-}" != "13" ] || [ "${VERSION_CODENAME:-}" != "trixie" ]; then
  echo "错误: 本脚本仅支持 Debian 13（Trixie）GNOME 桌面版。"
  echo "当前系统: ${PRETTY_NAME:-未知}"
  exit 1
fi

case "$(dpkg --print-architecture)" in
  amd64|arm64) ;;
  *)
    echo "错误: Ghostty 和 Yazi 的安装配置仅支持 amd64、arm64 架构。" >&2
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
echo "==> 安装 APT 基础依赖..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg git file fontconfig libglib2.0-bin unzip

# 2. 安装终端工具与插件
echo "==> 安装终端工具和 zsh 插件..."
sudo apt-get install -y \
  zsh \
  zoxide \
  eza \
  bat \
  zsh-autosuggestions \
  zsh-syntax-highlighting \
  starship \
  fzf

# 2.1 安装 Ghostty
echo "==> 配置 Ghostty 软件源..."
curl -fsSL "$GHOSTTY_KEY_URL" -o "$TMP_DIR/ghostty.asc"
gpg --batch --dearmor --output "$TMP_DIR/ghostty.gpg" "$TMP_DIR/ghostty.asc"
sudo install -d -m 0755 /etc/apt/keyrings
if ! sudo cmp -s "$TMP_DIR/ghostty.gpg" "$GHOSTTY_KEYRING"; then
  sudo install -m 0644 "$TMP_DIR/ghostty.gpg" "$GHOSTTY_KEYRING"
  echo "    ✓ $GHOSTTY_KEYRING"
else
  echo "    Ghostty 密钥已是最新，跳过。"
fi

printf '%s\n' "$GHOSTTY_APT_SOURCE" > "$TMP_DIR/ghostty.list"
if [ -e "$GHOSTTY_SOURCE_LIST" ]; then
  if ! sudo cmp -s "$TMP_DIR/ghostty.list" "$GHOSTTY_SOURCE_LIST"; then
    echo "错误: $GHOSTTY_SOURCE_LIST 已存在且内容不同。"
    echo "请先检查该文件，确认无用后删除，再重新运行本脚本。"
    exit 1
  fi
  echo "    Ghostty 软件源已存在，跳过。"
else
  sudo install -m 0644 "$TMP_DIR/ghostty.list" "$GHOSTTY_SOURCE_LIST"
  echo "    ✓ $GHOSTTY_SOURCE_LIST"
fi
sudo apt-get update
sudo apt-get install -y ghostty

# 3. 安装 Yazi

# 3.1 配置软件源
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

# 3.2 安装软件包
sudo apt-get update
sudo apt-get install -y yazi

# 4. 安装 zsh-completions
echo "==> 安装或更新 zsh-completions..."
if [ -d "$ZSH_COMPLETIONS_DIR/.git" ] && [ -d "$ZSH_COMPLETIONS_DIR/src" ]; then
  git -C "$ZSH_COMPLETIONS_DIR" pull --ff-only
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
# 设置默认终端字体
# ==============================================================================
# 1. 设置字体与字号
echo "==> 设置 GNOME Terminal 默认配置的字体..."
if ! gsettings list-schemas | grep -Fx 'org.gnome.Terminal.ProfilesList' >/dev/null; then
  echo "错误: 未检测到 GNOME Terminal 配置；请在 Debian GNOME 的默认终端中运行。" >&2
  exit 1
fi
TERMINAL_PROFILE="$(gsettings get org.gnome.Terminal.ProfilesList default)"
TERMINAL_PROFILE="${TERMINAL_PROFILE#\'}"
TERMINAL_PROFILE="${TERMINAL_PROFILE%\'}"
if [[ ! "$TERMINAL_PROFILE" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]]; then
  echo "错误: GNOME Terminal 默认配置 ID 无效，请先打开终端创建默认配置。" >&2
  exit 1
fi
TERMINAL_SETTINGS="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$TERMINAL_PROFILE/"
TERMINAL_FONT="Maple Mono NF CN Regular 10"
for key in font use-system-font; do
  if [ "$(gsettings writable "$TERMINAL_SETTINGS" "$key")" != true ]; then
    echo "错误: GNOME Terminal 的 $key 设置不可写，请检查桌面策略。" >&2
    exit 1
  fi
done
if [ "$(gsettings get "$TERMINAL_SETTINGS" font)" = "'$TERMINAL_FONT'" ] &&
   [ "$(gsettings get "$TERMINAL_SETTINGS" use-system-font)" = false ]; then
  echo "    GNOME Terminal 字体已是 $TERMINAL_FONT，跳过。"
else
  gsettings set "$TERMINAL_SETTINGS" font "$TERMINAL_FONT"
  gsettings set "$TERMINAL_SETTINGS" use-system-font false
  if [ "$(gsettings get "$TERMINAL_SETTINGS" font)" != "'$TERMINAL_FONT'" ] ||
     [ "$(gsettings get "$TERMINAL_SETTINGS" use-system-font)" != false ]; then
    echo "错误: GNOME Terminal 字体设置未保存，请在当前用户的桌面会话中运行。" >&2
    exit 1
  fi
  echo "    ✓ GNOME Terminal = $TERMINAL_FONT"
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
echo "默认字体: Ghostty、GNOME Terminal = Maple Mono NF CN Regular，10 号。"
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
