# Debian 13 Desktop Shell Config

适用于 **Debian 13（Trixie）GNOME 桌面版**，面向 13.7 安装介质及同系列更新，提供 Ghostty 终端模拟器、Starship 彩虹条提示符、zsh 插件、模糊搜索、智能目录跳转、文件管理器和常用命令别名。

> WSL 用户请改用 [`wsl/`](../../../wsl/) 目录。WSL 内没有图形界面，不需要也无法安装 Ghostty，那边只配置 Shell 工具。

本目录与仓库中的 macOS 配置相互独立，各自安装对应平台的终端模拟器与字体。

## 效果

- Ghostty 终端：半透明窗口、Catppuccin Mocha 主题、Maple Mono NF CN 字体、10 号
- Debian 自带终端 GNOME Terminal：自动关闭系统字体，设置 Maple Mono NF CN Regular、10 号
- 为 Ghostty 保留明确指定的 Maple CN 字体优先级，并验证中英文环境的常规、粗体匹配
- Starship 彩虹条提示符
- zsh Tab 补全、语法高亮和历史命令自动建议
- fzf 模糊搜索历史命令与文件
- zoxide 智能目录跳转
- Yazi 终端文件管理器
- eza、batcat 常用命令别名

## 包含的配置文件

| 文件 | 说明 | 安装位置 |
|------|------|---------|
| `ghostty/config` | Ghostty 终端配置（字体、主题、窗口、光标） | `~/.config/ghostty/config` |
| `starship/starship.toml` | Starship 彩虹条提示符配置 | `~/.config/starship.toml` |
| `zsh/.zshrc` | Debian 版 zsh 配置 | 追加到 `~/.zshrc` 的受控标记块内 |
| `install.sh` | Debian 13 一键安装脚本 | 可在任意目录运行（自动定位配置） |
| `configure-fonts.sh` | 设置字体匹配规则，安装器自动调用，也可单独运行 | 当前用户的 Fontconfig |
| `fontconfig/99-maple-mono-nf-cn-ghostty.conf` | 保留明确指定的 Maple CN 字体优先级 | `~/.config/fontconfig/conf.d/` |

配置目录遵循 `XDG_CONFIG_HOME`，未设置时使用 `~/.config`。GNOME Terminal 和 Ghostty 的默认字重均为 Regular；`eza` 等程序仍可为目录名请求粗体，Starship 彩虹条路径保持原有常规样式。

## 前置条件

- Debian 13（`ID=debian`、`VERSION_ID=13`、`VERSION_CODENAME=trixie`），`amd64` 或 `arm64` 架构
- 安装时选择 GNOME，在默认的 GNOME Terminal 桌面会话中运行
- 当前用户已安装 `sudo` 并具有相应权限；不要以 root 运行整个脚本
- 可以访问 Debian 软件源、Griffo 免费软件源、GitHub 和 Yazi 官方软件源

13.7 是 Debian 13 的更新节点，脚本按主版本及代号检查，不限定 `/etc/debian_version` 的小版本。当前仅完成静态检查与软件源核验，尚未在 Debian 13.7 实机完成安装验证。

## 与 macOS 版 Ghostty 配置的差异

两边配置基本一致，只有三个键在 Linux 上不起作用，因此未启用：

| 配置项 | 说明 |
|--------|------|
| `font-thicken` | 字体加粗渲染，仅 macOS 支持 |
| `macos-titlebar-style` | 标签页融入标题栏，仅 macOS 支持 |
| `window-save-state` | 退出后保留窗口状态，仅 macOS 支持，在 Linux 上无任何效果 |

Linux 版使用含中文的 NF CN 字体，字号为 10，并额外设置 GNOME Terminal 的字体和当前用户的 Fontconfig 规则。主题、内边距、透明度、光标和交互设置与 macOS 版保持一致。

另外 `background-blur`（毛玻璃模糊）只在部分桌面环境下生效，例如 KDE Plasma。Debian 默认的 GNOME 不支持客户端模糊，此时窗口透明度仍然生效，只是没有模糊效果。

## 一键安装

在本 README 所在目录执行：

```bash
bash install.sh
```

脚本会自动执行：

