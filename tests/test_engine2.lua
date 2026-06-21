package.path = "./?.lua;" .. package.path
local Match = require("src.engine.match")
local C = require("src.constants")

local function assertTrue(cond, msg)
	if not cond then error("ASSERTION FAILED: " .. msg) end
end

local function freshMatch(rngSeed)
	local s = rngSeed or 1
	local rng = function() s = (s * 1103515245 + 12345) % 2147483648; return s / 2147483648 end
	-- minimal decklists: enough copies to reach 50, simple & deterministic
	local main = {
		{ id = "5G-001", n = 3 }, { id = "5G-002", n = 3 }, { id = "5G-004", n = 3 },
		{ id = "5G-005", n = 3 }, { id = "5G-006", n = 3 }, { id = "5G-007", n = 3 },
		{ id = "5G-008", n = 3 }, { id = "5G-009", n = 3 }, { id = "5G-010", n = 3 },
		{ id = "5G-011", n = 3 }, { id = "5G-101", n = 3 }, { id = "5G-102", n = 3 },
		{ id = "5G-104", n = 3 }, { id = "5G-111", n = 3 }, { id = "5G-121", n = 2 },
		{ id = "5G-131", n = 3 }, { id = "5G-141", n = 3 },
	}
	local life = { "5G-012", "5G-013", "5G-014", "5G-016", "5G-017" }
	return Match.new({
		decklist1 = main, life1 = life, name1 = "Alice",
		decklist2 = main, life2 = life, name2 = "Bob",
		firstPlayer = 1, rng = rng,
	})
end

