-- src/scenes/lobby.lua
local Theme = require("src.ui.theme")
local Button = require("src.ui.button")
local Manager = require("src.scenes.manager")
local Decks = require("src.decks")
local Network = require("src.net.network")
local protocol = require("src.net.protocol")

local Lobby = {}

local function deckPickerButtons(x, y, selectedRef, onPick)
	local buttons = {}
	for i, d in ipairs(Decks.list) do
		local bx = x
		local by = y + (i - 1) * 90
		buttons[#buttons + 1] = Button.new({
			x = bx, y = by, w = 320, h = 76, label = d.name,
			onClick = function() selectedRef.id = d.id; onPick() end,
		})
	end
	return buttons
end

function Lobby:enter(mode)
	self.mode = mode -- "hotseat" | "vsai" | "host" | "join"
	self.status = nil
	self.net = nil
	self.ipInput = "127.0.0.1"
	self.ipFocused = false
	self.pickerStage = 1 -- for hotseat: 1=pick P1 deck, 2=pick P2 deck
	self.deck1 = { id = "deckA" }
	self.deck2 = { id = "deckB" }
	self.myDeck = { id = "deckA" }
	self:rebuildButtons()
end

function Lobby:leave()
	-- keep self.net alive if we're transitioning into the game scene with it;
	-- the game scene takes ownership. Nothing to clean up here.
end

