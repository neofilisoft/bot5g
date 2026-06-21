-- src/scenes/rps.lua
local Theme = require("src.ui.theme")
local Button = require("src.ui.button")
local Manager = require("src.scenes.manager")
local protocol = require("src.net.protocol")

local RPS = {}

local CHOICES = { "rock", "scissors", "paper" }
local LABEL = { rock = "ค้อน", scissors = "กรรไกร", paper = "กระดาษ" }

local function beats(a, b)
	return (a == "rock" and b == "scissors") or (a == "scissors" and b == "paper") or (a == "paper" and b == "rock")
end

local function randomChoice()
	return CHOICES[math.random(1, 3)]
end

function RPS:enter(opts)
	self.opts = opts
	self.mode = opts.mode
	self.net = opts.net
	self.buttons = {}
	self.hostChoice, self.clientChoice = nil, nil
	self.resolved = false
	self.result = nil

	if self.mode == "hotseat" then
		self.stage = "p1ready"
		self.p1Choice, self.p2Choice = nil, nil
	elseif self.mode == "vsai" then
		self.stage = "choose"
	elseif self.mode == "host" then
		self.net.onMessage = function(msg) self:onHostMessage(msg) end
		self.net.onDisconnect = function() local Menu = require("src.scenes.menu"); Manager.switch(Menu) end
		self.stage = "choose"
	elseif self.mode == "client" then
		self.net.onMessage = function(msg) self:onClientMessage(msg) end
		self.net.onDisconnect = function() local Menu = require("src.scenes.menu"); Manager.switch(Menu) end
		self.stage = "choose"
	end
	self:rebuildButtons()
end

function RPS:leave() end

function RPS:proceedToGame(firstPlayer)
	local Game = require("src.scenes.game")
	if self.mode == "hotseat" then
		Manager.switch(Game, { mode = "hotseat", deckId1 = self.opts.deckId1, deckId2 = self.opts.deckId2, firstPlayer = firstPlayer })
	elseif self.mode == "vsai" then
		Manager.switch(Game, { mode = "vsai", deckId1 = self.opts.deckId1, deckId2 = self.opts.deckId2, firstPlayer = firstPlayer })
	elseif self.mode == "host" then
		Manager.switch(Game, {
			mode = "host", net = self.net, mySeat = 1,
			deckId1 = self.opts.deckId1, deckId2 = self.opts.deckId2,
			name1 = self.opts.name1, name2 = self.opts.name2, firstPlayer = firstPlayer,
		})
	end
end

-- ===================== host networking =====================

function RPS:onHostMessage(msg)
	if msg.t == protocol.RPS_CHOICE then
		self.clientChoice = msg.choice
		self:tryResolveHost()
	elseif msg.t == protocol.RPS_FIRSTPICK then
		local firstPlayer = msg.goFirst and 2 or 1
		self:proceedToGame(firstPlayer)
	end
end

function RPS:tryResolveHost()
	if self.resolved then return end
	if not (self.hostChoice and self.clientChoice) then return end
	self.resolved = true
	local tie = (self.hostChoice == self.clientChoice)
	local winnerSeat = nil
	if not tie then winnerSeat = beats(self.hostChoice, self.clientChoice) and 1 or 2 end
	self.net:send({ t = protocol.RPS_RESULT, hostChoice = self.hostChoice, clientChoice = self.clientChoice, tie = tie, winnerSeat = winnerSeat })
	self.result = { tie = tie, winnerSeat = winnerSeat, mine = self.hostChoice, theirs = self.clientChoice }
	self.stage = "reveal"
	self:rebuildButtons()
end

-- ===================== client networking =====================

function RPS:onClientMessage(msg)
	if msg.t == protocol.RPS_RESULT then
		self.result = { tie = msg.tie, winnerSeat = msg.winnerSeat, mine = msg.clientChoice, theirs = msg.hostChoice }
		self.stage = "reveal"
		self:rebuildButtons()
	elseif msg.t == protocol.STATE then
		local Game = require("src.scenes.game")
		Manager.switch(Game, { mode = "client", net = self.net, mySeat = self.opts.mySeat, initialView = msg.view })
	end
end

-- ===================== input handlers shared by stages =====================

function RPS:choose(choice)
	if self.mode == "hotseat" then
		if self.stage == "p1choose" then
			self.p1Choice = choice
			self.stage = "p2ready"
		elseif self.stage == "p2choose" then
			self.p2Choice = choice
			local tie = (self.p1Choice == self.p2Choice)
			local winnerSeat = nil
			if not tie then winnerSeat = beats(self.p1Choice, self.p2Choice) and 1 or 2 end
			self.result = { tie = tie, winnerSeat = winnerSeat, mine = self.p1Choice, theirs = self.p2Choice }
			self.stage = "reveal"
		end
	elseif self.mode == "vsai" then
		local opp = randomChoice()
		local tie = (choice == opp)
		local winnerSeat = nil
		if not tie then winnerSeat = beats(choice, opp) and 1 or 2 end
		self.result = { tie = tie, winnerSeat = winnerSeat, mine = choice, theirs = opp }
		self.stage = "reveal"
		if winnerSeat == 2 then
			self.aiGoFirst = (math.random() < 0.7)
		end
	elseif self.mode == "host" then
		self.hostChoice = choice
		self.stage = "waiting"
		self:tryResolveHost()
	elseif self.mode == "client" then
		self.net:send({ t = protocol.RPS_CHOICE, choice = choice })
		self.stage = "waiting"
	end
	self:rebuildButtons()
