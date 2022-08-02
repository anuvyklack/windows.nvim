---
--- Singleton
---
local singleton = require('windows.class.singleton')
local Animation = require('animation')
local round = require('windows.util').round

---@class win.ResizeWindowsAnimated : nvim.Animation
---@field _instance win.ResizeWindowsAnimated the instance of the singleton
---@field winsdata win.WinResizeData[]
---@field ignored_wins win.Window[] Windows to ignore during animation
---@field new fun(...):win.ResizeWindowsAnimated
local ResizeWindowsAnimated = singleton(Animation)

function ResizeWindowsAnimated:initialize(duration, fps, easing)
   Animation.initialize(self, duration, fps, easing, nil)
end

---@param winsdata win.WinResizeData[]
function ResizeWindowsAnimated:load(winsdata)
   if self:is_running() then self:finish() end

   self.winsdata = {}
   for _, d in ipairs(winsdata) do
      local a = false
      if d.final_width then
         local f = d.final_width -- final
         local i = d.win:get_width() -- initial
         if f < i - 2 or i + 2 < f then
            a = true
            d.initial_width = i
            d.delta_width = f - i -- delta
         end
      end
      if d.final_height then
         local f = d.final_height -- final
         local i = d.win:get_height() -- initial
         if i ~= f then
            a = true
            d.initial_height = i
            d.delta_height = f - i -- delta
         end
      end
      if a then
         table.insert(self.winsdata, d)
      end
   end

   -- local IDs = {}
   -- for _, d in ipairs(winsdata) do
   --    IDs[d.win.id] = true
   -- end

   -- self.ignored_wins = {}
   -- self.eadirection = vim.o.eadirection
   -- for _, id in ipairs(api.nvim_tabpage_list_wins(0)) do
   --    local win = Window(id) ---@type win.Window
   --    if not IDs[id] and win:is_ignored() then
   --       table.insert(self.ignored_wins, win)
   --    end
   -- end

   self:set_callback(function(fraction)
      for _, d in ipairs(self.winsdata) do
         if d.delta_width then
            local width = d.initial_width + round(fraction * d.delta_width)
            d.win:set_width(width)
         end
         if d.delta_height then
            local height = d.initial_height + round(fraction * d.delta_height)
            d.win:set_height(height)
         end
      end
   end)
end

function ResizeWindowsAnimated:run()
   if self:is_running() then return end

   -- for id, d in ipairs(self.winsdata) do
   --    -- if d.win.is_valid() then
   --       d.win:temp_change_option('winfixwidth', true)
   --       d.win:temp_change_option('winfixheight', true)
   --    -- else
   --    --    self.winsdata.id = nil
   --    -- end
   -- end

   -- for _, win in ipairs(self.ignored_wins) do
   --    win:temp_change_option('winfixwidth', true)
   --    win:temp_change_option('winfixheight', true)
   -- end

   Animation.run(self)
end

function ResizeWindowsAnimated:finish()
   if not self:is_running() then return end

   Animation.finish(self)

   -- vim.o.eadirection = self.eadirection

   -- for _, d in ipairs(self.winsdata) do
   --    if d.win:is_valid() then
   --       d.win:restore_changed_options()
   --    end
   -- end

   -- for _, win in ipairs(self.ignored_wins) do
   --    if win:is_valid() then
   --       win:restore_changed_options()
   --    end
   -- end

   self.winsdata = {}
   self.ignored_wins = {}
end

return ResizeWindowsAnimated
