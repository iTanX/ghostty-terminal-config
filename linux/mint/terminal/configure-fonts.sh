#!/usr/bin/env bash
# 修复中文环境下 Ghostty 将 Maple Mono NF CN 匹配为 Noto 的问题。
# install.sh 安装字体后自动调用；已有安装可单独运行，不更新软件包。
# 可选参数：备份目录。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_DIR="${1:-$HOME/.config-backup/$(date +%Y%m%d_%H%M%S)}"
FONT_DIR="$HOME/.local/share/fonts/maple-mono-nf-cn"
FONTCONFIG_SOURCE="$SCRIPT_DIR/fontconfig/99-maple-mono-nf-cn-ghostty.conf"
FONTCONFIG_TARGET="$CONFIG_DIR/fontconfig/conf.d/99-maple-mono-nf-cn-ghostty.conf"

if [ "$(id -u)" -eq 0 ]; then
  echo "错误: 请使用普通用户运行本脚本，不要使用 sudo。" >&2
  exit 1
fi
for cmd in fc-cache fc-match; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "错误: 缺少 $cmd，请先运行 install.sh 安装依赖。" >&2
    exit 1
  fi
done
if [ ! -f "$FONTCONFIG_SOURCE" ] || [ ! -f "$FONT_DIR/MapleMono-NF-CN-Regular.ttf" ]; then
  echo "错误: 缺少 Fontconfig 规则或 Maple Mono NF CN 字体，请先运行 install.sh。" >&2
  exit 1
fi

echo "==> 修复 Ghostty 的 Maple Mono NF CN 字体匹配..."
if [ -d "$FONTCONFIG_TARGET" ] && [ ! -L "$FONTCONFIG_TARGET" ]; then
  echo "错误: $FONTCONFIG_TARGET 是目录，无法安装字体规则。" >&2
  exit 1
fi
if [ -f "$FONTCONFIG_TARGET" ] && cmp -s "$FONTCONFIG_SOURCE" "$FONTCONFIG_TARGET"; then
  echo "    Fontconfig 规则已是最新，跳过复制。"
else
  if [ -e "$FONTCONFIG_TARGET" ] || [ -L "$FONTCONFIG_TARGET" ]; then
    mkdir -p "$BACKUP_DIR"
    cp -a "$FONTCONFIG_TARGET" "$BACKUP_DIR/maple-mono-nf-cn-ghostty.conf"
    rm -f "$FONTCONFIG_TARGET"
    echo "    旧规则已备份到 $BACKUP_DIR/maple-mono-nf-cn-ghostty.conf"
  fi
  mkdir -p "$(dirname "$FONTCONFIG_TARGET")"
  cp "$FONTCONFIG_SOURCE" "$FONTCONFIG_TARGET"
  echo "    ✓ $FONTCONFIG_TARGET"
fi
fc-cache -f "$FONT_DIR" >/dev/null

# 显式指定语言，避免在 Codex 等 C.UTF-8 环境中漏掉中文桌面的错误匹配。
for lang in zh-cn en; do
  for style in Regular Bold; do
    FONT_MATCH="$(fc-match -f '%{family}' "Maple Mono NF CN:spacing=100:lang=$lang:style=$style")"
    if [ "$FONT_MATCH" != "Maple Mono NF CN" ]; then
      echo "错误: $lang / $style 匹配为 $FONT_MATCH，预期为 Maple Mono NF CN。" >&2
      exit 1
    fi
  done
done
echo "    ✓ 中文和英文环境的常规、粗体均匹配 Maple Mono NF CN"
echo "请完全退出 Ghostty 的旧进程，再重新打开以加载字体规则。"
