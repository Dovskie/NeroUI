local BASE_URL = "https://raw.githubusercontent.com/Dovskie/NeroUI/main/"

local Cache = {}

local function Import(path)
	if Cache[path] then
		return Cache[path]
	end

	local url = BASE_URL .. path .. ".lua"

	local ok, source = pcall(game.HttpGet, game, url)
	assert(ok, ("NeroUI: gagal fetch module '%s' -> %s"):format(path, tostring(source)))

	local chunk, compileErr = loadstring(source, "=" .. path)
	assert(chunk, ("NeroUI: gagal compile module '%s' -> %s"):format(path, tostring(compileErr)))

	local result = chunk(Import)
	Cache[path] = result

	return result
end

local ScreenManager = Import("Core/ScreenManager")
local Draw = Import("Core/Draw")
local Create = Import("Core/Create")
local InputHandler = Import("Core/InputHandler")
local ThemeEngine = Import("Theme/ThemeEngine")

local Label = Import("Components/Basic/Label")
local Separator = Import("Components/Basic/Separator")
local Section = Import("Components/Layout/Section")
local Tab = Import("Components/Layout/Tab")
local ScrollFrame = Import("Components/Layout/ScrollFrame")
local Toggle = Import("Components/Input/Toggle")
local Slider = Import("Components/Input/Slider")
local Keybind = Import("Components/Input/Keybind")
local Dropdown = Import("Components/Selection/Dropdown")
local ColorPicker = Import("Components/Selection/ColorPicker")
local SearchBar = Import("Components/Search/SearchBar")
local ButtonComponent = Import("Components/Basic/Button")
local Notification = Import("Components/Feedback/Notification")
local Icons = Import("Assets/Icons")

local Watermark = Import("Extras/Watermark")
local ConfigManager = Import("Extras/ConfigManager")
local KeybindManager = Import("Extras/KeybindManager")

local NeroUI = {}

NeroUI.Import = Import

NeroUI.Watermark = Watermark
NeroUI.ConfigManager = ConfigManager
NeroUI.KeybindManager = KeybindManager
NeroUI.ThemeEngine = ThemeEngine

local function attachComponentHelpers(container)
	local function make(componentClass)
		return function(_, props)
			props = props or {}
			props.Parent = container:GetContentFrame()
			local component = componentClass.new(props)
			container:AddComponent(component)
			return component
		end
	end

	container.AddLabel = make(Label)
	container.AddButton = make(ButtonComponent)
	container.AddSeparator = make(Separator)
	container.AddToggle = make(Toggle)
	container.AddSlider = make(Slider)
	container.AddKeybind = make(Keybind)
	container.AddDropdown = make(Dropdown)
	container.AddColorPicker = make(ColorPicker)
	container.AddSearchBar = make(SearchBar)

	function container:AddSection(props)
		if type(props) == "string" then
			props = { Title = props }
		end
		props = props or {}
		props.Parent = container:GetContentFrame()

		local section = Section.new(props)
		container:AddComponent(section)
		attachComponentHelpers(section)
		return section
	end

	return container
end


local Window = {}
Window.__index = Window

local WINDOW_DEFAULT_SIZE = UDim2.new(0, 550, 0, 400)
local WINDOW_RADIUS = 10
local SIDEBAR_WIDTH = 140
local TITLEBAR_HEIGHT = 36
local TAB_ACCENT_BAR_WIDTH = 3

local _reopenKeybindCounter = 0

