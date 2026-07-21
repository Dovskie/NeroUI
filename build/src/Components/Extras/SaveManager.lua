local Import = ...
local Create = Import('Core/Create')
local Draw = Import('Core/Draw')
local BaseComponent = Import('Components/Base/BaseComponent')
local Dropdown = Import('Components/Selection/Dropdown')
local ButtonComponent = Import('Components/Basic/Button')
local TextBox = Import('Components/Input/TextBox')
local Notification = Import('Components/Feedback/Notification')
local ConfigManager = Import('Extras/ConfigManager')

local SaveManager = setmetatable({}, {__index = BaseComponent})
SaveManager.__index = SaveManager

local function currentConfigList()
    local list = ConfigManager.ListConfigs()
    if #list == 0 then
        list = { 'Default' }
    end
    return list
end

function SaveManager.new(props)
    props = props or {}

    local inst = Create('Frame', {
        Name = 'NeroSaveManager',
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = props.Parent
    })
    Draw.ApplyListLayout(inst, 8, 'Vertical')

    local self = BaseComponent.new(inst)
    setmetatable(self, SaveManager)

    self._nameInput = TextBox.new({
        Text = 'Nama Config',
        Placeholder = 'contoh: preset1',
        Parent = inst,
    })
    self:AddChild(self._nameInput)

    self._configDropdown = Dropdown.new({
        Text = 'Load Config',
        Options = currentConfigList(),
        Parent = inst,
    })
    self:AddChild(self._configDropdown)

    local buttonRow = Create('Frame', {
        Name = 'ButtonRow',
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        Parent = inst,
    })
    Draw.ApplyListLayout(buttonRow, 8, 'Horizontal')

    self._saveButton = ButtonComponent.new({
        Text = 'Save',
        Size = UDim2.new(0, 100, 0, 32),
        Parent = buttonRow,
        Callback = function()
            self:_handleSave()
        end,
    })
    self:AddChild(self._saveButton)

    self._loadButton = ButtonComponent.new({
        Text = 'Load',
        Size = UDim2.new(0, 100, 0, 32),
        Parent = buttonRow,
        Callback = function()
            self:_handleLoad()
        end,
    })
    self:AddChild(self._loadButton)

    self._deleteButton = ButtonComponent.new({
        Text = 'Delete',
        Size = UDim2.new(0, 100, 0, 32),
        Parent = buttonRow,
        Callback = function()
            self:_handleDelete()
        end,
    })
    self:AddChild(self._deleteButton)

    return self
end

function SaveManager:_refreshDropdown(preferredValue)
    local list = currentConfigList()
    self._configDropdown:SetOptions(list)

    if preferredValue and table.find(list, preferredValue) then
        self._configDropdown:SetValue(preferredValue)
    end
end

function SaveManager:_handleSave()
    local name = self._nameInput:GetValue()
    if not name or name == '' then
        Notification.Show({ Title = 'Save gagal', Message = 'Nama config ga boleh kosong', Type = 'Error' })
        return
    end

    local ok, err = ConfigManager.Save(name)
    if ok then
        Notification.Show({ Title = 'Config disimpan', Message = ('"%s" berhasil disimpan.'):format(name), Type = 'Success' })
        self:_refreshDropdown(name)
    else
        Notification.Show({ Title = 'Save gagal', Message = tostring(err), Type = 'Error' })
    end
end

function SaveManager:_handleLoad()
    local name = self._configDropdown:GetValue()
    if not name then return end

    local ok, err = ConfigManager.Load(name)
    if ok then
        Notification.Show({ Title = 'Config dimuat', Message = ('"%s" berhasil dimuat.'):format(name), Type = 'Success' })
    else
        Notification.Show({ Title = 'Load gagal', Message = tostring(err), Type = 'Error' })
    end
end

function SaveManager:_handleDelete()
    local name = self._configDropdown:GetValue()
    if not name then return end

    local ok = ConfigManager.DeleteConfig(name)
    if ok then
        Notification.Show({ Title = 'Config dihapus', Message = ('"%s" berhasil dihapus.'):format(name), Type = 'Warning' })
        self:_refreshDropdown()
    else
        Notification.Show({ Title = 'Delete gagal', Message = 'Config ga ketemu atau executor ga support', Type = 'Error' })
    end
end

return SaveManager