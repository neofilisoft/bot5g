-- src/engine/costcalc.lua
-- Pure functions operating on plain {id=...} references (as found in a
-- Match:serialize() view), mirroring the algorithm Match uses internally
-- (src/engine/match.lua effectiveCost/suggestCost) but without needing a
-- live Match object. Used by the UI to propose a cost combo - the host's
-- Match is always the final authority and will reject anything invalid.

local Cards = require("src.cards")

local M = {}

function M.costReduction(constructs, tribe)
	local r = 0
	for _, c in ipairs(constructs) do
		local def = Cards.byId[c.id]
		local ab = def and def.ability
		if ab and ab.kind == "construct_cost_reduction" and ab.tribe == tribe then
			r = r + (ab.amount or 0)
		end
	end
	return r
end

function M.effectiveCost(constructs, def)
	local base = def.cost or 0
	if def.type == "avatar" then
		base = base - M.costReduction(constructs, def.tribe)
	end
	if base < 0 then base = 0 end
	return base
end

-- hand: array of {uid=, id=}; excludeIndex: 1-based index not to use as fuel
function M.suggestCost(hand, excludeIndex, need)
	if need <= 0 then return {} end
	local candidates = {}
	for i, c in ipairs(hand) do
		if i ~= excludeIndex then
			local def = Cards.byId[c.id]
			candidates[#candidates + 1] = { i = i, gem = (def and def.gem) or 0 }
		end
	end
	table.sort(candidates, function(a, b) return a.gem > b.gem end)
	local chosen, sum = {}, 0
	for _, cand in ipairs(candidates) do
		if sum >= need then break end
		chosen[#chosen + 1] = cand.i
		sum = sum + cand.gem
	end
	if sum < need then return nil end
	return chosen
end

return M
