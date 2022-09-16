local calculate_layout = require('windows.calculate-layout')
local resize_windows = require('windows.lib.resize-windows').resize_windows
local merge_resize_data = require('windows.lib.resize-windows').merge_resize_data
local Window = require('windows.lib.api').Window
local config = require('windows.config')
local cache = require('windows.cache')
local ffi = require('windows.lib.ffi')
local fn = vim.fn
local api = vim.api
local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup('windows.auto-width', {})
local command = vim.api.nvim_create_user_command
local M = {}

local curwin ---@type win.Window
local curbufnr ---@type integer

---Flag for when a new window has been created.
---@type boolean
local new_window

M.resizing_requested = false ---@type boolean

---@type win.ResizeWindowsAnimated?
local animation
if config.animation then
   local ResizeWindowsAnimated = require('windows.lib.resize-windows-animated')
   animation = ResizeWindowsAnimated:new()
end

local function setup_layout()
   if not curwin or not M.resizing_requested then
      return
   end
   M.resizing_requested = false

   local winsdata = calculate_layout.autowidth(curwin)

   if not winsdata then
      return
   end

   if cache.restore_maximized then
      local height_data
      if new_window then
         height_data = calculate_layout.equalize_heights()
      else
         height_data = cache.restore_maximized.height
      end
      winsdata = merge_resize_data(winsdata, height_data)
      cache.restore_maximized = nil
   end
   if animation then
      animation:load(winsdata)
      animation:run()
   else
      resize_windows(winsdata)
   end
end

---Is resizing deferred?
local resizing_defered = false

function M.enable_auto_width()
   autocmd('BufWinEnter', { group = augroup, callback = function(ctx)
      resizing_defered = false

      local win = Window(0) ---@type win.Window
      if win:is_floating()
         or win:get_type() == 'command' -- in "[Command Line]" window
         -- or vim.fn.getcmdwintype() ~= '' -- in "[Command Line]" window
      then
         return
      end
      cache.cursor_virtcol[curwin] = nil

      M.resizing_requested = true

      curbufnr = ctx.buf
      setup_layout()
   end })

   autocmd('WinEnter', { group = augroup, callback = function(ctx)
      local win = Window(0) ---@type win.Window
      if win:is_floating() or (win == curwin and ctx.buf == curbufnr) then
         return
      end
      curwin = win

      M.resizing_requested = true

      if animation then
         local virtcol = cache.cursor_virtcol[curwin]
         if virtcol then
            local leftcol = fn.winsaveview().leftcol
            local width = curwin:get_width() - ffi.curwin_col_off()
            if leftcol == 0 and width < virtcol then
               cache.virtualedit = { win = curwin, value = curwin:get_option('virtualedit') }
               curwin:set_option('virtualedit', 'all')
               api.nvim_feedkeys(width..'|', 'nx', false)
               fn.winrestview({ leftcol = 0 })
            end
         end
      end

      resizing_defered = true
      vim.defer_fn(function()
         if resizing_defered then
            resizing_defered = false
            setup_layout()
         end
      end, 10)
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

function M.disable_auto_width()
   api.nvim_clear_autocmds({ group = augroup })
end

function M.toggle_auto_width()
   if config.autowidth.enable then
      M.disable_auto_width()
      config.autowidth.enable = false
   else
      M.enable_auto_width()
      config.autowidth.enable = true
   end
end

command('WindowsEnableAutoWidth',  M.enable_auto_width,  { bang = true })
command('WindowsDisableAutoWidth', M.disable_auto_width, { bang = true })
command('WindowsToggleAutoWidth',  M.toggle_auto_width,  { bang = true })

return M
