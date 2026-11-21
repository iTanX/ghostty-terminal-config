#!/usr/bin/env bash
# 自动发现并依次运行软件专属脚本，新增软件时无需修改本文件。
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

main() {
    # 1 检查运行身份，所有软件默认按当前普通用户安装。
    # 1.1 拒绝 root，避免将程序和桌面配置写入错误的用户目录。
    if [[ "${EUID}" -eq 0 ]]; then
        printf '请以普通用户运行，不要使用 sudo。\n' >&2
        return 1
    fi

    # 2 自动发现软件脚本，无需手动维护软件清单。
    # 2.1 只读取 apps 第一层的 .sh 文件，按文件名字节顺序排列。
    local LC_ALL=C
    local script status
    local -a scripts
    shopt -s nullglob
    scripts=("${SCRIPT_DIR}"/apps/*.sh)
    # 2.2 没有安装脚本时给出提示，正常结束。
    if ((${#scripts[@]} == 0)); then
        printf '没有找到软件安装脚本，请添加 apps/*.sh。\n'
        return
    fi

    # 3 按顺序串行执行每个软件的安装和配置。
    for script in "${scripts[@]}"; do
        [[ -f "$script" ]] || continue
        printf '\n正在执行：%s\n' "${script##*/}"
        # 3.1 使用独立 Bash 进程，避免软件脚本的变量、trap 和退出操作互相影响。
        if bash "$script"; then
            printf '执行完成：%s\n' "${script##*/}"
        else
            # 3.2 保留失败退出码并停止后续安装，便于定位和修复问题。
            status=$?
            printf '执行失败：%s（退出码 %s），已停止后续安装。\n' "${script##*/}" "$status" >&2
            return "$status"
        fi
    done
    # 4 所有专属脚本均成功结束后，再打印整体完成提示。
    printf '\n全部软件安装脚本执行完成。\n'
}

main "$@"
