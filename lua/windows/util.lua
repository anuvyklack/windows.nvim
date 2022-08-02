local util = {}
local floor = math.floor
local ceil = math.ceil

---Merge input config into default
---@param default table
---@param input table
---@return table
function util.megre_config(default, input)
   local r = default
   for key, value in pairs(input) do
      if type(value) == 'table' then
         r[key] = util.megre_config(r[key], value)
      else
         r[key] = input[key]
      end
   end
   return r
end

---Without arguments return a current high-resolution time in milliseconds.
---If `start` is passed, then return the time passed since given time point.
---@param start? number some time point in the past
---@return number time
function util.time(start)
   local time = vim.loop.hrtime() / 1e6
   if start then
      time = time - start
   end
   return time
end

---Returns the integer part of the number
---@param x number
---@return integer
function util.to_integer(x)
   if x > 0 then
      return floor(x)
   else
      return ceil(x)
   end
end

---@param x number
---@return integer
function util.round(x)
   return floor(x + 0.5)
end

function util.convert_list_to_set(list)
   for i = 1, #list do
      list[list[i]] = true
      list[i] = nil
   end
end

---@generic T
---@param minuend T
---@param subtract T
---@return T
function util.subtract_list_from_list(minuend, subtract)
   local set_to_substract = {}
   for _, v in ipairs(subtract) do
      set_to_substract[v] = true
   end
   local result = {}
   for _, v in ipairs(minuend) do
      if not set_to_substract[v] then
         table.insert(result, v)
      end
   end
   return result
end

return util
