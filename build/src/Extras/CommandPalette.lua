local UserInputService = game:GetService('UserInputService')

local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local Tween = Import('Core/Tween')
local InputHandler = Import('Core/InputHandler')
local ScreenManager = Import('Core/ScreenManager')
local ThemeEngine = Import('Theme/ThemeEngine')
local Icons = Import('Assets/Icons')

local CommandPalette = {}
CommandPalette.__index = CommandPalette

local CARD_WIDTH = 420
local CARD_PADDING = 10
local RESULTS_HEIGHT = 280
local ROW_HEIGHT = 38
local MAX_RESULTS = 30
local ANIM_DURATION = 0.15

-- Fuzzy match sederhana: exact/prefix/substring dapet skor tinggi & murah buat
-- dihitung, fallback ke subsequence match (semua karakter query muncul
-- berurutan di text, ga harus nempel) buat query kayak "aim ena" -> "Aim Enabled".
-- Return nil kalo ga match sama sekali.
local function fuzzyScore(text, query)
	if query == '' then return 0 end

	local lowerText = text:lower()
	local lowerQuery = query:lower()

	if lowerText == lowerQuery then return 1000 end

	if lowerText:sub(1, #lowerQuery) == lowerQuery then return 800 end

	local plainIndex = lowerText:find(lowerQuery, 1, true)
	if plainIndex then return 600 - plainIndex end

	local searchFrom = 1
	local firstMatch, lastMatch
	for i = 1, #lowerQuery do
		local char = lowerQuery:sub(i, i)
		local found = lowerText:find(char, searchFrom, true)
		if not found then return nil end
		firstMatch = firstMatch or found
		lastMatch = found
		searchFrom = found + 1
	end

	return 200 - (lastMatch - firstMatch)
end

function CommandPalette.new(window)
	local self = setmetatable({}, CommandPalette)

	self._window = window
	self._entries = {}
	self._rows = {}
	self._visible = false
	self._selectedIndex = 0
	self._overlay = nil

	self._inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed and not self._visible then return end

		local ctrlDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

		if ctrlDown and input.KeyCode == Enum.KeyCode.K then
			self:Toggle()
		elseif self._visible and input.KeyCode == Enum.KeyCode.Escape then
			self:Hide()
		elseif self._visible and input.KeyCode == Enum.KeyCode.Down then
			self:_move(1)
		elseif self._visible and input.KeyCode == Enum.KeyCode.Up then
			self:_move(-1)
		elseif self._visible and input.KeyCode == Enum.KeyCode.Return then
			self:_activateSelected()
		end
	end)

	return self
end

-- entry = { Label = string, TabTitle = string, Component, Tab, ScrollFrame }
function CommandPalette:RegisterEntry(entry)
	assert(type(entry.Label) == 'string' and entry.Label ~= '', 'CommandPalette:RegisterEntry butuh Label')
	table.insert(self._entries, entry)
end

function CommandPalette:Toggle()
	if self._visible then
		self:Hide()
	else
		self:Show()
	end
end

function CommandPalette:Show()
	if self._visible then return end
	if self._window._root and not self._window._root.Visible then return end

	self._visible = true
	self:_build()
end

function CommandPalette:Hide()
	if not self._visible then return end
	self._visible = false

	if self._searchTextConn then
		self._searchTextConn:Disconnect()
		self._searchTextConn = nil
	end
	if self._cardThemeConn then
		self._cardThemeConn:Disconnect()
		self._cardThemeConn = nil
	end
	if self._searchThemeConn then
		self._searchThemeConn:Disconnect()
		self._searchThemeConn = nil
	end
	if self._outsideInput then
		self._outsideInput:Destroy()
		self._outsideInput = nil
	end

	table.clear(self._rows)

	if self._overlay then
		self._overlay:Destroy()
		self._overlay = nil
	end
end

function CommandPalette:_build()
	local overlay = Create('Frame', {
		Name = 'NeroCommandPaletteOverlay',
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.35,
		Active = true,
		Parent = ScreenManager.GetRoot(),
	})
	ScreenManager.BringToFront(overlay)
	self._overlay = overlay

	self._outsideInput = InputHandler.new(overlay)
	self._outsideInput.PressEnd:Connect(function(wasClick)
		if wasClick then self:Hide() end
	end)

	local card = Create('Frame', {
		Name = 'Card',
		Size = UDim2.new(0, CARD_WIDTH, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 90),
		BorderSizePixel = 0,
		Active = true,
		Parent = overlay,
	})
	Draw.ApplyCorner(card, 10)
	Draw.ApplyPadding(card, CARD_PADDING)
	Draw.ApplyListLayout(card, 8, 'Vertical')

	self._cardThemeConn = ThemeEngine.Changed:Connect(function()
		card.BackgroundColor3 = ThemeEngine.Current.Surface
	end)
	card.BackgroundColor3 = ThemeEngine.Current.Surface

	local searchRow = Create('Frame', {
		Name = 'SearchRow',
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Parent = card,
	})

	local searchIcon = Icons.CreateImage('search', {
		Name = 'SearchIcon',
		Size = UDim2.new(0, 14, 0, 14),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Parent = searchRow,
	})

	local searchBox = Create('TextBox', {
		Name = 'SearchInput',
		Size = UDim2.new(1, -28, 1, 0),
		Position = UDim2.new(0, 26, 0, 0),
		BackgroundTransparency = 1,
		PlaceholderText = 'Cari komponen... (Esc buat nutup)',
		Text = '',
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
		Parent = searchRow,
	})
	self._searchBox = searchBox

	local function refreshSearchColors()
		searchBox.TextColor3 = ThemeEngine.Current.Text
		searchBox.PlaceholderColor3 = ThemeEngine.Current.TextDim
		searchIcon.ImageColor3 = ThemeEngine.Current.TextDim
	end
	self._searchThemeConn = ThemeEngine.Changed:Connect(refreshSearchColors)
	refreshSearchColors()

	local resultsFrame = Create('ScrollingFrame', {
		Name = 'Results',
		Size = UDim2.new(1, 0, 0, RESULTS_HEIGHT),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageTransparency = 0.3,
		Parent = card,
	})
	Draw.ApplyListLayout(resultsFrame, 2, 'Vertical')
	self._resultsFrame = resultsFrame

	self._emptyLabel = Create('TextLabel', {
		Name = 'EmptyLabel',
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		Text = 'Ga ada komponen yang cocok.',
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		Visible = false,
		Parent = card,
	})

	self._searchTextConn = searchBox:GetPropertyChangedSignal('Text'):Connect(function()
		self:_refreshResults(searchBox.Text)
	end)

	self:_refreshResults('')

	Tween.Quick(overlay, { BackgroundTransparency = 0.35 }, ANIM_DURATION)
	searchBox:CaptureFocus()
