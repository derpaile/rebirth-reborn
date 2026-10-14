#!/bin/bash
# Package the project-created master artwork at all standard macOS icon sizes.
set -euo pipefail
source_png="${1:?Supply the master PNG}"
output_icns="${2:?Supply the destination ICNS}"
icon_work="$(mktemp -d "${TMPDIR:-/tmp}/reborn-icon.XXXXXX")"
trap 'rm -rf "$icon_work"' EXIT
iconset="$icon_work/AppIcon.iconset"
mkdir "$iconset"
for points in 16 32 128 256 512; do
    for scale in 1 2; do
        pixels=$((points * scale))
        suffix=""; if [ "$scale" = 2 ]; then suffix="@2x"; fi
        sips -z "$pixels" "$pixels" "$source_png" --out "$iconset/icon_${points}x${points}${suffix}.png" >/dev/null
    done
done
mkdir -p "$(dirname "$output_icns")"
iconutil -c icns "$iconset" -o "$output_icns"
