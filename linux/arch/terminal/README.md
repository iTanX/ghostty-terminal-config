# Arch Linux 终端配置

适用于 **Arch Linux、x86_64 架构**，提供 Ghostty、Starship、Zsh 插件、模糊搜索、智能目录跳转、Yazi 和常用命令别名。终端只配置 Ghostty，无需 GNOME Terminal。

## 效果

- Ghostty：半透明窗口、Catppuccin Mocha 主题、Maple Mono NF CN 字体、10 号
- Fontconfig：保留明确指定的 Maple CN 字体优先级，验证中英文环境下的常规、粗体匹配
- Starship 彩虹条提示符
- Zsh Tab 补全、语法高亮和历史命令自动建议
- fzf 模糊搜索、zoxide 目录跳转、Yazi 文件管理
- eza 和 bat 常用命令别名

## 包含的配置文件

| 文件 | 说明 | 安装位置 |
|------|------|----------|
| `ghostty/config` | Ghostty 字体、主题、窗口和交互配置 | `~/.config/ghostty/config` |
| `starship/starship.toml` | Starship 彩虹条提示符 | `~/.config/starship.toml` |
| `zsh/.zshrc` | Zsh 配置 | 追加到 `~/.zshrc` 的受控标记块内 |
| `install.sh` | 终端安装器 | 可在任意目录运行，自动定位资源 |
| `configure-fonts.sh` | 配置字体匹配，刷新缓存并验证 | 安装器自动调用，也可单独运行 |
| `fontconfig/99-maple-mono-nf-cn-ghostty.conf` | Maple CN 字体规则 | `~/.config/fontconfig/conf.d/` |

配置目录遵循 `XDG_CONFIG_HOME`，未设置时使用 `~/.config`。Ghostty 默认字体为 Regular；eza 等程序仍可为目录名请求粗体。

## 前置条件

- 官方 Arch Linux（`ID=arch`），`x86_64` 架构
- 已有可运行 Ghostty 的图形桌面环境
- 当前普通用户已安装 `sudo` 并具有相应权限
- 可以访问 Arch 官方软件仓库和 GitHub

## 安装

在本 README 所在目录运行：

```bash
bash install.sh
```

也可以从仓库根目录按顺序运行两个初始化脚本：

```bash
bash linux/arch/one_click_setup/01-basic-config.sh
bash linux/arch/one_click_setup/02-development-environment.sh
```

安装器会执行：

1. 检查操作系统、架构、sudo 和资源文件。
2. 使用 `pacman -Syu` 完整升级系统并安装辅助依赖。
3. 从官方仓库安装终端工具和 Zsh 插件。
4. 从 Maple Font 官方 Release 下载 `v7.9` 的 Maple Mono NF CN，校验 SHA-256 后安装。
5. 部署 Fontconfig 规则，刷新字体缓存并验证字体匹配。
6. 备份并部署 Ghostty 和 Starship 配置。
7. 将 Zsh 配置追加到 `~/.zshrc` 的受控标记块内。
8. 将当前用户的默认 Shell 切换为 Zsh。

完成后注销并重新登录，再打开 Ghostty。若 Ghostty 已在运行，请完全退出旧进程后重新打开。

## 依赖来源

