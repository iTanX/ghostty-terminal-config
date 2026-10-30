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

- `install.sh`：备份并合并 BlueZ 的 LL Privacy 配置，安装服务，重新初始化蓝牙并检查一次。
- `fix-bluetooth-wakeup.py`：启用所有 USB 蓝牙适配器自身的 power/wakeup，为所有已配对／绑定且提供 WakeAllowed 属性的设备开启权限。
- `fix-bluetooth-wakeup.service`：在 sleep.target 之前执行脚本，实际睡眠服务在 sleep.target 之后执行。

## 安装

适用当前 Debian 13、BlueZ 5.82、systemd 环境，需要 Python 3 和 busctl。使用电脑上的终端进入本文件夹后执行：

```bash
bash install.sh
```

**安装会申请 sudo 权限并短暂断开蓝牙键鼠和音响。** 无需重启电脑，但设备可能需要重新连接。

安装操作：

1. 在 `/etc/bluetooth/main.conf` 已有 `[General]` 段中合并 `KernelExperimental = 15c0a148-c273-11ea-b3de-0242ac130004`。保留其他 UUID；已有 true 则保留。修改前在 `/etc/bluetooth/` 下生成 `main.conf.bak-时间戳`（例如 `/etc/bluetooth/main.conf.bak-20261028-210000-123456`），仅配置发生改变时备份；重复安装不会重复加入 UUID。
2. 安装 `/usr/local/lib/bluetooth-wakeup-systemd/fix-bluetooth-wakeup.py` 和 `/etc/systemd/system/fix-bluetooth-wakeup.service`，由 root 管理。
3. 将服务启用到 sleep.target。
4. 暂时关闭已打开的控制器，重启 BlueZ，恢复这些控制器，以应用 LL Privacy。控制器对象异步注册，恢复时每个控制器最多等待约 20 秒并重试，失败报告最后一次错误。其配置在以后 BlueZ 初始化时继续应用；无需在每次睡眠前开关控制器。实际开启仍取决于硬件支持和 BlueZ 初始化结果。
5. 读取每个控制器的 `ExperimentalFeatures`，确认 BlueZ 已成功启用 LL Privacy。验证失败会报告错误并使安装器以非零状态退出，已安装文件保留。
6. 立即检查一次权限；以后每次正常 systemd 睡眠流程之前再检查。

安装时关闭的控制器仍可能受 BlueZ 自身 AutoEnable 策略影响；本脚本只对原先已打开的控制器显式恢复开关。

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
| `LL_PRIVACY_UUID` | `15c0a148-c273-11ea-b3de-0242ac130004` | Linux／BlueZ 定义的功能标识，与具体设备无关；安装器复用此常量 |
| `DBUS_TIMEOUT_SECONDS` | 2 秒 | 单次 D-Bus 请求超时 |
| `COMMAND_TIMEOUT_SECONDS` | 3 秒 | busctl 进程超时 |
| `MAX_ATTEMPTS` | 3 | 设备权限检查最多轮数 |
| `RETRY_INTERVAL_SECONDS` | 1 秒 | 两轮检查之间的等待时间 |
| `DEVICE_CHECK_BUDGET_SECONDS` | 20 秒 | 设备权限检查时间预算 |
| `DEVICE_CALL_COUNT` | 2 | 每设备设置和读取各一次，用于计算预留时间 |
| `PRIVACY_CHECK_ATTEMPTS` | 5 | 安装后 LL Privacy 状态验证最多轮数 |

设备操作和重试预留时间由上述参数计算。服务中的 `TimeoutStartSec=30s` 为整体硬超时，调整预算时要同时保留足够余量。安装器的 `ADAPTER_TIMEOUT_SECONDS=5` 控制单次控制器调用超时，`ADAPTER_READY_BUDGET_SECONDS=20` 和 `ADAPTER_RETRY_INTERVAL_SECONDS=1` 控制恢复控制器的重试窗口与间隔。单次调用可能使实际等待略超窗口。

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

若睡眠前检查仍报 Invalid Parameters，用 btmgmt 分别读取实际地址及类型对应的支持标志。LE Public 为类型 1，LE Random 为类型 2。支持标志需包含 bit 0（0x1）。不要仅因配置文件存在 UUID 就认定 LL Privacy 成功启用。

## 停用本方案

```bash
sudo systemctl disable fix-bluetooth-wakeup.service
```

停用后不再在睡眠前执行权限修复；已应用的设备权限和 LL Privacy 配置仍然保留。若需撤销 LL Privacy，先对比配置备份，移除对应 UUID 并保留其他配置；重新初始化蓝牙后才会改变运行状态。

## 来源

触发思路参考 EnriqueWood/wake-on-bluetooth 的 systemd 睡眠前执行方案：

https://github.com/EnriqueWood/wake-on-bluetooth/tree/19bdc7e0b98fc265350dba7cb11bdccedc14ccff/systemd

本实现包含 USB 适配器唤醒授权、设备 WakeAllowed 设置和 LL Privacy 配置，通过 Before=sleep.target 保证权限修复在实际睡眠流程之前执行。
