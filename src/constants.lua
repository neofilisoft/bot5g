-- src/constants.lua
local Const = {}

Const.Zone = {
	DECK = "deck",
	HAND = "hand",
	GRAVEYARD = "graveyard",
	AVATAR = "avatar", -- array, up to MAX_AVATAR_SLOTS
	MAGIC = "magic", -- resolved/attached magic sitting in play (weapons attached to avatars live on the avatar itself)
	LIFE = "life", -- array, up to LIFE_COUNT, face-down
	LAND = "land", -- single slot: the active Land Magic
	CONSTRUCT = "construct", -- array of constructs in play
}

Const.Phase = {
	DRAW = "draw",
	MAIN = "main",
	ATTACK = "attack",
	END = "end",
}

Const.PHASE_ORDER = { Const.Phase.DRAW, Const.Phase.MAIN, Const.Phase.ATTACK, Const.Phase.END }

Const.CardType = {
	AVATAR = "avatar",
	MAGIC = "magic",
	CONSTRUCT = "construct",
}

Const.MagicType = {
	LAND = "land", -- affects both players, sits in Land Magic Zone
	WEAPON = "weapon", -- modification, attaches to an avatar
	NORMAL = "normal", -- one-shot, goes to graveyard after resolving
	COUNTER = "counter", -- played in reaction, usually on opponent's turn
}

Const.MAX_AVATAR_SLOTS = 4
Const.LIFE_COUNT = 5
Const.DECK_SIZE = 50
Const.MAX_COPIES = 3 -- per non-"Only One" card name
Const.STARTING_HAND = 5

return Const
