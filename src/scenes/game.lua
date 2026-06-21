-- src/scenes/game.lua
local Theme = require("src.ui.theme")
local Button = require("src.ui.button")
local Board = require("src.ui.board")
local Log = require("src.ui.log")
local Manager = require("src.scenes.manager")
local Match = require("src.engine.match")
local AI = require("src.engine.ai")
local Decks = require("src.decks")
local Cards = require("src.cards")
local costcalc = require("src.engine.costcalc")
local protocol = require("src.net.protocol")
local flux = require("libs.flux")

local Game = {}

local SB_X = 1330
local SB_W = 250

local PHASE_LABEL = { draw = "จั่วการ์ด", main = "หลัก (Main)", attack = "โจมตี (Attack)", ["end"] = "จบเทิร์น (End)" }

local function pointIn(x, y, r)
	return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function Game:enter(opts)
	self.mode = opts.mode
	self.toast = nil
	self.selection = { mode = "idle" }
	self.pending = nil
	self.pendingReveal = false
	self.lastViewSeat = nil
	self.buttons = {}
	self.view = nil
	self.layout = nil
	self.net = nil
	self.match = nil
	self.ai = nil
	self.cardAnim = {}
	self.hoverAnim = {}
	self.hoverUid = nil
	self.prevVisibleUids = nil

	if self.mode == "hotseat" then
		local d1, d2 = Decks.byId[opts.deckId1], Decks.byId[opts.deckId2]
		self.match = Match.new({
			decklist1 = d1.main, life1 = d1.life, name1 = "ผู้เล่น 1",
			decklist2 = d2.main, life2 = d2.life, name2 = "ผู้เล่น 2",
			firstPlayer = opts.firstPlayer or 1,
		})
	elseif self.mode == "vsai" then
		local d1, d2 = Decks.byId[opts.deckId1], Decks.byId[opts.deckId2]
		self.match = Match.new({
			decklist1 = d1.main, life1 = d1.life, name1 = "คุณ",
			decklist2 = d2.main, life2 = d2.life, name2 = "AI บอท",
			firstPlayer = opts.firstPlayer or 1,
		})
		self.ai = AI.new(self.match, 2)
		self.mySeatFixed = 1
	elseif self.mode == "host" then
		local d1, d2 = Decks.byId[opts.deckId1], Decks.byId[opts.deckId2]
		self.match = Match.new({
			decklist1 = d1.main, life1 = d1.life, name1 = opts.name1 or "Host",
			decklist2 = d2.main, life2 = d2.life, name2 = opts.name2 or "Player 2",
			firstPlayer = opts.firstPlayer or 1,
		})
		self.net = opts.net
		self.mySeatFixed = 1
		self.net.onMessage = function(msg) self:onHostMessage(msg) end
		self.net.onDisconnect = function() self.toast = { text = "ผู้เล่นอีกฝ่ายตัดการเชื่อมต่อ", timer = 6 } end
		self.net:send({ t = protocol.START })
	elseif self.mode == "client" then
		self.net = opts.net
		self.mySeatFixed = opts.mySeat or 2
		self.net.onMessage = function(msg) self:onClientMessage(msg) end
		self.net.onDisconnect = function() self.toast = { text = "หลุดการเชื่อมต่อกับโฮสต์", timer = 6 } end
		if opts.initialView then
			self:applyView(opts.initialView, self.mySeatFixed)
		end
	end

	if self.match then
		self:runAIIfNeeded()
		self:refreshView()
	end
	if self.mode == "client" then self:rebuildButtons() end
end

function Game:leave()
	if self.net then self.net:close() end
end

-- ===================== seat / view helpers =====================

function Game:viewSeat()
	if self.mode == "hotseat" then
		if self.match.reactionWindow then return self.match.reactionWindow.forPlayer end
		return self.match.activePlayerIndex
	end
	return self.mySeatFixed
end

function Game:oppSeat()
	return (self:viewSeat() == 1) and 2 or 1
end

function Game:canAct()
	if not self.view or self.view.gameOver then return false end
	local seat = self:viewSeat()
	if self.view.reactionWindow then return self.view.reactionWindow.forPlayer == seat end
	return self.view.activePlayerIndex == seat
