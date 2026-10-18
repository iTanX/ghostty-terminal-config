# Linux Mint 22.3 Desktop Shell Config

适用于 **Linux Mint 22.3（Ubuntu 24.04 Noble 基础）**，提供 Starship 彩虹条提示符、zsh 插件、模糊搜索、智能目录跳转、文件管理器和常用命令别名。

> WSL 用户请改用 [`wsl/`](../../../wsl/) 目录。WSL 内没有图形界面，不需要也无法安装 Ghostty，那边只配置 Shell 工具。

本目录与仓库中的 macOS 配置相互独立。Ghostty 的 PPA、安装、配置部署与验证步骤已暂时注释；配置文件和相关代码保留，便于以后恢复。Maple Mono NF CN 字体仍用于 Shell 工具的图标显示。

## 效果

<!-- - Ghostty 终端：半透明窗口、Catppuccin Mocha 主题、Maple Mono NF CN 字体、10 号 -->
- Starship 彩虹条提示符
- zsh Tab 补全、语法高亮和历史命令自动建议
- fzf 模糊搜索历史命令与文件
- zoxide 智能目录跳转
- Yazi 终端文件管理器
- eza、batcat 常用命令别名

## 包含的配置文件

| 文件 | 说明 | 安装位置 |
|------|------|---------|
| `ghostty/config` | 保留的 Ghostty 终端配置，暂不部署 | 暂停安装 |
| `starship/starship.toml` | Starship 彩虹条提示符配置 | `~/.config/starship.toml` |
| `zsh/.zshrc` | Linux Mint 版 zsh 配置 | 追加到 `~/.zshrc` 的受控标记块内 |
| `install.sh` | Linux Mint 22.3 一键安装及更新脚本 | 可在任意目录运行（自动定位配置） |

配置目录遵循 `XDG_CONFIG_HOME`，未设置时使用 `~/.config`。`eza` 等程序仍可为目录名请求粗体，Starship 彩虹条路径保持原有常规样式。

## 前置条件

- Linux Mint 22.3，`/etc/os-release` 中的 `UBUNTU_CODENAME` 为 `noble`
- 当前用户具有 `sudo` 权限
- 可以访问 Mint / Ubuntu 软件源、GitHub、Starship 官网和 Yazi 官方软件源

<!-- Ghostty 相关说明暂时保留，恢复安装时可取消此注释。
## 与 macOS 版 Ghostty 配置的差异

两边配置基本一致，只有三个键在 Linux 上不起作用，因此未启用：

| 配置项 | 说明 |
|--------|------|
| `font-thicken` | 字体加粗渲染，仅 macOS 支持 |
| `macos-titlebar-style` | 标签页融入标题栏，仅 macOS 支持 |
| `window-save-state` | 退出后保留窗口状态，仅 macOS 支持，在 Linux 上无任何效果 |

Linux 版使用含中文的 NF CN 字体，字号为 10。主题、内边距、透明度、光标和交互设置与 macOS 版保持一致。

另外 `background-blur`（毛玻璃模糊）只在部分桌面环境下生效，例如 KDE Plasma。Linux Mint 默认的 Cinnamon 不支持客户端模糊，此时窗口透明度仍然生效，只是没有模糊效果。

-->

## 一键安装

在本 README 所在目录执行：

```bash
bash install.sh
```

脚本会自动执行：

1. 检查当前系统是否为 Linux Mint 22.3，Ubuntu 基础代号是否为 `noble`
2. 使用 Mint 自带的 Ubuntu 基础源（Ghostty PPA 步骤暂时注释）
3. 添加使用独立 keyring 和 `signed-by` 的 Yazi 官方稳定版 APT 源
4. 通过 APT 安装或更新 zsh、zoxide、eza、bat、Yazi 和两个 zsh 插件；通过上游安装器更新 Starship、fzf 到 `/usr/local/bin`
5. 首次克隆 zsh-completions 到 `~/.local/share/zsh-completions`，再次运行时执行 `git pull --ff-only`
6. 从官方 GitHub Release 下载 Maple Mono NF CN 字体并校验完整性，安装到 `~/.local/share/fonts/maple-mono-nf-cn`
7. 刷新字体缓存
8. 备份并安装 Starship 配置
9. 将 Linux zsh 配置追加到 `~/.zshrc`
10. 将当前用户的默认 Shell 切换为 zsh

### 3. 重新登录

注销后重新登录（或重启系统），新会话应直接进入 zsh 并显示 Starship 提示符。

## 依赖来源

