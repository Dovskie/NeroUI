--[[
	Example.lua
	Contoh pemakaian NeroUI dari nol sampai fitur-fitur lanjutannya.
]]

local NeroUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Dovskie/NeroUI/refs/heads/main/build/dist/NeroUI.lua"))()

-- Window: Theme & Accent opsional, langsung keset dari sini
-- Watermark: konten (Title/Desc/Tags) di-set di sini, tapi TIDAK langsung muncul.
-- Dia baru muncul otomatis saat window di-minimize, dan hilang lagi saat dibuka.
-- AutoLoadConfig: otomatis manggil ConfigManager buat load config "default" begitu
-- semua komponen (termasuk yang di-Register lewat ConfigManager.Register di bawah)
-- udah selesai dibuat. Kalau file config "default" belum pernah ada, ini di-skip
-- diam-diam (ga error), jadi aman dipasang dari awal walau usernya belum pernah save.
local window = NeroUI.new({
	Title = "NeroUI Hub",
	Icon = "shield",
	Theme = "Dark",
	Accent = Color3.fromHex("#6C5CE7"),
	Minimize = true, -- default true, kalo false berarti ga ada tombol minimize di titlebar
	Keybind = Enum.KeyCode.RightControl, -- cuma aktif kalo Watermark.Enabled = false, buat buka lagi window yang di-minimize
	AutoLoadConfig = "default", -- ganti/hapus kalo ga mau auto-load pas start
	Watermark = {
		Enabled = false, -- set false kalo mau matiin watermark sepenuhnya (pastikan Keybind di atas ke-set!)
		Title = "NeroUI Hub",
		Desc = "made by Dovskie",
		Tags = {
			{ Text = "BETA", Color = Color3.fromRGB(230, 180, 60) },
		},
	},
})

-- Tooltip: NeroUI.Import buat modul yang jarang dipake tapi butuh di-load manual.
-- Tooltip.Attach nempel ke Instance mentah komponen (bukan komponennya sendiri),
-- jadi selalu akses lewat `komponen.Instance`.
local Tooltip = NeroUI.Import("Components/Feedback/Tooltip")

-- Tab "Main": section dulu, baru komponen-komponen di dalamnya
local mainTab = window:AddTab("Main")

-- Paragraph: cocok buat disclaimer/changelog/info panjang di paling atas tab
mainTab:AddParagraph({
	Title = "Selamat Datang",
	Text = "Script ini masih tahap beta. Kalau nemu bug atau ada saran fitur, laporkan ke Discord server ya. Jangan lupa selalu update ke versi terbaru biar ga ketinggalan fix.",
})
mainTab:AddSeparator()

local aimSection = mainTab:AddSection("Aim Settings")

local aimToggle = aimSection:AddToggle({
	Text = "Enable Aim",
	Default = false,
	Callback = function(isEnabled)
		print("Aim enabled:", isEnabled)
	end,
})

-- Slider: sekarang value di kanan bisa langsung diklik & diketik manual, ga cuma drag
-- DependsOn: sliders/komponen di bawah aimToggle sekarang cuma keliatan kalo Aim aktif,
-- jadi UI ga penuh sama opsi yang ga relevan pas fiturnya lagi off.
local sensitivitySlider = aimSection:AddSlider({
	Text = "Sensitivity",
	Min = 0,
	Max = 100,
	Default = 50,
	Step = 5,
	DependsOn = { Component = aimToggle },
	Callback = function(value)
		print("Sensitivity:", value)
	end,
})

-- Tooltip.Attach: muncul pas mouse hover di atas komponennya (ada delay dikit),
-- cocok buat kasih penjelasan singkat tanpa makan tempat kayak AddParagraph.
Tooltip.Attach(sensitivitySlider.Instance, {
	Text = "Kecepatan rotasi aim per frame. Mulai dari nilai rendah dulu.",
})

