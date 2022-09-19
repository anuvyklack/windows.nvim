local calculate_layout = require('windows.calculate-layout')
local resize_windows = require('windows.lib.resize-windows').resize_windows
local merge_resize_data = require('windows.lib.resize-windows').merge_resize_data
local autowidth = require('windows.autowidth')
local Window = require('windows.lib.api').Window
local config = require('windows.config')
local cache = require('windows.cache')
local autocmd = vim.api.nvim_create_autocmd
local augroup_name = 'windows.maximize'
local augroup
local command = vim.api.nvim_create_user_command
local M = {}

---@type win.ResizeWindowsAnimated?
local animation
if config.animation.enable then
   local ResizeWindowsAnimated = require('windows.lib.resize-windows-animated')
   animation = ResizeWindowsAnimated:new()
end

local function setup_autocmds()
   augroup = vim.api.nvim_create_augroup(augroup_name, {})

   autocmd('WinEnter', { group = augroup, callback = function()
      local winsdata
      if cache.restore_maximized then
         local wd = cache.restore_maximized.width or {}
         local hd = cache.restore_maximized.height or {}
         winsdata = merge_resize_data(wd, hd)
         cache.restore_maximized = nil
      else
         winsdata = calculate_layout.equalize_windows(true, true)
      end
      if animation then
         animation:load(winsdata)
         animation:run()
      else
         resize_windows(winsdata)
      end
      vim.api.nvim_clear_autocmds({ group = augroup })
   end })

   autocmd('WinClosed', { group = augroup, callback = function(ctx)
      ---Id of the closing window.
      local id = tonumber(ctx.match) --[[@as integer]]
      local win = Window(id)

      if not win:is_floating() then
         cache.restore_maximized = nil
      end
   end })
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

      if not config.autowidth.enable then
         vim.api.nvim_clear_autocmds({ group = augroup })
      end
   else
      wd, hd = calculate_layout.maximize_window(curwin)
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

      if not config.autowidth.enable then
         setup_autocmds()
      end

   end

   local winsdata = merge_resize_data(wd, hd)

   if animation then
      animation:load(winsdata)
      animation:run()
   else
      resize_windows(winsdata)
   end
end

command('WindowsMaximize',  M.maximize_curwin,  { bang = true })

