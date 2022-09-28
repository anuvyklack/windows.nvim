---
--- Everywhere where you see something like: "n-1", "-n +1" or "-1", this
--- is a subtraction of the width of separators between children frames from
--- frame width.
---
local Frame = require('windows.lib.frame')
local merge_resize_data = require('windows.lib.resize-windows').merge_resize_data
local M = {}

---Calculate layout for auotwidth
---@param curwin win.Window
---@return win.WinResizeData[]
function M.autowidth(curwin)
   local topFrame = Frame() ---@type win.Frame
   if topFrame.type == 'leaf' then
      return {}
   end

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

   -- --------------------------------------------------------
   -- local t = {};
   -- for _, d in ipairs(data) do
   --    t[#t+1] = string.format('%d : %d', d.win.id, d.width)
   -- end
   -- print(table.concat(t, ' | '))
   -- --------------------------------------------------------

   return data
end

---@param win win.Window
---@param do_width boolean
---@param do_height boolean
---@return win.WinResizeData[] width
---@return win.WinResizeData[] height
function M.maximize_win(win, do_width, do_height)
   local topFrame = Frame() ---@type win.Frame
   if topFrame.type == 'leaf' then
      return {}, {}
   end

   local winLeaf = topFrame:find_window(win)
   topFrame:maximize_window(winLeaf, do_width, do_height)

   local width_data = topFrame:get_data_for_width_resizing()
   local height_data = topFrame:get_data_for_height_resizing()

   return width_data, height_data
end

---@param do_width boolean
---@param do_height boolean
---@return win.WinResizeData[]
function M.equalize_wins(do_width, do_height)
   assert(do_width or do_height, 'No arguments have been passed')
   local topFrame = Frame() ---@type win.Frame
   if topFrame.type == 'leaf' then
      return {}
   end

   topFrame:equalize_windows(do_width, do_height)

   local data
   if do_width and not do_height then
      data = topFrame:get_data_for_width_resizing()
   elseif not do_width and do_height then
      data = topFrame:get_data_for_height_resizing()
   else
      data = merge_resize_data(topFrame:get_data_for_width_resizing(),
                               topFrame:get_data_for_height_resizing())
   end
   return data
end

return M
