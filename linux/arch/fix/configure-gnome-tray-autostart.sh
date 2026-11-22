#!/usr/bin/env bash
# 为当前用户的 GNOME 自启动项配置托盘就绪等待。
set -euo pipefail

install_launcher() (
    local launcher="$1" staged

    if [[ ! -e "$launcher" && ! -L "$launcher" ]]; then
        mkdir -p -- "${launcher%/*}"
        staged=$(mktemp "${launcher}.tmp.XXXXXXXX")
        trap 'rm -f -- "$staged"' EXIT
        cat > "$staged" <<'BASH'
#!/usr/bin/env bash
# 等到托盘宿主就绪后，用原命令替换当前进程。
set -euo pipefail

if (( $# == 0 )); then
    printf '用法：gnome-tray-autostart 命令 [参数…]\n' >&2
    exit 1
fi

if command -v busctl >/dev/null; then
    watcher=org.kde.StatusNotifierWatcher
    deadline=$((SECONDS + 30))
    while (( SECONDS < deadline )); do
        if [[ $(busctl --user --auto-start=no --timeout=1s call \
            "$watcher" /StatusNotifierWatcher org.freedesktop.DBus.Properties Get \
            ss "$watcher" IsStatusNotifierHostRegistered 2>/dev/null) == 'v b true' ]]; then
            exec "$@"
        fi
        sleep 0.25
    done
    printf '托盘宿主在 30 秒内未就绪，继续启动应用。\n' >&2
else
    printf '缺少 busctl，直接启动应用。\n' >&2
fi
exec "$@"
BASH
        chmod 755 -- "$staged"
        # 用硬链接发布完整脚本，避免覆盖已有文件。
        if ln -T -- "$staged" "$launcher"; then
            printf '已安装等待脚本：%s\n' "$launcher"
        elif [[ ! -e "$launcher" && ! -L "$launcher" ]]; then
            return 1
        fi
    fi
    if [[ ! -f "$launcher" || ! -x "$launcher" ]]; then
        printf '已有等待脚本无法执行：%s\n' "$launcher" >&2
        return 1
    fi
)

quote_exec_path() {
    local value=${1//%/%%}
    if [[ "$value" == *[!a-zA-Z0-9_./%+-]* ]]; then
        # Desktop Entry 的字符串转义先于 Exec 的引号转义。
        value=${value//\\/\\\\}
        value=${value//\"/\\\"}
        value=${value//\$/\\\$}
        value=${value//\`/\\\`}
        value=${value//\\/\\\\}
        value=${value//$'\n'/\\n}
        value="\"$value\""
    fi
    printf '%s' "$value"
}

wrap_exec() {
    local launcher_command="$1" launcher="$2"
    local line ending section='' prefix command existing found=false
    local section_pattern='^[[:blank:]]*\[([^]]+)\][[:space:]]*$'
    local exec_pattern='^([[:blank:]]*Exec[[:blank:]]*=[[:blank:]]*)([^[:space:]].*)$'
    local -a existing_commands=("$launcher_command" "$launcher" "\"$launcher\"" "${launcher##*/}" "\"${launcher##*/}\"")

    # 只处理主段的 Exec，保留换行、注释和应用参数。
    while :; do
        if IFS= read -r line; then
            ending=$'\n'
        elif [[ -n "$line" ]]; then
            ending=''
        else
            break
        fi
        if [[ "$line" =~ $section_pattern ]]; then
            section=${BASH_REMATCH[1]}
        fi
        if [[ "$section" == 'Desktop Entry' && "$found" == false && "$line" =~ $exec_pattern ]]; then
            found=true
            prefix=${BASH_REMATCH[1]}
            command=${BASH_REMATCH[2]}
            line="$prefix$launcher_command $command"
            for existing in "${existing_commands[@]}"; do
                if [[ "$command" == "$existing" || "$command" == "$existing"[[:space:]]* ]]; then
                    line="$prefix$command"
                    break
                fi
            done
        fi
        printf '%s%s' "$line" "$ending"
    done
}

if (( EUID == 0 )); then
    printf '请以 GNOME 桌面用户运行，不要使用 sudo。\n' >&2
    exit 1
fi

# 1. 安装等待脚本，复用已有文件。
launcher="$HOME/.local/bin/gnome-tray-autostart"
install_launcher "$launcher"
launcher_command=$(quote_exec_path "$launcher")

# 2. 扫描用户自启动项，只备份并替换需要修改的文件。
config_dir=${XDG_CONFIG_HOME:-$HOME/.config}
state_dir=${XDG_STATE_HOME:-$HOME/.local/state}
[[ "$config_dir" == /* ]] || config_dir="$HOME/.config"
[[ "$state_dir" == /* ]] || state_dir="$HOME/.local/state"
autostart_dir="$config_dir/autostart"
backup_dir=''
staged=''
trap 'if [[ -n "$staged" ]]; then rm -f -- "$staged"; fi' EXIT
shopt -s nullglob dotglob
for entry in "$autostart_dir"/*.desktop; do
    [[ -f "$entry" ]] || continue
    if [[ -z "$staged" ]]; then
        staged=$(mktemp "$autostart_dir/.tray-autostart.XXXXXXXX")
    fi
    wrap_exec "$launcher_command" "$launcher" < "$entry" > "$staged"
    if cmp -s -- "$entry" "$staged"; then
        continue
    fi
    if [[ -z "$backup_dir" ]]; then
        mkdir -p -- "$state_dir"
        backup_dir=$(mktemp -d "$state_dir/gnome-tray-autostart.XXXXXXXX")
        printf '原自启动文件备份：%s\n' "$backup_dir"
    fi
    chmod --reference="$entry" -- "$staged"
    cp -a -- "$entry" "$backup_dir/"
    mv -f -- "$staged" "$entry"
    staged=''
    printf '已配置：%s\n' "${entry##*/}"
done
if [[ -z "$backup_dir" ]]; then
    printf '没有需要更新的用户自启动项。\n'
fi
