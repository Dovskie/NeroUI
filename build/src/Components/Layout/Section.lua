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