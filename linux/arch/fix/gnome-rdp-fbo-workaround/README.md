# GNOME 远程桌面断连绕过方案

适用于 Arch Linux 上使用 GNOME 内置远程桌面时，Mutter 51.1 在捕获画面过程中发生 `SIGSEGV`、导致 Wayland 桌面退出和 RDP 断开的情况。它不是通用的 RDP 断连修复。

## 安装

在目标机器上，以需要修复的 GNOME 桌面用户登录后，从本目录运行：

```bash
bash install.sh
```

无需 `sudo`。脚本将 `MUTTER_DEBUG_USE_FBOS=0` 写入 `~/.config/systemd/user/org.gnome.Shell@user.service.d/90-rdp-fbo-workaround.conf`，让 Mutter 改用 GBM/EGL surface 路径，绕开崩溃位置。这不会关闭 GPU 硬件加速。

脚本不会覆盖内容不同的同名文件，也不会自动注销或修改扩展状态。安装后请保存工作，**注销 GNOME 桌面并重新登录**，再连接远程桌面测试。仅断开 RDP 连接不会使配置生效。

## 撤销

确认下列文件是本方案安装的配置后执行，再注销并重新登录：

```bash
rm -- "$HOME/.config/systemd/user/org.gnome.Shell@user.service.d/90-rdp-fbo-workaround.conf"
systemctl --user daemon-reload
```
