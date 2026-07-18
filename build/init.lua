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
local SIDEBAR_WIDTH = 140
local TITLEBAR_HEIGHT = 36

local function createTabButton(sidebar, text)
	local instance = Create("TextButton", {
		Name = "TabButton",
		Size = UDim2.new(1, 0, 0, 32),
		AutoButtonColor = false,
		Text = text,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		BorderSizePixel = 0,
		Parent = sidebar,
	})
	Draw.ApplyCorner(instance, 6)

	local input = InputHandler.new(instance)
	local isActive = false

	local function refreshColor()
		if isActive then
			instance.BackgroundColor3 = ThemeEngine.Current.Accent
			instance.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			instance.BackgroundColor3 = ThemeEngine.Current.Surface
			instance.TextColor3 = ThemeEngine.Current.Text
		end
	end

	local themeConnection = ThemeEngine.Changed:Connect(refreshColor)
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

	local root = Create("Frame", {
		Name = "NeroWindow",
		Size = props.Size or WINDOW_DEFAULT_SIZE,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	})
	Draw.ApplyCorner(root, 10)
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
	table.insert(self._themeConnections, ThemeEngine.Changed:Connect(function()
		titlebar.BackgroundColor3 = ThemeEngine.Current.Surface
	end))
	titlebar.BackgroundColor3 = ThemeEngine.Current.Surface

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
	table.insert(self._themeConnections, ThemeEngine.Changed:Connect(function()
		sidebar.BackgroundColor3 = ThemeEngine.Current.Surface
	end))
	sidebar.BackgroundColor3 = ThemeEngine.Current.Surface
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

	local tabButtonHandle = createTabButton(self._sidebar, props.Title or "Tab")
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