-- local class = require('middleclass')
--
-- ---@class win.Cache

local cache = {
   buffer = {},
   cursor_virtcol = {},
   virtualedit = {}, ---@type { win: win.Window, value: integer }
   restore_maximized = nil
}

local mt = {
   ---@param w win.Window | number
   __index = function(self, w)
      local id = (type(w) == 'number') and w or w.id
      return rawget(self, id)
   end,

   ---@param w win.Window | number
   __newindex = function(self, w, value)
      if w then
         local id = (type(w) == 'number') and w or w.id
         rawset(self, id, value)
      end
   end
}

setmetatable(cache.cursor_virtcol, mt)

return cache
