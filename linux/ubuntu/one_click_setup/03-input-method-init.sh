#!/usr/bin/env bash

# ==============================================================================
# 准备配置
# ==============================================================================
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "错误：请使用普通用户运行本脚本，不要使用 sudo。" >&2
  exit 1
fi

RIME_DIR="$HOME/.local/share/fcitx5/rime"
ENV_FILE="$HOME/.config/environment.d/fcitx5.conf"
AUTOSTART_SOURCE="/usr/share/applications/org.fcitx.Fcitx5.desktop"
AUTOSTART_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/org.fcitx.Fcitx5.desktop"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# ==============================================================================
# 配置输入法
# ==============================================================================
# 1. 安装输入法
echo "==> 安装 Fcitx5、Rime 及依赖..."
sudo apt update

# 1.1 安装依赖
sudo apt install -y git curl unzip python3 libglib2.0-bin

# 1.2 安装输入法软件包
sudo apt install -y \
  fcitx5 fcitx5-rime fcitx5-config-qt librime-plugin-lua

# 2. 设置默认框架与自启动
echo "==> 设置 Fcitx5 为默认输入法框架及登录自启动..."
im-config -n fcitx5

if [ ! -f "$AUTOSTART_SOURCE" ]; then
  echo "错误：未找到 Fcitx5 启动文件：$AUTOSTART_SOURCE" >&2
  exit 1
fi
if cmp -s "$AUTOSTART_SOURCE" "$AUTOSTART_FILE"; then
  echo "Fcitx5 登录自启动已配置，跳过写入。"
else
  install -Dm644 -T "$AUTOSTART_SOURCE" "$AUTOSTART_FILE"
  echo "已设置 Fcitx5 登录自启动：$AUTOSTART_FILE"
fi

# 3. 配置输入法环境变量
echo "==> 写入环境变量配置..."
mkdir -p "$(dirname "$ENV_FILE")"
if [ -e "$ENV_FILE" ]; then
  echo "已存在 ${ENV_FILE}，跳过写入（如需修改请手动编辑）。"
else
  cat > "$ENV_FILE" <<'EOF'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF
  echo "已写入 $ENV_FILE"
fi

echo "==> 配置 Input Method Panel..."
if command -v gnome-shell >/dev/null 2>&1; then
  KIMPANEL_UUID="kimpanel@kde.org"
  KIMPANEL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$KIMPANEL_UUID"
  GNOME_VERSION="$(gnome-shell --version | awk '{print $NF}')"
  GNOME_MAJOR="${GNOME_VERSION%%.*}"
  if [[ ! "$GNOME_MAJOR" =~ ^[0-9]+$ ]]; then
    echo "错误：无法识别 GNOME Shell 版本：$GNOME_VERSION" >&2
    exit 1
  fi

  if python3 - "$KIMPANEL_DIR/metadata.json" "$GNOME_MAJOR" "$KIMPANEL_UUID" 2>/dev/null <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    metadata = json.load(f)
sys.exit(0 if metadata.get("uuid") == sys.argv[3]
         and sys.argv[2] in metadata.get("shell-version", []) else 1)
PY
  then
    echo "Input Method Panel 已安装且兼容 GNOME $GNOME_MAJOR，跳过下载。"
  else
    python3 - "$TMP_DIR/kimpanel.zip" "$GNOME_MAJOR" "$KIMPANEL_UUID" <<'PY'
import json, sys
from shutil import copyfileobj
from urllib.parse import urlencode
from urllib.request import urlopen
base = "https://extensions.gnome.org"
query = urlencode({"pk": 261, "shell_version": sys.argv[2]})
with urlopen(base + "/extension-info/?" + query, timeout=30) as response:
    info = json.load(response)
path = info.get("download_url", "")
if info.get("uuid") != sys.argv[3] or not path.startswith("/download-extension/"):
    sys.exit("错误：GNOME 官方目录未返回兼容的 Input Method Panel 下载地址。")
with urlopen(base + path, timeout=120) as response, open(sys.argv[1], "wb") as bundle:
    copyfileobj(response, bundle)
PY
    gnome-extensions install --force "$TMP_DIR/kimpanel.zip"
  fi

  python3 - "$KIMPANEL_UUID" <<'PY'
import ast, json, subprocess, sys
uuid = sys.argv[1]
def get(key):
    value = subprocess.check_output(
        ["gsettings", "get", "org.gnome.shell", key], text=True).strip()
    if value in ("true", "false"):
        return value == "true"
    return ast.literal_eval(value.removeprefix("@as "))
for key in ("enabled-extensions", "disabled-extensions"):
    values = get(key)
    if key == "enabled-extensions":
        if uuid not in values:
            values.append(uuid)
    else:
        values = [value for value in values if value != uuid]
    subprocess.run(["gsettings", "set", "org.gnome.shell", key,
                    json.dumps(values)], check=True)
    if get(key) != values:
        sys.exit("错误：无法保存 GNOME 扩展启用状态，请在当前用户的桌面终端运行。")
subprocess.run(["gsettings", "set", "org.gnome.shell",
                "disable-user-extensions", "false"], check=True)
if get("disable-user-extensions"):
    sys.exit("错误：无法打开 GNOME 用户扩展开关。")
PY
  if gnome-extensions enable "$KIMPANEL_UUID"; then
    echo "Input Method Panel 已设置为启用。"
  else
    echo "Input Method Panel 的启用设置已保存，注销并重新登录后加载。"
  fi
else
  echo "未检测到 GNOME Shell，跳过 GNOME 专用的 Input Method Panel。"
fi

# 4. 安装雾凇拼音
echo "==> 安装雾凇拼音..."
if [ -d "$RIME_DIR/.git" ]; then
  echo "检测到已有雾凇拼音仓库，执行更新..."
  git -C "$RIME_DIR" pull --ff-only
elif [ -e "$RIME_DIR" ]; then
  echo "检测到非 Git 仓库的 Rime 配置目录，删除后重新克隆..."
  rm -rf "$RIME_DIR"
  git clone --depth=1 https://github.com/iDvel/rime-ice.git "$RIME_DIR"
else
  git clone --depth=1 https://github.com/iDvel/rime-ice.git "$RIME_DIR"
fi

# ==============================================================================
# 完成配置
# ==============================================================================
cat <<'MSG'

============================================================
脚本执行完成。剩余步骤需手动操作：

1. 注销并重新登录（使 im-config、环境变量和新装的 Input Method Panel 生效）。
   Fcitx5 已配置为登录桌面后自动启动。
   GNOME 下的 Input Method Panel 已自动安装并设置为启用，无需手动安装扩展。

2. 运行以下命令打开配置工具：
     fcitx5-configtool
   取消勾选“仅显示当前语言”，搜索并添加 Rime，调整顺序后应用。

3. 触发部署（二选一）：
     busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 SetConfig sv fcitx://config/addon/rime/deploy s ''
   或在托盘图标右键菜单点击“重新部署”。请等待输入法的部署完成提示。

4. 按 Ctrl+空格 切换到 Rime，输入拼音验证。
   输入状态下按 F4 可查看当前方案是否为雾凇拼音。
============================================================

MSG
