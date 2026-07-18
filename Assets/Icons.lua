local Import = ...
local Create = Import("Core/Create")

local Icons = {}

local _icons = {}
local _lucide = nil
local _lucideLoadAttempted = false

local LUCIDE_BUNDLE_URL = "https://github.com/latte-soft/lucide-roblox/releases/latest/download/lucide-roblox.luau"

local function getLucide()
	if _lucide or _lucideLoadAttempted then
		return _lucide
	end
	_lucideLoadAttempted = true

	local fetchOk, source = pcall(game.HttpGet, game, LUCIDE_BUNDLE_URL)
	if not fetchOk then
		warn("Icons.lua: gagal fetch Lucide bundle -> " .. tostring(source))
		return nil
	end

	local compileOk, LucideOrErr = pcall(function()
		return loadstring(source)()
	end)
	if not compileOk then
		warn("Icons.lua: gagal compile Lucide bundle -> " .. tostring(LucideOrErr))
		return nil
	end

	_lucide = LucideOrErr
	return _lucide
end

function Icons.Register(name, assetId)
	assert(type(name) == "string" and name ~= "", "Icons.Register butuh name berupa string")
	assert(type(assetId) == "string" and assetId ~= "", "Icons.Register butuh assetId berupa string")

	_icons[name] = { Id = assetId, Rect = nil, Size = nil }
end

function Icons.RegisterSprite(name, assetId, rectOffset, rectSize)
	assert(type(name) == "string" and name ~= "", "Icons.RegisterSprite butuh name berupa string")
	assert(type(assetId) == "string" and assetId ~= "", "Icons.RegisterSprite butuh assetId berupa string")
	assert(typeof(rectOffset) == "Vector2", "Icons.RegisterSprite butuh rectOffset berupa Vector2")
	assert(typeof(rectSize) == "Vector2", "Icons.RegisterSprite butuh rectSize berupa Vector2")

	_icons[name] = { Id = assetId, Rect = rectOffset, Size = rectSize }
end

function Icons.RegisterBatch(map)
	for name, assetId in map do
		Icons.Register(name, assetId)
	end
end

function Icons.Get(name)
	return _icons[name]
end

function Icons.IsRegistered(name)
	return _icons[name] ~= nil
end

local function tryAutoRegister(name)
	local Lucide = getLucide()
	if not Lucide then return nil end

	local ok, asset = pcall(Lucide.GetAsset, name, 48)
	if not ok then
		warn(("Icons.lua: icon Lucide \"%s\" ga ketemu -> %s"):format(name, tostring(asset)))
		return nil
	end

	Icons.RegisterSprite(name, asset.Url, asset.ImageRectOffset, asset.ImageRectSize)
	return _icons[name]
end

function Icons.CreateImage(name, props)
	props = props or {}
	local entry = Icons.Get(name) or tryAutoRegister(name)

	if not entry then
		warn(("Icons.CreateImage: icon \"%s\" ga ketemu, ImageLabel dibikin kosong"):format(name))
	end

	local merged = {
		BackgroundTransparency = 1,
	}
	for key, value in props do
		merged[key] = value
	end
	merged.Image = entry and entry.Id or ""

	if entry and entry.Rect and entry.Size then
		merged.ImageRectOffset = entry.Rect
		merged.ImageRectSize = entry.Size
	end

	return Create("ImageLabel", merged)
end

return Icons