end

function Game:collectVisibleUids(view, seat)
	local set = {}
	local mine = view.players[seat]
	for _, c in ipairs(mine.hand) do set[c.uid] = true end
	for pIdx = 1, 2 do
		local p = view.players[pIdx]
		for _, a in ipairs(p.avatars) do set[a.uid] = true end
		for _, c in ipairs(p.constructs) do set[c.uid] = true end
	end
	if view.land then set[view.land.uid] = true end
	return set
end

-- plays a small "fly in and settle" tween for any card uid that just became
-- visible (newly drawn into hand, newly summoned, newly built, etc.)
function Game:triggerEntranceAnimations(newSet)
	local prev = self.prevVisibleUids
	if prev then
		for uid in pairs(newSet) do
			if not prev[uid] then
				local a = { x = 70, y = -36, scale = 0.55 }
				self.cardAnim[uid] = a
				flux.to(a, 0.32, { x = 0, y = 0, scale = 1 }):ease("backout")
			end
		end
	end
	self.prevVisibleUids = newSet
end

function Game:applyView(view, seat)
	self.view = view
	self.layout = Board.computeLayout(view, seat)
	self:triggerEntranceAnimations(self:collectVisibleUids(view, seat))
end

function Game:refreshView()
	local seat = self:viewSeat()
	self:applyView(self.match:serialize(seat), seat)
	self:rebuildButtons()
end

function Game:toast2(text)
	self.toast = { text = text, timer = 2.2 }
end

-- ===================== network message handling =====================

function Game:onHostMessage(msg)
	if msg.t == protocol.ACTION then
		local ok, err = self.match:applyAction(2, msg.action)
		if ok then
			self:afterLocalChange()
		else
			self.net:send({ t = protocol.ERROR, message = err })
		end
	end
end

function Game:onClientMessage(msg)
	if msg.t == protocol.STATE then
		self:applyView(msg.view, self.mySeatFixed)
		self.selection = { mode = "idle" }
		self.pending = nil
		self:rebuildButtons()
	elseif msg.t == protocol.ERROR then
		self:toast2(msg.message or "การกระทำไม่ถูกต้อง")
		self.selection = { mode = "idle" }
		self.pending = nil
		self:rebuildButtons()
	end
end

-- after the LOCAL authoritative match changes (hotseat/vsai/host)
function Game:afterLocalChange()
	self.selection = { mode = "idle" }
	self.pending = nil
	self:runAIIfNeeded()
	if self.mode == "host" and self.net then
		self.net:send({ t = protocol.STATE, view = self.match:serialize(2) })
	end
	self:refreshView()
end

function Game:runAIIfNeeded()
	if self.mode ~= "vsai" then return end
	local guard = 0
	while not self.match.gameOver and guard < 60 do
		guard = guard + 1
		local seatTurn = self.match.reactionWindow and self.match.reactionWindow.forPlayer or self.match.activePlayerIndex
		if seatTurn == 2 then self.ai:step() else break end
	end
end

-- ===================== submitting actions =====================

function Game:submitAction(action)
	if self.mode == "client" then
		self.net:send({ t = protocol.ACTION, action = action })
		self.selection = { mode = "idle" }
		self.pending = nil
		self:rebuildButtons()
	else
		local actingSeat = (self.mode == "hotseat") and self:viewSeat() or 1
		local ok, err = self.match:applyAction(actingSeat, action)
		if ok then
			self:afterLocalChange()
		else
			self:toast2(err or "ทำไม่ได้")
		end
	end
end

-- ===================== input =====================

function Game:update(dt)
	flux.update(dt)
	if self.net then self.net:update() end
	if self.toast then
		self.toast.timer = self.toast.timer - dt
		if self.toast.timer <= 0 then self.toast = nil end
	end
	if self.mode == "hotseat" and self.match and not self.match.gameOver then
		local seat = self:viewSeat()
		if seat ~= self.lastViewSeat then
			self.lastViewSeat = seat
			self.pendingReveal = true
			self:refreshView()
		end
	end
	local mx, my = love.mouse.getPosition()
	mx, my = Manager.toVirtual(mx, my)
	for _, b in ipairs(self.buttons) do b:update(mx, my) end
	self:updateHover(mx, my)
