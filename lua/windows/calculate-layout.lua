---
--- Everywhere where you see something like: "n - 1", "-n  + 1" or "-1", this
--- is a subtraction of the width of separators between children frames from
--- frame width.
---
local Frame = require('windows.lib.Frame')
local round = require('windows.util').round

---@param topFrame win.Frame
---@param curwin win.Window
local function calculate_layout_recursively(topFrame, curwin)
   if topFrame.type == 'col' then
      local width = topFrame.new_width
      for _, frame in ipairs(topFrame.children) do
         frame.new_width = width
         if frame:is_curwin() then
            calculate_layout_recursively(frame, curwin)
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
      for _, frame in ipairs(topFrame.children) do
         if not frame:is_curwin() and frame:is_fixed_width() then
            local width = frame:get_width()
            frame.new_width = width
            room = room - width - 1
            frame:equalize_windows_widths()

            -- print(string.format('%d %d : %d', i, frame.win.id, frame.new_width))
            -- print(string.format('room : %d', room))

            totwincount = totwincount - #frame:get_longest_row()
         end
      end

      local curwinFrame = topFrame:get_curwinFrame()
      local curwin_wanted_width = curwin:get_wanted_width()
      local wanted_width = curwinFrame:get_min_width(curwin, curwin_wanted_width)

      local n = #curwinFrame:get_longest_row()
      local N = totwincount
      local owed_width = round((room - N + 1) * n / N + n - 1)

      totwincount = totwincount - n

      if wanted_width > owed_width then
         curwinFrame.new_width = wanted_width
         calculate_layout_recursively(curwinFrame, curwin)
         room = room - wanted_width - 1
      else -- wanted_width < owed_width
         curwinFrame.new_width = owed_width
         calculate_layout_recursively(curwinFrame, curwin)
         room = room - owed_width - 1
      end

      ---All topFrame children frames that are not curwinFrame and not fixed
      ---width.
      local other_frames = {}
      for _, frame in ipairs(topFrame.children) do
         if not frame:is_curwin() and not frame:is_fixed_width() then
            table.insert(other_frames, frame)
         end
      end

      local Nf = #other_frames
      for i, frame in ipairs(other_frames) do
         if i == Nf then
            frame.new_width = room
         else
            local n = #frame:get_longest_row()
            local N = totwincount
            local w = round((room - N + 1) * n / N + n - 1)
            frame.new_width = w
            room = room - w - 1
            totwincount = totwincount - n
         end
         frame:equalize_windows_widths()
      end
   end
end

---Check if "topFrame" wanted more width than it has. In this case we set widht
---of all other windows to 'winminwidth' and give the rest room to curwin.
---@param topFrame win.Frame
---@param curwin win.Window
local function check_max_width(topFrame, curwin)
   local curwin_wanted_width = curwin:get_wanted_width()
   local topFrame_width = topFrame:get_width()
   local topFrame_wanted_width = topFrame:get_min_width(curwin, curwin_wanted_width)

   if topFrame_wanted_width > topFrame_width then
      local curwinFrame = topFrame:find_window(curwin)

      curwinFrame.new_width = curwin_wanted_width + topFrame_width - topFrame_wanted_width
      topFrame = curwinFrame.parent

      while topFrame do
         if topFrame.type == 'col' then
            local w = curwinFrame.new_width
            if not topFrame.new_width then topFrame.new_width = w end
            for _, frame in ipairs(topFrame.children) do
               if not frame:is_curwin() then
                  if not frame.new_width then frame.new_width = w end
                  frame:equalize_windows_widths()
               end
            end
         elseif topFrame.type == 'row' then
            local width = curwinFrame.new_width + #topFrame.children - 1
            for _, frame in ipairs(topFrame.children) do
               if not frame:is_curwin() then
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
            else
               topFrame.new_width = width
            end
         end
         curwinFrame = topFrame
         topFrame = topFrame.parent
      end

      return true
   else
      return false
   end
end

---@param curwin win.Window
---@return win.WinResizeData[]?
local function calculate_layout(curwin)
   local topFrame = Frame() ---@type win.Frame
   if topFrame.type == 'leaf' then
      return
   end
   topFrame:mark_fixed_width()
   topFrame.new_width = vim.o.columns --[[@as integer]]

   if curwin:is_valid() and not curwin:is_floating() and not curwin:is_ignored()
   then
      topFrame:set_curwin(curwin)

      if not check_max_width(topFrame, curwin) then
         calculate_layout_recursively(topFrame, curwin)
      end
   else
      topFrame:equalize_windows_widths()
   end

   local output = {} ---@type win.WinResizeData[]
   for i, leaf in ipairs(topFrame:get_leafs_for_auto_width()) do
      output[i] = {
         win = leaf.win,
         final_width = leaf.new_width
      }
   end
   return output
end

return calculate_layout
