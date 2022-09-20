---
--- Everywhere where you see something like: "n - 1", "-n  + 1" or "-1", this
--- is a subtraction of the width of separators between children frames from
--- frame width.
---
local class = require('middleclass')
local Window = require('windows.lib.api').Window
local round = require('windows.lib.util').round
local list_extend = vim.list_extend

---Width threshold
local THRESHOLD = 1

---@class win.Frame
---@field type 'leaf' | 'col' | 'row'
---@field id string
---@field parent win.Frame | nil
---@field children win.Frame[]
---@field prev win.Frame | nil frame left or above in same parent, nil for first
---@field next win.Frame | nil frame right or below in same parent, nil for last
---@field win win.Window
---@field new_width  integer
---@field new_height integer
---@field _fixed_width  boolean
---@field _fixed_height boolean
---@field _curwin_frame boolean
local Frame = class('win.Frame')

---@param layout table
---@param id? string
---@param parent? win.Frame
function Frame:initialize(layout, id, parent)
   layout = layout or vim.fn.winlayout()
   self.id = id or '0'
   self.parent = parent

   -- Set the new_width and new_height of the top frame, since it can't be
   -- changed.
   if not parent then
      self.new_width = vim.o.columns --[[@as integer]]
      self.new_height = vim.o.lines - vim.o.cmdheight
                        - (vim.o.tabline ~= '' and 1 or 0) -- tabline
                        - 1 -- statusline
   end

   self.type = layout[1]
   if self.type == 'leaf' then
      self.win = Window(layout[2])
   else -- 'row' or 'col'
      local children = {}  ---@type win.Frame[]
      for i, l in ipairs(layout[2]) do
         children[i] = Frame(l, self.id..i, self)
      end
      -- for i, frame in ipairs(children) do
      --    frame.prev = children[i-1]
      --    frame.next = children[i+1]
      -- end
      self.children = children
   end
end

---@param l win.Frame
---@param r win.Frame
function Frame.__eq(l, r)
   return l.id == r.id
end

function Frame:_mark_fixed_width()
   if self.type == 'leaf' then
      if self.win:is_ignored() then
         self._fixed_width = true
      else
         -- Frame with one window: fixed width if 'winfixwidth' set.
         self._fixed_width = self.win:get_option('winfixwidth')
      end
   elseif self.type == 'row' then
      --  The frame is fixed width if all of the frames in the row are fixed width.
      self._fixed_width = true
      for _, frame in ipairs(self.children) do
         frame:_mark_fixed_width()
         if not frame._fixed_width then
            self._fixed_width = false
         end
      end
   else -- self.type == 'col'
      --  The frame is fixed width if one of the frames in the column is fixed width.
      self._fixed_width = false
      for _, frame in ipairs(self.children) do
         frame:_mark_fixed_width()
         if frame._fixed_width then
            self._fixed_width = true
         end
      end
   end
end

function Frame:_mark_fixed_height()
   if self.type == 'leaf' then
      if self.win:is_ignored() then
         self._fixed_height = true
      else
         -- Frame with one window is fixed height if 'winfixheight' set.
         self._fixed_height = self.win:get_option('winfixheight')
      end
   elseif self.type == 'row' then
      --  The frame is fixed height if one of the frames in the row is fixed height.
      self._fixed_height = false
      for _, frame in ipairs(self.children) do
         frame:_mark_fixed_height()
         if frame._fixed_height then
            self._fixed_height = true
         end
      end
   else -- self.type == 'col'
      --  The frame is fixed height if all of the frames in the column are fixed height.
      self._fixed_height = true
      for _, frame in ipairs(self.children) do
         frame:_mark_fixed_height()
         if not frame._fixed_height then
            self._fixed_height = false
         end
      end
   end
end

---@return boolean
function Frame:is_fixed_width()
   if self._fixed_width == nil then
      local topFrame = self
      while topFrame.parent do ---@diagnostic disable-line
         topFrame = topFrame.parent
      end
      ---@cast topFrame -nil
      topFrame:_mark_fixed_width()
   end
   return self._fixed_width
end

---@return boolean
function Frame:is_fixed_height()
   if self._fixed_height == nil then
      local topFrame = self
      while topFrame.parent do ---@diagnostic disable-line
         topFrame = topFrame.parent
      end
      ---@cast topFrame -nil
      topFrame:_mark_fixed_height()
   end
   return self._fixed_height
end

