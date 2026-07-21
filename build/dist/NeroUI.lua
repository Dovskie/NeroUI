local Modules = {}

Modules["Assets/Icons"] = function(...)
local Import = ...
local Create = Import("Core/Create")

local Icons = {}

local _icons = {}
local _lucide = nil
local _lucideLoadAttempted = false

local LUCIDE_BUNDLE_URL = "https://github.com/latte-soft/lucide-roblox/releases/latest/download/lucide-roblox.luau"

local function getLucide()
	if _lucide or _lucideLoadAttempted then
		return _lucide
	end
	_lucideLoadAttempted = true

	local fetchOk, source = pcall(game.HttpGet, game, LUCIDE_BUNDLE_URL)
	if not fetchOk then
		warn("Icons.lua: gagal fetch Lucide bundle -> " .. tostring(source))
		return nil
	end

	local compileOk, LucideOrErr = pcall(function()
		return loadstring(source)()
	end)
	if not compileOk then
		warn("Icons.lua: gagal compile Lucide bundle -> " .. tostring(LucideOrErr))
		return nil
	end

	_lucide = LucideOrErr
	return _lucide
end

function Icons.Register(name, assetId)
	assert(type(name) == "string" and name ~= "", "Icons.Register butuh name berupa string")
	assert(type(assetId) == "string" and assetId ~= "", "Icons.Register butuh assetId berupa string")

	_icons[name] = { Id = assetId, Rect = nil, Size = nil }
end

function Icons.RegisterSprite(name, assetId, rectOffset, rectSize)
	assert(type(name) == "string" and name ~= "", "Icons.RegisterSprite butuh name berupa string")
	assert(type(assetId) == "string" and assetId ~= "", "Icons.RegisterSprite butuh assetId berupa string")
	assert(typeof(rectOffset) == "Vector2", "Icons.RegisterSprite butuh rectOffset berupa Vector2")
	assert(typeof(rectSize) == "Vector2", "Icons.RegisterSprite butuh rectSize berupa Vector2")

	_icons[name] = { Id = assetId, Rect = rectOffset, Size = rectSize }
end

function Icons.RegisterBatch(map)
	for name, assetId in map do
		Icons.Register(name, assetId)
	end
end

function Icons.Get(name)
	return _icons[name]
end

function Icons.IsRegistered(name)
	return _icons[name] ~= nil
end

local function tryAutoRegister(name)
	local Lucide = getLucide()
	if not Lucide then return nil end

	local ok, asset = pcall(Lucide.GetAsset, name, 48)
	if not ok then
		warn(("Icons.lua: icon Lucide \"%s\" ga ketemu -> %s"):format(name, tostring(asset)))
		return nil
	end

	Icons.RegisterSprite(name, asset.Url, asset.ImageRectOffset, asset.ImageRectSize)
	return _icons[name]
end

function Icons.CreateImage(name, props)
	props = props or {}
	local entry = Icons.Get(name) or tryAutoRegister(name)

	if not entry then
		warn(("Icons.CreateImage: icon \"%s\" ga ketemu, ImageLabel dibikin kosong"):format(name))
	end

	local merged = {
		BackgroundTransparency = 1,
	}
	for key, value in props do
		merged[key] = value
	end
	merged.Image = entry and entry.Id or ""

	if entry and entry.Rect and entry.Size then
		merged.ImageRectOffset = entry.Rect
		merged.ImageRectSize = entry.Size
	end

	return Create("ImageLabel", merged)
end

return Icons
end

Modules["Components/Base/BaseComponent"] = function(...)
local Import = ...
local Signal = Import('Core/Signal')
local ThemeEngine = Import('Theme/ThemeEngine')

local BaseComponent = {}
BaseComponent.__index = BaseComponent

function BaseComponent.new(inst)
    assert(typeof(inst) == 'Instance' and inst:IsA('GuiObject'), 'BaseComponent.new butuh GuiObject sebagai instance utama')

    local self = setmetatable({}, BaseComponent)

    self.Instance = inst
    self.Destroyed = false

    self._themeConn = nil
    self._connections = {}
    self._children = {}

    return self
end

function BaseComponent:BindCallback(signal, callback)
    if type(callback) ~= 'function' then return end
    local connection = signal:Connect(callback)
    table.insert(self._connections, connection)
    return connection
end

function BaseComponent:OnThemeChanged(callback)
    assert(typeof(callback) == 'function', 'OnThemeChanged butuh function')

    local connection = ThemeEngine.Changed:Connect(function()
        callback(ThemeEngine.Current)
    end)
    table.insert(self._connections, connection)

    callback(ThemeEngine.Current)

    return connection
end

function BaseComponent:AddChild(childComponent)
    table.insert(self._children, childComponent)
    return childComponent
end

function BaseComponent:Destroy()
    if self.Destroyed then return end

    self.Destroyed = true
    for _, child in self._children do
        child:Destroy()
    end
    table.clear(self._children)

    for _, connection in self._connections do
        connection:Disconnect()
    end
    table.clear(self._connections)

    if self.Instance then
        self.Instance:Destroy()
        self.Instance = nil
    end
end

return BaseComponent
end

Modules["Components/Basic/Button"] = function(...)
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
end

Modules["Components/Basic/Label"] = function(...)
local Import = ...
local Create = Import('Core/Create')
local ThemeEngine = Import('Theme/ThemeEngine')
local BaseComponent = Import('Components/Base/BaseComponent')

local Label = setmetatable({}, {__index = BaseComponent})
Label.__index = Label

local DEFAULT_SIZE = UDim2.new(1,0,0,20)

function Label.new(props)
    props = props or {}

    local inst = Create('TextLabel', {
        Name = 'NeroLabel',
        Size = props.Size or DEFAULT_SIZE,
        Position = props.Position,
        BackgroundTransparency = 1,
        Text = props.Text or '',
        TextSize = props.TextSize or 14,
        Font = props.Bold and Enum.Font.GothamBold or Enum.Font.GothamMedium,
        TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = props.Parent
    })
    local self = BaseComponent.new(inst)
    setmetatable(self, Label)

    self._variant = props.Variant == 'Dim' and 'Dim' or 'Primary'

    self:OnThemeChanged(function(theme)
        self.Instance.TextColor3 = self._variant == 'Dim' and theme.TextDim or theme.Text
    end)

    return self
end

function Label:SetText(txt)
    self.Instance.Text = txt
end

function Label:SetVariant(variant)
    self._variant = variant == 'Dim' and 'Dim' or 'Primary'
    
    self.Instance.TextColor3 = self._variant == 'Dim' and ThemeEngine.Current.TextDim or ThemeEngine.Current.Text
end

return Label
end

Modules["Components/Basic/Separator"] = function(...)
local Import = ...
local Create = Import('Core/Create')
local BaseComponent = Import('Components/Base/BaseComponent')

local Separator = setmetatable({}, {__index = BaseComponent})
Separator.__index = Separator

local DEFAULT_HEIGHT = 1

function Separator.new(props)
    props = props or {}

    local inst = Create('Frame', {
        Name = 'NeroSeparator',
        Size = UDim2.new(1, 0, 0, props.Thickness or DEFAULT_HEIGHT),
        BorderSizePixel = 0,
        Parent = props.Parent
    })

    local self = BaseComponent.new(inst)
    setmetatable(self, Separator)

    self:OnThemeChanged(function(theme)
        self.Instance.BackgroundColor3 = theme.Border
    end)

    return self
end

return Separator
end

Modules["Components/Feedback/Notification"] = function(...)
local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local Tween = Import('Core/Tween')
local InputHandler = Import('Core/InputHandler')
local ScreenManager = Import('Core/ScreenManager')
local BaseComponent = Import('Components/Base/BaseComponent')
local Label = Import('Components/Basic/Label')

local Notification = setmetatable({}, {__index = BaseComponent})
Notification.__index = Notification

