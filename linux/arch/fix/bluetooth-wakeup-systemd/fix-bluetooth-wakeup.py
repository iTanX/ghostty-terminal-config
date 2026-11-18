#!/usr/bin/env python3
"""睡眠前启用 USB 蓝牙适配器及已配对设备的唤醒权限，不限制型号或地址。"""

import json
import os
from pathlib import Path
import subprocess
import sys
import time


# Linux 蓝牙管理接口定义的 LL Privacy 功能 UUID，与设备地址或型号无关。
LL_PRIVACY_UUID = "15c0a148-c273-11ea-b3de-0242ac130004"

# D-Bus 自身超时略短于进程超时，为命令返回错误留出时间。
DBUS_TIMEOUT_SECONDS = 2
COMMAND_TIMEOUT_SECONDS = 3
MAX_ATTEMPTS = 3
RETRY_INTERVAL_SECONDS = 1
DEVICE_CHECK_BUDGET_SECONDS = 20
# 每个设备需要一次设置和一次读取；重试前还需预留等待时间。
DEVICE_CALL_COUNT = 2
DEVICE_OPERATION_BUDGET_SECONDS = DEVICE_CALL_COUNT * COMMAND_TIMEOUT_SECONDS
RETRY_BUDGET_SECONDS = RETRY_INTERVAL_SECONDS + DEVICE_OPERATION_BUDGET_SECONDS
# 安装后验证 BlueZ 实验功能状态时，为初始化保留独立的重试窗口。
PRIVACY_CHECK_ATTEMPTS = 5


def log(message):
    print(message, flush=True)


def busctl(*arguments):
    """限制单次调用时间；不因查询而自动启动已关闭的 BlueZ 服务。"""
    result = subprocess.run(
        ["/usr/bin/busctl", "--system", "--auto-start=no",
         f"--timeout={DBUS_TIMEOUT_SECONDS}", *arguments],
        capture_output=True, text=True, timeout=COMMAND_TIMEOUT_SECONDS,
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "D-Bus 调用失败")
    return result.stdout


def objects():
    reply = busctl("--json=short", "call", "org.bluez", "/",
                   "org.freedesktop.DBus.ObjectManager", "GetManagedObjects")
    return json.loads(reply)["data"][0]


def value(properties, name, default=None):
    return properties.get(name, {}).get("data", default)


def enable_adapters():
    # 第 1 步：枚举 HCI 控制器，沿父目录找到最近的 USB 设备。
    # 根据 idVendor/idProduct 定位适配器自身的 power/wakeup，并跳过连接子节点。
    errors = {}
    seen = set()
    for hci in Path("/sys/class/bluetooth").glob("hci*"):
        if ":" in hci.name:
            continue
        node = hci.resolve()
        for parent in (node, *node.parents):
            if not ((parent / "idVendor").is_file() and (parent / "idProduct").is_file()):
                continue
            wakeup = parent / "power/wakeup"
            if wakeup in seen:
                break
            seen.add(wakeup)
            try:
                if wakeup.exists() and wakeup.read_text().strip() == "disabled":
                    wakeup.write_text("enabled\n")
                    if wakeup.read_text().strip() != "enabled":
                        raise RuntimeError("写入后不是 enabled")
                    log(f"已启用适配器唤醒：{wakeup}")
            except (OSError, RuntimeError) as error:
                errors[str(wakeup)] = str(error)
            break
    return errors


