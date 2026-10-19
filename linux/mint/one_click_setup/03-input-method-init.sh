#!/usr/bin/env bash
# ============================================================
# Linux Mint 22.3 配置 Fcitx5 + Rime + 雾凇拼音
# 用法：bash 03-input-method-init.sh
# 说明：脚本只处理可自动化部分；注销重登和 GUI 添加输入法需手动完成。
# ============================================================

# 任何命令失败立即退出，未定义变量报错，管道错误也捕获
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

# ===== 步骤 1：安装软件包 =====
echo "[1/4] 安装 Fcitx5、Rime 及依赖..."
sudo apt update
# 按 APT 默认策略安装推荐依赖，包括 GTK/Qt 输入法前端。
# fcitx5-rime 是 Rime 引擎适配器，必需
# librime-plugin-lua 提供 Lua 支持，雾凇部分功能依赖
sudo apt install -y \
  fcitx5 fcitx5-rime fcitx5-config-qt git librime-plugin-lua

# ===== 步骤 2：设置默认输入法框架及登录自启动 =====
echo "[2/4] 设置 Fcitx5 为默认输入法框架及登录自启动..."
# 写入 im-config 的用户级配置，注销重登后生效
im-config -n fcitx5

# 按 Fcitx 官方方式部署 XDG 自启动项，使用同一文件名，重复运行不会新增条目。
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

# ===== 步骤 3：配置环境变量 =====
echo "[3/4] 写入环境变量配置..."
# Mint 桌面登录时读取 ~/.profile；保留原有内容，重复运行不追加同一配置块。
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

# ===== 步骤 4：安装雾凇拼音 =====
echo "[4/4] 安装雾凇拼音..."
if [ -d "$RIME_DIR/.git" ]; then
  # 已是 git 仓库：直接拉取更新，避免重复克隆
  echo "检测到已有雾凇拼音仓库，执行更新..."
  git -C "$RIME_DIR" pull --ff-only
elif [ -e "$RIME_DIR" ]; then
  # 目录存在但不是 git 仓库：直接删除后重新克隆（不备份）
  echo "检测到非 Git 仓库的 Rime 配置目录，删除后重新克隆..."
  rm -rf "$RIME_DIR"
  git clone --depth=1 https://github.com/iDvel/rime-ice.git "$RIME_DIR"
else
  # 全新安装
  git clone --depth=1 https://github.com/iDvel/rime-ice.git "$RIME_DIR"
fi

# ===== 后续手动步骤提示 =====
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
