local class = require('middleclass')
-- local Animation = require('windows.animation')
local config = require('windows.config')
local api = vim.api
-- local cmd = vim.cmd

---@class WinID : integer

---@class win.Window
---@field id WinID
---@field _original_options? table<string, any>
local Window = class('win.Window')

---@param winid? integer If absent or 0 - the current window ID will be used.
function Window:initialize(winid)
   self.id = (not winid or winid == 0) and api.nvim_get_current_win() or winid
end

---@param l win.Window
---@param r win.Window
function Window.__eq(l, r)
   return l.id == r.id
end

---@return integer bufnr
function Window:get_buf()
   return api.nvim_win_get_buf(self.id)
end

---@return boolean
function Window:is_valid()
   return api.nvim_win_is_valid(self.id)
end

---Is this window floating?
function Window:is_floating()
   return api.nvim_win_get_config(self.id).relative ~= ''
end

---Should we ignore this window during resizing other windows?
function Window:is_ignored()
   local bufnr = self:get_buf()
   local bt = api.nvim_buf_get_option(bufnr, 'buftype')
   local ft = api.nvim_buf_get_option(bufnr, 'filetype')
   if config.ignore.buftype[bt] or config.ignore.filetype[ft] then
      return true
   else
      return false
   end
end

function Window:get_option(name)
   return api.nvim_win_get_option(self.id, name)
end

---Temporary change window scoped option.
---@param name string
---@param value any
function Window:temp_change_option(name, value)
   self._original_options = self._original_options or {}
   if not self._original_options[name] then
      self._original_options[name] = api.nvim_win_get_option(self.id, name)
   end
   api.nvim_win_set_option(self.id, name, value)
end

---Restore all option change with `temp_change_option` method.
function Window:restore_changed_options()
   if self:is_valid() then
      if self._original_options then
         for name, value in pairs(self._original_options) do
            api.nvim_win_set_option(self.id, name, value)
         end
      end
   end
   self._original_options = nil
end

---@return integer
function Window:get_width()
   return api.nvim_win_get_width(self.id)
end

---@return integer width
function Window:get_wanted_width()
   if self:get_option('winfixwidth') then
      return self:get_width()
   end

   local w = config.winwidth
   if 0 < w and w < 1 then
      return math.floor(w * vim.o.columns)
   else
      -- Textwidth
      ---@type integer
      local tw = api.nvim_buf_get_option(self:get_buf(), 'textwidth') or 80

      if tw == 0 then tw = 80 end
      if w < 0 then
         return tw - w
      elseif w == 0 then
         return tw
      elseif 1 <= w and w <= 2 then
         return math.floor(w * tw)
      else
         return tw + w
      end
   end
end

---@return integer
function Window:get_height()
   return api.nvim_win_get_height(self.id)
end

---@param width integer
function Window:set_width(width)
   api.nvim_win_set_width(self.id, width)
end

---@param height integer
function Window:set_height(height)
   api.nvim_win_set_height(self.id, height)
end

return Window
