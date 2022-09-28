local config = require('windows.config')
local M = {}

function M.setup(input)
   config(input)

   if config.animation.enable then
      local ResizeWindowsAnimated = require('windows.lib.resize-windows-animated')
      ResizeWindowsAnimated:new(config.animation.duration,
                                config.animation.fps,
                                config.animation.easing)
   end

   if config.autowidth.enable then
      require('windows.autowidth').enable()
   end

   require('windows.commands')
end

return M