end

function RPS:pickFirstOrSecond(goFirst)
	if self.mode == "hotseat" then
		local winnerSeat = self.result.winnerSeat
		local loserSeat = (winnerSeat == 1) and 2 or 1
		self:proceedToGame(goFirst and winnerSeat or loserSeat)
	elseif self.mode == "vsai" then
		self:proceedToGame(goFirst and 1 or 2)
	elseif self.mode == "host" then
		self:proceedToGame(goFirst and 1 or 2)
	elseif self.mode == "client" then
		self.net:send({ t = protocol.RPS_FIRSTPICK, goFirst = goFirst })
		self.stage = "waitingStart"
		self:rebuildButtons()
	end
end

function RPS:rethrow()
	if self.mode == "hotseat" then
		self.p1Choice, self.p2Choice = nil, nil
		self.stage = "p1ready"
	else
		self.result = nil
		self.stage = "choose"
		if self.mode == "host" then self.hostChoice, self.clientChoice, self.resolved = nil, nil, false end
	end
	self:rebuildButtons()
end

-- ===================== buttons =====================

function RPS:rebuildButtons()
	self.buttons = {}
	local cx = 800

	if self.mode == "hotseat" and (self.stage == "p1ready" or self.stage == "p2ready") then
		return -- handled via full-screen tap in mousepressed
	end

	if self.stage == "choose" or self.stage == "p1choose" or self.stage == "p2choose" then
		local labels = { { c = "rock", t = "✊ ค้อน" }, { c = "scissors", t = "✌ กรรไกร" }, { c = "paper", t = "✋ กระดาษ" } }
		for i, l in ipairs(labels) do
			self.buttons[#self.buttons + 1] = Button.new({
				x = cx - 480 + (i - 1) * 340, y = 480, w = 300, h = 110, label = l.t, style = "primary",
				font = Theme.fonts.heading,
				onClick = function() self:choose(l.c) end,
			})
		end
	elseif self.stage == "reveal" then
		if self.result.tie then
			self.buttons[#self.buttons + 1] = Button.new({
				x = cx - 200, y = 600, w = 400, h = 70, label = "เสมอ! เป่าใหม่ 🔁", style = "primary",
				onClick = function() self:rethrow() end,
			})
		else
			local iWon
			if self.mode == "hotseat" then iWon = true -- the winner is the one whose turn it now is to choose (shown for both, see draw)
			elseif self.mode == "vsai" then iWon = (self.result.winnerSeat == 1)
			elseif self.mode == "host" then iWon = (self.result.winnerSeat == 1)
			elseif self.mode == "client" then iWon = (self.result.winnerSeat == self.opts.mySeat)
			end
			if self.mode == "hotseat" then
				local winnerSeat = self.result.winnerSeat
				self.buttons[#self.buttons + 1] = Button.new({
					x = cx - 420, y = 600, w = 380, h = 80, label = string.format("ผู้เล่น %d: ไปก่อน", winnerSeat), style = "primary",
					onClick = function() self:pickFirstOrSecond(true) end,
				})
				self.buttons[#self.buttons + 1] = Button.new({
					x = cx + 40, y = 600, w = 380, h = 80, label = string.format("ผู้เล่น %d: ไปทีหลัง", winnerSeat),
					onClick = function() self:pickFirstOrSecond(false) end,
				})
			elseif iWon then
				self.buttons[#self.buttons + 1] = Button.new({
					x = cx - 420, y = 600, w = 380, h = 80, label = "ไปก่อน (Go First)", style = "primary",
					onClick = function() self:pickFirstOrSecond(true) end,
				})
				self.buttons[#self.buttons + 1] = Button.new({
					x = cx + 40, y = 600, w = 380, h = 80, label = "ไปทีหลัง (Go Second)",
					onClick = function() self:pickFirstOrSecond(false) end,
				})
			elseif self.mode == "vsai" then
				self.buttons[#self.buttons + 1] = Button.new({
					x = cx - 200, y = 600, w = 400, h = 70, label = "ดำเนินการต่อ ▶", style = "primary",
					onClick = function() self:proceedToGame(self.aiGoFirst and 2 or 1) end,
				})
			end
		end
	end
end

-- ===================== input =====================

