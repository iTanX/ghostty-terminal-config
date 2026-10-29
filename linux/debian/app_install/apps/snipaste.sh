#!/usr/bin/env bash
# 安装 Snipaste，并配置应用菜单及 Ctrl + F1 截图快捷键；可独立运行。
set -euo pipefail

INSTALL_ROOT="${HOME}/.local/opt"
DATA_ROOT="${XDG_DATA_HOME:-${HOME}/.local/share}"
MANUAL_STEPS=()

require_commands() {
    local command_name
    for command_name in "$@"; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            printf '缺少必需命令：%s，请安装后重新运行。\n' "$command_name" >&2
            return 1
        fi
    done
}

# 在独立目录内下载、解包，成功后再放入正式位置，无需 FUSE。
install_appimage() (
    local name="$1" version="$2" url="$3"
    local destination="${INSTALL_ROOT}/${name}"
    local archive="${name}-${version}-x86_64.AppImage"
    local work backup

    # 2.1 检查同版本安装，存在时复用程序，后续仍检查菜单和快捷键。
    if [[ -x "${destination}/app/AppRun" && -f "${destination}/${archive}" ]]; then
        printf '%s %s 已安装，复用现有文件。\n' "$name" "$version"
        return
    fi

    # 2.2 在新建的独立临时目录下载官方安装包，退出时清理临时文件。
    mkdir -p "$INSTALL_ROOT"
    work="$(mktemp -d "${INSTALL_ROOT}/.install.XXXXXXXX")"
    trap 'rm -rf -- "$work"' EXIT
    mkdir "${work}/package"
    printf '正在下载 %s %s……\n' "$name" "$version"
    curl --fail --location --retry 3 --proto '=https' --proto-redir '=https' \
        --output "${work}/package/${archive}" "$url"
    # 2.3 执行 AppImage 的解包模式，无需 FUSE；解包失败时输出日志并终止。
    chmod u+x "${work}/package/${archive}"
    if ! (cd "${work}/package" && "./${archive}" --appimage-extract >"${work}/extract.log" 2>&1); then
        printf '解包失败：\n' >&2
        /usr/bin/python3 -I -c 'import pathlib, sys; print(pathlib.Path(sys.argv[1]).read_text(errors="replace"), end="")' "${work}/extract.log" >&2
        return 1
    fi
    # 2.4 统一解包目录名称，确认启动入口存在且可执行，再操作正式安装目录。
    mv "${work}/package/squashfs-root" "${work}/package/app"
    test -x "${work}/package/app/AppRun"

    # 2.5 备份已有安装目录，再放入新版本，避免升级或重装时丢失配置。
    if [[ -e "$destination" || -L "$destination" ]]; then
        backup="$(mktemp -d "${destination}.backup.XXXXXXXX")"
        mv -- "$destination" "${backup}/previous"
        printf '原安装已备份至：%s/previous\n' "$backup"
    fi
    mv -- "${work}/package" "$destination"
    printf '已安装到：%s\n' "$destination"
)

create_desktop_entry() {
    local name="$1" description="$2" launcher="$3" icon="$4"
    mkdir -p "${DATA_ROOT}/applications"
    # 3.1 写入当前用户的应用菜单入口，按 desktop 格式转义路径中的特殊字符。
    /usr/bin/python3 -I - "$name" "$description" "$launcher" "$icon" "$DATA_ROOT" <<'PY'
from pathlib import Path
import sys

name, description, launcher, icon, data_root = sys.argv[1:]

def value(text):
    return text.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '\\r')

def executable(text):
    text = text.replace('%', '%%')
    for char in ('\\', '"', '`', '$'):
        text = text.replace(char, '\\' + char)
    return value('"' + text + '"')

entry = '\n'.join([
    '[Desktop Entry]', 'Type=Application', f'Name={value(name)}',
    f'Comment={value(description)}', f'Exec={executable(launcher)}',
    f'Icon={value(icon)}', 'Terminal=false', 'Categories=Utility;',
    'StartupNotify=false', '',
])
path = Path(data_root) / 'applications' / f'{name}.desktop'
path.write_text(entry, encoding='utf-8')
PY
    # 3.2 系统提供校验工具时，检查生成的菜单文件是否符合格式要求。
    if command -v desktop-file-validate >/dev/null 2>&1; then
        desktop-file-validate "${DATA_ROOT}/applications/${name}.desktop"
    fi
}

