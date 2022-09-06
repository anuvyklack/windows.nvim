---
--- Everywhere where you see something like: "n - 1", "-n  + 1" or "-1", this
--- is a subtraction of the width of separators between children frames from
--- frame width.
---
local class = require('middleclass')
local Window = require('windows.lib.Window')
local round = require('windows.util').round
local list_extend = vim.list_extend

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
   self.id = id or ''
   self.parent = parent
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

function Frame:mark_fixed_width()
   if self._fixed_width ~= nil then return end
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
         frame:mark_fixed_width()
         if not frame._fixed_width then
            self._fixed_width = false
         end
      end
   else -- self.type == 'col'
      --  The frame is fixed width if one of the frames in the column is fixed width.
      self._fixed_width = false
      for _, frame in ipairs(self.children) do
         frame:mark_fixed_width()
         if frame._fixed_width then
            self._fixed_width = true
         end
      end
   end
end

function Frame:mark_fixed_height()
   if self._fixed_height ~= nil then return end
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
         frame:mark_fixed_height()
         if frame._fixed_height then
            self._fixed_height = true
         end
      end
   else -- self.type == 'col'
      --  The frame is fixed height if all of the frames in the column are fixed height.
      self._fixed_height = true
      for _, frame in ipairs(self.children) do
         frame:mark_fixed_height()
         if not frame._fixed_height then
            self._fixed_height = false
         end
      end
   end
end

---@return boolean
function Frame:is_fixed_width()
   assert(self._fixed_width ~= nil, 'Need to call Frame:mark_fixed_width() method first')
   return self._fixed_width
end

---@return boolean
function Frame:is_fixed_height()
   assert(self._fixed_height ~= nil, 'Need to call Frame:mark_fixed_height() method first')
   return self._fixed_height
end

---Get child frame that contains target frame.
---@param frame win.Frame
---@return win.Frame
---@return integer index Index of child frame among other children.
function Frame:get_child(frame)
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
      for i, frame in ipairs(self.children) do
         print(i, frame.type)
         local col = frame:get_longest_column()
         print(type(col))
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
   if self.parent == nil then
      return vim.o.columns --[[@as integer]]
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
   if self.parent == nil then
      return vim.o.lines --[[@as integer]]
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

         local var_height_frames = {} ---@type win.Frame[]
         for _, frame in ipairs(self.children) do
            if frame:is_fixed_height() then
               frame.new_height = frame:get_height()
               room = room - frame.new_height - 1
               Nw = Nw - #frame:get_longest_row()
            else
               table.insert(var_height_frames, frame)
            end
         end

         local Nf = #var_height_frames -- number of frames
         for i, frame in ipairs(var_height_frames) do
            if i == Nf then
               frame.new_height = room
            else
               local n = #frame:get_longest_row()
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

-- function Frame:equalize_windows_widths()
--    if self.type == 'col' then
--       local w = self.new_width
--       for _, frame in ipairs(self.children) do
--          frame.new_width = w
--          if frame.type ~= 'leaf' then
--             frame:equalize_windows_widths()
--          end
--       end
--    elseif self.type == 'row' then
--
--       local Nw = #self:get_longest_row() -- number of windows
--
--       -- #self.children - 1 : widths of separators between children frames
--       local room = self.new_width - #self.children + 1
--
--       local var_width_frames = {} ---@type win.Frame[]
--       for _, frame in ipairs(self.children) do
--          if frame:is_fixed_width() then
--             frame.new_width = frame:get_width()
--             room = room - frame.new_width - 1
--             Nw = Nw - #frame:get_longest_row()
--          else
--             table.insert(var_width_frames, frame)
--          end
--       end
--
--       local Nf = #var_width_frames -- number of frames
--       for i, frame in ipairs(var_width_frames) do
--          if not frame.new_width then
--             if i == Nf then
--                frame.new_width = room
--             else
--                local n = #frame:get_longest_row()
--                local width = round(room * n / Nw + n - 1)
--                Nw = Nw - n
--                frame.new_width = width
--                room = room - width
--             end
--          end
--       end
--
--       for _, frame in ipairs(self.children) do
--          if frame.type ~= 'leaf' then
--             frame:equalize_windows_widths()
--          end
--       end
--    end
-- end

