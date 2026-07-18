local UserInputService = game:GetService("UserInputService")

local Import = ...
local Create = Import("Core/Create")
local Draw = Import("Core/Draw")
local Signal = Import("Core/Signal")
local InputHandler = Import("Core/InputHandler")
local ThemeEngine = Import("Theme/ThemeEngine")
local ScreenManager = Import("Core/ScreenManager")
local BaseComponent = Import("Components/Base/BaseComponent")
local Label = Import("Components/Basic/Label")

local ColorPicker = setmetatable({}, { __index = BaseComponent })
ColorPicker.__index = ColorPicker

local CONTAINER_HEIGHT = 36
local SWATCH_SIZE = UDim2.new(0, 40, 0, 24)
local POPUP_WIDTH = 180
local SV_SQUARE_SIZE = 150
local HUE_SLIDER_HEIGHT = 16
local POPUP_PADDING = 12
local POPUP_RADIUS = 8

local function isPointerInput(inputType)
	return inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch
end

local function rainbowSequence()
	local keypoints = {}
	local steps = 12
	for i = 0, steps do
		local hue = i / steps
		table.insert(keypoints, ColorSequenceKeypoint.new(hue, Color3.fromHSV(hue, 1, 1)))
	end
	return ColorSequence.new(keypoints)
end

function ColorPicker.new(props)
	props = props or {}

	local container = Create("Frame", {
		Name = "NeroColorPicker",
		Size = UDim2.new(1, 0, 0, CONTAINER_HEIGHT),
		BackgroundTransparency = 1,
		Parent = props.Parent
	})

	local self = BaseComponent.new(container)
	setmetatable(self, ColorPicker)

	self.OnValueChanged = Signal.new()

	local defaultColor = props.Default or ThemeEngine.Current.Accent
	local h, s, v = defaultColor:ToHSV()
	self._hue, self._sat, self._val = h, s, v
	self._open = false
	self._popup = nil

	self._label = Label.new({
		Text = props.Text or "Color",
		Size = UDim2.new(1, -56, 1, 0),
		Parent = container,
	})
	self:AddChild(self._label)

	local swatch = Create("TextButton", {
		Name = "Swatch",
		Size = SWATCH_SIZE,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = defaultColor,
		BorderSizePixel = 0,
		Parent = container,
	})
	Draw.ApplyCorner(swatch, 6)
	Draw.ApplyStroke(swatch, Color3.fromRGB(255, 255, 255), 1, 0.8)
	self._swatch = swatch

	self._input = InputHandler.new(swatch)
	self._input.PressEnd:Connect(function(wasClick)
		if wasClick then
			self:Toggle()
		end
	end)

	return self
end

function ColorPicker:_currentColor()
	return Color3.fromHSV(self._hue, self._sat, self._val)
end

