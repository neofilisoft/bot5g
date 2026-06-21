-- src/ui/cardart.lua
-- Optional custom artwork loader. If a file exists at
-- assets/cards/<card-id>.png (or .jpg), it is loaded and used to render
-- that card instead of the built-in styled placeholder. If no such file
-- exists, CardArt.get() simply returns nil and the caller falls back to
-- the default look.
--
-- This project does NOT ship any third-party/official card art by default
-- - this loader exists so a user can drop their own legitimately-sourced
-- images into assets/cards/ in their own local copy if they choose to.

local CardArt = {}

local cache = {}
local checked = {}
local EXTENSIONS = { "png", "jpg", "jpeg" }

function CardArt.get(cardId)
	if checked[cardId] then return cache[cardId] end
	checked[cardId] = true
	for _, ext in ipairs(EXTENSIONS) do
		local path = "assets/cards/" .. cardId .. "." .. ext
		local info = love.filesystem.getInfo(path)
		if info then
			local ok, img = pcall(love.graphics.newImage, path)
			if ok and img then
				img:setFilter("linear", "linear")
				cache[cardId] = img
				return img
			end
		end
	end
	return nil
end

-- call if you ever hot-swap files at runtime (not needed in normal play)
function CardArt.clearCache()
	cache, checked = {}, {}
end

return CardArt
