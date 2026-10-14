#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
scratch="${REBORN_BUILD_DIR:-${REBIRTH_BUILD_DIR:-/tmp/reborn-squared-build}}"
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/reborn-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/tmp}/reborn-swift-cache"
swift build -c release --arch arm64 --scratch-path "$scratch" --disable-sandbox --manifest-cache none -Xswiftc -module-cache-path -Xswiftc "$SWIFTPM_MODULECACHE_OVERRIDE"
bin="$scratch/arm64-apple-macosx/release"
"$bin/RebornCheck"
"$bin/RebornEffectsCheck"
app="$PWD/dist/Reborn².app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/Reborn" "$app/Contents/MacOS/Reborn"
bash ../scripts/build-icon.sh "$PWD/Assets/AppIcon.png" "$app/Contents/Resources/AppIcon.icns"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>Reborn</string>
<key>CFBundleIdentifier</key><string>io.github.derpaile.rebirthreborn</string>
<key>CFBundleName</key><string>Reborn²</string>
<key>CFBundleDisplayName</key><string>Reborn²</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.1</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app"
printf 'App: %s\n' "$app"