1. 检查当前系统是否为 Debian 13 Trixie，架构是否为 `amd64` 或 `arm64`
2. 使用 Debian `main` 安装共同工具，添加使用独立 keyring 和 `signed-by` 的 Griffo 免费 trixie APT 源并安装 Ghostty
3. 添加使用独立 keyring 和 `signed-by` 的 Yazi 官方稳定版 APT 源
4. 安装 Ghostty、zsh、Starship、fzf、zoxide、eza、bat、Yazi 和两个 zsh 插件
5. 首次克隆 zsh-completions 到 `~/.local/share/zsh-completions`，再次运行时执行 `git pull --ff-only`
6. 从官方 GitHub Release 下载 Maple Mono NF CN 字体并校验完整性，安装到 `~/.local/share/fonts/maple-mono-nf-cn`
7. 安装 Fontconfig 兼容规则，刷新缓存并验证中英文环境下的常规、粗体均匹配 Maple CN
8. 备份并安装 Ghostty（CN 字体、10 号）和 Starship 配置
9. 将 Linux zsh 配置追加到 `~/.zshrc`
10. 将 GNOME Terminal 的字体设为 `Maple Mono NF CN Regular 10`，并关闭“使用系统字体”
11. 将当前用户的默认 Shell 切换为 zsh

### 3. 重新登录

注销后重新登录（或重启系统），新会话应直接进入 zsh 并显示 Starship 提示符，然后从应用列表启动 Ghostty。

## 配套初始化脚本

`../one_click_setup/01-basic-config.sh` 会调用本目录的安装器；`02-development-environment.sh` 保留 Python、Node.js、Java 和 AI 工具的配置流程。

`03-input-method-init.sh` 显式安装 `im-config` 和 `fcitx5-frontend-all`，覆盖 GTK3、GTK4、Qt5、Qt6，保留 Fcitx5 自启动、`environment.d` 环境变量和按 GNOME 版本安装 Input Method Panel 的流程；`04-input-method-update.sh` 更新雾凇拼音并请求重新部署。

输入法初始化后需注销重登，确认 GNOME 会话及应用获得输入法环境变量，再验证 Ghostty、GTK、Qt 和使用中的 XWayland 应用能否输入中文，以及候选窗口的位置。文件写入或扩展启用成功不等于桌面输入法已完成实机验证。

## 依赖来源

