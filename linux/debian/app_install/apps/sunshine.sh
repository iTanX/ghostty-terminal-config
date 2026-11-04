#!/usr/bin/env bash
# 通过官方 Cloudsmith 稳定源使用 APT 安装 Sunshine；可独立运行。
set -euo pipefail

KEY_URL='https://dl.cloudsmith.io/public/lizardbyte/stable/gpg.04C871E8D308324E.key'
KEYRING='/usr/share/keyrings/lizardbyte-stable-archive-keyring.gpg'
SOURCE_LIST='/etc/apt/sources.list.d/lizardbyte-stable.list'
REPOSITORY='https://dl.cloudsmith.io/public/lizardbyte/stable/deb/debian'

install_sunshine() (
    local work architecture
    architecture="$(dpkg --print-architecture)"
    work="$(mktemp -d)"
    trap 'rm -rf -- "$work"' EXIT

    # ==============================================================================
    # 安装 Sunshine
    # ==============================================================================
    # 1. 准备软件源配置，检查已有文件是否一致。
    printf 'deb [arch=%s signed-by=%s] %s trixie main\n' \
        "$architecture" "$KEYRING" "$REPOSITORY" > "${work}/lizardbyte-stable.list"
    if [[ -e "$SOURCE_LIST" || -L "$SOURCE_LIST" ]]; then
        if ! sudo cmp -s "${work}/lizardbyte-stable.list" "$SOURCE_LIST"; then
            printf '软件源文件已存在且内容不同，请检查后重新运行：%s\n' "$SOURCE_LIST" >&2
            return 1
        fi
    fi

    # 2. 安装 APT 软件源所需的辅助依赖。
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg

    # 3. 下载签名密钥并配置官方稳定源。
    printf '正在配置 Sunshine 官方稳定源……\n'
    mkdir "${work}/key"
    curl --fail --location --retry 3 --proto '=https' --proto-redir '=https' \
        --output "${work}/key/lizardbyte-stable.asc" "$KEY_URL"
    gpg --batch --dearmor --output "${work}/lizardbyte-stable.gpg" "${work}/key/lizardbyte-stable.asc"
    sudo install -d -m 0755 /usr/share/keyrings /etc/apt/sources.list.d
    if ! sudo cmp -s "${work}/lizardbyte-stable.gpg" "$KEYRING"; then
        sudo install -m 0644 "${work}/lizardbyte-stable.gpg" "$KEYRING"
    fi
    if [[ ! -e "$SOURCE_LIST" ]]; then
        sudo install -m 0644 "${work}/lizardbyte-stable.list" "$SOURCE_LIST"
    else
        printf 'Sunshine 稳定源已配置，复用现有文件。\n'
    fi

    # 4. 刷新索引，通过 APT 安装或更新 Sunshine。
    sudo apt-get update
    sudo apt-get install -y sunshine

    # 5. 检查并修复虚拟键鼠输入。
    repair_sunshine_input
    printf '\nSunshine 稳定版安装完成，可从应用菜单启动 Sunshine。\n'
    printf '后续可通过 APT 更新 Sunshine。\n'
)

repair_sunshine_input() (
    local module_missing=0 work
    local modules_file='/etc/modules-load.d/sunshine-uinput.conf'
    local service='app-dev.lizardbyte.app.Sunshine.service'

    # 1. 检查内核设备及当前用户权限，正常时跳过修复。
    if [[ ! -d /sys/class/misc/uinput ]]; then
        printf '检测到 uinput 内核设备未注册，需要加载模块。\n'
        module_missing=1
    elif [[ -r /dev/uinput && -w /dev/uinput ]]; then
        printf 'uinput 设备及读写权限正常，跳过输入修复。\n'
        return
    else
        printf '检测到当前用户无法读写 /dev/uinput，需要重新应用设备权限。\n'
    fi

    # 2. 加载缺失模块，重新应用软件包自带的设备权限规则。
    if ((module_missing)); then
        sudo modprobe uinput
    fi
    sudo udevadm control --reload-rules
    sudo udevadm trigger --subsystem-match=misc --sysname-match=uinput
    sudo udevadm settle

    # 3. 验证修复结果，未恢复时停止并提示检查。
    if [[ ! -d /sys/class/misc/uinput || ! -r /dev/uinput || ! -w /dev/uinput ]]; then
        printf 'uinput 设备或读写权限仍不正常，请检查 Sunshine udev 规则及当前桌面会话权限。\n' >&2
        return 1
    fi

    # 4. 为本次缺失的模块配置开机加载，保留已有的不同配置。
    if ((module_missing)); then
        work="$(mktemp -d)"
        trap 'rm -rf -- "$work"' EXIT
        printf 'uinput\n' > "${work}/sunshine-uinput.conf"
        if [[ -e "$modules_file" || -L "$modules_file" ]]; then
            if ! sudo cmp -s "${work}/sunshine-uinput.conf" "$modules_file"; then
                printf '模块配置已存在且内容不同，请检查后重新运行：%s\n' "$modules_file" >&2
                return 1
            fi
        else
            sudo install -D -m 0644 "${work}/sunshine-uinput.conf" "$modules_file"
        fi
    fi

    # 5. 重启正在运行的用户服务，重新创建虚拟键鼠。
    if systemctl --user is-active --quiet "$service"; then
        printf '正在重启 Sunshine 以应用输入修复，当前串流将断开。\n'
        systemctl --user restart "$service"
    else
        printf 'Sunshine 用户服务未运行，下次启动时将创建虚拟键鼠。\n'
    fi
    printf 'uinput 输入修复完成，请通过 Moonlight 验证鼠标和键盘操作。\n'
)

main() {
    # ==============================================================================
    # 检查安装环境
    # ==============================================================================
    # 1. 检查普通用户身份及系统工具。
    if [[ "${EUID}" -eq 0 ]]; then
        printf '请以普通用户运行，不要使用 sudo。\n' >&2
        return 1
    fi
    local command_name
    for command_name in sudo apt-get dpkg modprobe udevadm systemctl; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            printf '缺少必需命令：%s，请安装后重新运行。\n' "$command_name" >&2
            return 1
        fi
    done

    # 2. 检查 Debian 13 及官方软件包支持的架构。
    . /etc/os-release
    if [[ "${ID:-}" != 'debian' || "${VERSION_CODENAME:-}" != 'trixie' ]]; then
        printf '此脚本仅支持 Debian 13（trixie）。\n' >&2
        return 1
    fi
    case "$(dpkg --print-architecture)" in
        amd64|arm64) ;;
        *)
            printf 'Sunshine 官方 Debian 软件包仅支持 amd64 和 arm64。\n' >&2
            return 1
            ;;
    esac

    install_sunshine
}

main "$@"
