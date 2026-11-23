#!/usr/bin/env bash
# 通过 Gear Lever 安装 SwitchHosts 官方 AppImage 并配置更新源。
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/github-appimage.sh"

main() {
    local arch

    # 按 CPU 架构匹配稳定版；由 polkit 在写入 hosts 文件时请求授权。
    case "$(uname -m)" in
        x86_64) arch=amd64 ;;
        aarch64) arch=aarch64 ;;
        *) printf 'SwitchHosts 未提供当前架构的 AppImage。\n' >&2; return 1 ;;
    esac
    install_github_appimage SwitchHosts oldj/SwitchHosts "SwitchHosts-*-linux-${arch}.AppImage" polkit
}

main "$@"
