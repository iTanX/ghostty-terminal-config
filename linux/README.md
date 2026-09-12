# WSL Ubuntu 26.04 Shell Config

适用于 **WSL 2 下的 Ubuntu 26.04 LTS**，提供 Starship 彩虹条提示符、zsh 插件、模糊搜索、智能目录跳转、文件管理器和常用命令别名。

本目录与仓库根目录的 macOS 配置完全独立，只安装和配置 WSL 内的 Shell 工具，不安装或修改终端模拟器配置。

## 效果

- Starship 彩虹条提示符
- zsh Tab 补全、语法高亮和历史命令自动建议
- fzf 模糊搜索历史命令与文件
- zoxide 智能目录跳转
- Yazi 终端文件管理器
- eza、batcat 常用命令别名

## 包含的配置文件

| 文件 | 说明 | 安装位置 |
|------|------|---------|
| `linux/starship/starship.toml` | Starship 彩虹条提示符配置 | `~/.config/starship.toml` |
| `linux/zsh/.zshrc` | Ubuntu 版 zsh 配置 | 追加到 `~/.zshrc` 的受控标记块内 |
| `linux/install.sh` | Ubuntu 26.04 一键安装脚本 | 从仓库根目录运行 |

## 前置条件

- WSL 2
- Ubuntu 26.04 LTS
- 当前 WSL 用户具有 `sudo` 权限
- 可以访问 Ubuntu 软件源、GitHub 和 Yazi 官方软件源

建议将仓库克隆到 WSL 的 Linux 文件系统（例如 `~/ghostty-terminal-config`），不要放在 `/mnt/c` 等 Windows 挂载目录中，以避免文件权限和 I/O 性能差异。

## 字体准备

Starship 和 eza 使用 Nerd Font 图标。通过 Windows Terminal 或其他 Windows 终端使用 WSL 时，字体由 **Windows 主机**渲染，不能只安装到 Ubuntu 中。

1. 从 [Maple Mono 官方 Release](https://github.com/subframe7536/maple-font/releases) 下载并在 Windows 中安装 Maple Mono NF。
2. 在所用终端的 Ubuntu/WSL 配置中，将字体选择为 `Maple Mono NF`。
3. Windows Terminal 可在“设置 → Ubuntu 配置文件 → 外观 → 字体”中修改，具体可参考 [Windows Terminal 外观设置](https://learn.microsoft.com/windows/terminal/customize-settings/profile-appearance)。

未安装 Nerd Font 不影响命令执行，但提示符和文件图标可能显示为方框。

## 一键安装

### 1. 下载仓库

在 WSL Ubuntu 中运行：

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
bash linux/install.sh
```

安装前会询问确认，确认后自动执行：

1. 检查当前系统是否为 Ubuntu 26.04 LTS
2. 启用 Ubuntu `universe` 源
3. 添加使用独立 keyring 和 `signed-by` 的 Yazi 官方稳定版 APT 源
4. 安装 zsh、Starship、fzf、zoxide、eza、bat、Yazi 和两个 zsh 插件
5. 从官方仓库安装 zsh-completions 到 `~/.local/share/zsh-completions`
6. 备份并安装 Starship 配置
7. 将 Linux zsh 配置追加到 `~/.zshrc`
8. 将当前 WSL 用户的默认 Shell 切换为 zsh

### 3. 重新打开 WSL

关闭当前 WSL 终端窗口并重新打开 Ubuntu。新会话应直接进入 zsh 并显示 Starship 提示符。

如果仍然进入 Bash，请在 Windows PowerShell 中执行：

```powershell
wsl --shutdown
```

然后重新打开 Ubuntu。

## 依赖来源

| 工具 | 用途 | 来源 |
|------|------|------|
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
  file zsh starship fzf zoxide eza bat yazi \
  zsh-autosuggestions zsh-syntax-highlighting

mkdir -p ~/.local/share
git clone --depth 1 \
  https://github.com/zsh-users/zsh-completions.git \
  ~/.local/share/zsh-completions
```

如果 `~/.local/share/zsh-completions` 已存在且包含 `src` 目录，请跳过 `git clone`。

### 2. 备份并部署配置

```bash
BACKUP_DIR="$HOME/.config-backup/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR" ~/.config

# 仅在已有 Starship 配置时备份
if [ -e ~/.config/starship.toml ] || [ -L ~/.config/starship.toml ]; then
  cp -a ~/.config/starship.toml "$BACKUP_DIR/starship.toml"
fi

rm -f ~/.config/starship.toml
cp linux/starship/starship.toml ~/.config/starship.toml
```

将 zsh 配置追加到现有文件尾部：

```bash
{
  echo ""
  echo "# >>> wsl-ubuntu-shell-config >>>"
  echo "# 以下内容由 WSL Ubuntu shell 配置安装脚本自动追加"
  echo "# 删除方法: 移除从 >>> 到 <<< 之间的所有内容"
  cat linux/zsh/.zshrc
  echo "# <<< wsl-ubuntu-shell-config <<<"
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
|------------|---------|
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

检查依赖和默认 Shell：

```bash
command -v zsh starship fzf zoxide eza batcat yazi
getent passwd "$USER" | cut -d: -f7
```

预期第二条命令输出 `/usr/bin/zsh`。

检查插件与 zsh 配置：

```bash
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
- Starship 配置内容相同时不会重复复制或备份
- `~/.zshrc` 中存在 Linux 配置 marker 时不会再次追加
- 默认 Shell 已是 zsh 时不会重复切换

如果 `~/.config/starship.toml` 内容不同，脚本会先备份再替换。安装脚本不会覆盖内容不同的 `/etc/apt/sources.list.d/yazi.list`，需要先由用户确认该文件的用途。

## 备份与恢复

安装脚本只在替换已有 Starship 配置时创建：

```text
~/.config-backup/<时间戳>/starship.toml
```

恢复命令：

```bash
rm -f ~/.config/starship.toml
cp -a ~/.config-backup/<时间戳>/starship.toml ~/.config/starship.toml
```

zsh 配置不会覆盖原文件，而是写在以下标记之间：

```text
# >>> wsl-ubuntu-shell-config >>>
# <<< wsl-ubuntu-shell-config <<<
```

卸载 zsh 配置时，编辑 `~/.zshrc`，删除这两个标记及其之间的全部内容即可。

安装器不会自动卸载 APT 软件包、删除 Yazi 软件源或删除 `~/.local/share/zsh-completions`，避免影响这些组件的其他用途。如确认不再使用，请自行清理。

## 常见问题

### 图标显示为方框

确认 Maple Mono NF 已安装在 Windows 主机，并且当前 WSL 终端配置确实选择了该字体。只在 Ubuntu 中安装字体对 Windows 终端无效。

### 找不到软件包

确认系统确实为 Ubuntu 26.04，并检查 `universe` 是否启用：

```bash
apt-cache policy starship eza bat
```

然后重新运行：

```bash
sudo apt-get update
```

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

### 重新打开 WSL 后仍是 Bash

检查登录 Shell：

```bash
getent passwd "$USER" | cut -d: -f7
```

如果不是 `/usr/bin/zsh`，重新执行：

```bash
sudo chsh -s /usr/bin/zsh "$USER"
```

然后在 Windows PowerShell 中运行 `wsl --shutdown`，再重新打开 Ubuntu。
