local UserInputService = game:GetService("UserInputService")

local Import = ...
local Signal = Import('Core/Signal')

local InputHandler = {}
InputHandler.__index = InputHandler

local function isPointerInput(inputType)
    return inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch
end

function InputHandler.new(guiObject)
    assert(typeof(guiObject) == 'Instance' and guiObject:IsA("GuiObject"), 'InputHandler.new butuh GuiObject')

    local self = setmetatable({}, InputHandler)
    self.Instance = guiObject
    self.Hovering = false
    self.Pressed = false

    self.HoverStart = Signal.new()
    self.HoverEnd = Signal.new()
    self.PressStart = Signal.new()
    self.PressEnd = Signal.new()
    self.DragStart = Signal.new()
    self.DragMove = Signal.new()
    self.DragEnd = Signal.new()

    self._connection = {}
    self._dragging = false
    self._dragStartPos = nil

    self:_setupHover()
    self:_setupPress()

    return self
end

function InputHandler:_track(connection)
    table.insert(self._connection, connection)
end

function InputHandler:_setupHover()
    self:_track(self.Instance.MouseEnter:Connect(function()
        self.Hovering = true
        self.HoverStart:Fire()
    end))

    self:_track(self.Instance.MouseLeave:Connect(function()
        self.Hovering = false
        self.HoverEnd:Fire()
    end))
end

function InputHandler:_setupPress()
    self:_track(self.Instance.InputBegan:Connect(function(input)
        if not isPointerInput(input.UserInputType) then return end
        self.Pressed = true
        self.PressStart:Fire(input)
    end))

    self:_track(self.Instance.InputEnded:Connect(function(input)
        if not isPointerInput(input.UserInputType) then return end
        if not self.Pressed then return end

        self.Pressed = false
        self.PressEnd:Fire(self.Hovering)
    end))
end

function InputHandler:EnableDrag(dragTarget)
    dragTarget = dragTarget or self.Instance

    self:_track(self.Instance.InputBegan:Connect(function(input)
        if not isPointerInput(input.UserInputType) then return end

        self._dragging = true
        self._dragStartPos = input.Position
        self._dragStartOffset = dragTarget.Position
        self.DragStart:Fire()

        local moveConn
        local endConn

        moveConn = UserInputService.InputChanged:Connect(function(moveInput)
            if not self._dragging then return end
            if moveInput.UserInputType ~= Enum.UserInputType.MouseMovement and moveInput.UserInputType ~= Enum.UserInputType.Touch then return end

            local delta = moveInput.Position - self._dragStartPos
            dragTarget.Position = UDim2.new(
                self._dragStartOffset.X.Scale,
                self._dragStartOffset.X.Offset + delta.X,
                self._dragStartOffset.Y.Scale,
                self._dragStartOffset.Y.Offset + delta.Y
            )
            self.DragMove:Fire(Vector2.new(delta.X, delta.Y))
        end)

        endConn = UserInputService.InputEnded:Connect(function(endInput)
            if not isPointerInput(endInput.UserInputType) then return end
            if not self._dragging then return end

            self._dragging = false
            moveConn:Disconnect()
            endConn:Disconnect()
            self.DragEnd:Fire()
        end)
    end))
end

function InputHandler:Destroy()
    for _, connection in self._connection do
        connection:Disconnect()
    end

    table.clear(self._connection)
    
    self.HoverStart:Destroy()
	self.HoverEnd:Destroy()
	self.PressStart:Destroy()
	self.PressEnd:Destroy()
	self.DragStart:Destroy()
	self.DragMove:Destroy()
	self.DragEnd:Destroy()
end

return InputHandler