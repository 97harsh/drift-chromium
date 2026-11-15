#!/usr/bin/env bash
# Fetch just the Chromium files Drift's branding touches (plus grit), at the
# version this repo builds, into <dir>. Lets apply_branding.sh be tested in
# minutes without a full Chromium checkout.
set -euo pipefail
_out="${1:?usage: fetch_test_src.sh <dir>}"
_root="$(cd "$(dirname "$0")/../.." && pwd)"
V="$(cat "$_root/ungoogled-chromium/chromium_version.txt")"
G="https://chromium.googlesource.com/chromium/src/+/refs/tags/$V"
A="https://chromium.googlesource.com/chromium/src/+archive/refs/tags/$V"
get() { mkdir -p "$(dirname "$_out/$1")"; curl -sfL "$G/$1?format=TEXT" | base64 -d > "$_out/$1"; }
mkdir -p "$_out/tools/grit" "$_out/chrome/app/resources"
curl -sfL "$A/tools/grit.tar.gz" | tar -xz -C "$_out/tools/grit"
curl -sfL "$A/chrome/app/resources.tar.gz" | tar -xz -C "$_out/chrome/app/resources" --include='chromium_strings_*.xtb'
get chrome/app/chromium_strings.grd
get chrome/app/settings_chromium_strings.grdp
get chrome/common/chrome_paths_mac.mm
for f in BRANDING product_logo.svg product_logo_16.png product_logo_22_mono.png product_logo_24.png product_logo_48.png \
         product_logo_64.png product_logo_128.png product_logo_256.png mac/app.icns mac/Assets.car; do
  get "chrome/app/theme/chromium/$f"
done
for f in product_logo_16.png product_logo_32.png product_logo_name_22.png product_logo_name_22_white.png; do
  get "chrome/app/theme/default_100_percent/chromium/$f"
done
echo "fetched Chromium $V branding inputs into $_out"
