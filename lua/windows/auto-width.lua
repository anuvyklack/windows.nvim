local calculate_layout = require('windows.calculate-layout').calculate_layout_for_auto_width
local resize_windows = require('windows.lib.resize-windows')
local Window = require('windows.lib.Window')
local config = require('windows.config')
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
         animation:load(winsdata)
         animation:run()
      else
         resize_windows(winsdata)
      end
   end
end

---Is resizing deferred?
local defered_resizing = false

function M.enable_auto_width()
   autocmd('BufWinEnter', { group = augroup, callback = function(ctx)
      defered_resizing = false
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

      defered_resizing = true

      vim.defer_fn(function()
         if defered_resizing then
            setup_layout()
            defered_resizing = false
         end
      end, 10)
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