local function createTabButton(sidebar, props)
	props = props or {}
	local hasIcon = props.Icon ~= nil

	local instance = Create("TextButton", {
		Name = "TabButton",
		Size = UDim2.new(1, 0, 0, 32),
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = sidebar,
	})
	Draw.ApplyCorner(instance, 6)

	local accentBar = Create("Frame", {
		Name = "AccentBar",
		Size = UDim2.new(0, TAB_ACCENT_BAR_WIDTH, 1, -10),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Parent = instance,
	})
	Draw.ApplyCorner(accentBar, TAB_ACCENT_BAR_WIDTH / 2)

	local iconImage
	if hasIcon then
		iconImage = Icons.CreateImage(props.Icon, {
			Name = "Icon",
			Size = UDim2.new(0, 14, 0, 14),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, TAB_ACCENT_BAR_WIDTH + 10, 0.5, 0),
			Parent = instance,
		})
	end

	local textLabel = Create("TextLabel", {
		Name = "Text",
		Size = UDim2.new(1, -(TAB_ACCENT_BAR_WIDTH + 10 + (hasIcon and 22 or 10)), 1, 0),
		Position = UDim2.new(0, TAB_ACCENT_BAR_WIDTH + 10 + (hasIcon and 22 or 0), 0, 0),
		BackgroundTransparency = 1,
		Text = props.Text or "Tab",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		Parent = instance,
	})

	local input = InputHandler.new(instance)
	local isActive = false

	local function refreshColor()
		if isActive then
			instance.BackgroundColor3 = ThemeEngine.Current.Surface
			textLabel.TextColor3 = ThemeEngine.Current.Text
			if iconImage then iconImage.ImageColor3 = ThemeEngine.Current.Text end
			accentBar.BackgroundColor3 = ThemeEngine.Current.Accent
			accentBar.BackgroundTransparency = 0
		elseif input.Hovering then
			instance.BackgroundColor3 = ThemeEngine.Current.Surface
			textLabel.TextColor3 = ThemeEngine.Current.Text
			if iconImage then iconImage.ImageColor3 = ThemeEngine.Current.Text end
			accentBar.BackgroundTransparency = 1
		else
			instance.BackgroundColor3 = ThemeEngine.Current.Background
			textLabel.TextColor3 = ThemeEngine.Current.TextDim
			if iconImage then iconImage.ImageColor3 = ThemeEngine.Current.TextDim end
			accentBar.BackgroundTransparency = 1
		end
	end

	instance.BackgroundTransparency = 0

	local themeConnection = ThemeEngine.Changed:Connect(refreshColor)
	input.HoverStart:Connect(refreshColor)
	input.HoverEnd:Connect(refreshColor)
	refreshColor()

	return {
		Instance = instance,
		Input = input,
		SetActive = function(active)
			isActive = active
			refreshColor()
		end,
		Destroy = function()
			input:Destroy()
			themeConnection:Disconnect()
			instance:Destroy()
		end,
	}
end

