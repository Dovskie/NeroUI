local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local Tween = Import('Core/Tween')
local InputHandler = Import('Core/InputHandler')
local WidgetDrag = Import('Extras/WidgetDrag')
local ScreenManager = Import('Core/ScreenManager')
local ThemeEngine = Import('Theme/ThemeEngine')
local Label = Import('Components/Basic/Label')

local Watermark = {}

local CONTAINER_TOP_MARGIN = 10
local CONTAINER_HEIGHT = 32
local CONTAINER_PADDING = 12
local ITEM_GAP = 10
local TAG_PADDING_X = 8
local TAG_RADIUS = 5
local STATUS_DOT_SIZE = 7
local STATUS_PULSE_DURATION = 1
local DEFAULT_STATUS_COLOR = Color3.fromRGB(87, 217, 132)

local _container = nil
local _stroke = nil
local _statusDot = nil
local _statusTween = nil
local _titleLabel = nil
local _descLabel = nil
local _separator = nil
local _tagRow = nil
local _tags = {}
local _input = nil
local _dragHandle = nil
local _onClick = nil
local _enabled = true
local _themeConnection = nil

local function refreshSeparator()
	if _separator then
		_separator.Visible = #_tags > 0
	end
end

local function pulseStatusDot(toTransparent)
	if not _statusDot then return end

	local targetTransparency = toTransparent and 0.65 or 0
	_statusTween = Tween.new(_statusDot, { BackgroundTransparency = targetTransparency }, STATUS_PULSE_DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	_statusTween.Completed:Connect(function()
		pulseStatusDot(not toTransparent)
	end)
	_statusTween:Play()
end

local function refreshStatusDot()
	if _statusDot then
		_statusDot.Visible = #_tags == 0
	end
end

local function ensureContainer()
	if _container then
		return
	end

	local container = Create("Frame", {
		Name = "NeroWatermark",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, CONTAINER_TOP_MARGIN),
		Size = UDim2.new(0, 0, 0, CONTAINER_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.X,
		BorderSizePixel = 0,
		Visible = false,
		Parent = ScreenManager.GetRoot(),
	})
	Draw.ApplyCorner(container, CONTAINER_HEIGHT / 2)
	Draw.ApplyPadding(container, { top = 0, bottom = 0, left = CONTAINER_PADDING, right = CONTAINER_PADDING })
	Draw.ApplyListLayout(container, ITEM_GAP, "Horizontal")

	_stroke = Draw.Stroke(nil, 1)
	_stroke.Parent = container

	_themeConnection = ThemeEngine.Changed:Connect(function()
		container.BackgroundColor3 = ThemeEngine.Current.Surface
		if _input and not _input.Hovering then
			_stroke.Color = ThemeEngine.Current.Border
		end
	end)
	container.BackgroundColor3 = ThemeEngine.Current.Surface
	_stroke.Color = ThemeEngine.Current.Border

	_container = container
	ScreenManager.BringToFront(container)

	_input = InputHandler.new(container)

	_dragHandle = WidgetDrag.Enable(container, {
		SnapToEdge = false,
		OnClick = function()
			if _onClick then
				_onClick()
			end
		end,
	})

	_input.HoverStart:Connect(function()
		Tween.Quick(_stroke, { Color = ThemeEngine.Current.Accent }, 0.15)
	end)
	_input.HoverEnd:Connect(function()
		Tween.Quick(_stroke, { Color = ThemeEngine.Current.Border }, 0.15)
	end)

	_statusDot = Create("Frame", {
		Name = "StatusDot",
		Size = UDim2.new(0, STATUS_DOT_SIZE, 0, STATUS_DOT_SIZE),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		BackgroundColor3 = DEFAULT_STATUS_COLOR,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Parent = container,
	})
	Draw.ApplyCorner(_statusDot, STATUS_DOT_SIZE / 2)
	pulseStatusDot(true)

	_titleLabel = Label.new({
		Text = "NeroUI",
		Bold = true,
		Size = UDim2.new(0, 0, 1, 0),
		LayoutOrder = 2,
		Parent = container,
	})
	_titleLabel.Instance.AutomaticSize = Enum.AutomaticSize.X

	_descLabel = Label.new({
		Text = "",
		Variant = "Dim",
		TextSize = 12,
		Size = UDim2.new(0, 0, 1, 0),
		LayoutOrder = 3,
		Parent = container,
	})
	_descLabel.Instance.AutomaticSize = Enum.AutomaticSize.X
	_descLabel.Instance.Visible = false

	_separator = Create("Frame", {
		Name = "Separator",
		Size = UDim2.new(0, 1, 0, 16),
		BackgroundColor3 = ThemeEngine.Current.Border,
		BorderSizePixel = 0,
		Visible = false,
		LayoutOrder = 4,
		Parent = container,
	})

	_tagRow = Create("Frame", {
		Name = "TagRow",
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		LayoutOrder = 5,
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

function Watermark.Configure(props)
	props = props or {}
	ensureContainer()

	_enabled = props.Enabled ~= false

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
end

function Watermark:SetMinimized(isMinimized)
	local shouldShow = isMinimized and _enabled

	if not _container then
		if not shouldShow then
			return
		end
		ensureContainer()
	end

	_container.Visible = shouldShow
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

function Watermark.SetStatusColor(color)
	ensureContainer()
	if _statusDot then
		_statusDot.BackgroundColor3 = color
	end
end

function Watermark.AddTag(text, color)
	ensureContainer()
	local instance = createTagInstance(text, color)
	table.insert(_tags, { Text = text, Color = color, Instance = instance })
	refreshSeparator()
	refreshStatusDot()
end

function Watermark.ClearTags()
	for _, tag in _tags do
		tag.Instance:Destroy()
	end
	table.clear(_tags)
	refreshSeparator()
	refreshStatusDot()
end

function Watermark:Hide()
	if _container then
		_container.Visible = false
	end
end

function Watermark.Toggle()
	if _container then
		_container.Visible = not _container.Visible
	end
end

function Watermark.SetOnClick(callback)
	_onClick = callback
end

function Watermark.Destroy()
	if _statusTween then
		_statusTween:Destroy()
		_statusTween = nil
	end
	if _dragHandle then
		_dragHandle:Destroy()
		_dragHandle = nil
	end
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
	_onClick = nil
	_enabled = true
	_statusDot = nil
	_titleLabel = nil
	_descLabel = nil
	_separator = nil
	_tagRow = nil
end

return Watermark