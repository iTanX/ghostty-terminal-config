#!/usr/bin/env bash
set -euo pipefail

# 1. 检测 CPU 架构
raw_arch=$(uname -m)
case "$raw_arch" in
    x86_64)  motrix_arch="x64" ;;
    aarch64) motrix_arch="aarch64" ;;
    *) echo "错误：不支持的架构 '$raw_arch'"; exit 1 ;;
esac

echo "检测到架构：$raw_arch，Motrix 包标识：$motrix_arch"

# 2. 获取最新版本号：优先使用 releases/latest 重定向，避开 API 限流
REPO="agalwood/Motrix"
echo "正在解析 Motrix 最新版本..."

version=""
# 主方案：读取重定向的 Location 头（无 API 消耗，无速率限制）
# 这是一个 302 重定向，Location 指向 .../releases/tag/vX.Y.Z
redirect_url=$(curl -sI "https://github.com/${REPO}/releases/latest" \
    | grep -i '^location:' \
    | tr -d '\r' \
    | awk '{print $2}')

if [[ -n "$redirect_url" ]]; then
    # 从 URL 末尾提取 tag（例如 .../releases/tag/v2.4.4 -> v2.4.4）
    version="${redirect_url##*/}"
    version="${version#v}"  # 去掉前缀 v
    echo "通过重定向解析到版本：$version"
fi

# 备用方案：如果重定向解析失败，才尝试 API（可能触发限流）
if [[ -z "$version" ]]; then
    echo "重定向解析失败，尝试 GitHub API（可能受限）..."
    api_response=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" || true)
    if grep -q "API rate limit exceeded" <<< "$api_response"; then
        echo "错误：GitHub API 速率已超限，且重定向解析失败。请稍后重试，或使用 GITHUB_TOKEN 环境变量。"
        exit 1
    fi
    version=$(echo "$api_response" | grep -oP '"tag_name":\s*"\K[^"]+' | head -n1)
    version="${version#v}"
fi

if [[ -z "$version" ]]; then
    echo "错误：无法确定 Motrix 最新版本。"
    exit 1
fi

echo "目标版本：$version"

# 3. 构造下载链接
package_name="Motrix-${version}-${motrix_arch}.pacman"
download_url="https://github.com/${REPO}/releases/download/v${version}/${package_name}"

echo "准备下载：$package_name"

# 4. 下载到临时目录
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

echo "正在下载..."
curl -fL --progress-bar -o "$temp_dir/$package_name" "$download_url"

# 5. 安装
echo "正在安装 Motrix..."
sudo pacman -U "$temp_dir/$package_name" --noconfirm

echo "Motrix $version ($motrix_arch) 安装完成。"