#!/usr/bin/env bash
# Linux Mint 应用安装：下载并安装最新版 Google Chrome 稳定版。
# 用法：bash 05-auto-install-app.sh；请使用普通用户运行，不要使用 sudo 执行整个脚本。
# 可重复执行，已安装的 Chrome 会通过最新 deb 包更新。

set -euo pipefail

# 与其他初始化脚本保持一致，仅系统级安装使用 sudo。
if [ "$(id -u)" -eq 0 ]; then
    echo "错误：请使用普通用户运行本脚本，不要使用 sudo。" >&2
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    echo "错误：未找到 sudo，请先为当前用户配置 sudo 权限。" >&2
    exit 1
fi

# Mint 使用 amd64 软件包，避免在其他架构上安装错误的 deb。
if [ "$(dpkg --print-architecture)" != "amd64" ]; then
    echo "错误：本脚本的 Google Chrome 安装包仅适用于 amd64 架构。" >&2
    exit 1
fi

printf '\n==> 安装下载依赖\n'
sudo apt-get update
sudo apt-get install -y ca-certificates curl xdg-user-dirs

# 按系统设置定位下载文件夹，兼容中文“下载”和自定义目录；安装后保留安装包。
DOWNLOAD_DIR="$(xdg-user-dir DOWNLOAD)"
mkdir -p "$DOWNLOAD_DIR"
CHROME_DEB="$DOWNLOAD_DIR/google-chrome-stable_current_amd64.deb"

printf '\n==> 下载最新版 Google Chrome 稳定版\n'
# 官方 current 地址始终提供当前稳定版，无需在脚本中维护版本号。
curl -fL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    -o "$CHROME_DEB"

# 安装时由 APT 自动处理依赖。
printf '\n==> 安装或更新 Google Chrome\n'
sudo apt-get install -y "$CHROME_DEB"

printf '\nGoogle Chrome 安装或更新完成。安装包保留在：%s\n' "$CHROME_DEB"
