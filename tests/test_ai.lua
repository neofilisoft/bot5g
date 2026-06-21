package.path = "./?.lua;" .. package.path
local Match = require("src.engine.match")
local Decks = require("src.decks")
local AI = require("src.engine.ai")

local function seededRng(seed)
	local s = seed
	return function() s = (s * 1103515245 + 12345) % 2147483648; return s / 2147483648 end
end

local deckA = Decks.byId.deckA
local deckB = Decks.byId.deckB

for trial = 1, 5 do
	local m = Match.new({
		decklist1 = deckA.main, life1 = deckA.life, name1 = "BotA",
		decklist2 = deckB.main, life2 = deckB.life, name2 = "BotB",
		firstPlayer = 1, rng = seededRng(trial * 17 + 3),
	})
	local ai1 = AI.new(m, 1)
	local ai2 = AI.new(m, 2)

	local steps = 0
	while not m.gameOver and steps < 4000 do
		steps = steps + 1
		ai1:step()
		ai2:step()
	end

	print(string.format(
		"Trial %d: gameOver=%s winner=%s turns=%d steps=%d p1life=%d p2life=%d p1hand=%d p2hand=%d p1deck=%d p2deck=%d",
		trial, tostring(m.gameOver), tostring(m.winner), m.turnNumber, steps,
		#m.players[1].life, #m.players[2].life, #m.players[1].hand, #m.players[2].hand,
		#m.players[1].deck, #m.players[2].deck))

	if not m.gameOver then
		print("  WARNING: game did not finish within step budget (likely a stalemate loop)")
	end
end

print("\nAI VS AI SIMULATION COMPLETE")
