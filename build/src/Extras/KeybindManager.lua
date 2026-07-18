local UserInputService = game:GetService("UserInputService")

local Import = ...

local KeybindManager = {}

local _actions = {}
local _enabled = true

local _inputBeganConnection = nil
local _inputEndedConnection = nil

local function ensureListening()
	if _inputBeganConnection then
		return
	end

	_inputBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or not _enabled then
			return
		end
		if input.KeyCode == Enum.KeyCode.Unknown then
			return
		end

		for _, action in _actions do
			if action.KeyCode == input.KeyCode then
				if action.Mode == "Hold" then
					if not action._isDown then
						action._isDown = true
						local ok, err = pcall(action.Callback, true)
						if not ok then
							warn("KeybindManager: callback error -> " .. tostring(err))
						end
					end
				else
					local ok, err = pcall(action.Callback)
					if not ok then
						warn("KeybindManager: callback error -> " .. tostring(err))
					end
				end
			end
		end
	end)

	_inputEndedConnection = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.Unknown then
			return
		end

		for _, action in _actions do
			if action.Mode == "Hold" and action.KeyCode == input.KeyCode and action._isDown then
				action._isDown = false
				local ok, err = pcall(action.Callback, false)
				if not ok then
					warn("KeybindManager: callback error -> " .. tostring(err))
				end
			end
		end
	end)
end

function KeybindManager.Register(actionName, props)
	assert(type(actionName) == "string" and actionName ~= "", "KeybindManager.Register butuh actionName berupa string")
	assert(type(props.Callback) == "function", "KeybindManager.Register butuh props.Callback berupa function")

	ensureListening()

	_actions[actionName] = {
		KeyCode = props.Default,
		Mode = props.Mode == "Hold" and "Hold" or "Press",
		Callback = props.Callback,
		_isDown = false,
	}
end

function KeybindManager.Bind(actionName, keybindComponent, props)
	props = props or {}

	KeybindManager.Register(actionName, {
		Default = keybindComponent:GetValue(),
		Mode = props.Mode,
		Callback = props.Callback,
	})

	keybindComponent.OnValueChanged:Connect(function(newKeyCode)
		KeybindManager.SetKey(actionName, newKeyCode)
	end)
end

function KeybindManager.SetKey(actionName, keyCode)
	local action = _actions[actionName]
	if action then
		action.KeyCode = keyCode
	end
end

function KeybindManager.Unregister(actionName)
	_actions[actionName] = nil
end

function KeybindManager.SetEnabled(enabled)
	_enabled = enabled
end

return KeybindManager