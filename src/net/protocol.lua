-- src/net/protocol.lua
local json = require("src.serialize")

local P = {}

P.HELLO = "hello" -- C->H  {name=...}
P.WELCOME = "welcome" -- H->C  {seat=1|2, name=...}
P.STATE = "state" -- H->C  {view=<serialized match view>}
P.ACTION = "action" -- C->H  {action={kind=..., ...}}
P.ERROR = "error" -- H->C  {message=...}
P.CHAT = "chat" -- both ways {from=.., text=..}
P.START = "start" -- H->C  signals match has begun
P.PING = "ping"
P.PONG = "pong"
P.RPS_CHOICE = "rps_choice" -- C->H  {choice="rock"|"scissors"|"paper"}
P.RPS_RESULT = "rps_result" -- H->C  {hostChoice=, clientChoice=, tie=bool, winnerSeat=1|2}
P.RPS_FIRSTPICK = "rps_firstpick" -- C->H  {goFirst=bool}  (sent only if client won the throw)

function P.encode(msgTable)
	return json.encode(msgTable)
end

-- returns ok, msgTable_or_errorString
function P.decode(str)
	local ok, t = json.decode(str)
	if not ok then return false, t end
	if type(t) ~= "table" or type(t.t) ~= "string" then return false, "malformed message" end
	return true, t
end

return P
