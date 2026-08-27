# Rotmarchy

A brainrot button for the Omarchy bar.

Click the face. A random video appears somewhere on your screen, cropped to a
phone shape, silent. Click again and another one appears. That is the entire
interface.

Hover the button and it reports your cortisol level. It is making that up.

Minecraft parkour, Family Guy, Subway Surfers or GTA mega-ramps, each opened at
a random timestamp so it is never the same twice.

**Press `q` on a window to close it**, or clear them all at once:

```bash
omarchy-shell io.github.andressm415.rotmarchy stop
```

## Requirements

```bash
sudo pacman -S --needed mpv yt-dlp deno
```

Three things, and the third is the one that catches people.

**mpv and yt-dlp are separate packages.** mpv ships the yt-dlp *integration* —
the built-in `ytdl_hook` behind `--ytdl-format` — but not the yt-dlp *binary*;
the hook shells out to whatever is on `PATH`. Arch lists yt-dlp as an
**optional** dependency of mpv, not a hard one.

**yt-dlp needs a JavaScript runtime.** YouTube gates real format URLs behind a
JS challenge. Solve it and you get ~40 formats; fail it and you get storyboard
images only, which mpv reports as the thoroughly misleading:

```
ERROR: [youtube] <id>: Requested format is not available
```

On Arch this is handled for you — `yt-dlp` hard-depends on `yt-dlp-ejs` and
`deno` does the solving. Elsewhere you must arrange it yourself. On
Debian/Ubuntu note that `apt install mpv` pulls in **youtube-dl** (dead since
2021, cannot parse YouTube at all), *not* yt-dlp.

Check before blaming anything else — this should print a long format table,
not three `mhtml` storyboard rows:

```bash
yt-dlp -F "https://www.youtube.com/watch?v=n_Dv4JMiwK8"
```

## Install

```bash
omarchy plugin add https://github.com/AndresSM415/rotmarchy --enable
```

To remove it again:

```bash
omarchy plugin remove io.github.andressm415.rotmarchy
```

Like every Omarchy plugin, this runs unsandboxed with your user permissions.
There is no sandbox to fall back on, so read it before you install it.

## Settings

| Setting | Default | Notes |
| --- | --- | --- |
| Category | `random` | Or pin it to one of the four |
| Video height | `720` | Fetch/crop resolution; the window shows it at 60% |

## How it works

**Phone shape by cropping, not scaling.** The filter is
`crop=w=ih*9/16:h=ih` — a full-height, 9:16 slice taken out of the middle of
the frame. The pixels are the source's own, so a 720p video yields a real
405×720 portrait image rather than a squashed 1280×720 one. Verified against
ffmpeg at every supported height:

| Source | Cropped |
| --- | --- |
| 854×480 | 270×480 |
| 1280×720 | 405×720 |
| 1920×1080 | 608×1080 |

That 1080 row is why the width is rounded half-up rather than truncated:
`1080*9/16` is 607.5, and ffmpeg resolves it to 608. Integer division would
give 607, leaving the window one pixel narrow and quietly reintroducing the
scaling the crop exists to avoid.

**Random position.** Hyprland rules are static, so the randomness happens after
the fact: the helper waits for the window to map, then resizes and moves it by
address, keeping a margin so it never hangs off screen. Windows are matched by
a unique per-launch title rather than by pid — `setsid` forks, so `$!` is the
wrapper, not the mpv process that owns the window. The title is also what makes
spamming the button safe: two launches racing each other each find their own
window.

**Silent.** `--no-audio`, and the format selector asks for video only, so an
audio stream is never fetched in the first place.

**The window is smaller than the video.** It renders at 60% of the cropped
size — 405x720 shown in a 243x432 window. The crop still happens at full source
resolution, so the picture is a sharp downscale rather than a small stream
stretched up.

| Video | Window |
| --- | --- |
| 270x480 | 162x288 |
| 405x720 | 243x432 |
| 608x1080 | 365x648 |

