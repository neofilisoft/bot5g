-- src/serialize.lua
-- A small, dependency-free JSON encoder/decoder.
--
-- IMPORTANT: this exists so that data coming from the network (which may be
-- sent by another player, i.e. untrusted) is parsed with a plain recursive
-- descent parser instead of Lua's load()/loadstring(). We never execute
-- code that arrives over the wire.

local json = {}

-- ===== encode =====

local escapes = {
	['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
}

local function encodeString(s)
	local out = { '"' }
	for i = 1, #s do
		local c = s:sub(i, i)
		out[#out + 1] = escapes[c] or c
	end
	out[#out + 1] = '"'
	return table.concat(out)
end

local encodeValue

local function isArray(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	local count = 0
	for i = 1, n do
		if t[i] == nil then return false, n end
		count = count + 1
	end
	return count == n, n
end

local function encodeTable(t)
	local arr, n = isArray(t)
	local out = {}
	if arr then
		out[#out + 1] = "["
		for i = 1, n do
			out[#out + 1] = encodeValue(t[i])
			if i < n then out[#out + 1] = "," end
		end
		out[#out + 1] = "]"
	else
		out[#out + 1] = "{"
		local first = true
		for k, v in pairs(t) do
			if not first then out[#out + 1] = "," end
			first = false
			out[#out + 1] = encodeString(tostring(k))
			out[#out + 1] = ":"
			out[#out + 1] = encodeValue(v)
		end
		out[#out + 1] = "}"
	end
	return table.concat(out)
end

encodeValue = function(v)
	local t = type(v)
	if t == "nil" then
		return "null"
	elseif t == "boolean" then
		return v and "true" or "false"
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return "0" end
		return tostring(v)
	elseif t == "string" then
		return encodeString(v)
	elseif t == "table" then
		return encodeTable(v)
	end
	return "null"
end

function json.encode(v)
	return encodeValue(v)
end

-- ===== decode =====

local function newParser(str)
	return { s = str, i = 1, n = #str }
end

local function skipWhitespace(p)
	while p.i <= p.n do
		local c = p.s:sub(p.i, p.i)
		if c == " " or c == "\t" or c == "\n" or c == "\r" then
			p.i = p.i + 1
		else
			break
		end
	end
end

local parseValue

local function parseString(p)
	p.i = p.i + 1 -- skip opening quote
	local out = {}
	while p.i <= p.n do
		local c = p.s:sub(p.i, p.i)
		if c == '"' then
			p.i = p.i + 1
			return table.concat(out)
		elseif c == "\\" then
			local nx = p.s:sub(p.i + 1, p.i + 1)
			if nx == "n" then out[#out + 1] = "\n"
			elseif nx == "t" then out[#out + 1] = "\t"
			elseif nx == "r" then out[#out + 1] = "\r"
			elseif nx == '"' then out[#out + 1] = '"'
			elseif nx == "\\" then out[#out + 1] = "\\"
			elseif nx == "/" then out[#out + 1] = "/"
			else out[#out + 1] = nx end
			p.i = p.i + 2
		else
			out[#out + 1] = c
			p.i = p.i + 1
		end
	end
	error("unterminated string")
end

local function parseNumber(p)
	local start = p.i
	while p.i <= p.n do
		local c = p.s:sub(p.i, p.i)
		if c:match("[%d%.%-%+eE]") then
			p.i = p.i + 1
		else
			break
		end
	end
	return tonumber(p.s:sub(start, p.i - 1))
end

local function parseArray(p)
	p.i = p.i + 1 -- [
	local out = {}
	skipWhitespace(p)
	if p.s:sub(p.i, p.i) == "]" then p.i = p.i + 1; return out end
	while true do
		skipWhitespace(p)
		out[#out + 1] = parseValue(p)
		skipWhitespace(p)
		local c = p.s:sub(p.i, p.i)
		if c == "," then
			p.i = p.i + 1
		elseif c == "]" then
			p.i = p.i + 1
			break
		else
			error("expected , or ] in array, got " .. tostring(c))
		end
	end
	return out
end

local function parseObject(p)
	p.i = p.i + 1 -- {
	local out = {}
	skipWhitespace(p)
	if p.s:sub(p.i, p.i) == "}" then p.i = p.i + 1; return out end
	while true do
		skipWhitespace(p)
		if p.s:sub(p.i, p.i) ~= '"' then error("expected string key") end
		local key = parseString(p)
		skipWhitespace(p)
		if p.s:sub(p.i, p.i) ~= ":" then error("expected :") end
		p.i = p.i + 1
		skipWhitespace(p)
		out[key] = parseValue(p)
		skipWhitespace(p)
		local c = p.s:sub(p.i, p.i)
		if c == "," then
			p.i = p.i + 1
		elseif c == "}" then
			p.i = p.i + 1
			break
		else
			error("expected , or } in object, got " .. tostring(c))
		end
	end
	return out
end

parseValue = function(p)
	skipWhitespace(p)
	local c = p.s:sub(p.i, p.i)
	if c == '"' then
		return parseString(p)
	elseif c == "{" then
		return parseObject(p)
	elseif c == "[" then
		return parseArray(p)
	elseif c == "t" then
		p.i = p.i + 4
		return true
	elseif c == "f" then
		p.i = p.i + 5
		return false
	elseif c == "n" then
		p.i = p.i + 4
		return nil
	else
		return parseNumber(p)
	end
end

-- Returns ok, value (or ok=false, errorMessage)
function json.decode(str)
	if type(str) ~= "string" or #str == 0 then return false, "empty" end
	local p = newParser(str)
	local ok, result = pcall(function()
		skipWhitespace(p)
		return parseValue(p)
	end)
	if not ok then return false, result end
	return true, result
end

return json
