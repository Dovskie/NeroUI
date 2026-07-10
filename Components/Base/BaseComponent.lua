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