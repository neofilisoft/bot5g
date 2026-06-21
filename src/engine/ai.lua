-- src/engine/ai.lua
-- A lightweight heuristic bot. It only ever calls the same public Match
-- methods a human player/UI would call, so it can't cheat or desync state.

local C = require("src.constants")
local class = require("src.class")

local AI = class()

function AI:init(match, playerIndex)
	self.match = match
	self.playerIndex = playerIndex
end

-- Call this once whenever it becomes the bot's turn / a reaction window opens
-- for the bot. It runs until there's nothing more to usefully do, then
-- returns control (the caller is expected to keep calling `step` again on
-- the next update if it's still the bot's turn, e.g. after an animation).
function AI:step()
	local m = self.match
	if m.gameOver then return end

	if m.reactionWindow then
		if m.reactionWindow.forPlayer == self.playerIndex then
			self:considerReaction()
		end
		return
	end

	if m.activePlayerIndex ~= self.playerIndex then return end

	if m.phase == C.Phase.MAIN then
		self:playMain()
		m:nextPhase(self.playerIndex)
	elseif m.phase == C.Phase.ATTACK then
		self:playAttacks()
		m:nextPhase(self.playerIndex)
	elseif m.phase == C.Phase.END then
		m:nextPhase(self.playerIndex)
	end
end

function AI:considerReaction()
	local m = self.match
	local p = m.players[self.playerIndex]
	for i, c in ipairs(p.hand) do
		if c.def.type == C.CardType.MAGIC and c.def.magicType == C.MagicType.COUNTER
			and c.def.ability and c.def.ability.kind == "earth_absorption" then
			local need = m:effectiveCost(p, c.def)
			local combo = m:suggestCost(p, i, need)
			if combo then
				local ok = m:castCounter(self.playerIndex, i, combo)
				if ok then return end
			end
		end
	end
	m:passReaction(self.playerIndex)
end

function AI:playMain()
	local m = self.match
	local p = m.players[self.playerIndex]
	local guard = 0

	-- 1) play constructs (cheap, always good value)
	local playedSomething = true
	while playedSomething and guard < 30 do
		guard = guard + 1
		playedSomething = false
		for i, c in ipairs(p.hand) do
			if c.def.type == C.CardType.CONSTRUCT then
				local need = m:effectiveCost(p, c.def)
				local combo = m:suggestCost(p, i, need)
				if combo then
					local ok = m:playConstruct(self.playerIndex, i, combo)
					if ok then playedSomething = true; break end
				end
			end
		end
	end

	-- 2) summon the strongest avatar it can afford, repeatedly
	playedSomething = true
	guard = 0
	while playedSomething and guard < 30 do
		guard = guard + 1
		playedSomething = false
		if p:hasOpenAvatarSlot() then
			local bestIdx, bestPower
			for i, c in ipairs(p.hand) do
				if c.def.type == C.CardType.AVATAR then
					local need = m:effectiveCost(p, c.def)
					local combo = m:suggestCost(p, i, need)
					if combo and (not bestPower or (c.def.power or 0) > bestPower) then
						bestIdx, bestPower = i, c.def.power or 0
					end
				end
			end
			if bestIdx then
				local c = p.hand[bestIdx]
				local need = m:effectiveCost(p, c.def)
				local combo = m:suggestCost(p, bestIdx, need)
				local ok = m:summonAvatar(self.playerIndex, bestIdx, combo)
				if ok then
					playedSomething = true
					if m.reactionWindow and m.reactionWindow.forPlayer ~= self.playerIndex then
						-- the (human) opponent gets to react; bot just waits, the
						-- caller's game loop will surface this window to them.
						return
					end
				end
			end
		end
	end

	-- 3) cast a normal "destroy" magic on the opponent's strongest avatar, if worthwhile
	local opp = m:opponentOf(self.playerIndex)
	for i, c in ipairs(p.hand) do
		if c.def.type == C.CardType.MAGIC and c.def.magicType == C.MagicType.NORMAL
			and c.def.ability and c.def.ability.kind == "destroy_avatar" then
			-- find a legal, juiciest target
			local bestTarget
			for _, av in ipairs(opp.avatars) do
				local pw = m:computePower(opp.index, av)
				if pw <= (c.def.ability.maxPower or 0) and (not bestTarget or pw > bestTarget.pw) then
					bestTarget = { uid = av.uid, pw = pw }
				end
			end
			if bestTarget then
				local need = m:effectiveCost(p, c.def)
				local combo = m:suggestCost(p, i, need)
				if combo then
					m:castMagic(self.playerIndex, i, combo, bestTarget.uid)
					break
				end
			end
		end
	end

	-- 4) equip a weapon on the strongest avatar it controls, if it has one
	for i, c in ipairs(p.hand) do
		if c.def.type == C.CardType.MAGIC and c.def.magicType == C.MagicType.WEAPON and #p.avatars > 0 then
			local best, bestPw
			for _, av in ipairs(p.avatars) do
				local pw = m:computePower(self.playerIndex, av)
				if not bestPw or pw > bestPw then best, bestPw = av, pw end
			end
			local need = m:effectiveCost(p, c.def)
			local combo = m:suggestCost(p, i, need)
			if combo and best then
				m:castMagic(self.playerIndex, i, combo, best.uid)
				break
			end
		end
	end

	-- 5) play a land magic if none is active yet
	if not m.land then
		for i, c in ipairs(p.hand) do
			if c.def.type == C.CardType.MAGIC and c.def.magicType == C.MagicType.LAND then
				local need = m:effectiveCost(p, c.def)
				local combo = m:suggestCost(p, i, need)
				if combo then
					m:castMagic(self.playerIndex, i, combo, nil)
					break
				end
			end
		end
	end
end

function AI:playAttacks()
	local m = self.match
	if m.turnNumber == 1 then return end
	local p = m.players[self.playerIndex]
	local opp = m:opponentOf(self.playerIndex)
	for _, av in ipairs(p.avatars) do
		if not av.tapped then
			local canDirect = av.def.ability and av.def.ability.kind == "direct_attack"
			if #opp.avatars == 0 then
				m:declareAttack(self.playerIndex, av.uid, "life", nil)
			else
				local atkPower = m:computePower(self.playerIndex, av)
				local bestTarget, bestMargin
				for _, dav in ipairs(opp.avatars) do
					local defPower = m:computePower(opp.index, dav)
					if atkPower > defPower then
						local margin = atkPower - defPower
						if not bestMargin or margin > bestMargin then
							bestTarget, bestMargin = dav, margin
						end
					end
				end
				if bestTarget then
					m:declareAttack(self.playerIndex, av.uid, "avatar", bestTarget.uid)
				elseif canDirect then
					m:declareAttack(self.playerIndex, av.uid, "life", nil)
				end
			end
		end
	end
end

return AI
