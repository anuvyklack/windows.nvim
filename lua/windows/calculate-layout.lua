---
--- Everywhere where you see something like: "n - 1", "-n  + 1" or "-1", this
--- is a subtraction of the width of separators between children frames from
--- frame width.
---
local Frame = require('windows.lib.Frame')
local round = require('windows.util').round
local M = {}

---@param topFrame win.Frame
---@param curwinLeaf win.Frame
local function calculate_layout_for_auto_width_recursively(topFrame, curwinLeaf)
   local curwin = curwinLeaf.win

   local curwinFrame = topFrame:get_child(curwinLeaf)

   if topFrame.type == 'col' then
      local width = topFrame.new_width
      for _, frame in ipairs(topFrame.children) do
         frame.new_width = width
         if frame.type ~= 'leaf' then
            if frame == curwinFrame then
               calculate_layout_for_auto_width_recursively(frame, curwinLeaf)
            else
               frame:equalize_windows(true, false)
            end
         end
      end
   elseif topFrame.type == 'row' then
      local room = topFrame.new_width
      local topFrame_leafs = topFrame:get_longest_row()

      -- print(string.format('room : %d', room))

      local totwincount = #topFrame_leafs

      -- Exclude fixed width frames from consideration.
      for _, frame in ipairs(topFrame.children) do
         if frame ~= curwinFrame and frame:is_fixed_width() then
            local width = frame:get_width()
            frame.new_width = width
            room = room - width - 1
            frame:equalize_windows(true, false)

            -- print(string.format('%d %d : %d', i, frame.win.id, frame.new_width))
            -- print(string.format('room : %d', room))

            totwincount = totwincount - #frame:get_longest_row()
         end
      end

      local curwin_wanted_width = curwin:get_wanted_width()
      local wanted_width = curwinFrame:get_min_width(curwin, curwin_wanted_width)

      local n = #curwinFrame:get_longest_row()
      local N = totwincount
      local owed_width = round((room - N + 1) * n / N + n - 1)

      totwincount = totwincount - n

      local width = (wanted_width > owed_width) and wanted_width or owed_width
      curwinFrame.new_width = width
      room = room - width - 1
      if curwinFrame.type ~= 'leaf' then
         calculate_layout_for_auto_width_recursively(curwinFrame, curwinLeaf)
      end

      ---All topFrame children frames that are not curwinFrame and not fixed
      ---width.
      local other_frames = {}
      for _, frame in ipairs(topFrame.children) do
         if frame ~= curwinFrame and not frame:is_fixed_width() then
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
         if frame.type ~= 'leaf' then
            frame:equalize_windows(true, false)
         end
      end
   end
end

---@param curwin win.Window
---@return win.WinResizeData[]?
function M.calculate_layout_for_auto_width(curwin)
   local topFrame = Frame() ---@type win.Frame
   if topFrame.type == 'leaf' then
      return
   end
   topFrame:mark_fixed_width()
   topFrame.new_width = vim.o.columns --[[@as integer]]

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
         M.maximize_window(topFrame, curwinLeaf, true, false)
      else
         calculate_layout_for_auto_width_recursively(topFrame, curwinLeaf)
      end
   else
      topFrame:equalize_windows(true, false)
   end

   local output = {} ---@type win.WinResizeData[]
   for i, leaf in ipairs(topFrame:get_leafs_for_auto_width()) do
      output[i] = {
         win = leaf.win,
         final_width = leaf.new_width
      }
   end

   -- local t = {};
   -- for _, d in ipairs(output) do
   --    t[#t+1] = string.format('%d : %d', d.win.id, d.final_width)
   -- end
   -- print(table.concat(t, ' | '))

   return output
end

---@param topFrame win.Frame
---@param winLeaf win.Frame
---@param do_width boolean
---@param do_height boolean
function M.maximize_window(topFrame, winLeaf, do_width, do_height)
   if do_width then
      local topFrame_width = topFrame:get_width()
      local topFrame_wanted_width = topFrame:get_min_width(winLeaf.win, topFrame_width)

      winLeaf.new_width = 2 * topFrame_width - topFrame_wanted_width
   end

   if do_height then
      local topFrame_height = topFrame:get_height()
      local topFrame_wanted_height = topFrame:get_min_height(winLeaf.win, topFrame_height)

      winLeaf.new_height = 2 * topFrame_height - topFrame_wanted_height
   end

   local winFrame = winLeaf
   local parentFrame = winFrame.parent
   while parentFrame do
      if parentFrame.type == 'col' then

         if do_height then
            local height = winFrame.new_height + #parentFrame.children - 1
            for _, frame in ipairs(parentFrame.children) do
               if frame ~= winFrame then
                  if frame:is_fixed_height() then
                     frame.new_height = frame:get_height()
                  else
                     local n = #frame:get_longest_column()
                     frame.new_height = vim.o.winminheight * n + n - 1
                  end
               end
               height = height + frame.new_height
            end
            if parentFrame.new_height then
               assert(parentFrame.new_height == height, 'parentFrame.new_height ~= height')
            end
            parentFrame.new_height = height
         end

         if do_width then
            local width = winFrame.new_width
            parentFrame.new_width = width
            for _, frame in ipairs(parentFrame.children) do
               if frame ~= winFrame then
                  frame.new_width = width
               end
            end
         end

      elseif parentFrame.type == 'row' then

         if do_width then
            local width = winFrame.new_width + #parentFrame.children - 1
            for _, frame in ipairs(parentFrame.children) do
               if frame ~= winFrame then
                  if frame:is_fixed_width() then
                     frame.new_width = frame:get_width()
                  else
                     local n = #frame:get_longest_row()
                     frame.new_width = vim.o.winminwidth * n + n - 1
                  end
                  width = width + frame.new_width
               end
            end
            if parentFrame.new_width then
               assert(parentFrame.new_width == width, 'parentFrame.new_width ~= width')
            end
            parentFrame.new_width = width
         end

         if do_height then
            local height = winFrame.new_height
            parentFrame.new_height = height
            for _, frame in ipairs(parentFrame.children) do
               if frame ~= winFrame then
                  frame.new_height = height
               end
            end
         end

      end

      for _, frame in ipairs(parentFrame.children) do
         if frame.type ~= 'leaf' and frame ~= winFrame then
            frame:equalize_windows(do_width, do_height)
         end
      end

      winFrame = parentFrame
      parentFrame = parentFrame.parent
   end
end

return M
