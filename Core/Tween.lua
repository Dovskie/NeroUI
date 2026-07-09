local TweenService = game:GetService('TweenService')

local Import = loadstring(game:HttpGet('https://raw.githubusercontent.com/Dovskie/NeroUI/refs/heads/main/init.lua'))()
local Signal = Import('Core/Tween')

local Tween = {}
Tween.__index = Tween

local DEFAULT_DURATION = 0.2
local DEFAULT_STYLE = Enum.EasingStyle.Quad
local DEFAULT_DIRECTION = Enum.EasingDirection.Out

function Tween.new(instance, props, duration, style, direction)
    assert(typeof(instance) == "Instance", "Tween.new butuh Instance, dapetnya " .. typeof(instance))
    assert(typeof(props) == 'table', "Tween.new butuh props berupa table")

    local self =setmetatable({}, Tween)

    self.Instance = instance
    self.Completed = Signal.new()
    self.Playing = false

    local tweenInfo = TweenInfo.new(
        duration or DEFAULT_DIRECTION,
        style or DEFAULT_STYLE,
        direction or DEFAULT_DIRECTION
    )

    self._tween = TweenService:Create(instance, tweenInfo, props)
    
    self._completedConn = self._tween.Completed:Connect(function(playbackState)
        self.Playing = false
        self.Completed:Fire(playbackState)
    end)

    return self
end

function Tween:Play()
    self.Playing = true
    self._tween:Play()
    return self
end

function Tween:Pause()
    self.Playing = false
    self._tween:Pause()
    return self
end

function Tween:Cancel()
    self.Playing = false
    self._tween:Cancel()
    return self
end

function Tween:Destroy()
    if self._completedConn then
        self._completedConn:Disconnect()
        self._completedConn = nil
    end

    if self._tween then
        self._tween:Cancel()
        self._tween = nil
    end

    self.Completed:Destroy()
end

function Tween.Quick(instance, props, duration, style, direction)
    local self = Tween.new(instance, props, duration, style, direction)
    self:Play()
    return self
end

return Tween