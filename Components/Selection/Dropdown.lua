local UserInputService = game:GetService("UserInputService")

local Import = ...
local Create = Import("Core/Create")
local Draw = Import("Core/Draw")
local Signal = Import("Core/Signal")
local InputHandler = Import("Core/InputHandler")
local ThemeEngine = Import("Theme/ThemeEngine")
local Icons = Import("Assets/Icons")
local ScreenManager = Import("Core/ScreenManager")
local BaseComponent = Import("Components/Base/BaseComponent")
local Label = Import("Components/Basic/Label")

local Dropdown = setmetatable({}, { __index = BaseComponent })
Dropdown.__index = Dropdown

local CONTAINER_HEIGHT = 36
local SELECT_BUTTON_SIZE = UDim2.new(0, 140, 0, 28)
local OPTION_HEIGHT = 28
local POPUP_RADIUS = 6
local POPUP_MAX_HEIGHT = 160

function Dropdown.new(props)
	props = props or {}

	local options = props.Options or {}
	assert(#options > 0, "Dropdown.new butuh minimal 1 opsi di props.Options")

	local container = Create("Frame", {
		Name = "NeroDropdown",
		Size = UDim2.new(1, 0, 0, CONTAINER_HEIGHT),
		BackgroundTransparency = 1,
		Parent = props.Parent
	})

	local self = BaseComponent.new(container)
	setmetatable(self, Dropdown)

	self.OnValueChanged = Signal.new()
	self._options = options
	self._value = (table.find(options, props.Default) and props.Default) or options[1]
	self._open = false
	self._popup = nil

	self._label = Label.new({
		Text = props.Text or "Dropdown",
		Size = UDim2.new(1, -150, 1, 0),
		Parent = container,
	})
	self:AddChild(self._label)

	local selectButton = Create("TextButton", {
		Name = "SelectButton",
		Size = SELECT_BUTTON_SIZE,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		AutoButtonColor = false,
		Text = "  " .. self._value,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Parent = container,
	})
	Draw.ApplyCorner(selectButton, POPUP_RADIUS)
	self._selectButton = selectButton

	local chevron = Icons.CreateImage("chevron-down", {
		Name = "Chevron",
		Size = UDim2.new(0, 14, 0, 14),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Parent = selectButton,
	})
	self._chevron = chevron

	self:OnThemeChanged(function(theme)
		chevron.ImageColor3 = Color3.fromRGB(255, 255, 255)
	end)

	self._input = InputHandler.new(selectButton)
	self._input.PressEnd:Connect(function(wasClick)
		if wasClick then
			self:Toggle()
		end
	end)

	self:OnThemeChanged(function(theme)
		selectButton.BackgroundColor3 = theme.Surface
	end)

	return self
end

function Dropdown:_ensurePopup()
	if self._popup then
		return
	end

	local popup = Create("Frame", {
		Name = "NeroDropdownPopup",
		Size = UDim2.new(0, SELECT_BUTTON_SIZE.X.Offset, 0, math.min(#self._options * OPTION_HEIGHT, POPUP_MAX_HEIGHT)),
		BorderSizePixel = 0,
		Visible = false,
	})
	Draw.ApplyCorner(popup, POPUP_RADIUS)
	Draw.ApplyListLayout(popup, 0, "Vertical")

	self:OnThemeChanged(function(theme)
		popup.BackgroundColor3 = theme.Surface
	end)

	for _, optionText in self._options do
		local optionButton = Create("TextButton", {
			Name = "Option_" .. optionText,
			Size = UDim2.new(1, 0, 0, OPTION_HEIGHT),
			AutoButtonColor = false,
			Text = "  " .. optionText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
			BackgroundTransparency = 1,
			Parent = popup,
		})

		local optionInput = InputHandler.new(optionButton)
		optionInput.HoverStart:Connect(function()
			optionButton.BackgroundTransparency = 0
			optionButton.BackgroundColor3 = ThemeEngine.Current.AccentHover
		end)
		optionInput.HoverEnd:Connect(function()
			optionButton.BackgroundTransparency = 1
		end)
		optionInput.PressEnd:Connect(function(wasClick)
			if wasClick then
				self:SetValue(optionText)
				self:Close()
			end
		end)

		self:OnThemeChanged(function(theme)
			optionButton.TextColor3 = theme.Text
		end)
	end

	self._popup = popup
end

function Dropdown:_positionPopup()
	local buttonPos = self._selectButton.AbsolutePosition
	local buttonSize = self._selectButton.AbsoluteSize

	self._popup.Position = UDim2.new(0, buttonPos.X, 0, buttonPos.Y + buttonSize.Y + 4)
end

function Dropdown:Open()
	if self._open then
		return
	end

	self:_ensurePopup()
	self._popup.Parent = ScreenManager.GetRoot()
	ScreenManager.BringToFront(self._popup)
	self:_positionPopup()
	self._popup.Visible = true
	self._open = true
	self._chevron.Rotation = 180
	self._outsideClickConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		task.defer(function()
			if not self._open then
				return
			end
			local mouse = UserInputService:GetMouseLocation()
			local overSelectButton = self:_isPointInside(self._selectButton, mouse)
			local overPopup = self:_isPointInside(self._popup, mouse)
			if not overSelectButton and not overPopup then
				self:Close()
			end
		end)
	end)
end

function Dropdown:Close()
	if not self._open then
		return
	end

	self._open = false
	self._chevron.Rotation = 0
	if self._popup then
		self._popup.Visible = false
	end

	if self._outsideClickConnection then
		self._outsideClickConnection:Disconnect()
		self._outsideClickConnection = nil
	end
end

function Dropdown:Toggle()
	if self._open then
		self:Close()
	else
		self:Open()
	end
end

function Dropdown:_isPointInside(guiObject, point)
	local pos = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize
	return point.X >= pos.X and point.X <= pos.X + size.X
		and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

function Dropdown:SetValue(value)
	if not table.find(self._options, value) then
		return
	end
	if value == self._value then
		return
	end

	self._value = value
	self._selectButton.Text = "  " .. value
	self.OnValueChanged:Fire(self._value)
end

function Dropdown:GetValue()
	return self._value
end

function Dropdown:Destroy()
	self:Close()

	if self._input then
		self._input:Destroy()
		self._input = nil
	end

	if self._popup then
		self._popup:Destroy()
		self._popup = nil
	end

	self.OnValueChanged:Destroy()

	BaseComponent.Destroy(self)
end

return Dropdown