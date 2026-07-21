local UserInputService = game:GetService("UserInputService")

local Import = ...
local Create = Import("Core/Create")
local Draw = Import("Core/Draw")
local Signal = Import("Core/Signal")
local InputHandler = Import("Core/InputHandler")
local ThemeEngine = Import("Theme/ThemeEngine")
local Icons = Import("Assets/Icons")
local ScreenManager = Import("Core/ScreenManager")
local BaseComponent = Import("Components/Base/BaseComponent")
local Label = Import("Components/Basic/Label")

local Dropdown = setmetatable({}, { __index = BaseComponent })
Dropdown.__index = Dropdown

local CONTAINER_HEIGHT = 36
local SELECT_BUTTON_SIZE = UDim2.new(0, 140, 0, 28)
local OPTION_HEIGHT = 28
local SEARCH_HEIGHT = 30
local POPUP_RADIUS = 6
local POPUP_MAX_HEIGHT = 200
local CHECK_SIZE = 14
local ACTIVE_TRANSPARENCY = 0.85

function Dropdown.new(props)
	props = props or {}

	local options = props.Options or {}
	assert(#options > 0, "Dropdown.new butuh minimal 1 opsi di props.Options")

	local container = Create("Frame", {
		Name = "NeroDropdown",
		Size = UDim2.new(1, 0, 0, CONTAINER_HEIGHT),
		BackgroundTransparency = 1,
		Parent = props.Parent
	})

	local self = BaseComponent.new(container)
	setmetatable(self, Dropdown)

	self.OnValueChanged = Signal.new()
	self:BindCallback(self.OnValueChanged, props.Callback)

	self._options = options
	self._isMulti = props.IsMulti == true
	self._searchable = props.Searchable == true
	self._placeholder = props.Placeholder or "Pilih..."
	self._open = false
	self._popup = nil
	self._optionRows = {}
	self._searchBox = nil

	if self._isMulti then
		self._selected = {}
		self._value = {}

		if type(props.Default) == "table" then
			for _, v in props.Default do
				if table.find(options, v) and not self._selected[v] then
					self._selected[v] = true
					table.insert(self._value, v)
				end
			end
		end
	else
		self._value = (table.find(options, props.Default) and props.Default) or options[1]
	end

	self._label = Label.new({
		Text = props.Text or "Dropdown",
		Size = UDim2.new(1, -150, 1, 0),
		Parent = container,
	})
	self:AddChild(self._label)

	local selectButton = Create("TextButton", {
		Name = "SelectButton",
		Size = SELECT_BUTTON_SIZE,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		AutoButtonColor = false,
		Text = self:_getDisplayText(),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		BorderSizePixel = 0,
		Parent = container,
	})
	Draw.ApplyCorner(selectButton, POPUP_RADIUS)
	self._selectButton = selectButton

	local chevron = Icons.CreateImage("chevron-down", {
		Name = "Chevron",
		Size = UDim2.new(0, 14, 0, 14),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Parent = selectButton,
	})
	self._chevron = chevron

	self._input = InputHandler.new(selectButton)
	self._input.PressEnd:Connect(function(wasClick)
		if wasClick then self:Toggle() end
	end)

	self:OnThemeChanged(function(theme)
		chevron.ImageColor3 = theme.Text
		selectButton.BackgroundColor3 = theme.Surface
		selectButton.TextColor3 = theme.Text
	end)

	return self
end

function Dropdown:_getDisplayText()
	if not self._isMulti then return "  " .. tostring(self._value) end

	local count = #self._value
	if count == 0 then
		return "  " .. self._placeholder
	elseif count == 1 then
		return "  " .. self._value[1]
	else
		return "  " .. count .. " Selected"
	end
end

function Dropdown:_isOptionActive(optionText)
	if self._isMulti then
		return self._selected[optionText] == true
	end
	return self._value == optionText
end

function Dropdown:_refreshOptionVisual(optionText)
	local row = self._optionRows[optionText]
	if not row then return end

	local active = self:_isOptionActive(optionText)

	if row.Check then row.Check.BackgroundTransparency = active and 0 or 1 end
	if row.CheckMark then row.CheckMark.Visible = active end

	if not row.Hovering then
		row.Button.BackgroundColor3 = ThemeEngine.Current.Accent
		row.Button.BackgroundTransparency = active and ACTIVE_TRANSPARENCY or 1
	end
	row.Button.TextColor3 = active and ThemeEngine.Current.Accent or ThemeEngine.Current.Text
end

function Dropdown:_refreshAllOptionVisuals()
	for optionText in self._optionRows do
		self:_refreshOptionVisual(optionText)
	end
end

function Dropdown:_filterOptions(query)
	query = query:lower()

	for optionText, row in self._optionRows do
		local match = query == "" or optionText:lower():find(query, 1, true) ~= nil
		row.Button.Visible = match
	end
end

function Dropdown:_ensurePopup()
	if self._popup then return end

	local listHeight = math.min(#self._options * OPTION_HEIGHT, POPUP_MAX_HEIGHT)
	local popupHeight = listHeight + (self._searchable and SEARCH_HEIGHT or 0)

	local popup = Create("Frame", {
		Name = "NeroDropdownPopup",
		Size = UDim2.new(0, SELECT_BUTTON_SIZE.X.Offset, 0, popupHeight),
		BorderSizePixel = 0,
		Visible = false,
	})
	Draw.ApplyCorner(popup, POPUP_RADIUS)
	Draw.ApplyListLayout(popup, 0, "Vertical")

	self:OnThemeChanged(function(theme)
		popup.BackgroundColor3 = theme.Surface
	end)

	if self._searchable then
		local searchBox = Create("TextBox", {
			Name = "Search",
			Size = UDim2.new(1, 0, 0, SEARCH_HEIGHT),
			BackgroundTransparency = 1,
			PlaceholderText = "Cari...",
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 12,
			Font = Enum.Font.GothamMedium,
			ClearTextOnFocus = false,
			LayoutOrder = 0,
			Parent = popup,
		})
		Draw.ApplyPadding(searchBox, { top = 0, bottom = 0, left = 10, right = 10 })

		self:OnThemeChanged(function(theme)
			searchBox.TextColor3 = theme.Text
			searchBox.PlaceholderColor3 = theme.TextDim
		end)

		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			self:_filterOptions(searchBox.Text)
		end)

		self._searchBox = searchBox
	end

	for index, optionText in self._options do
		local optionButton = Create("TextButton", {
			Name = "Option_" .. optionText,
			Size = UDim2.new(1, 0, 0, OPTION_HEIGHT),
			AutoButtonColor = false,
			Text = "  " .. optionText,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 13,
			Font = Enum.Font.GothamMedium,
			BackgroundTransparency = 1,
			LayoutOrder = index,
			Parent = popup,
		})

		local checkFrame = nil
		local checkMark = nil

		if self._isMulti then
			checkFrame = Create("Frame", {
				Name = "Check",
				Size = UDim2.new(0, CHECK_SIZE, 0, CHECK_SIZE),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				BorderSizePixel = 1,
				BackgroundTransparency = self._selected[optionText] and 0 or 1,
				Parent = optionButton,
			})
			Draw.ApplyCorner(checkFrame, 4)

			checkMark = Icons.CreateImage("check", {
				Name = "CheckMark",
				Size = UDim2.new(0, 10, 0, 10),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				ImageColor3 = Color3.fromRGB(255, 255, 255),
				Visible = self._selected[optionText] == true,
				Parent = checkFrame,
			})

			self:OnThemeChanged(function(theme)
				checkFrame.BorderColor3 = theme.TextDim
				checkFrame.BackgroundColor3 = ThemeEngine.Current.Accent
			end)
		end

		self._optionRows[optionText] = { Button = optionButton, Check = checkFrame, CheckMark = checkMark, Hovering = false }

		local optionInput = InputHandler.new(optionButton)
		optionInput.HoverStart:Connect(function()
			local row = self._optionRows[optionText]
			row.Hovering = true
			optionButton.BackgroundColor3 = ThemeEngine.Current.AccentHover
			optionButton.BackgroundTransparency = 0
		end)
		optionInput.HoverEnd:Connect(function()
			local row = self._optionRows[optionText]
			row.Hovering = false
			self:_refreshOptionVisual(optionText)
		end)
		optionInput.PressEnd:Connect(function(wasClick)
			if not wasClick then
				return
			end

			if self._isMulti then
				self:ToggleValue(optionText)
			else
				self:SetValue(optionText)
				self:Close()
			end
		end)

		self:OnThemeChanged(function(theme)
			if not self._optionRows[optionText].Hovering then
				optionButton.TextColor3 = self:_isOptionActive(optionText) and theme.Accent or theme.Text
			end
		end)

		self:_refreshOptionVisual(optionText)
	end

	self._popup = popup
end

function Dropdown:_positionPopup()
	local buttonPos = self._selectButton.AbsolutePosition
	local buttonSize = self._selectButton.AbsoluteSize

	self._popup.Position = UDim2.new(0, buttonPos.X, 0, buttonPos.Y + buttonSize.Y + 4)
end

function Dropdown:Open()
	if self._open then return end

	self:_ensurePopup()
	self._popup.Parent = ScreenManager.GetRoot()
	ScreenManager.BringToFront(self._popup)
	self:_positionPopup()
	self._popup.Visible = true
	self._open = true
	self._chevron.Rotation = 180

	if self._searchBox then
		self._searchBox.Text = ""
		self:_filterOptions("")
	end

	self._outsideClickConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end

		task.defer(function()
			if not self._open then return end
			local mouse = UserInputService:GetMouseLocation()
			local overSelectButton = self:_isPointInside(self._selectButton, mouse)
			local overPopup = self:_isPointInside(self._popup, mouse)
			if not overSelectButton and not overPopup then self:Close() end
		end)
	end)
