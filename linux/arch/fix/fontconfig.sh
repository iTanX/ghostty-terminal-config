#!/usr/bin/env bash
# 设置宿主机字体规则，并让当前用户的 Flatpak 应用共用这份配置。
set -euo pipefail

write_config() (
    local target="$1" temporary backup
    if [[ -e "$target" && ! -f "$target" ]]; then
        printf '配置路径已被其他类型的文件占用：%s\n' "$target" >&2
        return 1
    fi

    # 内容发生变化时先备份，再替换配置文件。
    temporary="$(mktemp "${target}.tmp.XXXXXXXX")"
    trap 'rm -f -- "$temporary"' EXIT
    cat > "$temporary"
    if cmp -s -- "$target" "$temporary"; then
        return
    fi
    if [[ -e "$target" || -L "$target" ]]; then
        backup="${target}.bak.$(date +%Y%m%d%H%M%S).$$"
        cp -a -- "$target" "$backup"
        printf '原配置已备份至 %s\n' "$backup"
    fi
    mv -f -- "$temporary" "$target"
)

main() {
    local fontconfig_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/fontconfig"
    local host_config="${fontconfig_dir}/fonts.conf"
    local flatpak_config="${fontconfig_dir}/flatpak-fonts.conf"
    local include_path

    # 1. 检查运行身份和 Flatpak。
    if [[ "$EUID" -eq 0 ]]; then
        printf '请以普通用户运行，不要使用 sudo。\n' >&2
        return 1
    fi
    if ! command -v flatpak >/dev/null 2>&1; then
        printf '缺少 Flatpak，请先完成系统的 Flatpak 设置。\n' >&2
        return 1
    fi
    mkdir -p -- "$fontconfig_dir"

    # 2. 配置宿主机的字体优先级和渲染参数。
    write_config "$host_config" <<'XML'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>

    <match target="font">
        <edit name="antialias" mode="assign"><bool>true</bool></edit>
        <edit name="hinting" mode="assign"><bool>true</bool></edit>
        <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
        <edit name="rgba" mode="assign"><const>rgb</const></edit>
        <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
    </match>

    <alias>
        <family>sans-serif</family>
        <prefer>
            <family>Noto Sans</family>
            <family>Noto Sans CJK SC</family>
            <family>Adwaita Sans</family>
        </prefer>
    </alias>

    <alias>
        <family>serif</family>
        <prefer>
            <family>Noto Sans</family>
            <family>Noto Sans CJK SC</family>
            <family>Adwaita Sans</family>
        </prefer>
    </alias>

    <alias>
        <family>monospace</family>
        <prefer>
            <family>JetBrains Mono</family>
            <family>JetBrains Maple Mono</family>
            <family>Adwaita Mono</family>
        </prefer>
    </alias>

</fontconfig>
XML

    # 3. 依次加载 Flatpak 运行时的默认配置和宿主机字体规则。
    include_path="$(printf '%s' "$host_config" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')"
    write_config "$flatpak_config" <<XML
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
    <include>/etc/fonts/fonts.conf</include>
    <include>${include_path}</include>
</fontconfig>
XML

    # 4. 为当前用户的 Flatpak 应用启用共用配置。
    flatpak override --user \
        --filesystem="${fontconfig_dir}:ro" \
        --env="FONTCONFIG_FILE=${flatpak_config}"
    printf '宿主机和 Flatpak 的字体配置已写入 %s，请完全退出并重新打开应用。\n' "$fontconfig_dir"
}

main "$@"
