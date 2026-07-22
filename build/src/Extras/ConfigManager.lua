local HttpService = game:GetService("HttpService")

local Import = ...

local ConfigManager = {}

local ROOT_FOLDER = "NeroUI"
local CONFIG_FOLDER = "NeroUI/Configs"

local _registry = {}

local function hasFileSupport()
	return writefile ~= nil and readfile ~= nil and isfile ~= nil and makefolder ~= nil and isfolder ~= nil
end

local function ensureFolders()
	if not isfolder(ROOT_FOLDER) then
		makefolder(ROOT_FOLDER)
	end
	if not isfolder(CONFIG_FOLDER) then
		makefolder(CONFIG_FOLDER)
	end
end

local function serializeValue(value)
	if typeof(value) == "Color3" then
		return { __type = "Color3", R = value.R, G = value.G, B = value.B }
	end
	if typeof(value) == "EnumItem" then
		return { __type = "EnumItem", EnumType = tostring(value.EnumType), Name = value.Name }
	end
	return value
end

local function deserializeValue(value)
	if type(value) == "table" and value.__type == "Color3" then
		return Color3.new(value.R, value.G, value.B)
	end
	if type(value) == "table" and value.__type == "EnumItem" then
		local enumTable = Enum[value.EnumType]
		return enumTable and enumTable[value.Name]
	end
	return value
end

local function base64EncodeFallback(data)
	local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local result = {}
	local byteCount = #data

	for i = 1, byteCount, 3 do
		local b1, b2, b3 = string.byte(data, i, i + 2)
		b2 = b2 or 0
		b3 = b3 or 0

		local n = bit32.lshift(b1, 16) + bit32.lshift(b2, 8) + b3

		local c1 = bit32.band(bit32.rshift(n, 18), 0x3F)
		local c2 = bit32.band(bit32.rshift(n, 12), 0x3F)
		local c3 = bit32.band(bit32.rshift(n, 6), 0x3F)
		local c4 = bit32.band(n, 0x3F)

		local remaining = byteCount - i + 1
		table.insert(result, string.sub(B64_CHARS, c1 + 1, c1 + 1))
		table.insert(result, string.sub(B64_CHARS, c2 + 1, c2 + 1))
		table.insert(result, remaining >= 2 and string.sub(B64_CHARS, c3 + 1, c3 + 1) or "=")
		table.insert(result, remaining >= 3 and string.sub(B64_CHARS, c4 + 1, c4 + 1) or "=")
	end

	return table.concat(result)
end

local function base64DecodeFallback(data)
	local B64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	data = data:gsub("[^%a%d%+%/%=]", "")

	local lookup = {}
	for index = 1, #B64_CHARS do
		lookup[string.sub(B64_CHARS, index, index)] = index - 1
	end

	local result = {}
	local i = 1
	local len = #data

	while i <= len do
		local c1 = lookup[string.sub(data, i, i)]
		local c2 = lookup[string.sub(data, i + 1, i + 1)]
		local s3 = string.sub(data, i + 2, i + 2)
		local s4 = string.sub(data, i + 3, i + 3)
		local c3 = lookup[s3]
		local c4 = lookup[s4]

		assert(c1 and c2, "base64Decode: input corrupt")

		local n = bit32.lshift(c1, 18) + bit32.lshift(c2, 12) + bit32.lshift(c3 or 0, 6) + (c4 or 0)

		table.insert(result, string.char(bit32.band(bit32.rshift(n, 16), 0xFF)))
		if s3 ~= "=" and s3 ~= "" then
			table.insert(result, string.char(bit32.band(bit32.rshift(n, 8), 0xFF)))
		end
		if s4 ~= "=" and s4 ~= "" then
			table.insert(result, string.char(bit32.band(n, 0xFF)))
		end

		i += 4
	end

	return table.concat(result)
end

local function base64Encode(data)
	if crypt and crypt.base64encode then
		return crypt.base64encode(data)
	end
	return base64EncodeFallback(data)
end

local function base64Decode(data)
	if crypt and crypt.base64decode then
		return crypt.base64decode(data)
	end
	return base64DecodeFallback(data)
