#!/usr/bin/env bash
# Generate placeholder PWA icons (Apple 180px, manifest 192/512px) and icon.svg
# from an accent color + a one/two-letter mark. Replace these with real artwork
# before shipping. Usage:
#   make-icons.sh <out_dir> <accent_hex> <fg_hex> <letters>
# Example: make-icons.sh frontend/public "#2E9E7B" "#FFFFFF" "R"
set -euo pipefail

OUT="${1:?out dir}"; ACCENT="${2:?accent hex}"; FG="${3:-#FFFFFF}"; LETTERS="${4:-A}"
mkdir -p "$OUT"

# Full-bleed background with the mark inside the maskable safe zone. OSes apply
# their own rounded/squircle mask; transparent corners break Apple touch icons
# and are invalid for a maskable manifest icon. SVG is the source of truth.
cat > "$OUT/icon.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
  <rect width="512" height="512" fill="${ACCENT}"/>
  <text x="50%" y="52%" dy=".35em" text-anchor="middle"
        font-family="system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
        font-size="248" font-weight="700" fill="${FG}">${LETTERS}</text>
</svg>
SVG

render() { # <size> <file>
  local size="$1" file="$2"
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w "$size" -h "$size" "$OUT/icon.svg" -o "$file"
  elif command -v magick >/dev/null 2>&1; then
    magick -background none -density 300 "$OUT/icon.svg" -resize "${size}x${size}" "$file"
  elif command -v convert >/dev/null 2>&1; then
    convert -background none -density 300 "$OUT/icon.svg" -resize "${size}x${size}" "$file"
  elif command -v inkscape >/dev/null 2>&1; then
    inkscape "$OUT/icon.svg" -w "$size" -h "$size" -o "$file" >/dev/null 2>&1
  else
    echo "WARN: no SVG->PNG converter (rsvg-convert / imagemagick / inkscape)." >&2
    echo "      Wrote icon.svg only — create $file (${size}x${size}) by hand." >&2
    return 1
  fi
}

render 180 "$OUT/icon-180.png" || true
render 192 "$OUT/icon-192.png" || true
render 512 "$OUT/icon-512.png" || true
echo "Icons written to $OUT (replace with real artwork before shipping)."
