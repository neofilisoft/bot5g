-- src/ui/board.lua
local Theme = require("src.ui.theme")
local Cards = require("src.cards")
local C = require("src.constants")
local CardArt = require("src.ui.cardart")

local Board = {}

local VW, VH = 1600, 900
Board.VW, Board.VH = VW, VH
local PLAY_W = 1320

local SLOT_W, SLOT_H = 140, 170
local SLOT_GAP = 16
local HAND_W, HAND_H = 120, 160

local function avatarSlotX(i, n)
	n = n or 4
	local totalW = n * SLOT_W + (n - 1) * SLOT_GAP
	local startX = (PLAY_W - totalW) / 2
	return startX + (i - 1) * (SLOT_W + SLOT_GAP)
end

-- ===================== layout =====================
-- Returns a table describing every clickable rect on the battlefield, plus
-- where to draw zone backgrounds. Used by both Board.draw and by the game
-- scene's hit-testing.
function Board.computeLayout(view, mySeat)
	local oppSeat = (mySeat == 1) and 2 or 1
	local opp = view.players[oppSeat]
	local mine = view.players[mySeat]

	local layout = {
		oppSeat = oppSeat, mySeat = mySeat,
		oppAvatars = {}, myAvatars = {},
		oppConstructs = {}, myConstructs = {},
		hand = {},
		land = { x = (PLAY_W - 110) / 2, y = 350, w = 110, h = 150 },
		oppLifeBar = { x = 20, y = 10, w = 900, h = 50 },
		myLifeBar = { x = 20, y = 650, w = 900, h = 50 },
		oppInfo = { x = 950, y = 10, w = 350, h = 50 },
		myInfo = { x = 950, y = 650, w = 350, h = 50 },
	}

	for i = 1, C.MAX_AVATAR_SLOTS do
		layout.oppAvatars[i] = { x = avatarSlotX(i), y = 70, w = SLOT_W, h = SLOT_H, avatar = opp.avatars[i] }
		layout.myAvatars[i] = { x = avatarSlotX(i), y = 530, w = SLOT_W, h = SLOT_H, avatar = mine.avatars[i] }
	end

	for i, c in ipairs(opp.constructs) do
		layout.oppConstructs[i] = { x = 950 + (i - 1) * 100, y = 70, w = 90, h = 110, card = c }
	end
	for i, c in ipairs(mine.constructs) do
		layout.myConstructs[i] = { x = 950 + (i - 1) * 100, y = 530, w = 90, h = 110, card = c }
	end

	local n = math.max(1, #mine.hand)
	local spacing = math.min(HAND_W + 10, (PLAY_W - 40) / n)
	local totalW = spacing * (n - 1) + HAND_W
	local startX = (PLAY_W - totalW) / 2
	for i, c in ipairs(mine.hand) do
		layout.hand[i] = { x = startX + (i - 1) * spacing, y = 715, w = HAND_W, h = HAND_H, card = c, handIndex = i }
	end

	return layout
end

-- ===================== drawing helpers =====================

local function wrapName(name)
	if #name > 26 then return name:sub(1, 24) .. "…" end
	return name
end

local function drawCardArtCover(img, x, y, w, h)
	local iw, ih = img:getWidth(), img:getHeight()
	local scale = math.max(w / iw, h / ih)
	local dw, dh = iw * scale, ih * scale
	local ox, oy = x + (w - dw) / 2, y + (h - dh) / 2
	love.graphics.setScissor(x, y, w, h)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(img, ox, oy, 0, scale, scale)
	love.graphics.setScissor()
end

local function drawCardFace(x, y, w, h, def, opts)
	opts = opts or {}
	local typeColor = Theme.cardColor(def)
	local rarColor = Theme.rarityColor(def)
	local art = CardArt.get(def.id)

	Theme.rect(x, y, w, h, 10, { 0.10, 0.11, 0.15 })

	if art then
		drawCardArtCover(art, x, y, w, h)
	else
		love.graphics.setScissor(x, y, w, 26)
		Theme.rect(x, y, w, 26, 10, typeColor)
		love.graphics.setScissor()

		love.graphics.setFont(Theme.fonts.tiny)
		Theme.setColor({ 1, 1, 1 })
		local label = def.type == "avatar" and (def.tribe or "Avatar")
			or def.type == "construct" and "Construct"
			or (def.magicType or "magic")
		love.graphics.printf(label, x + 4, y + 6, w - 8, "left")

		love.graphics.setFont(Theme.fonts.small)
		Theme.setColor(Theme.color.text)
		love.graphics.printf(wrapName(def.name), x + 6, y + 30, w - 12, "left")
	end

	-- cost pip (bottom-left circle)
	love.graphics.setColor(Theme.color.gem)
	love.graphics.circle("fill", x + 16, y + h - 18, 13)
	love.graphics.setColor(0, 0, 0)
	love.graphics.setFont(Theme.fonts.small)
	love.graphics.printf(tostring(def.cost or 0), x, y + h - 27, 32, "center")

	if def.type == "avatar" then
		love.graphics.setColor(Theme.color.power)
		love.graphics.circle("fill", x + w - 18, y + h - 18, 15)
		love.graphics.setColor(0, 0, 0)
		love.graphics.printf(tostring(opts.power or def.power or 0), x + w - 36, y + h - 27, 32, "center")
	end

	Theme.outlineRect(x, y, w, h, 10, rarColor, opts.highlight and 4 or 2)

	if opts.tapped then
		love.graphics.setColor(0, 0, 0, 0.45)
		love.graphics.rectangle("fill", x, y, w, h, 10, 10)
		love.graphics.setColor(1, 1, 1, 0.7)
		love.graphics.setFont(Theme.fonts.tiny)
		love.graphics.printf("ใช้แล้ว", x, y + h / 2 - 7, w, "center")
	end

	if opts.dim then
		love.graphics.setColor(0, 0, 0, 0.55)
		love.graphics.rectangle("fill", x, y, w, h, 10, 10)
	end

	if opts.selectable then
		love.graphics.setColor(Theme.color.good[1], Theme.color.good[2], Theme.color.good[3], 0.18)
		love.graphics.rectangle("fill", x, y, w, h, 10, 10)
		Theme.outlineRect(x, y, w, h, 10, Theme.color.good, 3)
	end
end

local function withCardTransform(uid, fx, x, y, w, h, drawFn)
	local anim = fx and fx.anim and fx.anim[uid]
	local hover = fx and fx.hoverAnim and fx.hoverAnim[uid]
	local liftPx = hover and (hover.lift or 0) * 16 or 0
	local ox, oy, scale = 0, 0, 1
	if anim then ox, oy, scale = anim.x or 0, anim.y or 0, anim.scale or 1 end
	if ox == 0 and oy == 0 and scale == 1 and liftPx == 0 then
		drawFn()
		return
	end
	local cx, cy = x + w / 2, y + h / 2
	love.graphics.push()
	love.graphics.translate(cx + ox, cy + oy - liftPx)
	love.graphics.scale(scale, scale)
	love.graphics.translate(-cx, -cy)
	drawFn()
	love.graphics.pop()
end

local function drawEmptySlot(x, y, w, h, hint)
	Theme.outlineRect(x, y, w, h, 10, { 0.25, 0.27, 0.33 }, 1)
	if hint then
		love.graphics.setFont(Theme.fonts.tiny)
		Theme.setColor(Theme.color.textDim)
		love.graphics.printf(hint, x, y + h / 2 - 7, w, "center")
	end
end

local function drawLifeBar(x, y, w, h, p, label)
	love.graphics.setFont(Theme.fonts.label)
	Theme.setColor(Theme.color.text)
	love.graphics.printf(string.format("%s %s", label, p.name), x, y, w, "left")
	local pipR = 9
	for i = 1, C.LIFE_COUNT do
		local cx = x + 4 + (i - 1) * (pipR * 2 + 6) + pipR
		local cy = y + 32
		if i <= p.lifeCount then
			love.graphics.setColor(Theme.color.bad)
		else
			love.graphics.setColor(0.25, 0.25, 0.3)
		end
		love.graphics.circle("fill", cx, cy, pipR)
	end
	if p.critical then
		love.graphics.setFont(Theme.fonts.small)
		Theme.setColor(Theme.color.bad)
		love.graphics.print("[สาหัส!]", x + 4 + C.LIFE_COUNT * (pipR * 2 + 6) + 10, y + 24)
	end
	love.graphics.setFont(Theme.fonts.tiny)
	Theme.setColor(Theme.color.textDim)
	love.graphics.print(string.format("กองจั่ว %d  มือ %d", p.deckCount, p.handCount), x, y + 38)
end

-- ===================== main draw =====================
-- selection: { mode="idle"|"choosingAttackerTarget"|"choosingMagicTarget",
--              attackerUid=.., highlightUids={[uid]=true}, lifeTargetEnabled=bool,
--              selectedHandIndex=.. }
function Board.draw(view, mySeat, layout, selection, fx)
	selection = selection or {}
	local highlight = selection.highlightUids or {}

	love.graphics.setColor(Theme.color.bg)
	love.graphics.rectangle("fill", 0, 0, PLAY_W, VH)

	-- info bars
	drawLifeBar(layout.oppLifeBar.x, layout.oppLifeBar.y, layout.oppLifeBar.w, layout.oppLifeBar.h, view.players[layout.oppSeat], "คู่ต่อสู้:")
	drawLifeBar(layout.myLifeBar.x, layout.myLifeBar.y, layout.myLifeBar.w, layout.myLifeBar.h, view.players[layout.mySeat], "คุณ:")

	-- avatars
	for _, slot in ipairs(layout.oppAvatars) do
		if slot.avatar then
			local def = Cards.byId[slot.avatar.id]
			withCardTransform(slot.avatar.uid, fx, slot.x, slot.y, slot.w, slot.h, function()
				drawCardFace(slot.x, slot.y, slot.w, slot.h, def, {
					selectable = highlight[slot.avatar.uid],
					tapped = false,
				})
			end)
		else
			drawEmptySlot(slot.x, slot.y, slot.w, slot.h)
		end
	end
	for _, slot in ipairs(layout.myAvatars) do
		if slot.avatar then
			local def = Cards.byId[slot.avatar.id]
			local isSelectedAttacker = selection.attackerUid == slot.avatar.uid
			withCardTransform(slot.avatar.uid, fx, slot.x, slot.y, slot.w, slot.h, function()
				drawCardFace(slot.x, slot.y, slot.w, slot.h, def, {
					tapped = slot.avatar.tapped,
					highlight = isSelectedAttacker,
					selectable = highlight[slot.avatar.uid] and not slot.avatar.tapped,
				})
			end)
		else
			drawEmptySlot(slot.x, slot.y, slot.w, slot.h)
		end
	end

	-- constructs
	for _, slot in ipairs(layout.oppConstructs) do
		withCardTransform(slot.card.uid, fx, slot.x, slot.y, slot.w, slot.h, function()
			drawCardFace(slot.x, slot.y, slot.w, slot.h, Cards.byId[slot.card.id])
		end)
	end
	for _, slot in ipairs(layout.myConstructs) do
		withCardTransform(slot.card.uid, fx, slot.x, slot.y, slot.w, slot.h, function()
			drawCardFace(slot.x, slot.y, slot.w, slot.h, Cards.byId[slot.card.id])
		end)
	end

	-- land (shared)
	love.graphics.setFont(Theme.fonts.tiny)
	Theme.setColor(Theme.color.textDim)
	love.graphics.printf("Land Magic (กลางสนาม)", layout.land.x - 30, layout.land.y - 18, layout.land.w + 60, "center")
	if view.land then
		withCardTransform(view.land.uid, fx, layout.land.x, layout.land.y, layout.land.w, layout.land.h, function()
			drawCardFace(layout.land.x, layout.land.y, layout.land.w, layout.land.h, Cards.byId[view.land.id])
		end)
	else
		drawEmptySlot(layout.land.x, layout.land.y, layout.land.w, layout.land.h, "ว่าง")
	end

	-- opponent life zone click target (shown as a glowing strip when targetable)
	if selection.lifeTargetEnabled then
		local r = layout.oppLifeBar
		love.graphics.setColor(Theme.color.good[1], Theme.color.good[2], Theme.color.good[3], 0.22)
		love.graphics.rectangle("fill", r.x - 10, r.y - 6, r.w + 20, r.h + 16, 8, 8)
		Theme.outlineRect(r.x - 10, r.y - 6, r.w + 20, r.h + 16, 8, Theme.color.good, 3)
	end

	-- hand
	for _, slot in ipairs(layout.hand) do
		local def = Cards.byId[slot.card.id]
		local isSelected = selection.selectedHandIndex == slot.handIndex
		withCardTransform(slot.card.uid, fx, slot.x, slot.y, slot.w, slot.h, function()
			drawCardFace(slot.x, slot.y, slot.w, slot.h, def, {
				highlight = isSelected,
				dim = selection.dimHandExcept and not isSelected and not (selection.costSet and selection.costSet[slot.handIndex]),
			})
			if selection.costSet and selection.costSet[slot.handIndex] then
				love.graphics.setColor(Theme.color.gem)
				love.graphics.setFont(Theme.fonts.tiny)
				love.graphics.printf("ค่าใช้จ่าย", slot.x, slot.y - 16, slot.w, "center")
			end
		end)
	end
end

return Board
