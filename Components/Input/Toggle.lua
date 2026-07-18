local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local Tween = Import('Core/Tween')
local Signal = Import('Core/Signal')
local InputHandler = Import('Core/InputHandler')
local ThemeEngine = Import('Theme/ThemeEngine')
local BaseComponent = Import('Components/Base/BaseComponent')
local Label = Import('Components/Basic/Label')

local Toggle = setmetatable({}, {__index = BaseComponent})
Toggle.__index = Toggle

local CONTAINER_HEIGHT = 36
local TRACK_SIZE = UDim2.new(0, 36, 0, 20)
local KNOB_SIZE = UDim2.new(0, 16, 0, 16)
local KNOB_MARGIN = 2
local COLOR_TWEEN_DURATION = 0.15
local KNOB_TWEEN_DURATION = 0.15

function Toggle.new(props)
    props = props or {}

    local inst = Create('Frame', {
        Name ='NeroToggle',
        Size = UDim2.new(1, 0, 0, CONTAINER_HEIGHT),
        BackgroundTransparency = 1,
        Parent = props.Parent
    })

    local self = BaseComponent.new(inst)
    setmetatable(self, Toggle)
    
    self.OnValueChanged = Signal.new()
    self._value = props.Default == true

    self._label = Label.new({
        Text = props.Text or 'Toggle',
        Size = UDim2.new(1, -56, 1, 0),
        Parent = inst
    })
    self:AddChild(self._label)

    local track = Create('Frame', {
        Name = 'Track',
        Size = TRACK_SIZE,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        BorderSizePixel = 0,
        Parent = inst
    })
    Draw.ApplyCorner(track, TRACK_SIZE.Y.Offset / 2)

    self._track = track

    local knob = Create('Frame', {
        Name = 'Knob',
        Size = KNOB_SIZE,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, KNOB_MARGIN, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Parent = track
    })
    Draw.ApplyCorner(knob, KNOB_SIZE.Y.Offset / 2)

    self._knob = knob
    self._knobTween = nil
    self._trackTween = nil

    local function knobOffsetX()
        if self._value then
            return TRACK_SIZE.X.Offset - KNOB_SIZE.X.Offset - KNOB_MARGIN
        end
        return KNOB_MARGIN
    end

    local function updateVisual(animated)
        local targetTrackColor = self._value and ThemeEngine.Current.Accent or ThemeEngine.Current.Border
        local targetKnobX = knobOffsetX()

        if animated then
            if self._trackTween then self._trackTween:Cancel() end
            if self._knobTween then self._knobTween:Cancel() end

            self._trackTween = Tween.Quick(track, {BackgroundColor3 = targetTrackColor}, COLOR_TWEEN_DURATION)
            self._knobTween = Tween.Quick(knob, {Position = UDim2.new(0, targetKnobX, 0.5, 0)}, KNOB_TWEEN_DURATION)
        else
            track.BackgroundColor3 = targetTrackColor
            knob.Position = UDim2.new(0, targetKnobX, 0.5, 0)
        end
    end

    self._input = InputHandler.new(track)
    self._input.PressEnd:Connect(function(wasClick)
        if wasClick then
            self:SetValue(not self._value)
        end
    end)

    self:OnThemeChanged(function()
        updateVisual(false)
    end)

    self._updateVisual = updateVisual

    return self
end

function Toggle:SetValue(value, animated)
    value = value == true
    if value == self._value then return end

    self._value = value
    self._updateVisual(animated ~= false)
    self.OnValueChanged:Fire(self._value)
end

function Toggle:GetValue(value)
    return self._value
end

function Toggle:Destroy()
    if self._trackTween then
        self._trackTween:Destroy()
        self._trackTween = nil
    end
    if self._knobTween then
        self._knobTween:Destroy()
        self._knobTween = nil
    end
    if self._input then
        self._input:Destroy()
        self._input = nil
    end

    self.OnValueChanged:Destroy()
    BaseComponent.Destroy(self)
end

return Toggle