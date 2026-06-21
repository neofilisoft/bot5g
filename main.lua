-- main.lua
-- Battle of Talingchan 5G (Fanmade)
-- An unofficial fan expansion implementing the real Battle of Talingchan
-- ruleset with an original, 100% fan-made "5G internet meme" card set.
-- Built with LÖVE 11.5.

local Manager = require("src.scenes.manager")
local Theme = require("src.ui.theme")

function love.load()
	math.randomseed(os.time())
	love.graphics.setDefaultFilter("linear", "linear")
	Theme.loadFonts()
	Manager.updateScale()
	local Menu = require("src.scenes.menu")
	Manager.switch(Menu)
end

function love.update(dt)
	Manager.update(dt)
end

function love.draw()
	Manager.draw()
end

function love.mousepressed(x, y, button)
	Manager.mousepressed(x, y, button)
end

function love.mousemoved(x, y)
	Manager.mousemoved(x, y)
end

function love.keypressed(key)
	Manager.keypressed(key)
end

function love.textinput(t)
	Manager.textinput(t)
end

function love.resize(w, h)
	Manager.updateScale()
end
