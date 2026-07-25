local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Import = ...
local Tween = Import("Core/Tween")

local WidgetDrag = {}
WidgetDrag.__index = WidgetDrag

local CLICK_THRESHOLD = 5
local SNAP_MARGIN = 12
local SNAP_TWEEN_DURATION = 0.2

local function isPointerInput(inputType)
	return inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch
end

local function getViewportSize()
	local camera = Workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1920, 1080)
end

function WidgetDrag.Enable(instance, props)
	assert(typeof(instance) == "Instance" and instance:IsA("GuiObject"),
		"WidgetDrag.Enable butuh GuiObject")
	props = props or {}

	local self = setmetatable({}, WidgetDrag)
	self._instance = instance
	self._snapToEdge = props.SnapToEdge ~= false
	self._onClick = props.OnClick
	self._snapTween = nil

	self._inputBeganConnection = instance.InputBegan:Connect(function(input)
		if not isPointerInput(input.UserInputType) then
			return
		end

		local dragStartMouse = input.Position
		local dragStartInstance = instance.Position
		local totalMovement = 0
		local dragging = true

		local moveConnection, endConnection

		moveConnection = UserInputService.InputChanged:Connect(function(moveInput)
			if not dragging then
				return
			end
			if moveInput.UserInputType ~= Enum.UserInputType.MouseMovement
				and moveInput.UserInputType ~= Enum.UserInputType.Touch then
				return
			end

			local delta = moveInput.Position - dragStartMouse
			totalMovement = math.max(totalMovement, delta.Magnitude)

			instance.Position = UDim2.new(
				dragStartInstance.X.Scale,
				dragStartInstance.X.Offset + delta.X,
				dragStartInstance.Y.Scale,
				dragStartInstance.Y.Offset + delta.Y
			)
		end)

		endConnection = UserInputService.InputEnded:Connect(function(endInput)
			if not isPointerInput(endInput.UserInputType) then
				return
			end
			if not dragging then
				return
			end

			dragging = false
			moveConnection:Disconnect()
			endConnection:Disconnect()

			if totalMovement < CLICK_THRESHOLD then
				if self._onClick then
					self._onClick()
				end
			elseif self._snapToEdge then
				self:_snap()
			end
		end)
	end)

	return self
end

function WidgetDrag:_snap()
	local viewport = getViewportSize()
	local instance = self._instance
	local currentX = instance.AbsolutePosition.X
	local width = instance.AbsoluteSize.X

	local centerX = currentX + (width / 2)
	local targetX

	if centerX < viewport.X / 2 then
		targetX = SNAP_MARGIN
	else
		targetX = viewport.X - width - SNAP_MARGIN
	end

	if self._snapTween then
		self._snapTween:Cancel()
	end
	self._snapTween = Tween.Quick(instance, {
		Position = UDim2.new(0, targetX, 0, instance.Position.Y.Offset),
	}, SNAP_TWEEN_DURATION)
end

function WidgetDrag:Destroy()
	if self._inputBeganConnection then
		self._inputBeganConnection:Disconnect()
		self._inputBeganConnection = nil
	end
	if self._snapTween then
		self._snapTween:Destroy()
		self._snapTween = nil
	end
end

return WidgetDrag