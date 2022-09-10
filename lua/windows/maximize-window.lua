local calculate_layout = require('windows.calculate-layout').calculate_layout_for_window_maximization
local resize_windows = require('windows.lib.resize-windows')
local Window = require('windows.lib.api').Window
local config = require('windows.config')
local cache = require('windows.cache')
local command = vim.api.nvim_create_user_command
local M = {}

---@type win.ResizeWindowsAnimated?
local animation
if config.animation then
   animation = require('windows.lib.ResizeWindowsAnimated'):new()
end

function M.maximize_curwin()
   local curwin = Window() ---@type win.Window
   if curwin:is_floating() then return end
   local winsdata = calculate_layout(curwin)

   if winsdata then
      if animation then
         animation:load(winsdata)
         animation:run()
      else
         resize_windows(winsdata)
      end
   end
end

command('WindowsMaximaze',  M.maximize_curwin,  { bang = true })

