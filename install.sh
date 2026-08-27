#!/bin/bash
#
# Dev install: copy this folder into ~/.config/omarchy/plugins/ and enable it.
#
# Once the plugin is published, the real install path is:
#   omarchy plugin add https://github.com/<you>/omarchy-rotmarchy --enable
#
# A copy rather than a symlink on purpose — the marketplace validator rejects
# symlinks inside a plugin folder, so developing through one would hide a
# failure that only appears at submission.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ID="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$ROOT/manifest.json")"
DEST="$HOME/.config/omarchy/plugins/$ID"

say() { printf '  %s\n' "$*"; }

printf '\nInstalling %s\n\n' "$ID"

# --- dependencies -----------------------------------------------------------
missing=()
command -v mpv    >/dev/null || missing+=(mpv)
command -v yt-dlp >/dev/null || missing+=(yt-dlp)
if (( ${#missing[@]} )); then
  printf 'Missing required package(s): %s\n\n  sudo pacman -S --needed mpv yt-dlp\n\n' "${missing[*]}" >&2
  exit 1
fi
say "deps OK (mpv, yt-dlp)"

# yt-dlp cannot reach YouTube's real formats without a JS runtime. Warn rather
# than fail — a cached library still plays fine without one.
if ! command -v deno >/dev/null && ! command -v node >/dev/null; then
  say "WARNING: no deno or node found."
  say "         yt-dlp needs a JS runtime to solve YouTube's challenge;"
  say "         without one you get 'Requested format is not available'."
fi

# --- validate before installing --------------------------------------------
if command -v omarchy-plugin-validate >/dev/null || command -v omarchy >/dev/null; then
  omarchy plugin validate "$ROOT" >/dev/null && say "manifest valid"
fi

# --- copy -------------------------------------------------------------------
mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST"
mkdir -p "$DEST"
for item in manifest.json BarWidget.qml Model.js README.md LICENSE bin share assets preview.png; do
  [[ -e $ROOT/$item ]] && cp -r "$ROOT/$item" "$DEST/"
done
chmod +x "$DEST/bin/rotmarchy"
say "copied to $DEST"

# The Hyprland rules are optional, but if a previous version installed them
# they must be refreshed — a stale rule with a hard-coded size silently
# overrides the window geometry the helper asks for.
if [[ -f $HOME/.config/hypr/rotmarchy.lua ]]; then
  install -m 644 "$ROOT/hypr/rotmarchy.lua" "$HOME/.config/hypr/rotmarchy.lua"
  command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1 || true
  say "refreshed ~/.config/hypr/rotmarchy.lua"
fi

# --- register ---------------------------------------------------------------
# The rescan is asynchronous, so `enable` can arrive before the shell knows the
# folder exists. Retry rather than reporting a timing failure as success.
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true

enabled=0
for attempt in 1 2 3 4 5; do
  if omarchy plugin list 2>/dev/null | grep -q "^$ID[[:space:]]"; then
    state="$(omarchy plugin list 2>/dev/null | awk -v id="$ID" '$1==id { print $2 }')"
    if [[ $state == enabled ]]; then enabled=1; say "enabled"; break; fi
    if omarchy plugin enable "$ID" >/dev/null 2>&1; then enabled=1; say "enabled"; break; fi
  fi
  sleep 1
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
done

if (( ! enabled )); then
  say "could not enable automatically — run:"
  say "    omarchy plugin enable $ID"
fi

# A plain hot reload re-reads the QML but keeps the previously evaluated
# `.pragma library` JS module (Model.js) cached in the engine — so a reinstall
# silently keeps running the old argv builder. Restarting the shell is the only
# way to pick up a Model.js change.
omarchy restart shell >/dev/null 2>&1 || true
say "restarted shell (flushes the cached Model.js)"

cat <<EOF

Done. Look for the face in the bar.

  click    another random video, somewhere random on screen
  hover    your cortisol level
  q        close a video window

  $DEST/bin/rotmarchy stop     close all of them

Optional — borderless and pinned across workspaces. Without this they still
float, because Omarchy floats every mpv window by default:

  cp "$ROOT/hypr/rotmarchy.lua" ~/.config/hypr/rotmarchy.lua
  echo 'require("hypr.rotmarchy")' >> ~/.config/hypr/hyprland.lua
  hyprctl reload

EOF