function RPS:update(dt)
	if self.net then self.net:update() end
	local mx, my = love.mouse.getPosition()
	mx, my = Manager.toVirtual(mx, my)
	for _, b in ipairs(self.buttons) do b:update(mx, my) end
end

function RPS:mousepressed(x, y, btn)
	if btn ~= 1 then return end
	if self.mode == "hotseat" then
		if self.stage == "p1ready" then self.stage = "p1choose"; self:rebuildButtons(); return end
		if self.stage == "p2ready" then self.stage = "p2choose"; self:rebuildButtons(); return end
	end
	for _, b in ipairs(self.buttons) do
		if b:mousepressed(x, y, btn) then return end
	end
end

-- ===================== draw =====================

function RPS:draw()
	love.graphics.setColor(Theme.color.bg)
	love.graphics.rectangle("fill", 0, 0, Manager.VW, Manager.VH)

	love.graphics.setFont(Theme.fonts.heading)
	Theme.setColor(Theme.color.accent2)
	love.graphics.printf("เป่ายิ้งฉุบหาสัญญาณ 5G - ใครชนะได้เลือกไปก่อนหรือหลัง", 0, 60, Manager.VW, "center")

	if self.mode == "hotseat" then
		if self.stage == "p1ready" or self.stage == "p2ready" then
			local who = self.stage == "p1ready" and "ผู้เล่น 1" or "ผู้เล่น 2"
			love.graphics.setFont(Theme.fonts.title)
			Theme.setColor(Theme.color.text)
			love.graphics.printf("ส่งจอให้ " .. who, 0, Manager.VH / 2 - 60, Manager.VW, "center")
			love.graphics.setFont(Theme.fonts.body)
			Theme.setColor(Theme.color.textDim)
			love.graphics.printf("แตะหน้าจอเพื่อเลือก", 0, Manager.VH / 2, Manager.VW, "center")
			return
		end
		if self.stage == "p1choose" or self.stage == "p2choose" then
			local who = self.stage == "p1choose" and "ผู้เล่น 1" or "ผู้เล่น 2"
			love.graphics.setFont(Theme.fonts.heading)
			Theme.setColor(Theme.color.text)
			love.graphics.printf(who .. " เลือก:", 0, 380, Manager.VW, "center")
		end
	elseif self.stage == "choose" then
		love.graphics.setFont(Theme.fonts.heading)
		Theme.setColor(Theme.color.text)
		love.graphics.printf("เลือกของคุณ:", 0, 380, Manager.VW, "center")
	elseif self.stage == "waiting" then
		love.graphics.setFont(Theme.fonts.heading)
		Theme.setColor(Theme.color.textDim)
		love.graphics.printf("รอคู่ต่อสู้เลือก...", 0, 450, Manager.VW, "center")
	elseif self.stage == "waitingStart" then
		love.graphics.setFont(Theme.fonts.heading)
		Theme.setColor(Theme.color.textDim)
		love.graphics.printf("กำลังเริ่มเกม...", 0, 450, Manager.VW, "center")
	end

	if self.stage == "reveal" and self.result then
		love.graphics.setFont(Theme.fonts.title)
		local mine = LABEL[self.result.mine] or "?"
		local theirs = LABEL[self.result.theirs] or "?"
		if self.mode == "hotseat" then
			Theme.setColor(Theme.color.text)
			love.graphics.printf(string.format("ผู้เล่น 1: %s        ผู้เล่น 2: %s", mine, theirs), 0, 380, Manager.VW, "center")
		else
			Theme.setColor(Theme.color.text)
			love.graphics.printf(string.format("คุณ: %s        คู่ต่อสู้: %s", mine, theirs), 0, 380, Manager.VW, "center")
		end
		love.graphics.setFont(Theme.fonts.heading)
		if self.result.tie then
			Theme.setColor(Theme.color.textDim)
			love.graphics.printf("เสมอ!", 0, 470, Manager.VW, "center")
		else
			Theme.setColor(Theme.color.good)
			local text
			if self.mode == "hotseat" then
				text = string.format("ผู้เล่น %d ชนะ! เลือกว่าจะไปก่อนหรือหลัง:", self.result.winnerSeat)
			elseif self.mode == "vsai" then
				text = (self.result.winnerSeat == 1) and "คุณชนะ! เลือกว่าจะไปก่อนหรือหลัง:" or ("AI ชนะ และเลือก: " .. (self.aiGoFirst and "ไปก่อน" or "ไปทีหลัง"))
			else
				local iWon = (self.result.winnerSeat == self.opts.mySeat)
				text = iWon and "คุณชนะ! เลือกว่าจะไปก่อนหรือหลัง:" or "คู่ต่อสู้ชนะ และกำลังเลือก..."
			end
			love.graphics.printf(text, 0, 470, Manager.VW, "center")
		end
	end

	for _, b in ipairs(self.buttons) do b:draw() end
end

return RPS
