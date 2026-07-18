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