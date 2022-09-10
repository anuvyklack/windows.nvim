local calculate_layout = require('windows.calculate-layout').calculate_layout_for_auto_width
local resize_windows = require('windows.lib.resize-windows')
local Window = require('windows.lib.api').Window
local config = require('windows.config')
local cache = require('windows.cache')
local ffi = require('windows.lib.ffi')
local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup('windows.auto-width', {})
local command = vim.api.nvim_create_user_command
local M = {}

local curbufnr ---@type integer
local curwin ---@type win.Window

---@type win.ResizeWindowsAnimated?
local animation
if config.animation then
   animation = require('windows.lib.ResizeWindowsAnimated'):new()
end

local function setup_layout()
   local winsdata = calculate_layout(curwin)
   if winsdata then
      if animation then
         local cursor_pos

         local win_cache = cache.window[curwin]
         if win_cache then
            cursor_pos = win_cache.cursor_pos
         end

         animation:load(winsdata, cursor_pos)
         animation:run()
      else
         resize_windows(winsdata)
      end
   end
end

---Is resizing deferred?
local resizing_defered = false

function M.enable_auto_width()

   autocmd('BufWinEnter', { group = augroup, callback = function(ctx)
      resizing_defered = false
      if vim.fn.getcmdwintype() ~= '' then
         -- in "[Command Line]" window
         return
      end
      curbufnr = ctx.buf
      setup_layout()
   end })

   autocmd('WinEnter', { group = augroup, callback = function(ctx)
      local win = Window(0) ---@type win.Window
      if win:is_floating() or (win == curwin and ctx.buf == curbufnr) then
         return
      end
      curwin = win

      local win_cache = cache.window[curwin]
      if win_cache then
         local cursor_pos = win_cache.cursor_pos
         local width = curwin:get_width() - ffi.curwin_col_off()
         if width > cursor_pos[2] then
            curwin:set_cursor(cursor_pos)
         else
            curwin:set_cursor({cursor_pos[1], width - 1})
         end
      end

      resizing_defered = true
      vim.defer_fn(function()
         if resizing_defered then
            setup_layout()
            resizing_defered = false
         end
      end, 10)
   end })

   autocmd('WinLeave', { group = augroup, callback = function()
      local win = Window() ---@type win.Window
      local cursor_pos = win:get_cursor()
      cache.window[win] = {
         cursor_pos = cursor_pos
      }
      -- win:set_cursor({cursor_pos[1], 0})
   end })

   autocmd('WinClosed', { group = augroup, callback = function(ctx)
      ---Id of the closing window.
      local id = tonumber(ctx.match) --[[@as integer]]
      local win = Window(id) ---@type win.Window
      if win:is_floating() or win:is_ignored() then
         return
      end
      cache.window[id] = nil
   end })

   autocmd('TabLeave', { group = augroup, callback = function()
      if animation then animation:finish() end
   end })

end

function M.disable_auto_width()
   vim.api.nvim_clear_autocmds({ group = augroup })
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
