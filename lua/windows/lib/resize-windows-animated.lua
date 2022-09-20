---
--- Singleton
---
local singleton = require('windows.class.singleton')
local Animation = require('animation')
local Window = require('windows.lib.api').Window
local cache = require('windows.cache')
local round = require('windows.lib.util').round
local ffi = require('windows.lib.ffi')
local nvim_feedkeys = vim.api.nvim_feedkeys
local winsaveview = vim.fn.winsaveview

---@class win.ResizeWindowsAnimated.Data
---@field win win.Window
---@field initial_width?  integer
---@field initial_height? integer
---@field final_width?    integer
---@field final_height?   integer
---@field delta_width?    integer The delta between initial and final widths.
---@field delta_height?   integer The delta between initial and final heights.

---@class win.ResizeWindowsAnimated : nvim.Animation
---@field winsdata win.ResizeWindowsAnimated.Data[]
---@field curwin win.Window
---@field cursor_pos? { [1]: integer, [2]: integer } The cursor position of the current window
---@field cursor_virtcol? integer
---@field new fun(...):win.ResizeWindowsAnimated
local ResizeWindowsAnimated = singleton(Animation)

function ResizeWindowsAnimated:initialize(duration, fps, easing)
   Animation.initialize(self, duration, fps, easing, nil)
end

---@param winsdata win.WinResizeData[]
function ResizeWindowsAnimated:load(winsdata)
   if self:is_running() then self:finish() end

   self.winsdata = {}
   for i, wd in ipairs(winsdata) do
      local data = {}
      data.win = wd.win
      if wd.width then
         local fin = wd.width -- final
         local init = wd.win:get_width() -- initial
         data.initial_width = init
         data.delta_width = fin - init -- delta
      end
      if wd.height then
         local fin = wd.height -- final
         local init = wd.win:get_height() -- initial
         data.initial_height = init
         data.delta_height = fin - init -- delta
      end
      self.winsdata[i] = data
   end

   self.curwin = Window(0)

   if winsaveview().leftcol == 0 then
      self.cursor_virtcol = cache.cursor_virtcol[self.curwin]
   end

   self:set_callback(function(fraction)
      for _, d in ipairs(self.winsdata) do
         if d.delta_width then
            local width = d.initial_width + round(fraction * d.delta_width)
            d.win:set_width(width)
         end
         if d.delta_height then
            local height = d.initial_height + round(fraction * d.delta_height)
            d.win:set_height(height)
         end
      end

      if self.cursor_virtcol then
         local width = self.curwin:get_width() - ffi.curwin_col_off()
         local col
         if width < self.cursor_virtcol then
            col = width
         else
            col = self.cursor_virtcol
            self.cursor_virtcol = nil
         end
         vim.api.nvim_feedkeys(col..'|', 'nx', false)
      else
         nvim_feedkeys('ze', 'nx', false)
      end

   end)
end

function ResizeWindowsAnimated:run()
   if self:is_running() then return end

   if self.cursor_virtcol and cache.virtualedit and cache.virtualedit.win == self.curwin then
      self.virtualedit = cache.virtualedit.value
   else
      self.virtualedit = vim.api.nvim_win_get_option(0, 'virtualedit')
   end

   Animation.run(self)
end

function ResizeWindowsAnimated:finish()
   if not self:is_running() then return end

   Animation.finish(self)

   if self.virtualedit and self.curwin:is_valid() then
      self.curwin:set_option('virtualedit', self.virtualedit)
   end
   cache.virtualedit = nil

   self.winsdata = {}
end

return ResizeWindowsAnimated
