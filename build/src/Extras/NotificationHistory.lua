local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local Tween = Import('Core/Tween')
local InputHandler = Import('Core/InputHandler')
local ScreenManager = Import('Core/ScreenManager')
local ThemeEngine = Import('Theme/ThemeEngine')
local Notification = Import('Components/Feedback/Notification')

local NotificationHistory = {}
NotificationHistory.__index = NotificationHistory

local PANEL_WIDTH = 300
local LIST_HEIGHT = 300
local ANIM_DURATION = 0.15

local function formatRelativeTime(timestamp)
	local delta = os.time() - timestamp
	if delta < 60 then return 'barusan' end
	if delta < 3600 then return math.floor(delta / 60) .. 'm lalu' end
	if delta < 86400 then return math.floor(delta / 3600) .. 'j lalu' end
	return math.floor(delta / 86400) .. 'h lalu'
end

function NotificationHistory.new(window, anchorButton)
	local self = setmetatable({}, NotificationHistory)

	self._window = window
	self._anchorButton = anchorButton
	self._visible = false
	self._rows = {}
	self._lastSeenCount = #Notification.GetHistory()

	return self
end

function NotificationHistory:HasUnread()
	return #Notification.GetHistory() > self._lastSeenCount
end

function NotificationHistory:Toggle()
	if self._visible then
		self:Hide()
	else
		self:Show()
	end
end

function NotificationHistory:Show()
	if self._visible then return end
	if self._window._root and not self._window._root.Visible then return end

	self._visible = true
	self._lastSeenCount = #Notification.GetHistory()
	self:_build()
end

function NotificationHistory:Hide()
	if not self._visible then return end
	self._visible = false

	if self._historyChangedConn then
		self._historyChangedConn:Disconnect()
		self._historyChangedConn = nil
	end
	if self._panelThemeConn then
		self._panelThemeConn:Disconnect()
		self._panelThemeConn = nil
	end
	if self._headerThemeConn then
		self._headerThemeConn:Disconnect()
		self._headerThemeConn = nil
	end
	if self._clearInput then
		self._clearInput:Destroy()
		self._clearInput = nil
	end
	if self._outsideInput then
		self._outsideInput:Destroy()
		self._outsideInput = nil
	end

	self:_clearRows()

	if self._overlay then
		self._overlay:Destroy()
		self._overlay = nil
	end
end

