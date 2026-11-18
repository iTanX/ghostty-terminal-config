# 蓝牙睡眠唤醒权限修复

## 目标和文件

本方案每次系统准备睡眠时执行一次检查，不使用 udev 规则、不使用 timer、不常驻轮询。

```text
bluetooth-wakeup-systemd/
├── install.sh
├── fix-bluetooth-wakeup.py
├── fix-bluetooth-wakeup.service
└── README.md
```

- `install.sh`：安装服务，检查一次唤醒权限，并读取内核报告的 LL Privacy 状态。
- `fix-bluetooth-wakeup.py`：启用所有 USB 蓝牙适配器自身的 power/wakeup，为所有已配对／绑定且提供 WakeAllowed 属性的设备开启权限。
- `fix-bluetooth-wakeup.service`：在 sleep.target 之前执行脚本，实际睡眠服务在 sleep.target 之后执行。

## 安装

适用于使用稳定 LL Privacy 管理接口的 Arch Linux。需要 systemd、BlueZ、Python 3 和 busctl。进入本文件夹后执行：

```bash
bash install.sh
```

安装器通过 sudo 安装并启用睡眠前服务，立即执行一次唤醒权限检查，再通过 Linux Bluetooth MGMT 查询每个控制器的 LL Privacy 状态。唤醒权限检查失败会使安装器返回非零状态。LL Privacy 状态单独输出，服务保持启用。

## LL Privacy

新内核通过 MGMT 报告控制器是否支持和启用 LL Privacy。BlueZ 默认采用 `[LE]` 段的 `CentralAddressResolution = 1`，在条件满足时为需要地址解析的设备设置对应标志。若本机配置显式设置为 `0`，可改回 `1` 后重启 BlueZ。控制器的 LL Privacy 状态与每个设备的地址解析标志是独立的检查项。

Arch 安装器保留现有 BlueZ 配置并使用当前运行的蓝牙服务。若此前运行过 Debian 版，可对照配置备份清理旧版加入的实验 UUID。

## 每次睡眠前的行为

```text
正常 systemd 睡眠请求
  → fix-bluetooth-wakeup.service
  → 检查适配器 power/wakeup 和设备 WakeAllowed
  → sleep.target
  → systemd-sleep 执行实际睡眠
```

- 不限制设备型号、地址或控制器编号。
- 已授权设备跳过；不主动打开蓝牙、不主动连接设备、不清除绑定、不读取密钥。
- 只给已配对／已绑定且提供 WakeAllowed 属性的设备授权，音响等没有属性的设备跳过。
- 最多三轮有限重试，总预算约 20 秒；服务 30 秒硬超时。设备很多或 BlueZ 无响应时可能有设备未处理，日志会说明。
- 单个设备失败继续处理其他设备。检查失败会使服务报告失败，但不会强制取消系统睡眠，不能保证失败设备能唤醒。
- 这是睡眠前一次性修正，平时新增设备或蓝牙重启后不会立即检查；下次睡眠前处理。直接写 `/sys/power/state` 等绕开 systemd 的方式不会执行该服务。
- 不保证不存在的设备稍后加入时能在这轮被处理；该设备下次睡眠前有记录且暴露属性时再处理。
- 统一开启策略会在每次睡眠前覆盖用户手动设置的 WakeAllowed=false。

## 常量和时间参数

`fix-bluetooth-wakeup.py` 顶部统一定义：

| 常量 | 默认值 | 用途 |
|---|---|---|
| `DBUS_TIMEOUT_SECONDS` | 2 秒 | 单次 D-Bus 请求超时 |
| `COMMAND_TIMEOUT_SECONDS` | 3 秒 | busctl 进程超时 |
| `MAX_ATTEMPTS` | 3 | 设备权限检查最多轮数 |
| `RETRY_INTERVAL_SECONDS` | 1 秒 | 两轮检查之间的等待时间 |
| `DEVICE_CHECK_BUDGET_SECONDS` | 20 秒 | 设备权限检查时间预算 |
| `DEVICE_CALL_COUNT` | 2 | 每设备设置和读取各一次，用于计算预留时间 |

设备操作和重试预留时间由上述参数计算。服务中的 `TimeoutStartSec=30s` 为整体硬超时，调整预算时要同时保留足够余量。

系统接口名称和标准路径是固定约定；设备地址、USB 厂商／产品 ID、控制器编号均动态获取。

## 功能边界

LL Privacy 用于控制器识别使用 RPA／IRK 的已绑定设备。它不能区分自动重连广播与用户主动唤醒。

**ESP32 如果断连后立即持续广播，启用权限后可能使电脑立即醒来。此方案不会解决广播误唤醒。**

Linux 挂起时仍可能主动断开 BLE／音频连接；本方案不提供保持连接功能，也不解决音响断连后自动关机。

不修改上游 USB 集线器、PCI 唤醒设置或固件。硬件、广播和平台唤醒链路仍需实际验证。

## 检查

```bash
# 服务是否已启用（oneshot 正常完成后为 inactive，不是常驻进程）
systemctl is-enabled fix-bluetooth-wakeup.service

# 查看上次和历次执行日志
journalctl -u fix-bluetooth-wakeup.service -n 60 --no-pager

# 手动执行一次检查，不会触发睡眠
sudo systemctl start fix-bluetooth-wakeup.service

# 各设备应显示 WakeAllowed: yes
bluetoothctl info <设备地址>

# 验证所有已枚举控制器的 LL Privacy 运行状态，不修改设置
sudo python3 -I /usr/local/lib/bluetooth-wakeup-systemd/fix-bluetooth-wakeup.py --verify-ll-privacy

# 查看 BlueZ 相关日志
sudo journalctl -b -u bluetooth --no-pager -g 'RPA|Privacy|privacy|flags|wake'
```

若睡眠前检查仍报 Invalid Parameters，用 btmgmt 分别读取实际地址及类型对应的支持标志。LE Public 为类型 1，LE Random 为类型 2。支持标志需包含 bit 0（0x1）。

## 停用本方案

```bash
sudo systemctl disable fix-bluetooth-wakeup.service
```

停用后，已应用的设备唤醒权限仍然保留。

## 来源

触发思路参考 EnriqueWood/wake-on-bluetooth 的 systemd 睡眠前执行方案：

https://github.com/EnriqueWood/wake-on-bluetooth/tree/19bdc7e0b98fc265350dba7cb11bdccedc14ccff/systemd

本实现包含 USB 适配器唤醒授权、设备 WakeAllowed 设置和 LL Privacy 状态查询，通过 Before=sleep.target 保证权限修复在实际睡眠流程之前执行。