# 仅设置 GNOME 自定义快捷键；保留其他条目，遇到按键冲突则交给用户处理。
configure_shortcut() {
    local name="$1" command_line="$2" binding="$3"
    /usr/bin/python3 -I - "$name" "$command_line" "$binding" <<'PY'
import os
import sys

name, command, binding = sys.argv[1:]
try:
    # 4.1 检查桌面环境、GSettings 组件及写入权限，不支持时交给人工配置。
    if 'gnome' not in os.environ.get('XDG_CURRENT_DESKTOP', '').lower():
        raise RuntimeError('当前桌面不是 GNOME')
    from gi.repository import Gio

    source = Gio.SettingsSchemaSource.get_default()
    parent_id = 'org.gnome.settings-daemon.plugins.media-keys'
    child_id = parent_id + '.custom-keybinding'
    if not source or not all(source.lookup(s, True) for s in (parent_id, child_id)):
        raise RuntimeError('缺少 GNOME 快捷键设置组件')
    parent = Gio.Settings.new(parent_id)
    if not parent.is_writable('custom-keybindings'):
        raise RuntimeError('系统不允许修改自定义快捷键')
    paths = list(parent.get_strv('custom-keybindings'))
    children = [(p, Gio.Settings.new_with_path(child_id, p)) for p in paths]

    def normalized(key):
        return key.lower().replace('<primary>', '<control>').replace('<ctrl>', '<control>')

    # 4.2 复用同一截图命令的条目，检查其他自定义快捷键是否占用目标按键。
    selected = None
    for path, settings in children:
        if settings.get_string('command') == command:
            selected = (path, settings)
        elif normalized(settings.get_string('binding')) == normalized(binding):
            raise RuntimeError(f'快捷键已被其他自定义命令占用：{settings.get_string("name")}')

    # 4.3 检查 GNOME 内置快捷键，发现冲突时保留原配置，不抢占按键。
    schemas, _ = source.list_schemas(True)
    for schema_id in schemas:
        if not (schema_id.endswith('.keybindings') or schema_id == parent_id):
            continue
        schema = source.lookup(schema_id, True)
        settings = Gio.Settings.new(schema_id)
        for key in schema.list_keys():
            value = settings.get_value(key)
            if value.get_type_string() == 'as':
                if any(normalized(item) == normalized(binding) for item in value.unpack()):
                    raise RuntimeError(f'快捷键已被系统设置占用：{schema_id} / {key}')

    # 4.4 没有可复用条目时分配空闲路径；只更新当前命令，保留其他条目。
    if selected is None:
        index = 0
        base = '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/'
        while f'{base}custom{index}/' in paths:
            index += 1
        path = f'{base}custom{index}/'
        selected = (path, Gio.Settings.new_with_path(child_id, path))
    path, settings = selected
    if not all(settings.is_writable(k) for k in ('name', 'command', 'binding')):
        raise RuntimeError('系统不允许修改该快捷键')
    settings.delay()
    for key, text in (('name', name), ('command', command), ('binding', binding)):
        if not settings.set_string(key, text):
            raise RuntimeError(f'无法写入快捷键字段：{key}')
    settings.apply()
    if path not in paths and not parent.set_strv('custom-keybindings', paths + [path]):
        raise RuntimeError('无法注册快捷键')
    # 4.5 提交设置并读取验证，失败则返回非零状态，供调用方生成手动步骤。
    Gio.Settings.sync()
    if path not in parent.get_strv('custom-keybindings') or settings.get_string('binding') != binding:
        raise RuntimeError('快捷键写入后验证失败')
    print(f'已配置快捷键：{name} → {binding}')
except Exception as error:
    print(f'无法自动配置快捷键：{error}', file=sys.stderr)
    sys.exit(1)
PY
}

install_snipaste() {
    local name='Snipaste' version='2.11.3'
    local url='https://download.snipaste.com/archives/Snipaste-2.11.3-x86_64.AppImage'
    local launcher="${INSTALL_ROOT}/${name}/app/AppRun"
    local shortcut_command
    # 1.2 检查官方安装包要求的平台与架构，不匹配时停止安装。
    if [[ "$(uname -sm)" != 'Linux x86_64' ]]; then
        printf '%s 的当前软件包要求 Linux x86_64。\n' "$name" >&2
        return 1
    fi
    # 2 安装程序：检查版本、下载、解包、校验，并备份替换已有安装。
    install_appimage "$name" "$version" "$url"
    # 3 创建应用菜单入口，用户可以从桌面应用列表启动程序。
    create_desktop_entry "$name" '截图与贴图工具' "$launcher" "${INSTALL_ROOT}/${name}/app/Snipaste.png"
    # 4 通过系统快捷键调用 snip，绕过 Wayland 下应用自身的全局快捷键限制。
    shortcut_command="$(/usr/bin/python3 -I -c 'import shlex, sys; print(shlex.quote(sys.argv[1]) + " snip")' "$launcher")"
    if ! configure_shortcut 'Snipaste 截图' "$shortcut_command" '<Control>F1'; then
        # 4.6 自动配置不可用时收集人工步骤，安装完成后统一打印。
        MANUAL_STEPS+=("在系统设置 → 键盘 → 自定义快捷键中添加：
  名称：Snipaste 截图
  命令：${shortcut_command}
  快捷键：Ctrl + F1（如被占用，请先解除原绑定）")
    fi
    printf '使用提示：先从应用菜单启动 Snipaste 并保持后台运行，再按 Ctrl + F1 截图。\n'
}

main() {
    # 1 检查安装前提，确认以普通用户运行且具备所需工具。
    # 1.1 拒绝 root，并检查下载工具及系统 Python。
    if [[ "${EUID}" -eq 0 ]]; then
        printf '请以普通用户运行，不要使用 sudo。\n' >&2
        return 1
    fi
    require_commands curl /usr/bin/python3
    install_snipaste

    # 5 完成安装后的桌面集成，并打印结果和需要手动处理的步骤。
    # 5.1 更新菜单缓存；缓存更新失败时提示重新登录，不误报程序安装失败。
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "${DATA_ROOT}/applications" || printf '应用菜单缓存更新失败，可重新登录后查看。\n' >&2
    fi
    # 5.2 明确报告安装完成，最后列出本次未能自动完成的配置。
    printf '\nSnipaste 安装完成。\n'
    if ((${#MANUAL_STEPS[@]})); then
        printf '\n以下步骤需要手动处理：\n'
        printf '%s\n' "${MANUAL_STEPS[@]}"
    fi
}

main "$@"