function Lobby:rebuildButtons()
	self.buttons = {}
	self.buttons[#self.buttons + 1] = Button.new({
		x = 20, y = 20, w = 140, h = 44, label = "◀ กลับ",
		onClick = function() local Menu = require("src.scenes.menu"); Manager.switch(Menu) end,
	})

	if self.mode == "hotseat" then
		local p1btns = deckPickerButtons(220, 200, self.deck1, function() end)
		local p2btns = deckPickerButtons(1060, 200, self.deck2, function() end)
		for _, b in ipairs(p1btns) do self.buttons[#self.buttons + 1] = b end
		for _, b in ipairs(p2btns) do self.buttons[#self.buttons + 1] = b end
		self.buttons[#self.buttons + 1] = Button.new({
			x = 600, y = 760, w = 400, h = 70, label = "เริ่มเกม ▶", style = "primary",
			onClick = function() self:startHotseat() end,
		})
	elseif self.mode == "vsai" then
		local p1btns = deckPickerButtons(220, 200, self.deck1, function() end)
		local p2btns = deckPickerButtons(1060, 200, self.deck2, function() end)
		for _, b in ipairs(p1btns) do self.buttons[#self.buttons + 1] = b end
		for _, b in ipairs(p2btns) do self.buttons[#self.buttons + 1] = b end
		self.buttons[#self.buttons + 1] = Button.new({
			x = 600, y = 760, w = 400, h = 70, label = "เริ่มเกม ▶", style = "primary",
			onClick = function() self:startVsAI() end,
		})
	elseif self.mode == "host" then
		local btns = deckPickerButtons(640, 220, self.myDeck, function() end)
		for _, b in ipairs(btns) do self.buttons[#self.buttons + 1] = b end
		self.buttons[#self.buttons + 1] = Button.new({
			x = 600, y = 560, w = 400, h = 70, label = "เปิดห้อง (Create Room) ▶", style = "primary",
			onClick = function() self:doHost() end,
		})
	elseif self.mode == "join" then
		local btns = deckPickerButtons(640, 220, self.myDeck, function() end)
		for _, b in ipairs(btns) do self.buttons[#self.buttons + 1] = b end
		self.buttons[#self.buttons + 1] = Button.new({
			x = 600, y = 620, w = 400, h = 70, label = "เชื่อมต่อ (Join) ▶", style = "primary",
			onClick = function() self:doJoin() end,
		})
	end
end

function Lobby:startHotseat()
	local RPS = require("src.scenes.rps")
	Manager.switch(RPS, { mode = "hotseat", deckId1 = self.deck1.id, deckId2 = self.deck2.id })
end

function Lobby:startVsAI()
	local RPS = require("src.scenes.rps")
	Manager.switch(RPS, { mode = "vsai", deckId1 = self.deck1.id, deckId2 = self.deck2.id })
end

function Lobby:doHost()
	local net, err = Network.startHost(Network.DEFAULT_PORT)
	if not net then
		self.status = "ผิดพลาด: " .. tostring(err)
		return
	end
	self.net = net
	self.localIP = Network.guessLocalIP()
	self.status = "รอผู้เล่นอีกฝ่ายเชื่อมต่อ... แชร์ที่อยู่: " .. self.localIP .. ":" .. tostring(net.port)
	net.onConnect = function()
		self.status = "ผู้เล่นเชื่อมต่อแล้ว กำลังรอข้อมูลเด็ค..."
	end
	net.onMessage = function(msg)
		if msg.t == protocol.HELLO then
			self.remoteDeckId = msg.deckId or "deckB"
			self.remoteName = msg.name or "Player 2"
			net:send({ t = protocol.WELCOME, seat = 2, name = "Host" })
			local RPS = require("src.scenes.rps")
			Manager.switch(RPS, {
				mode = "host", net = self.net,
				deckId1 = self.myDeck.id, deckId2 = self.remoteDeckId,
				name1 = "Host", name2 = self.remoteName,
			})
		end
	end
end

function Lobby:doJoin()
	local net, err = Network.startClient(self.ipInput, Network.DEFAULT_PORT)
	if not net then
		self.status = "ผิดพลาด: " .. tostring(err)
		return
	end
	self.net = net
	self.status = "กำลังเชื่อมต่อ " .. self.ipInput .. " ..."
	net.onConnect = function()
		self.status = "เชื่อมต่อสำเร็จ กำลังส่งข้อมูล..."
		net:send({ t = protocol.HELLO, name = "Player 2", deckId = self.myDeck.id })
	end
	net.onMessage = function(msg)
		if msg.t == protocol.WELCOME then
			local RPS = require("src.scenes.rps")
			Manager.switch(RPS, { mode = "client", net = self.net, mySeat = msg.seat or 2 })
		end
	end
end

function Lobby:update(dt)
	if self.net then self.net:update() end
	local mx, my = love.mouse.getPosition()
	mx, my = Manager.toVirtual(mx, my)
	for _, b in ipairs(self.buttons) do b:update(mx, my) end
end

local titles = {
	hotseat = "เล่น 2 คน (Local Hotseat) - เลือกเด็คทั้งสองฝ่าย",
	vsai = "เล่นกับ AI - เลือกเด็คของคุณและของบอท",
	host = "สร้างห้อง 5G (Host)",
	join = "เข้าร่วมห้อง 5G (Join)",
}

function Lobby:draw()
	love.graphics.setColor(Theme.color.bg)
	love.graphics.rectangle("fill", 0, 0, Manager.VW, Manager.VH)

	love.graphics.setFont(Theme.fonts.heading)
	Theme.setColor(Theme.color.text)
	love.graphics.printf(titles[self.mode] or "", 0, 90, Manager.VW, "center")

	if self.mode == "hotseat" or self.mode == "vsai" then
		love.graphics.setFont(Theme.fonts.label)
		Theme.setColor(Theme.color.textDim)
		love.graphics.printf(self.mode == "hotseat" and "ผู้เล่น 1" or "คุณ", 220, 160, 320, "center")
		love.graphics.printf(self.mode == "hotseat" and "ผู้เล่น 2" or "บอท (AI)", 1060, 160, 320, "center")
		for i, d in ipairs(Decks.list) do
			local sel1 = self.deck1.id == d.id
			local sel2 = self.deck2.id == d.id
			Theme.setColor(sel1 and Theme.color.good or Theme.color.textDim)
			love.graphics.setFont(Theme.fonts.tiny)
			love.graphics.printf(d.desc, 220, 200 + (i - 1) * 90 + 50, 320, "center")
			Theme.setColor(sel2 and Theme.color.good or Theme.color.textDim)
			love.graphics.printf(d.desc, 1060, 200 + (i - 1) * 90 + 50, 320, "center")
		end
	elseif self.mode == "host" then
		love.graphics.setFont(Theme.fonts.label)
		Theme.setColor(Theme.color.textDim)
		love.graphics.printf("เลือกเด็คของคุณ", 640, 170, 320, "center")
		for i, d in ipairs(Decks.list) do
			local sel = self.myDeck.id == d.id
			Theme.setColor(sel and Theme.color.good or Theme.color.textDim)
			love.graphics.setFont(Theme.fonts.tiny)
			love.graphics.printf(d.desc, 640, 220 + (i - 1) * 90 + 50, 320, "center")
		end
		if self.status then
			love.graphics.setFont(Theme.fonts.body)
			Theme.setColor(Theme.color.accent)
			love.graphics.printf(self.status, 200, 670, 1200, "center")
		end
	elseif self.mode == "join" then
		love.graphics.setFont(Theme.fonts.label)
		Theme.setColor(Theme.color.textDim)
		love.graphics.printf("เลือกเด็คของคุณ", 640, 170, 320, "center")
		for i, d in ipairs(Decks.list) do
			local sel = self.myDeck.id == d.id
			Theme.setColor(sel and Theme.color.good or Theme.color.textDim)
			love.graphics.setFont(Theme.fonts.tiny)
			love.graphics.printf(d.desc, 640, 220 + (i - 1) * 90 + 50, 320, "center")
		end
		love.graphics.setFont(Theme.fonts.label)
		Theme.setColor(Theme.color.text)
		love.graphics.printf("ที่อยู่ห้อง (IP):", 600, 480, 400, "left")
		Theme.rect(600, 515, 400, 50, 6, Theme.color.bgPanel2)
		Theme.outlineRect(600, 515, 400, 50, 6, self.ipFocused and Theme.color.accent or Theme.color.border, 2)
		love.graphics.setFont(Theme.fonts.body)
		Theme.setColor(Theme.color.text)
		love.graphics.printf(self.ipInput .. (self.ipFocused and "_" or ""), 612, 528, 380, "left")
		if self.status then
			love.graphics.setFont(Theme.fonts.body)
			Theme.setColor(Theme.color.accent)
			love.graphics.printf(self.status, 200, 700, 1200, "center")
		end
	end

	for _, b in ipairs(self.buttons) do b:draw() end
end

function Lobby:mousepressed(x, y, btn)
	if self.mode == "join" then
		self.ipFocused = (x >= 600 and x <= 1000 and y >= 515 and y <= 565)
	end
	for _, b in ipairs(self.buttons) do
		if b:mousepressed(x, y, btn) then return end
	end
end

function Lobby:textinput(t)
	if self.mode == "join" and self.ipFocused then
		self.ipInput = self.ipInput .. t
	end
end

function Lobby:keypressed(key)
	if self.mode == "join" and self.ipFocused and key == "backspace" then
		self.ipInput = self.ipInput:sub(1, -2)
	end
end

return Lobby