local CONTAINER_WIDTH = 280
local CONTAINER_MARGIN = 16
local CARD_PADDING = 12
local CARD_GAP = 8
local ACCENT_BAR_WIDTH = 3
local DEFAULT_DURATION = 4
local SLIDE_DISTANCE = 40
local ANIM_DURATION = 0.25

local TYPE_COLORS = {
    Success = Color3.fromRGB(87, 201, 122),
    Warning = Color3.fromRGB(230, 180, 60),
    Error = Color3.fromRGB(224, 90, 90)
}

local _container = nil
local _layoutOrderCounter = 0

local function ensureContainer()
    if _container then return _container end

    local container = Create('Frame', {
        Name = 'NeroNotification',
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -CONTAINER_MARGIN, 1, -CONTAINER_MARGIN),
        Size = UDim2.new(0, CONTAINER_WIDTH, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = ScreenManager.GetRoot()
    })
    Draw.ApplyListLayout(container, CARD_GAP, 'Vertical')

    _container = container
    return container
end

function Notification.Show(props)
    props = props or {}
    
    local container = ensureContainer()
    local accentColor = TYPE_COLORS[props.Type]

    _layoutOrderCounter += 1

    local card = Create('Frame', {
        Name = 'NotificationCard',
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        LayoutOrder = _layoutOrderCounter,
        ClipsDescendants = true,
        Parent = container,
    })
    Draw.ApplyCorner(card, 8)

    local self = BaseComponent.new(card)
    setmetatable(self, Notification)

    self:OnThemeChanged(function(theme)
        card.BackgroundColor3 = theme.Surface
    end)

    local accentBar = Create('Frame', {
        Name = 'AccentBar',
        Size = UDim2.new(0, ACCENT_BAR_WIDTH, 0, 0),
        BorderSizePixel = 0,
        Parent = card
    })
    self:OnThemeChanged(function(theme)
        accentBar.BackgroundColor3 = accentColor or theme.Accent
    end)

    local content = Create('Frame', {
        Name = 'Content',
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = card,
    })
    Draw.ApplyPadding(content, {top = CARD_PADDING, bottom = CARD_PADDING, left = CARD_PADDING + ACCENT_BAR_WIDTH + 6, right = CARD_PADDING})
    Draw.ApplyListLayout(content, 2, 'Vertical')

    local function syncAccentBarHeight()
        accentBar.Size = UDim2.new(0, ACCENT_BAR_WIDTH, 0, content.AbsoluteSize.Y)
    end

    local sizeConn = content:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncAccentBarHeight)
    table.insert(self._connections, sizeConn)
    syncAccentBarHeight()

    self._title = Label.new({
        Text = props.Title or 'Notification', 
        Bold = true,
        Size = UDim2.new(1, 0, 0, 18),
        Parent = content,
    })
    self:AddChild(self._title)

    if props.Message then
        self._message = Label.new({
            Text = props.Message,
            Size = UDim2.new(1, 0, 0, 0),
            Variant = 'Dim',
            TextSize = 13,
            Parent = content
        })
        self._message.Instance.TextWrapped = true
        self._message.Instance.AutomaticSize = Enum.AutomaticSize.Y
        self:AddChild(self._message)
    end

    self._input = InputHandler.new(card)
    self._input.PressEnd:Connect(function(wasClick)
        if wasClick then
            self:Close()
        end
    end)
    
    self._closed = false

    card.Position = UDim2.new(0, SLIDE_DISTANCE, 0, 0)
    card.BackgroundTransparency = 1
    accentBar.BackgroundTransparency = 1
    Tween.Quick(card, { Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0 }, ANIM_DURATION)
    Tween.Quick(accentBar, { BackgroundTransparency = 0 }, ANIM_DURATION)

    task.delay(props.Duration or DEFAULT_DURATION, function()
        if not self._closed then
            self:Close()
        end
    end)

    return self
end

function Notification:Close()
    if self._closed then return end
    self._closed = true
    local tween = Tween.Quick(self.Instance, {
        Position = UDim2.new(0, SLIDE_DISTANCE, 0, 0),
        BackgroundTransparency = 1,
    }, ANIM_DURATION)

    tween.Completed:Connect(function()
        self:Destroy()
    end)
end

function Notification:Destroy()
    if self._input then
        self._input:Destroy()
        self._input = nil
    end

    BaseComponent.Destroy(self)
end

return Notification
end

Modules["Components/Feedback/Tooltip"] = function(...)
local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local InputHandler = Import('Core/InputHandler')
local ScreenManager = Import('Core/ScreenManager')
local ThemeEngine = Import('Theme/ThemeEngine')

local Tooltip = {}
Tooltip.__index = Tooltip

local DEFAULT_DELAY = 0.5
local TOOLTIP_PADDING = 8
local TOOLTIP_RADIUS = 6
local TOOLTIP_GAP_FROM_TARGET = 6
local TOOLTIP_MAX_WIDTH = 220

function Tooltip.Attach(targetInst, props)
    assert(typeof(targetInst) == 'Instance' and targetInst:IsA('GuiObject'), 'Tooltip.Attach butuh GuiObject sebagai target')

    props = props or {}
    
    local self = setmetatable({}, Tooltip)
    self._target = targetInst
    self._text = props.Text or ''
    self._delay = props.Delay or DEFAULT_DELAY
    self._card = nil
    self._visible = false
    self._themeConn = nil
    self._generation = 0

    self._input = InputHandler.new(targetInst)
    self._input.HoverStart:Connect(function()
        self._generation += 1
        local myGeneration = self._generation

        task.delay(self._delay, function()
            if self._generation == myGeneration then
                self:_show()
            end
        end)
    end)

    self._input.HoverEnd:Connect(function()
        self._generation += 1
        self:_hide()
    end)

    return self
end

function Tooltip:_ensureCard()
    if self._card then return end

    local card = Create('TextLabel', {
        Name = 'NeroTooltip',
        AutomaticSize = Enum.AutomaticSize.XY,
        Size = UDim2.new(0, 0, 0, 0),
        BorderSizePixel = 0,
        Text = self._text,
        TextWrapped = true,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        Visible = false,
        ZIndex = 1000,
        Parent = ScreenManager.GetRoot()
    })
    Draw.ApplyCorner(card, TOOLTIP_RADIUS)
    Draw.ApplyPadding(card, TOOLTIP_PADDING)

    local sizeConstraint = Create('UISizeConstraint', {
        MaxSize = Vector2.new(TOOLTIP_MAX_WIDTH, math.huge)
    })
    sizeConstraint.Parent = card

    self._card = card
    
    self._themeConn = ThemeEngine.Changed:Connect(function()
        card.BackgroundColor3 = ThemeEngine.Current.Surface
        card.TextColor3 = ThemeEngine.Current.Text
    end)
    card.BackgroundColor3 = ThemeEngine.Current.Surface
    card.TextColor3 = ThemeEngine.Current.Text
end

function Tooltip:_positionCard()
    local targetPos = self._target.AbsolutePosition
    local targetSize = self._target.AbsoluteSize
    local cardSize = self._card.AbsoluteSize

    local x = targetPos.X + (targetSize.X / 2) - (cardSize.X / 2)
    local y = targetPos.Y - cardSize.Y - TOOLTIP_GAP_FROM_TARGET

    self._card.Position = UDim2.new(0, x, 0, y)
end

function Tooltip:_show()
    self:_ensureCard()
    ScreenManager.BringToFront(self._card)
    self:_positionPopupSafe()
    self._card.Visible = true
    self._visible = true
end

function Tooltip:_positionPopupSafe()
    self:_positionCard()
    task.defer(function()
        if self._card then self:_positionCard() end
    end)
end

function Tooltip:_hide()
    if self._card then self._card.Visible = false end

    self._visible = false
end