end

function Game:updateHover(mx, my)
	local newUid = nil
	if self.layout and not self.pendingReveal then
		for _, slot in ipairs(self.layout.hand) do
			if mx >= slot.x and mx <= slot.x + slot.w and my >= slot.y and my <= slot.y + slot.h then
				newUid = slot.card.uid
				break
			end
		end
	end
	if newUid ~= self.hoverUid then
		if self.hoverUid and self.hoverAnim[self.hoverUid] then
			flux.to(self.hoverAnim[self.hoverUid], 0.15, { lift = 0 }):ease("quadout")
		end
		if newUid then
			self.hoverAnim[newUid] = self.hoverAnim[newUid] or { lift = 0 }
			flux.to(self.hoverAnim[newUid], 0.15, { lift = 1 }):ease("quadout")
		end
		self.hoverUid = newUid
	end
end

function Game:mousepressed(x, y, btn)
	if btn ~= 1 then return end
	if self.pendingReveal then
		self.pendingReveal = false
		self:rebuildButtons()
		return
	end
	for _, b in ipairs(self.buttons) do
		if b:mousepressed(x, y, btn) then return end
	end
	self:onBoardClick(x, y)
end

function Game:onClickHandCardMain(i, cardRef)
	local def = Cards.byId[cardRef.id]
	local mine = self.view.players[self:viewSeat()]

	if def.type == "avatar" then
		if #mine.avatars >= 4 then self:toast2("Avatar Zone เต็ม (สูงสุด 4)"); return end
		local need = costcalc.effectiveCost(mine.constructs, def)
		local combo = costcalc.suggestCost(mine.hand, i, need)
		if not combo then self:toast2(string.format("เจมในมือไม่พอ (ต้องการ %d)", need)); return end
		self:submitAction({ kind = "summon_avatar", handIndex = i, cost = combo })
	elseif def.type == "construct" then
		local need = costcalc.effectiveCost(mine.constructs, def)
		local combo = costcalc.suggestCost(mine.hand, i, need)
		if not combo then self:toast2(string.format("เจมในมือไม่พอ (ต้องการ %d)", need)); return end
		self:submitAction({ kind = "play_construct", handIndex = i, cost = combo })
	elseif def.type == "magic" then
		if def.magicType == "counter" then
			self:toast2("การ์ด Counter ใช้ได้เฉพาะตอนตอบโต้คู่ต่อสู้เท่านั้น")
			return
		end
		local need = costcalc.effectiveCost(mine.constructs, def)
		local combo = costcalc.suggestCost(mine.hand, i, need)
		if not combo then self:toast2(string.format("เจมในมือไม่พอ (ต้องการ %d)", need)); return end
		if def.magicType == "land" then
			self:submitAction({ kind = "cast_magic", handIndex = i, cost = combo })
		elseif def.magicType == "weapon" then
			if #mine.avatars == 0 then
				self:toast2("คุณยังไม่มี Avatar ให้สวมใส่")
			elseif #mine.avatars == 1 then
				self:submitAction({ kind = "cast_magic", handIndex = i, cost = combo, target = mine.avatars[1].uid })
			else
				self.pending = { handIndex = i, cost = combo }
				self.selection = { mode = "pickOwnTarget" }
				self:rebuildButtons()
			end
		elseif def.ability and def.ability.kind == "destroy_avatar" then
			local opp = self.view.players[self:oppSeat()]
			if #opp.avatars == 0 then
				self:toast2("คู่ต่อสู้ยังไม่มี Avatar ให้ทำลาย")
			else
				self.pending = { handIndex = i, cost = combo }
				self.selection = { mode = "pickEnemyTarget" }
				self:rebuildButtons()
			end
		else
			self:submitAction({ kind = "cast_magic", handIndex = i, cost = combo })
		end
	end
end

function Game:confirmPendingWithTarget(uid)
	if not self.pending then return end
	local action = { kind = "cast_magic", handIndex = self.pending.handIndex, cost = self.pending.cost, target = uid }
	self.pending = nil
	self:submitAction(action)
