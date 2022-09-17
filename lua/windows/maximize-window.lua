local calculate_layout = require('windows.calculate-layout').maximize_window
local resize_windows = require('windows.lib.resize-windows').resize_windows
local merge_resize_data = require('windows.lib.resize-windows').merge_resize_data
local autowidth = require('windows.autowidth')
local Window = require('windows.lib.api').Window
local config = require('windows.config')
local cache = require('windows.cache')
local command = vim.api.nvim_create_user_command
local M = {}

---@type win.ResizeWindowsAnimated?
local animation
if config.animation.enable then
   local ResizeWindowsAnimated = require('windows.lib.resize-windows-animated')
   animation = ResizeWindowsAnimated:new()
end

function M.maximize_curwin()
   local curwin = Window() ---@type win.Window
   if curwin:is_floating() or vim.api.nvim_tabpage_list_wins(0) == 1 then
      return
   end

   autowidth.resizing_requested = false

   local wd, hd
   if cache.restore_maximized then
      wd = cache.restore_maximized.width or {}
      hd = cache.restore_maximized.height or {}
      cache.restore_maximized = nil
   else
      wd, hd = calculate_layout(curwin)
      if not wd then
         return
      end
      ---@cast wd -nil
      ---@cast hd -nil
      cache.restore_maximized = {}
      local new_cache = {}
      for i, d in ipairs(wd) do
         local win = d.win
         new_cache[i] = {
            win = win,
            width = win:get_width()
         }
      end
      cache.restore_maximized.width = new_cache
      new_cache = {}
      for i, d in ipairs(hd) do
         local win = d.win
         new_cache[i] = {
            win = win,
            height = win:get_height()
         }
      end
      cache.restore_maximized.height = new_cache
   end

   local winsdata = merge_resize_data(wd, hd)

   if animation then
      animation:load(winsdata)
      animation:run()
   else
      resize_windows(winsdata)
   end
end

command('WindowsMaximaze',  M.maximize_curwin,  { bang = true })

