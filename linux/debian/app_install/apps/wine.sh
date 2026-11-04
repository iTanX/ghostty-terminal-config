#!/usr/bin/env bash
# 通过官方 APT 源安装 Wine Staging 和 WineGUI；可由普通用户独立运行。
# WineHQ：https://gitlab.winehq.org/wine/wine/-/wikis/Debian-Ubuntu
# WineGUI：https://github.com/winegui/WineGUI
set -euo pipefail

WINEHQ_URL='https://dl.winehq.org/wine-builds'
WINEGUI_INSTALLER_URL='https://raw.githubusercontent.com/winegui/WineGUI/main/scripts/install.sh'

require_commands() {
    local command_name
    for command_name in "$@"; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            printf '缺少必需命令：%s，请安装后重新运行。\n' "$command_name" >&2
            return 1
        fi
    done
}

install_repository_file() {
    local source="$1" destination="$2" backup
    # 3.3.1 复用内容相同的文件，备份并替换有变更的软件源或密钥。
    if [[ -e "$destination" || -L "$destination" ]]; then
        if cmp -s -- "$source" "$destination"; then
            return
        fi
        backup="${destination}.backup.$(date +%Y%m%d%H%M%S).$$"
        sudo cp -a -- "$destination" "$backup"
        printf '原文件已备份至：%s\n' "$backup"
    fi
    sudo install -m 0644 -- "$source" "$destination"
}

main() (
    local distribution suite work source_file winegui_suite package
    local ID='' ID_LIKE='' VERSION_CODENAME='' UBUNTU_CODENAME=''

    # 1 检查运行身份、依赖及目标平台。
    # 1.1 检查普通用户身份和必需命令。
    if [[ "${EUID}" -eq 0 ]]; then
        printf '请以普通用户运行本脚本，脚本会在需要时调用 sudo。\n' >&2
        return 1
    fi
    require_commands sudo apt-get dpkg dpkg-query curl bash mktemp cmp date cp install grep rm
    # 1.2 识别 Debian、Ubuntu 及兼容衍生发行版，优先使用 Ubuntu 基础版本代号。
    if [[ ! -r /etc/os-release ]]; then
        printf '无法读取 /etc/os-release，不能确认系统版本。\n' >&2
        return 1
    fi
    source /etc/os-release
    if [[ "$ID" == ubuntu || " ${ID_LIKE} " == *' ubuntu '* || -n "$UBUNTU_CODENAME" ]]; then
        distribution=ubuntu
    elif [[ "$ID" == debian || " ${ID_LIKE} " == *' debian '* ]]; then
        distribution=debian
    else
        printf '本脚本用于 Debian、Ubuntu 及兼容的衍生发行版。\n' >&2
        return 1
    fi
    suite="${UBUNTU_CODENAME:-${VERSION_CODENAME}}"
    if [[ ! "$suite" =~ ^[a-z]+$ || "$(dpkg --print-architecture)" != amd64 ]]; then
        printf '需要具有有效版本代号的 64 位 amd64 Debian/Ubuntu 兼容系统。\n' >&2
        return 1
    fi

    # 2 下载官方安装文件并检查兼容性。
    # 2.1 使用独立临时目录，退出时清理下载文件。
    work="$(mktemp -d)"
    trap 'rm -rf -- "$work"' EXIT
    source_file="winehq-${suite}.sources"
    printf '正在下载 %s 的 WineHQ 软件源、签名密钥和 WineGUI 安装脚本……\n' "$suite"
    curl --fail --location --retry 3 --proto '=https' --proto-redir '=https' \
        --output "${work}/${source_file}" \
        "${WINEHQ_URL}/${distribution}/dists/${suite}/${source_file}"
    curl --fail --location --retry 3 --proto '=https' --proto-redir '=https' \
        --output "${work}/winehq.key" "${WINEHQ_URL}/winehq.key"
    curl --fail --location --retry 3 --proto '=https' --proto-redir '=https' \
        --output "${work}/winegui-install.sh" "$WINEGUI_INSTALLER_URL"
    # 2.2 检查 WineGUI 安装脚本语法和系统兼容性。
    bash -n "${work}/winegui-install.sh"
    winegui_suite="$(bash "${work}/winegui-install.sh" --print-suite)"
    if [[ "$winegui_suite" != "$suite" ]]; then
        printf 'WineGUI 与 WineHQ 检测到的系统代号不一致，停止安装。\n' >&2
        return 1
    fi
    # 2.3 校验 WineHQ 软件源的发行版、地址和签名密钥路径。
    grep -Fxq "Suites: ${suite}" "${work}/${source_file}"
    grep -Fxq "URIs: ${WINEHQ_URL}/${distribution}" "${work}/${source_file}"
    grep -Fxq 'Signed-By: /etc/apt/keyrings/winehq-archive.key' "${work}/${source_file}"

    # 3 配置 WineHQ 软件源并安装 Wine Staging。
    # 3.1 获取 sudo 权限，刷新索引并安装辅助依赖。
    sudo -v
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    # 3.2 按软件源的架构声明启用 i386 支持。
    if grep -Eq '^Architectures:.*\bi386\b' "${work}/${source_file}"; then
        sudo dpkg --add-architecture i386
    fi
    # 3.3 转换签名密钥，安装密钥和 WineHQ 软件源文件。
    gpg --homedir "$work" --batch --yes --dearmor --output "${work}/winehq-archive.key" "${work}/winehq.key"
    sudo install -d -m 0755 /etc/apt/keyrings /etc/apt/sources.list.d
    install_repository_file "${work}/winehq-archive.key" /etc/apt/keyrings/winehq-archive.key
    install_repository_file "${work}/${source_file}" "/etc/apt/sources.list.d/${source_file}"
    # 3.4 刷新索引并安装 Wine Staging 及推荐依赖。
    printf '正在安装 Wine Staging……\n'
    sudo apt-get update
    sudo apt-get install -y --install-recommends winehq-staging

    # 4 使用官方安装器配置 WineGUI APT 源并安装图形管理工具。
    # 4.1 执行 WineGUI 官方安装脚本。
    printf '正在安装 WineGUI……\n'
    sudo bash "${work}/winegui-install.sh"

    # 5 验证安装结果并打印启动和后续更新提示。
    # 5.1 检查 Wine 和 WineGUI 安装状态。
    for package in winehq-staging winegui; do
        if [[ "$(dpkg-query -W -f='${Status}' "$package")" != 'install ok installed' ]]; then
            printf '软件包未完成安装：%s\n' "$package" >&2
            return 1
        fi
    done
    # 5.2 输出安装结果、启动方式、更新和软件源恢复提示。
    printf '\nWine Staging 和 WineGUI 安装完成。\n'
    printf '从应用菜单启动 WineGUI，或在终端运行 winegui。\n'
    printf '之后可通过系统更新升级 Wine Staging 和 WineGUI。\n'
    printf '如已生成备份，可将对应的 .backup.* 文件复制回原路径，再运行 sudo apt-get update。\n'
)

main "$@"
