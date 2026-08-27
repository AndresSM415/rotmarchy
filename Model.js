.pragma library

// Pure helpers for the Rotmarchy bar widget. No QML imports, no side effects —
// everything here is a function of its arguments.
//
// NOTE for anyone editing this file: `.pragma library` modules are evaluated
// once and cached by the QML engine. A hot reload re-reads the QML but keeps
// this cached, so edits here do nothing until the shell is restarted.

var CATEGORIES = ["random", "minecraft", "familyguy", "subwaysurfer", "gta"]
var HEIGHTS = [480, 720, 1080]

// Settings arrive from shell.json, which is a file the user edits by hand.
// Treat every value as untrusted: clamp it to the documented grammar here, at
// the boundary, before it can reach an argv vector.

function normalizeCategory(value) {
  var v = String(value || "").toLowerCase()
  return CATEGORIES.indexOf(v) >= 0 ? v : "random"
}

function normalizeHeight(value) {
  var n = parseInt(value, 10)
  return HEIGHTS.indexOf(n) >= 0 ? n : 720
}

// Build the argv vector for the helper. Passed to Util.execArgv, which runs it
// via `exec "$@"` — the values land in positional parameters and are never
// re-tokenized by a shell. Every value has been through a normalizer above.
function launchArgv(helper, opts) {
  return [
    "env",
    "ROTMARCHY_HEIGHT=" + normalizeHeight(opts.height),
    helper,
    normalizeCategory(opts.category)
  ]
}

function stopArgv(helper) {
  return [helper, "stop"]
}

// Entirely made up, which is the joke. 1-99 so it never reads as a real
// measurement of anything.
function rollCortisol() {
  return 1 + Math.floor(Math.random() * 99)
}

function cortisolLabel(percent) {
  return "Cortisol level: " + percent + "%"
}
