--[[
	Example.lua
	Contoh pemakaian NeroUI dari nol sampai fitur-fitur lanjutannya.
]]

local NeroUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Dovskie/NeroUI/main/init.lua"))()

-- Window: Theme & Accent opsional, langsung keset dari sini
local window = NeroUI.new({
	Title = "NeroUI Hub",
	Theme = "Dark", -- atau "Light"
	Accent = Color3.fromHex("#6C5CE7"),
})

-- Watermark: widget draggable yang nampilin Title/Desc + badge tag
NeroUI.Watermark.Show({
	Title = "NeroUI Hub",
	Desc = "made by Dovskie",
	Tags = {
		{ Text = "BETA", Color = Color3.fromRGB(230, 180, 60) },
	},
})

-- Tab "Main": section dulu, baru komponen-komponen di dalamnya
local mainTab = window:AddTab("Main")
local aimSection = mainTab:AddSection("Aim Settings")

local aimToggle = aimSection:AddToggle({
	Text = "Enable Aim",
	Default = false,
	Callback = function(isEnabled)
		print("Aim enabled:", isEnabled)
	end,
})

local sensitivitySlider = aimSection:AddSlider({
	Text = "Sensitivity",
	Min = 0,
	Max = 100,
	Default = 50,
	Step = 5,
	Callback = function(value)
		print("Sensitivity:", value)
	end,
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
	Callback = function(selected)
		print("Target priority:", selected)
	end,
})

-- Tab "Visual": komponen bisa langsung ditaruh di tab tanpa section
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
	Callback = function(color)
		window:SetAccent(color)
	end,
})

-- Button dengan Icon (nama icon dari Lucide, lihat Assets/Icons.lua) + Callback
local resetButton = visualTab:AddButton({
	Text = "Reset ke Default",
	Icon = "rotate-ccw",
	Callback = function()
		espToggle:SetValue(true)
		accentPicker:SetValue(Color3.fromHex("#6C5CE7"))
	end,
})

-- Tab "Config": ConfigManager buat save/load semua komponen ter-daftar
local configTab = window:AddTab("Config")

local searchBar = configTab:AddSearchBar({
	Placeholder = "Cari pengaturan...",
	Callback = function(query) -- dipanggil tiap teksnya berubah
		print("Search query:", query)
	end,
})

-- flagName di Register HARUS unik per komponen
NeroUI.ConfigManager.Register("AimEnabled", aimToggle)
NeroUI.ConfigManager.Register("Sensitivity", sensitivitySlider)
NeroUI.ConfigManager.Register("AimKey", aimKeybind)
NeroUI.ConfigManager.Register("TargetPriority", targetDropdown)
NeroUI.ConfigManager.Register("ESPEnabled", espToggle)
NeroUI.ConfigManager.Register("AccentColor", accentPicker)

local saveButton = configTab:AddButton({
	Text = "Save Config",
	Icon = "save",
	Callback = function()
		local ok, err = NeroUI.ConfigManager.Save("default")
		local Notification = NeroUI.Import("Components/Feedback/Notification")

		if ok then
			Notification.Show({ Title = "Config Tersimpan", Type = "Success" })
		else
			Notification.Show({ Title = "Gagal Save", Message = err, Type = "Error" })
		end
	end,
})

local loadButton = configTab:AddButton({
	Text = "Load Config",
	Icon = "folder-open",
	Callback = function()
		NeroUI.ConfigManager.Load("default")
	end,
})

-- Tooltip: nempel ke Instance komponen yang udah ada, tinggal Attach
local Tooltip = NeroUI.Import("Components/Feedback/Tooltip")
Tooltip.Attach(resetButton.Instance, {
	Text = "Balikin semua pengaturan Visual ke nilai awal",
})

-- KeybindManager: nyambungin Keybind (UI) ke aksi runtime beneran
NeroUI.KeybindManager.Bind("AimKey", aimKeybind, {
	Mode = "Hold", -- nembak selama tombolnya ditahan
	Callback = function(isDown)
		print("Aim aktif:", isDown)
	end,
})

-- Toggle biasa tetep bisa pakai Callback juga, bukan cuma OnValueChanged:Connect
local themeToggle = mainTab:AddToggle({
	Text = "Light Mode",
	Default = false,
	Callback = function(isLight)
		window:SetTheme(isLight and "Light" or "Dark")
	end,
})

print("NeroUI Example loaded! Coba klik tombol minimize di titlebar buat test WidgetDrag juga.")