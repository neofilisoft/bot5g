-- conf.lua
function love.conf(t)
	t.window.title = "Battle of Talingchan 5G (Fanmade)"
	t.window.width = 1280
	t.window.height = 720
	t.window.resizable = true
	t.window.minwidth = 960
	t.window.minheight = 540
	t.window.vsync = 1
	t.console = false
	t.identity = "battle-of-talingchan-5g"
	t.version = "11.5"

	-- we don't use 3D/physics, keep startup lean
	t.modules.joystick = false
	t.modules.physics = false
	t.modules.video = false
end
