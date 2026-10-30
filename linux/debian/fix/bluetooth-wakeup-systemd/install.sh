#!/usr/bin/env bash
# 配置 LL Privacy，安装并启用每次睡眠前执行的蓝牙唤醒权限修复服务。
# 安装时重新初始化蓝牙控制器，会暂时断开已连接的键鼠和音响。
set -euo pipefail
package_dir=$(dirname -- "$(readlink -f -- "$0")")
# 安装阶段允许每次控制器操作最多等待 5 秒，不影响睡眠前服务的超时设置。
readonly ADAPTER_TIMEOUT_SECONDS=5
# BlueZ 服务就绪与控制器对象注册是异步的，为对象重新出现预留有限等待时间。
readonly ADAPTER_READY_BUDGET_SECONDS=20
readonly ADAPTER_RETRY_INTERVAL_SECONDS=1

# 第 1 步：获取管理员权限，检查依赖工具、配套文件和 Python 语法。
if (( EUID != 0 )); then
    exec sudo /bin/bash "$package_dir/install.sh" "$@"
fi
for tool in python3 busctl systemctl systemd-analyze install; do
    command -v "$tool" >/dev/null || { printf '缺少工具：%s\n' "$tool" >&2; exit 1; }
done
test -f "$package_dir/fix-bluetooth-wakeup.py"
test -f "$package_dir/fix-bluetooth-wakeup.service"
/usr/bin/python3 -I - "$package_dir/fix-bluetooth-wakeup.py" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
compile(path.read_text(), str(path), "exec")
PY

# 第 2 步：在 [General] 段合并 LL Privacy 的 KernelExperimental UUID。
# 保留已有配置；修改前在 /etc/bluetooth/ 生成带时间戳的 main.conf 备份。
/usr/bin/python3 -I - /etc/bluetooth/main.conf "$package_dir/fix-bluetooth-wakeup.py" <<'PY'
from datetime import datetime
from pathlib import Path
import os
import re
import runpy
import shutil
import sys
import tempfile

path = Path(sys.argv[1])
# 复用脚本中的协议常量；执行模块定义，不调用权限设置入口。
LL_PRIVACY_UUID = runpy.run_path(sys.argv[2])["LL_PRIVACY_UUID"]
lines = path.read_text().splitlines(keepends=True)
sections = [(i, match.group(1).strip()) for i, line in enumerate(lines)
            if (match := re.match(r"\s*\[([^]]+)\]\s*(?:[#;].*)?$", line))]
general = [i for i, name in sections if name == "General"]
if len(general) != 1:
    sys.exit("需要唯一的 [General] 段；请检查 main.conf。")
start = general[0]
end = next((i for i, _ in sections if i > start), len(lines))
keys = [i for i in range(start + 1, end)
        if re.match(r"\s*KernelExperimental\s*=", lines[i])]
if len(keys) > 1:
    sys.exit("KernelExperimental 重复，请先整理配置。")
if keys:
    index = keys[0]
    raw = lines[index].split("=", 1)[1].strip()
    parts = re.split(r"\s+([#;].*)", raw, maxsplit=1)
    value = parts[0].strip()
    comment = " " + parts[1] if len(parts) > 1 else ""
    if value.lower() == "true":
        print("保留 KernelExperimental=true，已包含 LL Privacy。")
        sys.exit(0)
    entries = [] if value.lower() in ("false", "") else [x.strip() for x in value.split(",") if x.strip()]
    if LL_PRIVACY_UUID in [x.lower() for x in entries]:
        print("LL Privacy 已配置，无需修改配置文件。")
        sys.exit(0)
    entries.append(LL_PRIVACY_UUID)
    lines[index] = "KernelExperimental = " + ",".join(entries) + comment + "\n"
else:
    lines.insert(start + 1, "\n# 允许控制器在睡眠时解析已绑定设备的隐私地址。\n"
                 "KernelExperimental = " + LL_PRIVACY_UUID + "\n")
backup = path.with_name(path.name + ".bak-" + datetime.now().strftime("%Y%m%d-%H%M%S-%f"))
shutil.copy2(path, backup)
stat = path.stat()
fd, temporary = tempfile.mkstemp(prefix=".main.conf-", dir=path.parent)
try:
    with os.fdopen(fd, "w") as stream:
        stream.write("".join(lines))
        stream.flush()
        os.fsync(stream.fileno())
    os.chown(temporary, stat.st_uid, stat.st_gid)
    os.chmod(temporary, stat.st_mode & 0o7777)
    os.replace(temporary, path)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
print(f"已配置 LL Privacy；备份：{backup}")
PY

