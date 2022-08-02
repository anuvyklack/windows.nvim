local calculate_layout = require('windows.calculate-layout')
local resize_windows = require('windows.resize-windows')
local Window = require('windows.lib.Window')
local config = require('windows.config')
local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup('windows.auto-width', {})
local command = vim.api.nvim_create_user_command
local M = {}

---Previous context: combination of window and buffer we have been in.
---@type { win: win.Window, buf: integer }
local context = {}

local curbufnr ---@type integer | nil
local curwin ---@type win.Window | nil
local prevwin ---@type win.Window | nil

---@type win.ResizeWindowsAnimated | nil
local animation
if config.animation then
   animation = require('windows.lib.ResizeWindowsAnimated'):new()
end

local autocmd_timer ---@type luv.Timer | nil
local setup_layout_co ---@type thread | nil

local function setup_layout()
   if autocmd_timer then
      autocmd_timer:close()
      autocmd_timer = nil
   end

   local winsdata = calculate_layout(curwin, prevwin)
   if winsdata then
      if animation then
         animation:load(winsdata)
         animation:run()
      else
         resize_windows(winsdata)
      end
   end
end

function M.enable_auto_width()

   autocmd('BufWinEnter', { group = augroup, callback = function(ctx)
      if Window(0):is_floating() then return end
      curbufnr = ctx.buf

      -- if setup_layout_co and coroutine.status(setup_layout_co) ~= 'dead' then
      if setup_layout_co then
         coroutine.resume(setup_layout_co)
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

      prevwin, curwin = curwin, win

      setup_layout_co = coroutine.create(setup_layout)

      vim.defer_fn(function()
         if setup_layout_co then
            coroutine.resume(setup_layout_co)
            setup_layout_co = nil
         end
      end, 10)
   end })

   autocmd('TabLeave', { group = augroup, callback = function()
      if animation then animation:finish() end
      curwin = nil
      prevwin = nil
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