---Get child frame that contains target frame.
---@param frame win.Frame
---@return win.Frame
---@return integer index Index of child frame among other children.
function Frame:get_child_with_frame(frame)
   local n = #self.id
   assert(frame.id:sub(0, n) == self.id, "The Frame does not contain seeking frame")
   local i = tonumber(frame.id:sub(n+1, n+1)) --[[@as integer]]
   return self.children[i], i
end

---Calculate the maximum number of windows horizontally in this frame and return
---these windows "leaf" frames as a list.
---@return win.Frame[]
function Frame:get_longest_row()
   if self.type == 'leaf' then
      return { self }
   elseif self.type == 'row' then
      local output = {}
      for _, frame in ipairs(self.children) do
         list_extend(output, frame:get_longest_row())
      end
      return output
   else -- self.type == 'col'
      local output
      local N = 0
      for _, frame in ipairs(self.children) do
         local list = frame:get_longest_row()
         if #list > N then
            output = list
            N = #list
         end
      end
      return output
   end
end

---@return win.Frame[]
function Frame:get_longest_column()
   if self.type == 'leaf' then
      return { self }
   elseif self.type == 'row' then
      local output
      local N = 0
      for _, frame in ipairs(self.children) do
         local col = frame:get_longest_column()
         if #col > N then
            output = col
            N = #col
         end
      end
      return output
   else -- self.type == 'col'
      local output = {}
      for _, frame in ipairs(self.children) do
         list_extend(output, frame:get_longest_column())
      end
      return output
   end
end

---@param win? win.Window
---@return win.Frame[]
---@return boolean found
function Frame:get_longest_row_contains_target_window(win)
   if self.type == 'leaf' then
      return { self }, self.win == win
   elseif self.type == 'row' then
      local output = {} ---@type win.Frame[]
      local found = false
      for _, frame in ipairs(self.children) do
         local o, f = frame:get_longest_row_contains_target_window(win)
         list_extend(output, o)
         found = found or f
      end
      return output, found
   else -- self.type == 'col'
      local output = {} ---@type win.Frame[]
      for _, node in ipairs(self.children) do
         local o, f = node:get_longest_row_contains_target_window(win)
         if f then
            return o, true
         elseif #o > #output then
            output = o
         end
      end
      return output, false
   end
end

---@param win? win.Window
---@return win.Frame[]
---@return boolean found
function Frame:get_longest_column_contains_target_window(win)
   if self.type == 'leaf' then
      return { self }, self.win == win
   elseif self.type == 'col' then
      local output = {} ---@type win.Frame[]
      local found = false
      for _, frame in ipairs(self.children) do
         local o, f = frame:get_longest_column_contains_target_window(win)
         list_extend(output, o)
         found = found or f
      end
      return output, found
   else -- self.type == 'row'
      local output = {} ---@type win.Frame[]
      for _, node in ipairs(self.children) do
         local o, f = node:get_longest_column_contains_target_window(win)
         if f then
            return o, true
         elseif #o > #output then
            output = o
         end
      end
      return output, false
   end
end

---Return the width of the frame.
---@return integer
function Frame:get_width()
   if not self.parent then
      return self.new_width
   elseif self.type == 'leaf' then
      return self.win:get_width()
   elseif self.type == 'row' then
      local width = 0
      for _, frame in ipairs(self.children) do
         width = width + frame:get_width()
      end
      width = width + #self.children - 1 -- separators between frames
      return width
   else -- self.type == 'col'
      for _, frame in ipairs(self.children) do
         if frame.type == 'leaf' then
            return frame.win:get_width()
         end
      end
      return self.children[1]:get_width()
   end
end

---Return the height of the frame.
---@return integer
function Frame:get_height()
   if not self.parent then
      return self.new_height
   elseif self.type == 'leaf' then
      return self.win:get_height()
   elseif self.type == 'col' then
      local height = 0
      for _, frame in ipairs(self.children) do
         height = height + frame:get_height()
      end
      height = height + #self.children - 1 -- separators between frames
      return height
   else -- self.type == 'row'
      for _, frame in ipairs(self.children) do
         if frame.type == 'leaf' then
            return frame.win:get_height()
         end
      end
      return self.children[1]:get_height()
   end
end

