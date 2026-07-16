local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local BaseComponent = Import('Components/Base/BaseComponent')

local Tab = setmetatable({}, {__index = BaseComponent })
Tab.__index = Tab

local SECTION_GAP = 10

function Tab.new(props)
	props = props or {}
    
    local inst = Create('Frame', {
        Name = 'NeroTab',
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = props.Visible ~= false,
        Parent = props.Parent,
    })

    Draw.ApplyListLayout(inst, SECTION_GAP, 'Vertical')
    
    local self = BaseComponent.new(inst)
    setmetatable(self, Tab)

    self.Visible = inst.Visible

    return self
end

function Tab:GetContentFrame()
    return self.Instance
end

function Tab:AddComponent(component)
    return self:AddChild(component)
end

function Tab:Show()
    self.Visible = true
    self.Instance.Visible = true
end

function Tab:Hide()
    self.Visible = false
    self.Instance.Visible = false
end

return Tab