| 工具 | 来源 |
|------|------|
| Ghostty、Yazi | Arch 官方仓库 |
| Zsh、Starship、fzf、zoxide、eza、bat | Arch 官方仓库 |
| zsh-autosuggestions、zsh-syntax-highlighting、zsh-completions | Arch 官方仓库 |
| Maple Mono NF CN | [Maple Font Release](https://github.com/subframe7536/maple-font/releases) |

辅助依赖与终端工具分组安装。无需额外 APT 源、AUR 助手或 Rust 编译环境。字体版本由 `install.sh` 中的 `MAPLE_VERSION` 控制。

Zsh 补全使用官方包安装的 `/usr/share/zsh/site-functions/`，两个插件使用 `/usr/share/zsh/plugins/` 下的路径。bat 的命令名为 `bat`。

## 开发环境

`02-development-environment.sh` 使用 mise 管理以下工具：

| 工具 | 版本范围 |
|------|----------|
| Python | `3.14`，跟进 `3.14.x` |
| uv | `latest`，跟进最新稳定版 |
| Node.js | `24`，跟进 `24.x` |
| Java | `temurin-25`，跟进 Temurin JDK 25 更新 |
| Maven | `3.9`，跟进 `3.9.x` |

Python 的 `python` 和 `python3` 命令均由 mise 管理的 Python 3.14 提供。无需安装 `python-is-python3`，也不需要额外安装系统 Python、nvm 或 SDKMAN。

Maven 的 `settings.xml` 仍部署到 `~/.m2/settings.xml`，替换前备份原文件。Claude Code 和 Codex 由开发环境脚本分别通过 npm 全局安装，独立管理安装与更新。

`../one_click_setup/assets/mise.toml` 部署到 `${XDG_CONFIG_HOME:-~/.config}/mise/config.toml`，已有不同配置会先备份到 `~/.config-backup/<时间戳>/mise-config.toml`。这是本套脚本管理的全局配置，额外的全局工具需要自行合并。工具版本使用浮动范围，更新时不会跨越上述版本线。

自动更新使用 mise 的原生 `tool-update` 用户服务：服务每小时检查一次，每个工具按 24 小时间隔检查更新。需要支持该功能的 mise 版本，当前 Arch 仓库为 `2026.11.8`。服务在用户管理器运行期间工作，未启用退出登录后持续运行。mise 自身随 pacman 更新。

检查自动更新服务，或手动更新全局工具：

```bash
mise bootstrap services status
systemctl --user status dev.mise.mise-tool-update.service
mise --yes upgrade --global
```

手动更新遵循版本范围，不使用会改写版本范围的 `--bump`。

新开 Zsh 会话后可验证工具：

```bash
python --version
python3 --version
uv --version
node --version
npm --version
java -version
mvn --version
claude --version
codex --version
```

非交互脚本使用 `mise exec -- <命令>` 加载工具环境；交互 Zsh 使用脚本追加的 `eval "$(mise activate zsh)"`。

脚本会创建以下链接，允许目标文件暂时不存在，之后再同步：

```text
~/.claude/CLAUDE.md -> ~/.agents/AGENTS.md
~/.codex/AGENTS.md  -> ~/.agents/AGENTS.md
```

## 快捷键与命令

| 快捷键或命令 | 功能 |
|--------------|------|
| `→`、`Ctrl+F` | 接受历史命令建议 |
| `Ctrl+R` | 模糊搜索历史命令 |
| `Ctrl+T` | 模糊搜索文件 |
| `命令 **<Tab>` | fzf 补全 |
| `Tab` | Zsh 补全 |
| `ls`、`lsa` | eza 列表，后者显示隐藏文件 |
| `ll`、`lla` | eza 详细列表，后者显示隐藏文件 |
| `lt`、`lta` | eza 两层目录树，后者显示隐藏文件 |
| `cat 文件名` | `bat --paging=never --style=plain` |
| `z foo`、`zi foo` | 智能跳转、交互选择目录 |
| `yazi` | 打开文件管理器，退出后保留原目录 |
| `y` | 退出 Yazi 后进入最后浏览的目录 |

## 验证

```bash
command -v zsh ghostty starship fzf zoxide eza bat yazi
fc-match 'Maple Mono NF CN:spacing=100:lang=zh-cn'
getent passwd "$USER" | cut -d: -f7
ghostty +validate-config
test -d /usr/share/zsh/site-functions && printf 'zsh-completions: OK\n'
test -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh && printf 'autosuggestions: OK\n'
test -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh && printf 'syntax-highlighting: OK\n'
zsh -lic 'alias ls; alias cat; whence -w y'
```

字体匹配预期为 Maple Mono NF CN，登录 Shell 预期为 `/usr/bin/zsh`。随后实际测试补全、搜索、目录跳转和中文显示。

当前开发环境为 macOS，适配只进行了静态检查和隔离验证，仍需在 Arch 实机验证安装、字体显示及图形会话。

## 重复运行与恢复

- 每次运行安装器都会通过 pacman 完整升级系统，再安装或核对依赖和工具。
- 字体版本与 `MAPLE_VERSION` 相同时跳过下载。
- 每次核对 Fontconfig 规则、刷新缓存并验证匹配结果。
- Ghostty 和 Starship 配置相同时跳过复制；替换前备份到 `~/.config-backup/<时间戳>/`。
- `~/.zshrc` 已有 Linux 配置标记时跳过追加。
- 默认 Shell 已是 Zsh 时跳过切换。

备份目录按实际替换的文件包含以下内容：

```text
~/.config-backup/<时间戳>/ghostty-config
~/.config-backup/<时间戳>/starship.toml
~/.config-backup/<时间戳>/maple-mono-nf-cn-ghostty.conf
```

恢复时，将所需备份复制回对应配置路径。删除 Shell 配置时，在 `~/.zshrc` 中删除以下两个标记及其之间的内容：

```text
# >>> linux-ghostty-terminal-config >>>
# <<< linux-ghostty-terminal-config <<<
```

安装器不自动卸载软件包或删除字体。

## 常见问题

### 中文字形不符合预期

重新运行 `bash configure-fonts.sh`，然后完全退出 Ghostty 再打开。中文语言环境已生成时，可以进一步检查：

```bash
LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8 ghostty +show-face --string='ABC文档下载'
```

这些字符应匹配 Maple Mono NF CN。规则只处理明确指定该字体的请求，不修改系统默认字体。

### 窗口没有毛玻璃效果

`background-blur` 是否生效取决于桌面合成器。桌面不支持客户端模糊时，透明度仍可正常生效。

### 找不到软件包

确认运行的是官方 Arch Linux，官方仓库已启用，镜像可用，然后执行完整升级。不要使用 `pacman -Sy` 后仅升级个别软件包。

### 重新登录后仍是 Bash

检查登录 Shell：

```bash
getent passwd "$USER" | cut -d: -f7
```

如需手动设置：

```bash
sudo chsh -s /usr/bin/zsh "$USER"
```

注销后重新登录。若终端另行指定了启动命令，也需要检查该设置。
