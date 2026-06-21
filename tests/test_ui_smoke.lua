package.path = "./?.lua;" .. package.path

-- ---- stub love ----
love = {}
love.graphics = setmetatable({
	newFont = function() return {} end,
	getDimensions = function() return 1600, 900 end,
	getFont = function() return {} end,
}, { __index = function() return function(...) return {} end end })
love.mouse = { getPosition = function() return 0, 0 end }
love.keyboard = {}
love.window = { setTitle = function() end }
love.filesystem = { getInfo = function() return nil end }

local Manager = require("src.scenes.manager")
local Menu = require("src.scenes.menu")
local Cards = require("src.cards")

local function findButton(buttons, labelSubstr)
	for _, b in ipairs(buttons) do
		if b.label:find(labelSubstr, 1, true) then return b end
	end
	return nil
end

local function assertTrue(cond, msg)
	if not cond then error("ASSERTION FAILED: " .. msg) end
end

Manager.updateScale()
Manager.switch(Menu)
assertTrue(Manager.current == Menu, "should start at Menu")
print("OK: Menu entered")

-- click "เล่นกับ AI บอท"
local aiBtn = findButton(Menu.buttons, "AI บอท")
assertTrue(aiBtn, "AI button should exist")
aiBtn.onClick()

local Lobby = require("src.scenes.lobby")
assertTrue(Manager.current == Lobby, "should be in Lobby after clicking vs AI")
assertTrue(Lobby.mode == "vsai", "lobby mode should be vsai")
print("OK: Lobby (vsai) entered")

local startBtn = findButton(Lobby.buttons, "เริ่มเกม")
assertTrue(startBtn, "start button should exist")
startBtn.onClick()

local RPS = require("src.scenes.rps")
assertTrue(Manager.current == RPS, "should be in RPS scene")
assertTrue(RPS.mode == "vsai", "rps mode should be vsai")
print("OK: RPS scene entered")

-- play rock-paper-scissors until decisive (cycle choices to dodge ties)
local seq = { "rock", "scissors", "paper" }
local seqI = 1
local guard = 0
while RPS.stage ~= "reveal" or (RPS.result and RPS.result.tie) do
	guard = guard + 1
	assertTrue(guard < 30, "RPS should resolve within reasonable attempts")
	if RPS.stage == "reveal" and RPS.result and RPS.result.tie then
		local rethrowBtn = findButton(RPS.buttons, "เป่าใหม่")
		assertTrue(rethrowBtn, "rethrow button should exist on tie")
		rethrowBtn.onClick()
	end
	if RPS.stage == "choose" then
		local labels = { rock = "ค้อน", scissors = "กรรไกร", paper = "กระดาษ" }
		local choice = seq[seqI]
		seqI = (seqI % 3) + 1
		local btn = findButton(RPS.buttons, labels[choice])
		assertTrue(btn, "choice button should exist for " .. choice)
		btn.onClick()
	end
end
print(string.format("OK: RPS resolved, tie=%s winnerSeat=%s", tostring(RPS.result.tie), tostring(RPS.result.winnerSeat)))

if RPS.result.winnerSeat == 1 then
	local goFirstBtn = findButton(RPS.buttons, "ไปก่อน")
	assertTrue(goFirstBtn, "go-first button should exist")
	goFirstBtn.onClick()
else
	local contBtn = findButton(RPS.buttons, "ดำเนินการต่อ")
	assertTrue(contBtn, "continue button should exist when AI wins")
	contBtn.onClick()
end

local Game = require("src.scenes.game")
assertTrue(Manager.current == Game, "should now be in the Game scene")
assertTrue(Game.match ~= nil, "Game should have a live Match")
assertTrue(Game.view ~= nil, "Game should have a view")
print(string.format("OK: Game scene entered, firstPlayer=%d, phase=%s", Game.match.activePlayerIndex, Game.view.phase))

-- run a full update/draw cycle to make sure nothing crashes
Game:update(0)
Game:draw()
print("OK: Game:update/draw ran without error")

-- ===== simulate real clicks: try to summon every affordable card across several turns =====
local function clickCenter(rect)
	local cx = rect.x + rect.w / 2
	local cy = rect.y + rect.h / 2
	Game:mousepressed(cx, cy, 1)
end

local function tryPlayHand()
	local playedAny = true
	local guard2 = 0
	while playedAny and guard2 < 10 do
		guard2 = guard2 + 1
		playedAny = false
		Game:refreshView()
		local seat = Game:viewSeat()
		if Game.view.activePlayerIndex == seat and Game.view.phase == "main" and not Game.view.reactionWindow then
			for _, slot in ipairs(Game.layout.hand) do
				local def = Cards.byId[slot.card.id]
				if def.type == "avatar" or def.type == "magic" or def.type == "construct" then
					local before = #Game.match.players[seat].hand
					clickCenter(slot)
					Game:draw()
					local after = #Game.match.players[seat].hand
					if after < before or Game.selection.mode ~= "idle" then
						playedAny = true
						if Game.selection.mode == "pickEnemyTarget" then
							local opp = Game.view.players[Game:oppSeat()]
							if opp.avatars[1] then clickCenter(Game.layout.oppAvatars[1]) end
							Game.selection = { mode = "idle" }
						elseif Game.selection.mode == "pickOwnTarget" then
							if Game.layout.myAvatars[1].avatar then clickCenter(Game.layout.myAvatars[1]) end
							Game.selection = { mode = "idle" }
						end
						break
					end
				end
			end
		else
			break
		end
	end
end

for turnIter = 1, 8 do
	-- handle any open reaction window first (pass through it)
	if Game.match.reactionWindow then
		local passBtn = findButton(Game.buttons, "ปล่อยผ่าน")
		if passBtn then passBtn.onClick() end
	end
	tryPlayHand()
	-- advance through phases via the actual "next phase" button
	for _ = 1, 3 do
		Game:refreshView()
		if Game.match.reactionWindow then
			local passBtn = findButton(Game.buttons, "ปล่อยผ่าน")
			if passBtn then passBtn.onClick() end
		end
		local nb = findButton(Game.buttons, "ถัดไป")
		if nb then nb.onClick() end
		Game:draw()
		if Game.view.gameOver then break end
	end
	if Game.view.gameOver then break end
end

print(string.format("OK: simulated %d turn iterations via real button clicks", 8))
print(string.format("Final: turn=%d gameOver=%s winner=%s p1avatars=%d p2avatars=%d p1life=%d p2life=%d",
	Game.match.turnNumber, tostring(Game.match.gameOver), tostring(Game.match.winner),
	#Game.match.players[1].avatars, #Game.match.players[2].avatars,
	#Game.match.players[1].life, #Game.match.players[2].life))

print("\nALL UI SMOKE TESTS PASSED")
