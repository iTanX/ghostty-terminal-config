# 供应用安装脚本复用：从 GitHub Releases 下载并通过 Gear Lever 集成 AppImage。

find_integrated_appimage() {
    /usr/bin/python3 -I - "$1" "$2" <<'PY'
from configparser import ConfigParser, Error
from pathlib import Path
import os
import sys

# 通过 Gear Lever 写入的菜单元数据找到可原位替换的 AppImage。
folder, name = Path(sys.argv[1]).resolve(), sys.argv[2]
desktop_dir = Path.home() / '.local' / 'share' / 'applications'
launchers = []
for path in desktop_dir.glob('*.desktop'):
    parser = ConfigParser(interpolation=None)
    try:
        parser.read(path, encoding='utf-8')
    except (Error, UnicodeError):
        continue
    if not parser.has_section('Desktop Entry'):
        continue
    entry = parser['Desktop Entry']
    if entry.get('X-AppImage-Name', '').casefold() != name.casefold():
        continue
    launcher = Path(entry.get('TryExec', ''))
    if launcher.is_absolute() and launcher.is_file() and os.access(launcher, os.X_OK):
        launchers.append((launcher, entry.get('Name')))

if len(launchers) > 1:
    sys.exit(f'已集成多个 {name} AppImage，请先在 Gear Lever 中保留要更新的版本。')
if launchers:
    launcher, display_name = launchers[0]
    if launcher.resolve().parent != folder or display_name != name:
        sys.exit(f'无法原位替换现有的 {name}，请先在 Gear Lever 中处理该入口：{launcher}')
    print(launcher)
elif any(p.suffix.lower() == '.appimage' and p.name.casefold().startswith(name.casefold())
         for p in folder.glob('*')):
    sys.exit(f'找到 {name} AppImage，但没有有效的菜单入口。请先修复集成，避免重复安装。')
PY
}

github_appimage_asset() {
    curl --fail --silent --show-error --retry 3 --max-time 30 \
        "https://api.github.com/repos/$1/releases/latest" |
        /usr/bin/python3 -I -c '
from fnmatch import fnmatchcase
import json
import re
import sys

# 与 Gear Lever 使用同一文件名规则，只接受唯一匹配和上游公布的摘要。
repo, pattern = sys.argv[1:]
assets = [a for a in json.load(sys.stdin)["assets"] if fnmatchcase(a["name"], pattern)]
if len(assets) != 1:
    sys.exit(f"最新稳定版中未找到唯一匹配的 AppImage：{pattern}")
asset = assets[0]
name, url = asset["name"], asset["browser_download_url"]
digest = asset.get("digest") or ""
if not (re.fullmatch(r"[A-Za-z0-9._-]+\.AppImage", name)
        and url.startswith(f"https://github.com/{repo}/releases/download/")
        and url.endswith("/" + name)
        and re.fullmatch(r"sha256:[0-9a-f]{64}", digest)):
    sys.exit(f"AppImage 缺少有效的 GitHub 下载地址或 SHA-256：{name}")
print(url, digest.removeprefix("sha256:"), sep="\t")
' "$1" "$2"
}

appimage_matches_sha256() {
    local checksum
    checksum="$(sha256sum < "$1")" || return 1
    [[ "${checksum%% *}" == "$2" ]]
}

install_github_appimage() (
    local name="$1" repo="$2" pattern="$3"
    shift 3
    local gear_id='it.mijorus.gearlever' appimages_dir="${HOME}/.local/opt/AppImages"
    local cache_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/gear-lever-install/${repo##*/}"
    local pkg installed integrated scope asset url digest temp_dir archive
    local -a dependencies=() gear_lever gear_settings

    # 1. 检查运行环境并安装缺少的依赖。
    if [[ "$EUID" -eq 0 || "$(uname -s)" != Linux ]]; then
        printf '请在 Arch Linux 上以普通用户运行。\n' >&2
        return 1
    fi
    for pkg in curl python fuse2 "$@"; do
        pacman -Q "$pkg" >/dev/null 2>&1 || dependencies+=("$pkg")
    done
    if ((${#dependencies[@]})); then
        sudo pacman -S --needed --noconfirm "${dependencies[@]}"
    fi

    # 2. 查询最新稳定版并识别已有入口，防止同一应用被重复导入。
    mkdir -p -- "$cache_dir"
    exec 9> "$cache_dir/install.lock"
    flock 9
    installed="$(find_integrated_appimage "$appimages_dir" "$name")"
    asset="$(github_appimage_asset "$repo" "$pattern")"
    IFS=$'\t' read -r url digest <<< "$asset"

    # 3. 复用 Gear Lever，或从已配置的 Flathub 安装。
    if command -v gearlever >/dev/null 2>&1; then
        gear_lever=(gearlever)
        gear_settings=(gsettings)
    elif command -v flatpak >/dev/null 2>&1; then
        if ! flatpak info "$gear_id" >/dev/null 2>&1; then
            if flatpak remotes --user --columns=name | grep -Fx flathub >/dev/null; then
                scope=--user
            elif flatpak remotes --system --columns=name | grep -Fx flathub >/dev/null; then
                scope=--system
            else
                printf '未配置 Flathub，请先添加 Flathub 软件源。\n' >&2
                return 1
            fi
            flatpak install "$scope" --assumeyes flathub "$gear_id"
        fi
        gear_lever=(flatpak run "$gear_id")
        gear_settings=(flatpak run --command=gsettings "$gear_id")
    else
        printf '缺少 Gear Lever 和 Flatpak，请先完成系统的 Flatpak 设置。\n' >&2
        return 1
    fi

    # 4. 校验并集成新文件；更新时应答替换提示，沿用原有菜单入口。
    if [[ -n "$installed" ]] && appimage_matches_sha256 "$installed" "$digest"; then
        printf '%s 已是上游当前版本。\n' "$name"
    else
        temp_dir="$(mktemp -d -- "$cache_dir/download.XXXXXXXX")"
        trap 'rm -rf -- "$temp_dir"' EXIT
        archive="$temp_dir/${url##*/}"
        printf '正在下载 %s……\n' "${archive##*/}"
        curl --fail --location --retry 3 --connect-timeout 15 --remove-on-error \
            --proto '=https' --proto-redir '=https' --output "$archive" "$url"
        if ! appimage_matches_sha256 "$archive" "$digest"; then
            printf '%s AppImage 的 SHA-256 校验失败，未集成新文件。\n' "$name" >&2
            return 1
        fi

        mkdir -p -- "$appimages_dir"
        "${gear_settings[@]}" set "$gear_id" appimages-default-folder "$appimages_dir"
        if [[ -n "$installed" ]]; then
            "${gear_lever[@]}" --integrate "$archive" --replace <<< $'y\nr'
        else
            "${gear_lever[@]}" --integrate "$archive" --replace --yes
        fi
        integrated="$(find_integrated_appimage "$appimages_dir" "$name")"
        if [[ -z "$integrated" || ( -n "$installed" && "$integrated" != "$installed" ) ]] ||
            ! appimage_matches_sha256 "$integrated" "$digest"; then
            printf 'Gear Lever 集成后的 %s AppImage 验证失败。\n' "$name" >&2
            return 1
        fi
        installed="$integrated"
    fi

    # 5. 配置 Gear Lever 的 GitHub 更新源，后续可以在图形界面更新。
    "${gear_lever[@]}" --set-update-source "$installed" --manager GithubUpdater \
        "repo=$repo" "repo_filename=$pattern" allow_prereleases=false
    printf '%s 已就绪，Gear Lever 更新源：%s\n' "$name" "https://github.com/$repo/releases"
)