-- Predicate: paragraph warning ini cuma muncul kalo Sensitivity di atas 80,
-- jadi tergantung VALUE komponen lain, bukan cuma ada/gaknya sesuatu.
aimSection:AddParagraph({
	Title = "Perhatian",
	Text = "Sensitivity terlalu tinggi bisa keliatan mencurigakan.",
	DependsOn = { Component = sensitivitySlider, Predicate = function(v) return v > 80 end },
})

local aimKeybind = aimSection:AddKeybind({
	Text = "Aim Key",
	Default = Enum.KeyCode.E,
	DependsOn = { Component = aimToggle },
})

-- KeybindManager.Bind: hubungin komponen Keybind ke aksi nyata. Beda sama
-- AddKeybind doang (yang cuma nyimpen KeyCode-nya), ini yang bikin tombolnya
-- BENERAN ngelakuin sesuatu pas ditekan, dan otomatis ke-update kalo user ganti
-- tombolnya lewat UI (ga perlu re-Bind manual).
NeroUI.KeybindManager.Bind("ToggleAim", aimKeybind, {
	Mode = "Press",
	Callback = function()
		aimToggle:SetValue(not aimToggle:GetValue())
	end,
})

aimSection:AddSeparator({ DependsOn = { Component = aimToggle } })

local targetDropdown = aimSection:AddDropdown({
	Text = "Target Priority",
	Options = { "Closest", "Lowest HP", "Highest HP" },
	Default = "Closest",
	DependsOn = { Component = aimToggle },
	Callback = function(selected)
		print("Target priority:", selected)
	end,
})

local targetDropdown2 = aimSection:AddDropdown({
	Text = "Target Priority",
	Options = { "Closest", "Lowest HP", "Highest HP" },
	Default = "Closest",
	IsMulti = true,
	DependsOn = { Component = aimToggle },
	Callback = function(selected)
		print("Target priority:", selected)
	end,
})

aimSection:AddSeparator({ DependsOn = { Component = aimToggle } })

-- Dropdown Searchable: berguna kalau opsinya banyak, contoh daftar player di server
local playerDropdown = aimSection:AddDropdown({
	Text = "Target Player",
	Options = { "Player1", "Player2", "Player3", "Player4", "Player5" },
	Searchable = true,
	DependsOn = { Component = aimToggle },
	Callback = function(selected)
		print("Target player:", selected)
	end,
})

-- Kalau daftar player berubah (ada yang join/leave), tinggal panggil SetOptions
local function refreshPlayerList()
	local names = {}
	for _, plr in game:GetService("Players"):GetPlayers() do
		table.insert(names, plr.Name)
	end
	if #names > 0 then
		playerDropdown:SetOptions(names)
	end
end
-- refreshPlayerList() -- panggil ini tiap ada PlayerAdded/PlayerRemoving

aimSection:AddSeparator({ DependsOn = { Component = aimToggle } })

-- Input (TextBox): buat teks bebas, contoh nama target spesifik
local targetNameInput = aimSection:AddInput({
	Text = "Nama Target Spesifik",
	Placeholder = "cth: Roblox123",
	DependsOn = { Component = aimToggle },
	Callback = function(value)
		print("Target name diubah:", value)
	end,
})

-- Input numerik: set Numeric = true, otomatis validasi & bisa dikasih Min/Max
local fovInput = aimSection:AddInput({
	Text = "FOV Radius",
	Numeric = true,
	Default = 120,
	Min = 10,
	Max = 500,
	DependsOn = { Component = aimToggle },
	Callback = function(value)
		print("FOV Radius:", value)
	end,
})

