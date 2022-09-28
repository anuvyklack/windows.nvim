local cache = {
   buffer = {},

   ---The screen column number of the cursor of the active window.
   cursor_virtcol = {},

   ---@type { win: win.Window, value: integer }
   virtualedit = {},

   ---The original widths' and heights' data of the windows to restore later.
   ---@type { width: win.WinResizeData[], height: win.WinResizeData[] }
   maximized = nil
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
