# Snipaste 在 GNOME Wayland 下开机后没有托盘图标：修复记录与重装指南

记录日期：2026-10-26。

## 给以后协助修复的助手

先阅读本文并检查当前安装路径、桌面环境、托盘扩展和自启动来源。本文记录的是已经验证有效的处理方式：**等待 StatusNotifier 托盘服务报告就绪，再启动 Snipaste**。按当前机器的实际路径调整配置，不要直接照搬旧版本的安装目录；修改前先备份现有文件。

此问题不需要卸载 GNOME“帮助”，也不需要修改截图权限。不要把“程序在运行、快捷键可用”当作托盘正常的证据，应检查托盘注册列表中是否存在 Snipaste 进程对应的条目。

## 1. 适用现象与已验证环境

现象：重启登录后，Snipaste 已运行，截图快捷键可以触发，但托盘图标不显示。退出 Snipaste，等托盘扩展启动后重新打开，图标恢复。

本次环境：

- Debian GNU/Linux 13，GNOME Shell 48.7，Wayland。
- Snipaste 2.11.3，用户目录安装。
- Status Tray 扩展：`status-tray@keithvassallo.com`，版本 2.8（33）。
- Snipaste 自启动文件：`~/.config/autostart/snipaste.desktop`。
- 当时的 Snipaste 启动器：`/home/frankchan/.local/opt/snipaste-2.11.3-r2g1825y/squashfs-root/AppRun`。

本次观察到：Snipaste 在登录初期直接启动，托盘扩展随后处于 ACTIVE 状态，但 `RegisteredStatusNotifierItems` 中没有 Snipaste。改用等待脚本重启程序后，列表新增条目的 D-Bus 连接 PID 与 Snipaste PID 一致。

验证范围：已验证当前登录中重新启动后注册成功；写本文时尚未验证修改后的下一次系统重启。托盘扩展自身若没有启用或发生故障，需要先处理扩展问题。

## 2. 修复前检查

以下命令均为只读检查：

```bash
printenv XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
pgrep -ax Snipaste
gnome-extensions info status-tray@keithvassallo.com
```

查看托盘服务：

```bash
gdbus introspect --session \
  --dest org.kde.StatusNotifierWatcher \
  --object-path /StatusNotifierWatcher \
  --only-properties
```

正常时应包含：

```text
IsStatusNotifierHostRegistered = true
RegisteredStatusNotifierItems = [...]
```

如果扩展未安装或未启用，先安装适配当前 GNOME 版本的 Status Tray 并启用。若改用其他托盘扩展，应确认它同样提供 `org.kde.StatusNotifierWatcher` 接口，不能只依赖本文中的扩展名称。

查看已有启动入口：

```bash
rg -n -i 'snipaste' \
  "$HOME/.config/autostart" \
  "$HOME/.config/systemd/user" \
  /etc/xdg/autostart

systemctl --user list-units --all --no-pager '*snipaste*'
```

某个搜索目录不存在时，`rg` 报该路径不存在不影响其余检查。确认只有一套开机启动机制，避免多个入口同时启动。

## 3. 确认当前安装路径

先查看菜单和自启动文件中的 `Exec=`：

```bash
rg -n '^Exec=' \
  "$HOME/.local/share/applications/snipaste.desktop" \
  "$HOME/.config/autostart/snipaste.desktop"
```

本文使用解压后 AppImage 的 `AppRun`。重装后应改成实际存在、可执行的启动器路径；也可以使用已赋予执行权限的 AppImage 路径。

本次路径仅供对照：

```text
/home/frankchan/.local/opt/snipaste-2.11.3-r2g1825y/squashfs-root/AppRun
```

检查 Python 的 GObject 绑定：

```bash
/usr/bin/python3 -I -c 'from gi.repository import Gio, GLib; print("Gio / GLib OK")'
```

如果 Debian/Ubuntu 上缺少这个依赖，再安装：

```bash
sudo apt-get install python3-gi
```

## 4. 创建等待托盘就绪的启动脚本

目标文件：`~/.local/bin/snipaste-start`。

如果该文件已经存在，先阅读内容并备份，再决定更新，不要直接覆盖其他脚本。创建父目录：

```bash
mkdir -p "$HOME/.local/bin"
```

将下面内容保存到该文件，**把 `APP` 改成当前机器实际的 Snipaste 启动器绝对路径**：

