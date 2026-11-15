#!/usr/bin/env bash
# Drift: make sure DevTools can find the esbuild npm package.
# github_before_build.sh installs esbuild into build/esbuild-node (outside build/src)
# and symlinks it into the source tree. Older hand-off archives only packed
# build/src, so resumed jobs had a dangling symlink and the build failed with
# "Cannot find package 'esbuild'". Re-create it whenever it's missing.
set -euo pipefail

_root_dir="$(dirname "$(greadlink -f "$0")")"
_src_dir="$_root_dir/build/src"
_esbuild_version="$(/opt/homebrew/bin/esbuild --version)"
_esbuild_module="$_root_dir/build/esbuild-node/node_modules/esbuild"
_link="$_src_dir/third_party/devtools-frontend/src/node_modules/esbuild"

if [[ ! -f "$_esbuild_module/package.json" ]] || \
    [[ "$(node -p 'require(process.argv[1]).version' "$_esbuild_module/package.json")" != "$_esbuild_version" ]]; then
  echo "Installing esbuild@$_esbuild_version for DevTools"
  npm install --prefix "$_root_dir/build/esbuild-node" --no-save --package-lock=false --no-bin-links --ignore-scripts --omit=optional --no-audit --no-fund "esbuild@$_esbuild_version"
fi
if [[ "$(greadlink -f "$_link" 2>/dev/null || true)" != "$(greadlink -f "$_esbuild_module")" ]]; then
  rm -rf "$_link"
  ln -s "$_esbuild_module" "$_link"
fi
echo "esbuild ready: $(node -p 'require(process.argv[1]).version' "$_link/package.json")"
