-- vim.api.nvim_tabpage_list_wins
-- vim.fn.getbufinfo
-- vim.go.eadirection
local config = require('windows.config')
local M = {}

function M.setup(input)
   config(input)

   if config.animation then
      require('windows.lib.ResizeWindowsAnimated'):new(
         config.animation.duration, config.animation.fps, config.animation.easing)
   end

   if config.enable_autowidth then
      require('windows.auto-width').enable_auto_width()
   end

   require('windows.maximize-window')
end

return M