| 工具 | 用途 | 来源 |
|------|------|------|
| Ghostty | GPU 加速终端模拟器 | [Griffo 免费第三方 APT 源](https://deb.griffo.io/free.html)，使用 `trixie` 构建 |
| Maple Mono NF CN | 终端字体（含中文字形和 Nerd Font 图标） | [Maple Font Release](https://github.com/subframe7536/maple-font/releases)，脚本下载并校验 sha256 |
| libglib2.0-bin | 通过 GSettings 设置 GNOME Terminal 字体 | Debian APT |
| zsh | Shell | Debian APT |
| Starship | 跨 Shell 提示符 | Debian `main` |
| fzf | 模糊搜索 | Debian `main` |
| zoxide | 智能目录跳转 | Debian `main` |
| eza | 替代 ls，支持彩色图标 | Debian `main` |
| bat | 替代 cat，Debian 命令名为 `batcat` | Debian `main` |
| Yazi | 终端文件管理器 | [Yazi 官方 APT 源](https://yazi-rs.github.io/docs/installation/) |
| zsh-autosuggestions | 历史命令自动建议 | Debian `main` |
| zsh-syntax-highlighting | 命令语法高亮 | Debian `main` |
| zsh-completions | Tab 补全增强 | [zsh-users/zsh-completions](https://github.com/zsh-users/zsh-completions) |

字体版本固定在 `install.sh` 顶部的 `MAPLE_VERSION`（当前 `v7.9`），升级时只需改这一处。

Yazi 官方 APT 源提供 `amd64` 和 `arm64` 稳定版软件包。脚本不会使用已废弃的 `apt-key`，也不会安装 Rust/Cargo 编译环境。

Ghostty 使用 `https://deb-free.griffo.io/apt trixie main`，无需账号或订阅，可随 APT 升级。维护者说明，新上游版本有约两个月延迟，已提供版本的安全及补丁修复立即发布；这是第三方维护者的更新承诺。不要将免费源替换为需要订阅凭据的 `deb.griffo.io`，也不要添加 Ubuntu PPA。

Starship 和 fzf 直接使用 trixie 官方包；其中 fzf 0.60.3 支持现有的 `fzf --zsh`，无需上游安装器。

## 手动安装

如果不运行安装脚本，可以按以下步骤手动部署。

### 1. 安装 APT 依赖

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg git file fontconfig libglib2.0-bin unzip
```

添加 Ghostty 免费 trixie APT 源。下面的命令会覆盖同名 keyring 和源文件，已有配置时请先检查：

```bash
(
  set -euo pipefail
  KEY_TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$KEY_TMP_DIR"' EXIT
  curl -fsSL https://deb-free.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc -o "$KEY_TMP_DIR/ghostty.asc"
  gpg --batch --dearmor --output "$KEY_TMP_DIR/ghostty.gpg" "$KEY_TMP_DIR/ghostty.asc"
  sudo install -d -m 0755 /etc/apt/keyrings
  sudo install -m 0644 "$KEY_TMP_DIR/ghostty.gpg" /etc/apt/keyrings/deb-free.griffo.io.gpg
)
echo 'deb [signed-by=/etc/apt/keyrings/deb-free.griffo.io.gpg] https://deb-free.griffo.io/apt trixie main' \
  | sudo tee /etc/apt/sources.list.d/deb-free.griffo.io.list >/dev/null
sudo apt-get update
sudo apt-get install -y ghostty
```

添加 Yazi 官方稳定版 APT 源。若 `/etc/apt/sources.list.d/yazi.list` 已存在，请先确认其内容；下面的 `tee` 命令会覆盖该文件：

```bash
curl -fsSL https://yazi-rs.github.io/builds/yazi-keyring.gpg \
  | sudo tee /usr/share/keyrings/yazi-keyring.gpg >/dev/null

echo 'deb [signed-by=/usr/share/keyrings/yazi-keyring.gpg] https://yazi-rs.github.io/builds/ stable main' \
  | sudo tee /etc/apt/sources.list.d/yazi.list >/dev/null
```

安装工具和插件：

```bash
sudo apt-get update
sudo apt-get install -y \
  zsh zoxide eza bat zsh-autosuggestions zsh-syntax-highlighting starship fzf yazi

mkdir -p ~/.local/share
if [ -d ~/.local/share/zsh-completions/.git ] && [ -d ~/.local/share/zsh-completions/src ]; then
  git -C ~/.local/share/zsh-completions pull --ff-only
else
  git clone --depth 1 \
    https://github.com/zsh-users/zsh-completions.git \
    ~/.local/share/zsh-completions
fi
```

已有 zsh-completions 仓库会快进更新；若本地改动与上游冲突，更新报错并保留本地内容。

### 2. 安装 Maple Mono NF CN 字体

```bash
FONT_DIR="$HOME/.local/share/fonts/maple-mono-nf-cn"
mkdir -p "$FONT_DIR" /tmp/maple-font && cd /tmp/maple-font

curl -fsSLO https://github.com/subframe7536/maple-font/releases/download/v7.9/MapleMono-NF-CN.zip
curl -fsSLO https://github.com/subframe7536/maple-font/releases/download/v7.9/MapleMono-NF-CN.sha256

# 官方 .sha256 文件里只有裸哈希，没有文件名，因此不能用 sha256sum -c
[ "$(tr -d '[:space:]' < MapleMono-NF-CN.sha256)" = "$(sha256sum MapleMono-NF-CN.zip | cut -d' ' -f1)" ] \
  && echo "校验通过" || echo "校验失败，请勿安装"

unzip -oq MapleMono-NF-CN.zip -d extracted
find extracted -name '*.ttf' -exec cp -f {} "$FONT_DIR/" \;
printf 'v7.9\n' > "$FONT_DIR/.version"
fc-cache -f "$FONT_DIR"
```

### 3. 备份并部署配置

以下命令在本 README 所在目录（`linux/debian/terminal/`）执行。

先安装中文字体匹配规则。此步骤也适用于已经安装 CN 字体、只需要补上修复的机器：

```bash
bash configure-fonts.sh
```

已有字体规则会先备份。GNOME Terminal 默认 profile 的字体由 `install.sh` 设置，不备份原字体和字号；未检测到 GNOME Terminal 配置时会报错，请在安装 GNOME 后自带的默认终端运行。字体匹配或 GSettings 保存失败时会报错，避免把未生效的设置当作成功。

```bash
BACKUP_DIR="$HOME/.config-backup/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR" ~/.config/ghostty

# 仅在已有配置时备份
if [ -e ~/.config/ghostty/config ] || [ -L ~/.config/ghostty/config ]; then
  cp -a ~/.config/ghostty/config "$BACKUP_DIR/ghostty-config"
fi
if [ -e ~/.config/starship.toml ] || [ -L ~/.config/starship.toml ]; then
  cp -a ~/.config/starship.toml "$BACKUP_DIR/starship.toml"
fi

rm -f ~/.config/ghostty/config ~/.config/starship.toml
cp ghostty/config ~/.config/ghostty/config
cp starship/starship.toml ~/.config/starship.toml
```

将 zsh 配置追加到现有文件尾部：

```bash
{
  echo ""
  echo "# >>> linux-ghostty-terminal-config >>>"
  echo "# 以下内容由 Debian shell 配置安装脚本自动追加"
  echo "# 删除方法: 移除从 >>> 到 <<< 之间的所有内容"
  cat zsh/.zshrc
  echo "# <<< linux-ghostty-terminal-config <<<"
} >> ~/.zshrc
```

> 注意：手动追加前请确认 `~/.zshrc` 中不存在同名标记，否则会产生重复配置。推荐优先使用安装脚本，它会自动检查。

切换默认 Shell：

```bash
sudo chsh -s "$(command -v zsh)" "$USER"
```

## 快捷键速查

| 快捷键 | 功能 |
|--------|------|
| `→` | 接受 autosuggestions 的建议 |
| `Ctrl+R` | fzf 模糊搜索历史命令 |
| `Ctrl+T` | fzf 模糊搜索当前目录下的文件 |
| `命令 **<Tab>` | 触发 fzf 补全，例如 `cd **<Tab>` |
| `Tab` | zsh 补全，连续按可在候选列表中移动 |

## 命令与别名速查

| 命令或别名 | 实际行为 |
|------------|----------|
| `ls` | `eza --icons --group-directories-first --sort=name` |
| `lsa` | `ls` 的全部文件版本 |
| `ll` | eza 详细列表 |
| `lla` | `ll` 的全部文件版本 |
| `lt` | eza 两层树形视图 |
| `lta` | `lt` 的全部文件版本 |
| `cat 文件名` | `batcat --paging=never --style=plain` |
| `z foo` | zoxide 跳转到包含 `foo` 的常用目录 |
| `zi foo` | 通过 fzf 交互选择匹配目录 |
| `yazi` | 打开文件管理器，退出后留在原目录 |
| `y` | 打开 Yazi，退出后自动进入最后浏览的目录 |

## 验证安装

检查依赖、字体和默认 Shell：

```bash
command -v zsh ghostty starship fzf zoxide eza batcat yazi
fc-list | grep -i "Maple Mono NF CN" | head -3
fc-match 'Maple Mono NF CN:spacing=100:lang=zh-cn'
TERMINAL_PROFILE="$(gsettings get org.gnome.Terminal.ProfilesList default | tr -d "'")"
TERMINAL_SETTINGS="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$TERMINAL_PROFILE/"
gsettings get "$TERMINAL_SETTINGS" font
gsettings get "$TERMINAL_SETTINGS" use-system-font
getent passwd "$USER" | cut -d: -f7
```

字体匹配预期为 Maple Mono NF CN；GNOME Terminal 预期为 `'Maple Mono NF CN Regular 10'` 和 `false`；最后一条预期输出 `/usr/bin/zsh`。

检查 Ghostty 配置与插件：

```bash
ghostty +validate-config
test -d ~/.local/share/zsh-completions/src && echo "zsh-completions: OK"
test -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh && echo "autosuggestions: OK"
test -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh && echo "syntax-highlighting: OK"
zsh -lic 'alias ls; alias cat; whence -w y'
```

随后可实际测试 `Ctrl+R`、`Ctrl+T`、Tab、`z`、`zi` 和 `y`。

## 重复运行

安装脚本可以重复运行：

- Ghostty 免费 trixie 源和 Yazi APT 源不会重复添加
- Ghostty 随 APT 安装或升级；重新运行脚本也会更新到软件源的候选版本，不执行全系统升级
- 每次对已有 zsh-completions 执行 `git pull --ff-only`
- 字体目录中记录的版本与 `MAPLE_VERSION` 相同时跳过下载
- 每次都会安装或核对 Fontconfig 规则、刷新字体缓存，并验证中文和英文环境的常规、粗体匹配
- GNOME Terminal 字体已正确设置时跳过修改；需要修改时直接设置，不备份旧值
- Ghostty 和 Starship 配置内容相同时不会重复复制或备份
- `~/.zshrc` 中存在 Linux 配置 marker 时不会再次追加
- 默认 Shell 已是 zsh 时不会重复切换

如果 `~/.config/ghostty/config` 或 `~/.config/starship.toml` 内容不同，脚本会先备份再替换。安装脚本不会覆盖内容不同的 `/etc/apt/sources.list.d/deb-free.griffo.io.list` 或 `/etc/apt/sources.list.d/yazi.list`，需要先由用户确认这些文件的用途。

## 备份与恢复

安装脚本只在替换已有配置时创建：

```text
~/.config-backup/<时间戳>/ghostty-config
~/.config-backup/<时间戳>/starship.toml
~/.config-backup/<时间戳>/maple-mono-nf-cn-ghostty.conf
```

恢复命令：

```bash
rm -f ~/.config/ghostty/config ~/.config/starship.toml
cp -a ~/.config-backup/<时间戳>/ghostty-config ~/.config/ghostty/config
cp -a ~/.config-backup/<时间戳>/starship.toml ~/.config/starship.toml
```

如果备份目录包含 `maple-mono-nf-cn-ghostty.conf`，可以将其恢复到 `~/.config/fontconfig/conf.d/99-maple-mono-nf-cn-ghostty.conf`。

只会为确实被替换的配置创建对应备份文件。

zsh 配置不会覆盖原文件，而是写在以下标记之间：

```text
# >>> linux-ghostty-terminal-config >>>
# <<< linux-ghostty-terminal-config <<<
```

卸载 zsh 配置时，编辑 `~/.zshrc`，删除这两个标记及其之间的全部内容即可。

安装器不会自动卸载 APT 软件包、删除 Ghostty 或 Yazi 软件源、删除 `~/.local/share/zsh-completions` 或删除已安装的字体，避免影响这些组件的其他用途。如确认不再使用，请自行清理。

## 常见问题

### Ghostty 中文字形与 Maple CN 不同

Fontconfig 的等宽分类和中文字体回退规则可能影响 Ghostty 请求的字体。此规则只处理明确指定 `Maple Mono NF CN` 的请求，保留该字体优先级并使用字体原生的双宽分类，不修改系统默认字体。Debian 不依赖 Ubuntu 的 `language-selector` 规则，是否需要修复以实际字体匹配结果为准。

已有安装可以运行 `bash configure-fonts.sh` 补上规则，然后完全退出 Ghostty 的旧进程再重新打开。用实际的中文语言环境验证：

```bash
LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8 ghostty +show-face --string='ABC文档下载'
```

这些字符都应匹配 `Maple Mono NF CN`。仅在英文语言环境中测试可能无法发现上述问题。

### 窗口没有毛玻璃模糊效果

`background-blur` 只在支持客户端模糊的桌面环境下生效，例如 KDE Plasma。Debian 默认的 GNOME 不支持，这是桌面环境的限制而不是配置问题；窗口透明度仍然正常生效。如需模糊效果可改用 KDE Plasma，或删除 `ghostty/config` 中的 `background-blur` 一行。

### 图标显示为方框

确认字体已安装并被 fontconfig 识别：

```bash
fc-list | grep -i "Maple Mono NF CN" | head -3
```

如果输出为空，重新执行安装脚本或按「手动安装」第 2 步安装字体，然后刷新缓存并重启 Ghostty：

```bash
fc-cache -fv
```

### 找不到软件包

确认系统为 Debian 13 Trixie，并检查 Ghostty 免费 trixie 源和各包的候选版本：

```bash
apt-cache policy ghostty starship eza bat
```

然后重新运行：

```bash
sudo apt-get update
```

Debian 13 官方源不提供 `ghostty`，需确认已添加 `deb-free.griffo.io` 的 `trixie` 源，且其签名密钥可读。若出现订阅认证错误，请检查是否误用了付费的 `deb.griffo.io` 源。

### Yazi 软件源冲突

如果脚本提示 `/etc/apt/sources.list.d/yazi.list` 内容不同，请先查看文件：

```bash
cat /etc/apt/sources.list.d/yazi.list
```

确认不需要原有配置后再删除该文件并重新运行安装脚本。脚本不会自动覆盖来源不明的软件源配置。

### zsh 插件加载失败

检查文件是否存在：

```bash
ls ~/.local/share/zsh-completions/src
ls /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
ls /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
```

如果后两个文件不存在，请重新安装对应 Debian 软件包。

### 重新登录后仍是 Bash

检查登录 Shell：

```bash
getent passwd "$USER" | cut -d: -f7
```

如果不是 `/usr/bin/zsh`，重新执行：

```bash
sudo chsh -s /usr/bin/zsh "$USER"
```

然后注销并重新登录。部分桌面环境还需要在终端模拟器的配置中指定启动 `zsh`。
