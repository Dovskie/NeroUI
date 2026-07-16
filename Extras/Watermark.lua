local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local InputHandler = Import('Core/InputHandler')
local ScreenManager = Import('Core/ScreenManager')
local ThemeEngine = Import('Theme/ThemeEngine')
local Label = Import('Components/Basic/Label')

local Watermark = {}

local CONTAINER_MARGIN = 16
local CONTAINER_HEIGHT = 30
local CONTAINER_PADDING = 10
local ITEM_GAP = 8
local TAG_PADDING_X = 8
local TAG_RADIUS = 4

local _container = nil
local _titleLabel = nil
local _descLabel = nil
local _tagRow = nil
local _tags = {}
local _input = nil
local _themeConnection = nil

local function ensureContainer()
	if _container then
		return
	end

	local container = Create("Frame", {
		Name = "NeroWatermark",
		Position = UDim2.new(0, CONTAINER_MARGIN, 0, CONTAINER_MARGIN),
		Size = UDim2.new(0, 0, 0, CONTAINER_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
        BorderSizePixel = 0,
		Parent = ScreenManager.GetRoot(),
	})
	Draw.ApplyCorner(container, CONTAINER_HEIGHT / 2)
	Draw.ApplyPadding(container, { top = 0, bottom = 0, left = CONTAINER_PADDING, right = CONTAINER_PADDING })
	Draw.ApplyListLayout(container, ITEM_GAP, "Horizontal")

	_themeConnection = ThemeEngine.Changed:Connect(function()
		container.BackgroundColor3 = ThemeEngine.Current.Surface
	end)
	container.BackgroundColor3 = ThemeEngine.Current.Surface

	_container = container
	ScreenManager.BringToFront(container)

    _input = InputHandler.new(container)
	_input:EnableDrag()

	_titleLabel = Label.new({
		Text = "NeroUI",
		Bold = true,
		Size = UDim2.new(0, 0, 1, 0),
		Parent = container,
	})
    _titleLabel.Instance.AutomaticSize = Enum.AutomaticSize.X

    _descLabel = Label.new({
		Text = "",
		Variant = "Dim",
		TextSize = 12,
		Size = UDim2.new(0, 0, 1, 0),
		Parent = container,
	})
    _descLabel.Instance.AutomaticSize = Enum.AutomaticSize.X
	_descLabel.Instance.Visible = false

    _tagRow = Create("Frame", {
		Name = "TagRow",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Parent = container,
	})
	Draw.ApplyListLayout(_tagRow, 4, "Horizontal")
end

local function createTagInstance(text, color)
	local tag = Create("Frame", {
		Name = "Tag",
		Size = UDim2.new(0, 0, 0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = color or ThemeEngine.Current.Accent,
		BorderSizePixel = 0,
		Parent = _tagRow,
	})
	Draw.ApplyCorner(tag, TAG_RADIUS)
	Draw.ApplyPadding(tag, { top = 0, bottom = 0, left = TAG_PADDING_X, right = TAG_PADDING_X })

	Create("TextLabel", {
		Name = "Text",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = text,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		Parent = tag,
	})

	return tag
end

function Watermark.Show(props)
	props = props or {}
	ensureContainer()

	if props.Title then
		Watermark.SetTitle(props.Title)
	end
	if props.Desc then
		Watermark.SetDesc(props.Desc)
	end
	if props.Tags then
		Watermark.ClearTags()
		for _, tagProps in props.Tags do
			Watermark.AddTag(tagProps.Text, tagProps.Color)
		end
	end

	_container.Visible = true
end

function Watermark.SetTitle(text)
	ensureContainer()
	_titleLabel:SetText(text)
end

function Watermark.SetDesc(text)
	ensureContainer()
	_descLabel:SetText(text)
	_descLabel.Instance.Visible = text ~= nil and text ~= ""
end

function Watermark.AddTag(text, color)
	ensureContainer()
	local instance = createTagInstance(text, color)
	table.insert(_tags, { Text = text, Color = color, Instance = instance })
end

function Watermark.ClearTags()
	for _, tag in _tags do
		tag.Instance:Destroy()
	end
	table.clear(_tags)
end

function Watermark.Hide()
	if _container then
		_container.Visible = false
	end
end

function Watermark.Toggle()
	if _container then
		_container.Visible = not _container.Visible
	end
end

function Watermark.Destroy()
	if _input then
		_input:Destroy()
		_input = nil
	end
	if _themeConnection then
		_themeConnection:Disconnect()
		_themeConnection = nil
	end
	Watermark.ClearTags()
	if _container then
		_container:Destroy()
		_container = nil
	end
	_titleLabel = nil
	_descLabel = nil
	_tagRow = nil
end

return Watermark