---Return the list of indexes of nested frames, follow which you can find the
---window "leaf" frame.
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

--------------------------------------------------------------------------------

-- ---Mark all nested frames that contain passed window. Whether the frame is
-- ---marked, can be checked with `is_curwin` method.
-- ---@param win? win.Window
-- function Frame:set_curwin(win)
--    win = win or Window()
--    local frame = self:find_window(win)
--    while frame do
--       frame._curwin_frame = true
--       frame = frame.parent
--    end
-- end
--
-- ---Return `true` if the frame containes "current" window.
-- ---@return boolean
-- function Frame:is_curwin()
--    return self._curwin_frame or false
-- end
--
-- ---@return win.Frame
-- function Frame:get_curwinFrame()
--    for _, frame in ipairs(self.children) do
--       if frame:is_curwin() then
--          return frame
--       end
--    end
--    error('No curwinFrame found')
-- end

--------------------------------------------------------------------------------

---Does frame have leaf-type frame among its children?
function Frame:has_leaf()
   if self.type == 'leaf' then
      return false
   end
   for _, frame in ipairs(self.children) do
      if frame.type == 'leaf' then
         return true
      end
   end
   return false
end

function Frame:get_all_leafs()
   if self.type == 'leaf' then
      return { self }
   else
      local output = {}
      for _, frame in ipairs(self.children) do
         list_extend(output, frame:get_all_leafs())
      end
      return output
   end
end

--------------------------------------------------------------------------------

---Extract the list of windows suitable for auto-width resizing.
---@param add_last_in_first_row boolean? Add last frame in first row
---@return win.Frame[]
function Frame:_get_leafs_for_auto_width_recursively(add_last_in_first_row)
   if self.type == 'leaf' then
      return { self }
   elseif self.type == 'row' then
      local output = {}

      local N = #self.children

      if self.children[N-1].type ~= 'leaf'
         and not self.children[N-1]:has_leaf()
      then
         -- self.children[N-1] should be colomn frame because we are in row frame
         add_last_in_first_row = true
      end

      for i, frame in ipairs(self.children) do
         if i ~= N or frame.type ~= 'leaf' or add_last_in_first_row then
            if frame.type == 'leaf' then
               table.insert(output, frame)
            else
               list_extend(output, frame:_get_leafs_for_auto_width_recursively())
            end
         end
      end

      return output
   else -- self.type == 'col'
      local output = {}

      local has_leaf = false
      for _, frame in ipairs(self.children) do
         if frame.type == 'leaf' then
            table.insert(output, frame)
            has_leaf = true
            break
         end
      end

      for i, frame in ipairs(self.children) do
         if frame.type ~= 'leaf' then
            list_extend(output, frame:_get_leafs_for_auto_width_recursively(
               i == 1 and not has_leaf))
         end
      end

      return output
   end
end

---@return win.Frame[]
function Frame:get_leafs_for_auto_width()
   if self.type == 'leaf' then
      return { self }
   end

   -- ---Set with all WinIDs of the rightmost windows.
   -- local rightmost_winids = {}
   -- for _, l in ipairs(self:_get_rightmost_frames()) do
   --    rightmost_winids[l.win.id] = true
   -- end

   local list = {}
   for _, leaf in ipairs(self:_get_leafs_for_auto_width_recursively()) do
      -- if not rightmost_winids[leaf.win.id] then
      --    table.insert(list, leaf)
      -- end
      table.insert(list, leaf)
   end

   return list
end

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
--    { "leaf", 1000 },
--    { "col", {
--       { "row", {
--          { "leaf", 1005 },
--          { "leaf", 1006 }
--       }},
--       { "row", {
--          { "leaf", 1007 },
--          { "leaf", 1008 }
--       }},
--    }},
--    { "leaf", 1002 }
-- }}

--------------------------------------------------------------------------------

-- local frame1 = Frame(test_layouts[1])
-- local frame2 = Frame(test_layouts[2])
-- local frame3 = Frame(test_layouts[3])
-- local frame4 = Frame(test_layouts[4])

-- local w = {}
-- for _, f in ipairs(frame2:get_longest_column_contains_target_window(Window(1006))) do
--    w[#w+1] = f.win.id
-- end
-- print(w)

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
