-- src/engine/player.lua
local class = require("src.class")
local C = require("src.constants")

local Player = class()

function Player:init(index, name)
	self.index = index -- 1 or 2
	self.name = name or ("Player " .. index)
	self.deck = {} -- array of CardInstance, top of deck = deck[#deck]
	self.hand = {} -- array of CardInstance
	self.graveyard = {} -- array of CardInstance
	self.avatars = {} -- array of CardInstance, up to MAX_AVATAR_SLOTS (sparse-safe, but we keep compact)
	self.life = {} -- array of CardInstance, up to LIFE_COUNT
	self.land = nil -- single CardInstance or nil
	self.constructs = {} -- array of CardInstance
	self.critical = false -- true once life cards have all been destroyed once
end

function Player:isDefeated()
	return self.critical and self.lifeDepletedTwice
end

function Player:avatarCount()
	return #self.avatars
end

function Player:hasOpenAvatarSlot()
	return #self.avatars < C.MAX_AVATAR_SLOTS
end

function Player:findAvatar(uid)
	for i, a in ipairs(self.avatars) do
		if a.uid == uid then return a, i end
	end
	return nil
end

function Player:removeAvatarAt(i)
	return table.remove(self.avatars, i)
end

return Player
