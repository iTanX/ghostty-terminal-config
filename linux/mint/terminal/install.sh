#!/bin/bash

# ==============================================================================
# Linux Mint 22.3 Shell Config 一键安装及更新脚本
# ==============================================================================
# 用法（在脚本所在目录执行）:
#   bash install.sh
#
# 说明:
#   1. 添加 Ghostty 社区 PPA 和 Yazi 官方 APT 源，安装或更新终端工具与 zsh 插件
#   2. 通过上游安装器更新 Starship 和 fzf，通过 Git 更新 zsh-completions
#   3. 安装 Maple Mono NF CN 字体到 ~/.local/share/fonts/maple-mono-nf-cn
#   4. 备份已有 Ghostty 和 Starship 配置到 ~/.config-backup/YYYYMMDD_HHMMSS/
#   5. 安装 Ghostty、Starship 和 zsh 配置，设置系统终端字体，并将默认 Shell 切换为 zsh
#
# 恢复备份:
#   rm -f ~/.config/ghostty/config
#   cp -a ~/.config-backup/<时间戳>/ghostty-config ~/.config/ghostty/config
#   rm -f ~/.config/starship.toml
#   cp -a ~/.config-backup/<时间戳>/starship.toml ~/.config/starship.toml
#
# 卸载 zsh 配置:
#   删除 ~/.zshrc 中 ">>> linux-ghostty-terminal-config >>>" 到 "<<< linux-ghostty-terminal-config <<<" 之间的内容
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
YAZI_KEY_URL="https://yazi-rs.github.io/builds/yazi-keyring.gpg"
YAZI_KEYRING="/usr/share/keyrings/yazi-keyring.gpg"
YAZI_SOURCE_LIST="/etc/apt/sources.list.d/yazi.list"
YAZI_APT_SOURCE="deb [signed-by=$YAZI_KEYRING] https://yazi-rs.github.io/builds/ stable main"
# Maple Mono NF CN 没有 Ubuntu 软件包，只能从 GitHub Release 下载
# 固定版本，升级时只改这里
MAPLE_VERSION="v7.9"
MAPLE_RELEASE_URL="https://github.com/subframe7536/maple-font/releases/download/$MAPLE_VERSION"
MAPLE_ZIP_NAME="MapleMono-NF-CN.zip"
MAPLE_SHA_NAME="MapleMono-NF-CN.sha256"
# 用户级字体目录，无需 sudo，fontconfig 会自动扫描
FONT_DIR="$HOME/.local/share/fonts/maple-mono-nf-cn"

# 下载文件与 fzf 临时仓库均放在此目录，成功或失败退出时一并清理。
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# ==============================================================================
# 检查环境
# ==============================================================================
if [ "$(id -u)" -eq 0 ]; then
  echo "错误: 请使用普通用户运行本脚本，不要使用 root。"
  exit 1
fi

if [ ! -r /etc/os-release ]; then
  echo "错误: 无法识别当前操作系统。"
  exit 1
fi

# Mint 22.3 使用 Ubuntu Noble 基础源，不能用 Mint 的 Zena 代号添加 Ubuntu 源。
. /etc/os-release
if [ "${ID:-}" != "linuxmint" ] || [ "${VERSION_ID:-}" != "22.3" ] || [ "${UBUNTU_CODENAME:-}" != "noble" ]; then
  echo "错误: 本脚本仅支持 Linux Mint 22.3（Ubuntu Noble 基础）。"
  echo "当前系统: ${PRETTY_NAME:-未知}"
  exit 1
fi

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
# 用户确认
# ==============================================================================
echo ""
echo "======================================"
echo " Linux Mint 22.3 Shell Config 安装及更新脚本"
echo "======================================"
echo ""
echo "本脚本将执行以下操作:"
echo "  1. 添加 Ghostty 社区 PPA 和 Yazi 官方签名 APT 源，安装或更新 APT 软件包"
echo "  2. 更新 Starship、fzf 和 zsh-completions"
echo "  3. 从官方 GitHub Release 安装 Maple Mono NF CN 字体"
echo "  4. 备份并安装 Ghostty、Starship 和 zsh 配置"
echo "  5. 将系统默认终端 GNOME Terminal 的字体设为 Maple Mono NF CN"
echo "  6. 将当前用户的默认 Shell 切换为 zsh"
echo ""
echo "已有 Ghostty 和 Starship 配置将备份到: $BACKUP_DIR"
echo ""
# read -r -p "是否继续？(y/n) " -n 1 REPLY < /dev/tty
# echo ""
# if [[ ! $REPLY =~ ^[Yy]$ ]]; then
#   echo "已取消安装。"
#   exit 0
# fi
# echo ""

# ==============================================================================
# 安装 APT 依赖
# ==============================================================================
echo "==> 安装 APT 基础依赖..."
sudo apt-get update
sudo apt-get install -y mintsources ca-certificates curl gnupg git

# Mint 的命令自动使用 Ubuntu 基础代号，可重复执行；不支持 Ubuntu 的 --no-update 参数。
echo "==> 配置 Ghostty 社区 PPA..."
sudo add-apt-repository -y ppa:mkasberg/ghostty-ubuntu

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

echo "==> 安装或更新终端工具和 zsh 插件..."
sudo apt-get update
# install 同时将已安装的指定包升级到当前源中的候选版本。
sudo apt-get install -y \
  file \
  fontconfig \
  libglib2.0-bin \
  unzip \
  zsh \
  ghostty \
  zoxide \
  eza \
  bat \
  yazi \
  zsh-autosuggestions \
  zsh-syntax-highlighting

