#!/usr/bin/env bash
# ============================================================
# 一键更新雾凇拼音并重新部署
# 用法：bash 04-input-method-update.sh
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

# ===== 触发重新部署 =====
# 调用 Rime 的部署入口进行完整检查，不手动删除 build；-r 只重载 Fcitx 全局配置。
if pgrep -x fcitx5 >/dev/null; then
  echo "请求重新部署 Rime..."
  if ! busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 \
      SetConfig sv fcitx://config/addon/rime/deploy s ''; then
    echo "错误：请求 Rime 部署失败，请在当前桌面用户的终端重试，或通过托盘菜单重新部署。" >&2
    exit 1
  fi
  # 部署在后台进行，D-Bus 调用成功只表示请求已受理。
  echo "雾凇拼音已更新，已请求 Rime 重新部署，请等待输入法的完成提示。"
else
  echo "雾凇拼音已更新。Fcitx5 未运行，请启动后通过托盘菜单重新部署，或执行："
  echo "  busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 SetConfig sv fcitx://config/addon/rime/deploy s ''"
fi
