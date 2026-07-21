local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local Signal = Import('Core/Signal')
local InputHandler = Import('Core/InputHandler')
local BaseComponent = Import('Components/Base/BaseComponent')
local ScrollFrame = Import('Components/Layout/ScrollFrame')
local Icons = Import('Assets/Icons')

local DataTable = setmetatable({}, {__index = BaseComponent})
DataTable.__index = DataTable

local HEADER_HEIGHT = 28
local DEFAULT_ROW_HEIGHT = 30
local CELL_PADDING = 8
local DEFAULT_VISIBLE_ROWS = 6

function DataTable.new(props)
    props = props or {}
    assert(type(props.Columns) == 'table' and #props.Columns > 0, 'DataTable.new butuh minimal 1 kolom di props.Columns')

    local inst = Create('Frame', {
        Name = 'NeroDataTable',
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = props.Parent,
    })
    Draw.ApplyListLayout(inst, 0, 'Vertical')

    local self = BaseComponent.new(inst)
    setmetatable(self, DataTable)

    self.OnRowClick = Signal.new()
    self:BindCallback(self.OnRowClick, props.OnRowClick)

    self._columns = props.Columns
    self._data = props.Data or {}
    self._sortable = props.Sortable == true
    self._sortKey = nil
    self._sortAscending = true
    self._rowHeight = props.RowHeight or DEFAULT_ROW_HEIGHT
    self._maxVisibleRows = props.MaxVisibleRows or DEFAULT_VISIBLE_ROWS
    self._rowFrames = {}
    self._headerCells = {}

    local totalDefined = 0
    local undefinedCount = 0
    for _, col in self._columns do
        if col.Width then totalDefined += col.Width else undefinedCount += 1 end
    end
    local remaining = math.max(1 - totalDefined, 0)
    local fallbackWidth = undefinedCount > 0 and (remaining / undefinedCount) or 0
    for _, col in self._columns do
        col._resolvedWidth = col.Width or fallbackWidth
    end

    self:_buildHeader()

    local bodyHeight = math.max(math.min(#self._data, self._maxVisibleRows), 1) * self._rowHeight
    local scroll = ScrollFrame.new({
        Size = UDim2.new(1, 0, 0, bodyHeight),
        Parent = inst,
    })
    scroll.Instance.LayoutOrder = 2
    self:AddChild(scroll)
    self._scroll = scroll
    self._rowContainer = scroll:GetContentFrame()

    self:_render()

    return self
end

function DataTable:_buildHeader()
    local header = Create('Frame', {
        Name = 'Header',
        Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
        BorderSizePixel = 0,
        LayoutOrder = 1,
        Parent = self.Instance,
    })
    self._header = header
    self:OnThemeChanged(function(theme)
        header.BackgroundColor3 = theme.Surface
    end)

    local xOffset = 0
    for _, col in self._columns do
        local cell = Create('TextButton', {
            Name = 'HeaderCell_' .. col.Key,
            Size = UDim2.new(col._resolvedWidth, 0, 1, 0),
            Position = UDim2.new(xOffset, 0, 0, 0),
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = '',
            Parent = header,
        })
        xOffset += col._resolvedWidth

        local label = Create('TextLabel', {
            Name = 'Label',
            Size = UDim2.new(1, -CELL_PADDING * 2, 1, 0),
            Position = UDim2.new(0, CELL_PADDING, 0, 0),
            BackgroundTransparency = 1,
            Text = col.Title or col.Key,
            TextXAlignment = col.Align or Enum.TextXAlignment.Left,
            TextSize = 12,
            Font = Enum.Font.GothamBold,
            Parent = cell,
        })
        self:OnThemeChanged(function(theme)
            label.TextColor3 = theme.TextDim
        end)

        local entry = { Label = label }

        if self._sortable then
            local sortIcon = Icons.CreateImage('chevron-down', {
                Name = 'SortIcon',
                Size = UDim2.new(0, 10, 0, 10),
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -CELL_PADDING, 0.5, 0),
                Visible = false,
                Parent = cell,
            })
            self:OnThemeChanged(function(theme)
                sortIcon.ImageColor3 = theme.TextDim
            end)

            cell.MouseButton1Click:Connect(function()
                self:Sort(col.Key)
            end)

            entry.Icon = sortIcon
        end

        self._headerCells[col.Key] = entry
    end
end

function DataTable:_clearRows()
    for _, row in self._rowFrames do
        if row.Input then row.Input:Destroy() end
        row.Instance:Destroy()
    end
    table.clear(self._rowFrames)
end

function DataTable:_render()
    self:_clearRows()

    for index, rowData in self._data do
        local rowFrame = Create('Frame', {
            Name = 'Row_' .. index,
            Size = UDim2.new(1, 0, 0, self._rowHeight),
            BackgroundTransparency = index % 2 == 0 and 1 or 0.97,
            BorderSizePixel = 0,
            LayoutOrder = index,
            Parent = self._rowContainer,
        })
        self:OnThemeChanged(function(theme)
            rowFrame.BackgroundColor3 = theme.Border
        end)

        local xOffset = 0
        for _, col in self._columns do
            local value = rowData[col.Key]
            local label = Create('TextLabel', {
                Name = 'Cell_' .. col.Key,
                Size = UDim2.new(col._resolvedWidth, -CELL_PADDING * 2, 1, 0),
                Position = UDim2.new(xOffset, CELL_PADDING, 0, 0),
                BackgroundTransparency = 1,
                Text = value ~= nil and tostring(value) or '',
                TextXAlignment = col.Align or Enum.TextXAlignment.Left,
                TextSize = 13,
                Font = Enum.Font.GothamMedium,
                Parent = rowFrame,
            })
            xOffset += col._resolvedWidth

            self:OnThemeChanged(function(theme)
                label.TextColor3 = theme.Text
            end)
        end

        local input = InputHandler.new(rowFrame)
        input.PressEnd:Connect(function(wasClick)
            if wasClick then
                self.OnRowClick:Fire(rowData, index)
            end
        end)

        table.insert(self._rowFrames, { Instance = rowFrame, Input = input })
    end
end

function DataTable:Sort(key, ascending)
    if ascending == nil then
        ascending = (self._sortKey == key) and not self._sortAscending or true
    end

    self._sortKey = key
    self._sortAscending = ascending

    table.sort(self._data, function(a, b)
        local av, bv = a[key], b[key]
        if av == bv then return false end
        if ascending then return av < bv end
        return av > bv
    end)

    for colKey, headerCell in self._headerCells do
        if headerCell.Icon then
            headerCell.Icon.Visible = colKey == key
            headerCell.Icon.Rotation = ascending and 180 or 0
        end
    end

    self:_render()
end

function DataTable:SetData(rows)
    self._data = rows or {}
    if self._sortKey then
        self:Sort(self._sortKey, self._sortAscending)
    else
        self:_render()
    end
end

function DataTable:AddRow(row)
    table.insert(self._data, row)
    self:SetData(self._data)
end

function DataTable:RemoveRow(predicateOrIndex)
    if type(predicateOrIndex) == 'number' then
        table.remove(self._data, predicateOrIndex)
    elseif type(predicateOrIndex) == 'function' then
        for i = #self._data, 1, -1 do
            if predicateOrIndex(self._data[i]) then
                table.remove(self._data, i)
            end
        end
    end
    self:SetData(self._data)
end

function DataTable:Clear()
    self._data = {}
    self:_render()
end

function DataTable:Destroy()
    self:_clearRows()
    self.OnRowClick:Destroy()
    BaseComponent.Destroy(self)
end

return DataTable