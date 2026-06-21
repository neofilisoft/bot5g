-- src/ui/log.lua
local Theme = require("src.ui.theme")

local Log = {}

function Log.draw(x, y, w, h, entries)
	Theme.rect(x, y, w, h, 8, Theme.color.bgPanel)
	Theme.outlineRect(x, y, w, h, 8, Theme.color.border, 1)
	love.graphics.setFont(Theme.fonts.tiny)
	love.graphics.setScissor(x + 4, y + 4, w - 8, h - 8)
	local lineH = 18
	local maxLines = math.floor((h - 12) / lineH)
	local total = #entries
	local startI = math.max(1, total - maxLines + 1)
	local yy = y + 6
	for i = startI, total do
		Theme.setColor(Theme.color.textDim)
		love.graphics.printf(entries[i], x + 8, yy, w - 16, "left")
		yy = yy + lineH
	end
	love.graphics.setScissor()
end

return Log
