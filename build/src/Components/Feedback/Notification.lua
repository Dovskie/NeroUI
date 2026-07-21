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