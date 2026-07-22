local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local Signal = Import('Core/Signal')
local ThemeEngine = Import('Theme/ThemeEngine')
local Icons = Import('Assets/Icons')

local BaseComponent = {}
BaseComponent.__index = BaseComponent

local LOCK_ICON_SIZE = 14

function BaseComponent.new(inst)
    assert(typeof(inst) == 'Instance' and inst:IsA('GuiObject'), 'BaseComponent.new butuh GuiObject sebagai instance utama')

    local self = setmetatable({}, BaseComponent)

    self.Instance = inst
    self.Destroyed = false
    self.Locked = false

    self._themeConn = nil
    self._connections = {}
    self._children = {}
    self._lockOverlay = nil
    self._lockThemeConn = nil

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

function BaseComponent:SetLocked(locked)
    locked = locked == true
    if locked == self.Locked then return end
    self.Locked = locked

    if not self.Instance then return end

    if locked then
        self.Instance.Active = false

        local overlay = Create('Frame', {
            Name = 'LockOverlay',
            Size = UDim2.new(1, 0, 1, 0),
            BorderSizePixel = 0,
            BackgroundTransparency = 0.4,
            Active = true,
            ZIndex = 1000,
            Parent = self.Instance,
        })

        local icon = Icons.CreateImage('lock', {
            Name = 'LockIcon',
            Size = UDim2.new(0, LOCK_ICON_SIZE, 0, LOCK_ICON_SIZE),
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -8, 0.5, 0),
            ZIndex = 1001,
            Parent = overlay,
        })

        local function refreshColors()
            overlay.BackgroundColor3 = ThemeEngine.Current.Background
            icon.ImageColor3 = ThemeEngine.Current.TextDim
        end
        self._lockThemeConn = ThemeEngine.Changed:Connect(refreshColors)
        refreshColors()

        self._lockOverlay = overlay
    else
        self.Instance.Active = true

        if self._lockThemeConn then
            self._lockThemeConn:Disconnect()
            self._lockThemeConn = nil
        end
        if self._lockOverlay then
            self._lockOverlay:Destroy()
            self._lockOverlay = nil
        end
    end
end

function BaseComponent:IsLocked()
    return self.Locked
end

function BaseComponent:AddChild(childComponent)
    table.insert(self._children, childComponent)
    return childComponent
end

function BaseComponent:Destroy()
    if self.Destroyed then return end

    self.Destroyed = true

    if self._lockThemeConn then
        self._lockThemeConn:Disconnect()
        self._lockThemeConn = nil
    end

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