end

function Dropdown:Close()
	if not self._open then return end

	self._open = false
	self._chevron.Rotation = 0
	if self._popup then self._popup.Visible = false end

	if self._outsideClickConnection then
		self._outsideClickConnection:Disconnect()
		self._outsideClickConnection = nil
	end
end

function Dropdown:Toggle()
	if self._open then
		self:Close()
	else
		self:Open()
	end
end

function Dropdown:_isPointInside(guiObject, point)
	local pos = guiObject.AbsolutePosition
	local size = guiObject.AbsoluteSize
	return point.X >= pos.X and point.X <= pos.X + size.X
		and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

function Dropdown:ToggleValue(value)
	if not self._isMulti then return end
	if not table.find(self._options, value) then return end

	if self._selected[value] then
		self._selected[value] = nil
		local index = table.find(self._value, value)

		if index then table.remove(self._value, index) end
	else
		self._selected[value] = true
		table.insert(self._value, value)
	end

	self:_refreshOptionVisual(value)
	self._selectButton.Text = self:_getDisplayText()
	self.OnValueChanged:Fire(self:GetValue())
end

function Dropdown:SetValue(value)
	if self._isMulti then
		if type(value) ~= "table" then return end

		self._selected = {}
		self._value = {}
		for _, v in value do
			if table.find(self._options, v) and not self._selected[v] then
				self._selected[v] = true
				table.insert(self._value, v)
			end
		end

		self:_refreshAllOptionVisuals()
		self._selectButton.Text = self:_getDisplayText()
		self.OnValueChanged:Fire(self:GetValue())
		return
	end

	if not table.find(self._options, value) then return end
	if value == self._value then return end

	local previousValue = self._value
	self._value = value
	self._selectButton.Text = self:_getDisplayText()
	self:_refreshOptionVisual(previousValue)
	self:_refreshOptionVisual(value)
	self.OnValueChanged:Fire(self._value)