## The CLI

`bin/rotmarchy` is the engine and stands alone:

```bash
bin/rotmarchy                  # random category
bin/rotmarchy gta              # pick your poison
bin/rotmarchy cache gta        # pre-download for instant, offline starts
bin/rotmarchy stop             # close all of them
bin/rotmarchy status           # exit 0 if anything is playing
bin/rotmarchy list             # categories, video and window size
```

`ROTMARCHY_HEIGHT`, `ROTMARCHY_WINDOW_SCALE`, `ROTMARCHY_MAX_WINDOWS`,
`ROTMARCHY_FORMAT` and `ROTMARCHY_SOURCES` all override behaviour; see
`--help`.

**No Hyprland config required.** Omarchy floats every `mpv` window by default,
and everything else — size, position, pinning — is applied at runtime by
address once the window maps. Nothing is written to `~/.config/hypr`.

## Adding your own videos

`share/sources.tsv` is `category <TAB> duration <TAB> id <TAB> title`. Duration
is stored so a random seek offset can be picked with no metadata round-trip
before playback. To add one:

```bash
yt-dlp --flat-playlist --print "%(id)s|%(duration)s|%(title)s" "ytsearch5:your query"
```

**Treat a sources file from someone else as untrusted.** Both fields are
validated against their grammar before use — duration must be digits, the id
must be exactly 11 characters of `[A-Za-z0-9_-]` — and malformed rows are
dropped. That check is not cosmetic: `duration` reaches bash arithmetic, and
bash evaluates a variable's *value* as an arithmetic expression, where an array
subscript performs command substitution. A duration of `HEIGHT[$(cmd)]` would
otherwise run `cmd`. `set -u` does not save you; it only rejects the payload if
it names a variable the script has not already defined.

## Notes for anyone hacking on this

**`Model.js` changes need a shell restart, not a hot reload.** The shell
re-reads QML on save but keeps the already-evaluated `.pragma library` JS
module cached in the engine, so an edited `Model.js` appears to do nothing —
the old argv builder keeps running. Symptom: the plugin invokes flags or
subcommands you already deleted. Fix with `omarchy restart shell`.

**`hyprctl dispatch` is Lua now.** On Hyprland 0.5x,
`hyprctl dispatch movewindowpixel exact X Y,address:0x..` is a *syntax error* —
the argument is parsed as Lua. Use
`hl.dsp.window.move({ window = "address:0x..", x = X, y = Y })`, with the
legacy string as a fallback, exactly as `omarchy-hyprland-window-pop` does.

**Nothing is downloaded unless you ask.** Playback streams. `rotmarchy cache`
is the only thing that writes a video to disk, opt-in and one at a time.
Sources are mostly published as "No Copyright" / "free to use".

**`pkill -f` matches more than you mean.** It tests the whole command line, so
a pattern like the app id also matches any shell that merely *mentions* it —
including the one running `rotmarchy stop`. Processes are resolved to pids and
confirmed to be `mpv` via `/proc/<pid>/comm` before anything is killed.

**Security.** The plugin runs unsandboxed in the shell process, like every
Omarchy plugin. It holds no credentials and makes no network requests from QML.
Every command goes through `Util.execArgv` as an argv vector — no value is ever
interpolated into a shell string — and settings from `shell.json` are
normalized in `Model.js` before reaching an argv, so a hand-edited config
cannot smuggle anything through. Sources files are validated at the boundary
(see above), and concurrent windows are capped so that `play`, which any local
process can invoke over IPC, cannot be looped into a resource exhaustion.

## Layout

```
manifest.json        plugin metadata + settings schema
BarWidget.qml        the bar button (one click handler)
Model.js             pure normalizers + argv building
assets/icon.png      the face, background removed
bin/rotmarchy        the engine (works standalone)
share/sources.tsv    the video pool
```

Install and removal go through `omarchy plugin add` / `remove`, so there are no
install scripts and nothing is written outside the plugin folder.

MIT.
