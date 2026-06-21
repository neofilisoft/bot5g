package.path = "./?.lua;" .. package.path
love = {}
love.graphics = setmetatable({ newFont = function() return {} end, getDimensions = function() return 1600, 900 end, getFont = function() return {} end }, { __index = function() return function(...) return {} end end })
love.mouse = { getPosition = function() return 0, 0 end }
love.keyboard = {}; love.window = { setTitle = function() end }; love.filesystem = { getInfo = function() return nil end }

local Manager = require("src.scenes.manager")
local function assertTrue(cond, msg) if not cond then error("ASSERTION FAILED: " .. msg) end end

Manager.updateScale()

local RPS = require("src.scenes.rps")
Manager.switch(RPS, { mode = "hotseat", deckId1 = "deckA", deckId2 = "deckB" })
assertTrue(RPS.stage == "p1ready", "hotseat RPS should start at p1ready (pass-screen gate)")

RPS:mousepressed(800, 450, 1) -- tap to reveal P1's choices
assertTrue(RPS.stage == "p1choose", "should now show P1 choice buttons")
assertTrue(#RPS.buttons == 3, "should have 3 RPS choice buttons")
RPS.buttons[1].onClick() -- P1 picks rock
assertTrue(RPS.stage == "p2ready", "should move to P2 pass-screen gate")

RPS:mousepressed(800, 450, 1) -- tap to reveal P2's choices
assertTrue(RPS.stage == "p2choose", "should now show P2 choice buttons")
RPS.buttons[2].onClick() -- P2 picks scissors (rock beats scissors -> P1 wins)
assertTrue(RPS.stage == "reveal", "should be at reveal stage")
assertTrue(not RPS.result.tie, "rock vs scissors should not tie")
assertTrue(RPS.result.winnerSeat == 1, "rock beats scissors, P1 should win")
print("OK: hotseat RPS p1ready->p1choose->p2ready->p2choose->reveal flow works, winner=" .. RPS.result.winnerSeat)

-- P1 (winner) chooses to go first
local goFirstBtn
for _, b in ipairs(RPS.buttons) do
	if b.label:find("ไปก่อน", 1, true) then goFirstBtn = b end
end
assertTrue(goFirstBtn, "go-first button should exist")
goFirstBtn.onClick()

local Game = require("src.scenes.game")
assertTrue(Manager.current == Game, "should be in Game scene now")
assertTrue(Game.mode == "hotseat", "mode should be hotseat")
assertTrue(Game.match.activePlayerIndex == 1, "P1 should go first as chosen")
print("OK: transitioned into hotseat Game with correct firstPlayer")

Game:update(0) -- first real frame tick, like love.update would trigger

-- the very first frame should show a pendingReveal pass-screen for P1
assertTrue(Game.pendingReveal == true, "hotseat should gate the first view behind a pass-screen")
Game:mousepressed(800, 450, 1) -- tap to reveal
assertTrue(Game.pendingReveal == false, "pass-screen should clear after tap")
print("OK: initial hotseat pass-screen gates correctly")

-- advance to attack/end phase and confirm turn switches trigger a new pass-screen
Game:update(0)
local nb
for _, b in ipairs(Game.buttons) do if b.label:find("ถัดไป", 1, true) then nb = b end end
assertTrue(nb, "next-phase button should exist for active hotseat player")
nb.onClick() -- MAIN -> ATTACK
Game:update(0)
for _, b in ipairs(Game.buttons) do if b.label:find("ถัดไป", 1, true) then nb = b end end
nb.onClick() -- ATTACK -> END
Game:update(0)
for _, b in ipairs(Game.buttons) do if b.label:find("ถัดไป", 1, true) then nb = b end end
nb.onClick() -- END -> switch to P2
Game:update(0)
assertTrue(Game.match.activePlayerIndex == 2, "should now be P2's turn")
assertTrue(Game.pendingReveal == true, "switching active hotseat player should trigger a new pass-screen")
print("OK: turn switch correctly re-triggers the pass-screen for the other player")

print("\nALL HOTSEAT SMOKE TESTS PASSED")
