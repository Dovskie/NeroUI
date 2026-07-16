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