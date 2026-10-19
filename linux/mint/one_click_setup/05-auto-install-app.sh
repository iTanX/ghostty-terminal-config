#!/usr/bin/env bash
# Linux Mint 应用安装：通过 Google 官方 APT 源安装 Google Chrome 稳定版。
# 用法：bash 05-auto-install-app.sh；请使用普通用户运行，不要使用 sudo 执行整个脚本。
# 可重复执行，已安装的 Chrome 会通过 APT 源更新。

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

# Google Chrome 的 Linux APT 源仅提供 amd64 软件包。
if [ "$(dpkg --print-architecture)" != "amd64" ]; then
    echo "错误：Google Chrome 的 Linux APT 源仅适用于 amd64 架构。" >&2
    exit 1
fi

printf '\n==> 安装软件源配置依赖\n'
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
CHROME_KEYRING="/usr/share/keyrings/google-chrome.gpg"
CHROME_SOURCE_FILE="/etc/apt/sources.list.d/google-chrome.sources"

printf '\n==> 配置 Google Chrome 官方 APT 源\n'
# 与官方软件包使用相同的二进制密钥路径和 DEB822 源配置。
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub -o "$TMP_DIR/google-chrome.asc"
gpg --batch --dearmor --output "$TMP_DIR/google-chrome.gpg" "$TMP_DIR/google-chrome.asc"
sudo install -Dm0644 "$TMP_DIR/google-chrome.gpg" "$CHROME_KEYRING"
cat > "$TMP_DIR/google-chrome.sources" <<EOF
X-Repolib-Name: Google Chrome
Types: deb
URIs: https://dl.google.com/linux/chrome-stable/deb/
Suites: stable
Components: main
Architectures: amd64
Signed-By: $CHROME_KEYRING
EOF
sudo install -Dm0644 "$TMP_DIR/google-chrome.sources" "$CHROME_SOURCE_FILE"

# 安装时由 APT 自动处理依赖。
printf '\n==> 安装或更新 Google Chrome\n'
sudo apt-get update
sudo apt-get install -y google-chrome-stable

printf '\nGoogle Chrome 安装或更新完成，后续可通过 APT 更新。\n'
