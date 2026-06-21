-- src/deck.lua
local C = require("src.constants")
local Cards = require("src.cards")

local Deck = {}

-- decklist = { {id="5G-001", n=3}, ... }  lifeIds = { "5G-008", ... } (5 unique-name cards)
-- Returns a flat array of card-def tables (NOT instances) for the main deck,
-- and a flat array for the life cards.
function Deck.build(decklist, lifeIds)
	local main = {}
	for _, entry in ipairs(decklist) do
		local def = Cards.byId[entry.id]
		assert(def, "unknown card id: " .. tostring(entry.id))
		for _ = 1, entry.n do
			main[#main + 1] = def
		end
	end
	local life = {}
	for _, id in ipairs(lifeIds) do
		local def = Cards.byId[id]
		assert(def, "unknown card id: " .. tostring(id))
		life[#life + 1] = def
	end
	return main, life
end

-- Validates: main deck has exactly DECK_SIZE cards, life has exactly
-- LIFE_COUNT cards with unique names, copy limits respected.
function Deck.validate(decklist, lifeIds)
	local errors = {}
	local total = 0
	local counts = {}
	for _, entry in ipairs(decklist) do
		local def = Cards.byId[entry.id]
		if not def then
			errors[#errors + 1] = "ไม่รู้จักการ์ด: " .. tostring(entry.id)
		else
			total = total + entry.n
			counts[entry.id] = (counts[entry.id] or 0) + entry.n
			local limit = def.onlyOne and 1 or C.MAX_COPIES
			if counts[entry.id] > limit then
				errors[#errors + 1] = string.format("%s ใส่ได้สูงสุด %d ใบ", def.name, limit)
			end
		end
	end
	if total ~= C.DECK_SIZE then
		errors[#errors + 1] = string.format("กองจั่วต้องมี %d ใบ (ตอนนี้มี %d)", C.DECK_SIZE, total)
	end
	if #lifeIds ~= C.LIFE_COUNT then
		errors[#errors + 1] = string.format("Life Card ต้องมี %d ใบ (ตอนนี้มี %d)", C.LIFE_COUNT, #lifeIds)
	end
	local seenNames = {}
	for _, id in ipairs(lifeIds) do
		local def = Cards.byId[id]
		if def then
			if seenNames[def.name] then
				errors[#errors + 1] = "Life Card ชื่อซ้ำกัน: " .. def.name
			end
			seenNames[def.name] = true
		end
	end
	return (#errors == 0), errors
end

function Deck.shuffle(arr, rng)
	rng = rng or math.random
	for i = #arr, 2, -1 do
		local j = math.floor(rng() * i) + 1
		arr[i], arr[j] = arr[j], arr[i]
	end
end

return Deck
