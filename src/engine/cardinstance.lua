-- src/engine/cardinstance.lua
local class = require("src.class")

local CardInstance = class()

local nextUid = 1

function CardInstance:init(def, owner)
	self.uid = nextUid
	nextUid = nextUid + 1
	self.def = def -- the static card definition (from src/cards.lua)
	self.owner = owner -- player index (1 or 2)
	self.tapped = false -- has attacked / used this turn
	self.summonTurn = nil -- turn number it was summoned on (for "newly summoned" checks)
	self.weapons = {} -- attached weapon CardInstances (for avatars)
	self.basePowerBonus = 0 -- permanent bonuses applied directly to this instance (rare, kept for flexibility)
end

function CardInstance:currentPower()
	local p = self.def.power or 0
	p = p + self.basePowerBonus
	for _, w in ipairs(self.weapons) do
		if w.def.ability and w.def.ability.kind == "weapon_buff" then
			p = p + (w.def.ability.power or 0)
		end
	end
	return p
end

function CardInstance:isNewlySummoned(currentTurn)
	return self.summonTurn == currentTurn
end

return CardInstance
