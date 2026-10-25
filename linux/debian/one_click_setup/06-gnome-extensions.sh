#!/usr/bin/env bash

# ==============================================================================
# 准备配置
# ==============================================================================
set -euo pipefail

progress() {
    printf '\n==> %s\n' "$1"
}

# 1. 检查运行环境
if [ "$(id -u)" -eq 0 ]; then
    echo "错误：请使用普通用户在 GNOME 桌面终端运行，不要使用 sudo 执行整个脚本。" >&2
    exit 1
fi

. /etc/os-release
if [ "${ID:-}" != debian ] || [ "${VERSION_ID:-}" != 13 ]; then
    echo "错误：本脚本仅支持 Debian 13。" >&2
    exit 1
fi

for cmd in sudo gnome-shell gnome-extensions gsettings; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "错误：未找到 $cmd，请先安装该依赖。" >&2
        exit 1
    fi
done

GNOME_VERSION="$(gnome-shell --version)"
GNOME_MAJOR="${GNOME_VERSION##* }"
GNOME_MAJOR="${GNOME_MAJOR%%.*}"
if [[ ! "$GNOME_MAJOR" =~ ^[0-9]+$ ]]; then
    echo "错误：无法识别 GNOME Shell 版本：$GNOME_VERSION" >&2
    exit 1
fi

EXTENSION_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions"
EXTENSIONS=(
    # 任务栏和 Shell 主题。
    dash-to-panel@jderose9.github.com
    user-theme@gnome-shell-extensions.gcampax.github.com
    # 窗口平铺、剪贴板和背景模糊。
    tiling-assistant@leleat-on-github
    clipboard-indicator@tudmotu.com
    blur-my-shell@aunetx
    # 防休眠和应用托盘。
    caffeine@patapon.info
    status-tray@keithvassallo.com
)
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# ==============================================================================
# 安装扩展管理器
# ==============================================================================
# 1. 刷新软件索引
progress "GNOME 扩展 / 刷新软件索引"
sudo apt-get update

# 2. 安装依赖
sudo apt-get install -y ca-certificates python3 libglib2.0-bin

# 3. 安装扩展管理器
progress "GNOME 扩展 / 安装扩展管理器"
sudo apt-get install -y gnome-shell-extension-manager

# ==============================================================================
# 安装 GNOME 扩展
# ==============================================================================
# 1. 检查兼容性并安装扩展
for uuid in "${EXTENSIONS[@]}"; do
    progress "GNOME 扩展 / 安装 $uuid"
    # 兼容的已有扩展直接复用；新安装包校验 UUID 和 Shell 版本后再安装。
    python3 -I - "$uuid" "$GNOME_MAJOR" "$EXTENSION_DIR" "$TMP_DIR" <<'PY'
import json
from pathlib import Path
from shutil import copyfileobj
import subprocess
import sys
from urllib.parse import urlencode
from urllib.request import urlopen
from zipfile import ZipFile

uuid, major, destination, temporary = sys.argv[1:]

def compatible(metadata):
    return metadata.get('uuid') == uuid and major in metadata.get('shell-version', [])

for base in (Path(destination), Path('/usr/share/gnome-shell/extensions')):
    metadata_file = base / uuid / 'metadata.json'
    if metadata_file.is_file():
        metadata = json.loads(metadata_file.read_text())
        if compatible(metadata):
            print(f"已安装且兼容 GNOME {major}，跳过下载。")
            sys.exit(0)
        # 用户目录中的同名扩展优先于系统扩展，需替换不兼容版本。
        break

base = 'https://extensions.gnome.org'
query = urlencode({'uuid': uuid, 'shell_version': major})
with urlopen(base + '/extension-info/?' + query, timeout=30) as response:
    info = json.load(response)
path = info.get('download_url', '')
if info.get('uuid') != uuid or not path.startswith('/download-extension/'):
    sys.exit(f'错误：GNOME 官方目录未返回 {uuid} 的兼容下载地址。')
archive = Path(temporary) / (uuid + '.zip')
with urlopen(base + path, timeout=120) as response, archive.open('wb') as output:
    copyfileobj(response, output)
with ZipFile(archive) as bundle:
    metadata = json.loads(bundle.read('metadata.json'))
if not compatible(metadata):
    sys.exit(f'错误：下载的扩展 UUID 或 GNOME {major} 兼容信息不匹配：{uuid}')
subprocess.run(['gnome-extensions', 'install', '--force', str(archive)], check=True)
PY
done

# 2. 保存扩展启用设置
progress "GNOME 扩展 / 保存启用设置"
python3 -I - "${EXTENSIONS[@]}" <<'PY'
import ast
import json
import subprocess
import sys

extensions = sys.argv[1:]

def get(key):
    value = subprocess.check_output(
        ['gsettings', 'get', 'org.gnome.shell', key], text=True).strip()
    if value in ('true', 'false'):
        return value == 'true'
    return ast.literal_eval(value.removeprefix('@as '))

# 保留其他扩展的状态，仅添加本脚本管理的扩展并解除它们的禁用状态。
for key in ('enabled-extensions', 'disabled-extensions'):
    values = get(key)
    if key == 'enabled-extensions':
        values += [uuid for uuid in extensions if uuid not in values]
    else:
        values = [uuid for uuid in values if uuid not in extensions]
    subprocess.run(['gsettings', 'set', 'org.gnome.shell', key, json.dumps(values)], check=True)
    if get(key) != values:
        sys.exit('错误：无法保存扩展启用设置，请在当前用户的 GNOME 桌面终端运行。')
subprocess.run(['gsettings', 'set', 'org.gnome.shell', 'disable-user-extensions', 'false'], check=True)
if get('disable-user-extensions'):
    sys.exit('错误：无法打开 GNOME 用户扩展开关。')
PY

# 3. 尝试在当前桌面启用扩展
for uuid in "${EXTENSIONS[@]}"; do
    if ! gnome-extensions enable "$uuid"; then
        printf '已保存 %s 的启用设置，注销并重新登录后加载。\n' "$uuid"
    fi
done

# ==============================================================================
# 完成配置
# ==============================================================================
printf '\n扩展管理器和 GNOME 扩展已安装，启用设置已保存。请注销并重新登录以加载新安装的扩展。\n'
