local UserInputService = game:GetService("UserInputService")
local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local Tween = Import('Core/Tween')
local Signal = Import('Core/Signal')
local InputHandler = Import('Core/InputHandler')
local ThemeEngine = Import('Theme/ThemeEngine')
local BaseComponent = Import('Components/Base/BaseComponent')
local Label = Import('Components/Basic/Label')

local Slider = setmetatable({}, {__index = BaseComponent})
Slider.__index = Slider

local CONTAINER_HEIGHT = 44
local LABEL_ROW_HEIGHT =18
local TRACK_HEIGHT = 6
local HANDLE_SIZE = 12
local FILL_TWEEN_DURATION = 0.1

local function isPointerInput(inputType)
    return inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch
end

function Slider.new(props)
    props = props or {}

    local min = props.Min or 0
    local max = props.Max or 100
    assert(max > min, 'Slider.new: Max harus lebih besar dari Min')

    local inst = Create('Frame', {
        Name = 'NeroSlider',
        Size = UDim2.new(1, 0, 0, CONTAINER_HEIGHT),
        BackgroundTransparency = 1,
		Parent = props.Parent
    })

    local self = BaseComponent.new(inst)
    setmetatable(self, Slider)
    
    self.OnValueChanged = Signal.new()
	self:BindCallback(self.OnValueChanged, props.Callback)
	
    self._min = min
    self._max = max
    self._step = props.Step
    self._value = math.clamp(props.Default or min, min, max)

    self._label = Label.new({
        Text = props.Text or 'Slider',
        Size = UDim2.new(1, -50, 0, LABEL_ROW_HEIGHT),
        Parent = inst
    })
    self:AddChild(self._label)

    local valueBox = Create('TextBox', {
		Name = 'ValueInput',
		Size = UDim2.new(0, 50, 0, LABEL_ROW_HEIGHT),
		Position = UDim2.new(1, -50, 0, 0),
		BackgroundTransparency = 1,
		Text = tostring(self._value),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
		ClearTextOnFocus = false,
		Parent = inst,
	})
	self._valueBox = valueBox

	self:OnThemeChanged(function(theme)
		valueBox.TextColor3 = theme.TextDim
	end)

	valueBox.FocusLost:Connect(function()
		local number = tonumber(valueBox.Text)
		if number then
			self:SetValue(number, true)
		else
			valueBox.Text = tostring(self._value)
		end
	end)

    self:AddChild(self._valueBox)

    local track = Create('Frame', {
        Name = 'Track',
        Size = UDim2.new(1, 0, 0, TRACK_HEIGHT),
		Position = UDim2.new(0, 0, 1, -TRACK_HEIGHT),
		BorderSizePixel = 0,
		Parent = inst,
    })
    Draw.ApplyCorner(track, TRACK_HEIGHT / 2)
	self._track = track

	local fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.new(0, 0, 1, 0),
		BorderSizePixel = 0,
		Parent = track,
	})
	Draw.ApplyCorner(fill, TRACK_HEIGHT / 2)
	self._fill = fill

	local handle = Create("Frame", {
		Name = "Handle",
		Size = UDim2.new(0, HANDLE_SIZE, 0, HANDLE_SIZE),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		Parent = track,
	})
	Draw.ApplyCorner(handle, HANDLE_SIZE / 2)
	self._handle = handle

	self._fillTween = nil
	self._dragging = false

    local function percent()
		return (self._value - self._min) / (self._max - self._min)
	end

    local function updateVisual(animated)
		local p = percent()
		local fillWidth = UDim2.new(p, 0, 1, 0)
		local handlePos = UDim2.new(p, 0, 0.5, 0)

		if animated then
			if self._fillTween then
				self._fillTween:Cancel()
			end
			self._fillTween = Tween.Quick(fill, { Size = fillWidth }, FILL_TWEEN_DURATION)
			Tween.Quick(handle, { Position = handlePos }, FILL_TWEEN_DURATION)
		else
			fill.Size = fillWidth
			handle.Position = handlePos
		end

		self._valueBox.Text = tostring(self._value)
	end
	self._updateVisual = updateVisual

    local function valueFromAbsoluteX(x)
		local trackPos = track.AbsolutePosition.X
		local trackWidth = track.AbsoluteSize.X
		local relative = trackWidth > 0 and math.clamp((x - trackPos) / trackWidth, 0, 1) or 0

		local rawValue = self._min + (self._max - self._min) * relative
		if self._step and self._step > 0 then
			rawValue = math.floor(rawValue / self._step + 0.5) * self._step
		end
		return math.clamp(rawValue, self._min, self._max)
	end

	self._input = InputHandler.new(track)

    self._input.PressStart:Connect(function(input)
		self._dragging = true
		self:SetValue(valueFromAbsoluteX(input.Position.X), false)

		local moveConnection
		local endConnection

		moveConnection = UserInputService.InputChanged:Connect(function(moveInput)
			if not self._dragging then
				return
			end
			if moveInput.UserInputType ~= Enum.UserInputType.MouseMovement
				and moveInput.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			self:SetValue(valueFromAbsoluteX(moveInput.Position.X), false)
		end)

		endConnection = UserInputService.InputEnded:Connect(function(endInput)
			if not isPointerInput(endInput.UserInputType) then
				return
			end
			if not self._dragging then
				return
			end
			self._dragging = false
			moveConnection:Disconnect()
			endConnection:Disconnect()
		end)
	end)

    self:OnThemeChanged(function(theme)
		track.BackgroundColor3 = theme.Border
		fill.BackgroundColor3 = theme.Accent
		updateVisual(false)
	end)

	return self
end

function Slider:SetValue(value, animated)
    value = math.clamp(value, self._min, self._max)
	if self._step and self._step > 0 then
		value = math.floor(value / self._step + 0.5) * self._step
	end

	if value == self._value then
		return
	end

	self._value = value
	self._updateVisual(animated ~= false)
	self.OnValueChanged:Fire(self._value)
end

function Slider:GetValue()
	return self._value
end

function Slider:Destroy()
	if self._fillTween then
		self._fillTween:Destroy()
		self._fillTween = nil
	end
	if self._input then
		self._input:Destroy()
		self._input = nil
	end

	self.OnValueChanged:Destroy()

	BaseComponent.Destroy(self)
end

return Slider