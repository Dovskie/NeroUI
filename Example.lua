--[[
	Example.lua
]]

-- ============================================================
-- 1. LOAD NeroUI -- cukup 1 baris, BASE_URL udah nempel di init.lua sendiri
-- ============================================================
local NeroUI = loadstring(game:HttpGet(
	"https://raw.githubusercontent.com/Dovskie/NeroUI/main/init.lua"
))()

-- ============================================================
-- 2. BIKIN WINDOW -- tema, accent color bisa langsung di-set dari awal
-- ============================================================
local window = NeroUI.new({
	Title = "NeroUI Hub",
	Theme = "Light", -- atau "Light"
	Accent = Color3.fromHex("#6C5CE7"),
})

-- ============================================================
-- 3. WATERMARK -- widget mengambang draggable, Title + Desc + Tag badge
-- ============================================================
NeroUI.Watermark.Show({
	Title = "NeroUI Hub",
	Desc = "made by Dovskie",
	Tags = {
		{ Text = "BETA", Color = Color3.fromRGB(230, 180, 60) },
	},
})

-- ============================================================
-- 4. TAB "Main" -- contoh AddSection DULU baru AddToggle/AddSlider/dst
-- ============================================================
local mainTab = window:AddTab("Main")

local aimSection = mainTab:AddSection("Aim Settings")

local aimToggle = aimSection:AddToggle({
	Text = "Enable Aim",
	Default = false,
})

local sensitivitySlider = aimSection:AddSlider({
	Text = "Sensitivity",
	Min = 0,
	Max = 100,
	Default = 50,
	Step = 5,
})

local aimKeybind = aimSection:AddKeybind({
	Text = "Aim Key",
	Default = Enum.KeyCode.E,
})

aimSection:AddSeparator()

local targetDropdown = aimSection:AddDropdown({
	Text = "Target Priority",
	Options = { "Closest", "Lowest HP", "Highest HP" },
	Default = "Closest",
})

-- ============================================================
-- 5. TAB "Visual" -- contoh LANGSUNG AddToggle/AddButton dari Tab, TANPA
--    lewat AddSection (dua-duanya valid, sesuai keputusan project)
-- ============================================================
local visualTab = window:AddTab("Visual")

visualTab:AddLabel({ Text = "Pengaturan Tampilan", Bold = true })
visualTab:AddSeparator()

local espToggle = visualTab:AddToggle({
	Text = "ESP Box",
	Default = true,
})

local accentPicker = visualTab:AddColorPicker({
	Text = "Accent Color",
	Default = Color3.fromHex("#6C5CE7"),
})
accentPicker.OnValueChanged:Connect(function(color)
	window:SetAccent(color)
end)

local resetButton = visualTab:AddButton({
	Text = "Reset ke Default",
})
resetButton.OnClick:Connect(function()
	espToggle:SetValue(true)
	accentPicker:SetValue(Color3.fromHex("#6C5CE7"))
end)

-- ============================================================
-- 6. TAB "Config" -- ConfigManager: Register semua komponen yang mau disave
-- ============================================================
local configTab = window:AddTab("Config")

local searchBar = configTab:AddSearchBar({
	Placeholder = "Cari pengaturan...",
})
searchBar.OnQueryChanged:Connect(function(query)
	print("Search query:", query)
end)

-- Register komponen yang mau ikut ke-save/load. flagName HARUS unik.
NeroUI.ConfigManager.Register("AimEnabled", aimToggle)
NeroUI.ConfigManager.Register("Sensitivity", sensitivitySlider)
NeroUI.ConfigManager.Register("AimKey", aimKeybind)
NeroUI.ConfigManager.Register("TargetPriority", targetDropdown)
NeroUI.ConfigManager.Register("ESPEnabled", espToggle)
NeroUI.ConfigManager.Register("AccentColor", accentPicker)

local saveButton = configTab:AddButton({ Text = "Save Config" })
saveButton.OnClick:Connect(function()
	local ok, err = NeroUI.ConfigManager.Save("default")
	if ok then
		-- Notification.lua, dari Import() langsung soalnya ga di-expose ke
		-- root NeroUI (dianggap "opsional", ga semua developer butuh notif)
		local Notification = NeroUI.Import("Components/Feedback/Notification")
		Notification.Show({ Title = "Config Tersimpan", Type = "Success" })
	else
		local Notification = NeroUI.Import("Components/Feedback/Notification")
		Notification.Show({ Title = "Gagal Save", Message = err, Type = "Error" })
	end
end)

local loadButton = configTab:AddButton({ Text = "Load Config" })
loadButton.OnClick:Connect(function()
	NeroUI.ConfigManager.Load("default")
end)

-- ============================================================
-- 7. TOOLTIP -- nempel ke Instance komponen yang udah ada
-- ============================================================
local Tooltip = NeroUI.Import("Components/Feedback/Tooltip")
Tooltip.Attach(resetButton.Instance, {
	Text = "Balikin semua pengaturan Visual ke nilai awal",
})

-- ============================================================
-- 8. KEYBIND MANAGER -- nyambungin aimKeybind (UI) ke aksi runtime beneran
-- ============================================================
NeroUI.KeybindManager.Bind("AimKey", aimKeybind, {
	Mode = "Hold", -- nembak selama tombolnya ditahan
	Callback = function(isDown)
		print("Aim aktif:", isDown)
	end,
})

-- ============================================================
-- 9. THEME SWITCHING -- contoh toggle Dark/Light dari Toggle biasa
-- ============================================================
local themeToggle = mainTab:AddToggle({
	Text = "Light Mode",
	Default = false,
})
themeToggle.OnValueChanged:Connect(function(isLight)
	window:SetTheme(isLight and "Light" or "Dark")
end)

print("NeroUI Example loaded! Coba klik tombol minimize di titlebar buat test WidgetDrag juga.")