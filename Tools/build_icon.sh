#!/bin/bash
# 由 Assets/AppIcon.png（1024x1024 源图）生成 Assets/AppIcon.icns
# 用法：
#   ./Tools/build_icon.sh                 # 用现有 Assets/AppIcon.png 生成 icns（替换图标后走这条）
#   ./Tools/build_icon.sh --regen-source  # 重新绘制占位源图，再生成 icns（回到出厂占位图标）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
TARGET="arm64-apple-macos14.0"
SRC_PNG="Assets/AppIcon.png"
ICNS="Assets/AppIcon.icns"
ICONSET=".build/AppIcon.iconset"
REFRESH_SOURCE=0

for arg in "$@"; do
    case "$arg" in
        --regen-source|--refresh) REFRESH_SOURCE=1 ;;
        -h|--help)
            sed -n '2,6p' "$0"
            exit 0
            ;;
        *)
            printf '[错误] 未知参数：%s（可用：--regen-source）\n' "$arg" >&2
            exit 1
            ;;
    esac
done

fail() { printf '\n[错误] %s\n' "$1" >&2; exit 1; }
warn() { printf '[警告] %s\n' "$1" >&2; }
step() { printf '\n==> %s\n' "$1"; }

command -v sips >/dev/null 2>&1 || fail "找不到 sips（macOS 自带，请检查系统环境）。"
command -v iconutil >/dev/null 2>&1 || fail "找不到 iconutil（macOS 自带，请检查系统环境）。"
mkdir -p .build Assets

if [ "$REFRESH_SOURCE" -eq 1 ] || [ ! -f "$SRC_PNG" ]; then
    step "绘制占位源图：$SRC_PNG"
    [ -d "$SDK" ] || fail "找不到可用 SDK：$SDK"
    [ -f "Tools/make_icon.swift" ] || fail "缺少 Tools/make_icon.swift，无法绘制占位图标。"
    swiftc -O -sdk "$SDK" -target "$TARGET" \
        -module-cache-path "./.build/mc" \
        -o ".build/make_icon" "Tools/make_icon.swift" || fail "占位图标绘制脚本编译失败。"
    "./.build/make_icon" "$SRC_PNG" || fail "离屏绘制失败。"
fi

[ -f "$SRC_PNG" ] || fail "源图不存在：$SRC_PNG"
[ -s "$SRC_PNG" ] || fail "源图为空文件：$SRC_PNG"

W="$(sips -g pixelWidth "$SRC_PNG" 2>/dev/null | awk '/pixelWidth/{print $2}')"
H="$(sips -g pixelHeight "$SRC_PNG" 2>/dev/null | awk '/pixelHeight/{print $2}')"
[ -n "${W:-}" ] && [ -n "${H:-}" ] || fail "无法读取源图尺寸（不是有效图片？）：$SRC_PNG"
printf '源图尺寸：%sx%s\n' "$W" "$H"
if [ "$W" -ne "$H" ]; then
    warn "源图不是正方形（%sx%s），图标会被拉伸；建议使用 1024x1024 正方形 PNG。" "$W" "$H"
fi
if [ "$W" -lt 512 ]; then
    warn "源图偏小（%sx%s），生成的 icns 在高分屏上可能发虚；建议使用 1024x1024。" "$W" "$H"
fi

step "生成 iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
gen() {
    sips -z "$1" "$1" "$SRC_PNG" --out "$ICONSET/$2" >/dev/null 2>&1 \
        || fail "sips 缩放失败：$2（目标 $1x$1）"
}
gen 16   icon_16x16.png
gen 32   icon_16x16@2x.png
gen 32   icon_32x32.png
gen 64   icon_32x32@2x.png
gen 128  icon_128x128.png
gen 256  icon_128x128@2x.png
gen 256  icon_256x256.png
gen 512  icon_256x256@2x.png
gen 512  icon_512x512.png
gen 1024 icon_512x512@2x.png

step "打包 icns"
iconutil -c icns "$ICONSET" -o "$ICNS" || fail "iconutil 打包失败（iconset 不完整？目录：$ICONSET）"

printf '\niconset 尺寸清单：\n'
for f in "$ICONSET"/*.png; do
    printf '  %-22s %s\n' "$(basename "$f")" "$(sips -g pixelWidth -g pixelHeight "$f" 2>/dev/null | awk '/pixel/{printf "%s ", $2}')"
done
printf '\n产物：%s（%s）\n' "$ICNS" "$(du -h "$ICNS" | cut -f1)"
printf '下一步：./build.sh 重新打包 App 以应用新图标。\n'
