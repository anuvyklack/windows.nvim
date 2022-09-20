local ffi = require("ffi")
local M = {}

ffi.cdef('int curwin_col_off(void);')

---The width of offset of a window, occupied by line number column,
---fold column and sign column.
---@type fun():integer
M.curwin_col_off = ffi.C.curwin_col_off

return M