end

function Dropdown:SetOptions(newOptions)
	assert(type(newOptions) == "table" and #newOptions > 0, "Dropdown:SetOptions butuh array berisi minimal 1 opsi")

	if self._open then
		self:Close()
	end

	if self._popup then
		self._popup:Destroy()
		self._popup = nil
		table.clear(self._optionRows)
		self._searchBox = nil
	end

	self._options = newOptions

	if self._isMulti then
		local newSelected, newValue = {}, {}
		for _, v in self._value do
			if table.find(newOptions, v) then
				newSelected[v] = true
				table.insert(newValue, v)
			end
		end
		self._selected = newSelected
		self._value = newValue
	else
		if not table.find(newOptions, self._value) then
			self._value = newOptions[1]
		end
	end

	self._selectButton.Text = self:_getDisplayText()
end

function Dropdown:GetValue()
	if self._isMulti then
		local copy = {}
		for _, v in self._value do
			table.insert(copy, v)
		end
		return copy
	end

	return self._value
end

function Dropdown:Destroy()
	self:Close()

	if self._input then
		self._input:Destroy()
		self._input = nil
	end

	if self._popup then
		self._popup:Destroy()
		self._popup = nil
	end

	self.OnValueChanged:Destroy()

	BaseComponent.Destroy(self)
end

return Dropdown