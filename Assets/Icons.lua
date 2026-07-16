local Import = ...
local Create = Import("Core/Create")

local Icons = {}

local _icons = {}

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

function Icons.CreateImage(name, props)
	props = props or {}
	local entry = Icons.Get(name)

	if not entry then
		warn(("Icons.CreateImage: icon \"%s\" belum ke-Register, ImageLabel dibikin kosong"):format(name))
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

local CORE_ICONS = { "chevron-down", "search" }

local LUCIDE_BUNDLE_URL = "https://github.com/latte-soft/lucide-roblox/releases/latest/download/lucide-roblox.luau"

local function autoBootstrapLucide()
	local fetchOk, source = pcall(game.HttpGet, game, LUCIDE_BUNDLE_URL)
	if not fetchOk then
		warn("Icons.lua: gagal fetch Lucide bundle, icon bawaan NeroUI (chevron/search) bakal kosong -> " .. tostring(source))
		return
	end

	local compileOk, LucideOrErr = pcall(function()
		return loadstring(source)()
	end)
	if not compileOk then
		warn("Icons.lua: gagal compile Lucide bundle -> " .. tostring(LucideOrErr))
		return
	end

	local Lucide = LucideOrErr
	for _, iconName in CORE_ICONS do
		local ok, asset = pcall(Lucide.GetAsset, iconName, 48)
		if ok then
			Icons.RegisterSprite(iconName, asset.Url, asset.ImageRectOffset, asset.ImageRectSize)
		else
			warn("Icons.lua: icon Lucide \"" .. iconName .. "\" ga ketemu -> " .. tostring(asset))
		end
	end
end

autoBootstrapLucide()

return Icons