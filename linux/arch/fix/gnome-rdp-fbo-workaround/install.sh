#!/usr/bin/env bash
# 安装 GNOME 远程桌面断连的 Mutter FBO 绕过配置。
set -euo pipefail

# 1. 确认以桌面用户运行，且 GNOME Shell 用户服务可用。
if (( EUID == 0 )); then
    printf '请以需要修复的 GNOME 桌面用户运行，不要使用 sudo。\n' >&2
    exit 1
fi
if ! systemctl --user cat org.gnome.Shell@user.service >/dev/null; then
    printf '无法读取 GNOME Shell 用户服务，请登录 GNOME 桌面后重试。\n' >&2
    exit 1
fi

# 2. 安装配置，保留已有的不同配置。
config_dir="$HOME/.config/systemd/user/org.gnome.Shell@user.service.d"
config_file="$config_dir/90-rdp-fbo-workaround.conf"
config_content='# 绕过 Mutter 51.1 在远程桌面捕获画面时的 FBO 后备缓冲区崩溃。
[Service]
Environment=MUTTER_DEBUG_USE_FBOS=0'

if [[ -L "$config_file" ]]; then
    printf '目标是符号链接，未修改：%s\n' "$config_file" >&2
    exit 1
elif [[ -e "$config_file" ]]; then
    if [[ ! -f "$config_file" ]] || ! cmp -s "$config_file" <(printf '%s\n' "$config_content"); then
        printf '目标已存在且内容不同，未覆盖：%s\n' "$config_file" >&2
        exit 1
    fi
    printf '配置已存在：%s\n' "$config_file"
else
    mkdir -p -- "$config_dir"
    (set -o noclobber; printf '%s\n' "$config_content" > "$config_file")
    printf '已写入配置：%s\n' "$config_file"
fi

# 3. 重新加载用户服务配置，不退出当前桌面会话。
systemctl --user daemon-reload
printf '请保存工作，注销 GNOME 桌面并重新登录，使配置生效；仅断开远程桌面连接不会生效。\n'
