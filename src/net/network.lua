-- src/net/network.lua
-- Thin wrapper around LÖVE's bundled `enet` for a simple 1-host/1-client
-- match. Host is authoritative: it runs the real Match object and only
-- ever sends out filtered Match:serialize(viewerIndex) snapshots. The
-- client never simulates locally - it just renders the latest snapshot and
-- sends action requests to the host. This avoids any possibility of
-- desync between host and client.
--
-- NOTE ON "ROOMS": there is no central matchmaking/relay server here. The
-- host starts listening on a port and shares their IP:port (shown on
-- screen) with the other player ("Create Room"); the joining player enters
-- that IP:port directly ("Join Room"). This works over LAN out of the box;
-- playing over the open internet requires the host to port-forward (or a
-- relay server, which is a separate, optional addition).

local class = require("src.class")
local protocol = require("src.net.protocol")

local DEFAULT_PORT = 22122

local Network = class()

function Network:init(role)
	self.role = role -- "host" or "client"
	self.host = nil -- enet host object
	self.peer = nil -- the single remote peer
	self.connected = false
	self.onMessage = nil -- function(msgTable)
	self.onConnect = nil -- function()
	self.onDisconnect = nil -- function()
	self.lastError = nil
end

function Network.startHost(port)
	local ok, enet = pcall(require, "enet")
	if not ok then return nil, "ไม่พบไลบรารี enet (ต้องรันผ่าน LÖVE)" end
	port = port or DEFAULT_PORT
	local net = Network.new("host")
	local ok2, h = pcall(enet.host_create, "*:" .. tostring(port))
	if not ok2 or not h then
		return nil, "เปิดพอร์ต " .. tostring(port) .. " ไม่สำเร็จ (อาจถูกใช้งานอยู่)"
	end
	net.host = h
	net.port = port
	return net
end

function Network.startClient(address, port)
	local ok, enet = pcall(require, "enet")
	if not ok then return nil, "ไม่พบไลบรารี enet (ต้องรันผ่าน LÖVE)" end
	port = port or DEFAULT_PORT
	local net = Network.new("client")
	local h = enet.host_create()
	if not h then return nil, "สร้าง client ไม่สำเร็จ" end
	net.host = h
	local okc, peer = pcall(h.connect, h, address .. ":" .. tostring(port))
	if not okc or not peer then return nil, "เชื่อมต่อ " .. tostring(address) .. " ไม่สำเร็จ" end
	net.peer = peer
	return net
end

-- best-effort local IP guess, for showing the player what to share
function Network.guessLocalIP()
	local ok, socket = pcall(require, "socket")
	if not ok then return "127.0.0.1" end
	local ok2, s = pcall(socket.udp)
	if not ok2 or not s then return "127.0.0.1" end
	local okc = pcall(s.setpeername, s, "8.8.8.8", 80)
	if not okc then s:close(); return "127.0.0.1" end
	local ip = select(1, s:getsockname())
	s:close()
	return ip or "127.0.0.1"
end

function Network:send(msgTable)
	local str = protocol.encode(msgTable)
	if self.role == "host" then
		if self.peer then self.peer:send(str) end
	else
		if self.peer then self.peer:send(str) end
	end
end

function Network:update()
	if not self.host then return end
	local event = self.host:service(0)
	while event do
		if event.type == "connect" then
			self.peer = event.peer
			self.connected = true
			if self.onConnect then self.onConnect() end
		elseif event.type == "receive" then
			local ok, msg = protocol.decode(event.data)
			if ok and self.onMessage then self.onMessage(msg) end
		elseif event.type == "disconnect" then
			self.connected = false
			if self.onDisconnect then self.onDisconnect() end
		end
		event = self.host:service(0)
	end
end

function Network:close()
	if self.peer then pcall(function() self.peer:disconnect_now() end) end
	if self.host then pcall(function() self.host:flush() end) end
	self.host = nil
	self.peer = nil
	self.connected = false
end

Network.DEFAULT_PORT = DEFAULT_PORT

return Network
