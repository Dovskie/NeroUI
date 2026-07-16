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

	local data = {}
	for flagName, component in _registry do
		local ok, value = pcall(function()
			return component:GetValue()
		end)
		if ok then
			data[flagName] = serializeValue(value)
		end
	end

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

	for flagName, rawValue in data do
		local component = _registry[flagName]
		if component then
			pcall(function()
				component:SetValue(deserializeValue(rawValue), false)
			end)
		end
	end

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