end

function Game:onClickMyAvatarAttack(avatar)
	if avatar.tapped then self:toast2("Avatar ใบนี้โจมตีไปแล้วในเทิร์นนี้"); return end
	local def = Cards.byId[avatar.id]
	local canDirect = def.ability and def.ability.kind == "direct_attack"
	local opp = self.view.players[self:oppSeat()]
	self.selection = {
		mode = "attackerSelected",
		attackerUid = avatar.uid,
		lifeTargetEnabled = (#opp.avatars == 0) or canDirect,
	}
	self:rebuildButtons()
end

function Game:onAscensionClick(avatarUid, activationCost)
	local mine = self.view.players[self:viewSeat()]
	if #mine.graveyard == 0 then self:toast2("นรกของคุณว่างเปล่า"); return end
	local combo = costcalc.suggestCost(mine.hand, nil, activationCost or 0)
	if not combo then self:toast2(string.format("เจมในมือไม่พอ (ต้องการ %d)", activationCost or 0)); return end
	local targetUid = mine.graveyard[#mine.graveyard].uid
	self:submitAction({ kind = "activate_ascension", avatarUid = avatarUid, cost = combo, graveyardUid = targetUid })
end

function Game:onBoardClick(x, y)
	if not self:canAct() then return end
	local sel = self.selection

	if sel.mode == "idle" then
		if self.view.phase == "main" then
			for _, slot in ipairs(self.layout.hand) do
				if pointIn(x, y, slot) then self:onClickHandCardMain(slot.handIndex, slot.card); return end
			end
		elseif self.view.phase == "attack" then
			for _, slot in ipairs(self.layout.myAvatars) do
				if slot.avatar and pointIn(x, y, slot) then self:onClickMyAvatarAttack(slot.avatar); return end
			end
		end
	elseif sel.mode == "pickEnemyTarget" then
		for _, slot in ipairs(self.layout.oppAvatars) do
			if slot.avatar and pointIn(x, y, slot) then self:confirmPendingWithTarget(slot.avatar.uid); return end
		end
	elseif sel.mode == "pickOwnTarget" then
		for _, slot in ipairs(self.layout.myAvatars) do
			if slot.avatar and pointIn(x, y, slot) then self:confirmPendingWithTarget(slot.avatar.uid); return end
		end
	elseif sel.mode == "attackerSelected" then
		for _, slot in ipairs(self.layout.oppAvatars) do
			if slot.avatar and pointIn(x, y, slot) then
				self:submitAction({ kind = "declare_attack", attackerUid = sel.attackerUid, targetType = "avatar", targetUid = slot.avatar.uid })
				return
			end
		end
		if sel.lifeTargetEnabled then
			local r = self.layout.oppLifeBar
			local expanded = { x = r.x - 10, y = r.y - 6, w = r.w + 20, h = r.h + 16 }
			if pointIn(x, y, expanded) then
				self:submitAction({ kind = "declare_attack", attackerUid = sel.attackerUid, targetType = "life" })
				return
			end
		end
		for _, slot in ipairs(self.layout.myAvatars) do
			if slot.avatar and pointIn(x, y, slot) then
				if slot.avatar.uid == sel.attackerUid then
					self.selection = { mode = "idle" }
					self:rebuildButtons()
				else
					self:onClickMyAvatarAttack(slot.avatar)
				end
				return
			end
		end
	end
end

-- ===================== buttons =====================

function Game:rebuildButtons()
	self.buttons = {}
	local Menu = require("src.scenes.menu")
	self.buttons[#self.buttons + 1] = Button.new({
		x = SB_X, y = 800, w = SB_W, h = 50, label = "เมนูหลัก",
		onClick = function() Manager.switch(Menu) end,
	})

	if not self.view then return end

	if self.view.gameOver then
		local seat = self:viewSeat()
		local label = (self.view.winner == seat) and "คุณชนะ! 🎉" or "คุณแพ้"
		if self.mode == "hotseat" then
			label = string.format("%s ชนะ!", self.view.players[self.view.winner].name)
		end
		self.buttons[#self.buttons + 1] = Button.new({
			x = 600, y = 500, w = 400, h = 70, label = "กลับเมนูหลัก", style = "primary",
			onClick = function() Manager.switch(Menu) end,
		})
		return
	end

	if self.pendingReveal then return end

	local seat = self:viewSeat()

	if self.view.reactionWindow and self.view.reactionWindow.forPlayer == seat then
		local mine = self.view.players[seat]
		local yy = 130
		for i, c in ipairs(mine.hand) do
			local def = Cards.byId[c.id]
			if def.type == "magic" and def.magicType == "counter" and def.ability and def.ability.kind == "earth_absorption" then
				local idx = i
				self.buttons[#self.buttons + 1] = Button.new({
					x = SB_X, y = yy, w = SB_W, h = 56, label = "ใช้: " .. def.name, style = "primary",
					font = Theme.fonts.small,
					onClick = function()
						local need = costcalc.effectiveCost(mine.constructs, def)
						local combo = costcalc.suggestCost(mine.hand, idx, need)
						if combo then
							self:submitAction({ kind = "cast_counter", handIndex = idx, cost = combo })
						else
							self:toast2("เจมในมือไม่พอ")
						end
					end,
				})
				yy = yy + 64
			end
		end
		self.buttons[#self.buttons + 1] = Button.new({
			x = SB_X, y = yy + 10, w = SB_W, h = 50, label = "ปล่อยผ่าน",
			onClick = function() self:submitAction({ kind = "pass_reaction" }) end,
		})
		return
	end

	if not self:canAct() then return end

	if self.selection.mode == "pickEnemyTarget" or self.selection.mode == "pickOwnTarget" then
		self.buttons[#self.buttons + 1] = Button.new({
			x = SB_X, y = 130, w = SB_W, h = 50, label = "ยกเลิก", style = "danger",
			onClick = function() self.pending = nil; self.selection = { mode = "idle" }; self:rebuildButtons() end,
		})
		return
	end

	if self.selection.mode == "attackerSelected" then
		self.buttons[#self.buttons + 1] = Button.new({
			x = SB_X, y = 130, w = SB_W, h = 50, label = "ยกเลิกการโจมตี", style = "danger",
			onClick = function() self.selection = { mode = "idle" }; self:rebuildButtons() end,
		})
	end

	if self.view.phase == "main" and self.selection.mode == "idle" then
		local mine = self.view.players[seat]
		for _, slot in ipairs(self.layout.myAvatars) do
			if slot.avatar then
				local def = Cards.byId[slot.avatar.id]
				if def.ability and def.ability.kind == "ascension" then
					local uid = slot.avatar.uid
					local cost = def.ability.activationCost or 0
					self.buttons[#self.buttons + 1] = Button.new({
						x = slot.x, y = slot.y + slot.h + 6, w = slot.w, h = 32, label = "จุติ (" .. cost .. ")",
						font = Theme.fonts.tiny,
						onClick = function() self:onAscensionClick(uid, cost) end,
					})
				end
			end
		end
	end

	if self.selection.mode == "idle" then
		self.buttons[#self.buttons + 1] = Button.new({
			x = SB_X, y = 720, w = SB_W, h = 64, label = "ถัดไป ▶", style = "primary",
			onClick = function() self:submitAction({ kind = "next_phase" }) end,
		})
	end
