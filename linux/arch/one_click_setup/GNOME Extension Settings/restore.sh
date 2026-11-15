#!/usr/bin/env bash
# 只恢复有已保存配置的 6 个扩展；使用 --enable 时额外启用这 6 个扩展。
set -euo pipefail

backup_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
enable_extensions=false
case "${1:-}" in
    '') ;;
    --enable) enable_extensions=true ;;
    -h|--help)
        printf '用法：bash "%s" [--enable]\n默认只恢复设置；--enable 额外启用清单内的扩展，不禁用其他扩展。\n' "$0"
        exit 0
        ;;
    *) printf '未知参数：%s\n' "$1" >&2; exit 1 ;;
esac
if (( $# > 1 )); then
    printf '参数过多，请使用 --help 查看用法。\n' >&2
    exit 1
fi
command -v dconf >/dev/null || { printf '找不到 dconf 命令，无法恢复设置。\n' >&2; exit 1; }
[[ -r "$backup_dir/settings.tsv" && -r "$backup_dir/enabled-extensions.txt" ]] || {
    printf '备份清单缺失，请保留完整的备份目录。\n' >&2
    exit 1
}

# 写入前检查全部备份文件，避免恢复到一半才发现文件缺失。
while IFS=$'\t' read -r uuid path file; do
    [[ -n "$uuid" ]] || continue
    [[ "$path" == /org/gnome/shell/extensions/*/ && "$file" == settings/* && -r "$backup_dir/$file" && -s "$backup_dir/$file" ]] || {
        printf '无效或缺失的备份项：%s\n' "$uuid" >&2
        exit 1
    }
done < "$backup_dir/settings.tsv"
if "$enable_extensions"; then
    command -v gnome-extensions >/dev/null || { printf '缺少 gnome-extensions 命令。\n' >&2; exit 1; }
    while IFS= read -r uuid; do
        [[ -n "$uuid" ]] || continue
        gnome-extensions info "$uuid" >/dev/null || {
            printf '请先安装此扩展，并让 GNOME Shell 加载它：%s\n' "$uuid" >&2
            exit 1
        }
    done < "$backup_dir/enabled-extensions.txt"
fi

# 恢复前保存目标路径的现状，导出全部成功后才开始覆盖。
umask 077
before_dir="$(mktemp -d "$backup_dir/恢复前设置-$(date +%Y%m%d-%H%M%S)-XXXXXX")"
mkdir -- "$before_dir/settings"
cp -- "$backup_dir/settings.tsv" "$before_dir/settings.tsv"
while IFS=$'\t' read -r uuid path file; do
    [[ -n "$uuid" ]] || continue
    dconf dump "$path" > "$before_dir/$file"
done < "$backup_dir/settings.tsv"
printf '恢复前的设置已保存到：%s\n' "$before_dir"
trap 'printf "恢复未完成。恢复前的设置位于：%s\n" "$before_dir" >&2' ERR

while IFS=$'\t' read -r uuid path file; do
    [[ -n "$uuid" ]] || continue
    # 先清除目标路径，才能让备份中未显式设置的项目恢复为扩展默认值。
    dconf reset -f "$path"
    dconf load "$path" < "$backup_dir/$file"
    printf '已恢复：%s\n' "$uuid"
done < "$backup_dir/settings.tsv"
if "$enable_extensions"; then
    while IFS= read -r uuid; do
        [[ -n "$uuid" ]] || continue
        gnome-extensions enable "$uuid"
    done < "$backup_dir/enabled-extensions.txt"
    printf '已启用清单内的扩展。若 GNOME 的扩展总开关关闭，请在“扩展”应用中打开。\n'
fi
printf '设置恢复完成。如桌面显示尚未更新，请注销后重新登录。\n'
