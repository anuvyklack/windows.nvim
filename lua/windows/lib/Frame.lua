local class = require('middleclass')
local Window = require('windows.lib.Window')
local round = require('windows.util').round
local list_extend = vim.list_extend

---@class win.Frame
---@field type 'leaf' | 'col' | 'row'
---@field parent win.Frame | nil
---@field children win.Frame[]
---@field prev win.Frame | nil frame left or above in same parent, nil for first
---@field next win.Frame | nil frame right or below in same parent, nil for last
---@field win win.Window
---@field new_width integer
---@field _fixed_width boolean
local Frame = class('win.Frame')

function Frame:initialize(layout, parent)
   layout = layout or vim.fn.winlayout()
   self.parent = parent
   self.type = layout[1]
   if self.type == 'leaf' then
      self.win = Window(layout[2])
   else -- 'row' or 'col'
      local children = {}  ---@type win.Frame[]
      for i, l in ipairs(layout[2]) do
         children[i] = Frame(l, self)
      end
      for i, frame in ipairs(children) do
         frame.prev = children[i-1]
         frame.next = children[i+1]
      end
      self.children = children
   end
end

---Calculate the maximum number of windows horizontally in this frame and return
---these windows "leaf" frames as a list.
---@return win.Frame[]
function Frame:get_longest_row()
   local list, _ = self:_get_longest_row_contains_target_window()
   return list
end

---@param win win.Window
---@return win.Frame[]
function Frame:get_longest_row_contains_target_window(win)
   local list, found = self:_get_longest_row_contains_target_window(win)
   assert(found, 'Invalid window')
   return list
end

---@param win? win.Window
---@return win.Frame[]
---@return boolean found
function Frame:_get_longest_row_contains_target_window(win)
   if self.type == 'leaf' then
      return { self }, self.win == win
   elseif self.type == 'row' then
      local output = {} ---@type win.Frame[]
      local found = false
      for _, frame in ipairs(self.children) do
         local o, f = frame:_get_longest_row_contains_target_window(win)
         list_extend(output, o)
         found = found or f
      end
      return output, found
   else -- self.type == 'col'
      local output = {} ---@type win.Frame[]
      for _, node in ipairs(self.children) do
         local o, f = node:_get_longest_row_contains_target_window(win)
         if f then
            return o, true
         elseif #o > #output then
            output = o
         end
      end
      return output, false
   end
end

---Return `true` if width of the frame should not be changed because of the
---'winfixwidth' option.
---@return boolean
function Frame:is_fixed_width()
   if self._fixed_width then
      return self._fixed_width
   elseif self.type == 'leaf' then
      if self.win:is_ignored() then
         self._fixed_width = true
      else
         -- Frame with one window: fixed width if 'winfixwidth' set.
         self._fixed_width = self.win:get_option('winfixwidth')
      end
      return self._fixed_width
   elseif self.type == 'row' then
      --  The frame is fixed width if all of the frames in the row are fixed width.
      for _, frame in ipairs(self.children) do
         if not frame:is_fixed_width() then
            self._fixed_width = false
            return false
         end
         self._fixed_width = true
         return true
      end
   else -- self.type == 'col'
      --  The frame is fixed width if one of the frames in the column is fixed width.
      for _, frame in ipairs(self.children) do
         if frame:is_fixed_width() then
            self._fixed_width = true
            return true
         end
         self._fixed_width = false
         return false
      end
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

function Frame:equalize_windows_widths()
   if self.type == 'col' then
      local w = self.new_width
      for _, frame in ipairs(self.children) do
         frame.new_width = w
         if frame.type ~= 'leaf' then
            frame:equalize_windows_widths()
         end
      end
   elseif self.type == 'row' then
      local Nf = #self.children -- number of frames
      local Nw = #self:get_longest_row() -- number of windows

      -- Nf-1 : widths of separators between children frames
      local room = self.new_width - Nf + 1

      for _, frame in ipairs(self.children) do
         if frame:is_fixed_width() then
            local width = frame:get_width()
            frame.new_width = width
            room = room - width - 1
            Nw = Nw - #frame:get_longest_row()
         end
      end

      for i, frame in ipairs(self.children) do
         if not frame.new_width then
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
         if frame.type ~= 'leaf' then
            frame:equalize_windows_widths()
         end
      end
   end