end

-- ===================== draw =====================

local function drawSidebar(self)
	Theme.rect(SB_X - 10, 0, SB_W + 20, Manager.VH, 0, Theme.color.bgPanel)
	if not self.view then
		love.graphics.setFont(Theme.fonts.body)
		Theme.setColor(Theme.color.text)
		love.graphics.printf("กำลังเชื่อมต่อ...", SB_X, 20, SB_W, "center")
		return
	end
	love.graphics.setFont(Theme.fonts.heading)
	Theme.setColor(Theme.color.accent2)
	love.graphics.printf("เทิร์นที่ " .. self.view.turnNumber, SB_X, 10, SB_W, "left")
	love.graphics.setFont(Theme.fonts.label)
	Theme.setColor(Theme.color.text)
	love.graphics.printf("เฟส: " .. (PHASE_LABEL[self.view.phase] or self.view.phase), SB_X, 48, SB_W, "left")
	local activeName = self.view.players[self.view.activePlayerIndex].name
	love.graphics.setFont(Theme.fonts.small)
	Theme.setColor(Theme.color.textDim)
	love.graphics.printf("ตา: " .. activeName, SB_X, 76, SB_W, "left")

	if self.view.reactionWindow and self.view.reactionWindow.forPlayer == self:viewSeat() then
		love.graphics.setFont(Theme.fonts.small)
		Theme.setColor(Theme.color.bad)
		love.graphics.printf("คู่ต่อสู้อัญเชิญ Avatar! คุณมี Counter หรือไม่?", SB_X, 100, SB_W, "left")
	elseif self.selection.mode == "pickEnemyTarget" then
		love.graphics.setFont(Theme.fonts.small)
		Theme.setColor(Theme.color.good)
		love.graphics.printf("เลือก Avatar ของคู่ต่อสู้เป็นเป้าหมาย", SB_X, 100, SB_W, "left")
	elseif self.selection.mode == "pickOwnTarget" then
		love.graphics.setFont(Theme.fonts.small)
		Theme.setColor(Theme.color.good)
		love.graphics.printf("เลือก Avatar ของคุณเพื่อสวมใส่", SB_X, 100, SB_W, "left")
	elseif self.selection.mode == "attackerSelected" then
		love.graphics.setFont(Theme.fonts.small)
		Theme.setColor(Theme.color.good)
		love.graphics.printf("เลือกเป้าหมายที่จะโจมตี (หรือกดที่ Avatar เดิมเพื่อยกเลิก)", SB_X, 100, SB_W, "left")
	end

	Log.draw(SB_X, 420, SB_W, 280, self.view.eventLog)