# 第 3 步：以 root 所有权安装权限修复脚本和服务，验证后启用睡眠前执行。
install -D -o root -g root -m 0644 "$package_dir/fix-bluetooth-wakeup.py" /usr/local/lib/bluetooth-wakeup-systemd/fix-bluetooth-wakeup.py
install -D -o root -g root -m 0644 "$package_dir/fix-bluetooth-wakeup.service" /etc/systemd/system/fix-bluetooth-wakeup.service
systemd-analyze verify /etc/systemd/system/fix-bluetooth-wakeup.service
systemctl daemon-reload
systemctl enable fix-bluetooth-wakeup.service

# 第 4 步：记录已打开的控制器，关闭后重启 BlueZ，应用 LL Privacy 配置。
# 内核要求在控制器关闭时切换此功能；退出时通过 trap 尝试重新打开这些控制器。
systemctl start bluetooth.service
adapter_paths=$(/usr/bin/busctl --system --timeout="$ADAPTER_TIMEOUT_SECONDS" --json=short call org.bluez / \
    org.freedesktop.DBus.ObjectManager GetManagedObjects | /usr/bin/python3 -I -c '
import json, sys
for path, interfaces in json.load(sys.stdin)["data"][0].items():
    if interfaces.get("org.bluez.Adapter1", {}).get("Powered", {}).get("data", False):
        print(path)
')
adapters=()
if [[ -n "$adapter_paths" ]]; then
    mapfile -t adapters <<< "$adapter_paths"
fi
# 服务重启返回后，Adapter1 对象可能尚未注册；设置失败时等待后重试。
# 每个控制器有独立截止时间，超过预算后输出最后一次错误并返回失败。
power_on_adapter() {
    local adapter="$1" deadline=$((SECONDS + ADAPTER_READY_BUDGET_SECONDS))
    local error='控制器尚未准备好'
    while (( SECONDS < deadline )); do
        if error=$(/usr/bin/busctl --system --timeout="$ADAPTER_TIMEOUT_SECONDS" set-property \
            org.bluez "$adapter" org.bluez.Adapter1 Powered b true 2>&1); then
            return 0
        fi
        sleep "$ADAPTER_RETRY_INTERVAL_SECONDS"
    done
    printf '恢复控制器失败 %s：%s\n' "$adapter" "$error" >&2
    return 1
}
restore_adapters() {
    local adapter failed=0
    for adapter in "${adapters[@]}"; do
        power_on_adapter "$adapter" || failed=1
    done
    return "$failed"
}
# 出错或中断时也尝试恢复蓝牙；恢复前移除 trap，避免重复进入恢复过程。
restore_on_exit() {
    local status=$?
    trap - EXIT
    restore_adapters || true
    exit "$status"
}
trap restore_on_exit EXIT
for adapter in "${adapters[@]}"; do
    /usr/bin/busctl --system --timeout="$ADAPTER_TIMEOUT_SECONDS" set-property org.bluez "$adapter" org.bluez.Adapter1 Powered b false
done
systemctl restart bluetooth.service
# 正常恢复也使用相同的有界重试；全部控制器处理完后统一判断结果。
restore_status=0
restore_adapters || restore_status=$?
trap - EXIT
if (( restore_status != 0 )); then
    printf '部分蓝牙控制器未能恢复；已安装配置保留，请检查蓝牙服务日志。\n' >&2
    exit "$restore_status"
fi

# 第 5 步：读取 BlueZ 已启用的实验功能，确认每个控制器都报告 LL Privacy。
# 验证失败时保留已安装文件，继续检查权限，最后以非零退出码报告未完全成功。
privacy_status=0
/usr/bin/python3 -I /usr/local/lib/bluetooth-wakeup-systemd/fix-bluetooth-wakeup.py --verify-ll-privacy || privacy_status=$?

# 第 6 步：立即运行一次权限修复服务，并输出验证方法。
# 外设重连或内核记录尚未就绪时可能失败，可从服务日志查看具体设备和错误。
if ! systemctl start fix-bluetooth-wakeup.service; then
    printf '本次检查未完全成功，请查看日志；下次睡眠前会再次执行。\n' >&2
fi
printf '\n已安装睡眠前检查服务，无需重启电脑。\n'
printf '查看日志：journalctl -u fix-bluetooth-wakeup.service -n 60 --no-pager\n'
if (( privacy_status != 0 )); then
    printf 'LL Privacy 未通过运行状态验证，请检查上方错误及 BlueZ 日志。\n' >&2
    exit "$privacy_status"
fi
printf 'LL Privacy 运行状态验证通过；实际睡眠唤醒效果仍需测试。\n'
