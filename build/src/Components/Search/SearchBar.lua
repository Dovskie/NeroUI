local Import = ...
local Create = Import("Core/Create")
local Draw = Import("Core/Draw")
local Signal = Import("Core/Signal")
local BaseComponent = Import("Components/Base/BaseComponent")
local Icons = Import("Assets/Icons")

local SearchBar = setmetatable({}, { __index = BaseComponent })
SearchBar.__index = SearchBar

local CONTAINER_HEIGHT = 32
local CORNER_RADIUS = 6
local ICON_WIDTH = 28

function SearchBar.new(props)
	props = props or {}

	local container = Create("Frame", {
		Name = "NeroSearchBar",
		Size = UDim2.new(1, 0, 0, CONTAINER_HEIGHT),
		BorderSizePixel = 0,
		Parent = props.Parent,
	})
	Draw.ApplyCorner(container, CORNER_RADIUS)

	local self = BaseComponent.new(container)
	setmetatable(self, SearchBar)

	self.OnQueryChanged = Signal.new()
	self.OnSubmit = Signal.new()
	self:BindCallback(self.OnQueryChanged, props.Callback)
	self:BindCallback(self.OnSubmit, props.OnSubmit)

	local icon = Icons.CreateImage("search", {
		Name = "Icon",
		Size = UDim2.new(0, 14, 0, 14),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, (ICON_WIDTH - 14) / 2, 0.5, 0),
		Parent = container,
	})
	self._icon = icon

	local textBox = Create("TextBox", {
		Name = "Input",
		Size = UDim2.new(1, -ICON_WIDTH - 8, 1, 0),
		Position = UDim2.new(0, ICON_WIDTH, 0, 0),
		BackgroundTransparency = 1,
		PlaceholderText = props.Placeholder or "Search...",
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		ClearTextOnFocus = false,
		Parent = container,
	})
	self._textBox = textBox

	textBox:GetPropertyChangedSignal("Text"):Connect(function()
		self.OnQueryChanged:Fire(textBox.Text)
	end)

	textBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			self.OnSubmit:Fire(textBox.Text)
		end
	end)

	self:OnThemeChanged(function(theme)
		container.BackgroundColor3 = theme.Surface
		icon.ImageColor3 = theme.TextDim
		textBox.TextColor3 = theme.Text
		textBox.PlaceholderColor3 = theme.TextDim
	end)

	return self
end

function SearchBar:GetQuery()
	return self._textBox.Text
end

function SearchBar:Clear()
	self._textBox.Text = ""
end

function SearchBar:Destroy()
	self.OnQueryChanged:Destroy()
	self.OnSubmit:Destroy()

	BaseComponent.Destroy(self)
end

return SearchBar