#!/usr/bin/env bash

# ==============================================================================
# 准备配置
# ==============================================================================
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "错误：请使用普通用户运行本脚本，不要使用 sudo。" >&2
  exit 1
fi

RIME_DIR="$HOME/.local/share/fcitx5/rime"
PROFILE_FILE="$HOME/.profile"
PROFILE_MARKER="# >>> fcitx5-input-method >>>"
AUTOSTART_SOURCE="/usr/share/applications/org.fcitx.Fcitx5.desktop"
AUTOSTART_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/org.fcitx.Fcitx5.desktop"

# ==============================================================================
# 配置输入法
# ==============================================================================
# 1. 安装输入法
echo "==> 安装 Fcitx5、Rime 及依赖..."
sudo apt update

# 1.1 安装依赖
sudo apt install -y git

# 1.2 安装输入法软件包
sudo apt install -y \
  fcitx5 fcitx5-rime fcitx5-config-qt librime-plugin-lua

# 2. 设置默认框架与自启动
echo "==> 设置 Fcitx5 为默认输入法框架及登录自启动..."
im-config -n fcitx5

if [ ! -f "$AUTOSTART_SOURCE" ]; then
  echo "错误：未找到 Fcitx5 启动文件：$AUTOSTART_SOURCE" >&2
  exit 1
fi
if cmp -s "$AUTOSTART_SOURCE" "$AUTOSTART_FILE"; then
  echo "Fcitx5 登录自启动已配置，跳过写入。"
else
  install -Dm644 -T "$AUTOSTART_SOURCE" "$AUTOSTART_FILE"
  echo "已设置 Fcitx5 登录自启动：$AUTOSTART_FILE"
fi

# 3. 配置输入法环境变量
echo "==> 写入环境变量配置..."
if grep -Fqx "$PROFILE_MARKER" "$PROFILE_FILE" 2>/dev/null; then
  echo "${PROFILE_FILE} 中已存在 Fcitx5 环境变量配置，跳过追加。"
else
  cat >> "$PROFILE_FILE" <<'EOF'

# >>> fcitx5-input-method >>>
# Fcitx5 输入法环境变量：为 GTK、Qt 和 X11 应用启用 Fcitx 输入法，注销重登后生效。
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
# <<< fcitx5-input-method <<<
EOF
  echo "已追加 Fcitx5 输入法环境变量到 $PROFILE_FILE"
fi

# 4. 安装雾凇拼音
echo "==> 安装雾凇拼音..."
if [ -d "$RIME_DIR/.git" ]; then
  echo "检测到已有雾凇拼音仓库，执行更新..."
  git -C "$RIME_DIR" pull --ff-only
elif [ -e "$RIME_DIR" ]; then
  echo "检测到非 Git 仓库的 Rime 配置目录，删除后重新克隆..."
  rm -rf "$RIME_DIR"
  git clone --depth=1 https://github.com/iDvel/rime-ice.git "$RIME_DIR"
else
  git clone --depth=1 https://github.com/iDvel/rime-ice.git "$RIME_DIR"
fi

# ==============================================================================
# 完成配置
# ==============================================================================
cat <<'MSG'

============================================================
脚本执行完成。剩余步骤需手动操作：

1. 注销并重新登录（使 im-config 和环境变量生效）。
   Fcitx5 已配置为登录桌面后自动启动。

2. 运行以下命令打开配置工具：
     fcitx5-configtool
   取消勾选“仅显示当前语言”，搜索并添加 Rime，调整顺序后应用。

3. 触发部署（二选一）：
     busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 SetConfig sv fcitx://config/addon/rime/deploy s ''
   或在托盘图标右键菜单点击“重新部署”。请等待输入法的部署完成提示。

4. 按 Ctrl+空格 切换到 Rime，输入拼音验证。
   输入状态下按 F4 可查看当前方案是否为雾凇拼音。
============================================================

MSG