```python
#!/usr/bin/python3 -I
import os
import sys
import time

from gi.repository import Gio, GLib

APP = '/home/frankchan/.local/opt/snipaste-2.11.3-r2g1825y/squashfs-root/AppRun'
WATCHER = 'org.kde.StatusNotifierWatcher'
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
deadline = time.monotonic() + 90

while time.monotonic() < deadline:
    try:
        reply = bus.call_sync(
            WATCHER,
            '/StatusNotifierWatcher',
            'org.freedesktop.DBus.Properties',
            'Get',
            GLib.Variant('(ss)', (WATCHER, 'IsStatusNotifierHostRegistered')),
            GLib.VariantType.new('(v)'),
            Gio.DBusCallFlags.NO_AUTO_START,
            1000,
            None,
        )
        if reply.unpack()[0] is True:
            os.execv(APP, [APP, *sys.argv[1:]])
    except GLib.Error:
        pass
    time.sleep(0.5)

print('Snipaste: status tray did not become ready within 90 seconds; startup skipped.', file=sys.stderr)
sys.exit(1)
```

设置执行权限：

```bash
chmod 755 "$HOME/.local/bin/snipaste-start"
```

脚本每 0.5 秒检查一次托盘宿主注册状态，就绪后立即启动。它设置了 90 秒的等待期限，每次 D-Bus 调用最多等待 1 秒，因此总耗时可能略超过 90 秒。超时会报错并放弃本次启动，不会在托盘未就绪时继续打开 Snipaste。

`NO_AUTO_START` 用来探测现有服务，不会主动拉起未知托盘后端。`os.execv` 直接将等待进程替换成 Snipaste 启动器，保留桌面启动时的进程归属，有助于保持截图门户识别的应用身份稳定。

## 5. 修改开机启动入口

修改对象是：

```text
~/.config/autostart/snipaste.desktop
```

先查看当前文件并备份。下面的备份名带时间，避免覆盖旧备份：

```bash
mkdir -p "$HOME/.local/state/snipaste"
cp -a -- "$HOME/.config/autostart/snipaste.desktop" \
  "$HOME/.local/state/snipaste/autostart-before-tray-wait-$(date +%Y%m%d-%H%M%S).desktop.bak"
```

如果重装后还没有自启动文件，可先从当前安装好的应用菜单入口复制：

```bash
mkdir -p "$HOME/.config/autostart"
cp -a -- "$HOME/.local/share/applications/snipaste.desktop" \
  "$HOME/.config/autostart/snipaste.desktop"
```

随后把自启动文件的 `Exec=` 改为等待脚本的**绝对路径**。当前用户的修改结果是：

```ini
Exec=/home/frankchan/.local/bin/snipaste-start
```

`.desktop` 文件的 `Exec=` 不会按 shell 规则展开 `~` 或 `$HOME`，不能写成 `Exec=~/.local/bin/snipaste-start` 或 `Exec=$HOME/.local/bin/snipaste-start`。

保留现有名称、图标等字段。确认没有 `Hidden=true`、`X-GNOME-Autostart-enabled=false` 或不适用的 `OnlyShowIn` 条件阻止启动。菜单入口和自启动入口继续使用 `snipaste.desktop` 这个文件名，不必为了此修复重命名。

如果系统安装了校验工具，检查文件：

```bash
desktop-file-validate "$HOME/.config/autostart/snipaste.desktop"
```

原文件中的 `Categories=Graphics;ImageProcessing;` 可能产生 category hint，这不属于启动失败。

本次没有修改 `~/.local/share/applications/snipaste.desktop`，也没有修改 `Ctrl + F1` 的 GNOME 自定义快捷键。等待脚本只接管开机自启动。

## 6. 验证修复

优先重启或注销再登录，确认托盘图标和截图快捷键都正常。当前登录也可先从 Snipaste 菜单正常退出，等旧进程退出后，用下面命令测试。

为了测试时保持门户识别为 `snipaste`，使用符合桌面应用命名规则的 systemd scope：

```bash
systemd-run --user --scope --collect \
  --unit=app-snipaste-traycheck \
  "$HOME/.local/bin/snipaste-start"
```

此命令会随 Snipaste 持续运行，不需要等待命令退出才能在另一个终端检查。不要反复执行启动命令；先确认旧实例已经退出。

查看托盘注册列表：

```bash
gdbus call --session \
  --dest org.kde.StatusNotifierWatcher \
  --object-path /StatusNotifierWatcher \
  --method org.freedesktop.DBus.Properties.Get \
  org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems
```

