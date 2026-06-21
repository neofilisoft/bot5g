-- src/engine/match.lua
local class = require("src.class")
local C = require("src.constants")
local Deck = require("src.deck")
local Player = require("src.engine.player")
local CardInstance = require("src.engine.cardinstance")

local Match = class()

-- ===================== setup =====================

function Match:init(opts)
	opts = opts or {}
	self.rng = opts.rng or math.random
	self.players = { Player.new(1, opts.name1), Player.new(2, opts.name2) }
	self.turnNumber = 0
	self.activePlayerIndex = opts.firstPlayer or 1
	self.phase = C.Phase.MAIN
	self.land = nil -- shared Land Magic Zone (single CardInstance or nil)
	self.reactionWindow = nil
	self.gameOver = false
	self.winner = nil
	self.eventLog = {}

	self:setupPlayer(1, opts.decklist1, opts.life1)
	self:setupPlayer(2, opts.decklist2, opts.life2)

	self:beginTurn(self.activePlayerIndex, true)
end

function Match:setupPlayer(idx, decklist, lifeIds)
	local p = self.players[idx]
	local mainDefs, lifeDefs = Deck.build(decklist, lifeIds)
	local mainInstances = {}
	for _, def in ipairs(mainDefs) do
		mainInstances[#mainInstances + 1] = CardInstance.new(def, idx)
	end
	Deck.shuffle(mainInstances, self.rng)
	p.deck = mainInstances
	for _, def in ipairs(lifeDefs) do
		p.life[#p.life + 1] = CardInstance.new(def, idx)
	end
	for _ = 1, C.STARTING_HAND do
		local c = table.remove(p.deck)
		if c then p.hand[#p.hand + 1] = c end
	end
end

function Match:log(fmt, ...)
	local msg = string.format(fmt, ...)
	self.eventLog[#self.eventLog + 1] = msg
	if #self.eventLog > 80 then table.remove(self.eventLog, 1) end
end

function Match:player(idx) return self.players[idx] end
function Match:activePlayer() return self.players[self.activePlayerIndex] end
function Match:opponentIndex(idx) idx = idx or self.activePlayerIndex; return (idx == 1) and 2 or 1 end
function Match:opponentOf(idx) return self.players[self:opponentIndex(idx)] end

-- ===================== turn flow =====================

function Match:beginTurn(idx, isVeryFirstTurn)
	self.activePlayerIndex = idx
	self.turnNumber = self.turnNumber + 1
	local p = self.players[idx]
	for _, a in ipairs(p.avatars) do
		a.tapped = false
		a.usedAbilityThisTurn = false
	end
	self.phase = C.Phase.DRAW
	-- The very first turn of the whole game: no draw (starting hand stands).
	if not (isVeryFirstTurn and self.turnNumber == 1) then
		self:drawStep(p)
	end
	if not self.gameOver then
		self.phase = C.Phase.MAIN
		self:log("เทิร์นที่ %d: ถึงตา %s", self.turnNumber, p.name)
	end
end

function Match:drawStep(p)
	self:drawN(p, 1)
	if self.gameOver then return end
	for _, construct in ipairs(p.constructs) do
		local ab = construct.def.ability
		if ab and ab.kind == "construct_extra_draw" then
			self:drawN(p, ab.n or 1)
			if self.gameOver then return end
		end
	end
end

function Match:drawN(p, n)
	for _ = 1, n do
		if #p.deck == 0 then
			self.gameOver = true
			self.winner = self:opponentIndex(p.index)
			self:log("%s กองจั่วหมด! %s ชนะ", p.name, self.players[self.winner].name)
			return
		end
		local c = table.remove(p.deck)
		p.hand[#p.hand + 1] = c
	end
end

-- next_phase: only callable by the active player, and only when no reaction
-- window is open.
function Match:nextPhase(byPlayer)
	if self.gameOver then return false, "เกมจบแล้ว" end
	if self.reactionWindow then return false, "ต้องจัดการ Counter ก่อน" end
	if byPlayer ~= self.activePlayerIndex then return false, "ไม่ใช่ตาคุณ" end

	if self.phase == C.Phase.MAIN then
		self.phase = C.Phase.ATTACK
	elseif self.phase == C.Phase.ATTACK then
		self.phase = C.Phase.END
	elseif self.phase == C.Phase.END then
		self:log("จบเทิร์นของ %s", self:activePlayer().name)
		self:beginTurn(self:opponentIndex(self.activePlayerIndex), false)
	else
		return false, "phase ผิดพลาด"
	end
	return true
end

-- ===================== helpers =====================

local function findInHand(p, idx)
	return p.hand[idx]
end

-- Remove several hand indexes at once (must be a set of distinct valid indexes).
local function removeHandIndexes(p, indexes)
	local sorted = {}
	for _, i in ipairs(indexes) do sorted[#sorted + 1] = i end
	table.sort(sorted, function(a, b) return a > b end)
	local removed = {}
	for _, i in ipairs(sorted) do
		removed[#removed + 1] = table.remove(p.hand, i)
	end
	return removed
end

local function sumGem(cards)
	local s = 0
	for _, c in ipairs(cards) do s = s + (c.def.gem or 0) end
	return s
end

-- Greedy helper: pick hand indexes (excluding `exclude`) whose gem sums to
-- at least `need`. Used by the "auto pay" UI button and by the AI.
function Match:suggestCost(p, exclude, need)
	if need <= 0 then return {} end
	local candidates = {}
	for i, c in ipairs(p.hand) do
		if i ~= exclude then candidates[#candidates + 1] = { i = i, gem = c.def.gem or 0 } end
	end
	table.sort(candidates, function(a, b) return a.gem > b.gem end)
	local chosen, sum = {}, 0
	for _, cand in ipairs(candidates) do
		if sum >= need then break end
		chosen[#chosen + 1] = cand.i
		sum = sum + cand.gem
	end
	if sum < need then return nil end
	return chosen
end

function Match:costReduction(p, tribe)
	local r = 0
	for _, construct in ipairs(p.constructs) do
		local ab = construct.def.ability
		if ab and ab.kind == "construct_cost_reduction" and ab.tribe == tribe then
			r = r + (ab.amount or 0)
		end
	end
	return r
end

function Match:effectiveCost(p, def)
	local base = def.cost or 0
	if def.type == C.CardType.AVATAR then
		base = base - self:costReduction(p, def.tribe)
	end
	if base < 0 then base = 0 end
	return base
end

-- Power of an avatar instance including weapons, tribe buffs, mob bonuses,
-- and the shared Land Magic effect.
function Match:computePower(owner, avatar)
	local p = avatar:currentPower()
	local mine = self.players[owner]
	for _, ally in ipairs(mine.avatars) do
		local ab = ally.def.ability
		if ab and ab.kind == "buff_tribe" and ab.tribe == avatar.def.tribe then
			p = p + (ab.power or 0)
		end
	end
	if avatar.def.ability and avatar.def.ability.kind == "mob" then
		local count = 0
		for _, ally in ipairs(mine.avatars) do
			if ally.uid ~= avatar.uid and ally.def.tribe == avatar.def.ability.tribe then
				count = count + 1
			end
		end
		p = p + count * (avatar.def.ability.power or 0)
	end
	if self.land and self.land.def.ability and self.land.def.ability.kind == "land_buff"
		and self.land.def.ability.tribe == avatar.def.tribe then
		p = p + (self.land.def.ability.power or 0)
	end
	return p
end

local function moveAvatarToGraveyard(self, ownerIdx, avatar)
	local p = self.players[ownerIdx]
	for _, w in ipairs(avatar.weapons) do
		p.graveyard[#p.graveyard + 1] = w
	end
	avatar.weapons = {}
	p.graveyard[#p.graveyard + 1] = avatar
end

function Match:destroyAvatar(ownerIdx, uid)
	local p = self.players[ownerIdx]
	local _, idx = p:findAvatar(uid)
	if not idx then return false end
	local avatar = table.remove(p.avatars, idx)
	moveAvatarToGraveyard(self, ownerIdx, avatar)
	return true
end

function Match:discardRandom(p, n)
	local names = {}
	for _ = 1, n do
		if #p.hand == 0 then break end
		local i = math.floor(self.rng() * #p.hand) + 1
		local c = table.remove(p.hand, i)
		names[#names + 1] = c.def.name
		p.graveyard[#p.graveyard + 1] = c
	end
	return names
end

-- ===================== main-phase actions =====================

function Match:summonAvatar(byPlayer, handIndex, costHandIndexes)
	if self.gameOver then return false, "เกมจบแล้ว" end
	if self.reactionWindow then return false, "ต้องจัดการ Counter ก่อน" end
	if byPlayer ~= self.activePlayerIndex or self.phase ~= C.Phase.MAIN then
		return false, "ทำได้เฉพาะ Main Phase ในตาคุณ"
	end
	local p = self:activePlayer()
	local card = findInHand(p, handIndex)
	if not card or card.def.type ~= C.CardType.AVATAR then return false, "การ์ดไม่ถูกต้อง" end
	if not p:hasOpenAvatarSlot() then return false, "Avatar Zone เต็ม (สูงสุด 4)" end
	for _, i in ipairs(costHandIndexes) do
		if i == handIndex then return false, "ใช้การ์ดที่จะอัญเชิญเป็นค่าคอร์สไม่ได้" end
	end
	local costCards = {}
	for _, i in ipairs(costHandIndexes) do
		local cc = p.hand[i]
		if not cc then return false, "ดัชนีการ์ดค่าคอร์สไม่ถูกต้อง" end
		costCards[#costCards + 1] = cc
	end
	local need = self:effectiveCost(p, card.def)
	if sumGem(costCards) < need then return false, string.format("เจมไม่พอ (ต้องการ %d)", need) end

	local allIdx = { handIndex }
	for _, i in ipairs(costHandIndexes) do allIdx[#allIdx + 1] = i end
	local removed = removeHandIndexes(p, allIdx)
	local avatarCard
	for _, c in ipairs(removed) do
		if c.uid == card.uid then avatarCard = c else p.graveyard[#p.graveyard + 1] = c end
	end

	avatarCard.summonTurn = self.turnNumber
	avatarCard.tapped = false
	p.avatars[#p.avatars + 1] = avatarCard
	self:log("%s อัญเชิญ %s", p.name, avatarCard.def.name)

	local ab = avatarCard.def.ability
	if ab and ab.trigger == "on_play" then
		self:resolveOnPlay(p, ab)
	end

	-- open a reaction window for the opponent (earth_absorption counters)
	self.reactionWindow = { forPlayer = self:opponentIndex(byPlayer), kind = "post_summon", avatarUid = avatarCard.uid, avatarOwner = byPlayer }
	return true
end

function Match:resolveOnPlay(p, ab)
	if ab.kind == "draw" then
		self:drawN(p, ab.n or 1)
	elseif ab.kind == "disruption_discard" then
		local opp = self:opponentOf(p.index)
		local names = self:discardRandom(opp, ab.n or 1)
		if #names > 0 then
			self:log("%s ถูกบังคับทิ้ง: %s", opp.name, table.concat(names, ", "))
		end
	end
end

function Match:playConstruct(byPlayer, handIndex, costHandIndexes)
	if self.gameOver then return false, "เกมจบแล้ว" end
	if self.reactionWindow then return false, "ต้องจัดการ Counter ก่อน" end
	if byPlayer ~= self.activePlayerIndex or self.phase ~= C.Phase.MAIN then
		return false, "ทำได้เฉพาะ Main Phase ในตาคุณ"
	end
	local p = self:activePlayer()
	local card = findInHand(p, handIndex)
	if not card or card.def.type ~= C.CardType.CONSTRUCT then return false, "การ์ดไม่ถูกต้อง" end
	for _, i in ipairs(costHandIndexes) do
		if i == handIndex then return false, "ใช้การ์ดที่จะสร้างเป็นค่าคอร์สไม่ได้" end
	end
	local costCards = {}
	for _, i in ipairs(costHandIndexes) do
		local cc = p.hand[i]
		if not cc then return false, "ดัชนีการ์ดค่าคอร์สไม่ถูกต้อง" end
		costCards[#costCards + 1] = cc
	end
	local need = self:effectiveCost(p, card.def)
	if sumGem(costCards) < need then return false, string.format("เจมไม่พอ (ต้องการ %d)", need) end

	local allIdx = { handIndex }
	for _, i in ipairs(costHandIndexes) do allIdx[#allIdx + 1] = i end
	local removed = removeHandIndexes(p, allIdx)
	local theCard
	for _, c in ipairs(removed) do
		if c.uid == card.uid then theCard = c else p.graveyard[#p.graveyard + 1] = c end
	end
	p.constructs[#p.constructs + 1] = theCard
	self:log("%s สร้าง %s", p.name, theCard.def.name)
	return true
end

-- targetAvatarUid: required for WEAPON (own avatar) and for destroy_avatar NORMAL magic (enemy avatar)
function Match:castMagic(byPlayer, handIndex, costHandIndexes, targetAvatarUid)
	if self.gameOver then return false, "เกมจบแล้ว" end
	if self.reactionWindow then return false, "ต้องจัดการ Counter ก่อน" end
	if byPlayer ~= self.activePlayerIndex or self.phase ~= C.Phase.MAIN then
		return false, "ทำได้เฉพาะ Main Phase ในตาคุณ"
	end
	local p = self:activePlayer()
	local card = findInHand(p, handIndex)
	if not card or card.def.type ~= C.CardType.MAGIC then return false, "การ์ดไม่ถูกต้อง" end
	if card.def.magicType == C.MagicType.COUNTER then
		return false, "การ์ด Counter ใช้ได้เฉพาะตอนตอบโต้เท่านั้น"
	end
	for _, i in ipairs(costHandIndexes) do
		if i == handIndex then return false, "ใช้การ์ดที่จะร่ายเป็นค่าคอร์สไม่ได้" end
	end
	local costCards = {}
	for _, i in ipairs(costHandIndexes) do
		local cc = p.hand[i]
		if not cc then return false, "ดัชนีการ์ดค่าคอร์สไม่ถูกต้อง" end
		costCards[#costCards + 1] = cc
	end
	local need = self:effectiveCost(p, card.def)
	if sumGem(costCards) < need then return false, string.format("เจมไม่พอ (ต้องการ %d)", need) end

	-- pre-validate target before spending the cards
	local ab = card.def.ability
	local opp = self:opponentOf(byPlayer)
	if card.def.magicType == C.MagicType.WEAPON then
		if not targetAvatarUid then return false, "ต้องเลือก Avatar ของคุณเพื่อสวมใส่" end
		local avatar = select(1, p:findAvatar(targetAvatarUid))
		if not avatar then return false, "ไม่พบ Avatar เป้าหมาย" end
	elseif ab and ab.kind == "destroy_avatar" then
		if not targetAvatarUid then return false, "ต้องเลือก Avatar ของคู่ต่อสู้เป็นเป้าหมาย" end
		local avatar = select(1, opp:findAvatar(targetAvatarUid))
		if not avatar then return false, "ไม่พบ Avatar เป้าหมาย" end
		if self:computePower(opp.index, avatar) > (ab.maxPower or 0) then
			return false, "พลังโจมตีเป้าหมายสูงเกินไป"
		end
	end

	local allIdx = { handIndex }
	for _, i in ipairs(costHandIndexes) do allIdx[#allIdx + 1] = i end
	local removed = removeHandIndexes(p, allIdx)
	local theCard
	for _, c in ipairs(removed) do
		if c.uid == card.uid then theCard = c else p.graveyard[#p.graveyard + 1] = c end
	end

	if card.def.magicType == C.MagicType.LAND then
		if self.land then
			local prevOwner = self.players[self.land.owner]
			prevOwner.graveyard[#prevOwner.graveyard + 1] = self.land
		end
		self.land = theCard
		self:log("%s ร่ายเวทย์สนาม %s", p.name, theCard.def.name)
	elseif card.def.magicType == C.MagicType.WEAPON then
		local avatar = select(1, p:findAvatar(targetAvatarUid))
		avatar.weapons[#avatar.weapons + 1] = theCard
		self:log("%s สวมใส่ %s ให้กับ %s", p.name, theCard.def.name, avatar.def.name)
	else -- NORMAL
		self:log("%s ใช้ %s", p.name, theCard.def.name)
		if ab then
			if ab.kind == "draw" then
				self:drawN(p, ab.n or 1)
			elseif ab.kind == "disruption_discard" then
				local names = self:discardRandom(opp, ab.n or 1)
				if #names > 0 then self:log("%s ถูกบังคับทิ้ง: %s", opp.name, table.concat(names, ", ")) end
			elseif ab.kind == "destroy_avatar" then
				local avatar = select(1, opp:findAvatar(targetAvatarUid))
				self:log("%s ถูกทำลาย", avatar.def.name)
				self:destroyAvatar(opp.index, targetAvatarUid)
			end
		end
		p.graveyard[#p.graveyard + 1] = theCard
	end
	return true
end

-- "ascension": pay `ability.activationCost` gem from hand, return a card
-- from the graveyard back into the deck (then shuffle).
function Match:activateAscension(byPlayer, avatarUid, costHandIndexes, graveyardUid)
	if self.gameOver then return false, "เกมจบแล้ว" end
	if self.reactionWindow then return false, "ต้องจัดการ Counter ก่อน" end
	if byPlayer ~= self.activePlayerIndex or self.phase ~= C.Phase.MAIN then
		return false, "ทำได้เฉพาะ Main Phase ในตาคุณ"
	end
	local p = self:activePlayer()
	local avatar = select(1, p:findAvatar(avatarUid))
	if not avatar then return false, "ไม่พบ Avatar" end
	local ab = avatar.def.ability
	if not ab or ab.kind ~= "ascension" then return false, "Avatar นี้ไม่มีความสามารถจุติ" end
	if avatar.usedAbilityThisTurn then return false, "ใช้ความสามารถนี้ไปแล้วในเทิร์นนี้" end
	local gIdx
	for i, g in ipairs(p.graveyard) do
		if g.uid == graveyardUid then gIdx = i break end
	end
	if not gIdx then return false, "ไม่พบการ์ดเป้าหมายในนรก" end

	local costCards = {}
	for _, i in ipairs(costHandIndexes) do
		local cc = p.hand[i]
		if not cc then return false, "ดัชนีการ์ดค่าใช้จ่ายไม่ถูกต้อง" end
		costCards[#costCards + 1] = cc
	end
	if sumGem(costCards) < (ab.activationCost or 0) then
		return false, string.format("เจมไม่พอ (ต้องการ %d)", ab.activationCost or 0)
	end
	local discarded = removeHandIndexes(p, costHandIndexes)
	for _, c in ipairs(discarded) do
		p.graveyard[#p.graveyard + 1] = c
	end

	local revived = table.remove(p.graveyard, gIdx)
	table.insert(p.deck, math.floor(self.rng() * (#p.deck + 1)) + 1, revived)
	Deck.shuffle(p.deck, self.rng)
	avatar.usedAbilityThisTurn = true
	self:log("%s จุติ: นำ %s กลับเข้ากองจั่ว", p.name, revived.def.name)
	return true
end

-- ===================== reaction window (Counter Magic) =====================

function Match:castCounter(byPlayer, handIndex, costHandIndexes)
	if self.gameOver then return false, "เกมจบแล้ว" end
	if not self.reactionWindow or self.reactionWindow.forPlayer ~= byPlayer then
		return false, "ไม่มีโอกาสใช้ Counter ในตอนนี้"
	end
	local p = self.players[byPlayer]
	local card = findInHand(p, handIndex)
	if not card or card.def.type ~= C.CardType.MAGIC or card.def.magicType ~= C.MagicType.COUNTER then
		return false, "ต้องเป็นการ์ด Counter"
	end
	local ab = card.def.ability
	if not ab or ab.kind ~= "earth_absorption" then return false, "Counter ใบนี้ใช้ตอนนี้ไม่ได้" end
	if self.reactionWindow.kind ~= "post_summon" then return false, "ไม่มีเป้าหมายให้ตอบโต้" end

	local costCards = {}
	for _, i in ipairs(costHandIndexes) do
		if i ~= handIndex then
			local cc = p.hand[i]
			if not cc then return false, "ดัชนีการ์ดค่าใช้จ่ายไม่ถูกต้อง" end
			costCards[#costCards + 1] = cc
		end
	end
	local need = self:effectiveCost(p, card.def)
	if sumGem(costCards) < need then return false, string.format("เจมไม่พอ (ต้องการ %d)", need) end

	local allIdx = { handIndex }
	for _, i in ipairs(costHandIndexes) do
		if i ~= handIndex then allIdx[#allIdx + 1] = i end
	end
	local removed = removeHandIndexes(p, allIdx)
	local theCard
	for _, c in ipairs(removed) do
		if c.uid == card.uid then theCard = c else p.graveyard[#p.graveyard + 1] = c end
	end
	p.graveyard[#p.graveyard + 1] = theCard

	local targetOwner = self.reactionWindow.avatarOwner
	local targetUid = self.reactionWindow.avatarUid
	local targetAvatar = select(1, self.players[targetOwner]:findAvatar(targetUid))
	if targetAvatar then
		self:log("%s ใช้ %s ทำลาย %s ของ %s!", p.name, theCard.def.name, targetAvatar.def.name, self.players[targetOwner].name)
		self:destroyAvatar(targetOwner, targetUid)
	end
	self.reactionWindow = nil
	return true
end

function Match:passReaction(byPlayer)
	if not self.reactionWindow or self.reactionWindow.forPlayer ~= byPlayer then
		return false, "ไม่มีอะไรให้ตอบโต้"
	end
	self.reactionWindow = nil
	return true
end

-- ===================== attack phase =====================

function Match:declareAttack(byPlayer, attackerUid, targetType, targetAvatarUid)
	if self.gameOver then return false, "เกมจบแล้ว" end
	if self.reactionWindow then return false, "ต้องจัดการ Counter ก่อน" end
	if byPlayer ~= self.activePlayerIndex or self.phase ~= C.Phase.ATTACK then
		return false, "ทำได้เฉพาะ Attack Phase ในตาคุณ"
	end
	if self.turnNumber == 1 then
		return false, "เทิร์นแรกของเกมยังโจมตีไม่ได้"
	end
	local p = self:activePlayer()
	local opp = self:opponentOf(byPlayer)
	local attacker = select(1, p:findAvatar(attackerUid))
	if not attacker then return false, "ไม่พบ Avatar ผู้โจมตี" end
	if attacker.tapped then return false, "Avatar ใบนี้โจมตีไปแล้วในเทิร์นนี้" end

	local canDirect = attacker.def.ability and attacker.def.ability.kind == "direct_attack"
	if targetType == "life" then
		if #opp.avatars > 0 and not canDirect then
			return false, "ต้องทำลาย Avatar ของคู่ต่อสู้ก่อนจึงจะตี Life Card ได้"
		end
		attacker.tapped = true
		if #opp.life > 0 then
			local flipped = table.remove(opp.life)
			opp.graveyard[#opp.graveyard + 1] = flipped
			self:log("%s โจมตี Life Card ของ %s โดยตรง! (เหลือ %d ใบ)", attacker.def.name, opp.name, #opp.life)
			if #opp.life == 0 then
				opp.critical = true
				self:log("%s เข้าสู่สถานะ [สาหัส]!", opp.name)
			end
		else
			self.gameOver = true
			self.winner = byPlayer
			self:log("%s โจมตีซ้ำขณะ [สาหัส]! %s ชนะเกม!", attacker.def.name, p.name)
		end
		return true
	elseif targetType == "avatar" then
		local defender = select(1, opp:findAvatar(targetAvatarUid))
		if not defender then return false, "ไม่พบ Avatar เป้าหมาย" end
		attacker.tapped = true
		local atkPower = self:computePower(byPlayer, attacker)
		local defPower = self:computePower(opp.index, defender)
		self:log("%s (พลัง %d) โจมตี %s (พลัง %d)", attacker.def.name, atkPower, defender.def.name, defPower)
		if atkPower > defPower then
			self:destroyAvatar(opp.index, defender.uid)
			self:log("%s ถูกทำลาย", defender.def.name)
		elseif atkPower < defPower then
			self:destroyAvatar(byPlayer, attacker.uid)
			self:log("%s ถูกทำลาย", attacker.def.name)
		else
			self:destroyAvatar(opp.index, defender.uid)
			self:destroyAvatar(byPlayer, attacker.uid)
			self:log("ทั้งสองฝ่ายถูกทำลาย")
		end
		return true
	end
	return false, "targetType ไม่ถูกต้อง"
end

-- ===================== unified action dispatcher =====================
-- Used by the local UI, the AI, and (on the host) incoming network action
-- messages from the client - one code path, so there's no risk of the
-- network path applying actions differently than local play.
function Match:applyAction(byPlayer, action)
	if not action or type(action.kind) ~= "string" then return false, "การกระทำไม่ถูกต้อง" end
	local k = action.kind
	if k == "summon_avatar" then
		return self:summonAvatar(byPlayer, action.handIndex, action.cost or {})
	elseif k == "play_construct" then
		return self:playConstruct(byPlayer, action.handIndex, action.cost or {})
	elseif k == "cast_magic" then
		return self:castMagic(byPlayer, action.handIndex, action.cost or {}, action.target)
	elseif k == "activate_ascension" then
		return self:activateAscension(byPlayer, action.avatarUid, action.cost or {}, action.graveyardUid)
	elseif k == "declare_attack" then
		return self:declareAttack(byPlayer, action.attackerUid, action.targetType, action.targetUid)
	elseif k == "next_phase" then
		return self:nextPhase(byPlayer)
	elseif k == "cast_counter" then
		return self:castCounter(byPlayer, action.handIndex, action.cost or {})
	elseif k == "pass_reaction" then
		return self:passReaction(byPlayer)
	end
	return false, "ไม่รู้จักการกระทำ: " .. tostring(k)
end

-- ===================== view / serialization =====================
-- Produces a plain JSON-safe table representing the match from the point
-- of view of `viewerIndex` (1, 2, or nil for an all-seeing/local view).
-- Hidden information (deck order, opponent's hand, life card identities,
-- graveyard order beyond identity) is filtered appropriately:
--   - your own hand: full detail
--   - opponent's hand: count only
--   - both decks: count only
--   - both life zones: count only (face-down)
--   - graveyards/avatars/constructs/land: public, full detail

local function avatarView(a)
	local weapons = {}
	for _, w in ipairs(a.weapons) do
		weapons[#weapons + 1] = { uid = w.uid, id = w.def.id }
	end
	return {
		uid = a.uid, id = a.def.id, tapped = a.tapped or false,
		summonTurn = a.summonTurn, weapons = weapons,
	}
end

local function cardRefView(c)
	return { uid = c.uid, id = c.def.id }
end

function Match:serialize(viewerIndex)
	local function playerView(p, mine)
		local hand = {}
		if mine then
			for _, c in ipairs(p.hand) do hand[#hand + 1] = cardRefView(c) end
		end
		local avatars = {}
		for _, a in ipairs(p.avatars) do avatars[#avatars + 1] = avatarView(a) end
		local graveyard = {}
		for _, c in ipairs(p.graveyard) do graveyard[#graveyard + 1] = cardRefView(c) end
		local constructs = {}
		for _, c in ipairs(p.constructs) do constructs[#constructs + 1] = cardRefView(c) end
		return {
			name = p.name,
			handCount = #p.hand,
			hand = hand,
			deckCount = #p.deck,
			lifeCount = #p.life,
			critical = p.critical or false,
			graveyard = graveyard,
			avatars = avatars,
			constructs = constructs,
		}
	end

	return {
		turnNumber = self.turnNumber,
		activePlayerIndex = self.activePlayerIndex,
		phase = self.phase,
		gameOver = self.gameOver,
		winner = self.winner,
		reactionWindow = self.reactionWindow,
		land = self.land and cardRefView(self.land) or nil,
		viewerIndex = viewerIndex,
		players = {
			[1] = playerView(self.players[1], viewerIndex == nil or viewerIndex == 1),
			[2] = playerView(self.players[2], viewerIndex == nil or viewerIndex == 2),
		},
		eventLog = self.eventLog,
	}
end

return Match
