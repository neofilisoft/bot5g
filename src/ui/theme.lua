-- src/ui/theme.lua
local Theme = {}

Theme.color = {
	bg = { 0.07, 0.08, 0.11 },
	bgPanel = { 0.11, 0.12, 0.16, 0.92 },
	bgPanel2 = { 0.14, 0.15, 0.20, 0.95 },
	border = { 0.30, 0.32, 0.40 },
	text = { 0.92, 0.93, 0.96 },
	textDim = { 0.62, 0.64, 0.72 },
	accent = { 0.36, 0.62, 1.00 }, -- blue
	accent2 = { 0.95, 0.55, 0.20 }, -- orange (5G branding)
	good = { 0.40, 0.85, 0.55 },
	bad = { 0.92, 0.35, 0.38 },
	gem = { 0.45, 0.85, 0.95 },
	power = { 0.95, 0.55, 0.35 },

	-- card type accents
	typeAvatar = { 0.30, 0.55, 0.95 },
	typeMagicNormal = { 0.62, 0.42, 0.90 },
	typeMagicLand = { 0.45, 0.75, 0.45 },
	typeMagicWeapon = { 0.85, 0.55, 0.30 },
	typeMagicCounter = { 0.85, 0.35, 0.55 },
	typeConstruct = { 0.80, 0.65, 0.25 },

	-- rarity border
	rarityC = { 0.55, 0.56, 0.60 },
	rarityR = { 0.35, 0.60, 0.95 },
	raritySR = { 0.70, 0.40, 0.95 },
	rarityUR = { 0.95, 0.80, 0.25 },
}

function Theme.cardColor(def)
	if not def then return Theme.color.border end
	if def.type == "avatar" then return Theme.color.typeAvatar end
	if def.type == "construct" then return Theme.color.typeConstruct end
	if def.type == "magic" then
		if def.magicType == "land" then return Theme.color.typeMagicLand end
		if def.magicType == "weapon" then return Theme.color.typeMagicWeapon end
		if def.magicType == "counter" then return Theme.color.typeMagicCounter end
		return Theme.color.typeMagicNormal
	end
	return Theme.color.border
end

function Theme.rarityColor(def)
	if not def or not def.rarity then return Theme.color.rarityC end
	if def.rarity == "R" then return Theme.color.rarityR end
	if def.rarity == "SR" then return Theme.color.raritySR end
	if def.rarity == "UR" then return Theme.color.rarityUR end
	return Theme.color.rarityC
end

Theme.fonts = {}

function Theme.loadFonts()
	local base = "assets/fonts/"
	Theme.fonts.tiny = love.graphics.newFont(base .. "Kanit-Regular.ttf", 12)
	Theme.fonts.small = love.graphics.newFont(base .. "Kanit-Regular.ttf", 14)
	Theme.fonts.body = love.graphics.newFont(base .. "Kanit-Regular.ttf", 17)
	Theme.fonts.label = love.graphics.newFont(base .. "Kanit-SemiBold.ttf", 18)
	Theme.fonts.heading = love.graphics.newFont(base .. "Kanit-Bold.ttf", 28)
	Theme.fonts.title = love.graphics.newFont(base .. "Kanit-Bold.ttf", 48)
end

function Theme.setColor(c, a)
	love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end

function Theme.rect(x, y, w, h, radius, color, mode)
	mode = mode or "fill"
	Theme.setColor(color)
	love.graphics.rectangle(mode, x, y, w, h, radius or 6, radius or 6)
end

function Theme.outlineRect(x, y, w, h, radius, color, lineWidth)
	love.graphics.setLineWidth(lineWidth or 2)
	Theme.setColor(color)
	love.graphics.rectangle("line", x, y, w, h, radius or 6, radius or 6)
end

return Theme