end

local EXPORT_PREFIX = "NEROUI1:"

local function collectData()
	local data = {}
	for flagName, component in _registry do
		local ok, value = pcall(function()
			return component:GetValue()
		end)
		if ok then
			data[flagName] = serializeValue(value)
		end
	end
	return data
end

local function applyData(data)
	for flagName, rawValue in data do
		local component = _registry[flagName]
		if component then
			pcall(function()
				component:SetValue(deserializeValue(rawValue), false)
			end)
		end
	end
end

function ConfigManager.Register(flagName, component)
	assert(type(flagName) == "string" and flagName ~= "", "ConfigManager.Register butuh flagName berupa string")
	assert(component ~= nil and component.GetValue and component.SetValue,
		"ConfigManager.Register butuh komponen yang punya method :GetValue() dan :SetValue()")

	_registry[flagName] = component
end

function ConfigManager.Unregister(flagName)
	_registry[flagName] = nil
end

function ConfigManager.Save(name)
	if not hasFileSupport() then
		return false, "Executor ga support writefile/readfile, ga bisa save config"
	end

	ensureFolders()

	local data = collectData()

	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
	if not ok then
		return false, "Gagal encode config jadi JSON: " .. tostring(encoded)
	end

	local path = CONFIG_FOLDER .. "/" .. name .. ".json"
	local writeOk, writeErr = pcall(writefile, path, encoded)
	if not writeOk then
		return false, "Gagal nulis file: " .. tostring(writeErr)
	end

	return true
end

function ConfigManager.Load(name)
	if not hasFileSupport() then
		return false, "Executor ga support writefile/readfile, ga bisa load config"
	end

	local path = CONFIG_FOLDER .. "/" .. name .. ".json"
	if not isfile(path) then
		return false, "Config \"" .. name .. "\" ga ketemu"
	end

	local readOk, content = pcall(readfile, path)
	if not readOk then
		return false, "Gagal baca file: " .. tostring(content)
	end

	local decodeOk, data = pcall(HttpService.JSONDecode, HttpService, content)
	if not decodeOk then
		return false, "Gagal decode JSON, file config kemungkinan corrupt"
	end

	applyData(data)

	return true
end

function ConfigManager.Export()
	local data = collectData()

	local encodeOk, encoded = pcall(HttpService.JSONEncode, HttpService, data)
	if not encodeOk then
		return nil, "Gagal encode config jadi JSON: " .. tostring(encoded)
	end

	local b64Ok, b64 = pcall(base64Encode, encoded)
	if not b64Ok then
		return nil, "Gagal encode base64: " .. tostring(b64)
	end

	return EXPORT_PREFIX .. b64
end

function ConfigManager.Import(str)
	assert(type(str) == "string" and str ~= "", "ConfigManager.Import butuh string")

	local payload = str
	if str:sub(1, #EXPORT_PREFIX) == EXPORT_PREFIX then
		payload = str:sub(#EXPORT_PREFIX + 1)
	end

	local b64Ok, decoded = pcall(base64Decode, payload)
	if not b64Ok then
		return false, "String config ga valid atau corrupt"
	end

	local jsonOk, data = pcall(HttpService.JSONDecode, HttpService, decoded)
	if not jsonOk or type(data) ~= "table" then
		return false, "String config ga valid atau corrupt"
	end

	applyData(data)

	return true
end

function ConfigManager.ListConfigs()
	if not hasFileSupport() or not (listfiles and isfolder(CONFIG_FOLDER)) then
		return {}
	end

	local names = {}
	for _, path in listfiles(CONFIG_FOLDER) do
		local fileName = path:match("([^/\\]+)%.json$")
		if fileName then
			table.insert(names, fileName)
		end
	end
	return names
end

function ConfigManager.DeleteConfig(name)
	if not hasFileSupport() then
		return false
	end
	local path = CONFIG_FOLDER .. "/" .. name .. ".json"
	if isfile(path) then
		delfile(path)
		return true
	end
	return false
end

return ConfigManager