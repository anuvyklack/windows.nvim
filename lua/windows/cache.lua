-- local class = require('middleclass')
--
-- ---@class win.Cache
-- local Cache = class('win.Cache')

local cache = {
   buffer = {},
   window = {}
}

setmetatable(cache.window, {
   ---@param w win.Window | number
   __index = function(self, w)
      local id = (type(w) == 'number') and w or w.id
      return rawget(self, id)
   end,

   ---@param w win.Window | number
   __newindex = function(self, w, value)
      local id = (type(w) == 'number') and w or w.id
      rawset(self, id, value)
   end
})

return cache
