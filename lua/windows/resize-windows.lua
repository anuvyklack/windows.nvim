local Window = require('windows.lib.Window')
local M = {}

---@param winsdata win.WinResizeData[]
function M.resize_windows(winsdata)
   local ignored_wins = {}
   -- local eadirection = vim.o.eadirection

   for _, d in ipairs(winsdata) do
      d.win:temp_change_option('winfixwidth', true)
      d.win:temp_change_option('winfixheight', true)
   end

   for _, id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local win = Window(id) ---@type win.Window
      if not winsdata[id] and win:is_ignored() then
         win:temp_change_option('winfixwidth', true)
         win:temp_change_option('winfixheight', true)
         table.insert(ignored_wins, win)
      end
   end

   for _, d in ipairs(winsdata) do
      if d.final_width then
         d.win:set_width(d.final_width)
      end
   end
   for _, d in ipairs(winsdata) do
      if d.delta_height then
         d.win:set_height(d.final_height)
      end
   end

   for _, d in ipairs(winsdata) do
      d.win:restore_changed_options()
   end
   for _, win in ipairs(ignored_wins) do
      win:restore_changed_options()
   end
end

return M