function Tooltip:SetText(text)
    self._text = text
    if self._card then self._card.Text = text end
end

function Tooltip:Destroy()
    self._generation += 1

    if self._input then
        self._input:Destroy()
        self._input = nil
    end

    if self._themeConn then
        self._themeConn:Disconnect()
        self._themeConn = nil
    end

    if self._card then
        self._card:Destroy()
        self._card = nil
    end 
end

return Tooltip
end

Modules["Components/Input/Keybind"] = function(...)
local UserInputService = game:GetService('UserInputService')
local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local Signal = Import('Core/Signal')
local InputHandler = Import('Core/InputHandler')
local ThemeEngine = Import('Theme/ThemeEngine')
local BaseComponent = Import('Components/Base/BaseComponent')
local Label = Import('Components/Basic/Label')

local Keybind = setmetatable({}, {__index = BaseComponent})
Keybind.__index = Keybind

local CONTAINER_HEIGHT = 36
local KEY_BUTTON_SIZE = UDim2.new(0, 70, 0, 26)
local KEY_BUTTON_RADIUS = 6

local function inputToKeyCode(input)
    if input.KeyCode ~= Enum.KeyCode.Unknown then
        return input.KeyCode
    end
    return nil
end

local function displayName(keyCode)
    if keyCode then
        return keyCode.Name
    end
    return "None"
end

function Keybind.new(props)
    props = props or {}

    local inst = Create('Frame', {
        Name = 'NeroKeybind',
        Size = UDim2.new(1, 0, 0, CONTAINER_HEIGHT),
        BackgroundTransparency = 1,
        Parent = props.Parent
    })
    
    local self = BaseComponent.new(inst)
    setmetatable(self, Keybind)

    self.OnValueChanged = Signal.new()
    self:BindCallback(self.OnValueChanged, props.Callback)
    
    self._value = props.Default
    self._listening = false
    self._listenConn = nil

    self._label = Label.new({
        Text = props.Text or 'Keybind',
        Size = UDim2.new(1, -80, 1, 0),
        Parent = inst
    })
    self:AddChild(self._label)

    local keyButton = Create('TextButton', {
        Name = 'KeyButton',
        Size = KEY_BUTTON_SIZE,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        AutoButtonColor = false,
        Text = displayName(self._value),
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Parent = inst,
    })
    Draw.ApplyCorner(keyButton, KEY_BUTTON_RADIUS)
    self._keyButton = keyButton

    self._input = InputHandler.new(keyButton)
    self._input.PressEnd:Connect(function(wasClick)
        if wasClick and not self._listening then
            self:_startListening()
        end
    end)

    self:OnThemeChanged(function(theme)
        keyButton.BackgroundColor3 = self._listening and theme.Accent or theme.Surface
        keyButton.TextColor3 = theme.Text
    end)

    return self
end

function Keybind:_startListening()
    self._listening = true
    self._keyButton.Text = '...'
    self._keyButton.BackgroundColor3 = ThemeEngine.Current.Accent

    self._listenConn = UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if gameProcessedEvent then return end

        if input.KeyCode == Enum.KeyCode.Escape then
            self:_stopListening()
            return
        end

        local keyCode = inputToKeyCode(input)
        if not keyCode then return end

        self._value = keyCode
        self:_stopListening()
        self.OnValueChanged:Fire(self._value)
    end)
end

function Keybind:_stopListening()
    self._listening = false
    self._keyButton.Text = displayName(self._value)

    if self._listenConn then
        self._listenConn:Disconnect()
        self._listenConn = nil
    end
    
    self._keyButton.BackgroundColor3 = ThemeEngine.Current.Surface
end

function Keybind:SetValue(keyCode)
    if self._listening then
        self:_stopListening()
    end

    self._value = keyCode
    self._keyButton.Text = displayName(keyCode)
    self.OnValueChanged:Fire(self._value)
end

function Keybind:GetValue()
    return self._value
end

function Keybind:Destroy()
    if self._listenConn then
        self._listenConn:Disconnect()
        self._listenConn = nil
    end
    
    if self._input then
        self._input:Destroy()
        self._input = nil
    end

    self.OnValueChanged:Destroy()
    BaseComponent.Destroy(self)
end

return Keybind
end

Modules["Components/Input/Slider"] = function(...)
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

    self._valueLabel = Label.new({
        Text = tostring(self._value),
        Size = UDim2.new(0, 50, 0, LABEL_ROW_HEIGHT),
		Position = UDim2.new(1, -50, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Variant = "Dim",
        Parent = inst
    })

    self:AddChild(self._valueLabel)

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

		self._valueLabel:SetText(tostring(self._value))
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
end

Modules["Components/Input/Toggle"] = function(...)
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
    self:BindCallback(self.OnValueChanged, props.Callback)
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
end

Modules["Components/Layout/ScrollFrame"] = function(...)
local Import = ...
local Create = Import("Core/Create")
local Draw = Import("Core/Draw")
local BaseComponent = Import("Components/Base/BaseComponent")

local ScrollFrame = setmetatable({}, { __index = BaseComponent })
ScrollFrame.__index = ScrollFrame

local CONTENT_GAP = 10
local SCROLLBAR_THICKNESS = 4

function ScrollFrame.new(props)
	props = props or {}

	local instance = Create("ScrollingFrame", {
		Name = "NeroScrollFrame",
		Size = props.Size or UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = SCROLLBAR_THICKNESS,
		ScrollBarImageTransparency = 0.3,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = props.Parent,
	})

    Draw.ApplyPadding(instance, {
        top = 12,
        bottom = 12,
        left = 12,
        right = 12 + SCROLLBAR_THICKNESS + 4,
    })

	local listLayout = Draw.ListLayout(CONTENT_GAP, "Vertical")
	listLayout.Parent = instance

	local self = BaseComponent.new(instance)
	setmetatable(self, ScrollFrame)

	self._listLayout = listLayout

	self._connections = self._connections or {}
	local sizeConnection = listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self.Instance.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
	end)
	table.insert(self._connections, sizeConnection)

	self:OnThemeChanged(function(theme)
		self.Instance.ScrollBarImageColor3 = theme.Accent
	end)

	return self
end

function ScrollFrame:GetContentFrame()
	return self.Instance
end

function ScrollFrame:AddComponent(component)
	return self:AddChild(component)
end

return ScrollFrame
end

Modules["Components/Layout/Section"] = function(...)
local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local BaseComponent = Import('Components/Base/BaseComponent')
local Label = Import('Components/Basic/Label')

local Section = setmetatable({}, {__index = BaseComponent})
Section.__index = Section

local OUTER_RADIUS = 8
local OUTER_PADDING = 12
local CONTENT_GAP = 8

function Section.new(props)
    props = props or {}

    local inst = Create('Frame', {
        Name = 'NeroSection',
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        Parent = props.Parent
    })

    Draw.ApplyCorner(inst, OUTER_RADIUS)
    Draw.ApplyPadding(inst, OUTER_PADDING)
    Draw.ApplyListLayout(inst, CONTENT_GAP, 'Vertical')

    local self = BaseComponent.new(inst)
    setmetatable(self, Section)

    self:OnThemeChanged(function(theme)
		self.Instance.BackgroundColor3 = theme.Surface
	end)

    self._stroke = Draw.Stroke(nil, 1)
    self._stroke.Parent = inst

    self:OnThemeChanged(function(theme)
        self._stroke.Color = theme.Border
    end)

    if props.Title then
        self._title = Label.new({
            Text = props.Title,
            Bold = true,
            Size = UDim2.new(1,0,0,18),
            Parent = inst
        })
        self:AddChild(self._title)
    end
    
    self._content = Create('Frame', {
        Name = 'Content',
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        Parent = inst
    })
    Draw.ApplyListLayout(self._content, CONTENT_GAP, 'Vertical')

    return self
end

function Section:GetContentFrame()
    return self._content
