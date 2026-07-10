local Import = ...
local Signal = Import('Core/Signal')
local Tokens = Import('Theme/Tokens')
local AccentGenerator = Import('Theme/AccentGenerator')

local ThemeEngine = {}

ThemeEngine.Changed = Signal.new()

local _mode = 'Dark'
local _accentVariants = AccentGenerator.Generate(Tokens.DefaultAccent)

ThemeEngine.Current = {}

local function _rebuild()
    local base = Tokens[_mode]

    ThemeEngine.Current.Background = base.Background
    ThemeEngine.Current.Surface = base.Surface
    ThemeEngine.Current.Border = base.Border
    ThemeEngine.Current.Text = base.Text
    ThemeEngine.Current.TextDim = base.TextDim

    ThemeEngine.Current.Accent = _accentVariants.Base
    ThemeEngine.Current.AccentHover = _accentVariants.Hover
    ThemeEngine.Current.AccentPressed = _accentVariants.Pressed
    ThemeEngine.Current.AccentDisabled = _accentVariants.Disabled
end

function ThemeEngine.SetMode(mode)
    assert(mode == 'Dark' or mode == 'Light', 'ThemeEngine.SetMode cuma nerima "Dark" atau "Light"')

    if _mode == mode then return end
    _mode = mode
    _rebuild()
    ThemeEngine.Changed:Fire()
end

function ThemeEngine.GetMode()
    return _mode
end

function ThemeEngine.SetAccent(baseColor)
    assert(typeof(baseColor) == 'Color3', "ThemeEngine.SetAccent butuh Color3")

    _accentVariants = AccentGenerator.Generate(baseColor)
    _rebuild()
    ThemeEngine.Changed:Fire()
end

function ThemeEngine.Get(tokenName)
    return ThemeEngine.Current[tokenName]
end

_rebuild()

return ThemeEngine