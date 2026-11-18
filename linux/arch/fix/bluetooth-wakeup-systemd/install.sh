#!/usr/bin/env bash
# 安装每次睡眠前执行的蓝牙唤醒权限修复服务。
set -euo pipefail
package_dir=$(dirname -- "$(readlink -f -- "$0")")

# 1. 检查权限、依赖和配套文件。
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

# 2. 安装并启用睡眠前服务。
install -D -o root -g root -m 0644 "$package_dir/fix-bluetooth-wakeup.py" /usr/local/lib/bluetooth-wakeup-systemd/fix-bluetooth-wakeup.py
install -D -o root -g root -m 0644 "$package_dir/fix-bluetooth-wakeup.service" /etc/systemd/system/fix-bluetooth-wakeup.service
systemd-analyze verify /etc/systemd/system/fix-bluetooth-wakeup.service
systemctl daemon-reload
systemctl enable fix-bluetooth-wakeup.service

# 3. 执行一次睡眠前检查。
systemctl start fix-bluetooth-wakeup.service
printf '已安装睡眠前检查服务。\n'

# 4. 检查内核报告的 LL Privacy 状态。
if ! /usr/bin/python3 -I /usr/local/lib/bluetooth-wakeup-systemd/fix-bluetooth-wakeup.py --verify-ll-privacy; then
    printf '唤醒服务已启用；请根据上方输出检查 LL Privacy 状态。\n' >&2
fi