end

function Section:AddComponent(component)
    return self:AddChild(component)
end

return Section
end

Modules["Components/Layout/Tab"] = function(...)
local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local BaseComponent = Import('Components/Base/BaseComponent')

local Tab = setmetatable({}, {__index = BaseComponent })
Tab.__index = Tab

local SECTION_GAP = 10

function Tab.new(props)
	props = props or {}
    
    local inst = Create('Frame', {
        Name = 'NeroTab',
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = props.Visible ~= false,
        Parent = props.Parent,
    })

    Draw.ApplyListLayout(inst, SECTION_GAP, 'Vertical')
    
    local self = BaseComponent.new(inst)
    setmetatable(self, Tab)

    self.Visible = inst.Visible

    return self
end

function Tab:GetContentFrame()
    return self.Instance
end

function Tab:AddComponent(component)
    return self:AddChild(component)
end

function Tab:Show()
    self.Visible = true
    self.Instance.Visible = true
end

function Tab:Hide()
    self.Visible = false
    self.Instance.Visible = false
end

return Tab
end

Modules["Components/Search/SearchBar"] = function(...)
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
end

Modules["Components/Selection/ColorPicker"] = function(...)
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

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
	self:BindCallback(self.OnValueChanged, props.Callback)

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
		self._svDragging = true

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

		self._svMoveConn = UserInputService.InputChanged:Connect(function(moveInput)
			if not self._svDragging then return end
			if moveInput.UserInputType ~= Enum.UserInputType.MouseMovement
				and moveInput.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			updateFromInput(moveInput.Position)
		end)
		
		self._svEndConn = UserInputService.InputEnded:Connect(function(endInput)
			if not isPointerInput(endInput.UserInputType) then return end
			if not self._svDragging then return end
			self._svDragging = false
			self._svMoveConn:Disconnect()
			self._svEndConn:Disconnect()
		end)
	end)
	self._svInput = svInput

	local hueInput = InputHandler.new(hueSlider)
	hueInput.PressStart:Connect(function(input)
		self._hueDragging = true

		local function updateFromInput(pos)
			local abs = hueSlider.AbsolutePosition
			local size = hueSlider.AbsoluteSize
			local relX = size.X > 0 and math.clamp((pos.X - abs.X) / size.X, 0, 1) or 0

			self._hue = relX
			self:_updateCursorPositions()
			self.OnValueChanged:Fire(self:_currentColor())
		end

		updateFromInput(input.Position)

		self._hueMoveConn = UserInputService.InputChanged:Connect(function(moveInput)
			if not self._hueDragging then return end
			if moveInput.UserInputType ~= Enum.UserInputType.MouseMovement
				and moveInput.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			updateFromInput(moveInput.Position)
		end)
		self._hueEndConn = UserInputService.InputEnded:Connect(function(endInput)
			if not isPointerInput(endInput.UserInputType) then return end
			if not self._hueDragging then return end
			self._hueDragging = false
			self._hueMoveConn:Disconnect()
			self._hueEndConn:Disconnect()
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
			local mouse = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
			if not self:_isPointInside(self._swatch, mouse) and not self:_isPointInside(self._popup, mouse) then
				self:Close()
			end
		end)
	end)
end

function ColorPicker:Close()
    if not self._open then return end

    self._open = false

    if self._popup then self._popup.Visible = false end

    if self._outsideClickConnection then
        self._outsideClickConnection:Disconnect()
        self._outsideClickConnection = nil
    end

	self._svDragging = false
    self._hueDragging = false
    if self._svMoveConn then self._svMoveConn:Disconnect() self._svMoveConn = nil end
    if self._svEndConn then self._svEndConn:Disconnect() self._svEndConn = nil end
    if self._hueMoveConn then self._hueMoveConn:Disconnect() self._hueMoveConn = nil end
    if self._hueEndConn then self._hueEndConn:Disconnect() self._hueEndConn = nil end
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
end

