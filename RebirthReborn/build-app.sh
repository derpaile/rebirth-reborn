#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
scratch="${REBIRTH_BUILD_DIR:-/tmp/rebirth-reborn-build}"
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/reborn-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/tmp}/reborn-swift-cache"
swift build -c release --arch arm64 --scratch-path "$scratch" --disable-sandbox --manifest-cache none -Xswiftc -module-cache-path -Xswiftc "$SWIFTPM_MODULECACHE_OVERRIDE"
bin="$scratch/arm64-apple-macosx/release"
"$bin/RebirthCheck"
"$bin/RebirthEffectsCheck"
app="$PWD/dist/Rebirth Reborn.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/Rebirth" "$app/Contents/MacOS/Rebirth"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Rebirth</string>
<key>CFBundleIdentifier</key><string>io.github.derpaile.rebirthreborn</string>
<key>CFBundleName</key><string>Rebirth Reborn</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app"
printf 'App: %s\n' "$app"