---Return the minimal width the frame will take, assuming that the `tarwin` will
---occupy `tarwin_width` cells. And the list, with windows, that make up this
---width.
---@param tarwin? win.Window the ID of the target window
---@param tarwin_width? integer the width that tarwin will occupy. If `nil`, the `winwidth` value will be used.
---@return integer
---@return win.Frame[]
function Frame:get_min_width(tarwin, tarwin_width)
   if self.type == 'leaf' then
      if self.win == tarwin then
         ---@diagnostic disable-next-line
         return tarwin_width and tarwin_width or vim.o.winwidth, { self }
      elseif self:is_fixed_width() then
         return self:get_width(), { self }
      else
         return vim.o.winminwidth--[[@as integer]] , { self }
      end
   elseif self.type == 'row' then
      local width, leafs = 0, {}
      for _, frame in pairs(self.children) do
         local frame_width, frame_leafs = frame:get_min_width(tarwin, tarwin_width)
         width = width + frame_width
         list_extend(leafs, frame_leafs)
      end
      -- Add the number of separators between subframes.
      width = width + #self.children - 1
      return width, leafs
   else -- self.type == 'col'
      local width, leafs = 0, {}
      for _, frame in ipairs(self.children) do
         local new_width, new_leafs = frame:get_min_width(tarwin, tarwin_width)
         if new_width > width then
            width, leafs = new_width, new_leafs
         end
      end
      return width, leafs
   end
end

---@param tarwin? win.Window the ID of the target window
---@param tarwin_height? integer the height that tarwin will occupy. If `nil`, the `winheight` value will be used.
---@return integer
---@return win.Frame[]
function Frame:get_min_height(tarwin, tarwin_height)
   if self.type == 'leaf' then
      if self.win == tarwin then
         ---@diagnostic disable-next-line
         return tarwin_height and tarwin_height or vim.o.winheight, { self }
      elseif self:is_fixed_height() then
         return self:get_height(), { self }
      else
         return vim.o.winminheight--[[@as integer]] , { self }
      end
   elseif self.type == 'col' then
      local height, leafs = 0, {}
      for _, frame in pairs(self.children) do
         local frame_height, frame_leafs = frame:get_min_height(tarwin, tarwin_height)
         height = height + frame_height
         list_extend(leafs, frame_leafs)
      end
      -- Add the number of separators between subframes.
      height = height + #self.children - 1
      return height, leafs
   else -- self.type == 'row'
      local height, leafs = 0, {}
      for _, frame in ipairs(self.children) do
         local new_height, new_leafs = frame:get_min_height(tarwin, tarwin_height)
         if new_height > height then
            height, leafs = new_height, new_leafs
         end
      end
      return height, leafs
   end
end

---@param do_width boolean
---@param do_height boolean
function Frame:equalize_windows(do_width, do_height)
   if self.type == 'col' then
      if do_height then
         local Nw = #self:get_longest_column() -- number of windows

         -- #self.children - 1 : height of separators between children frames
         local room = self.new_height - #self.children + 1

         ---Variable height frames
         ---@type win.Frame[]
         local var_height_frames = {}
         for _, frame in ipairs(self.children) do
            if frame:is_fixed_height() then
               frame.new_height = frame:get_height()
               room = room - frame.new_height - 1
               Nw = Nw - #frame:get_longest_column()
            else
               table.insert(var_height_frames, frame)
            end
         end

         local Nf = #var_height_frames -- number of frames
         for i, frame in ipairs(var_height_frames) do
            if i == Nf then
               frame.new_height = room
            else
               local n = #frame:get_longest_column()
               local height = round(room * n / Nw + n - 1)
               Nw = Nw - n
               frame.new_height = height
               room = room - height
            end
         end

      end

      for _, frame in ipairs(self.children) do
         if do_width then
            frame.new_width = self.new_width
         end
         if frame.type ~= 'leaf' then
            frame:equalize_windows(do_width, do_height)
         end
      end
   elseif self.type == 'row' then
      if do_width then
         local Nw = #self:get_longest_row() -- number of windows

         -- #self.children - 1 : widths of separators between children frames
         local room = self.new_width - #self.children + 1

         local var_width_frames = {} ---@type win.Frame[]
         for _, frame in ipairs(self.children) do
            if frame:is_fixed_width() then
               frame.new_width = frame:get_width()
               room = room - frame.new_width - 1
               Nw = Nw - #frame:get_longest_row()
            else
               table.insert(var_width_frames, frame)
            end
         end

         local Nf = #var_width_frames -- number of frames
         for i, frame in ipairs(var_width_frames) do
            if i == Nf then
               frame.new_width = room
            else
               local n = #frame:get_longest_row()
               local width = round(room * n / Nw + n - 1)
               Nw = Nw - n
               frame.new_width = width
               room = room - width
            end
         end
      end

      for _, frame in ipairs(self.children) do
         if do_height then
            frame.new_height = self.new_height
         end
         if frame.type ~= 'leaf' then
            frame:equalize_windows(do_width, do_height)
         end
      end
   end
