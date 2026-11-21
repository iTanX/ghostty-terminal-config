#!/usr/bin/env bash
# 为 Gear Lever 集成的 Snipaste 设置 GNOME 的 Ctrl + F1 截图快捷键。
set -euo pipefail

find_shortcut_command() {
    /usr/bin/python3 -I - <<'PY'
from configparser import ConfigParser, Error
from pathlib import Path
import os
import shlex
import sys

# 2.1 从 Gear Lever 生成的菜单入口读取 AppImage 的实际路径。
applications = Path.home() / '.local' / 'share' / 'applications'
launchers = set()
for desktop_file in applications.glob('*.desktop'):
    parser = ConfigParser(interpolation=None)
    try:
        parser.read(desktop_file, encoding='utf-8')
    except (Error, UnicodeError):
        continue
    if not parser.has_section('Desktop Entry'):
        continue
    entry = parser['Desktop Entry']
    if entry.get('X-AppImage-Name', '').casefold() != 'snipaste':
        continue
    launcher = Path(entry.get('TryExec', ''))
    if launcher.is_absolute() and launcher.is_file() and os.access(launcher, os.X_OK):
        launchers.add(launcher)

# 2.2 确认只有一个可用的启动路径，再生成截图命令。
if not launchers:
    sys.exit('未找到可执行的 Snipaste AppImage，请先在 Gear Lever 中集成 Snipaste。')
if len(launchers) > 1:
    sys.exit('找到多个 Snipaste AppImage，请在 Gear Lever 中保留要绑定的版本后重试。')
print(shlex.join([str(launchers.pop()), 'snip']))
PY
}

configure_shortcut() {
    local name="$1" command_line="$2" binding="$3"
    /usr/bin/python3 -I - "$name" "$command_line" "$binding" <<'PY'
import os
import sys

name, command, binding = sys.argv[1:]
try:
    # 3.1 检查 GNOME 会话及快捷键设置权限。
    if 'gnome' not in os.environ.get('XDG_CURRENT_DESKTOP', '').lower():
        raise RuntimeError('当前桌面不是 GNOME')
    try:
        from gi.repository import Gio
    except ImportError as error:
        raise RuntimeError('缺少 python-gobject') from error

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

    # 3.2 复用已有的 Snipaste 条目，并检查自定义快捷键冲突。
    selected = None
    for path, settings in children:
        current_name = settings.get_string('name')
        if settings.get_string('command') == command or current_name == name:
            if selected is not None:
                raise RuntimeError('已有多个 Snipaste 截图快捷键，请手动确认要使用的条目')
            selected = (path, settings)
        elif normalized(settings.get_string('binding')) == normalized(binding):
            raise RuntimeError(f'快捷键已被其他自定义命令占用：{current_name}')

    # 3.3 检查 GNOME 内置快捷键冲突。
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

    # 3.4 写入截图命令及按键，提交后读取验证。
    if selected is None:
        index = 0
        base = '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/'
        while f'{base}custom{index}/' in paths:
            index += 1
        path = f'{base}custom{index}/'
        selected = (path, Gio.Settings.new_with_path(child_id, path))
    path, settings = selected
    values = {'name': name, 'command': command, 'binding': binding}
    if not all(settings.is_writable(key) for key in values):
        raise RuntimeError('系统不允许修改该快捷键')
    settings.delay()
    for key, text in values.items():
        if not settings.set_string(key, text):
            raise RuntimeError(f'无法写入快捷键字段：{key}')
    settings.apply()
    if path not in paths and not parent.set_strv('custom-keybindings', paths + [path]):
        raise RuntimeError('无法注册快捷键')
    Gio.Settings.sync()
    if path not in parent.get_strv('custom-keybindings') or any(
        settings.get_string(key) != text for key, text in values.items()
    ):
        raise RuntimeError('快捷键写入后验证失败')
    print(f'已配置快捷键：{name} → {binding}')
except Exception as error:
    print(f'无法自动配置快捷键：{error}', file=sys.stderr)
    sys.exit(1)
PY
}

main() {
    local shortcut_command

    # 1. 检查运行身份及系统 Python。
    if [[ "${EUID}" -eq 0 ]]; then
        printf '请以普通用户运行，不要使用 sudo。\n' >&2
        return 1
    fi
    if [[ ! -x /usr/bin/python3 ]]; then
        printf '缺少 /usr/bin/python3，请安装 Python 后重新运行。\n' >&2
        return 1
    fi

    # 2. 查找已集成的 Snipaste 并生成截图命令。
    shortcut_command="$(find_shortcut_command)"

    # 3. 配置截图快捷键。
    if ! configure_shortcut 'Snipaste 截图' "$shortcut_command" '<Control>F1'; then
        # 3.5 打印手动配置步骤。
        printf '\n在系统设置 → 键盘 → 自定义快捷键中编辑或添加：\n'
        printf '  名称：Snipaste 截图\n  命令：%s\n  快捷键：Ctrl + F1（如被占用，请先解除原绑定）\n' "$shortcut_command"
    fi
    printf '使用提示：先从应用菜单启动 Snipaste 并保持后台运行，再按 Ctrl + F1 截图。\n'
}

main "$@"