def enable_devices():
    # 第 2 步：在设备检查预算内有限重试，处理内核设备记录尚未就绪的情况。
    # systemd 的 TimeoutStartSec 是整个服务的最终超时，应大于此处预算。
    deadline = time.monotonic() + DEVICE_CHECK_BUDGET_SECONDS
    errors = {}
    for attempt in range(MAX_ATTEMPTS):
        errors = {}
        try:
            devices = objects()
        except (OSError, RuntimeError, ValueError, KeyError, IndexError,
                subprocess.TimeoutExpired) as error:
            errors["BlueZ 设备列表"] = str(error)
        else:
            for path, interfaces in devices.items():
                properties = interfaces.get("org.bluez.Device1")
                if properties is None:
                    continue
                # 筛选已配对／已绑定且 WakeAllowed=false 的设备。
                # 已启用权限或未提供该属性的设备直接跳过。
                if not (value(properties, "Paired", False) or value(properties, "Bonded", False)):
                    continue
                if value(properties, "WakeAllowed") is not False:
                    continue
                adapter = devices.get(value(properties, "Adapter"), {}).get("org.bluez.Adapter1", {})
                if not value(adapter, "Powered", False):
                    continue
                address = value(properties, "Address", path)
                # 预留一次设置和一次验证的最长时间，预算不足时不继续调用。
                if time.monotonic() + DEVICE_OPERATION_BUDGET_SECONDS > deadline:
                    errors[address] = "本轮检查时间预算不足"
                    continue
                try:
                    busctl("set-property", "org.bluez", path,
                           "org.bluez.Device1", "WakeAllowed", "b", "true")
                    reply = busctl("get-property", "org.bluez", path,
                                   "org.bluez.Device1", "WakeAllowed")
                    if reply.strip() != "b true":
                        raise RuntimeError("设置后读取结果不是 b true")
                    log(f"已启用设备唤醒：{address}")
                except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
                    errors[address] = str(error)
        if (not errors or attempt == MAX_ATTEMPTS - 1
                or time.monotonic() + RETRY_BUDGET_SECONDS > deadline):
            break
        # 每次重读设备列表，已成功设备自动跳过，不重复写入。
        time.sleep(RETRY_INTERVAL_SECONDS)
    return errors


def verify_ll_privacy():
    """查询 BlueZ 已成功启用的实验功能，验证所有已枚举控制器的 LL Privacy。"""
    errors = {}
    for attempt in range(PRIVACY_CHECK_ATTEMPTS):
        errors = {}
        try:
            adapters = {path: interfaces["org.bluez.Adapter1"]
                        for path, interfaces in objects().items()
                        if "org.bluez.Adapter1" in interfaces}
            if not adapters:
                errors["控制器"] = "未发现蓝牙控制器，无法验证 LL Privacy"
            for path, properties in adapters.items():
                features = value(properties, "ExperimentalFeatures", [])
                if LL_PRIVACY_UUID not in [feature.lower() for feature in features]:
                    errors[path] = "BlueZ 未报告 LL Privacy 已开启；请检查硬件支持与蓝牙服务日志"
        except (OSError, RuntimeError, ValueError, KeyError, IndexError,
                subprocess.TimeoutExpired) as error:
            errors["BlueZ"] = str(error)
        if not errors:
            log("LL Privacy 验证通过：所有已枚举控制器均已启用。")
            return 0
        if attempt < PRIVACY_CHECK_ATTEMPTS - 1:
            time.sleep(RETRY_INTERVAL_SECONDS)
    for target, error in errors.items():
        log(f"LL Privacy 验证失败：{target}：{error}")
    return 1


def main():
    if os.geteuid() != 0:
        log("请以 root 身份运行。")
        return 1
    # 安装器单独调用验证入口；普通睡眠前执行不重复切换或验证实验功能。
    if sys.argv[1:] == ["--verify-ll-privacy"]:
        return verify_ll_privacy()
    if sys.argv[1:]:
        log("用法：fix-bluetooth-wakeup.py [--verify-ll-privacy]")
        return 2
    errors = enable_adapters()
    errors.update(enable_devices())
    # 第 3 步：汇总适配器和设备设置错误，通过退出码报告本轮是否全部成功。
    for target, error in errors.items():
        log(f"未能启用唤醒：{target}：{error}")
    if errors:
        log("权限准备未完全成功；服务会报告失败，但不强制阻止系统睡眠。")
        return 1
    log("睡眠前蓝牙唤醒权限检查完成。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
