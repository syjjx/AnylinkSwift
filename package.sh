#!/bin/bash
# TunnelPilot 打包脚本
# 1. Release 构建 Swift app（构建阶段自动编译并打入 vpnagent/sslcon）
# 2. 逐个签名（含 Go 二进制，App 开 hardened runtime）
# 3. 生成 DMG
#
# 用法: ./package.sh [输出目录]（默认 /tmp）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/TunnelPilot"
OUT_DIR="${1:-/tmp}"
DERIVED_DATA="$SCRIPT_DIR/build"

IDENTITY=$(security find-identity -v -p codesigning \
    | grep -E "Apple Development|Developer ID Application" \
    | head -1 | awk -F'"' '{print $2}')
if [ -z "$IDENTITY" ]; then
    echo "错误: 未找到可用的签名证书" >&2
    exit 1
fi
echo "签名身份: $IDENTITY"

echo "== 1/4 构建 TunnelPilot (Release) =="
cd "$PROJECT_DIR"
xcodebuild -project TunnelPilot.xcodeproj \
    -scheme TunnelPilot \
    -configuration Release \
    -sdk macosx \
    -derivedDataPath "$DERIVED_DATA" \
    build >/dev/null

APP="$DERIVED_DATA/Build/Products/Release/TunnelPilot.app"
test -d "$APP" || { echo "错误: 未找到构建产物 $APP" >&2; exit 1; }

echo "== 2/4 签名 =="
codesign --force --sign "$IDENTITY" "$APP/Contents/MacOS/vpnagent"
codesign --force --sign "$IDENTITY" "$APP/Contents/MacOS/sslcon"
codesign --force --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP" || { echo "错误: 签名校验失败" >&2; exit 1; }

echo "== 3/4 生成 DMG =="
# 暂存目录：应用 + Applications 快捷方式，方便拖入安装
STAGING_DIR="$DERIVED_DATA/dmg-staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

DMG="$OUT_DIR/隧道助手.dmg"
rm -f "$DMG"
hdiutil create -volname "隧道助手 安全客户端" \
    -srcfolder "$STAGING_DIR" \
    -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING_DIR"

echo "== 4/4 完成 =="
echo "  App: $APP"
echo "  DMG: $DMG"