end

---Return the leaf frame that contains the the sought-for window.
---@param win win.Window
---@return win.Frame leaf leaf-type frame with sought-for window
function Frame:find_window(win)
   if self.type == 'leaf' then
      if self.win == win then
         return self
      end
   else
      for _, frame in ipairs(self.children) do
         local leaf = frame:find_window(win)
         if leaf then
            return leaf
         end
      end
   end ---@diagnostic disable-line
end

---If frame has leaf type frame among its direct children, then return it.
---If thare are several of them, then return then first one. If the frame is
---a leaf itself, then return itself.
---@return win.Frame | nil
function Frame:get_direct_child_leaf()
   if self.type == 'leaf' then
      return self
   else
      for _, frame in ipairs(self.children) do
         if frame.type == 'leaf' then
            return frame
         end
      end
   end
end

---@param winLeaf win.Frame
---@param do_width boolean
---@param do_height boolean
function Frame:maximize_window(winLeaf, do_width, do_height)
   if do_width then
      local topFrame_width = self:get_width()
      local topFrame_wanted_width = self:get_min_width(winLeaf.win, topFrame_width)

      winLeaf.new_width = 2 * topFrame_width - topFrame_wanted_width
   end

   if do_height then
      local topFrame_height = self:get_height()
      local topFrame_wanted_height = self:get_min_height(winLeaf.win, topFrame_height)

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
                  height = height + frame.new_height
               end
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

---@param curwinLeaf win.Frame
function Frame:autowidth(curwinLeaf)
   local curwin = curwinLeaf.win

   local curwinFrame = self:get_child_with_frame(curwinLeaf)

   if self.type == 'col' then
      local width = self.new_width
      for _, frame in ipairs(self.children) do
         frame.new_width = width
         if frame.type ~= 'leaf' then
            if frame == curwinFrame then
               frame:autowidth(curwinLeaf)
            else
               frame:equalize_windows(true, false)
            end
         end
      end
   elseif self.type == 'row' then
      local room = self.new_width
      local topFrame_leafs = self:get_longest_row()

      local totwincount = #topFrame_leafs

      -- Exclude fixed width frames from consideration.
      for _, frame in ipairs(self.children) do
         if frame ~= curwinFrame and frame:is_fixed_width() then
            local width = frame:get_width()
            frame.new_width = width
            room = room - width - 1
            frame:equalize_windows(true, false)

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

      -- Remove unnecessary windows "breathing", i.e. changing size in few cells.
      if curwinFrame.type == 'leaf' then
         local curwin_width = curwin:get_width()
         if curwin_width - THRESHOLD < width and width <= curwin_width + THRESHOLD
         then
            width = curwin_width
         end
      end

      curwinFrame.new_width = width
      room = room - width - 1
      if curwinFrame.type ~= 'leaf' then
         curwinFrame:autowidth(curwinLeaf)
      end

      ---All children frames that are not curwinFrame and not fixed width.
      local other_frames = {} ---@type win.Frame[]
      for _, frame in ipairs(self.children) do
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
            if frame.type == 'leaf' then
               -- Remove unnecessary windows "breathing", i.e. changing size in
               -- few cells.
               local win_width = frame.win:get_width()
               if win_width - THRESHOLD < w and w <= win_width + THRESHOLD then
                  w = win_width
               end
            end
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

---@return win.Frame[]
function Frame:get_all_nested_leafs()
   if self.type == 'leaf' then
      return { self }
   else
      local output = {}
      for _, frame in ipairs(self.children) do
         list_extend(output, frame:get_all_nested_leafs())
      end
      return output
   end
end

--------------------------------------------------------------------------------

