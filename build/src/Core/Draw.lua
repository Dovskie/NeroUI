local Import = ...
local Create = Import('Core/Create')

local Draw = {}

function Draw.Corner(rad)
    rad = rad or 6
    return Create("UICorner", {
        CornerRadius = UDim.new(0, rad)
    })
end

function Draw.ApplyCorner(inst, rad)
    Draw.Corner(rad).Parent = inst
    return inst
end

function Draw.Stroke(clr, thickness, transparency)
    return Create('UIStroke', {
        Color = clr or Color3.fromRGB(255, 255, 255),
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    })
end

function Draw.ApplyStroke(inst, clr, thickness, transparency)
	Draw.Stroke(clr, thickness, transparency).Parent = inst
	return inst
end

function Draw.Padding(value)
    if type(value) == 'number' then
        local px = UDim.new(0, value)
        return Create('UIPadding', {
            PaddingTop = px,
            PaddingBottom = px,
            PaddingLeft = px,
            PaddingRight = px
        })
    end
    value = value or {}
    return Create('UIPadding', {
        PaddingTop = UDim.new(0, value.top or 0),
        PaddingBottom = UDim.new(0, value.bottom or 0),
        PaddingLeft = UDim.new(0, value.left or 0),
        PaddingRight = UDim.new(0, value.right or 0)
    })
end

function Draw.ApplyPadding(inst, value)
    Draw.Padding(value).Parent = inst
    return inst
end

function Draw.Gradient(clrs, rotation)
    assert(type(clrs) == 'table' and #clrs >= 2, '"Draw.Gradient butuh minimal 2 warna"')

    local keypoints = {}
    for index, clr in clrs do
        local time = (index - 1) / (#clrs - 1)
        table.insert(keypoints, ColorSequenceKeypoint.new(time,clr))
    end

    return Create('UIGradient', {
        Color = ColorSequence.new(keypoints),
        Rotation = rotation or 90,
    })
end

function Draw.ApplyGradient(inst, clrs, rotation)
    Draw.Gradient(clrs, rotation).Parent = inst
    return inst
end

function Draw.ListLayout(gap, direction)
    local isHorizontal = direction == 'Horizontal'

    return Create('UIListLayout', {
        Padding = UDim.new(0, gap or 8),
        FillDirection = isHorizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
        VerticalAlignment = isHorizontal and Enum.VerticalAlignment.Center or Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
end

function Draw.ApplyListLayout(inst, gap, direction)
    Draw.ListLayout(gap, direction).Parent = inst
    return inst
end

function Draw.CornerMask(parent, radius, corner, color)
    assert(typeof(parent) == 'Instance', 'Draw.CornerMask butuh parent berupa Instance')
    assert(type(corner) == 'string', 'Draw.CornerMask butuh corner berupa string')

    local anchor, position
    if corner == "TopLeft" then
        anchor, position = Vector2.new(0, 0), UDim2.new(0, 0, 0, 0)
    elseif corner == "TopRight" then
        anchor, position = Vector2.new(1, 0), UDim2.new(1, 0, 0, 0)
    elseif corner == "BottomLeft" then
        anchor, position = Vector2.new(0, 1), UDim2.new(0, 0, 1, 0)
    elseif corner == "BottomRight" then
        anchor, position = Vector2.new(1, 1), UDim2.new(1, 0, 1, 0)
    else
        error('Draw.CornerMask: corner harus salah satu dari "TopLeft", "TopRight", "BottomLeft", "BottomRight"')
    end

    return Create("Frame", {
        Name = "CornerMask",
        Size = UDim2.new(0, radius, 0, radius),
        AnchorPoint = anchor,
        Position = position,
        BackgroundColor3 = color or Color3.fromRGB(0, 0, 0),
        BorderSizePixel = 0,
        ZIndex = 5,
        Parent = parent,
    })
end

return Draw