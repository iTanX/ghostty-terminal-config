#!/usr/bin/env bash
# 通过 Gear Lever 安装 SyncClipboard 官方 AppImage 并配置更新源。
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/../lib/github-appimage.sh"

main() {
    local arch

    # 按 CPU 架构选择上游 AppImage；安装 Wayland 剪贴板辅助工具。
    case "$(uname -m)" in
        x86_64) arch=x64 ;;
        aarch64) arch=arm64 ;;
        *) printf 'SyncClipboard 未提供当前架构的 AppImage。\n' >&2; return 1 ;;
    esac
    install_github_appimage SyncClipboard Jeric-X/SyncClipboard "SyncClipboard_linux_${arch}.AppImage" wl-clipboard
}

main "$@"
