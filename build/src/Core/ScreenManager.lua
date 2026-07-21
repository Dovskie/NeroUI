local Players = game:GetService('Players')
local CoreGui = game:GetService('CoreGui')

local ScreenManager = {}

local _root = nil
local _order = 0

local function generateRandomName()
    local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local result = {}

    for i = 1, 12 do
        local index = math.random(1, #chars)
        result[i] = chars:sub(index, index)
    end
    return table.concat(result)
end

local function resolveParent()
    local getHiddenUI = (getgenv and getgenv().gethui) or gethui
    if getHiddenUI then
        local ok, hiddenUI = pcall(getHiddenUI)
        if ok and hiddenUI then
            return hiddenUI
        end
    end

    local ok, coreGuiOk = pcall(function()
        return CoreGui
    end)

    if ok and coreGuiOk then
        local success = pcall(function()
            local test = Instance.new('ScreenGui')
            test.Parent = CoreGui
            test:Destroy()
        end)

        if success then
            return CoreGui
        end
    end

    local plr = Players.LocalPlayer
    if plr then
        return plr:WaitForChild('PlayerGui')
    end

    error('ScreenManager: ga nemu parent yang valid buat ScreenGui (CoreGui/PlayerGui/gethui gagal semua)')
end

local function tryProtectGui(gui)
	local protect = (syn and syn.protect_gui)
		or protect_gui
		or protectgui
		or (getgenv and getgenv().protect_gui)

	if protect then
		pcall(protect, gui)
	end
end

function ScreenManager.GetRoot()
    if _root then return _root end

    local gui = Instance.new('ScreenGui')
    gui.Name = generateRandomName()
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999
    gui.Parent = resolveParent()

    tryProtectGui(gui)

    _root = gui
    return _root
end

function ScreenManager.Register(frame)
    assert(typeof(frame) == 'Instance' and frame:IsA("GuiObject"), "ScreenManager.Register butuh GuiObject")

    frame.Parent = ScreenManager.GetRoot()
    ScreenManager.BringToFront(frame)
    return frame
end

function ScreenManager.BringToFront(frame)
    assert(typeof(frame) == 'Instance' and frame:IsA("GuiObject"), "ScreenManager.BringToFront butuh GuiObject")

    _order += 1

    local function applyRelative(inst)
        if inst:GetAttribute("_neroBaseZ") == nil then
            inst:SetAttribute("_neroBaseZ", inst.ZIndex)
        end
        inst.ZIndex = _order + inst:GetAttribute("_neroBaseZ")
    end

    applyRelative(frame)
    for _, descendant in frame:GetDescendants() do
        if descendant:IsA("GuiObject") then
            applyRelative(descendant)
        end
    end
end

function ScreenManager.Unregister(frame)
    if frame and frame.Parent == _root then
        frame.Parent = nil
    end
end

return ScreenManager