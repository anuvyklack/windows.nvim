local M = {}

---@class win.WinResizeData
---@field win win.Window
---@field width integer
---@field height integer

---Modifies the `width_data` table!
---@param width_data win.WinResizeData[]
---@param height_data win.WinResizeData[]
function M.merge_resize_data(width_data, height_data)
   if vim.tbl_isempty(height_data) then
      return width_data
   end
   -- ---@type win.WinResizeData[]
   -- local r = vim.deepcopy(width_data)
   local r = width_data
   local id = {}
   for i, d in ipairs(width_data) do
      id[d.win.id] = i
   end
   for _, d in ipairs(height_data) do
      local i = id[d.win.id]
      if i then
         r[i].height = d.height
      else
         table.insert(r, {
            win = d.win,
            height = d.height
         })
      end
   end
   return r
end

---@param winsdata win.WinResizeData[]
function M.resize_windows(winsdata)
   for _, d in ipairs(winsdata) do
      if d.width then
         d.win:set_width(d.width)
      end
      if d.height then
         d.win:set_height(d.height)
      end
   end
end

return M
