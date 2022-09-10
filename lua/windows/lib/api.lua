local class = require('middleclass')
local config = require('windows.config')
local api = vim.api
local M = {}

--------------------------------------------------------------------------------

---@class win.Window
---@field id integer
---@field _original_options? table<string, any>
local Window = class('win.Window')

---@param winid? integer If absent or 0 - the current window ID will be used.
function Window:initialize(winid)
   self.id = (not winid or winid == 0) and api.nvim_get_current_win() or winid
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
      local buf = self:get_buf()
      -- Textwidth
      ---@type integer
      local tw = buf:get_option('textwidth') or 80

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

---@param l win.Window
---@param r win.Window
function Window.__eq(l, r)
   return l.id == r.id
end

---@return win.Buffer
function Window:get_buf()
   return M.Buffer(api.nvim_win_get_buf(self.id))
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
   local buf = self:get_buf()
   local bt = buf:get_option('buftype')
   local ft = buf:get_option('filetype')
   if config.ignore.buftype[bt] or config.ignore.filetype[ft] then
      return true
   else
      return false
   end
end

---@param name string
function Window:get_option(name)
   return api.nvim_win_get_option(self.id, name)
end

---@param name string
function Window:set_option(name, value)
   return api.nvim_win_set_option(self.id, name, value)
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

---@param pos { [1]: integer, [2]: integer }
function Window:set_cursor(pos)
   api.nvim_win_set_cursor(self.id, pos)
end

---@return { [1]: integer, [2]: integer } pos
function Window:get_cursor()
   return api.nvim_win_get_cursor(self.id)
end

--------------------------------------------------------------------------------

---@class win.Buffer
---@field id integer
local Buffer = class('win.Buffer')

function Buffer:initialize(bufnr)
   self.id = bufnr
end

---@param l win.Buffer
---@param r win.Buffer
function Buffer.__eq(l, r)
   return l.id == r.id
end

function Buffer:get_name(name)
   return api.nvim_buf_get_name(self.id)
end

---@param name string
function Buffer:get_option(name)
   return api.nvim_buf_get_option(self.id, name)
end

--------------------------------------------------------------------------------

M.Window = Window
M.Buffer = Buffer

return M
