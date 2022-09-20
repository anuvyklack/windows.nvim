---
--- Singleton
---
local util = require('windows.lib.util')
local animation_is_available, easing = pcall(require, 'animation.easing')
local initialized = false
local mt = {}

---@class win.Config
---@field animation { enable: boolean, duration: integer, fps: integer, easing: fun(ratio: number): number }
---@field ignore { buftype: table<string, true>, filetype: table<string, true> }
local config = {
   autowidth = {
      enable = true, -- false
      winwidth = 5,
      filetype = {
         help = 2,
      },
   },
   ignore = {
      buftype = { 'quickfix' },
      filetype = { 'undotree', 'gundo', 'NvimTree', 'neo-tree' }
   },
   animation = {
      enable = true,
      duration = 300,
      fps = 30,
      easing = 'in_out_sine' ---@diagnostic disable-line
   }
}

---@param input? table
---@return win.Config
function mt:__call(input)
   if initialized then return config end

   util.megre_config(config, input or {})
   util.convert_list_to_set(config.ignore.buftype)
   util.convert_list_to_set(config.ignore.filetype)
   if config.animation.enable and animation_is_available then
      if not config.animation.easing
         or type(config.animation.easing) == 'string'
      then
         local name = config.animation.easing
         config.animation.easing = easing[name]
      end
   else
      config.animation.enable = false
   end

   initialized = true
   return config
end

setmetatable(config, mt)

return config

