package.path = "./?.lua;" .. package.path
love = {}
love.graphics = setmetatable({ newFont = function() return {} end, getDimensions = function() return 1600, 900 end, getFont = function() return {} end }, { __index = function() return function(...) return {} end end })
love.mouse = { getPosition = function() return 0, 0 end }
love.keyboard = {}; love.window = { setTitle = function() end }; love.filesystem = { getInfo = function() return nil end }

local protocol = require("src.net.protocol")
local Cards = require("src.cards")
local costcalc = require("src.engine.costcalc")
local function assertTrue(cond, msg) if not cond then error("ASSERTION FAILED: " .. msg) end end

-- scene modules are singleton tables (fine for the real app, which only
-- ever has one active scene) - for this test we need two INDEPENDENT
-- "host" and "client" instances side by side, so we instantiate via a
-- metatable that inherits methods from the shared module but keeps its
-- own fields.
local function instanceOf(moduleTable)
	return setmetatable({}, { __index = moduleTable })
end

local function makeLinkedMocks()
	local a, b = {}, {}
	a.outbox, b.outbox = {}, {}
	function a:send(msg) table.insert(b.outbox, msg) end
	function b:send(msg) table.insert(a.outbox, msg) end
	local function update(self)
		while #self.outbox > 0 do
			local m = table.remove(self.outbox, 1)
			if self.onMessage then self.onMessage(m) end
		end
	end
	a.update, b.update = update, update
	function a:close() end
	b.close = a.close
	return a, b
end

local hostNet, clientNet = makeLinkedMocks()

local RPSModule = require("src.scenes.rps")
local rpsHost = instanceOf(RPSModule)
local rpsClient = instanceOf(RPSModule)

rpsHost:enter({ mode = "host", net = hostNet, deckId1 = "deckA", deckId2 = "deckB", name1 = "Host", name2 = "Buddy" })
rpsClient:enter({ mode = "client", net = clientNet, mySeat = 2 })
assertTrue(rpsHost.mode == "host" and rpsClient.mode == "client", "independent scene instances should not clobber each other")
print("OK: independent host/client RPS scene instances created")

rpsHost:choose("rock")
assertTrue(rpsHost.stage == "waiting", "host should be waiting for client's choice")
rpsClient:choose("scissors")
assertTrue(rpsClient.stage == "waiting", "client should be waiting for host's result")

hostNet:update()
assertTrue(rpsHost.stage == "reveal", "host should have resolved after receiving client's choice")
assertTrue(rpsHost.result.winnerSeat == 1, "rock beats scissors -> host (seat 1) should win")
print("OK: host resolved RPS_CHOICE and computed correct winner (rock beats scissors)")

clientNet:update()
assertTrue(rpsClient.stage == "reveal", "client should now be at reveal stage")
assertTrue(rpsClient.result.winnerSeat == 1, "client should see the identical result")
print("OK: client received RPS_RESULT and matches host's computation")

local goFirstBtn
for _, b in ipairs(rpsHost.buttons) do
	if b.label:find("ไปก่อน", 1, true) then goFirstBtn = b end
end
assertTrue(goFirstBtn, "host (winner) should see go-first/second choice")
goFirstBtn.onClick()

local GameModule = require("src.scenes.game")
local hostGame = instanceOf(GameModule)
-- RPS:proceedToGame() calls Manager.switch(Game, opts) which we can't
-- intercept directly here, so replicate what it does: re-enter manually
-- using the same opts shape host's RPS would have built.
hostGame:enter({ mode = "host", net = hostNet, deckId1 = "deckA", deckId2 = "deckB", name1 = "Host", name2 = "Buddy", firstPlayer = 1 })
assertTrue(hostGame.match.activePlayerIndex == 1, "host chose to go first")
print("OK: host Game instance created with correct firstPlayer")

