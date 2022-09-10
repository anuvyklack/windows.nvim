local class = require('middleclass')
local M = {}

---@class win.WinResizeData
---@field win win.Window
---@field width integer
---@field height integer

---@class win.WinResDataList: { [integer]: win.WinResizeData }
local WinResDataList = class('win.WinResDataList')

---@param type 'width' | 'height'
---@param leafs win.Frame[]
function WinResDataList:initialize(type, leafs)
   assert(type == 'width' or type == 'height', 'Type is neither "width" nor "height"')
   for i, frame in ipairs(leafs) do
      local data = {}
      data.win = frame.win
      if type == 'width' then
         data.width = frame.new_width
      else
         data.height = frame.new_height
      end
      self[i] = data
   end
end

---@param type? 'width' | 'height'
---@param data_list win.WinResDataList
function WinResDataList:extend(type, data_list)
   assert(type == 'width' or type == 'height', 'Type is neither "width" nor "height"')
   local winids = {}
   for i, d in ipairs(self) do
      winids[d.win.id] = i
   end

   for _, data in ipairs(data_list) do
      local i = winids[data.win.id]
      if i then
         self[i][type] = data[type]
      else
         table.insert(self, data)
      end
   end
   return self
end

--------------------------------------------------------------------------------

---@param winsdata win.WinResDataList
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

M.WinResDataList = WinResDataList
return M
