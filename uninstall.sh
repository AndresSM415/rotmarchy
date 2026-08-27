#!/bin/bash
#
# Remove Rotmarchy. Leaves the video cache alone unless --purge is passed.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ID="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$ROOT/manifest.json")"
DEST="$HOME/.config/omarchy/plugins/$ID"
HYPR_DIR="$HOME/.config/hypr"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rotmarchy"

say() { printf '  %s\n' "$*"; }

printf '\nRemoving %s\n\n' "$ID"

[[ -x $DEST/bin/rotmarchy ]] && "$DEST/bin/rotmarchy" stop >/dev/null 2>&1 || true

omarchy plugin disable "$ID" >/dev/null 2>&1 && say "disabled" || true
rm -rf "$DEST" && say "removed $DEST"
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true

# Optional Hyprland rules, if they were installed.
if [[ -f $HYPR_DIR/rotmarchy.lua ]]; then
  rm -f "$HYPR_DIR/rotmarchy.lua"
  if grep -q 'hypr.rotmarchy' "$HYPR_DIR/hyprland.lua" 2>/dev/null; then
    cp "$HYPR_DIR/hyprland.lua" "$HYPR_DIR/hyprland.lua.bak.$(date +%s)"
    sed -i '/hypr\.rotmarchy/d; /-- Rotmarchy window rules/d' "$HYPR_DIR/hyprland.lua"
  fi
  command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1 || true
  say "removed Hyprland rules (backup kept)"
fi

if [[ ${1:-} == --purge ]]; then
  rm -rf "$CACHE_DIR" && say "purged cache"
else
  [[ -d $CACHE_DIR ]] && say "cache kept at $CACHE_DIR (--purge to remove)"
fi

printf '\nDone.\n\n'
