local api = vim.api
local fn = vim.fn
local calc_layout = require('windows.calculate-layout')
local config = require('windows.config')
local cache = require('windows.cache')
local ffi = require('windows.lib.ffi')
local Window = require('windows.lib.api').Window
local resize_windows = require('windows.lib.resize-windows').resize_windows
local merge_resize_data = require('windows.lib.resize-windows').merge_resize_data
local tbl_is_empty = vim.tbl_isempty
local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup('windows.autowidth', {})
local command = vim.api.nvim_create_user_command
local M = {}

local curwin   ---@type win.Window
local curbufnr ---@type integer

---Flag for when a new window has been created.
---@type boolean
local new_window = false

---To avoid multiple layout resizing in row, when several autocommands were
---triggered.
---@type boolean
M.resizing_request = false

---@type win.ResizeWindowsAnimated | nil
local animation
if config.animation.enable then
   local ResizeWindowsAnimated = require('windows.lib.resize-windows-animated')
   animation = ResizeWindowsAnimated:new()
end

local function setup_layout()
   if not curwin or not M.resizing_request then
      return
   end
   M.resizing_request = false

   local winsdata = calc_layout.autowidth(curwin)
   if tbl_is_empty(winsdata) then return end

   if cache.maximized then
      if cache.maximized.height then
         local height_data = new_window and calc_layout.equalize_wins(false, true)
                             or cache.maximized.height
         winsdata = merge_resize_data(winsdata, height_data)
      end
      cache.maximized = nil
   end
   new_window = false

   if animation then
      animation:load(winsdata)
      animation:run()
   else
      resize_windows(winsdata)
   end
end

---Enable autowidth
function M.enable()
   autocmd('BufWinEnter', { group = augroup, callback = function(ctx)
      local win = Window(0) ---@type win.Window
      if win:is_floating()
         or (new_window and win:is_ignored())
         or win:get_type() == 'command' -- "[Command Line]" window
      then
         return
      end
      cache.cursor_virtcol[curwin] = nil

      M.resizing_request = true

      curbufnr = ctx.buf
      setup_layout()
   end })

   autocmd('VimResized', { group = augroup, callback = function()
      M.resizing_request = true
      setup_layout()
   end })

   autocmd('WinEnter', { group = augroup, callback = function(ctx)
      local win = Window(0) ---@type win.Window
      if win:is_floating()
         or (win == curwin and ctx.buf == curbufnr)
      then
         return
      end
      curwin = win

      M.resizing_request = true

      if animation then
         local virtcol = cache.cursor_virtcol[curwin]
         if virtcol then
            local leftcol = fn.winsaveview().leftcol
            local width = curwin:get_width() - ffi.curwin_col_off()
            if leftcol == 0 and width < virtcol then
               cache.virtualedit = {
                  win = curwin,
                  value = curwin:get_option('virtualedit')
               }
               curwin:set_option('virtualedit', 'all')
               api.nvim_feedkeys(width..'|', 'nx', false)
               fn.winrestview({ leftcol = 0 })
            end
         end
      end

      -- Defer resizing to handle the case when a new buffer is opened.
      -- Then 'BufWinEnter' event will be fired after 'WinEnter'.
      vim.defer_fn(setup_layout, 10)
   end })

   autocmd('WinNew', { group = augroup, callback = function()
      new_window = true
   end })

   if animation then
      autocmd('WinLeave', { group = augroup, callback = function()
         local win = Window() ---@type win.Window
         if not win:is_floating() and not win:is_ignored()
            and not animation:is_running()
         then
            cache.cursor_virtcol[win] = fn.wincol() - ffi.curwin_col_off()
         end
      end })

      autocmd('WinClosed', { group = augroup, callback = function(ctx)
         ---Id of the closing window.
         local id = tonumber(ctx.match) --[[@as integer]]
         local win = Window(id)

         if not win:is_floating() then
            animation:finish()
            cache.cursor_virtcol[id] = nil
         end
      end })

      autocmd('TabLeave', { group = augroup, callback = function()
         animation:finish()
      end })
   end
end

---Disable autowidth
function M.disable()
   api.nvim_clear_autocmds({ group = augroup })
end

---Toggle autowidth
function M.toggle()
   if config.autowidth.enable then
      M.disable()
      config.autowidth.enable = false
   else
      M.enable()
      config.autowidth.enable = true
   end
end

command('WindowsEnableAutowidth',  M.enable,  { bang = true })
command('WindowsDisableAutowidth', M.disable, { bang = true })
command('WindowsToggleAutowidth',  M.toggle,  { bang = true })

return M