-- Field ini cuma relevan kalo Target Priority = "Lowest HP", makanya
-- DependsOn-nya dikasih Value spesifik, bukan cuma Component doang.
local hpThreshold = aimSection:AddInput({
	Text = "HP Threshold",
	Numeric = true,
	Default = 30,
	DependsOn = { Component = targetDropdown, Value = "Lowest HP" },
	Callback = function(value)
		print("HP Threshold:", value)
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
Tooltip.Attach(accentPicker.Instance, {
	Text = "Ganti warna aksen seluruh UI (tombol aktif, slider, dsb) secara live.",
})

visualTab:AddSeparator()

-- DataTable: cocok buat nampilin list player/ESP data secara live, lengkap
-- dengan header yang bisa di-klik buat sorting (Sortable = true).
-- Width kolom itu proporsi (0.5 = 50% lebar tabel), kolom tanpa Width otomatis
-- bagi rata sisa ruangnya.
local espTable = visualTab:AddDataTable({
	Columns = {
		{ Key = "Name", Title = "Nama", Width = 0.5 },
		{ Key = "Distance", Title = "Jarak", Width = 0.25, Align = Enum.TextXAlignment.Right },
		{ Key = "HP", Title = "HP", Align = Enum.TextXAlignment.Right },
	},
	Sortable = true,
	MaxVisibleRows = 6,
	Data = {
		{ Name = "Player1", Distance = 45, HP = 100 },
		{ Name = "Player2", Distance = 12, HP = 60 },
	},
	DependsOn = { Component = espToggle },
	OnRowClick = function(row, index)
		print("Diklik:", row.Name)
	end,
})

-- Update live tiap heartbeat/loop, misal buat refresh jarak & HP player
task.spawn(function()
	while task.wait(1) do
		local newPlayerList = {}
		for _, plr in game:GetService("Players"):GetPlayers() do
			local hp = plr.Character and plr.Character:FindFirstChild("Humanoid")
			table.insert(newPlayerList, {
				Name = plr.Name,
				Distance = 0, -- ganti sama hitungan jarak beneran
				HP = hp and math.floor(hp.Health) or 0,
			})
		end
		if #newPlayerList > 0 then
			espTable:SetData(newPlayerList)
		end
	end
end)

-- Modal: dipanggil sebelum aksi yang butuh konfirmasi (misal aksi destruktif)
local Notification = NeroUI.Import("Components/Feedback/Notification")
local Modal = NeroUI.Import("Components/Feedback/Modal")

local resetButton = visualTab:AddButton({
	Text = "Reset ke Default",
	Icon = "rotate-ccw",
	Callback = function()
		Modal.Show({
			Title = "Reset Pengaturan?",
			Message = "Semua pengaturan Visual bakal kembali ke nilai awal. Aksi ini ga bisa di-undo.",
			ConfirmText = "Reset",
			CancelText = "Batal",
			Danger = true,
			DismissOnOutsideClick = true,
			OnConfirm = function()
				espToggle:SetValue(true)
				accentPicker:SetValue(Color3.fromHex("#6C5CE7"))

				-- Notification dengan Action Button: kasih opsi Undo tanpa nutup notif-nya
				Notification.Show({
					Title = "Pengaturan Direset",
					Message = "Semua pengaturan Visual sudah kembali ke default.",
					Type = "Warning",
					Actions = {
						{
							Text = "Undo",
							Callback = function()
								espToggle:SetValue(false)
								print("Reset di-undo")
							end,
						},
					},
				})
			end,
		})
	end,
})

-- KeybindManager.Register: dipake langsung tanpa nempel ke komponen Keybind
-- manapun, cocok buat keybind "fixed" yang emang ga perlu dikustom user, kayak
-- panic button. Mode = "Press" cuma nembak sekali pas ditekan; Mode = "Hold"
-- (liat contoh lain di codebase) nembak Callback(true) pas ditekan & Callback(false)
-- pas dilepas.
NeroUI.KeybindManager.Register("PanicButton", {
	Default = Enum.KeyCode.P,
	Mode = "Press",
	Callback = function()
		aimToggle:SetValue(false)
		espToggle:SetValue(false)
		Notification.Show({
			Title = "Panic Button",
			Message = "Aim & ESP langsung dimatikan.",
			Type = "Warning",
		})
	end,
})

-- Section kecil buat nunjukin utilitas window yang sebenernya udah otomatis ada
-- dari awal (ga perlu di-setup manual), tinggal dipicu programatik kalo mau.
local utilitySection = visualTab:AddSection("Window Utilities")

-- CommandPalette: NYALA OTOMATIS dari awal (kecuali props.CommandPalette = false
-- pas NeroUI.new). Setiap komponen yang punya Title/Text otomatis ke-daftar jadi
-- entry yang bisa dicari -- coba tekan Ctrl+K buat buka lalu ketik "sensitivity".
local paletteButton = utilitySection:AddButton({
	Text = "Buka Command Palette",
	Icon = "search",
	Callback = function()
		window:ToggleCommandPalette()
	end,
})
Tooltip.Attach(paletteButton.Instance, {
	Text = "Shortcut: Ctrl+K. Cari komponen apapun di semua tab, klik buat auto-scroll ke sana.",
})

-- NotificationHistory: juga otomatis ada (ikon lonceng di titlebar, kecuali
-- props.NotificationHistory = false). Nyimpen semua Notification.Show yang pernah
-- muncul, lengkap sama timestamp relatif ("5m lalu") dan tombol Clear.
local historyButton = utilitySection:AddButton({
	Text = "Lihat Riwayat Notifikasi",
	Icon = "bell",
	Callback = function()
		window:ToggleNotificationHistory()
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

-- flagName di Register HARUS unik per komponen.
-- Semua komponen yang di-Register di sini otomatis ke-load kalo file config
-- "default" ada dan AutoLoadConfig = "default" dipasang di window di atas.
NeroUI.ConfigManager.Register("AimEnabled", aimToggle)
NeroUI.ConfigManager.Register("Sensitivity", sensitivitySlider)
NeroUI.ConfigManager.Register("AimKey", aimKeybind)
NeroUI.ConfigManager.Register("TargetPriority", targetDropdown)
NeroUI.ConfigManager.Register("HPThreshold", hpThreshold)
NeroUI.ConfigManager.Register("TargetName", targetNameInput)
NeroUI.ConfigManager.Register("FOVRadius", fovInput)
NeroUI.ConfigManager.Register("ESPEnabled", espToggle)
NeroUI.ConfigManager.Register("AccentColor", accentPicker)

configTab:AddSeparator()

-- SaveManager: cara instan buat save/load/delete config.
-- Alurnya:
--   1. Ketik nama di kolom "Nama Config" (contoh: "legit", "rage", "default")
--   2. Klik "Save" -> semua komponen yang di-Register di atas ke-simpan ke file itu,
--      dan dropdown "Load Config" di bawahnya OTOMATIS ke-refresh + milih nama itu.
--   3. Buka dropdown "Load Config" buat milih config lain yang udah pernah disave,
--      lalu klik "Load" buat nerapin nilainya ke semua komponen ter-Register.
--   4. Klik "Delete" buat hapus config yang lagi dipilih di dropdown -- dropdown
--      juga otomatis refresh abis delete.
-- Kalo mau AutoLoadConfig di atas kepake, config dengan nama yang sama ("default")
-- harus pernah di-Save minimal sekali lewat SaveManager ini.
configTab:AddSaveManager()

configTab:AddSeparator()

-- ProgressBar: berguna buat proses async (fetch data, loop panjang, dsb)
local downloadProgress = configTab:AddProgressBar({
	Text = "Download Assets",
	Default = 0,
})

configTab:AddButton({
	Text = "Simulasikan Download",
	Icon = "download",
	Callback = function()
		downloadProgress:SetValue(0, false)
		task.spawn(function()
			for i = 10, 100, 10 do
				task.wait(0.2)
				downloadProgress:SetValue(i)
			end
			Notification.Show({ Title = "Download Selesai", Type = "Success" })
		end)
	end,
})

-- ProgressBar Indeterminate: dipakai kalau durasi prosesnya ga bisa diprediksi
local loadingBar = configTab:AddProgressBar({
	Text = "Memuat Data Server",
	Indeterminate = true,
})

print("NeroUI Example loaded! Coba klik tombol minimize di titlebar buat test WidgetDrag, tekan Ctrl+K buat Command Palette, klik ikon lonceng buat Riwayat Notifikasi, atau tekan P buat Panic Button.")