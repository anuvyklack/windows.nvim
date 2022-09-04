local calculate_layout = require('windows.calculate-layout')
local resize_windows = require('windows.resize-windows')
local Window = require('windows.lib.Window')
local config = require('windows.config')
local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup('windows.auto-width', {})
local command = vim.api.nvim_create_user_command
local M = {}

local curbufnr ---@type integer | nil
local curwin ---@type win.Window | nil

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

---Coroutine wrap around "setup_layout" function.
---@type function?
local setup_layout_co

function M.enable_auto_width()
   autocmd('BufWinEnter', { group = augroup, callback = function(ctx)
      if vim.fn.getcmdwintype() ~= '' then
         setup_layout_co = nil
         return
      end
      curbufnr = ctx.buf

      if setup_layout_co then
         setup_layout_co()
         setup_layout_co = nil
      else
         setup_layout()
      end
   end })

   autocmd('WinEnter', { group = augroup, callback = function(ctx)
      local win = Window(0) ---@type win.Window
      if win:is_floating() or (win == curwin and ctx.buf == curbufnr) then
         return
      end
      curwin = win

      setup_layout_co = coroutine.wrap(setup_layout)

      vim.defer_fn(function()
         if setup_layout_co then
            setup_layout_co()
            setup_layout_co = nil
         end
      end, 10)
   end })

   autocmd('TabLeave', { group = augroup, callback = function()
      if animation then animation:finish() end
      curwin = nil
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
