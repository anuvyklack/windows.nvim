local util = require('windows.util')
local animation_is_available, easing = pcall(require, 'animation.easing')
local default_easing = 'in_out_sine'
local initialized = false
local mt = {}

---@class win.Config
---@field animation { duration: integer, fps: integer, easing: fun(ratio: number): number } | false
---@field ignore { buftype: table<string, true>, filetype: table<string, true> }
local config = {
   enable_autowidth = true,
   winwidth = 10,
   winminwidth = 20, -- vim.o.winminwidth
   ignore = {
      buftype = { 'quickfix' },
      filetype = { 'neo-tree', 'NvimTree' }
   },
   animation = {
      duration = 300,
      fps = 30,
   }
}

---@param input? table
---@return win.Config
function mt:__call(input)
   if initialized then return config end

   util.megre_config(config, input or {})
   util.convert_list_to_set(config.ignore.buftype)
   util.convert_list_to_set(config.ignore.filetype)
   if config.animation and animation_is_available then
      if not config.animation.easing
         or type(config.animation.easing) == 'string'
      then
         local name = config.animation.easing or default_easing
         config.animation.easing = easing[name]
      end
   else
      config.animation = false
   end

   initialized = true
   return config
end

setmetatable(config, mt)

return config

