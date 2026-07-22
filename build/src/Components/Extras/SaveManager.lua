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

    Create('Frame', {
        Name = 'Divider',
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundTransparency = 1,
        Parent = inst,
    })

    self._exportBox = TextBox.new({
        Text = 'Config String',
        Placeholder = 'Klik Export buat generate, atau paste config di sini lalu klik Import',
        BoxSize = UDim2.new(0, 220, 0, 28),
        Parent = inst,
    })
    self:AddChild(self._exportBox)

    local exportRow = Create('Frame', {
        Name = 'ExportRow',
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        Parent = inst,
    })
    Draw.ApplyListLayout(exportRow, 8, 'Horizontal')

    self._exportButton = ButtonComponent.new({
        Text = 'Export',
        Size = UDim2.new(0, 100, 0, 32),
        Parent = exportRow,
        Callback = function()
            self:_handleExport()
        end,
    })
    self:AddChild(self._exportButton)

    self._importButton = ButtonComponent.new({
        Text = 'Import',
        Size = UDim2.new(0, 100, 0, 32),
        Parent = exportRow,
        Callback = function()
            self:_handleImport()
        end,
    })
    self:AddChild(self._importButton)

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

function SaveManager:_handleExport()
    local exported, err = ConfigManager.Export()
    if not exported then
        Notification.Show({ Title = 'Export gagal', Message = tostring(err), Type = 'Error' })
        return
    end

    self._exportBox:SetValue(exported, false)

    if setclipboard then
        pcall(setclipboard, exported)
        Notification.Show({ Title = 'Config di-export', Message = 'String config disalin ke clipboard.', Type = 'Success' })
    else
        Notification.Show({
            Title = 'Config di-export',
            Message = 'Copy manual dari kolom Config String (executor ga support setclipboard).',
            Type = 'Success',
        })
    end
end

function SaveManager:_handleImport()
    local str = self._exportBox:GetValue()
    if not str or str == '' then
        Notification.Show({ Title = 'Import gagal', Message = 'Tempel string config dulu di kolom Config String', Type = 'Error' })
        return
    end

    local ok, err = ConfigManager.Import(str)
    if ok then
        Notification.Show({ Title = 'Config di-import', Message = 'Semua pengaturan berhasil diterapkan.', Type = 'Success' })
    else
        Notification.Show({ Title = 'Import gagal', Message = tostring(err), Type = 'Error' })
    end
end

return SaveManager