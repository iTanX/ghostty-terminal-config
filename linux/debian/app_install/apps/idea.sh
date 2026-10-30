#!/usr/bin/env bash
# 安装 IntelliJ IDEA，并配置数据目录与应用菜单；可独立运行。
set -euo pipefail

VERSION='2026.2.3'
ARCHIVE="idea-${VERSION}.tar.gz"
DOWNLOAD_URL="https://download.jetbrains.com/idea/${ARCHIVE}"
INSTALL_ROOT="${HOME}/.local/opt/idea"
DESTINATION="${INSTALL_ROOT}/latest"
DATA_ROOT="${XDG_DATA_HOME:-${HOME}/.local/share}"

require_commands() {
    local command_name
    for command_name in "$@"; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            printf '缺少必需命令：%s，请安装后重新运行。\n' "$command_name" >&2
            return 1
        fi
    done
}

check_installation() {
    # 2.1 核对产品、版本及必需文件，避免复用其他版本或不完整的安装。
    /usr/bin/python3 -I - "$1" "$VERSION" <<'PY'
import json
from pathlib import Path
import os
import sys

root = Path(sys.argv[1])
try:
    product = json.loads((root / 'product-info.json').read_text(encoding='utf-8'))
    valid = product['productCode'] == 'IU' and product['version'] == sys.argv[2]
    valid = valid and os.access(root / 'bin/idea', os.X_OK)
    valid = valid and (root / 'bin/idea.properties').is_file()
    valid = valid and (root / 'bin/idea64.vmoptions').is_file()
    valid = valid and (root / 'bin/idea.svg').is_file()
except (OSError, ValueError, KeyError, TypeError):
    valid = False
sys.exit(0 if valid else 1)
PY
}

configure_properties() {
    # 3.1 解除四项路径设置的注释并写入指定值，保留其他配置；重复执行不重复追加。
    /usr/bin/python3 -I - "$1/bin/idea.properties" <<'PY'
from pathlib import Path
import re
import shutil
import sys
import tempfile

path = Path(sys.argv[1])
settings = {
    'idea.config.path': '/home/frankchan/文档/.AppCaK/DevCac/JetBrains/idea/config',
    'idea.system.path': '/home/frankchan/文档/.AppCaK/DevCac/JetBrains/idea/system',
    'idea.plugins.path': '${idea.config.path}/plugins',
    'idea.log.path': '${idea.system.path}/log',
}
original = path.read_text(encoding='utf-8')
lines = original.splitlines(keepends=True)
seen = set()
result = []
for line in lines:
    match = re.match(r'^\s*[#!]?\s*(idea\.(?:config|system|plugins|log)\.path)\s*[=:]', line)
    if match:
        key = match.group(1)
        if key not in seen:
            result.append(f'{key}={settings[key]}\n')
            seen.add(key)
    else:
        result.append(line)
for key, value in settings.items():
    if key not in seen:
        if result and not result[-1].endswith('\n'):
            result[-1] += '\n'
        result.append(f'{key}={value}\n')
updated = ''.join(result)
if updated != original:
    # 3.2 修改前备份原始属性文件，不移动或清理已有的 IDE 数据目录。
    with tempfile.NamedTemporaryFile(prefix='idea.properties.backup.', dir=path.parent, delete=False) as backup:
        backup_path = Path(backup.name)
    shutil.copy2(path, backup_path)
    path.write_text(updated, encoding='utf-8')
    print(f'已配置：{path}')
else:
    print('idea.properties 已是指定配置，跳过修改。')
PY
}

