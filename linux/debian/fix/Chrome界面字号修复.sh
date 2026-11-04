#!/bin/bash
# 为采用 GTK 4 的 Linux Google Chrome 单独设置字号和半粗体（600），可重复执行。
# 配置内容只在内存中处理，不创建临时文件、备份或缓存。
set -euo pipefail

fail() {
    printf '错误：%s\n' "$*" >&2
    exit 1
}

trap 'printf "错误：配置未全部完成，请检查报错后重新运行。\n" >&2' ERR
trap 'printf "\n已中断；如在写入期间中断，可再次运行完成配置。\n" >&2; exit 130' INT

[[ $(uname -s) == Linux ]] || fail '此脚本仅适用于 Linux。'
(( EUID != 0 )) || fail '请用桌面登录用户运行，不要使用 sudo 或 root。'
chrome=$(command -v google-chrome-stable || command -v google-chrome || true)
[[ -n $chrome && $chrome == /* ]] || fail '未找到 Google Chrome，请先安装 Chrome。'
data_home=${XDG_DATA_HOME:-$HOME/.local/share}
[[ $data_home == /* ]] || fail 'XDG_DATA_HOME 必须是绝对路径。'
# desktop 启动命令中的百分号是特殊占位符，避免将特殊路径写成错误命令。
for value in "$HOME" "$data_home" "$chrome"; do
    [[ $value != *$'\n'* && $value != *$'\r'* && $value != *%* ]] || fail '配置路径不能包含换行或百分号。'
done

theme=$data_home/themes/Chrome-Compact/gtk-4.0/gtk.css
wrapper=$HOME/.local/bin/google-chrome-compact
apps=$data_home/applications
marker='Chrome 独立界面字号配置'
names=()
sources=()
IFS=: read -r -a data_dirs <<< "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
for name in google-chrome.desktop com.google.Chrome.desktop; do
    for directory in "${data_dirs[@]}"; do
        if [[ -n $directory && -f $directory/applications/$name ]]; then
            names+=("$name")
            sources+=("$directory/applications/$name")
            break
        fi
    done
done
[[ ${names[0]:-} == google-chrome.desktop ]] || fail '未找到 Chrome 系统启动项，未修改文件。'

# 检查配置归属；兼容之前已经安装的同一方案。
for path in "$theme" "$wrapper"; do
    [[ ! -L $path ]] || fail "目标是符号链接，请先检查：$path"
    if [[ -e $path ]]; then
        [[ -f $path ]] || fail "目标不是普通文件：$path"
        text=$(< "$path")
        [[ $text == *"$marker"* ||
           ( $path == "$theme" && $text == *'只为使用此主题的 Chrome 缩小界面字号'* ) ||
           ( $path == "$wrapper" && $text == *'仅为从此入口启动的 Chrome 使用'* ) ]] || fail "已有非本方案的同名文件：$path"
    fi
done

current=9
if [[ -f $theme ]]; then
    text=$(< "$theme")
    if [[ $text =~ font-size:[[:space:]]*([0-9]+([.][0-9]+)?)pt ]]; then
        current=${BASH_REMATCH[1]}
    fi
fi
printf '为 Chrome 单独设置界面字号与半粗体（600），保留系统字体设置与显示缩放。\n'
printf '支持 1～72 pt，最多两位小数，例如 9、9.5、10；输入 q 取消。\n'
while true; do
    printf '请输入字号 [回车保留 %s pt]：' "$current"
    if ! IFS= read -r answer; then
        printf '\n未收到输入，已取消，未修改文件。\n'
        exit 0
    fi
    [[ ${answer,,} != q ]] || { printf '已取消，未修改文件。\n'; exit 0; }
    answer=${answer:-$current}
    if [[ $answer =~ ^([0-9]{1,2})([.]([0-9]{1,2}))?$ ]]; then
        integer=$((10#${BASH_REMATCH[1]}))
        fraction=${BASH_REMATCH[3]:-0}
        fraction=${fraction}00
        fraction=${fraction:0:2}
        hundredths=$((integer * 100 + 10#$fraction))
        if (( hundredths >= 100 && hundredths <= 7200 )); then
            size=$integer
            fraction=${fraction%0}
            fraction=${fraction%0}
            [[ -z $fraction ]] || size+=.$fraction
            break
        fi
    fi
    printf '请输入 1～72 之间的数字，最多两位小数，或输入 q 取消。\n'
done

# desktop 文件先解析字符串转义，再解析 Exec 命令行。
desktop_quote() {
    local value=$1 char escaped= i
    for ((i=0; i<${#value}; i++)); do
        char=${value:i:1}
        case $char in
            '\'|'"'|'`'|'$') escaped+="\\$char" ;;
            *) escaped+=$char ;;
        esac
    done
    escaped=${escaped//\\/\\\\}
    printf '"%s"' "$escaped"
}

paths=("$theme" "$wrapper")
contents=()
printf -v text '/* %s：沿用 GTK 默认外观，设置界面字号和半粗体。 */\n@import url("resource:///org/gtk/libgtk/theme/Default/gtk.css");\n\n* {\n  font-size: %spt;\n  font-weight: 600;\n}\n' "$marker" "$size"
contents+=("$text")
printf -v text '#!/bin/bash\n# %s：仅为此入口启动的 Chrome 使用 %s pt 字体。\nexport GTK_THEME=Chrome-Compact\nexec %q "$@"\n' "$marker" "$size" "$chrome"
contents+=("$text")
quoted_wrapper=$(desktop_quote "$wrapper")
exec_pattern='^Exec=("[^"]+"|[^[:space:]]+)(.*)$'
for i in "${!names[@]}"; do
    target=$apps/${names[i]}
    [[ ! -L $target ]] || fail "启动项是符号链接，请先检查：$target"
    source=${sources[i]}
    if [[ -e $target ]]; then
        [[ -f $target ]] || fail "启动项不是普通文件：$target"
        source=$target
    fi
    text=
    count=0
    # 保留已有启动项的图标、名称和附加参数，只替换 Chrome 命令。
    while IFS= read -r line || [[ -n $line ]]; do
        if [[ $line == Exec=* ]]; then
            [[ $line =~ $exec_pattern ]] || fail "无法解析启动命令：$source"
            executable=${BASH_REMATCH[1]}
            suffix=${BASH_REMATCH[2]}
            executable=${executable#\"}
            executable=${executable%\"}
            case ${executable##*/} in
                google-chrome|google-chrome-stable|google-chrome-compact) ;;
                *) fail "启动项已有其他包装命令，请先检查：$source" ;;
            esac
            line=Exec=$quoted_wrapper$suffix
            count=$((count + 1))
        fi
        case $line in
            '# 用户级覆盖：'*|'# 与常规入口一致，'*) continue ;;
        esac
        text+=$line$'\n'
    done < "$source"
    (( count > 0 )) || fail "启动项没有 Exec 命令：$source"
    paths+=("$target")
    contents+=("$text")
done

# 所有内容检查完成后再写入；重复设置相同字号时不重写配置。
for i in "${!paths[@]}"; do
    path=${paths[i]}
    text=${contents[i]}
    if [[ ! -f $path ]] || [[ $(< "$path") != "${text%$'\n'}" ]]; then
        mkdir -p -- "${path%/*}"
        printf '%s' "$text" > "$path"
    fi
done
chmod u+x -- "$wrapper"
printf '\n已将 Chrome 独立界面字号设为 %s pt，字重设为 600（Semi-Bold）。\n' "$size"
printf '请从 Chrome 菜单选择“退出”，再从应用列表重新打开。\n'
printf '如果启动入口仍未刷新，请注销桌面后重新登录。\n'
printf '以后再次运行本脚本即可修改字号。未创建临时文件、备份或缓存。\n'
printf '仅保留以下必需配置：\n'
printf '  %s\n' "${paths[@]}"
