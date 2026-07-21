local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local Tween = Import('Core/Tween')
local InputHandler = Import('Core/InputHandler')
local ScreenManager = Import('Core/ScreenManager')
local ThemeEngine = Import('Theme/ThemeEngine')
local Label = Import('Components/Basic/Label')
local ButtonComponent = Import('Components/Basic/Button')

local Modal = {}

local CARD_WIDTH = 300
local CARD_PADDING = 16
local CARD_RADIUS = 10
local BUTTON_HEIGHT = 34
local BUTTON_GAP = 8
local ANIM_DURATION = 0.15
local DANGER_COLOR = Color3.fromRGB(224, 90, 90)
local DANGER_COLOR_HOVER = Color3.fromRGB(235, 110, 110)

function Modal.Show(props)
	props = props or {}

	local overlay = Create("Frame", {
		Name = "NeroConfirmOverlay",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = true,
		Parent = ScreenManager.GetRoot(),
	})
	ScreenManager.BringToFront(overlay)

	local card = Create("Frame", {
		Name = "Card",
		Size = UDim2.new(0, CARD_WIDTH, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.47, 0),
		BorderSizePixel = 0,
		Parent = overlay,
	})
	Draw.ApplyCorner(card, CARD_RADIUS)
	Draw.ApplyPadding(card, CARD_PADDING)
	Draw.ApplyListLayout(card, 10, "Vertical")

	local themeConn = ThemeEngine.Changed:Connect(function()
		card.BackgroundColor3 = ThemeEngine.Current.Surface
	end)
	card.BackgroundColor3 = ThemeEngine.Current.Surface

	Label.new({
		Text = props.Title or "Konfirmasi",
		Bold = true,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = card,
	})

	if props.Message then
		local messageLabel = Label.new({
			Text = props.Message,
			Variant = "Dim",
			TextSize = 13,
			Size = UDim2.new(1, 0, 0, 0),
			Parent = card,
		})
		messageLabel.Instance.TextWrapped = true
		messageLabel.Instance.AutomaticSize = Enum.AutomaticSize.Y
	end

	local buttonRow = Create("Frame", {
		Name = "ButtonRow",
		Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
		BackgroundTransparency = 1,
		Parent = card,
	})
	Draw.ApplyListLayout(buttonRow, BUTTON_GAP, "Horizontal")

	local closed = false
	local outsideClickConnection = nil

	local function close()
		if closed then return end
		closed = true

		if outsideClickConnection then
			outsideClickConnection:Disconnect()
		end

		Tween.Quick(overlay, { BackgroundTransparency = 1 }, ANIM_DURATION)
		local tween = Tween.Quick(card, { Position = UDim2.new(0.5, 0, 0.49, 0) }, ANIM_DURATION)
		tween.Completed:Connect(function()
			themeConn:Disconnect()
			overlay:Destroy()
		end)
	end

	ButtonComponent.new({
		Text = props.CancelText or "Batal",
		Size = UDim2.new(0.5, -BUTTON_GAP / 2, 1, 0),
		Parent = buttonRow,
		Callback = function()
			close()
			if props.OnCancel then
				props.OnCancel()
			end
		end,
	})

	local confirmButton = ButtonComponent.new({
		Text = props.ConfirmText or "Konfirmasi",
		Size = UDim2.new(0.5, -BUTTON_GAP / 2, 1, 0),
		Parent = buttonRow,
		Callback = function()
			close()
			if props.OnConfirm then
				props.OnConfirm()
			end
		end,
	})

	if props.Danger then
		confirmButton.Instance.BackgroundColor3 = DANGER_COLOR
		local input = InputHandler.new(confirmButton.Instance)
		input.HoverStart:Connect(function()
			Tween.Quick(confirmButton.Instance, { BackgroundColor3 = DANGER_COLOR_HOVER }, 0.15)
		end)
		input.HoverEnd:Connect(function()
			Tween.Quick(confirmButton.Instance, { BackgroundColor3 = DANGER_COLOR }, 0.15)
		end)
	end

	if props.DismissOnOutsideClick then
		local input = InputHandler.new(overlay)
		outsideClickConnection = input.PressEnd:Connect(function(wasClick)
			if wasClick then
				close()
				if props.OnCancel then
					props.OnCancel()
				end
			end
		end)
	end

	Tween.Quick(overlay, { BackgroundTransparency = 0.45 }, ANIM_DURATION)
	Tween.Quick(card, { Position = UDim2.new(0.5, 0, 0.45, 0) }, ANIM_DURATION)

	return { Close = close }
end

return Modal