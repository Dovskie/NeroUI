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