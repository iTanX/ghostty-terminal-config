#!/usr/bin/env bash
# ============================================================
# 一键更新雾凇拼音并重新部署
# 用法：bash update-rime-ice.sh
# ============================================================

set -euo pipefail

RIME_DIR="$HOME/.local/share/fcitx5/rime"

# ===== 前置检查：必须是 Git 仓库 =====
if [ ! -d "$RIME_DIR/.git" ]; then
  echo "错误：$RIME_DIR 不是 Git 仓库，无法更新。"
  echo "如果你当初是手动解压 zip 安装的，请重新下载覆盖，或改用它："
  echo "  rm -rf \"$RIME_DIR\""
  echo "  git clone --depth=1 https://github.com/iDvel/rime-ice.git \"$RIME_DIR\""
  exit 1
fi

# ===== 检查本地修改，避免 pull 冲突 =====
if ! git -C "$RIME_DIR" diff --quiet || ! git -C "$RIME_DIR" diff --cached --quiet; then
  echo "警告：检测到本地未提交的修改，git pull 可能失败。"
  echo "建议把自定义配置写进 *.custom.yaml，而不是修改雾凇拼音的原文件。"
  read -r -p "是否仍然继续？[y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "已取消。"; exit 0; }
fi

# ===== 拉取更新 =====
echo "正在更新雾凇拼音..."
git -C "$RIME_DIR" pull --ff-only

# ===== 清理 build 缓存，确保重新构建 =====
if [ -d "$RIME_DIR/build" ]; then
  echo "清理 build 缓存..."
  rm -rf "$RIME_DIR/build"
fi

# ===== 触发重新部署 =====
if pgrep -x fcitx5 >/dev/null; then
  echo "重新部署 Rime..."
  fcitx5-remote -r
  echo "更新完成。"
else
  echo "警告：Fcitx5 未运行，请启动 Fcitx5 后手动执行："
  echo "  fcitx5-remote -r"
fi