以下只读检查脚本可以自动匹配注册条目的 PID，确认 Snipaste 确实注册：

```bash
/usr/bin/python3 -I - <<'PY'
import subprocess
from gi.repository import Gio, GLib

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
pids = set(subprocess.run(
    ['pgrep', '-x', 'Snipaste'],
    capture_output=True, text=True,
).stdout.split())

reply = bus.call_sync(
    'org.kde.StatusNotifierWatcher',
    '/StatusNotifierWatcher',
    'org.freedesktop.DBus.Properties',
    'Get',
    GLib.Variant('(ss)', (
        'org.kde.StatusNotifierWatcher', 'RegisteredStatusNotifierItems',
    )),
    GLib.VariantType.new('(v)'),
    Gio.DBusCallFlags.NO_AUTO_START,
    2000,
    None,
)

found = False
for item in reply.unpack()[0]:
    dest = item.split('/')[0]
    try:
        result = bus.call_sync(
            'org.freedesktop.DBus', '/org/freedesktop/DBus',
            'org.freedesktop.DBus', 'GetConnectionUnixProcessID',
            GLib.Variant('(s)', (dest,)),
            GLib.VariantType.new('(u)'),
            Gio.DBusCallFlags.NONE, 2000, None,
        )
    except GLib.Error:
        continue
    pid = str(result.unpack()[0])
    if pid in pids:
        print('Snipaste 已注册到托盘:', item, 'PID:', pid)
        found = True

if not found:
    raise SystemExit('未找到 Snipaste 对应的托盘注册条目')
PY
```

本次测试成功的注册条目为 `:1.144/StatusNotifierItem`，对应 Snipaste PID `5507`。这些编号每次登录都可能变化，不要硬编码。

若已注册但图标仍不可见，应检查扩展的隐藏图标、溢出区、应用过滤和图标颜色等设置，不能继续认定为启动时机问题。

## 7. 故障检查与相关问题边界

查看本次启动相关日志：

```bash
journalctl --user -b --no-pager \
  --grep='snipaste|Snipaste|status-tray|Status Tray' -n 100
```

Snipaste 自身日志通常位于：

```text
~/.snipaste/splog.txt
```

如果等待脚本超时，检查扩展是否 ACTIVE、D-Bus 服务是否存在、`IsStatusNotifierHostRegistered` 是否为 true，以及 `APP` 路径是否有效。

如果升级 Snipaste 后更换安装目录，需要同步更新等待脚本的 `APP`，并检查菜单入口和截图快捷键中是否仍引用旧路径。

截图授权与托盘注册是不同配置。当前系统截图门户曾保存 `snipaste: ['yes']`，可用下列只读命令检查：

```bash
gdbus call --session \
  --dest org.freedesktop.impl.portal.PermissionStore \
  --object-path /org/freedesktop/impl/portal/PermissionStore \
  --method org.freedesktop.impl.portal.PermissionStore.Lookup \
  screenshot screenshot
```

从不同启动方式运行应用，可能改变门户识别的应用身份。为避免无谓的授权变化，正式使用保留原来的桌面入口；本指南不修改或放宽截图权限。

## 8. 回滚

恢复修改前的自启动文件即可停止使用等待逻辑。本次实际保留的原文件是：

```text
/home/frankchan/.local/state/snipaste/autostart-before-tray-wait.desktop.bak
```

本次机器上的恢复命令：

```bash
cp -a -- \
  /home/frankchan/.local/state/snipaste/autostart-before-tray-wait.desktop.bak \
  /home/frankchan/.config/autostart/snipaste.desktop
```

重装后的备份若使用了带时间的文件名，应改成对应的真实备份路径。确认自启动文件不再引用等待脚本后，可删除：

```bash
rm -- "$HOME/.local/bin/snipaste-start"
```

回滚不需要删除 Snipaste 配置、截图历史或修改 GNOME 快捷键。

## 9. 重装前保存

请把本文复制到独立备份盘或其他重装后仍能访问的位置。文档保存在当前系统的用户目录，格式化用户分区会丢失。

重装后可直接向助手引用此文件并提出：

> 按这份文档检查并修复 Snipaste 的 GNOME Wayland 开机托盘图标问题。先核实当前安装路径和托盘扩展，备份后应用等待托盘就绪的自启动方案，并验证注册条目的 PID 属于 Snipaste。