# ==============================================================================
# 安装或更新 Starship 和 fzf
# ==============================================================================
# 先在临时目录完成下载，再安装到 /usr/local/bin，失败时保留原有可执行文件。
echo "==> 安装或更新 Starship..."
mkdir -p "$TMP_DIR/starship-bin"
curl -fsSL https://starship.rs/install.sh -o "$TMP_DIR/starship-install.sh"
TMPDIR="$TMP_DIR" sh "$TMP_DIR/starship-install.sh" --yes --bin-dir "$TMP_DIR/starship-bin"
sudo install -Dm0755 "$TMP_DIR/starship-bin/starship" /usr/local/bin/starship

# --bin 只获取可执行文件，不生成 ~/.fzf 或重复修改 Shell 初始化配置。
echo "==> 安装或更新 fzf..."
git clone --depth 1 https://github.com/junegunn/fzf.git "$TMP_DIR/fzf"
bash "$TMP_DIR/fzf/install" --bin
# 上游安装器可能链接到已安装的同版本文件，避免向该文件自身复制。
if [ ! "$TMP_DIR/fzf/bin/fzf" -ef /usr/local/bin/fzf ]; then
  sudo install -Dm0755 "$TMP_DIR/fzf/bin/fzf" /usr/local/bin/fzf
fi

# ==============================================================================
# 安装或更新 zsh-completions
# ==============================================================================
echo "==> 安装或更新 zsh-completions..."
if [ -d "$ZSH_COMPLETIONS_DIR/.git" ] && [ -d "$ZSH_COMPLETIONS_DIR/src" ]; then
  # 仅允许快进更新，不覆盖本地修改或重写已有提交。
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
# 安装 Maple Mono NF CN 字体
# ==============================================================================
# 字体由脚本自行下载，因为 Maple Mono 没有 Ubuntu 软件包
echo "==> 安装 Maple Mono NF CN 字体..."
if [ "$(cat "$FONT_DIR/.version" 2>/dev/null)" = "$MAPLE_VERSION" ] &&
   [ -f "$FONT_DIR/MapleMono-NF-CN-Regular.ttf" ]; then
  echo "    Maple Mono NF CN $MAPLE_VERSION 已安装，跳过下载。"
else
  curl -fsSL "$MAPLE_RELEASE_URL/$MAPLE_ZIP_NAME" -o "$TMP_DIR/$MAPLE_ZIP_NAME"
  curl -fsSL "$MAPLE_RELEASE_URL/$MAPLE_SHA_NAME" -o "$TMP_DIR/$MAPLE_SHA_NAME"

  # 官方的 .sha256 文件里只有裸哈希、没有文件名，无法用 sha256sum -c 校验，改为手工比对
  EXPECTED_SHA="$(tr -d '[:space:]' < "$TMP_DIR/$MAPLE_SHA_NAME")"
  ACTUAL_SHA="$(sha256sum "$TMP_DIR/$MAPLE_ZIP_NAME" | cut -d' ' -f1)"
  if [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
    echo "错误: 字体包校验失败，已中止安装。"
    echo "  期望: $EXPECTED_SHA"
    echo "  实际: $ACTUAL_SHA"
    exit 1
  fi

  # 不假设 zip 内部的目录层级，按扩展名收集字体文件
  rm -rf "$TMP_DIR/maple"
  mkdir -p "$FONT_DIR" "$TMP_DIR/maple"
  unzip -oq "$TMP_DIR/$MAPLE_ZIP_NAME" -d "$TMP_DIR/maple"
  if [ -z "$(find "$TMP_DIR/maple" -type f -name 'MapleMono-NF-CN-Regular.ttf' -print -quit)" ]; then
    echo "错误: 字体包中未找到 MapleMono-NF-CN-Regular.ttf。"
    exit 1
  fi
  # 验证解压结果后再替换旧版本，避免残留已改名的字体文件。
  rm -f "$FONT_DIR"/*.ttf
  find "$TMP_DIR/maple" -type f -name '*.ttf' -exec cp -f {} "$FONT_DIR/" \;

  # 记录版本，下次运行时据此判断是否需要更新字体
  printf '%s\n' "$MAPLE_VERSION" > "$FONT_DIR/.version"
  echo "    ✓ $FONT_DIR ($MAPLE_VERSION)"
fi

# 安装字体匹配规则并刷新缓存，避免中文环境中被 Noto 替代。
bash "$FONT_SETUP_SCRIPT" "$BACKUP_DIR"

# ==============================================================================
# 安装配置文件
# ==============================================================================
echo "==> 安装配置文件..."
mkdir -p "$CONFIG_DIR"

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
  echo "    .zshrc 中已存在 Linux 配置，跳过。"
else
  {
    echo ""
    echo "$ZSH_MARKER_START"
    echo "# 以下内容由 Linux Mint shell 配置安装脚本自动追加"
    echo "# 删除方法: 移除从 >>> 到 <<< 之间的所有内容"
    cat "$ZSH_SOURCE"
    echo "$ZSH_MARKER_END"
  } >> "$HOME/.zshrc"
  echo "    ✓ $HOME/.zshrc (已追加到尾部)"
fi

# ==============================================================================
# 设置默认终端字体（Linux Mint Cinnamon 自带 GNOME Terminal）
# ==============================================================================
echo "==> 设置 GNOME Terminal 默认配置的字体..."
if ! gsettings list-schemas | grep -Fx 'org.gnome.Terminal.ProfilesList' >/dev/null; then
  echo "错误: 未检测到 GNOME Terminal 配置；此字体设置步骤适用于 Mint Cinnamon，请在桌面会话中运行。" >&2
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
