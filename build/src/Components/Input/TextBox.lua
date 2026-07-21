local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local Signal = Import('Core/Signal')
local BaseComponent = Import('Components/Base/BaseComponent')
local Label = Import('Components/Basic/Label')

local TextBox = setmetatable({}, {__index = BaseComponent})
TextBox.__index = TextBox

local CONTAINER_HEIGHT = 36
local BOX_SIZE = UDim2.new(0, 140, 0, 28)
local BOX_RADIUS = 6

function TextBox.new(props)
    props = props or {}

    local inst = Create('Frame', {
        Name = 'NeroTextBox',
        Size = UDim2.new(1, 0, 0, CONTAINER_HEIGHT),
        BackgroundTransparency = 1,
        Parent = props.Parent
    })

    local self = BaseComponent.new(inst)
    setmetatable(self, TextBox)

    self.OnValueChanged = Signal.new()
    self.OnSubmit = Signal.new()
    self:BindCallback(self.OnValueChanged, props.Callback)
    self:BindCallback(self.OnSubmit, props.OnSubmit)

    self._numeric = props.Numeric == true
    self._value = props.Default ~= nil and tostring(props.Default) or ''

    self._label = Label.new({
        Text = props.Text or 'Input',
        Size = UDim2.new(1, -150, 1, 0),
        Parent = inst
    })
    self:AddChild(self._label)

    local box = Create('Frame', {
        Name = 'Box',
        Size = props.BoxSize or BOX_SIZE,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, 0, 0.5, 0),
        BorderSizePixel = 0,
        Parent = inst,
    })
    Draw.ApplyCorner(box, BOX_RADIUS)
    self._box = box

    local textBox = Create('TextBox', {
        Name = 'Input',
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        PlaceholderText = props.Placeholder or '...',
        Text = self._value,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        ClearTextOnFocus = false,
        Parent = box,
    })
    self._textBox = textBox

    textBox.FocusLost:Connect(function(enterPressed)
        local text = textBox.Text

        if self._numeric then
            local number = tonumber(text)
            if not number then
                textBox.Text = self._value
                return
            end
            if props.Min then number = math.max(number, props.Min) end
            if props.Max then number = math.min(number, props.Max) end
            text = tostring(number)
            textBox.Text = text
        end

        if text == self._value then return end

        self._value = text
        self.OnValueChanged:Fire(self._value)

        if enterPressed then
            self.OnSubmit:Fire(self._value)
        end
    end)

    self:OnThemeChanged(function(theme)
        box.BackgroundColor3 = theme.Surface
        textBox.TextColor3 = theme.Text
        textBox.PlaceholderColor3 = theme.TextDim
    end)

    return self
end

function TextBox:GetValue()
    return self._numeric and tonumber(self._value) or self._value
end

function TextBox:SetValue(value, fireEvent)
    self._value = tostring(value)
    self._textBox.Text = self._value
    if fireEvent ~= false then
        self.OnValueChanged:Fire(self:GetValue())
    end
end

function TextBox:Destroy()
    self.OnValueChanged:Destroy()
    self.OnSubmit:Destroy()
    BaseComponent.Destroy(self)
end

return TextBox