#!/bin/bash
# Regenerate AppIcon.appiconset from a source image.
# Usage: ./generate-icons.sh [source_image]
# Default source: raw_icon_img_2.png

set -euo pipefail

SRC="${1:-raw_icon_img_2.png}"
DEST="ScrollMyMac/Resources/Assets.xcassets/AppIcon.appiconset"

if [ ! -f "$SRC" ]; then
    echo "Error: Source image '$SRC' not found."
    exit 1
fi

declare -A ICONS=(
    ["icon_16x16.png"]=16
    ["icon_16x16@2x.png"]=32
    ["icon_32x32.png"]=32
    ["icon_32x32@2x.png"]=64
    ["icon_128x128.png"]=128
    ["icon_128x128@2x.png"]=256
    ["icon_256x256.png"]=256
    ["icon_256x256@2x.png"]=512
    ["icon_512x512.png"]=512
    ["icon_512x512@2x.png"]=1024
)

for name in "${!ICONS[@]}"; do
    size=${ICONS[$name]}
    cp "$SRC" "$DEST/$name"
    sips -z "$size" "$size" "$DEST/$name" --out "$DEST/$name" > /dev/null 2>&1
done

echo "Generated ${#ICONS[@]} icons from $SRC"