---Extract the list of windows suitable for width resizing.
---@return win.Frame[]
function Frame:get_leafs_for_width_resizing()
   if self.type == 'leaf' then
      -- We get here only if root has only one "leaf" frame
      return { self }
   elseif self.type == 'row' then
      local r = {}
      local N = #self.children
      local add_last
      for i, frame in ipairs(self.children) do
         if i < N or add_last then
            local f = frame:get_direct_child_leaf()
            if f then
               table.insert(r, f)
            end
            if i == N-1 then
               add_last = not f
            end
         end
         if frame.type ~= 'leaf' then
            list_extend(r, frame:get_leafs_for_width_resizing())
         end
      end

      return r
   else -- self.type == 'col'
      local r = {}

      for _, frame in ipairs(self.children) do
         if frame.type ~= 'leaf' then
            list_extend(r, frame:get_leafs_for_width_resizing())
         end
      end

      return r
   end
end

---Extract the list of windows suitable for height resizing.
---@return win.Frame[]
function Frame:get_leafs_for_height_resizing()
   if self.type == 'leaf' then
      -- We get here only if root has only one "leaf" frame
      return { self }
   elseif self.type == 'col' then
      local r = {}
      local N = #self.children
      local add_last
      for i, frame in ipairs(self.children) do
         if i < N or add_last then
            local f = frame:get_direct_child_leaf()
            if f then
               table.insert(r, f)
            end
            if i == N-1 then
               add_last = not f
            end
         end
         if frame.type ~= 'leaf' then
            list_extend(r, frame:get_leafs_for_height_resizing())
         end
      end

      return r
   else -- self.type == 'row'
      local r = {}

      for _, frame in ipairs(self.children) do
         if frame.type ~= 'leaf' then
            list_extend(r, frame:get_leafs_for_height_resizing())
         end
      end

      return r
   end
end

--------------------------------------------------------------------------------

---@return win.WinResizeData[]
function Frame:get_data_for_width_resizing()
   local r = {}
   local leafs = self:get_leafs_for_width_resizing()
   for i, frame in ipairs(leafs) do
      r[i] = {
         win = frame.win,
         width = frame.new_width
      }
   end
   return r
end

---@return win.WinResizeData[]
function Frame:get_data_for_height_resizing()
   local r = {}
   local leafs = self:get_leafs_for_height_resizing()
   for i, frame in ipairs(leafs) do
      r[i] = {
         win = frame.win,
         height = frame.new_height
      }
   end
   return r
end

--------------------------------------------------------------------------------
-- function Frame:get_shortest_row()
--    if self.type == 'leaf' then
--       return { self }
--    elseif self.type == 'row' then
--       local r = {}
--       for _, frame in ipairs(self.children) do
--          if frame.type == 'leaf' then
--             table.insert(r, frame)
--          else
--             list_extend(r, frame:get_shortest_row())
--          end
--       end
--       return r
--    else -- self.type == 'col'
--       for _, frame in ipairs(self.children) do
--          if frame.type == 'leaf' then
--             return { frame }
--          end
--       end
--
--       local r
--       local N = math.huge
--       for _, frame in ipairs(self.children) do
--          local list = frame:get_shortest_row()
--          local n = #list
--          if n < N then
--             r, N = list, n
--          end
--       end
--       return r
--    end
-- end

--------------------------------------------------------------------------------