function NeroUI.new(props)
	props = props or {}

	if props.Theme then
		ThemeEngine.SetMode(props.Theme)
	end
	if props.Accent then
		ThemeEngine.SetAccent(props.Accent)
	end
	if props.Watermark then
		Watermark.Configure(props.Watermark)
	end

	local self = setmetatable({}, Window)
	self._tabs = {}
	self._tabButtonHandles = {}
	self._activeTab = nil
	self._themeConnections = {}
	self._reopenKeybind = props.Keybind

	if props.Keybind then
		_reopenKeybindCounter += 1
		self._reopenActionName = "__NeroUI_Reopen_" .. _reopenKeybindCounter
		KeybindManager.Register(self._reopenActionName, {
			Default = props.Keybind,
			Mode = "Press",
			Callback = function()
				if not Watermark.IsEnabled() then
					self:Show()
				end
			end,
		})
	elseif not Watermark.IsEnabled() then
		warn("NeroUI: Watermark.Enabled di-set false tapi props.Keybind ga di-set -- window bakal ga bisa dibuka lagi kalau di-minimize!")
	end

	local root = Create("Frame", {
		Name = "NeroWindow",
		Size = props.Size or WINDOW_DEFAULT_SIZE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	Draw.ApplyCorner(root, WINDOW_RADIUS)
	ScreenManager.Register(root)
	self._root = root

	table.insert(self._themeConnections, ThemeEngine.Changed:Connect(function()
		root.BackgroundColor3 = ThemeEngine.Current.Background
	end))
	root.BackgroundColor3 = ThemeEngine.Current.Background

	local titlebar = Create("Frame", {
		Name = "Titlebar",
		Size = UDim2.new(1, 0, 0, TITLEBAR_HEIGHT),
		BorderSizePixel = 0,
		Parent = root,
	})
	Draw.ApplyCorner(titlebar, WINDOW_RADIUS)

	local titlebarMaskBL = Draw.CornerMask(titlebar, WINDOW_RADIUS, "BottomLeft", ThemeEngine.Current.Surface)
	local titlebarMaskBR = Draw.CornerMask(titlebar, WINDOW_RADIUS, "BottomRight", ThemeEngine.Current.Surface)

	local titlebarDivider = Create("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = titlebar,
	})

	table.insert(self._themeConnections, ThemeEngine.Changed:Connect(function()
		titlebar.BackgroundColor3 = ThemeEngine.Current.Surface
		titlebarMaskBL.BackgroundColor3 = ThemeEngine.Current.Surface
		titlebarMaskBR.BackgroundColor3 = ThemeEngine.Current.Surface
		titlebarDivider.BackgroundColor3 = ThemeEngine.Current.Border
	end))
	titlebar.BackgroundColor3 = ThemeEngine.Current.Surface
	titlebarDivider.BackgroundColor3 = ThemeEngine.Current.Border

	local TITLE_ICON_SIZE = 16
	local TITLE_LEFT_PADDING = 12
	local TITLE_ICON_GAP = 8

	local titleOffsetX = TITLE_LEFT_PADDING

	if props.Icon then
		local titleIcon = Icons.CreateImage(props.Icon, {
			Name = "TitleIcon",
			Size = UDim2.new(0, TITLE_ICON_SIZE, 0, TITLE_ICON_SIZE),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, TITLE_LEFT_PADDING, 0.5, 0),
			ImageColor3 = ThemeEngine.Current.Text,
			Parent = titlebar,
		})
		table.insert(self._themeConnections, ThemeEngine.Changed:Connect(function()
			titleIcon.ImageColor3 = ThemeEngine.Current.Text
		end))
		self._titleIcon = titleIcon
		titleOffsetX = TITLE_LEFT_PADDING + TITLE_ICON_SIZE + TITLE_ICON_GAP
	end

	self._titleLabel = Label.new({
		Text = props.Title or "NeroUI",
		Bold = true,
		Size = UDim2.new(1, -80 - (titleOffsetX - TITLE_LEFT_PADDING), 1, 0),
		Parent = titlebar,
	})
	self._titleLabel.Instance.Position = UDim2.new(0, titleOffsetX, 0, 0)

	local closeButton = Create("TextButton", {
		Name = "CloseButton",
		Size = UDim2.new(0, 28, 0, 24),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		BackgroundTransparency = 1,
		Text = "",
		Parent = titlebar,
	})
	local closeIcon = Icons.CreateImage("x", {
		Name = "Icon",
		Size = UDim2.new(0, 14, 0, 14),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		ImageColor3 = ThemeEngine.Current.TextDim,
		Parent = closeButton,
	})
	table.insert(self._themeConnections, ThemeEngine.Changed:Connect(function()
		closeIcon.ImageColor3 = ThemeEngine.Current.TextDim
	end))

	local closeInput = InputHandler.new(closeButton)
	closeInput.PressEnd:Connect(function(wasClick)
		if wasClick then
			self:Close()
		end
	end)
	self._closeInput = closeInput

	if props.Minimize then
		local minimizeButton = Create("TextButton", {
			Name = "MinimizeButton",
			Size = UDim2.new(0, 28, 0, 24),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8 - 28 - 6, 0.5, 0),
			BackgroundTransparency = 1,
			Text = "",
			Parent = titlebar,
		})
		local minimizeIcon = Icons.CreateImage("minus", {
			Name = "Icon",
			Size = UDim2.new(0, 14, 0, 14),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			ImageColor3 = ThemeEngine.Current.TextDim,
			Parent = minimizeButton,
		})
		table.insert(self._themeConnections, ThemeEngine.Changed:Connect(function()
			minimizeIcon.ImageColor3 = ThemeEngine.Current.TextDim
		end))

		local minimizeInput = InputHandler.new(minimizeButton)
		minimizeInput.PressEnd:Connect(function(wasClick)
			if wasClick then
				self:Hide()
			end
		end)
		self._minimizeInput = minimizeInput
	end

	local titlebarInput = InputHandler.new(titlebar)
	titlebarInput:EnableDrag(root)
	self._titlebarInput = titlebarInput

	local sidebar = Create("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -TITLEBAR_HEIGHT),
		Position = UDim2.new(0, 0, 0, TITLEBAR_HEIGHT),
		BorderSizePixel = 0,
		Parent = root,
	})
	Draw.ApplyCorner(sidebar, WINDOW_RADIUS)

	local sidebarMaskTL = Draw.CornerMask(sidebar, WINDOW_RADIUS, "TopLeft", ThemeEngine.Current.Surface)
	local sidebarMaskTR = Draw.CornerMask(sidebar, WINDOW_RADIUS, "TopRight", ThemeEngine.Current.Surface)
	local sidebarMaskBR = Draw.CornerMask(sidebar, WINDOW_RADIUS, "BottomRight", ThemeEngine.Current.Surface)

	local sidebarDivider = Create("Frame", {
		Name = "Divider",
		Size = UDim2.new(0, 1, 1, 0),
		Position = UDim2.new(1, -1, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = sidebar,
	})

	table.insert(self._themeConnections, ThemeEngine.Changed:Connect(function()
		sidebar.BackgroundColor3 = ThemeEngine.Current.Surface
		sidebarMaskTL.BackgroundColor3 = ThemeEngine.Current.Surface
		sidebarMaskTR.BackgroundColor3 = ThemeEngine.Current.Surface
		sidebarMaskBR.BackgroundColor3 = ThemeEngine.Current.Surface
		sidebarDivider.BackgroundColor3 = ThemeEngine.Current.Border
	end))
	sidebar.BackgroundColor3 = ThemeEngine.Current.Surface
	sidebarDivider.BackgroundColor3 = ThemeEngine.Current.Border

	Draw.ApplyPadding(sidebar, 8)
	Draw.ApplyListLayout(sidebar, 4, "Vertical")
	self._sidebar = sidebar

	local body = Create("Frame", {
		Name = "Body",
		Size = UDim2.new(1, -SIDEBAR_WIDTH, 1, -TITLEBAR_HEIGHT),
		Position = UDim2.new(0, SIDEBAR_WIDTH, 0, TITLEBAR_HEIGHT),
		BackgroundTransparency = 1,
		Parent = root,
	})
	self._body = body

	return self
end

function Window:AddTab(props)
	if type(props) == "string" then
		props = { Title = props }
	end
	props = props or {}

	local tab = Tab.new({ Parent = self._body, Visible = false })
	local scroll = ScrollFrame.new({ Parent = tab:GetContentFrame() })
	tab:AddComponent(scroll)

	attachComponentHelpers(scroll)

	local tabButtonHandle = createTabButton(self._sidebar, {
		Text = props.Title or "Tab",
		Icon = props.Icon,
	})
	tabButtonHandle.Input.PressEnd:Connect(function(wasClick)
		if wasClick then
			self:_setActiveTab(tab)
		end
	end)

	table.insert(self._tabs, tab)
	table.insert(self._tabButtonHandles, tabButtonHandle)

	if not self._activeTab then
		self:_setActiveTab(tab)
	end

	return scroll
end

function Window:_setActiveTab(targetTab)
	for index, tab in self._tabs do
		local isTarget = tab == targetTab
		if isTarget then
			tab:Show()
		else
			tab:Hide()
		end
		self._tabButtonHandles[index].SetActive(isTarget)
	end
	self._activeTab = targetTab
end

function Window:SetTheme(mode)
	ThemeEngine.SetMode(mode)
end

function Window:SetAccent(color)
	ThemeEngine.SetAccent(color)
end

function Window:Show()
	self._root.Visible = true
	Watermark:SetMinimized(false)
end

function Window:Hide()
	self._root.Visible = false
	Watermark.SetOnClick(function()
		self:Show()
	end)
	Watermark:SetMinimized(true)

	if not Watermark.IsEnabled() then
		Notification.Show({
			Title = "Container di-minimize",
			Message = self._reopenKeybind
				and ("Tekan tombol %s buat buka lagi."):format(self._reopenKeybind.Name)
				or "Watermark dimatikan dan belum ada Keybind buat buka lagi.",
			Type = "Warning",
		})
	end
end

function Window:Toggle()
	if self._root.Visible then
		self:Hide()
	else
		self:Show()
	end
end

function Window:Close()
	self:Destroy()
	Watermark.Destroy()
end

function Window:Destroy()
	if self._reopenActionName then
		KeybindManager.Unregister(self._reopenActionName)
	end
	if self._titlebarInput then
		self._titlebarInput:Destroy()
	end
	if self._closeInput then
		self._closeInput:Destroy()
	end
	if self._minimizeInput then
		self._minimizeInput:Destroy()
	end

	for _, connection in self._themeConnections do
		connection:Disconnect()
	end
	table.clear(self._themeConnections)

	for _, tab in self._tabs do
		tab:Destroy()
	end
	table.clear(self._tabs)

	for _, handle in self._tabButtonHandles do
		handle.Destroy()
	end
	table.clear(self._tabButtonHandles)

	ScreenManager.Unregister(self._root)
	self._root:Destroy()
end

return NeroUI