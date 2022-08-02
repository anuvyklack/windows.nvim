local function singleton(super)
   local class = {}
   class.__index = class

   function class:new(...)
      if class._instance then
         return class._instance
      end

      local instance = setmetatable({}, class)
      if instance.initialize then
         instance:initialize(...)
      end

      class._instance = instance
      return class._instance
   end

   local mt = {}
   mt.__index = super
   mt.__call = class.new

   return setmetatable(class, mt)
end

return singleton
