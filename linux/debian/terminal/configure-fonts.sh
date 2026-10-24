#!/usr/bin/env bash
# ==============================================================================
# 准备配置
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP_DIR="${1:-$HOME/.config-backup/$(date +%Y%m%d_%H%M%S)}"
FONT_DIR="$HOME/.local/share/fonts/maple-mono-nf-cn"
FONTCONFIG_SOURCE="$SCRIPT_DIR/fontconfig/99-maple-mono-nf-cn-ghostty.conf"
FONTCONFIG_TARGET="$CONFIG_DIR/fontconfig/conf.d/99-maple-mono-nf-cn-ghostty.conf"

# 1. 检查运行环境
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

if [ ! -f "$FONT_DIR/MapleMono-NF-CN-Regular.ttf" ]; then
  echo "错误: 未找到 Maple Mono NF CN 字体，请先运行 install.sh。" >&2
  exit 1
fi

# ==============================================================================
# 配置字体匹配
# ==============================================================================
# 1. 部署字体规则
echo "==> 配置 Maple Mono NF CN 字体匹配..."
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
  fi
  mkdir -p "$(dirname "$FONTCONFIG_TARGET")"
  cp "$FONTCONFIG_SOURCE" "$FONTCONFIG_TARGET"
  echo "    ✓ $FONTCONFIG_TARGET"
fi

# 2. 刷新字体缓存
fc-cache -f "$FONT_DIR" >/dev/null

# 3. 验证字体匹配
for lang in zh-cn en; do
  FONT_MATCH="$(fc-match -f '%{family}' "Maple Mono NF CN:spacing=100:lang=$lang")"
  if [ "$FONT_MATCH" != "Maple Mono NF CN" ]; then
    echo "错误: $lang 环境字体匹配为 $FONT_MATCH，预期为 Maple Mono NF CN。" >&2
    exit 1
  fi
done
echo "    ✓ 中英文环境均匹配 Maple Mono NF CN"
