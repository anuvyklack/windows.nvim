---
--- Everywhere where you see something like: "n - 1", "-n  + 1" or "-1", this
--- is a subtraction of the width of separators between children frames from
--- frame width.
---
local Frame = require('windows.lib.Frame')
local round = require('windows.util').round
local list_extend = vim.list_extend
local list_slice = vim.list_slice

---@param topFrame win.Frame
---@param curwin win.Window
---@param curwin_path integer[]
local function calculate_layout_recursively(topFrame, curwin, curwin_path)
   -- Index of the "curwinFrame" among "topFrame" children.
   local ci = curwin_path[1]

   if topFrame.type == 'leaf' then

   elseif topFrame.type == 'col' then
      local width = topFrame.new_width
      for i, frame in ipairs(topFrame.children) do
         frame.new_width = width
         if i == ci then -- i.e. curwinFrame
            local new_curwin_path = list_slice(curwin_path, 2)
            calculate_layout_recursively(frame, curwin, new_curwin_path)
         else
            frame:equalize_windows_widths()
         end
      end
   elseif topFrame.type == 'row' and curwin then
      local room = topFrame.new_width
      local topFrame_leafs = topFrame:get_longest_row()

      -- print(string.format('room : %d', room))

      local totwincount = #topFrame_leafs

      -- Exclude fixed width frames from consideration.
      local fixed_width_frames = {}
      for i, frame in ipairs(topFrame.children) do
         if i ~= ci and frame:is_fixed_width() then
            local width = frame:get_width()
            frame.new_width = width
            room = room - width - 1
            frame:equalize_windows_widths()

            -- print(string.format('%d %d : %d', i, frame.win.id, frame.new_width))
            -- print(string.format('room : %d', room))

            totwincount = totwincount - #frame:get_longest_row()
            fixed_width_frames[i] = true
         end
      end

      local curwinFrame = topFrame.children[ci]
      local curwin_wanted_width = curwin:get_wanted_width()
      local wanted_width = curwinFrame:get_min_width(curwin, curwin_wanted_width)

      local n = #curwinFrame:get_longest_row()
      local N = totwincount
      local owed_width = round((room - N + 1) * n / N + n - 1)

      ---Total number of children frames.
      local Nf = #topFrame.children
      if Nf == ci then Nf = Nf - 1 end

      if wanted_width > owed_width then
         curwinFrame.new_width = wanted_width
         calculate_layout_recursively(curwinFrame, curwin, list_slice(curwin_path, 2))
         room = room - wanted_width - 1
      else -- wanted_width < owed_width
         curwinFrame.new_width = owed_width
         calculate_layout_recursively(curwinFrame, curwin, list_slice(curwin_path, 2))
         room = room - owed_width - 1
      end

      totwincount = totwincount - n

      for i, frame in ipairs(topFrame.children) do
         if i ~= ci and not fixed_width_frames[i] then
            if i ~= Nf then
               local n = #frame:get_longest_row()
               local N = totwincount
               local w = round((room - N + 1) * n / N + n - 1)
               frame.new_width = w
               room = room - w - 1
               totwincount = totwincount - n
            else
               frame.new_width = room
            end
            frame:equalize_windows_widths()
         end
      end

   end
end

---Check if "topFrame" wanted more width than it has. In this case we set widht
---of all other windows to 'winminwidth' and give the rest room to curwin.
---@param topFrame win.Frame
---@param curwin win.Window
---@param curwin_path integer[]
local function check_max_width(topFrame, curwin, curwin_path)
   local curwin_wanted_width = curwin:get_wanted_width()
   local topFrame_width = topFrame:get_width()
   local topFrame_wanted_width = topFrame:get_min_width(curwin, curwin_wanted_width)

   if topFrame_wanted_width > topFrame_width then
      local curwinFrame = topFrame
      for _, i in ipairs(curwin_path) do
         curwinFrame = curwinFrame.children[i]
      end

      curwinFrame.new_width = curwin_wanted_width + topFrame_width - topFrame_wanted_width
      topFrame = curwinFrame.parent
      local i_cp = #curwin_path    -- index of curwinFrame_index :)
      local ci = curwin_path[i_cp] -- curwinFrame_index
      while topFrame do
         if topFrame.type == 'col' then
            local w = curwinFrame.new_width
            if not topFrame.new_width then topFrame.new_width = w end
            for i, frame in ipairs(topFrame.children) do
               if i ~= ci then
                  if not frame.new_width then frame.new_width = w end
                  frame:equalize_windows_widths()
               end
            end
         elseif topFrame.type == 'row' then
            local width = curwinFrame.new_width + #topFrame.children - 1
            for i, frame in ipairs(topFrame.children) do
               if i ~= ci then
                  if not frame.new_width then
                     if frame:is_fixed_width() then
                        frame.new_width = frame:get_width()
                     else
                        local n = #frame:get_longest_row()
                        frame.new_width = vim.o.winminwidth * n + n - 1
                     end
                  end
                  width = width + frame.new_width
                  frame:equalize_windows_widths()
               end
            end
            if topFrame.new_width then
               assert(topFrame.new_width == width, 'topFrame.new_width ~= width')
            end
            topFrame.new_width = width
         end
         curwinFrame = topFrame
         topFrame = topFrame.parent
         i_cp = i_cp - 1
         ci = curwin_path[i_cp]
      end

      return true
   else
      return false
   end
end

---@param curwin? win.Window
---@param prevwin? win.Window
---@return win.WinResizeData[] | nil
local function calculate_layout(curwin, prevwin)
   local topFrame = Frame() ---@type win.Frame
   if topFrame.type == 'leaf' then
      return
   end
   topFrame.new_width = vim.o.columns --[[@as integer]]

   if curwin and curwin:is_valid()
      and not curwin:is_floating()
      and not curwin:is_ignored()
   then
      local curwin_path = topFrame:find_window(curwin) --[[@as integer[] ]]

      if not check_max_width(topFrame, curwin, curwin_path) then
         calculate_layout_recursively(topFrame, curwin, curwin_path)
      end
   elseif prevwin and prevwin:is_valid()
      and not prevwin:is_floating()
      and not prevwin:is_ignored()
   then
      topFrame:equalize_windows_widths()
   else
      return
   end

   local output = {} ---@type win.WinResizeData[]
   for i, leaf in ipairs(topFrame:get_leafs_for_auto_width()) do
      output[i] = {
         win = leaf.win,
         final_width = leaf.new_width
      }
   end

   -- local t = {}
   -- for i, leaf in ipairs(topFrame:get_leafs()) do
   --    t[i] = string.format('%d : %d', leaf.win.id, leaf.new_width)
   -- end
   -- print(table.concat(t, ' | '))

   -- print('Winsdata:')
   -- local t = {}
   -- for i, d in ipairs(output) do
   --    t[i] = string.format('%d : %d', d.win.id, d.final_width)
   -- end
   -- print(table.concat(t, ' | '))

   return output
end

return calculate_layout
