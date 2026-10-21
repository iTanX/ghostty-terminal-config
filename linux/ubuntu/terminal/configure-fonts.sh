#!/usr/bin/env bash
# 安装 Maple CN 的 Fontconfig 兼容规则。
# install.sh 安装字体后会自动调用；已有字体时也可单独运行：bash configure-fonts.sh
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

if [ ! -f "$FONT_DIR/MapleMono-NF-CN-Regular.ttf" ]; then
  echo "错误: 未找到 Maple Mono NF CN 字体，请先运行 install.sh。" >&2
  exit 1
fi

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

# 无论字体版本是否变化都刷新缓存，兼容以前安装过扫描规则的机器。
fc-cache -f "$FONT_DIR" >/dev/null

# 显式测试中文语言环境；英文环境下正确并不能证明 Ubuntu 中文环境正确。
for lang in zh-cn en; do
  FONT_MATCH="$(fc-match -f '%{family}' "Maple Mono NF CN:spacing=100:lang=$lang")"
  if [ "$FONT_MATCH" != "Maple Mono NF CN" ]; then
    echo "错误: $lang 环境字体匹配为 $FONT_MATCH，预期为 Maple Mono NF CN。" >&2
    exit 1
  fi
done
echo "    ✓ 中英文环境均匹配 Maple Mono NF CN"
