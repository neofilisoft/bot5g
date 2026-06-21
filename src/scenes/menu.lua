-- src/scenes/menu.lua
local Theme = require("src.ui.theme")
local Button = require("src.ui.button")
local Manager = require("src.scenes.manager")

local Menu = {}

function Menu:enter()
	self.buttons = {
		Button.new({ x = 600, y = 420, w = 400, h = 64, label = "เล่น 2 คน (Local Hotseat)", style = "primary",
			onClick = function() local Lobby = require("src.scenes.lobby"); Manager.switch(Lobby, "hotseat") end }),
		Button.new({ x = 600, y = 500, w = 400, h = 64, label = "เล่นกับ AI บอท", style = "primary",
			onClick = function() local Lobby = require("src.scenes.lobby"); Manager.switch(Lobby, "vsai") end }),
		Button.new({ x = 600, y = 580, w = 400, h = 64, label = "สร้างห้อง 5G (Host)",
			onClick = function() local Lobby = require("src.scenes.lobby"); Manager.switch(Lobby, "host") end }),
		Button.new({ x = 600, y = 660, w = 400, h = 64, label = "เข้าร่วมห้อง 5G (Join)",
			onClick = function() local Lobby = require("src.scenes.lobby"); Manager.switch(Lobby, "join") end }),
	}
end

function Menu:update(dt)
	local mx, my = love.mouse.getPosition()
	mx, my = Manager.toVirtual(mx, my)
	for _, b in ipairs(self.buttons) do b:update(mx, my) end
end

function Menu:draw()
	love.graphics.setColor(Theme.color.bg)
	love.graphics.rectangle("fill", 0, 0, Manager.VW, Manager.VH)

	love.graphics.setFont(Theme.fonts.title)
	Theme.setColor(Theme.color.accent2)
	love.graphics.printf("BATTLE OF TALINGCHAN 5G", 0, 140, Manager.VW, "center")

	for _, b in ipairs(self.buttons) do b:draw() end

	love.graphics.setFont(Theme.fonts.tiny)
	Theme.setColor(Theme.color.textDim)
	love.graphics.printf("ฟอนต์ Kanit (SIL OFL)  -  ไม่เกี่ยวข้องกับผู้สร้างเกมต้นฉบับ", 0, Manager.VH - 30, Manager.VW, "center")

	Theme.setColor(Theme.color.textDim)
	love.graphics.printf("Powered by Neofilisoft", Manager.VW - 260, Manager.VH - 24, 240, "right")
end

function Menu:mousepressed(x, y, btn)
	for _, b in ipairs(self.buttons) do
		if b:mousepressed(x, y, btn) then return end
	end
end

return Menu
