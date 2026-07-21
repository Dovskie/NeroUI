local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local BaseComponent = Import('Components/Base/BaseComponent')

local Paragraph = setmetatable({}, {__index = BaseComponent})
Paragraph.__index = Paragraph

function Paragraph.new(props)
    props = props or {}

    local inst = Create('Frame', {
        Name = 'NeroParagraph',
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = props.Parent
    })
    Draw.ApplyListLayout(inst, 4, 'Vertical')

    local self = BaseComponent.new(inst)
    setmetatable(self, Paragraph)

    if props.Title then
        self._title = Create('TextLabel', {
            Name = 'Title',
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Text = props.Title,
            TextSize = 14,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
            Parent = inst,
        })
        self:OnThemeChanged(function(theme)
            self._title.TextColor3 = theme.Text
        end)
    end

    self._content = Create('TextLabel', {
        Name = 'Content',
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Text = props.Text or '',
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        LayoutOrder = 2,
        Parent = inst,
    })
    self:OnThemeChanged(function(theme)
        self._content.TextColor3 = theme.TextDim
    end)

    return self
end

function Paragraph:SetText(text)
    self._content.Text = text
end

function Paragraph:SetTitle(text)
    if self._title then
        self._title.Text = text
    end
end

return Paragraph