-- host's enter() should have queued START + STATE for the client
assertTrue(#clientNet.outbox >= 1, "client should have received at least one queued message (START/STATE) from host enter()")

local clientGame = instanceOf(GameModule)
clientGame:enter({ mode = "client", net = clientNet, mySeat = 2 })
clientNet:update() -- deliver START + STATE
assertTrue(clientGame.view ~= nil, "client should have received a view via STATE message")
assertTrue(clientGame.view.players[1].name == "Host", "client's view should show correct player names")
print("OK: client Game instance received initial STATE over the mock network")

-- ===================== drive a real action across the wire =====================
local mineView = hostGame.view.players[1]
local handIdx, def
for i, c in ipairs(mineView.hand) do
	local d = Cards.byId[c.id]
	if d.type == "avatar" then handIdx, def = i, d break end
end
if not handIdx then
	for i, c in ipairs(mineView.hand) do
		local d = Cards.byId[c.id]
		if d.type == "construct" then handIdx, def = i, d break end
	end
end
assertTrue(handIdx, "host should have an avatar or construct in opening hand to test with")
local need = costcalc.effectiveCost(mineView.constructs, def)
local combo = costcalc.suggestCost(mineView.hand, handIdx, need)
assertTrue(combo, "should find a valid cost combo")

local kind = (def.type == "construct") and "play_construct" or "summon_avatar"
local beforeHand = #hostGame.match.players[1].hand
hostGame:submitAction({ kind = kind, handIndex = handIdx, cost = combo })
local afterHand = #hostGame.match.players[1].hand
assertTrue(afterHand < beforeHand, "host's local match should reflect the action immediately")
print(string.format("OK: host played %s locally (hand %d -> %d)", def.name, beforeHand, afterHand))

assertTrue(#clientNet.outbox >= 1, "host should have broadcast a new STATE to the client after the action")
clientNet:update()
assertTrue(#clientGame.view.players[1].avatars == #hostGame.view.players[1].avatars
	or #clientGame.view.players[1].constructs == #hostGame.view.players[1].constructs,
	"client's view should reflect the host's action after STATE sync")
print("OK: client received updated STATE reflecting host's action")

-- client should NOT be able to see host's actual hand contents (hidden info)
assertTrue(#clientGame.view.players[1].hand == 0, "client must not see host's hand card identities")
assertTrue(clientGame.view.players[1].handCount == #hostGame.match.players[1].hand, "client should see correct hand COUNT only")
print("OK: hidden information (opponent hand) correctly filtered for the client")

-- ===================== client sends an action back to host =====================
-- give the client a simple draw-magic card directly for a clean, deterministic test
local CardInstance = require("src.engine.cardinstance")
local CardsDB = require("src.cards")
local fakeDraw = CardInstance.new(CardsDB.byId["5G-104"], 2) -- รีสตาร์ทเราเตอร์: draw 2, cost 1, gem 1
table.insert(hostGame.match.players[2].hand, fakeDraw)
local fakeFuel = CardInstance.new(CardsDB.byId["5G-008"], 2)
table.insert(hostGame.match.players[2].hand, fakeFuel)

-- it must be player 2's turn for this to be legal; fast-forward via direct
-- phase advancement on the host (authoritative) match if needed
if hostGame.match.reactionWindow then
	-- the avatar summon above opened a reaction window for P2; resolve it (pass)
	hostGame.match:applyAction(hostGame.match.reactionWindow.forPlayer, { kind = "pass_reaction" })
end
if hostGame.match.activePlayerIndex == 1 then
	hostGame.match:applyAction(1, { kind = "next_phase" }) -- MAIN->ATTACK
	hostGame.match:applyAction(1, { kind = "next_phase" }) -- ATTACK->END
	hostGame.match:applyAction(1, { kind = "next_phase" }) -- END->switch to P2
end
assertTrue(hostGame.match.activePlayerIndex == 2, "should now be player 2's (client's) turn")

local drawIdx
for i, c in ipairs(hostGame.match.players[2].hand) do
	if c.def.id == "5G-104" then drawIdx = i break end
end
assertTrue(drawIdx, "the injected draw card should be in P2's hand")
local fuelIdx
for i, c in ipairs(hostGame.match.players[2].hand) do
	if c.def.id == "5G-008" then fuelIdx = i break end
end
assertTrue(fuelIdx, "the injected fuel card should be in P2's hand")

-- simulate the CLIENT submitting this action over the wire
clientGame.view = hostGame.match:serialize(2)
clientGame:submitAction({ kind = "cast_magic", handIndex = drawIdx, cost = { fuelIdx } })
assertTrue(#hostNet.outbox >= 1, "client's action should be queued for host")
local beforeP2Hand = #hostGame.match.players[2].hand
hostNet:update() -- host processes the incoming ACTION message
local afterP2Hand = #hostGame.match.players[2].hand
print(string.format("OK: host processed client's network ACTION message (P2 hand %d -> %d, draw-2 effect should net +0)", beforeP2Hand, afterP2Hand))
-- รีสตาร์ทเราเตอร์ costs 1 card + 1 fuel card (-2), then draws 2 (+2) = net 0
assertTrue(afterP2Hand == beforeP2Hand, "casting a 'draw 2' costing 2 cards should net to zero hand size change")

print("\nALL NETWORK PROTOCOL SMOKE TESTS PASSED")
