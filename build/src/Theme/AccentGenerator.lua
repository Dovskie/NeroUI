local AccentGenerator = {}

local function clamp01(value)
    return math.clamp(value, 0, 1)
end

function AccentGenerator.Generate(baseColor)
    assert(typeof(baseColor) == 'Color3', 'AccentGenerator.Generate butuh Color3')

    local h, s, v = baseColor:ToHSV()

    local hover = Color3.fromHSV(h, s, clamp01(v+0.09))
    local pressed = Color3.fromHSV(h, s, clamp01(v-0.13))
    local disabled = Color3.fromHSV(h, clamp01(s*0.35), clamp01(v*0.55))

    return {
        Base = baseColor,
        Hover = hover,
        Pressed = pressed,
        Disabled = disabled
    }
end

return AccentGenerator