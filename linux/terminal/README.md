# Ubuntu 26.04 Desktop Shell Config

适用于 **Ubuntu 26.04 LTS 桌面版**，提供 Ghostty 终端模拟器、Starship 彩虹条提示符、zsh 插件、模糊搜索、智能目录跳转、文件管理器和常用命令别名。

> WSL 用户请改用 [`wsl/`](../../wsl/) 目录。WSL 内没有图形界面，不需要也无法安装 Ghostty，那边只配置 Shell 工具。

本目录与仓库根目录的 macOS 配置相互独立，各自安装对应平台的终端模拟器与字体。

## 效果

- Ghostty 终端：半透明窗口、Catppuccin Mocha 主题、Maple Mono NF 字体
- Starship 彩虹条提示符
- zsh Tab 补全、语法高亮和历史命令自动建议
- fzf 模糊搜索历史命令与文件
- zoxide 智能目录跳转
- Yazi 终端文件管理器
- eza、batcat 常用命令别名

## 包含的配置文件

| 文件 | 说明 | 安装位置 |
|------|------|---------|
| `linux/terminal/ghostty/config` | Ghostty 终端配置（字体、主题、窗口、光标） | `~/.config/ghostty/config` |
| `linux/terminal/starship/starship.toml` | Starship 彩虹条提示符配置 | `~/.config/starship.toml` |
| `linux/terminal/zsh/.zshrc` | Ubuntu 版 zsh 配置 | 追加到 `~/.zshrc` 的受控标记块内 |
| `linux/terminal/install.sh` | Ubuntu 26.04 一键安装脚本 | 从仓库根目录运行 |

## 前置条件

- Ubuntu 26.04 LTS 桌面版（Ghostty 官方软件包自 26.04 起提供）
- 当前用户具有 `sudo` 权限
- 可以访问 Ubuntu 软件源、GitHub 和 Yazi 官方软件源

## 与 macOS 版 Ghostty 配置的差异

两边配置基本一致，只有三个键在 Linux 上不起作用，因此未启用：

| 配置项 | 说明 |
|--------|------|
| `font-thicken` | 字体加粗渲染，仅 macOS 支持 |
| `macos-titlebar-style` | 标签页融入标题栏，仅 macOS 支持 |
| `window-save-state` | 退出后保留窗口状态，仅 macOS 支持，在 Linux 上无任何效果 |

其余字体、字号、主题、内边距、透明度、光标和交互设置与 macOS 版保持一致。

另外 `background-blur`（毛玻璃模糊）只在部分桌面环境下生效，例如 KDE Plasma。Ubuntu 默认的 GNOME 不支持客户端模糊，此时窗口透明度仍然生效，只是没有模糊效果。

## 一键安装

### 1. 下载仓库

```bash
sudo apt-get update
sudo apt-get install -y git
cd ~
git clone --depth 1 https://github.com/iTanX/ghostty-terminal-config.git
cd ghostty-terminal-config
```

如果已经下载仓库，只需进入仓库根目录。

### 2. 运行安装脚本

```bash
bash linux/terminal/install.sh
```

脚本会自动执行：

1. 检查当前系统是否为 Ubuntu 26.04 LTS
2. 启用 Ubuntu `universe` 源
3. 添加使用独立 keyring 和 `signed-by` 的 Yazi 官方稳定版 APT 源
4. 安装 Ghostty、zsh、Starship、fzf、zoxide、eza、bat、Yazi 和两个 zsh 插件
5. 从官方仓库安装 zsh-completions 到 `~/.local/share/zsh-completions`
6. 从官方 GitHub Release 下载 Maple Mono NF 字体并校验完整性，安装到 `~/.local/share/fonts/maple-mono-nf`
7. 备份并安装 Ghostty 和 Starship 配置
8. 将 Linux zsh 配置追加到 `~/.zshrc`
9. 将当前用户的默认 Shell 切换为 zsh

### 3. 重新登录

注销后重新登录（或重启系统），新会话应直接进入 zsh 并显示 Starship 提示符，然后从应用列表启动 Ghostty。

## 依赖来源

