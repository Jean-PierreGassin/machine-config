local wezterm = require 'wezterm'

local config = wezterm.config_builder()

config.initial_cols = 180
config.initial_rows = 40

config.font = wezterm.font('JetBrains Mono')
config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }
config.font_size = 14

config.color_scheme = 'rose-pine'

local rose_pine = {
  base = '#191724',
  surface = '#1f1d2e',
  overlay = '#26233a',
  muted = '#6e6a86',
  subtle = '#908caa',
  text = '#e0def4',
  iris = '#c4a7e7',
}

config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_max_width = 32
config.window_frame = {
  active_titlebar_bg = rose_pine.base,
  inactive_titlebar_bg = rose_pine.base,
  font = wezterm.font('JetBrains Mono', { weight = 'Regular' }),
  font_size = 13,
}

config.colors = {
  tab_bar = {
    background = rose_pine.base,
    active_tab = { bg_color = rose_pine.overlay, fg_color = rose_pine.text },
    inactive_tab = { bg_color = rose_pine.base, fg_color = rose_pine.muted },
    inactive_tab_hover = { bg_color = rose_pine.surface, fg_color = rose_pine.text, italic = false },
    new_tab = { bg_color = rose_pine.base, fg_color = rose_pine.muted },
    new_tab_hover = { bg_color = rose_pine.surface, fg_color = rose_pine.text },
  },
}

config.window_close_confirmation = 'NeverPrompt'
config.max_fps = 120
config.front_end = 'WebGpu'
config.window_padding = { left = 12, right = 12, top = 8, bottom = 8 }

config.audible_bell = 'SystemBeep'
wezterm.on('bell', function(window, pane)
  window:toast_notification('WezTerm', 'Bell - ' .. pane:get_title(), nil, 4000)
end)

config.scrollback_lines = 10000
config.default_cursor_style = 'SteadyBlock'
config.inactive_pane_hsb = { saturation = 0.9, brightness = 0.7 }
config.window_background_opacity = 0.9
config.macos_window_background_blur = 20
config.window_decorations = 'RESIZE'

return config