end

function CommandPalette:_refreshResults(query)
	for _, row in self._rows do
		row.Input:Destroy()
		row.Instance:Destroy()
	end
	table.clear(self._rows)

	local scored = {}
	for _, entry in self._entries do
		if entry.Component.Instance then
			local score = fuzzyScore(entry.Label, query)
			if score then
				table.insert(scored, { Entry = entry, Score = score })
			end
		end
	end

	table.sort(scored, function(a, b) return a.Score > b.Score end)

	self._emptyLabel.Visible = #scored == 0
	self._emptyLabel.TextColor3 = ThemeEngine.Current.TextDim

	self._selectedIndex = #scored > 0 and 1 or 0

	for index, item in scored do
		if index > MAX_RESULTS then break end
		self:_createRow(item.Entry, index)
	end
end

function CommandPalette:_createRow(entry, index)
	local row = Create('TextButton', {
		Name = 'Row',
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Active = true,
		Text = '',
		BorderSizePixel = 0,
		LayoutOrder = index,
		Parent = self._resultsFrame,
	})
	Draw.ApplyCorner(row, 6)

	local tabLabel = Create('TextLabel', {
		Name = 'TabLabel',
		Size = UDim2.new(0, 90, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1,
		Text = entry.TabTitle,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 11,
		Font = Enum.Font.GothamMedium,
		Parent = row,
	})

	local nameLabel = Create('TextLabel', {
		Name = 'NameLabel',
		Size = UDim2.new(1, -110, 1, 0),
		Position = UDim2.new(0, 100, 0, 0),
		BackgroundTransparency = 1,
		Text = entry.Label,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		Parent = row,
	})

	local function refreshColors()
		local selected = index == self._selectedIndex
		row.BackgroundColor3 = ThemeEngine.Current.Accent
		row.BackgroundTransparency = selected and 0.85 or 1
		tabLabel.TextColor3 = ThemeEngine.Current.TextDim
		nameLabel.TextColor3 = ThemeEngine.Current.Text
	end
	refreshColors()

	local input = InputHandler.new(row)
	input.HoverStart:Connect(function()
		row.BackgroundTransparency = 0.9
	end)
	input.HoverEnd:Connect(refreshColors)
	input.PressEnd:Connect(function(wasClick)
		if wasClick then self:_jumpTo(entry) end
	end)

	table.insert(self._rows, {
		Instance = row,
		Input = input,
		Entry = entry,
		RefreshColors = refreshColors,
		Index = index,
	})
end

function CommandPalette:_move(delta)
	if #self._rows == 0 then return end

	self._selectedIndex = math.clamp(self._selectedIndex + delta, 1, #self._rows)

	for _, row in self._rows do
		row.RefreshColors()
	end

	local selectedRow = self._rows[self._selectedIndex]
	if selectedRow then
		local targetY = selectedRow.Instance.Position.Y.Offset
		if targetY < self._resultsFrame.CanvasPosition.Y then
			self._resultsFrame.CanvasPosition = Vector2.new(0, targetY)
		elseif targetY + ROW_HEIGHT > self._resultsFrame.CanvasPosition.Y + self._resultsFrame.AbsoluteSize.Y then
			self._resultsFrame.CanvasPosition = Vector2.new(0, targetY + ROW_HEIGHT - self._resultsFrame.AbsoluteSize.Y)
		end
	end
end

function CommandPalette:_activateSelected()
	local selectedRow = self._rows[self._selectedIndex]
	if selectedRow then
		self:_jumpTo(selectedRow.Entry)
	end
end

function CommandPalette:_jumpTo(entry)
	self:Hide()
	self._window:_setActiveTab(entry.Tab)

	task.defer(function()
		local scrollInst = entry.ScrollFrame.Instance
		local targetInst = entry.Component.Instance
		if not scrollInst or not targetInst then return end

		local offsetY = (targetInst.AbsolutePosition.Y - scrollInst.AbsolutePosition.Y) + scrollInst.CanvasPosition.Y
		scrollInst.CanvasPosition = Vector2.new(0, math.max(offsetY - 16, 0))

		local highlight = Draw.Stroke(ThemeEngine.Current.Accent, 2, 0)
		highlight.Parent = targetInst
		local tween = Tween.Quick(highlight, { Transparency = 1 }, 0.8)
		tween.Completed:Connect(function()
			highlight:Destroy()
		end)
	end)
end

function CommandPalette:Destroy()
	self:Hide()
	if self._inputConn then
		self._inputConn:Disconnect()
		self._inputConn = nil
	end
	table.clear(self._entries)
end

return CommandPalette