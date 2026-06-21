-- src/class.lua
-- Minimal class system (single inheritance) used across the project.
local function class(base)
	local cls = {}
	cls.__index = cls
	if base then
		setmetatable(cls, { __index = base })
	end
	cls.super = base
	cls.new = function(...)
		local self = setmetatable({}, cls)
		if self.init then self:init(...) end
		return self
	end
	return cls
end

return class
