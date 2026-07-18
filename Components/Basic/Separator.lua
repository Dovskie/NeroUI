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