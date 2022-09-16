local config = require('windows.config')
local M = {}

function M.setup(input)
   config(input)

   if config.animation then
      local ResizeWindowsAnimated = require('windows.lib.resize-windows-animated')
      ResizeWindowsAnimated:new(config.animation.duration,
                                config.animation.fps,
                                config.animation.easing)
   end

   if config.autowidth.enable then
      require('windows.autowidth').enable_auto_width()
   end

   require('windows.maximize-window')
end

return M
