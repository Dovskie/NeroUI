local Import = ...
local Create = Import("Core/Create")
local Draw = Import("Core/Draw")
local BaseComponent = Import("Components/Base/BaseComponent")

local ScrollFrame = setmetatable({}, { __index = BaseComponent })
ScrollFrame.__index = ScrollFrame

local CONTENT_GAP = 10
local SCROLLBAR_THICKNESS = 4

function ScrollFrame.new(props)
	props = props or {}

	local instance = Create("ScrollingFrame", {
		Name = "NeroScrollFrame",
		Size = props.Size or UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = SCROLLBAR_THICKNESS,
		ScrollBarImageTransparency = 0.3,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = props.Parent,
	})

	local listLayout = Draw.ListLayout(CONTENT_GAP, "Vertical")
	listLayout.Parent = instance

	local self = BaseComponent.new(instance)
	setmetatable(self, ScrollFrame)

	self._listLayout = listLayout

	self._connections = self._connections or {}
	local sizeConnection = listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self.Instance.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
	end)
	table.insert(self._connections, sizeConnection)

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