| 工具 | 用途 | 来源 |
|------|------|------|
| Ghostty | GPU 加速终端模拟器 | Ubuntu 官方软件源（26.04 起） |
| Maple Mono NF | 终端字体（Nerd Font，中文显示优秀） | [Maple Font Release](https://github.com/subframe7536/maple-font/releases)，脚本下载并校验 sha256 |
| zsh | Shell | Ubuntu APT |
| Starship | 跨 Shell 提示符 | Ubuntu `universe` |
| fzf | 模糊搜索 | Ubuntu `universe` |
| zoxide | 智能目录跳转 | Ubuntu `universe` |
| eza | 替代 ls，支持彩色图标 | Ubuntu `universe` |
| bat | 替代 cat，Ubuntu 命令名为 `batcat` | Ubuntu `universe` |
| Yazi | 终端文件管理器 | [Yazi 官方 APT 源](https://yazi-rs.github.io/docs/installation/) |
| zsh-autosuggestions | 历史命令自动建议 | Ubuntu `universe` |
| zsh-syntax-highlighting | 命令语法高亮 | Ubuntu `universe` |
| zsh-completions | Tab 补全增强 | [zsh-users/zsh-completions](https://github.com/zsh-users/zsh-completions) |

字体版本固定在 `linux/terminal/install.sh` 顶部的 `MAPLE_VERSION`（当前 `v7.9`，与 macOS 端 cask 对齐），升级时只需改这一处。

Yazi 官方 APT 源提供 `amd64` 和 `arm64` 稳定版软件包。脚本不会使用已废弃的 `apt-key`，也不会安装 Rust/Cargo 编译环境。

## 手动安装

如果不运行安装脚本，可以按以下步骤手动部署。

### 1. 安装 APT 依赖

```bash
sudo apt-get update
sudo apt-get install -y software-properties-common ca-certificates curl gnupg git
sudo add-apt-repository -y universe
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
  file fontconfig unzip zsh ghostty starship fzf zoxide eza bat yazi \
  zsh-autosuggestions zsh-syntax-highlighting

mkdir -p ~/.local/share
git clone --depth 1 \
  https://github.com/zsh-users/zsh-completions.git \
  ~/.local/share/zsh-completions
```

如果 `~/.local/share/zsh-completions` 已存在且包含 `src` 目录，请跳过 `git clone`。

### 2. 安装 Maple Mono NF 字体

```bash
FONT_DIR="$HOME/.local/share/fonts/maple-mono-nf"
mkdir -p "$FONT_DIR" /tmp/maple-font && cd /tmp/maple-font

curl -fsSLO https://github.com/subframe7536/maple-font/releases/download/v7.9/MapleMono-NF.zip
curl -fsSLO https://github.com/subframe7536/maple-font/releases/download/v7.9/MapleMono-NF.sha256

# 官方 .sha256 文件里只有裸哈希，没有文件名，因此不能用 sha256sum -c
[ "$(tr -d '[:space:]' < MapleMono-NF.sha256)" = "$(sha256sum MapleMono-NF.zip | cut -d' ' -f1)" ] \
  && echo "校验通过" || echo "校验失败，请勿安装"

unzip -oq MapleMono-NF.zip -d extracted
find extracted -name '*.ttf' -exec cp -f {} "$FONT_DIR/" \;
printf 'v7.9\n' > "$FONT_DIR/.version"
fc-cache -f "$FONT_DIR"
```

### 3. 备份并部署配置

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
cp linux/terminal/ghostty/config ~/.config/ghostty/config
cp linux/terminal/starship/starship.toml ~/.config/starship.toml
```

将 zsh 配置追加到现有文件尾部：

```bash
{
  echo ""
  echo "# >>> linux-ghostty-terminal-config >>>"
  echo "# 以下内容由 Ubuntu shell 配置安装脚本自动追加"
  echo "# 删除方法: 移除从 >>> 到 <<< 之间的所有内容"
  cat linux/terminal/zsh/.zshrc
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
fc-list | grep -i "Maple Mono NF" | head -3
getent passwd "$USER" | cut -d: -f7
```

预期最后一条输出 `/usr/bin/zsh`。

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

- `universe` 和 Yazi APT 源不会重复添加
- 已存在且有效的 zsh-completions 会跳过
- 字体目录中记录的版本与 `MAPLE_VERSION` 相同时跳过下载
- Ghostty 和 Starship 配置内容相同时不会重复复制或备份
- `~/.zshrc` 中存在 Linux 配置 marker 时不会再次追加
- 默认 Shell 已是 zsh 时不会重复切换

如果 `~/.config/ghostty/config` 或 `~/.config/starship.toml` 内容不同，脚本会先备份再替换。安装脚本不会覆盖内容不同的 `/etc/apt/sources.list.d/yazi.list`，需要先由用户确认该文件的用途。

## 备份与恢复

安装脚本只在替换已有配置时创建：

```text
~/.config-backup/<时间戳>/ghostty-config
~/.config-backup/<时间戳>/starship.toml
```

恢复命令：

```bash
rm -f ~/.config/ghostty/config ~/.config/starship.toml
cp -a ~/.config-backup/<时间戳>/ghostty-config ~/.config/ghostty/config
cp -a ~/.config-backup/<时间戳>/starship.toml ~/.config/starship.toml
```

zsh 配置不会覆盖原文件，而是写在以下标记之间：

```text
# >>> linux-ghostty-terminal-config >>>
# <<< linux-ghostty-terminal-config <<<
```

卸载 zsh 配置时，编辑 `~/.zshrc`，删除这两个标记及其之间的全部内容即可。

安装器不会自动卸载 APT 软件包、删除 Yazi 软件源、删除 `~/.local/share/zsh-completions` 或删除已安装的字体，避免影响这些组件的其他用途。如确认不再使用，请自行清理。

## 常见问题

### 窗口没有毛玻璃模糊效果

`background-blur` 只在支持客户端模糊的桌面环境下生效，例如 KDE Plasma。Ubuntu 默认的 GNOME 不支持，这是桌面环境的限制而不是配置问题；窗口透明度仍然正常生效。如需模糊效果可改用 KDE Plasma，或删除 `linux/terminal/ghostty/config` 中的 `background-blur` 一行。

### 图标显示为方框

确认字体已安装并被 fontconfig 识别：

```bash
fc-list | grep -i "Maple Mono NF" | head -3
```

如果输出为空，重新执行安装脚本或按「手动安装」第 2 步安装字体，然后刷新缓存并重启 Ghostty：

```bash
fc-cache -fv
```

### 找不到软件包

确认系统确实为 Ubuntu 26.04，并检查 `universe` 是否启用：

```bash
apt-cache policy ghostty starship eza bat
```

然后重新运行：

```bash
sudo apt-get update
```

`ghostty` 需要 Ubuntu 26.04 或更新的版本，更早的 Ubuntu 官方源中没有该软件包。

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
