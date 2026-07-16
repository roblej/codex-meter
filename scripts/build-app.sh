#!/bin/zsh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/CodexMeter.app"
CONTENTS="$APP/Contents"
MODULE_CACHE="$ROOT/.build/module-cache"
SWIFT_CACHE="$ROOT/.build/cache"
SWIFT_CONFIG="$ROOT/.build/config"
SWIFT_SECURITY="$ROOT/.build/security"
ASSET_CATALOG="$ROOT/.build/AppIcon.xcassets"
APPICONSET="$ASSET_CATALOG/AppIcon.appiconset"
ASSET_OUTPUT="$ROOT/.build/AppIconAssets"
ASSET_INFO="$ROOT/.build/AppIconInfo.plist"

mkdir -p "$MODULE_CACHE" "$SWIFT_CACHE" "$SWIFT_CONFIG" "$SWIFT_SECURITY"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE"

SWIFT_OPTIONS=(
    --disable-sandbox
    --cache-path "$SWIFT_CACHE"
    --config-path "$SWIFT_CONFIG"
    --security-path "$SWIFT_SECURITY"
)

swift build "${SWIFT_OPTIONS[@]}" -c release --package-path "$ROOT"
BIN_DIR="$(swift build "${SWIFT_OPTIONS[@]}" -c release --show-bin-path --package-path "$ROOT")"
swift "$ROOT/scripts/generate-icon.swift" "$ROOT/Resources/AppIcon-source.png" "$APPICONSET"
rm -rf "$ASSET_OUTPUT"
mkdir -p "$ASSET_OUTPUT"
xcrun actool \
    --compile "$ASSET_OUTPUT" \
    --platform macosx \
    --minimum-deployment-target 13.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "$ASSET_INFO" \
    "$ASSET_CATALOG"

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_DIR/CodexMeter" "$CONTENTS/MacOS/CodexMeter"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$ASSET_OUTPUT/Assets.car" "$CONTENTS/Resources/Assets.car"
if [[ -f "$ASSET_OUTPUT/AppIcon.icns" ]]; then
    cp "$ASSET_OUTPUT/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
fi
chmod +x "$CONTENTS/MacOS/CodexMeter"

codesign --force --deep --sign - "$APP"

echo "$APP"
