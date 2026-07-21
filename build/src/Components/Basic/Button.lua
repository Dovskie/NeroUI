local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local Tween = Import('Core/Tween')
local Signal = Import('Core/Signal')
local InputHandler = Import('Core/InputHandler')
local ThemeEngine = Import('Theme/ThemeEngine')
local BaseComponent = Import('Components/Base/BaseComponent')
local Icons = Import('Assets/Icons')

local Button = setmetatable({}, { __index = BaseComponent })
Button.__index = Button

local DEFAULT_SIZE = UDim2.new(0, 140, 0, 36)
local CORNER_RADIUS = 6
local COLOR_TWEEN_DURATION = 0.15

function Button.new(props)
    props = props or {}

    local hasCustomColor = props.Color ~= nil
    local baseColor = props.Color or ThemeEngine.Current.Accent
    local hoverColor = props.HoverColor or (hasCustomColor and baseColor or ThemeEngine.Current.AccentHover)
    local pressedColor = props.PressedColor or (hasCustomColor and baseColor or ThemeEngine.Current.AccentPressed)

    local inst = Create('TextButton', {
        Name = 'NeroButton',
        Size = props.Size or DEFAULT_SIZE,
        BackgroundColor3 = baseColor,
        AutoButtonColor = false,
        Text = '',
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        Font = Enum.Font.GothamMedium,
        BorderSizePixel = 0,
        Parent = props.Parent
    })
    Draw.ApplyCorner(inst, CORNER_RADIUS)

    Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, ICON_TEXT_GAP),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = inst,
    })

    local iconImage
    if hasIcon then
        iconImage = Icons.CreateImage(props.Icon, {
            Name = 'Icon',
            Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE),
            ImageColor3 = Color3.fromRGB(255, 255, 255),
            LayoutOrder = 1,
            Parent = inst,
        })
    end

    local textLabel = Create('TextLabel', {
        Name = 'ButtonText',
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = props.Text or 'Button',
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 14,
        Font = Enum.Font.GothamMedium,
        LayoutOrder = 2,
        Parent = inst,
    })
    
    local self = BaseComponent.new(inst)
    setmetatable(self, Button)

    self._textLabel = textLabel
    self._iconImage = iconImage

    self.OnClick = Signal.new()
    self:BindCallback(self.OnClick, props.Callback)

    self._input = InputHandler.new(inst)
    self._currentTween = nil

    self._hasCustomColor = hasCustomColor
    self._color = baseColor
    self._hoverColor = hoverColor
    self._pressedColor = pressedColor

    local function tweenTo(color)
        if self._currentTween then self._currentTween:Cancel() end
        self._currentTween = Tween.Quick(self.Instance, {BackgroundColor3 = color}, COLOR_TWEEN_DURATION)
    end

    self._input.HoverStart:Connect(function()
		if not self._input.Pressed then tweenTo(self._hoverColor) end
	end)

    self._input.HoverEnd:Connect(function()
        if not self._input.Pressed then tweenTo(self._color) end
    end)

    self._input.PressStart:Connect(function()
        tweenTo(self._pressedColor)
    end)

    self._input.PressEnd:Connect(function(wasClick)
        tweenTo(self._input.Hovering and self._hoverColor or self._color)
        if wasClick then
            self.OnClick:Fire()
        end
    end)

    self:OnThemeChanged(function(theme)
        -- Kalo Color di-set manual (misal Danger), warnanya independen dari tema,
        -- jadi ga usah di-refresh pas tema ganti.
        if not self._hasCustomColor then
            self._color = theme.Accent
            self._hoverColor = theme.AccentHover
            self._pressedColor = theme.AccentPressed
        end

        if self._input.Pressed then
            self.Instance.BackgroundColor3 = self._pressedColor
        elseif self._input.Hovering then
            self.Instance.BackgroundColor3 = self._hoverColor
        else
            self.Instance.BackgroundColor3 = self._color
        end
        self._textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)

    return self
end

-- Ganti warna base/hover/pressed button setelah dibuat (misal toggle Danger state).
function Button:SetColors(color, hoverColor, pressedColor)
    self._hasCustomColor = color ~= nil
    self._color = color or ThemeEngine.Current.Accent
    self._hoverColor = hoverColor or (self._hasCustomColor and self._color or ThemeEngine.Current.AccentHover)
    self._pressedColor = pressedColor or (self._hasCustomColor and self._color or ThemeEngine.Current.AccentPressed)

    if self._input.Pressed then
        self.Instance.BackgroundColor3 = self._pressedColor
    elseif self._input.Hovering then
        self.Instance.BackgroundColor3 = self._hoverColor
    else
        self.Instance.BackgroundColor3 = self._color
    end
end

function Button:SetText(text)
	self.Instance.Text = text
end

function Button:Destroy()
    if self._currentTween then self._currentTween:Destroy() self._currentTween = nil end
    if self._input then self._input:Destroy() self._input = nil end
    self.OnClick:Destroy()
    BaseComponent.Destroy(self)
end

return Button