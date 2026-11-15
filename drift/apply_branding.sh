#!/usr/bin/env bash
# Apply Drift's branding to a patched Chromium source tree. Run before `gn gen`.
#   drift/apply_branding.sh <chromium src dir>
# Needs macOS tools: sips, iconutil, and (for the macOS 26 icon) Xcode's actool.
# Set DRIFT_SKIP_ACTOOL=1 to skip the Assets.car step where Xcode isn't installed.
set -euo pipefail

_drift="$(cd "$(dirname "$0")" && pwd)"
_src="$(cd "$1" && pwd)"
_theme="$_src/chrome/app/theme/chromium"
_tmp="$(mktemp -d)"
trap 'rm -rf "$_tmp"' EXIT
log() { printf '[drift-branding] %s\n' "$*"; }

# 1. Product identity: app name, bundle id, copyright (read by gn gen).
cp "$_drift/BRANDING" "$_theme/BRANDING"
log "BRANDING: $(grep PRODUCT_FULLNAME "$_theme/BRANDING") $(grep MAC_BUNDLE_ID "$_theme/BRANDING")"

# 2. Profile folder: ~/Library/Application Support/Drift Browser (not "Chromium").
python3 - "$_src/chrome/common/chrome_paths_mac.mm" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = 'product_dir_name = "Chromium";'
if 'product_dir_name = "Drift Browser";' not in s:
    if s.count(old) != 1:
        sys.exit(f'apply_branding: expected exactly one {old!r} in {p}')
    s = s.replace(old, 'product_dir_name = "Drift Browser";')
    open(p, 'w', encoding='utf-8').write(s)
PY
log "profile dir: Drift Browser"

# 3. Icons and logos.
_icon="$_drift/icon/icon-1024.png"       # rounded icon with margin, pre-macOS-26 style
_bleed="$_drift/icon/fullbleed-1024.png"  # full-bleed art; macOS 26 adds the shape and glass
px() { sips -z "$2" "$2" "$1" --out "$3" >/dev/null; }

_iconset="$_tmp/app.iconset"; mkdir -p "$_iconset"
for s in 16 32 128 256 512; do
  px "$_icon" "$s" "$_iconset/icon_${s}x${s}.png"
  px "$_icon" "$((s * 2))" "$_iconset/icon_${s}x${s}@2x.png"
done
iconutil -c icns -o "$_theme/mac/app.icns" "$_iconset"

for s in 16 24 48 64 128 256; do px "$_icon" "$s" "$_theme/product_logo_${s}.png"; done
px "$_icon" 22 "$_theme/product_logo_22_mono.png"
sips -m '/System/Library/ColorSync/Profiles/Generic Gray Profile.icc' "$_theme/product_logo_22_mono.png" >/dev/null || true
cp "$_drift/icon/icon.svg" "$_theme/product_logo.svg"
_p100="$_src/chrome/app/theme/default_100_percent/chromium"
px "$_icon" 16 "$_p100/product_logo_16.png"
px "$_icon" 32 "$_p100/product_logo_32.png"
cp "$_drift/icon/wordmark-22.png" "$_p100/product_logo_name_22.png"
cp "$_drift/icon/wordmark-22-white.png" "$_p100/product_logo_name_22_white.png"
log "icons: app.icns + product logos + wordmarks"

# macOS 26 reads the app icon from the compiled asset catalog (Assets.car).
_iconbundle="$_tmp/AppIcon.icon"; mkdir -p "$_iconbundle/Assets"
cp "$_drift/icon/icon.json" "$_iconbundle/icon.json"
cp "$_bleed" "$_iconbundle/Assets/drift.png"
rm -rf "$_theme/mac/AppIcon.icon" && cp -R "$_iconbundle" "$_theme/mac/AppIcon.icon"  # keep the source in-tree too
if [[ "${DRIFT_SKIP_ACTOOL:-0}" == "1" ]]; then
  log "Assets.car: skipped (DRIFT_SKIP_ACTOOL=1)"
else
  mkdir -p "$_tmp/car"
  xcrun actool "$_iconbundle" --compile "$_tmp/car" --platform macosx --minimum-deployment-target 12.0 \
    --app-icon AppIcon --include-all-app-icons --output-partial-info-plist "$_tmp/partial.plist" \
    --output-format human-readable-text --notices --warnings --errors
  [[ -s "$_tmp/car/Assets.car" ]] || { log "actool produced no Assets.car"; exit 1; }
  cp "$_tmp/car/Assets.car" "$_theme/mac/Assets.car"
  log "Assets.car: $(du -h "$_theme/mac/Assets.car" | cut -f1)"
fi

# 4. User-visible strings, with translations kept in sync.
python3 "$_drift/rebrand_strings.py" "$_src" --name Drift
log "done"