| 工具 | 用途 | 来源 |
|------|------|------|
| Ghostty | 暂停安装 | 社区 PPA 和软件包安装代码已注释 |
| Maple Mono NF CN | 终端字体（含中文字形和 Nerd Font 图标） | [Maple Font Release](https://github.com/subframe7536/maple-font/releases)，脚本下载并校验 sha256 |
| zsh | Shell | Ubuntu APT |
| Starship | 跨 Shell 提示符 | [官方安装器](https://starship.rs/guide/)，安装到 `/usr/local/bin/starship` |
| fzf | 模糊搜索 | [上游安装器](https://github.com/junegunn/fzf#using-git)，安装到 `/usr/local/bin/fzf` |
| zoxide | 智能目录跳转 | Ubuntu `universe` |
| eza | 替代 ls，支持彩色图标 | Ubuntu `universe` |
| bat | 替代 cat，Ubuntu 命令名为 `batcat` | Ubuntu `universe` |
| Yazi | 终端文件管理器 | [Yazi 官方 APT 源](https://yazi-rs.github.io/docs/installation/) |
| zsh-autosuggestions | 历史命令自动建议 | Ubuntu `universe` |
| zsh-syntax-highlighting | 命令语法高亮 | Ubuntu `universe` |
| zsh-completions | Tab 补全增强 | [zsh-users/zsh-completions](https://github.com/zsh-users/zsh-completions) |

字体版本固定在 `install.sh` 顶部的 `MAPLE_VERSION`（当前 `v7.9`），升级时只需改这一处。

Yazi 官方 APT 源提供 `amd64` 和 `arm64` 稳定版软件包。脚本不会使用已废弃的 `apt-key`，也不会安装 Rust/Cargo 编译环境。

Starship 和 fzf 的安装文件放在临时目录，正常完成或失败退出时都会清理。fzf 使用 `--bin`，只获取可执行文件，不创建 `~/.fzf`，也不改写 Shell 配置；现有的 `source <(fzf --zsh)` 直接调用 `/usr/local/bin/fzf`。请确保 `/usr/local/bin` 在 `PATH` 中优先于 `/usr/bin`，避免调用系统仓库中的旧 fzf。

## 手动安装

如果不运行安装脚本，可以按以下步骤手动部署。

### 1. 安装 APT 依赖

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg git
# Ghostty PPA 暂时停用。
# sudo apt-get install -y mintsources
# sudo add-apt-repository -y ppa:mkasberg/ghostty-ubuntu
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
  file fontconfig unzip zsh zoxide eza bat yazi \
  zsh-autosuggestions zsh-syntax-highlighting
# sudo apt-get install -y ghostty

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

通过上游安装器安装或更新 Starship 和 fzf，下载目录用完即删：

```bash
(
  set -euo pipefail
  INSTALL_TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$INSTALL_TMP_DIR"' EXIT

  mkdir -p "$INSTALL_TMP_DIR/starship-bin"
  curl -fsSL https://starship.rs/install.sh -o "$INSTALL_TMP_DIR/starship-install.sh"
  TMPDIR="$INSTALL_TMP_DIR" sh "$INSTALL_TMP_DIR/starship-install.sh" --yes --bin-dir "$INSTALL_TMP_DIR/starship-bin"
  sudo install -Dm0755 "$INSTALL_TMP_DIR/starship-bin/starship" /usr/local/bin/starship

  git clone --depth 1 https://github.com/junegunn/fzf.git "$INSTALL_TMP_DIR/fzf"
  bash "$INSTALL_TMP_DIR/fzf/install" --bin
  # 安装器可能复用已安装的同版本文件，避免向自身复制。
  if [ ! "$INSTALL_TMP_DIR/fzf/bin/fzf" -ef /usr/local/bin/fzf ]; then
    sudo install -Dm0755 "$INSTALL_TMP_DIR/fzf/bin/fzf" /usr/local/bin/fzf
  fi
)
```

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

以下命令在本 README 所在目录（`linux/mint/terminal/`）执行。

```bash
BACKUP_DIR="$HOME/.config-backup/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR" ~/.config
# mkdir -p ~/.config/ghostty

# 仅在已有配置时备份
# if [ -e ~/.config/ghostty/config ] || [ -L ~/.config/ghostty/config ]; then
#   cp -a ~/.config/ghostty/config "$BACKUP_DIR/ghostty-config"
# fi
if [ -e ~/.config/starship.toml ] || [ -L ~/.config/starship.toml ]; then
  cp -a ~/.config/starship.toml "$BACKUP_DIR/starship.toml"
fi

# rm -f ~/.config/ghostty/config
rm -f ~/.config/starship.toml
# cp ghostty/config ~/.config/ghostty/config
cp starship/starship.toml ~/.config/starship.toml
```

将 zsh 配置追加到现有文件尾部：

```bash
{
  echo ""
  echo "# >>> linux-ghostty-terminal-config >>>"
  echo "# 以下内容由 Linux Mint shell 配置安装脚本自动追加"
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
command -v zsh starship fzf zoxide eza batcat yazi
# command -v ghostty
# ghostty --version
starship --version
fzf --version
fc-list | grep -i "Maple Mono NF CN" | head -3
fc-match 'Maple Mono NF CN:spacing=100:lang=zh-cn'
getent passwd "$USER" | cut -d: -f7
```

字体匹配预期为 Maple Mono NF CN；最后一条预期输出 `/usr/bin/zsh`。

检查 zsh 插件（Ghostty 验证暂时停用）：

```bash
# ghostty +validate-config
test -d ~/.local/share/zsh-completions/src && echo "zsh-completions: OK"
test -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh && echo "autosuggestions: OK"
test -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh && echo "syntax-highlighting: OK"
zsh -lic 'alias ls; alias cat; whence -w y'
```

随后可实际测试 `Ctrl+R`、`Ctrl+T`、Tab、`z`、`zi` 和 `y`。

## 重复运行

安装脚本可以重复运行：

- Yazi APT 源可重复配置，Ghostty PPA 暂时停用
- 每次刷新 APT 索引，并将脚本列出的 APT 软件包更新至当前软件源中的候选版本；不执行全系统升级
- 每次运行 Starship、fzf 上游安装器，安装或更新可执行文件
- 每次对已有 zsh-completions 执行 `git pull --ff-only`
- 字体目录中记录的版本与 `MAPLE_VERSION` 相同时跳过下载
- 每次都会刷新字体缓存
- Starship 配置内容相同时不会重复复制或备份
- `~/.zshrc` 中存在 Linux 配置 marker 时不会再次追加
- 默认 Shell 已是 zsh 时不会重复切换

如果 `~/.config/starship.toml` 内容不同，脚本会先备份再替换。安装脚本不会覆盖内容不同的 `/etc/apt/sources.list.d/yazi.list`，需要先由用户确认该文件的用途。

## 备份与恢复

安装脚本只在替换已有配置时创建：

```text
# ~/.config-backup/<时间戳>/ghostty-config（暂停备份）
~/.config-backup/<时间戳>/starship.toml
```

恢复命令：

```bash
# rm -f ~/.config/ghostty/config
rm -f ~/.config/starship.toml
# cp -a ~/.config-backup/<时间戳>/ghostty-config ~/.config/ghostty/config
cp -a ~/.config-backup/<时间戳>/starship.toml ~/.config/starship.toml
```

只会为确实被替换的配置创建对应备份文件。

zsh 配置不会覆盖原文件，而是写在以下标记之间：

```text
# >>> linux-ghostty-terminal-config >>>
# <<< linux-ghostty-terminal-config <<<
```

卸载 zsh 配置时，编辑 `~/.zshrc`，删除这两个标记及其之间的全部内容即可。

安装器不会自动卸载 APT 软件包、删除 Yazi 软件源、删除 `~/.local/share/zsh-completions` 或删除已安装的字体，避免影响这些组件的其他用途。如确认不再使用，请自行清理。

## 常见问题

<!-- Ghostty 暂停安装，对应问题说明保留。
### 窗口没有毛玻璃模糊效果

`background-blur` 只在支持客户端模糊的桌面环境下生效，例如 KDE Plasma。Linux Mint 默认的 Cinnamon 不支持，这是桌面环境的限制而不是配置问题；窗口透明度仍然正常生效。如需模糊效果可改用 KDE Plasma，或删除 `ghostty/config` 中的 `background-blur` 一行。

-->

### 图标显示为方框

确认字体已安装并被 fontconfig 识别：

```bash
fc-list | grep -i "Maple Mono NF CN" | head -3
```

如果输出为空，重新执行安装脚本或按「手动安装」第 2 步安装字体，然后刷新缓存并重新打开终端：

```bash
fc-cache -fv
```

### 找不到软件包

确认系统为 Linux Mint 22.3，检查 APT 软件包的候选版本：

```bash
apt-cache policy eza bat
# apt-cache policy ghostty
```

然后重新运行：

```bash
sudo apt-get update
```

Ghostty PPA 和安装步骤暂时注释。Starship 和 fzf 安装到 `/usr/local/bin`，不依赖 Noble 中缺失或较旧的 APT 包；请用 `command -v starship fzf` 和对应的 `--version` 检查实际调用的版本。

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

如果后两个文件不存在，请重新安装对应 Ubuntu 软件包。

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