end

---Return the list of indexes of nested frames, follow which you can find the
---window "leaf" frame.
---@param win win.Window
---@return integer[] | nil path
function Frame:find_window(win)
   if self.type == 'leaf' then
      if self.win == win then
         return {}
      end
   else
      for i, frame in ipairs(self.children) do
         local path = frame:find_window(win)
         if path then
            table.insert(path, 1, i)
            return path
         end
      end
   end
end

--------------------------------------------------------------------------------

function Frame:_get_rightmost_frames()
   if self.type == 'leaf' then
      return { self }
   elseif self.type == 'row' then
      local frame = self.children[#self.children]
      return frame:_get_rightmost_frames()
   else -- self.type == 'col'
      local output = {}
      for _, frame in ipairs(self.children) do
         list_extend(output, frame:_get_rightmost_frames())
      end
      return output
   end
end

---@param add_last_in_first_row boolean? Add last frame in first row
---@return win.Frame[]
function Frame:_get_leafs_for_auto_width_recursively(add_last_in_first_row)
   if self.type == 'leaf' then
      return { self }
   elseif self.type == 'row' then
      local output = {}

      local N = #self.children

      if self.children[N-1].type ~= 'leaf' then
         local colFrame = self.children[N-1]
         local colFrame_has_leafs = false
         for i, f in ipairs(colFrame) do
            if f.type == 'leaf' then
               colFrame_has_leafs = true
               break
            end
         end
         if not colFrame_has_leafs then
            add_last_in_first_row = true
         end
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
            has_leaf = true
            break
         end
      end

      local leaf_added = false
      for i, frame in ipairs(self.children) do
         if frame.type == 'leaf' and not leaf_added then
            table.insert(output, frame)
            leaf_added = true
         else
            list_extend(output, frame:_get_leafs_for_auto_width_recursively(
                                   i == 1 and not has_leaf or false))
         end
      end

      return output
   end
end

---Extract the list of windows suitable for auto-width resizing.
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

function Frame:get_leafs()
   if self.type == 'leaf' then
      return { self }
   else
      local output = {}
      for _, frame in ipairs(self.children) do
         list_extend(output, frame:get_leafs())
      end
      return output
   end
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
--
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

-- leafs = frame1:get_rightmost_frames()
-- wins = {}
-- for _, l in ipairs(leafs) do
--    print(l.win.id)
--    table.insert(wins, l.win.id)
-- end
-- print(wins)
--
-- leafs = frame2:get_rightmost_frames()
-- wins = {}
-- for _, l in ipairs(leafs) do
--    table.insert(wins, l.win.id)
-- end
-- print(wins)

-- local leafs = frame2:get_longest_row()
-- print(#leafs)
--
-- local subtract_list_from_list = require('windows.util').subtract_list_from_list
-- local l = frame2.children[1]:get_longest_row()
-- local r = subtract_list_from_list(leafs, l)
-- print(#r)

-- local width, wins = frame2:get_min_width()
-- print(width, wins)
-- width, wins = frame2:get_min_width(1009, 80)
-- print(width, wins)

-- local path
-- path = frame1:find_window(Window(1007))
-- print(path)
-- path = frame2:find_window(Window(1011))
-- print(path)
--
-- local row
-- row = frame1:get_longest_row()
-- print(#row)
-- for i, frame in ipairs(row) do
--    print(tostring(frame))
--    print(tostring(frame.win))
--    print(frame.win.id)
-- end

------------------------------------------------------------------------------

return Frame