function ColorPicker:_ensurePopup()
	if self._popup then
		return
	end

	local popupHeight = POPUP_PADDING * 3 + SV_SQUARE_SIZE + HUE_SLIDER_HEIGHT
	local popup = Create("Frame", {
		Name = "NeroColorPickerPopup",
		Size = UDim2.new(0, POPUP_WIDTH, 0, popupHeight),
		BorderSizePixel = 0,
		Visible = false,
	})
	Draw.ApplyCorner(popup, POPUP_RADIUS)
	Draw.ApplyPadding(popup, POPUP_PADDING)

	self:OnThemeChanged(function(theme)
		popup.BackgroundColor3 = theme.Surface
	end)
	self._popup = popup

    local svSquare = Create("Frame", {
		Name = "SVSquare",
		Size = UDim2.new(0, SV_SQUARE_SIZE, 0, SV_SQUARE_SIZE),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = Color3.fromHSV(self._hue, 1, 1),
		BorderSizePixel = 0,
		Parent = popup,
	})
	Draw.ApplyCorner(svSquare, 6)
	self._svSquare = svSquare

	local satOverlay = Create("Frame", {
		Name = "SaturationOverlay",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Parent = svSquare,
	})
	Draw.ApplyCorner(satOverlay, 6)
	Create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255)),
		Transparency = NumberSequence.new(0, 1),
		Parent = satOverlay,
	})

	local valOverlay = Create("Frame", {
		Name = "ValueOverlay",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Parent = svSquare,
	})
	Draw.ApplyCorner(valOverlay, 6)
	Create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(0, 0, 0), Color3.fromRGB(0, 0, 0)),
		Transparency = NumberSequence.new(1, 0),
		Parent = valOverlay,
	})

	local svCursor = Create("Frame", {
		Name = "Cursor",
		Size = UDim2.new(0, 10, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = svSquare,
	})
	Draw.ApplyCorner(svCursor, 5)
	Draw.ApplyStroke(svCursor, Color3.fromRGB(0, 0, 0), 1.5)
	self._svCursor = svCursor

    local hueSlider = Create("Frame", {
		Name = "HueSlider",
		Size = UDim2.new(1, 0, 0, HUE_SLIDER_HEIGHT),
		Position = UDim2.new(0, 0, 0, SV_SQUARE_SIZE + POPUP_PADDING),
		BorderSizePixel = 0,
		Parent = popup,
	})
	Draw.ApplyCorner(hueSlider, HUE_SLIDER_HEIGHT / 2)
	Create("UIGradient", {
		Color = rainbowSequence(),
		Parent = hueSlider,
	})
	self._hueSlider = hueSlider

	local hueHandle = Create("Frame", {
		Name = "Handle",
		Size = UDim2.new(0, 6, 1, 4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(self._hue, 0, 0.5, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = hueSlider,
	})
	Draw.ApplyCorner(hueHandle, 3)
	self._hueHandle = hueHandle

	self:_updateCursorPositions()
	self:_setupDragging(svSquare, hueSlider)
end

function ColorPicker:_updateCursorPositions()
	if self._svCursor then
		self._svCursor.Position = UDim2.new(self._sat, 0, 1 - self._val, 0)
	end
	if self._hueHandle then
		self._hueHandle.Position = UDim2.new(self._hue, 0, 0.5, 0)
	end
	if self._svSquare then
		self._svSquare.BackgroundColor3 = Color3.fromHSV(self._hue, 1, 1)
	end
	if self._swatch then
		self._swatch.BackgroundColor3 = self:_currentColor()
	end
end

function ColorPicker:_setupDragging(svSquare, hueSlider)
	local svInput = InputHandler.new(svSquare)
	svInput.PressStart:Connect(function(input)
		local dragging = true

		local function updateFromInput(pos)
			local abs = svSquare.AbsolutePosition
			local size = svSquare.AbsoluteSize
			local relX = size.X > 0 and math.clamp((pos.X - abs.X) / size.X, 0, 1) or 0
			local relY = size.Y > 0 and math.clamp((pos.Y - abs.Y) / size.Y, 0, 1) or 0

			self._sat = relX
			self._val = 1 - relY
			self:_updateCursorPositions()
			self.OnValueChanged:Fire(self:_currentColor())
		end

		updateFromInput(input.Position)

		local moveConn, endConn
		moveConn = UserInputService.InputChanged:Connect(function(moveInput)
			if not dragging then return end
			if moveInput.UserInputType ~= Enum.UserInputType.MouseMovement
				and moveInput.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			updateFromInput(moveInput.Position)
		end)
		endConn = UserInputService.InputEnded:Connect(function(endInput)
			if not isPointerInput(endInput.UserInputType) then return end
			if not dragging then return end
			dragging = false
			moveConn:Disconnect()
			endConn:Disconnect()
		end)
	end)
	self._svInput = svInput

	local hueInput = InputHandler.new(hueSlider)
	hueInput.PressStart:Connect(function(input)
		local dragging = true

		local function updateFromInput(pos)
			local abs = hueSlider.AbsolutePosition
			local size = hueSlider.AbsoluteSize
			local relX = size.X > 0 and math.clamp((pos.X - abs.X) / size.X, 0, 1) or 0

			self._hue = relX
			self:_updateCursorPositions()
			self.OnValueChanged:Fire(self:_currentColor())
		end

		updateFromInput(input.Position)

		local moveConn, endConn
		moveConn = UserInputService.InputChanged:Connect(function(moveInput)
			if not dragging then return end
			if moveInput.UserInputType ~= Enum.UserInputType.MouseMovement
				and moveInput.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			updateFromInput(moveInput.Position)
		end)
		endConn = UserInputService.InputEnded:Connect(function(endInput)
			if not isPointerInput(endInput.UserInputType) then return end
			if not dragging then return end
			dragging = false
			moveConn:Disconnect()
			endConn:Disconnect()
		end)
	end)
	self._hueInput = hueInput
end

function ColorPicker:_positionPopup()
	local pos = self._swatch.AbsolutePosition
	local size = self._swatch.AbsoluteSize
	self._popup.Position = UDim2.new(0, pos.X + size.X - POPUP_WIDTH, 0, pos.Y + size.Y + 4)
end

function ColorPicker:_isPointInside(guiObject, point)
	local pos = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize
	return point.X >= pos.X and point.X <= pos.X + size.X
		and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

function ColorPicker:Open()
	if self._open then
		return
	end

	self:_ensurePopup()
	self._popup.Parent = ScreenManager.GetRoot()
	ScreenManager.BringToFront(self._popup)
	self:_positionPopup()
	self._popup.Visible = true
	self._open = true

	self._outsideClickConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if not isPointerInput(input.UserInputType) then return end

		task.defer(function()
			if not self._open then return end
			local mouse = UserInputService:GetMouseLocation()
			if not self:_isPointInside(self._swatch, mouse) and not self:_isPointInside(self._popup, mouse) then
				self:Close()
			end
		end)
	end)
end

function ColorPicker:Close()
	if not self._open then
		return
	end

	self._open = false
	if self._popup then
		self._popup.Visible = false
	end

	if self._outsideClickConnection then
		self._outsideClickConnection:Disconnect()
		self._outsideClickConnection = nil
	end
end

function ColorPicker:Toggle()
	if self._open then
		self:Close()
	else
		self:Open()
	end
end

function ColorPicker:SetValue(color)
	local h, s, v = color:ToHSV()
	self._hue, self._sat, self._val = h, s, v
	self:_updateCursorPositions()
	self.OnValueChanged:Fire(self:_currentColor())
end

function ColorPicker:GetValue()
	return self:_currentColor()
end

function ColorPicker:Destroy()
	self:Close()

	if self._input then
		self._input:Destroy()
		self._input = nil
	end
	if self._svInput then
		self._svInput:Destroy()
		self._svInput = nil
	end
	if self._hueInput then
		self._hueInput:Destroy()
		self._hueInput = nil
	end
	if self._popup then
		self._popup:Destroy()
		self._popup = nil
	end

	self.OnValueChanged:Destroy()

	BaseComponent.Destroy(self)
end

return ColorPicker