-- ===== TEST 1: weapon attach increases power =====
do
	local m = freshMatch(7)
	local p1 = m.players[1]
	-- find a weapon card and an avatar card in hand, or force them in
	local weaponIdx, avatarIdx
	for i, c in ipairs(p1.hand) do
		if c.def.id == "5G-111" then weaponIdx = i end
		if c.def.type == C.CardType.AVATAR then avatarIdx = avatarIdx or i end
	end
	assertTrue(avatarIdx, "need an avatar in hand for weapon test")
	-- summon the avatar first (pay with any other cards)
	local need = m:effectiveCost(p1, p1.hand[avatarIdx].def)
	local combo = m:suggestCost(p1, avatarIdx, need)
	assertTrue(combo, "should find a cost combo")
	local ok, err = m:summonAvatar(1, avatarIdx, combo)
	assertTrue(ok, "summon should succeed: " .. tostring(err))
	if m.reactionWindow then m:passReaction(m.reactionWindow.forPlayer) end
	local avatar = p1.avatars[1]
	local basePower = m:computePower(1, avatar)

	-- now find weapon 5G-111 in hand (re-scan since indexes shifted)
	weaponIdx = nil
	for i, c in ipairs(p1.hand) do
		if c.def.id == "5G-111" then weaponIdx = i break end
	end
	if weaponIdx then
		local wneed = m:effectiveCost(p1, p1.hand[weaponIdx].def)
		local wcombo = m:suggestCost(p1, weaponIdx, wneed)
		assertTrue(wcombo, "should find cost combo for weapon")
		local ok2, err2 = m:castMagic(1, weaponIdx, wcombo, avatar.uid)
		assertTrue(ok2, "weapon cast should succeed: " .. tostring(err2))
		local newPower = m:computePower(1, avatar)
		assertTrue(newPower == basePower + 2, string.format("weapon should add +2 power (got %d -> %d)", basePower, newPower))
		print(string.format("TEST 1 PASSED: weapon buff %d -> %d", basePower, newPower))
	else
		print("TEST 1 SKIPPED: weapon card not in opening hand (rng), logic already covered by direct call below")
		-- force-test computePower logic directly via a synthetic weapon attach
		local CardInstance = require("src.engine.cardinstance")
		local Cards = require("src.cards")
		local fakeWeapon = CardInstance.new(Cards.byId["5G-111"], 1)
		avatar.weapons[#avatar.weapons + 1] = fakeWeapon
		local newPower = m:computePower(1, avatar)
		assertTrue(newPower == basePower + 2, "synthetic weapon attach should add +2 power")
		print(string.format("TEST 1 PASSED (synthetic): weapon buff %d -> %d", basePower, newPower))
	end
end

-- ===== TEST 2: land magic affects both players' matching tribe =====
do
	local m = freshMatch(99)
	local CardInstance = require("src.engine.cardinstance")
	local Cards = require("src.cards")
	-- manually summon a มนุษย์ avatar for each player (bypass hand/cost for a clean unit test)
	local a1 = CardInstance.new(Cards.byId["5G-001"], 1) -- ป้าทุย, มนุษย์, power 2
	local a2 = CardInstance.new(Cards.byId["5G-010"], 2) -- จ่าหมิว, มนุษย์, power 3
	m.players[1].avatars[1] = a1
	m.players[2].avatars[1] = a2
	local p1Before = m:computePower(1, a1)
	local p2Before = m:computePower(2, a2)
	m.land = CardInstance.new(Cards.byId["5G-121"], 1) -- สนามแข่งไลฟ์สด: มนุษย์ +1 both sides
	local p1After = m:computePower(1, a1)
	local p2After = m:computePower(2, a2)
	assertTrue(p1After == p1Before + 1, "land magic should buff p1's human avatar")
	assertTrue(p2After == p2Before + 1, "land magic should buff p2's human avatar too (both sides)")
	print(string.format("TEST 2 PASSED: land magic buffs both sides (%d->%d, %d->%d)", p1Before, p1After, p2Before, p2After))
end

-- ===== TEST 3: earth_absorption counter destroys a freshly summoned avatar =====
do
	local m = freshMatch(123)
	local CardInstance = require("src.engine.cardinstance")
	local Cards = require("src.cards")
	-- give player 2 a counter card directly in hand for a controlled test
	local counterCard = CardInstance.new(Cards.byId["5G-131"], 2)
	table.insert(m.players[2].hand, counterCard)
	local counterIdx = #m.players[2].hand
	-- give player2 a cheap gem card to pay for it
	local fuel = CardInstance.new(Cards.byId["5G-008"], 2)
	table.insert(m.players[2].hand, fuel)
	local fuelIdx = #m.players[2].hand

	-- player 1 summons an avatar
	local p1 = m.players[1]
	local avatarIdx
	for i, c in ipairs(p1.hand) do
		if c.def.type == C.CardType.AVATAR then avatarIdx = i break end
	end
	assertTrue(avatarIdx, "p1 needs an avatar in hand")
	local need = m:effectiveCost(p1, p1.hand[avatarIdx].def)
	local combo = m:suggestCost(p1, avatarIdx, need)
	assertTrue(combo, "cost combo should exist")
	local ok, err = m:summonAvatar(1, avatarIdx, combo)
	assertTrue(ok, "summon should succeed: " .. tostring(err))
	assertTrue(m.reactionWindow ~= nil, "a reaction window should now be open for p2")
	assertTrue(#p1.avatars == 1, "p1 should have 1 avatar before counter resolves")

	local ok2, err2 = m:castCounter(2, counterIdx, { fuelIdx })
	assertTrue(ok2, "counter should succeed: " .. tostring(err2))
	assertTrue(#p1.avatars == 0, "p1's avatar should have been destroyed by earth_absorption")
	assertTrue(m.reactionWindow == nil, "reaction window should be closed after countering")
	print("TEST 3 PASSED: earth_absorption counter destroyed the freshly summoned avatar")
end

-- ===== TEST 4: full life depletion -> critical -> winning hit =====
do
	local m = freshMatch(55)
	local CardInstance = require("src.engine.cardinstance")
	local Cards = require("src.cards")
	local attacker = CardInstance.new(Cards.byId["5G-005"], 1) -- AI เทวดาจำแลง, direct_attack
	m.players[1].avatars[1] = attacker
	m.turnNumber = 2 -- bypass first-turn-no-attack rule
	m.activePlayerIndex = 1
	m.phase = C.Phase.ATTACK
	assertTrue(#m.players[2].life == 5, "p2 should start with 5 life cards")
	for i = 1, 5 do
		attacker.tapped = false
		local ok, err = m:declareAttack(1, attacker.uid, "life", nil)
		assertTrue(ok, "life attack " .. i .. " should succeed: " .. tostring(err))
		assertTrue(not m.gameOver, "game should not be over until critical is hit again, i=" .. i)
	end
	assertTrue(#m.players[2].life == 0, "p2 should have 0 life cards left")
	assertTrue(m.players[2].critical == true, "p2 should be in critical status")
	attacker.tapped = false
	local ok, err = m:declareAttack(1, attacker.uid, "life", nil)
	assertTrue(ok, "final critical hit should succeed: " .. tostring(err))
	assertTrue(m.gameOver, "game should be over now")
	assertTrue(m.winner == 1, "player 1 should be the winner")
	print("TEST 4 PASSED: full life depletion -> critical -> win sequence works correctly")
end

-- ===== TEST 5: deck-out loss =====
do
	local m = freshMatch(8)
	m.players[1].deck = {} -- empty the deck
	local before = m.gameOver
	m:drawN(m.players[1], 1)
	assertTrue(m.gameOver, "drawing from empty deck should end the game")
	assertTrue(m.winner == 2, "player 2 should win on p1 deck-out")
	print("TEST 5 PASSED: deck-out loss works correctly")
end

print("\nALL TARGETED TESTS PASSED")