end

function Game:draw()
	love.graphics.setColor(Theme.color.bg)
	love.graphics.rectangle("fill", 0, 0, Manager.VW, Manager.VH)

	if self.view then
		local sel = self.selection
		local highlightUids = {}
		if sel.mode == "pickEnemyTarget" then
			for _, a in ipairs(self.view.players[self:oppSeat()].avatars) do highlightUids[a.uid] = true end
		elseif sel.mode == "pickOwnTarget" then
			for _, a in ipairs(self.view.players[self:viewSeat()].avatars) do highlightUids[a.uid] = true end
		elseif sel.mode == "attackerSelected" then
			for _, a in ipairs(self.view.players[self:oppSeat()].avatars) do highlightUids[a.uid] = true end
		end
		Board.draw(self.view, self:viewSeat(), self.layout, {
			attackerUid = sel.attackerUid,
			highlightUids = highlightUids,
			lifeTargetEnabled = sel.mode == "attackerSelected" and sel.lifeTargetEnabled,
		}, { anim = self.cardAnim, hoverAnim = self.hoverAnim })
	end

	drawSidebar(self)

	if self.pendingReveal then
		love.graphics.setColor(0.03, 0.03, 0.05, 0.96)
		love.graphics.rectangle("fill", 0, 0, Manager.VW, Manager.VH)
		love.graphics.setFont(Theme.fonts.heading)
		Theme.setColor(Theme.color.text)
		local name = self.view and self.view.players[self:viewSeat()].name or ""
		love.graphics.printf("ส่งจอให้ " .. name, 0, Manager.VH / 2 - 60, Manager.VW, "center")
		love.graphics.setFont(Theme.fonts.body)
		Theme.setColor(Theme.color.textDim)
		love.graphics.printf("แตะหน้าจอเพื่อดูมือของคุณ", 0, Manager.VH / 2, Manager.VW, "center")
	end

	if self.toast then
		love.graphics.setFont(Theme.fonts.body)
		local w = 600
		Theme.rect(Manager.VW / 2 - w / 2, Manager.VH - 80, w, 50, 8, { 0.05, 0.05, 0.06, 0.9 })
		Theme.setColor(Theme.color.bad)
		love.graphics.printf(self.toast.text, Manager.VW / 2 - w / 2, Manager.VH - 67, w, "center")
	end

	for _, b in ipairs(self.buttons) do b:draw() end
end

return Game

