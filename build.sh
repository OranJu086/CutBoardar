#!/bin/bash
# CutBoardar 构建与打包脚本
# 环境：本机没有 Xcode，只有 CommandLineTools，因此用 swiftc 直接编译，再手工组装 .app bundle。
# 用法：./build.sh            （SRC_DIR 环境变量可覆盖源码目录，仅供自检/临时验证使用）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

APP_NAME="CutBoardar"
SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
TARGET="arm64-apple-macos14.0"
SRC_DIR="${SRC_DIR:-Sources}"
BUILD_DIR=".build"
BIN="$BUILD_DIR/$APP_NAME"
APP="dist/$APP_NAME.app"
COMPILE_LOG="$BUILD_DIR/compile.log"
SIGN_LOG="$BUILD_DIR/sign.log"

step() { printf '\n==> %s\n' "$1"; }
warn() { printf '[警告] %s\n' "$1" >&2; }
fail() {
    printf '\n[错误] %s\n' "$1" >&2
    printf '[错误] 构建中止。\n' >&2
    exit 1
}

step "1/6 检查工具链"
[ -d "$SDK" ] || fail "找不到可用 SDK：$SDK
本机默认 SDK 与 swiftc 版本不匹配，必须用 MacOSX15.4.sdk 编译。请确认 CommandLineTools 已安装。"
command -v swiftc >/dev/null 2>&1 || fail "找不到 swiftc，请先安装 Command Line Tools：xcode-select --install"
mkdir -p "$BUILD_DIR"

step "2/6 收集源码（目录：$SRC_DIR/）"
[ -d "$SRC_DIR" ] || fail "源码目录不存在：$SRC_DIR/
请把 Swift 源文件放在 Sources/Core/ 与 Sources/App/ 下（至少一个 .swift 文件）。"
COUNT="$(find "$SRC_DIR" -type f -name '*.swift' | wc -l | tr -d ' ')"
[ "$COUNT" -gt 0 ] || fail "在 $SRC_DIR/ 下没有找到任何 .swift 文件，无法编译。
请先放入源码（Sources/Core/*.swift、Sources/App/*.swift）后重新执行 ./build.sh。"

SOURCE_LIST=()
while IFS= read -r f; do
    SOURCE_LIST+=("$f")
done < <(find "$SRC_DIR" -type f -name '*.swift' | sort)

printf '共 %d 个源文件：\n' "$COUNT"
printf '  %s\n' "${SOURCE_LIST[@]}"

step "3/6 编译（${TARGET}，SDK 15.4）"
if ! swiftc -parse-as-library -O \
    -sdk "$SDK" \
    -target "$TARGET" \
    -module-cache-path "./$BUILD_DIR/mc" \
    -o "$BIN" \
    "${SOURCE_LIST[@]}" > "$COMPILE_LOG" 2>&1; then
    printf '\n[错误] 编译失败，编译器原始输出如下（原样保留）：\n\n' >&2
    cat "$COMPILE_LOG" >&2
    printf '\n[错误] 编译失败，构建中止。完整日志：%s\n' "$COMPILE_LOG" >&2
    exit 1
fi
if [ -s "$COMPILE_LOG" ]; then
    printf '编译通过（编译器有警告输出，已记录到 %s）：\n' "$COMPILE_LOG"
    sed -n '1,20p' "$COMPILE_LOG"
else
    printf '编译通过，无警告。\n'
fi

step "4/6 组装 App bundle：$APP"
[ -f "Resources/Info.plist" ] || fail "缺少 Resources/Info.plist，无法生成 App bundle。"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
chmod +x "$APP/Contents/MacOS/$APP_NAME"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"
if ! PLIST_OUT="$(plutil -lint "$APP/Contents/Info.plist" 2>&1)"; then
    printf '%s\n' "$PLIST_OUT" >&2
    fail "Info.plist 校验失败（plutil -lint）：$APP/Contents/Info.plist"
fi
printf 'APPL????' > "$APP/Contents/PkgInfo"

if [ ! -f "Assets/AppIcon.icns" ]; then
    warn "Assets/AppIcon.icns 不存在，尝试调用 Tools/build_icon.sh 生成图标…"
    if ! bash "Tools/build_icon.sh"; then
        warn "图标生成失败，本次将以无图标状态打包（App 仍可正常使用）。"
    fi
fi
if [ -f "Assets/AppIcon.icns" ]; then
    cp "Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
else
    warn "缺少 Assets/AppIcon.icns，App 将使用系统默认图标。"
fi

step "5/6 ad-hoc 签名"
if ! codesign --force --deep --sign - "$APP" > "$SIGN_LOG" 2>&1; then
    warn "ad-hoc 签名失败（不影响本机双击运行）："
    sed -n '1,5p' "$SIGN_LOG" >&2 || true
else
    printf '已使用 ad-hoc 身份签名（codesign -s -）。\n'
fi

step "6/6 构建完成"
printf '产物路径：%s\n' "$ROOT/$APP"
printf '可执行文件：%s\n' "$(file -b "$APP/Contents/MacOS/$APP_NAME")"
printf 'Bundle 体积：%s（其中可执行文件 %s）\n' "$(du -sh "$APP" | cut -f1)" "$(du -h "$BIN" | cut -f1)"
printf '\nBundle 内容：\n'
find "$APP" | LC_ALL=C sort | sed "s|^$APP|$APP_NAME.app|; s|^$APP_NAME.app|  $APP_NAME.app|"
printf '\n启动方式：open %s\n' "$APP"
