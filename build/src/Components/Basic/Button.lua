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
    local inst = Create('TextButton', {
        Name = 'NeroButton',
        Size = props.Size or DEFAULT_SIZE,
        BackgroundColor3 = ThemeEngine.Current.Accent,
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

    local function tweenTo(color)
        if self._currentTween then self._currentTween:Cancel() end
        self._currentTween = Tween.Quick(self.Instance, {BackgroundColor3 = color}, COLOR_TWEEN_DURATION)
    end

    self._input.HoverStart:Connect(function()
		if not self._input.Pressed then tweenTo(ThemeEngine.Current.AccentHover) end
	end)

    self._input.HoverEnd:Connect(function()
        if not self._input.Pressed then tweenTo(ThemeEngine.Current.Accent) end
    end)

    self._input.PressStart:Connect(function()
        tweenTo(ThemeEngine.Current.AccentPressed)
    end)

    self._input.PressEnd:Connect(function(wasClick)
        tweenTo(self._input.Hovering and ThemeEngine.Current.AccentHover or ThemeEngine.Current.Accent)
        if wasClick then
            self.OnClick:Fire()
        end
    end)

    self:OnThemeChanged(function(theme)
        if self._input.Pressed then
            self.Instance.BackgroundColor3 = theme.AccentPressed
        elseif self._input.Hovering then
            self.Instance.BackgroundColor3 = theme.AccentHover
        else
            self.Instance.BackgroundColor3 = theme.Accent
        end
        self._textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)

    return self
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