---
--- Everywhere where you see something like: "n - 1", "-n  + 1" or "-1", this
--- is a subtraction of the width of separators between children frames from
--- frame width.
---
local Frame = require('windows.lib.frame')
local M = {}

---Calculate layout for auotwidth
---@param curwin win.Window
function M.calculate_layout_for_auto_width(curwin)
---@return win.WinResizeData[] | nil
   local topFrame = Frame() ---@type win.Frame
   if topFrame.type == 'leaf' then
      return
   end
   topFrame:mark_fixed_width()

   if curwin:is_valid()
      and not curwin:is_floating()
      and not curwin:get_option('winfixwidth')
      and not curwin:is_ignored()
   then
      local curwinLeaf = topFrame:find_window(curwin)
      local topFrame_width = topFrame:get_width()
      local curwin_wanted_width = curwin:get_wanted_width()
      local topFrame_wanted_width = topFrame:get_min_width(curwin, curwin_wanted_width)

      if topFrame_wanted_width > topFrame_width then
         topFrame:maximize_window(curwinLeaf, true, false)
      else
         topFrame:autowidth(curwinLeaf)
      end
   else
      topFrame:equalize_windows(true, false)
   end

   local data = topFrame:get_data_for_width_resizing()

   -- local t = {};
   -- for _, d in ipairs(data) do
   --    t[#t+1] = string.format('%d : %d', d.win.id, d.final_width)
   -- end
   -- print(table.concat(t, ' | '))

   return data
end

---@param curwin win.Window
---@return win.WinResizeData[] | nil width
---@return win.WinResizeData[] | nil height
   local topFrame = Frame() ---@type win.Frame
   if topFrame.type == 'leaf' then
      return
   end
   topFrame:mark_fixed_width()
   topFrame:mark_fixed_height()

   local curwinLeaf = topFrame:find_window(curwin)
   topFrame:maximize_window(curwinLeaf, true, true)

   local width_data = topFrame:get_data_for_width_resizing()
   local height_data = topFrame:get_data_for_height_resizing()

   return width_data, height_data
end

end

return M
