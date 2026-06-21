package.path = "./?.lua;" .. package.path
local Match = require("src.engine.match")
local Decks = require("src.decks")
local C = require("src.constants")

local function seededRng(seed)
	local s = seed
	return function()
		s = (s * 1103515245 + 12345) % 2147483648
		return s / 2147483648
	end
end

local deckA = Decks.byId.deckA
local deckB = Decks.byId.deckB

local m = Match.new({
	decklist1 = deckA.main, life1 = deckA.life, name1 = "Alice",
	decklist2 = deckB.main, life2 = deckB.life, name2 = "Bob",
	firstPlayer = 1,
	rng = seededRng(42),
})

local function assertTrue(cond, msg)
	if not cond then
		error("ASSERTION FAILED: " .. msg)
	end
end

assertTrue(#m.players[1].hand == 5, "p1 should have 5 starting cards")
assertTrue(#m.players[2].hand == 5, "p2 should have 5 starting cards")
assertTrue(#m.players[1].deck == 45, "p1 deck should be 45 after opening hand")
assertTrue(m.turnNumber == 1, "should be turn 1")
assertTrue(m.phase == C.Phase.MAIN, "should start in MAIN phase")

print("Initial hand P1:")
for i, c in ipairs(m.players[1].hand) do
	print(string.format("  [%d] %s (cost=%s gem=%s type=%s)", i, c.def.name, tostring(c.def.cost), tostring(c.def.gem), c.def.type))
end

-- Turn 1 should disallow attacks
local ok, err = m:nextPhase(1)
assertTrue(ok, "p1 should move MAIN->ATTACK")
assertTrue(m.phase == C.Phase.ATTACK, "phase should now be ATTACK")
ok, err = m:nextPhase(1)
assertTrue(ok, "p1 should move ATTACK->END")
ok, err = m:nextPhase(1)
assertTrue(ok, "p1 should end turn -> switch to p2")
assertTrue(m.activePlayerIndex == 2, "active player should now be 2")
assertTrue(m.turnNumber == 2, "turn number should be 2")
assertTrue(#m.players[2].hand == 6, "p2 should have drawn 1 card on their first turn (6 in hand)")

print("\nOK: turn 1 -> turn 2 transition works, p2 drew normally.")

-- Try a bunch of automated turns: each active player tries to summon any
-- affordable avatar (using suggestCost), cast any affordable magic, then
-- pass through phases. This exercises most of the engine surface.
local function tryAutoPlay(p_idx)
	local p = m.players[p_idx]
	local triedSomething = true
	local guard = 0
	while triedSomething and guard < 20 do
		guard = guard + 1
		triedSomething = false
		for i, c in ipairs(p.hand) do
			if c.def.type == C.CardType.AVATAR and p:hasOpenAvatarSlot() then
				local need = m:effectiveCost(p, c.def)
				local combo = m:suggestCost(p, i, need)
				if combo then
					local ok2, e2 = m:summonAvatar(p_idx, i, combo)
					if ok2 then
						triedSomething = true
						-- handle any opened reaction window immediately (opponent passes)
						if m.reactionWindow then
							m:passReaction(m.reactionWindow.forPlayer)
						end
						break
					end
				end
			end
		end
	end
end

for turn = 1, 6 do
	local pIdx = m.activePlayerIndex
	tryAutoPlay(pIdx)
	local ok1 = select(1, m:nextPhase(pIdx)) -- MAIN -> ATTACK
	assertTrue(ok1, "phase advance 1 failed turn " .. turn)

	-- attack with any untapped avatar against an open target
	local p = m.players[pIdx]
	local opp = m.players[m:opponentIndex(pIdx)]
	if m.turnNumber > 1 then
		for _, av in ipairs(p.avatars) do
			if not av.tapped then
				if #opp.avatars > 0 then
					m:declareAttack(pIdx, av.uid, "avatar", opp.avatars[1].uid)
				else
					m:declareAttack(pIdx, av.uid, "life", nil)
				end
				if m.gameOver then break end
			end
		end
	end
	if m.gameOver then break end

	local ok2 = select(1, m:nextPhase(pIdx)) -- ATTACK -> END
	assertTrue(ok2, "phase advance 2 failed turn " .. turn)
	local ok3 = select(1, m:nextPhase(pIdx)) -- END -> switch
	assertTrue(ok3, "phase advance 3 failed turn " .. turn)
end

print("\nOK: 6 simulated turns of auto-play completed without engine errors.")
print(string.format("P1 avatars on field: %d, P2 avatars on field: %d", #m.players[1].avatars, #m.players[2].avatars))
print(string.format("P1 life remaining: %d, P2 life remaining: %d", #m.players[1].life, #m.players[2].life))
print(string.format("P1 hand: %d, P2 hand: %d", #m.players[1].hand, #m.players[2].hand))
print("gameOver=" .. tostring(m.gameOver) .. " winner=" .. tostring(m.winner))

print("\nLast 15 log events:")
for i = math.max(1, #m.eventLog - 14), #m.eventLog do
	print("  " .. m.eventLog[i])
end

print("\nALL TESTS PASSED")
