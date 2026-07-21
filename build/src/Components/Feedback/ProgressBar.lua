local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local Tween = Import('Core/Tween')
local BaseComponent = Import('Components/Base/BaseComponent')
local Label = Import('Components/Basic/Label')

local ProgressBar = setmetatable({}, {__index = BaseComponent})
ProgressBar.__index = ProgressBar

local CONTAINER_HEIGHT = 40
local LABEL_ROW_HEIGHT = 18
local TRACK_HEIGHT = 8
local FILL_TWEEN_DURATION = 0.2
local INDETERMINATE_DURATION = 0.9

function ProgressBar.new(props)
	props = props or {}

	local inst = Create('Frame', {
		Name = 'NeroProgressBar',
		Size = UDim2.new(1, 0, 0, CONTAINER_HEIGHT),
		BackgroundTransparency = 1,
		Parent = props.Parent
	})

	local self = BaseComponent.new(inst)
	setmetatable(self, ProgressBar)

	self._min = props.Min or 0
	self._max = props.Max or 100
	assert(self._max > self._min, 'ProgressBar.new: Max harus lebih besar dari Min')

	self._value = math.clamp(props.Default or self._min, self._min, self._max)
	self._showPercentage = props.ShowPercentage ~= false
	self._indeterminate = false
	self._indeterminateTween = nil
	self._fillTween = nil

	self._label = Label.new({
		Text = props.Text or 'Progress',
		Size = UDim2.new(1, -50, 0, LABEL_ROW_HEIGHT),
		Parent = inst,
	})
	self:AddChild(self._label)

	if self._showPercentage then
		self._percentLabel = Label.new({
			Text = '',
			Size = UDim2.new(0, 50, 0, LABEL_ROW_HEIGHT),
			Position = UDim2.new(1, -50, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			Variant = 'Dim',
			Parent = inst,
		})
		self:AddChild(self._percentLabel)
	end

	local track = Create('Frame', {
		Name = 'Track',
		Size = UDim2.new(1, 0, 0, TRACK_HEIGHT),
		Position = UDim2.new(0, 0, 1, -TRACK_HEIGHT),
		BorderSizePixel = 0,
		Parent = inst,
	})
	Draw.ApplyCorner(track, TRACK_HEIGHT / 2)
	self._track = track

	local fill = Create('Frame', {
		Name = 'Fill',
		Size = UDim2.new(0, 0, 1, 0),
		BorderSizePixel = 0,
		Parent = track,
	})
	Draw.ApplyCorner(fill, TRACK_HEIGHT / 2)
	self._fill = fill

	self:OnThemeChanged(function(theme)
		track.BackgroundColor3 = theme.Border
		fill.BackgroundColor3 = theme.Accent
	end)

	self:_updateVisual(false)

	if props.Indeterminate then
		self:SetIndeterminate(true)
	end

	return self
end

function ProgressBar:_percent()
	return (self._value - self._min) / (self._max - self._min)
end

function ProgressBar:_updateVisual(animated)
	if self._indeterminate then return end

	local p = self:_percent()

	if self._fillTween then
		self._fillTween:Cancel()
	end

	if animated then
		self._fillTween = Tween.Quick(self._fill, { Size = UDim2.new(p, 0, 1, 0) }, FILL_TWEEN_DURATION)
	else
		self._fill.Size = UDim2.new(p, 0, 1, 0)
	end

	if self._percentLabel then
		self._percentLabel:SetText(math.floor(p * 100) .. '%')
	end
end

function ProgressBar:SetValue(value, animated)
	if self._indeterminate then
		self:SetIndeterminate(false)
	end

	self._value = math.clamp(value, self._min, self._max)
	self:_updateVisual(animated ~= false)
end

function ProgressBar:GetValue()
	return self._value
end

function ProgressBar:SetIndeterminate(isIndeterminate)
	self._indeterminate = isIndeterminate

	if self._indeterminateTween then
		self._indeterminateTween:Cancel()
		self._indeterminateTween = nil
	end

	if self._percentLabel then
		self._percentLabel.Instance.Visible = not isIndeterminate
	end

	if isIndeterminate then
		self._fill.Size = UDim2.new(0.3, 0, 1, 0)

		local function loop()
			self._fill.Position = UDim2.new(0, 0, 0, 0)
			self._indeterminateTween = Tween.new(self._fill, { Position = UDim2.new(0.7, 0, 0, 0) }, INDETERMINATE_DURATION, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			self._indeterminateTween.Completed:Connect(function()
				if self._indeterminate then
					loop()
				end
			end)
			self._indeterminateTween:Play()
		end
		loop()
	else
		self._fill.Position = UDim2.new(0, 0, 0, 0)
		self:_updateVisual(false)
	end
end

function ProgressBar:Destroy()
	if self._fillTween then
		self._fillTween:Destroy()
		self._fillTween = nil
	end
	if self._indeterminateTween then
		self._indeterminateTween:Destroy()
		self._indeterminateTween = nil
	end

	BaseComponent.Destroy(self)
end

return ProgressBar