configure_vmoptions() {
    # 3.3 保留现有 JVM 参数，只追加尚未配置的指定选项。
    /usr/bin/python3 -I - "$1/bin/idea64.vmoptions" <<'PY'
from pathlib import Path
import shutil
import sys
import tempfile

path = Path(sys.argv[1])
options = [
    '--add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED',
    '--add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED',
    '-javaagent:/home/frankchan/文档/.AppCaK/DevCac/JetBrains/active/ja-netfilter-260325/ja-netfilter/ja-netfilter.jar',
]
original = path.read_text(encoding='utf-8')
existing = {line.strip() for line in original.splitlines()}
missing = [option for option in options if option not in existing]
if missing:
    # 3.4 修改前备份原始 JVM 参数文件。
    with tempfile.NamedTemporaryFile(prefix='idea64.vmoptions.backup.', dir=path.parent, delete=False) as backup:
        backup_path = Path(backup.name)
    shutil.copy2(path, backup_path)
    separator = '\n' if original and not original.endswith('\n') else ''
    path.write_text(original + separator + '\n'.join(missing) + '\n', encoding='utf-8')
    print(f'已配置：{path}')
else:
    print('idea64.vmoptions 已包含指定参数，跳过修改。')
PY
}

install_idea() (
    local download_dir archive_path work download_work backup
    work=''
    download_work=''
    trap 'if [[ -n "$work" ]]; then rm -rf -- "$work"; fi; if [[ -n "$download_work" ]]; then rm -rf -- "$download_work"; fi' EXIT

    # 2.2 已安装同版本时复用程序，仍核对路径配置和应用菜单。
    if check_installation "$DESTINATION"; then
        printf 'IntelliJ IDEA %s 已安装，复用现有文件。\n' "$VERSION"
        configure_properties "$DESTINATION"
        configure_vmoptions "$DESTINATION"
        return
    fi

    # 2.3 获取系统下载目录，在其独立临时目录中下载官方校验文件与压缩包。
    download_dir="$(xdg-user-dir DOWNLOAD)"
    if [[ "$download_dir" != /* ]]; then
        printf '无法获取有效的下载目录。\n' >&2
        return 1
    fi
    mkdir -p "$download_dir" "$INSTALL_ROOT"
    archive_path="${download_dir}/${ARCHIVE}"
    download_work="$(mktemp -d "${download_dir}/.idea-download.XXXXXXXX")"
    curl --fail --location --retry 3 --proto '=https' --proto-redir '=https' \
        --output "${download_work}/${ARCHIVE}.sha256" "${DOWNLOAD_URL}.sha256"
    if [[ -f "$archive_path" ]]; then
        printf '检查下载目录中的现有压缩包：%s\n' "$archive_path"
    else
        if [[ -e "$archive_path" || -L "$archive_path" ]]; then
            printf '下载目标不是有效文件：%s\n' "$archive_path" >&2
            return 1
        fi
        printf '正在下载 IntelliJ IDEA %s……\n' "$VERSION"
        curl --fail --location --retry 3 --proto '=https' --proto-redir '=https' \
            --output "${download_work}/${ARCHIVE}" "$DOWNLOAD_URL"
        archive_path="${download_work}/${ARCHIVE}"
    fi
    # 2.4 按官方 SHA-256 校验压缩包，失败时停止，不覆盖已有安装。
    /usr/bin/python3 -I - "$archive_path" "${download_work}/${ARCHIVE}.sha256" <<'PY'
import hashlib
from pathlib import Path
import re
import sys

archive, checksum = map(Path, sys.argv[1:])
fields = checksum.read_text(encoding='utf-8').split()
if not fields or not re.fullmatch(r'[0-9a-fA-F]{64}', fields[0]):
    sys.exit('官方 SHA-256 文件格式无效。')
with archive.open('rb') as stream:
    actual = hashlib.file_digest(stream, 'sha256').hexdigest()
if actual != fields[0].lower():
    sys.exit(f'压缩包校验失败，请检查或移走后重新下载：{archive}')
print('SHA-256 校验通过。')
PY
    if [[ "$archive_path" != "${download_dir}/${ARCHIVE}" ]]; then
        mv -- "$archive_path" "${download_dir}/${ARCHIVE}"
    fi
    archive_path="${download_dir}/${ARCHIVE}"

    # 2.5 在全新目录内解压，移除包内顶层目录，核对产品版本和启动文件。
    work="$(mktemp -d "${INSTALL_ROOT}/.idea-install.XXXXXXXX")"
    tar -xzf "$archive_path" --strip-components=1 --no-same-owner -C "$work"
    if ! check_installation "$work"; then
        printf '解压后的 IDEA 产品、版本或必需文件不符合要求。\n' >&2
        return 1
    fi
    # 3. 写入指定数据路径和 JVM 参数，成功后备份替换已有程序目录。
    configure_properties "$work"
    configure_vmoptions "$work"
    if [[ -e "$DESTINATION" || -L "$DESTINATION" ]]; then
        backup="$(mktemp -d "${DESTINATION}.backup.XXXXXXXX")"
        mv -- "$DESTINATION" "${backup}/previous"
        printf '原安装已备份至：%s/previous\n' "$backup"
    fi
    mv -- "$work" "$DESTINATION"
    work=''
    printf '已安装到：%s\n压缩包保留在：%s\n' "$DESTINATION" "$archive_path"
)

create_desktop_entry() {
    # 4.1 创建当前用户的应用菜单入口，转义路径中的特殊字符。
    mkdir -p "${DATA_ROOT}/applications"
    /usr/bin/python3 -I - "$DESTINATION" "$DATA_ROOT" "$VERSION" <<'PY'
from pathlib import Path
import sys

root, data_root = map(Path, sys.argv[1:3])
version = sys.argv[3]

def value(text):
    return str(text).replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r')

def executable(text):
    text = str(text).replace('%', '%%')
    for char in ('\\', '"', '`', '$'):
        text = text.replace(char, '\\' + char)
    return value('"' + text + '"')

entry = '\n'.join([
    '[Desktop Entry]', 'Type=Application', f'Name=IntelliJ IDEA {version}',
    'Comment=Java 集成开发环境', f'Exec={executable(root / "bin/idea")} %f',
    f'Icon={value(root / "bin/idea.svg")}', 'Terminal=false',
    'Categories=Development;IDE;', 'StartupNotify=true', 'StartupWMClass=jetbrains-idea', '',
])
(Path(data_root) / 'applications/idea.desktop').write_text(entry, encoding='utf-8')
PY
    # 4.2 校验菜单文件并更新缓存，缓存更新失败时提示重新登录。
    if command -v desktop-file-validate >/dev/null 2>&1; then
        desktop-file-validate "${DATA_ROOT}/applications/idea.desktop"
    fi
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "${DATA_ROOT}/applications" || printf '应用菜单缓存更新失败，可重新登录后查看。\n' >&2
    fi
}

main() {
    # 1. 检查普通用户身份、依赖和官方安装包支持的平台。
    if [[ "${EUID}" -eq 0 ]]; then
        printf '请以普通用户运行，不要使用 sudo。\n' >&2
        return 1
    fi
    require_commands curl /usr/bin/python3 tar xdg-user-dir
    if [[ "$(uname -sm)" != 'Linux x86_64' ]]; then
        printf '当前 IDEA 安装包要求 Linux x86_64。\n' >&2
        return 1
    fi
    # 2. 下载、校验并安装程序；3. 配置 idea.properties 数据路径和 idea64.vmoptions 参数。
    install_idea
    # 4. 创建应用菜单入口。
    create_desktop_entry
    # 5. 打印完成提示，IDE 首次启动时创建配置、缓存、插件与日志目录。
    printf '\nIntelliJ IDEA %s 安装完成。\n' "$VERSION"
    printf '可从应用菜单启动，或运行："%s/bin/idea"\n' "$DESTINATION"
    printf '数据目录：/home/frankchan/文档/.AppCaK/DevCac/JetBrains/idea/\n'
}

main "$@"
