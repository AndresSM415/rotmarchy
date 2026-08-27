-- Rotmarchy window rules.
--
-- Loaded from ~/.config/hypr/hyprland.lua with:
--   require("hypr.rotmarchy")
--
-- Entirely optional. Without it the videos still float, because Omarchy floats
-- every mpv window by default (see $OMARCHY_PATH/default/hypr/apps/system.lua)
-- — they just arrive centred and bordered before the helper moves them.

-- Deliberately no size or position here. The helper picks a random spot and
-- applies it with `hyprctl dispatch` once the window has mapped, so a static
-- rule would only fight it. This sets the things that *are* constant.
o.window("^Rotmarchy$", {
  tag = "-default-opacity",
  float = true,
  pin = true,
  no_initial_focus = true,
  no_dim = true,
  border_size = 0,
  opacity = "1 1",
})
