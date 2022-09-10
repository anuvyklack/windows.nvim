local calculate_layout = require('windows.calculate-layout').calculate_layout_for_auto_width
local resize_windows = require('windows.lib.resize-windows').resize_windows
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

---@type win.ResizeWindowsAnimated?
local animation
if config.animation then
   animation = require('windows.lib.ResizeWindowsAnimated'):new()
end

local function setup_layout()
   if not curwin then return end
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

---Is resizing deferred?
local resizing_defered = false

function M.enable_auto_width()
   -- autocmd('VimEnter', { group = augroup, callback = function()
   --    curwin = Window()
   -- end })

   autocmd('BufWinEnter', { group = augroup, callback = function(ctx)
      resizing_defered = false

      local win = Window(0) ---@type win.Window
      if win:is_floating()
         or vim.fn.getcmdwintype() ~= '' -- in "[Command Line]" window
      then
         return
      end
      cache.cursor_virtcol[curwin] = nil

      curbufnr = ctx.buf
      setup_layout()
   end })

   autocmd('WinEnter', { group = augroup, callback = function(ctx)
      local win = Window(0) ---@type win.Window
      -- P('WinEnter', win.id)
      if win:is_floating() or (win == curwin and ctx.buf == curbufnr) then
         return
      end
      curwin = win

      if animation then
         -- local cursor_pos = curwin:get_cursor()
         -- cache.cursor_pos[curwin] = cursor_pos
         -- local cursor_pos = cache.cursor_pos[curwin]
         local virtcol = cache.cursor_virtcol[curwin]
         if virtcol then
            -- vim.o.virtualedit = 'all'
            -- local width = curwin:get_width() - ffi.curwin_col_off()
            local leftcol = fn.winsaveview().leftcol
            local width = curwin:get_width() - ffi.curwin_col_off()
            -- local virtcol = fn.wincol() - ffi.curwin_col_off()
            -- P(curwin.id, leftcol, width, virtcol)
            if leftcol == 0 and width < virtcol then
               -- P('leftcol == 0')
               cache.virtualedit = { win = curwin, value = curwin:get_option('virtualedit') }
               curwin:set_option('virtualedit', 'all')
               -- curwin:temp_change_option('virtualedit', 'all')
               -- curwin:set_cursor({ line, 0 })
               -- fn.setcursorcharpos(0, width-1)
               api.nvim_feedkeys(width..'|', 'nx', false)
               fn.winrestview({ leftcol = 0 })
               -- curwin:set_cursor({ line, width - 1 })
               -- cache.cursor_pos[curwin] = { line, col }
               -- curwin:restore_changed_options()
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

   if animation then
      autocmd('WinLeave', { group = augroup, callback = function()
         -- P('WinLeave')
         local win = Window() ---@type win.Window
         if not win:is_floating() and not win:is_ignored()
            and not animation:is_running()
         then
            -- cache.cursor_pos[win] = win:get_cursor()
            cache.cursor_virtcol[win] = fn.wincol() - ffi.curwin_col_off()
            -- P(win.id, 'cursor virtcol saved', cache.cursor_virtcol[win])
         end
      end })

      autocmd('WinClosed', { group = augroup, callback = function(ctx)
         ---Id of the closing window.
         local id = tonumber(ctx.match) --[[@as integer]]
         -- local win = Window(id) ---@type win.Window
         -- if win:is_valid() and (win:is_floating() or win:is_ignored()) then
         --    return
         -- end
         cache.cursor_pos[id] = nil
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
   if config.enable_autowidth then
      M.disable_auto_width()
      config.enable_autowidth = false
   else
      M.enable_auto_width()
      config.enable_autowidth = true
   end
end

command('WindowsEnableAutoWidth',  M.enable_auto_width,  { bang = true })
command('WindowsDisableAutoWidth', M.disable_auto_width, { bang = true })
command('WindowsToggleAutoWidth',  M.toggle_auto_width,  { bang = true })

return M
