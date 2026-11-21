#!/usr/bin/env bash
# 通过 Pacman 安装 Sunshine，并设置捕获、编码和界面语言。
set -euo pipefail

configure_sunshine() {
    local config_path="${XDG_CONFIG_HOME:-${HOME}/.config}/sunshine/sunshine.conf"

    # 3. 更新指定配置项，保留其他设置和注释。
    /usr/bin/python3 -I - "$config_path" <<'PY'
from pathlib import Path
from stat import S_IMODE
from tempfile import NamedTemporaryFile
import os
import re
import sys

path = Path(sys.argv[1]).resolve()
settings = {'capture': 'kms', 'encoder': 'vaapi', 'locale': 'zh'}
try:
    with path.open(encoding='utf-8', newline='') as config:
        original = config.read()
        mode = S_IMODE(os.fstat(config.fileno()).st_mode)
except FileNotFoundError:
    original = ''
    mode = 0o600

seen = set()

def replace(match):
    indent, key, trailing_space = match.groups()
    seen.add(key)
    return f'{indent}{key} = {settings[key]}{trailing_space}'

updated = re.sub(r'^([ \t]*)(capture|encoder|locale)[ \t]*=[^#\r\n]*?([ \t]*)(?=#|\r?$)',
                 replace, original, flags=re.MULTILINE)
if seen != settings.keys():
    newline = '\r\n' if '\r\n' in original else '\n'
    if updated and not updated.endswith(('\r', '\n')):
        updated += newline
    updated += ''.join(f'{key} = {value}{newline}' for key, value in settings.items() if key not in seen)

# 同目录写入后替换，避免写入中断时损坏原配置文件。
if updated != original:
    path.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(mode='w', encoding='utf-8', newline='', dir=path.parent, delete=False) as config:
        temporary = Path(config.name)
        try:
            config.write(updated)
            config.flush()
            os.fchmod(config.fileno(), mode)
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)
PY
    printf 'Sunshine 已配置为 KMS 捕获、VA-API 编码和简体中文。配置将在下次启动时生效。\n'
}

main() {
    local command_name

    # 1. 检查运行身份及必需命令。
    if [[ "$EUID" -eq 0 ]]; then
        printf '请以普通用户运行，不要使用 sudo。\n' >&2
        return 1
    fi
    for command_name in sudo pacman /usr/bin/python3; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            printf '缺少必需命令：%s，请安装后重新运行。\n' "$command_name" >&2
            return 1
        fi
    done

    # 2. 缺少 Sunshine 时从当前 Pacman 仓库安装。
    if ! pacman -Q sunshine >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm sunshine
    fi

    configure_sunshine
}

main "$@"