function NotificationHistory:_build()
	local overlay = Create('Frame', {
		Name = 'NeroNotificationHistoryOverlay',
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Active = true,
		Parent = ScreenManager.GetRoot(),
	})
	ScreenManager.BringToFront(overlay)
	self._overlay = overlay

	self._outsideInput = InputHandler.new(overlay)
	self._outsideInput.PressEnd:Connect(function(wasClick)
		if wasClick then self:Hide() end
	end)

	local anchorPos = self._anchorButton.AbsolutePosition
	local anchorSize = self._anchorButton.AbsoluteSize

	local panel = Create('Frame', {
		Name = 'Panel',
		Size = UDim2.new(0, PANEL_WIDTH, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.new(0, anchorPos.X + anchorSize.X - PANEL_WIDTH, 0, anchorPos.Y + anchorSize.Y + 6),
		BorderSizePixel = 0,
		Active = true,
		Parent = overlay,
	})
	Draw.ApplyCorner(panel, 10)
	Draw.ApplyPadding(panel, 10)
	Draw.ApplyListLayout(panel, 8, 'Vertical')
	self._panel = panel

	self._panelThemeConn = ThemeEngine.Changed:Connect(function()
		panel.BackgroundColor3 = ThemeEngine.Current.Surface
	end)
	panel.BackgroundColor3 = ThemeEngine.Current.Surface

	local headerRow = Create('Frame', {
		Name = 'HeaderRow',
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Parent = panel,
	})

	local headerLabel = Create('TextLabel', {
		Name = 'HeaderLabel',
		Text = 'Notifikasi',
		Size = UDim2.new(1, -50, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = headerRow,
	})

	local clearButton = Create('TextButton', {
		Name = 'ClearButton',
		Text = 'Clear',
		Size = UDim2.new(0, 44, 1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Parent = headerRow,
	})

	self._headerThemeConn = ThemeEngine.Changed:Connect(function()
		headerLabel.TextColor3 = ThemeEngine.Current.Text
		clearButton.TextColor3 = ThemeEngine.Current.TextDim
	end)
	headerLabel.TextColor3 = ThemeEngine.Current.Text
	clearButton.TextColor3 = ThemeEngine.Current.TextDim

	self._clearInput = InputHandler.new(clearButton)
	self._clearInput.PressEnd:Connect(function(wasClick)
		if wasClick then
			Notification.ClearHistory()
		end
	end)

	local listFrame = Create('ScrollingFrame', {
		Name = 'List',
		Size = UDim2.new(1, 0, 0, LIST_HEIGHT),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageTransparency = 0.3,
		Parent = panel,
	})
	Draw.ApplyListLayout(listFrame, 6, 'Vertical')
	self._listFrame = listFrame

	self._emptyLabel = Create('TextLabel', {
		Name = 'EmptyLabel',
		Text = 'Belum ada notifikasi.',
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		Visible = false,
		Parent = panel,
	})

	self._historyChangedConn = Notification.HistoryChanged:Connect(function()
		self:_refresh()
	end)

	self:_refresh()

	panel.BackgroundTransparency = 1
	Tween.Quick(panel, { BackgroundTransparency = 0 }, ANIM_DURATION)
end

function NotificationHistory:_clearRows()
	for _, row in self._rows do
		row.ThemeConn:Disconnect()
		row.Instance:Destroy()
	end
	table.clear(self._rows)
end

function NotificationHistory:_refresh()
	self:_clearRows()

	local history = Notification.GetHistory()
	self._emptyLabel.Visible = #history == 0
	self._emptyLabel.TextColor3 = ThemeEngine.Current.TextDim

	for i = #history, 1, -1 do
		self:_createRow(history[i])
	end
end

function NotificationHistory:_createRow(entry)
	local row = Create('Frame', {
		Name = 'Row',
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BorderSizePixel = 0,
		Parent = self._listFrame,
	})
	Draw.ApplyCorner(row, 6)
	Draw.ApplyPadding(row, 8)
	Draw.ApplyListLayout(row, 2, 'Vertical')

	local accentColor = Notification.TypeColors[entry.Type]

	local titleRow = Create('Frame', {
		Name = 'TitleRow',
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Parent = row,
	})

	local titleLabel = Create('TextLabel', {
		Name = 'TitleLabel',
		Text = entry.Title,
		Size = UDim2.new(1, -56, 1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = titleRow,
	})

	local timeLabel = Create('TextLabel', {
		Name = 'TimeLabel',
		Text = formatRelativeTime(entry.Timestamp),
		Size = UDim2.new(0, 56, 1, 0),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = titleRow,
	})

	local messageLabel = nil
	if entry.Message and entry.Message ~= '' then
		messageLabel = Create('TextLabel', {
			Name = 'MessageLabel',
			Text = entry.Message,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
	end

	local function refreshColors()
		row.BackgroundColor3 = accentColor or ThemeEngine.Current.Accent
		row.BackgroundTransparency = 0.9
		titleLabel.TextColor3 = ThemeEngine.Current.Text
		timeLabel.TextColor3 = ThemeEngine.Current.TextDim
		if messageLabel then
			messageLabel.TextColor3 = ThemeEngine.Current.TextDim
		end
	end
	refreshColors()

	local themeConn = ThemeEngine.Changed:Connect(refreshColors)

	table.insert(self._rows, { Instance = row, ThemeConn = themeConn })
end

function NotificationHistory:Destroy()
	self:Hide()
end

return NotificationHistory