-- src/ui/button.lua
local class = require("src.class")
local Theme = require("src.ui.theme")

local Button = class()

function Button:init(opts)
	self.x, self.y, self.w, self.h = opts.x, opts.y, opts.w, opts.h
	self.label = opts.label
	self.onClick = opts.onClick
	self.enabled = opts.enabled
	if self.enabled == nil then self.enabled = true end
	self.hover = false
	self.style = opts.style or "default" -- "default" | "primary" | "danger"
	self.font = opts.font
end

function Button:contains(x, y)
	return x >= self.x and x <= self.x + self.w and y >= self.y and y <= self.y + self.h
end

function Button:update(mx, my)
	self.hover = self:contains(mx, my)
end

function Button:mousepressed(x, y, btn)
	if btn == 1 and self.enabled and self:contains(x, y) then
		if self.onClick then self.onClick() end
		return true
	end
	return false
end

function Button:draw()
	local bg = Theme.color.bgPanel2
	local border = Theme.color.border
	if self.style == "primary" then border = Theme.color.accent end
	if self.style == "danger" then border = Theme.color.bad end
	if not self.enabled then
		love.graphics.setColor(0.2, 0.2, 0.24, 0.6)
		love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 8, 8)
		Theme.outlineRect(self.x, self.y, self.w, self.h, 8, { 0.3, 0.3, 0.34 })
	else
		Theme.rect(self.x, self.y, self.w, self.h, 8, bg)
		if self.hover then
			love.graphics.setColor(1, 1, 1, 0.06)
			love.graphics.rectangle("fill", self.x, self.y, self.w, self.h, 8, 8)
		end
		Theme.outlineRect(self.x, self.y, self.w, self.h, 8, border, self.hover and 3 or 2)
	end
	love.graphics.setFont(self.font or Theme.fonts.label)
	if self.enabled then Theme.setColor(Theme.color.text) else Theme.setColor(Theme.color.textDim) end
	love.graphics.printf(self.label, self.x, self.y + self.h / 2 - 11, self.w, "center")
end

return Button
