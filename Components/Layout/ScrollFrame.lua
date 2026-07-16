local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local BaseComponent = Import('Components/Base/BaseComponent')

local ScrollFrame = setmetatable({}, {__index = BaseComponent})
ScrollFrame.__index = ScrollFrame

local CONTENT_GAP = 10
local SCROLLBAR_THICKNESS = 4

function ScrollFrame.new(props)
    props = props or {}
    
    local inst = Create('ScrollingFrame', {
        Name ='NeroScrollingFrame',
        Size = props.Size or UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = SCROLLBAR_THICKNESS,
        ScrollBarImageTransparency = 0.3,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticCanvasSize.Y,
        Parent = props.Parent
    })

    local listLayout = Draw.ListLayout(CONTENT_GAP, 'Vertical')
    listLayout.Parent = inst

    local self = BaseComponent.new(inst)
    setmetatable(self, ScrollFrame)

    self._listLayout = listLayout

    local sizeConn = listLayout:GetPropertyChangedSignal('AbsoluteContentSize'):Connect(function()
        self.Instance.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
    end)
    table.insert(self._connections, sizeConn)

    self:OnThemeChanged(function(theme)
        self.Instance.ScrollBarImageColor3 = theme.Accent
    end)

    return self
end

function ScrollFrame:GetContentFrame()
    return self.Instance
end

function ScrollFrame:AddComponent(component)
    return self:AddChild(component)
end

return ScrollFrame