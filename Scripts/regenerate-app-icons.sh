#!/bin/bash
#
# Regenerate AppIcon.appiconset from a single source PNG.
# Run from the repo root:
#
#     ./Scripts/regenerate-app-icons.sh path/to/source-1024.png
#
# Source should be at least 1024×1024 — ideally a square PNG with transparency.
# Uses macOS's built-in `sips` so no extra tools are required.

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <source.png>" >&2
    exit 1
fi

SRC="$1"
if [[ ! -f "$SRC" ]]; then
    echo "Source not found: $SRC" >&2
    exit 1
fi

OUT="BananaBlitz/Assets.xcassets/AppIcon.appiconset"
if [[ ! -d "$OUT" ]]; then
    echo "AppIcon.appiconset not found at $OUT — run from repo root." >&2
    exit 1
fi

# Remove the legacy typo'd file if present.
rm -f "$OUT/AppIcon 1256x256@2x.png"

resize() {
    local size="$1"
    local name="$2"
    sips -z "$size" "$size" "$SRC" --out "$OUT/$name" >/dev/null
    echo "  wrote $name (${size}×${size})"
}

echo "Regenerating AppIcon set from $SRC..."
resize   16 AppIcon16x16.png
resize   32 AppIcon16x16@2x.png
resize   32 AppIcon32x32.png
resize   64 AppIcon32x32@2x.png
resize  128 AppIcon128x128.png
resize  256 AppIcon128x128@2x.png
resize  256 AppIcon256x256.png
resize  512 AppIcon256x256@2x.png
resize  512 AppIcon512x512.png
resize 1024 AppIcon512x512@2x.png

echo "Done. Contents.json already references these filenames."