-- local test_layouts = {}
--
-- -- ┌──────┬──────┬──────┬──────┐
-- -- │      │      │ 1005 │ 1007 │
-- -- │      │ 1003 ├──────┴──────┤
-- -- │ 1000 │      │    1006     │
-- -- │      ├──────┴─────────────┤
-- -- │      │        1004        │
-- -- └──────┴────────────────────┘
-- test_layouts[1] = { "row", {
--    { "leaf", 1000 },
--    { "col", {
--       { "row", {
--          { "leaf", 1003 },
--          { "col", {
--             { "row", {
--                { "leaf", 1005 },
--                { "leaf", 1007 }
--             }},
--             { "leaf", 1006 }
--          }}
--       }},
--       { "leaf", 1004 }
--    }}
-- }}
--
-- -- ┌──────┬──────┬──────────┬─────────┬──────┐
-- -- │ 1000 │ 1006 │   1003   │  1009   │      │
-- -- │      │      ├──────┬───┴──┬──────┤      │
-- -- ├──────┴──────┤ 1007 │ 1010 │ 1011 │ 1004 │
-- -- │             ├──────┴──────┴──────┤      │
-- -- │    1005     │        1008        │      │
-- -- └─────────────┴────────────────────┴──────┘
-- test_layouts[2] = { "row", {
--    { "col", {
--       { "row", {
--          { "leaf", 1000 },
--          { "leaf", 1006 }
--       }},
--       { "leaf", 1005 }
--    }},
--    { "col", {
--       { "row", {
--          { "leaf", 1003 },
--          { "leaf", 1009 }
--       }},
--       { "row", {
--          { "leaf", 1007 },
--          { "leaf", 1010 },
--          { "leaf", 1011 }
--       }},
--       { "leaf", 1008 }
--    }},
--    { "leaf", 1004 }
-- }}
--
-- -- ┌──────┬──────┬──────┬──────┐
-- -- │      │ 1005 │ 1006 │      │
-- -- │      │      │      │      │
-- -- │ 1000 ├──────┴──────┤ 1002 │
-- -- │      │             │      │
-- -- │      │    1004     │      │
-- -- └──────┴─────────────┴──────┘
--
-- test_layouts[3] = { "row", {
--    { "leaf", 1000 },
--    { "col", {
--       { "row", {
--          { "leaf", 1005 },
--          { "leaf", 1006 }
--       }},
--       { "leaf", 1004 }
--    }},
--    { "leaf", 1002 }
-- }}
--
--  -- ┌──────┬──────┬──────┬──────┐
--  -- │      │ 1005 │ 1006 │      │
--  -- │      │      │      │      │
--  -- │ 1000 ├──────┼──────┤ 1002 │
--  -- │      │      │      │      │
--  -- │      │ 1007 │ 1008 │      │
--  -- └──────┴──────┴──────┴──────┘
--
-- test_layouts[4] = { "row", {
-- { "leaf", 1000 },
-- { "col", {
--    { "row", {
--       { "leaf", 1005 },
--       { "leaf", 1006 }
--    }},
--    { "row", {
--       { "leaf", 1007 },
--       { "leaf", 1008 }
--    }},
-- }},
-- { "leaf", 1002 }
-- }}

--------------------------------------------------------------------------------

-- local frame1 = Frame(test_layouts[1])
-- local frame2 = Frame(test_layouts[2])
-- local frame3 = Frame(test_layouts[3])
-- local frame4 = Frame(test_layouts[4])
--
-- local frame, ww, wh = frame1, {}, {}
-- for _, f in ipairs(frame:get_leafs_for_width_resizing()) do
--    ww[#ww+1] = f.win.id
-- end
-- for _, f in ipairs(frame:get_leafs_for_height_resizing()) do
--    wh[#wh+1] = f.win.id
-- end
-- print(ww)
-- print(wh)

-- local win = Window(1011)
-- local timeit = require('windows.util').timeit
-- local t, t2
--
-- t = timeit(function() frame2:get_longest_row_old() end, 500)
-- t2 = timeit(function() frame2:get_longest_row() end, 500)
--
-- -- t = timeit(function() frame2:get_longest_row_contains_target_window(win) end, 100)
-- -- t2 = timeit(function() frame2:get_longest_row_contains_target_window_new(win) end, 100)
--
-- print(t)
-- print(t2)

-- for i, frame in ipairs(frame2:get_longest_row_contains_target_window_new(Window(1004))) do
--    print(frame.win.id)
-- end

-- for _, leaf in ipairs(frame1:get_all_leafs()) do
--    print(leaf.id, leaf.win.id)
-- end
-- for _, leaf in ipairs(frame2:get_all_leafs()) do
--    print(leaf.id, leaf.win.id)
-- end
-- for _, leaf in ipairs(frame3:get_all_leafs()) do
--    print(leaf.id, leaf.win.id)
-- end
-- for _, leaf in ipairs(frame4:get_all_leafs()) do
--    print(leaf.id, leaf.win.id)
-- end

-- local wins = {}
-- for _, l in ipairs(frame1:get_leafs_for_auto_width()) do
--    table.insert(wins, l.win.id)
-- end
-- print(wins)
--
-- wins = {}
-- for _, l in ipairs(frame2:get_leafs_for_auto_width()) do
--    table.insert(wins, l.win.id)
-- end
-- print(wins)
--
-- local wins = {}
-- for _, l in ipairs(frame3:get_leafs_for_auto_width()) do
--    table.insert(wins, l.win.id)
-- end
-- print(wins)
--
-- local wins = {}
-- for _, l in ipairs(frame4:get_leafs_for_auto_width()) do
--    table.insert(wins, l.win.id)
-- end
-- print(wins)

-- local leaf
-- leaf = frame1:find_window(Window(1007))
-- print(leaf.id)
-- leaf = frame2:find_window(Window(1011))
-- print(leaf.id)

------------------------------------------------------------------------------

return Frame
