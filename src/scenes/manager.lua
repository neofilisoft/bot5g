-- src/scenes/manager.lua
local Manager = {}

Manager.current = nil
Manager.VW, Manager.VH = 1600, 900
Manager.scaleX, Manager.scaleY = 1, 1

function Manager.switch(scene, ...)
	if Manager.current and Manager.current.leave then Manager.current:leave() end
	Manager.current = scene
	if scene.enter then scene:enter(...) end
end

-- converts real window coords to our virtual 1600x900 canvas coords
function Manager.toVirtual(x, y)
	return x / Manager.scaleX, y / Manager.scaleY
end

function Manager.updateScale()
	local w, h = love.graphics.getDimensions()
	Manager.scaleX = w / Manager.VW
	Manager.scaleY = h / Manager.VH
end

function Manager.update(dt)
	if Manager.current and Manager.current.update then Manager.current:update(dt) end
end

function Manager.draw()
	love.graphics.push()
	love.graphics.scale(Manager.scaleX, Manager.scaleY)
	if Manager.current and Manager.current.draw then Manager.current:draw() end
	love.graphics.pop()
end

function Manager.mousepressed(x, y, btn)
	local vx, vy = Manager.toVirtual(x, y)
	if Manager.current and Manager.current.mousepressed then Manager.current:mousepressed(vx, vy, btn) end
end

function Manager.mousemoved(x, y)
	local vx, vy = Manager.toVirtual(x, y)
	if Manager.current and Manager.current.mousemoved then Manager.current:mousemoved(vx, vy) end
end

function Manager.keypressed(key)
	if Manager.current and Manager.current.keypressed then Manager.current:keypressed(key) end
end

function Manager.textinput(t)
	if Manager.current and Manager.current.textinput then Manager.current:textinput(t) end
end

return Manager