Modules["Components/Selection/Dropdown"] = function(...)
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
	self:BindCallback(self.OnValueChanged, props.Callback)
	
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

	self._input = InputHandler.new(selectButton)
	self._input.PressEnd:Connect(function(wasClick)
		if wasClick then
			self:Toggle()
		end
	end)

	self:OnThemeChanged(function(theme)
		chevron.ImageColor3 = theme.Text
		selectButton.BackgroundColor3 = theme.Surface
		selectButton.TextColor3 = theme.Text
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
end

Modules["Core/Create"] = function(...)
local Create = {}

local DEFERRED_PROPS = {
	Parent = true,
}

function Create.new(className, props, children)
    assert(type(className) == 'string', 'Create butuh className berupa string')
    props = props or {}
    children = children or {}
    local instance = Instance.new(className)

    local deferred = {}
    
    for key, value in props do
        if DEFERRED_PROPS[key] then
            deferred[key] = value
        else
            local success, err = pcall(function()
                instance[key] = value
            end)
            
            if not success then
                warn(("Create(\"%s\"): gagal set property '%s' -> %s"):format(className, key, err))
            end
        end
    end
    
    for _, child in children do
        child.Parent = instance
    end

    for key, value in deferred do
        instance[key] = value
    end

    return instance
end

setmetatable(Create, {
	__call = function(_, ...)
		return Create.new(...)
	end,
})

return Create
end

Modules["Core/Draw"] = function(...)
local Import = ...
local Create = Import('Core/Create')

local Draw = {}

function Draw.Corner(rad)
    rad = rad or 6
    return Create("UICorner", {
        CornerRadius = UDim.new(0, rad)
    })
end

function Draw.ApplyCorner(inst, rad)
    Draw.Corner(rad).Parent = inst
    return inst
end

function Draw.Stroke(clr, thickness, transparency)
    return Create('UIStroke', {
        Color = clr or Color3.fromRGB(255, 255, 255),
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    })
end

function Draw.ApplyStroke(inst, clr, thickness, transparency)
	Draw.Stroke(clr, thickness, transparency).Parent = inst
	return inst
end

function Draw.Padding(value)
    if type(value) == 'number' then
        local px = UDim.new(0, value)
        return Create('UIPadding', {
            PaddingTop = px,
            PaddingBottom = px,
            PaddingLeft = px,
            PaddingRight = px
        })
    end
    value = value or {}
    return Create('UIPadding', {
        PaddingTop = UDim.new(0, value.top or 0),
        PaddingBottom = UDim.new(0, value.bottom or 0),
        PaddingLeft = UDim.new(0, value.left or 0),
        PaddingRight = UDim.new(0, value.right or 0)
    })
end

function Draw.ApplyPadding(inst, value)
    Draw.Padding(value).Parent = inst
    return inst
end

function Draw.Gradient(clrs, rotation)
    assert(type(clrs) == 'table' and #clrs >= 2, '"Draw.Gradient butuh minimal 2 warna"')

    local keypoints = {}
    for index, clr in clrs do
        local time = (index - 1) / (#clrs - 1)
        table.insert(keypoints, ColorSequenceKeypoint.new(time,clr))
    end

    return Create('UIGradient', {
        Color = ColorSequence.new(keypoints),
        Rotation = rotation or 90,
    })
end

function Draw.ApplyGradient(inst, clrs, rotation)
    Draw.Gradient(clrs, rotation).Parent = inst
    return inst
end

function Draw.ListLayout(gap, direction)
    local isHorizontal = direction == 'Horizontal'

    return Create('UIListLayout', {
        Padding = UDim.new(0, gap or 8),
        FillDirection = isHorizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
        VerticalAlignment = isHorizontal and Enum.VerticalAlignment.Center or Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
end

function Draw.ApplyListLayout(inst, gap, direction)
    Draw.ListLayout(gap, direction).Parent = inst
    return inst
end

return Draw
end

Modules["Core/InputHandler"] = function(...)
local UserInputService = game:GetService("UserInputService")

local Import = ...
local Signal = Import('Core/Signal')

local InputHandler = {}
InputHandler.__index = InputHandler

local function isPointerInput(inputType)
    return inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch
end

function InputHandler.new(guiObject)
    assert(typeof(guiObject) == 'Instance' and guiObject:IsA("GuiObject"), 'InputHandler.new butuh GuiObject')

    local self = setmetatable({}, InputHandler)
    self.Instance = guiObject
    self.Hovering = false
    self.Pressed = false

    self.HoverStart = Signal.new()
    self.HoverEnd = Signal.new()
    self.PressStart = Signal.new()
    self.PressEnd = Signal.new()
    self.DragStart = Signal.new()
    self.DragMove = Signal.new()
    self.DragEnd = Signal.new()

    self._connection = {}
    self._dragging = false
    self._dragStartPos = nil

    self:_setupHover()
    self:_setupPress()

    return self
end

function InputHandler:_track(connection)
    table.insert(self._connection, connection)
end

function InputHandler:_setupHover()
    self:_track(self.Instance.MouseEnter:Connect(function()
        self.Hovering = true
        self.HoverStart:Fire()
    end))

    self:_track(self.Instance.MouseLeave:Connect(function()
        self.Hovering = false
        self.HoverEnd:Fire()
    end))
end

function InputHandler:_setupPress()
    self:_track(self.Instance.InputBegan:Connect(function(input)
        if not isPointerInput(input.UserInputType) then return end
        self.Pressed = true
        self.PressStart:Fire(input)
    end))

    self:_track(self.Instance.InputEnded:Connect(function(input)
        if not isPointerInput(input.UserInputType) then return end
        if not self.Pressed then return end

        self.Pressed = false
        self.PressEnd:Fire(self.Hovering)
    end))
end

function InputHandler:EnableDrag(dragTarget)
    dragTarget = dragTarget or self.Instance

    self:_track(self.Instance.InputBegan:Connect(function(input)
        if not isPointerInput(input.UserInputType) then return end

        self._dragging = true
        self._dragStartPos = input.Position
        self._dragStartOffset = dragTarget.Position
        self.DragStart:Fire()

        local moveConn
        local endConn

        moveConn = UserInputService.InputChanged:Connect(function(moveInput)
            if not self._dragging then return end
            if moveInput.UserInputType ~= Enum.UserInputType.MouseMovement and moveInput.UserInputType ~= Enum.UserInputType.Touch then return end

            local delta = moveInput.Position - self._dragStartPos
            dragTarget.Position = UDim2.new(
                self._dragStartOffset.X.Scale,
                self._dragStartOffset.X.Offset + delta.X,
                self._dragStartOffset.Y.Scale,
                self._dragStartOffset.Y.Offset + delta.Y
            )
            self.DragMove:Fire(Vector2.new(delta.X, delta.Y))
        end)

        endConn = UserInputService.InputEnded:Connect(function(endInput)
            if not isPointerInput(endInput.UserInputType) then return end
            if not self._dragging then return end

            self._dragging = false
            moveConn:Disconnect()
            endConn:Disconnect()
            self.DragEnd:Fire()
        end)
    end))
end

function InputHandler:Destroy()
    for _, connection in self._connection do
        connection:Disconnect()
    end

    table.clear(self._connection)
    
    self.HoverStart:Destroy()
	self.HoverEnd:Destroy()
	self.PressStart:Destroy()
	self.PressEnd:Destroy()
	self.DragStart:Destroy()
	self.DragMove:Destroy()
	self.DragEnd:Destroy()
end

return InputHandler
end

Modules["Core/ScreenManager"] = function(...)
local Players = game:GetService('Players')
local CoreGui = game:GetService('CoreGui')

local ScreenManager = {}

local _root = nil
local _order = 0

local function generateRandomName()
    local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local result = {}

    for i = 1, 12 do
        local index = math.random(1, #chars)
        result[i] = chars:sub(index, index)
    end
    return table.concat(result)
end

local function resolveParent()
    local getHiddenUI = (getgenv and getgenv().gethui) or gethui
    if getHiddenUI then
        local ok, hiddenUI = pcall(getHiddenUI)
        if ok and hiddenUI then
            return hiddenUI
        end
    end

    local ok, coreGuiOk = pcall(function()
        return CoreGui
    end)

    if ok and coreGuiOk then
        local success = pcall(function()
            local test = Instance.new('ScreenGui')
            test.Parent = CoreGui
            test:Destroy()
        end)

        if success then
            return CoreGui
        end
    end

    local plr = Players.LocalPlayer
    if plr then
        return plr:WaitForChild('PlayerGui')
    end

    error('ScreenManager: ga nemu parent yang valid buat ScreenGui (CoreGui/PlayerGui/gethui gagal semua)')
end

local function tryProtectGui(gui)
	local protect = (syn and syn.protect_gui)
		or protect_gui
		or protectgui
		or (getgenv and getgenv().protect_gui)

	if protect then
		pcall(protect, gui)
	end
end

function ScreenManager.GetRoot()
    if _root then return _root end

    local gui = Instance.new('ScreenGui')
    gui.Name = generateRandomName()
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    gui.Parent = resolveParent()

    tryProtectGui(gui)

    _root = gui
    return _root
end

function ScreenManager.Register(frame)
    assert(typeof(frame) == 'Instance' and frame:IsA("GuiObject"), "ScreenManager.Register butuh GuiObject")

    frame.Parent = ScreenManager.GetRoot()
    ScreenManager.BringToFront(frame)
    return frame
end

function ScreenManager.BringToFront(frame)
    assert(typeof(frame) == 'Instance' and frame:IsA("GuiObject"), "ScreenManager.BringToFront butuh GuiObject")

    _order += 1

    local function applyRelative(inst)
        if inst:GetAttribute("_neroBaseZ") == nil then
            inst:SetAttribute("_neroBaseZ", inst.ZIndex)
        end
        inst.ZIndex = _order + inst:GetAttribute("_neroBaseZ")
    end

    applyRelative(frame)
    for _, descendant in frame:GetDescendants() do
        if descendant:IsA("GuiObject") then
            applyRelative(descendant)
        end
    end
end

function ScreenManager.Unregister(frame)
    if frame and frame.Parent == _root then
        frame.Parent = nil
    end
end

return ScreenManager
end

Modules["Core/Signal"] = function(...)
local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Signal.new()
    local self = setmetatable({}, Signal)
    self._handlers ={}
    self._firing = false
    return self
end

function Signal:Connect(fn)
    assert(type(fn) == "function", "Signal:Connect butuh function, dapetnya " .. type(fn))

    local handler = { fn = fn, once = false}
    table.insert(self._handlers, handler)
    
    local connection = setmetatable({}, Connection)
    connection._signal = self
    connection._handler = handler
    connection.Connected = true

    return connection
end

function Signal:Once(fn)
    assert(type(fn) == "function", "Signal:Connect butuh function, dapetnya " .. type(fn))

    local handler = { fn = fn, once = true}
    table.insert(self._handlers, handler)

    local connection = setmetatable({}, Connection)
    connection._signal = self
    connection._handler = handler
    connection.Connected = true

    return connection
end

function Signal:Fire(...)
    local handlers = table.clone(self._handlers)

    for _, handler in handlers do
        task.spawn(handler.fn, ...)
        
        if handler.once then
            self:_removeHandler(handler)
        end
    end
end

function Signal:Wait()
    local thread = coroutine.running()
    local connection

    connection = self:Once(function (...)
        task.spawn(thread, ...)
    end)

    return coroutine.yield()
end

function Signal:DisconnectAll()
    table.clear(self._handlers)
end

function Signal:Destroy(args)
    self:DisconnectAll()
end

function Signal:_removeHandler(handler)
    local index = table.find(self._handlers, handler)
    if index then
        table.remove(self._handlers, index)
    end
end

function Connection:Disconnect()
    if not self.Connected then
        return 
    end

    self.Connected = false
    self._signal:_removeHandler(self._handler)
end

return Signal

end

Modules["Core/Tween"] = function(...)
local TweenService = game:GetService('TweenService')

local Import = ...
local Signal = Import('Core/Signal')

local Tween = {}
Tween.__index = Tween

local DEFAULT_DURATION = 0.2
local DEFAULT_STYLE = Enum.EasingStyle.Quad
local DEFAULT_DIRECTION = Enum.EasingDirection.Out

function Tween.new(instance, props, duration, style, direction)
    assert(typeof(instance) == "Instance", "Tween.new butuh Instance, dapetnya " .. typeof(instance))
    assert(typeof(props) == 'table', "Tween.new butuh props berupa table")

    local self =setmetatable({}, Tween)

    self.Instance = instance
    self.Completed = Signal.new()
    self.Playing = false

    local tweenInfo = TweenInfo.new(
        duration or DEFAULT_DURATION,
        style or DEFAULT_STYLE,
        direction or DEFAULT_DIRECTION
    )

    self._tween = TweenService:Create(instance, tweenInfo, props)
    
    self._completedConn = self._tween.Completed:Connect(function(playbackState)
        self.Playing = false
        self.Completed:Fire(playbackState)
    end)

    return self
end

function Tween:Play()
    self.Playing = true
    self._tween:Play()
    return self
end

function Tween:Pause()
    self.Playing = false
    self._tween:Pause()
    return self
end

function Tween:Cancel()
    self.Playing = false
    self._tween:Cancel()
    return self
end

function Tween:Destroy()
    if self._completedConn then
        self._completedConn:Disconnect()
        self._completedConn = nil
    end

    if self._tween then
        self._tween:Cancel()
        self._tween = nil
    end

    self.Completed:Destroy()
end

function Tween.Quick(instance, props, duration, style, direction)
    local self = Tween.new(instance, props, duration, style, direction)
    self:Play()
    return self
end

return Tween
end

Modules["Extras/ConfigManager"] = function(...)
local HttpService = game:GetService("HttpService")

local Import = ...

local ConfigManager = {}

local ROOT_FOLDER = "NeroUI"
local CONFIG_FOLDER = "NeroUI/Configs"

local _registry = {}

local function hasFileSupport()
	return writefile ~= nil and readfile ~= nil and isfile ~= nil and makefolder ~= nil and isfolder ~= nil
end

local function ensureFolders()
	if not isfolder(ROOT_FOLDER) then
		makefolder(ROOT_FOLDER)
	end
	if not isfolder(CONFIG_FOLDER) then
		makefolder(CONFIG_FOLDER)
	end
end

local function serializeValue(value)
	if typeof(value) == "Color3" then
		return { __type = "Color3", R = value.R, G = value.G, B = value.B }
	end
	if typeof(value) == "EnumItem" then
		return { __type = "EnumItem", EnumType = tostring(value.EnumType), Name = value.Name }
	end
	return value
end

local function deserializeValue(value)
	if type(value) == "table" and value.__type == "Color3" then
		return Color3.new(value.R, value.G, value.B)
	end
	if type(value) == "table" and value.__type == "EnumItem" then
		local enumTable = Enum[value.EnumType]
		return enumTable and enumTable[value.Name]
	end
	return value
end

function ConfigManager.Register(flagName, component)
	assert(type(flagName) == "string" and flagName ~= "", "ConfigManager.Register butuh flagName berupa string")
	assert(component ~= nil and component.GetValue and component.SetValue,
		"ConfigManager.Register butuh komponen yang punya method :GetValue() dan :SetValue()")

	_registry[flagName] = component
end

function ConfigManager.Unregister(flagName)
	_registry[flagName] = nil
end

function ConfigManager.Save(name)
	if not hasFileSupport() then
		return false, "Executor ga support writefile/readfile, ga bisa save config"
	end

	ensureFolders()

	local data = {}
	for flagName, component in _registry do
		local ok, value = pcall(function()
			return component:GetValue()
		end)
		if ok then
			data[flagName] = serializeValue(value)
		end
	end

	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, data)
	if not ok then
		return false, "Gagal encode config jadi JSON: " .. tostring(encoded)
	end

	local path = CONFIG_FOLDER .. "/" .. name .. ".json"
	local writeOk, writeErr = pcall(writefile, path, encoded)
	if not writeOk then
		return false, "Gagal nulis file: " .. tostring(writeErr)
	end

	return true
end

function ConfigManager.Load(name)
	if not hasFileSupport() then
		return false, "Executor ga support writefile/readfile, ga bisa load config"
	end

	local path = CONFIG_FOLDER .. "/" .. name .. ".json"
	if not isfile(path) then
		return false, "Config \"" .. name .. "\" ga ketemu"
	end

	local readOk, content = pcall(readfile, path)
	if not readOk then
		return false, "Gagal baca file: " .. tostring(content)
	end

	local decodeOk, data = pcall(HttpService.JSONDecode, HttpService, content)
	if not decodeOk then
		return false, "Gagal decode JSON, file config kemungkinan corrupt"
	end

	for flagName, rawValue in data do
		local component = _registry[flagName]
		if component then
			pcall(function()
				component:SetValue(deserializeValue(rawValue), false)
			end)
		end
	end

	return true
end

function ConfigManager.ListConfigs()
	if not hasFileSupport() or not (listfiles and isfolder(CONFIG_FOLDER)) then
		return {}
	end

	local names = {}
	for _, path in listfiles(CONFIG_FOLDER) do
		local fileName = path:match("([^/\\]+)%.json$")
		if fileName then
			table.insert(names, fileName)
		end
	end
	return names
end

function ConfigManager.DeleteConfig(name)
	if not hasFileSupport() then
		return false
	end
	local path = CONFIG_FOLDER .. "/" .. name .. ".json"
	if isfile(path) then
		delfile(path)
		return true
	end
	return false
end

return ConfigManager
end

Modules["Extras/KeybindManager"] = function(...)
local UserInputService = game:GetService("UserInputService")

local Import = ...

local KeybindManager = {}

local _actions = {}
local _enabled = true

local _inputBeganConnection = nil
local _inputEndedConnection = nil

local function ensureListening()
	if _inputBeganConnection then
		return
	end

	_inputBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not _enabled then
			return
		end
		if input.KeyCode == Enum.KeyCode.Unknown then
			return
		end

		for _, action in _actions do
			if action.KeyCode == input.KeyCode then
				if action.Mode == "Hold" then
					if not action._isDown then
						action._isDown = true
						local ok, err = pcall(action.Callback, true)
						if not ok then
							warn("KeybindManager: callback error -> " .. tostring(err))
						end
					end
				else
					local ok, err = pcall(action.Callback)
					if not ok then
						warn("KeybindManager: callback error -> " .. tostring(err))
					end
				end
			end
		end
	end)

	_inputEndedConnection = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.Unknown then
			return
		end

		for _, action in _actions do
			if action.Mode == "Hold" and action.KeyCode == input.KeyCode and action._isDown then
				action._isDown = false
				local ok, err = pcall(action.Callback, false)
				if not ok then
					warn("KeybindManager: callback error -> " .. tostring(err))
				end
			end
		end
	end)
end

function KeybindManager.Register(actionName, props)
	assert(type(actionName) == "string" and actionName ~= "", "KeybindManager.Register butuh actionName berupa string")
	assert(type(props.Callback) == "function", "KeybindManager.Register butuh props.Callback berupa function")

	ensureListening()

	_actions[actionName] = {
		KeyCode = props.Default,
		Mode = props.Mode == "Hold" and "Hold" or "Press",
		Callback = props.Callback,
		_isDown = false,
	}
end

function KeybindManager.Bind(actionName, keybindComponent, props)
	props = props or {}

	KeybindManager.Register(actionName, {
		Default = keybindComponent:GetValue(),
		Mode = props.Mode,
		Callback = props.Callback,
	})

	keybindComponent.OnValueChanged:Connect(function(newKeyCode)
		KeybindManager.SetKey(actionName, newKeyCode)
	end)
end

function KeybindManager.SetKey(actionName, keyCode)
	local action = _actions[actionName]
	if action then
		action.KeyCode = keyCode
	end
end

function KeybindManager.Unregister(actionName)
	_actions[actionName] = nil
end

function KeybindManager.SetEnabled(enabled)
	_enabled = enabled
end

return KeybindManager
end

Modules["Extras/Watermark"] = function(...)
local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local Tween = Import('Core/Tween')
local InputHandler = Import('Core/InputHandler')
local WidgetDrag = Import('Extras/WidgetDrag')
local ScreenManager = Import('Core/ScreenManager')
local ThemeEngine = Import('Theme/ThemeEngine')
local Label = Import('Components/Basic/Label')

local Watermark = {}

local CONTAINER_TOP_MARGIN = 10
local CONTAINER_HEIGHT = 32
local CONTAINER_PADDING = 12
local ITEM_GAP = 10
local TAG_PADDING_X = 8
local TAG_RADIUS = 5
local STATUS_DOT_SIZE = 7
local STATUS_PULSE_DURATION = 1
local DEFAULT_STATUS_COLOR = Color3.fromRGB(87, 217, 132)

local _container = nil
local _stroke = nil
local _statusDot = nil
local _statusTween = nil
local _titleLabel = nil
local _descLabel = nil
local _separator = nil
local _tagRow = nil
local _tags = {}
local _input = nil
local _dragHandle = nil
local _onClick = nil
local _enabled = true
local _themeConnection = nil

local function refreshSeparator()
	if _separator then
		_separator.Visible = #_tags > 0
	end
end

local function pulseStatusDot(toTransparent)
	if not _statusDot then return end

	local targetTransparency = toTransparent and 0.65 or 0
	_statusTween = Tween.new(_statusDot, { BackgroundTransparency = targetTransparency }, STATUS_PULSE_DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	_statusTween.Completed:Connect(function()
		pulseStatusDot(not toTransparent)
	end)
	_statusTween:Play()
end

local function refreshStatusDot()
	if _statusDot then
		_statusDot.Visible = #_tags == 0
	end
end

local function ensureContainer()
	if _container then
		return
	end

	local container = Create("Frame", {
		Name = "NeroWatermark",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, CONTAINER_TOP_MARGIN),
		Size = UDim2.new(0, 0, 0, CONTAINER_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BorderSizePixel = 0,
		Visible = false,
		Parent = ScreenManager.GetRoot(),
	})
	Draw.ApplyCorner(container, CONTAINER_HEIGHT / 2)
	Draw.ApplyPadding(container, { top = 0, bottom = 0, left = CONTAINER_PADDING, right = CONTAINER_PADDING })
	Draw.ApplyListLayout(container, ITEM_GAP, "Horizontal")

	_stroke = Draw.Stroke(nil, 1)
	_stroke.Parent = container

	_themeConnection = ThemeEngine.Changed:Connect(function()
		container.BackgroundColor3 = ThemeEngine.Current.Surface
		if _input and not _input.Hovering then
			_stroke.Color = ThemeEngine.Current.Border
		end
	end)
	container.BackgroundColor3 = ThemeEngine.Current.Surface
	_stroke.Color = ThemeEngine.Current.Border

	_container = container
	ScreenManager.BringToFront(container)

	_input = InputHandler.new(container)

	_dragHandle = WidgetDrag.Enable(container, {
		SnapToEdge = false,
		OnClick = function()
			if _onClick then
				_onClick()
			end
		end,
	})

	_input.HoverStart:Connect(function()
		Tween.Quick(_stroke, { Color = ThemeEngine.Current.Accent }, 0.15)
	end)
	_input.HoverEnd:Connect(function()
		Tween.Quick(_stroke, { Color = ThemeEngine.Current.Border }, 0.15)
	end)

	_statusDot = Create("Frame", {
		Name = "StatusDot",
		Size = UDim2.new(0, STATUS_DOT_SIZE, 0, STATUS_DOT_SIZE),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = DEFAULT_STATUS_COLOR,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Parent = container,
	})
	Draw.ApplyCorner(_statusDot, STATUS_DOT_SIZE / 2)
	pulseStatusDot(true)

	_titleLabel = Label.new({
		Text = "NeroUI",
		Bold = true,
		Size = UDim2.new(0, 0, 1, 0),
		LayoutOrder = 2,
		Parent = container,
	})
	_titleLabel.Instance.AutomaticSize = Enum.AutomaticSize.X

	_descLabel = Label.new({
		Text = "",
		Variant = "Dim",
		TextSize = 12,
		Size = UDim2.new(0, 0, 1, 0),
		LayoutOrder = 3,
		Parent = container,
	})
	_descLabel.Instance.AutomaticSize = Enum.AutomaticSize.X
	_descLabel.Instance.Visible = false

	_separator = Create("Frame", {
		Name = "Separator",
		Size = UDim2.new(0, 1, 0, 16),
		BackgroundColor3 = ThemeEngine.Current.Border,
		BorderSizePixel = 0,
		Visible = false,
		LayoutOrder = 4,
		Parent = container,
	})

	_tagRow = Create("Frame", {
		Name = "TagRow",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		LayoutOrder = 5,
		Parent = container,
	})
	Draw.ApplyListLayout(_tagRow, 4, "Horizontal")
end

local function createTagInstance(text, color)
	local tag = Create("Frame", {
		Name = "Tag",
		Size = UDim2.new(0, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = color or ThemeEngine.Current.Accent,
		BorderSizePixel = 0,
		Parent = _tagRow,
	})
	Draw.ApplyCorner(tag, TAG_RADIUS)
	Draw.ApplyPadding(tag, { top = 0, bottom = 0, left = TAG_PADDING_X, right = TAG_PADDING_X })

	Create("TextLabel", {
		Name = "Text",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = text,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Parent = tag,
	})

	return tag
end

function Watermark.Configure(props)
	props = props or {}
	ensureContainer()

	_enabled = props.Enabled ~= false

	if props.Title then
		Watermark.SetTitle(props.Title)
	end
	if props.Desc then
		Watermark.SetDesc(props.Desc)
	end
	if props.Tags then
		Watermark.ClearTags()
		for _, tagProps in props.Tags do
			Watermark.AddTag(tagProps.Text, tagProps.Color)
		end
	end
end

function Watermark:SetMinimized(isMinimized)
	local shouldShow = isMinimized and _enabled

	if not _container then
		if not shouldShow then
			return
		end
		ensureContainer()
	end

	_container.Visible = shouldShow
end

function Watermark.SetTitle(text)
	ensureContainer()
	_titleLabel:SetText(text)
end

function Watermark.SetDesc(text)
	ensureContainer()
	_descLabel:SetText(text)
	_descLabel.Instance.Visible = text ~= nil and text ~= ""
end

function Watermark.SetStatusColor(color)
	ensureContainer()
	if _statusDot then
		_statusDot.BackgroundColor3 = color
	end
end

function Watermark.AddTag(text, color)
	ensureContainer()
	local instance = createTagInstance(text, color)
	table.insert(_tags, { Text = text, Color = color, Instance = instance })
	refreshSeparator()
	refreshStatusDot()
end

function Watermark.ClearTags()
	for _, tag in _tags do
		tag.Instance:Destroy()
	end
	table.clear(_tags)
	refreshSeparator()
	refreshStatusDot()
end

function Watermark:Hide()
	if _container then
		_container.Visible = false
	end
end

function Watermark.Toggle()
	if _container then
		_container.Visible = not _container.Visible
	end
end

function Watermark.SetOnClick(callback)
	_onClick = callback
end

function Watermark.IsEnabled()
	return _enabled
end

function Watermark.Destroy()
	if _statusTween then
		_statusTween:Destroy()
		_statusTween = nil
	end
	if _dragHandle then
		_dragHandle:Destroy()
		_dragHandle = nil
	end
	if _input then
		_input:Destroy()
		_input = nil
	end
	if _themeConnection then
		_themeConnection:Disconnect()
		_themeConnection = nil
	end
	Watermark.ClearTags()
	if _container then
		_container:Destroy()
		_container = nil
	end
	_onClick = nil
	_enabled = true
	_statusDot = nil
	_titleLabel = nil
	_descLabel = nil
	_separator = nil
	_tagRow = nil
end

return Watermark
end

Modules["Extras/WidgetDrag"] = function(...)
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Import = ...
local Tween = Import("Core/Tween")

local WidgetDrag = {}
WidgetDrag.__index = WidgetDrag

local CLICK_THRESHOLD = 5
local SNAP_MARGIN = 12
local SNAP_TWEEN_DURATION = 0.2

local function isPointerInput(inputType)
	return inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch
end

local function getViewportSize()
	local camera = Workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1920, 1080)
end

function WidgetDrag.Enable(instance, props)
	assert(typeof(instance) == "Instance" and instance:IsA("GuiObject"),
		"WidgetDrag.Enable butuh GuiObject")
	props = props or {}

	local self = setmetatable({}, WidgetDrag)
	self._instance = instance
	self._snapToEdge = props.SnapToEdge ~= false
	self._onClick = props.OnClick
	self._snapTween = nil

	self._inputBeganConnection = instance.InputBegan:Connect(function(input)
		if not isPointerInput(input.UserInputType) then
			return
		end

		local dragStartMouse = input.Position
		local dragStartInstance = instance.Position
		local totalMovement = 0
		local dragging = true

		local moveConnection, endConnection

		moveConnection = UserInputService.InputChanged:Connect(function(moveInput)
			if not dragging then
				return
			end
			if moveInput.UserInputType ~= Enum.UserInputType.MouseMovement
				and moveInput.UserInputType ~= Enum.UserInputType.Touch then
				return
			end

			local delta = moveInput.Position - dragStartMouse
			totalMovement = math.max(totalMovement, delta.Magnitude)

			instance.Position = UDim2.new(
				dragStartInstance.X.Scale,
				dragStartInstance.X.Offset + delta.X,
				dragStartInstance.Y.Scale,
				dragStartInstance.Y.Offset + delta.Y
			)
		end)

		endConnection = UserInputService.InputEnded:Connect(function(endInput)
			if not isPointerInput(endInput.UserInputType) then
				return
			end
			if not dragging then
				return
			end

			dragging = false
			moveConnection:Disconnect()
			endConnection:Disconnect()

			if totalMovement < CLICK_THRESHOLD then
				if self._onClick then
					self._onClick()
				end
			elseif self._snapToEdge then
				self:_snap()
			end
		end)
	end)

	return self
end

function WidgetDrag:_snap()
	local viewport = getViewportSize()
	local instance = self._instance
	local currentX = instance.AbsolutePosition.X
	local width = instance.AbsoluteSize.X

	local centerX = currentX + (width / 2)
	local targetX

	if centerX < viewport.X / 2 then
		targetX = SNAP_MARGIN
	else
		targetX = viewport.X - width - SNAP_MARGIN
	end

	if self._snapTween then
		self._snapTween:Cancel()
	end
	self._snapTween = Tween.Quick(instance, {
		Position = UDim2.new(0, targetX, 0, instance.Position.Y.Offset),
	}, SNAP_TWEEN_DURATION)
end

function WidgetDrag:Destroy()
	if self._inputBeganConnection then
		self._inputBeganConnection:Disconnect()
		self._inputBeganConnection = nil
	end
	if self._snapTween then
		self._snapTween:Destroy()
		self._snapTween = nil
	end
end

return WidgetDrag
end

Modules["Theme/AccentGenerator"] = function(...)
local AccentGenerator = {}

local function clamp01(value)
    return math.clamp(value, 0, 1)
end

function AccentGenerator.Generate(baseColor)
    assert(typeof(baseColor) == 'Color3', 'AccentGenerator.Generate butuh Color3')

    local h, s, v = baseColor:ToHSV()

    local hover = Color3.fromHSV(h, s, clamp01(v+0.09))
    local pressed = Color3.fromHSV(h, s, clamp01(v-0.13))
    local disabled = Color3.fromHSV(h, clamp01(s*0.35), clamp01(v*0.55))

    return {
        Base = baseColor,
        Hover = hover,
        Pressed = pressed,
        Disabled = disabled
    }
end

return AccentGenerator
end

Modules["Theme/ThemeEngine"] = function(...)
local Import = ...
local Signal = Import('Core/Signal')
local Tokens = Import('Theme/Tokens')
local AccentGenerator = Import('Theme/AccentGenerator')

local ThemeEngine = {}

ThemeEngine.Changed = Signal.new()

local _mode = 'Dark'
local _accentVariants = AccentGenerator.Generate(Tokens.DefaultAccent)

ThemeEngine.Current = {}

local function _rebuild()
    local base = Tokens[_mode]

    ThemeEngine.Current.Background = base.Background
    ThemeEngine.Current.Surface = base.Surface
    ThemeEngine.Current.Border = base.Border
    ThemeEngine.Current.Text = base.Text
    ThemeEngine.Current.TextDim = base.TextDim

    ThemeEngine.Current.Accent = _accentVariants.Base
    ThemeEngine.Current.AccentHover = _accentVariants.Hover
    ThemeEngine.Current.AccentPressed = _accentVariants.Pressed
    ThemeEngine.Current.AccentDisabled = _accentVariants.Disabled
end

function ThemeEngine.SetMode(mode)
    assert(mode == 'Dark' or mode == 'Light', 'ThemeEngine.SetMode cuma nerima "Dark" atau "Light"')

    if _mode == mode then return end
    _mode = mode
    _rebuild()
    ThemeEngine.Changed:Fire()
end

function ThemeEngine.GetMode()
    return _mode
end

function ThemeEngine.SetAccent(baseColor)
    assert(typeof(baseColor) == 'Color3', "ThemeEngine.SetAccent butuh Color3")

    _accentVariants = AccentGenerator.Generate(baseColor)
    _rebuild()
    ThemeEngine.Changed:Fire()
end

function ThemeEngine.Get(tokenName)
    return ThemeEngine.Current[tokenName]
end

_rebuild()

return ThemeEngine
end

Modules["Theme/Tokens"] = function(...)
local Tokens = {}

Tokens.Dark = {
    Background = Color3.fromHex("#0F1115"),
    Surface = Color3.fromHex("#191C22"),
    Border = Color3.fromHex('#262B33'),
    Text = Color3.fromHex('#E8EAED'),
    TextDim = Color3.fromHex('#8B92A0')
}

Tokens.Light = {
    Background = Color3.fromHex('#F5F5F7'),
    Surface = Color3.fromHex('#FFFFFF'),
    Border = Color3.fromHex('#E2E2E6'),
    Text = Color3.fromHex('#26272B'),
    TextDim = Color3.fromHex('#6B6C75')
}

Tokens.DefaultAccent = Color3.fromHex('#6C5CE7')

return Tokens
end


local Cache = {}

local function Import(path)
	if Cache[path] then
		return Cache[path]
	end

	local loader = Modules[path]
	assert(loader, ("NeroUI: module '%s' ga ketemu di bundle"):format(path))

	local result = loader(Import)
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
local SIDEBAR_WIDTH = 140
local TITLEBAR_HEIGHT = 36

local _reopenKeybindCounter = 0

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