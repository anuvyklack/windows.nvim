local calc_layout = require('windows.calculate-layout')
local autowidth = require('windows.autowidth')
local config = require('windows.config')
local cache = require('windows.cache')
local Window = require('windows.lib.api').Window
local resize_windows = require('windows.lib.resize-windows').resize_windows
local merge_resize_data = require('windows.lib.resize-windows').merge_resize_data
local api = vim.api
local tbl_is_empty = vim.tbl_isempty
local autocmd = api.nvim_create_autocmd
local command = api.nvim_create_user_command
local augroup_name = 'windows.maximize'
local augroup
local M = {}

---@type win.ResizeWindowsAnimated?
local animation
if config.animation.enable then
   local ResizeWindowsAnimated = require('windows.lib.resize-windows-animated')
   animation = ResizeWindowsAnimated:new()
end

local function setup_autocmds()
   augroup = api.nvim_create_augroup(augroup_name, {})

   autocmd('WinEnter', { group = augroup, callback = function()
      local curwin = Window()
      if curwin:is_floating() then return end

      api.nvim_clear_autocmds({ group = augroup })

      local winsdata
      if cache.maximized then
         local wd = cache.maximized.width or {}
         local hd = cache.maximized.height or {}
         winsdata = merge_resize_data(wd, hd)
         cache.maximized = nil
      else
         winsdata = calc_layout.equalize_wins(true, true)
         if tbl_is_empty(winsdata) then return end
      end

      if animation then
         animation:load(winsdata)
         animation:run()
      else
         resize_windows(winsdata)
      end
   end })

   autocmd('WinClosed', { group = augroup, callback = function(ctx)
      ---Id of the closing window.
      local id = tonumber(ctx.match) --[[@as integer]]
      local win = Window(id)

      if not win:is_floating() then
         cache.maximized = nil
      end
   end })
end

---Maximize current window
function M.maximize()
   ---@type win.Window
   local curwin = Window()
   if curwin:is_floating() then return end

   autowidth.resizing_request = false

   local wd, hd

   if cache.maximized then
      wd = cache.maximized.width or {}
      hd = cache.maximized.height or {}
      cache.maximized = nil

      if not config.autowidth.enable then
         api.nvim_clear_autocmds({ group = augroup })
      end
   else
      wd, hd = calc_layout.maximize_win(curwin, true, true)
      if tbl_is_empty(wd) then return end

      cache.maximized = {}

      local width_cache = {}
      for i, d in ipairs(wd) do
         local win = d.win
         width_cache[i] = {
            win = win,
            width = win:get_width()
         }
      end
      cache.maximized.width = width_cache

      local height_cache = {}
      for i, d in ipairs(hd) do
         local win = d.win
         height_cache[i] = {
            win = win,
            height = win:get_height()
         }
      end
      cache.maximized.height = height_cache

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

---Maximize current window verticaly.
---@See CTRL-W_bar
function M.maximize_verticaly()
   ---@type win.Window
   local curwin = Window()
   if curwin:is_floating() then return end

   local winsdata
   if cache.maximized and cache.maximized.height then -- Already maximized
      winsdata = cache.maximized.height
      cache.maximized.height = nil
   else
      _, winsdata = calc_layout.maximize_win(curwin, false, true)
      if tbl_is_empty(winsdata) then return end

      cache.maximized = cache.maximized or {}

      local height_cache = {}
      for i, d in ipairs(winsdata) do
         local win = d.win
         height_cache[i] = {
            win = win,
            height = win:get_height()
         }
      end
      cache.maximized.height = height_cache

      if not config.autowidth.enable then
         setup_autocmds()
      end
   end

   if animation then
      animation:load(winsdata)
      animation:run()
   else
      resize_windows(winsdata)
   end
end

---Maximize current window horizontally.
---@See CTRL-W__
function M.maximize_horizontally()
   ---@type win.Window
   local curwin = Window()
   if curwin:is_floating() then return end

   local winsdata
   if cache.maximized and cache.maximized.width then -- Already maximized
      winsdata = cache.maximized.width
      cache.maximized.width = nil
   else
      winsdata, _ = calc_layout.maximize_win(curwin, true, false)
      if tbl_is_empty(winsdata) then return end

      cache.maximized = cache.maximized or {}

      local width_cache = {}
      for i, d in ipairs(winsdata) do
         local win = d.win
         width_cache[i] = {
            win = win,
            width = win:get_width()
         }
      end
      cache.maximized.width = width_cache

      if not config.autowidth.enable then
         setup_autocmds()
      end
   end

   autowidth.resizing_request = false

   if animation then
      animation:load(winsdata)
      animation:run()
   else
      resize_windows(winsdata)
   end
end

---Equalize all windows heights and widths.
---@See CTRL-W_=
function M.equalize()
   ---@type win.Window
   local curwin = Window()
   if curwin:is_floating() then return end

   cache.maximized = nil
   autowidth.resizing_request = false

   local winsdata = calc_layout.equalize_wins(true, true)
   if tbl_is_empty(winsdata) then return end

   if animation then
      animation:load(winsdata)
      animation:run()
   else
      resize_windows(winsdata)
   end
end

command('WindowsMaximize', M.maximize, { bang = true })
command('WindowsMaximizeVertically', M.maximize_verticaly, { bang = true })
command('WindowsMaximizeHorizontally', M.maximize_horizontally, { bang = true })
command('WindowsEqualize', M.equalize, { bang = true })

return M

