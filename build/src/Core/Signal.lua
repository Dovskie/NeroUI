local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Signal.new()
    local self = setmetatable({}, Signal)
    self._handlers ={}
    self._firing = false
    return self
end

function Signal:Connect(fn)
    assert(type(fn) == "function", "Signal:Connect butuh function, dapetnya " .. type(fn))

    local handler = { fn = fn, once = false}
    table.insert(self._handlers, handler)
    
    local connection = setmetatable({}, Connection)
    connection._signal = self
    connection._handler = handler
    connection.Connected = true

    return connection
end

function Signal:Once(fn)
    assert(type(fn) == "function", "Signal:Connect butuh function, dapetnya " .. type(fn))

    local handler = { fn = fn, once = true}
    table.insert(self._handlers, handler)

    local connection = setmetatable({}, Connection)
    connection._signal = self
    connection._handler = handler
    connection.Connected = true

    return connection
end

function Signal:Fire(...)
    local handlers = table.clone(self._handlers)

    for _, handler in handlers do
        task.spawn(handler.fn, ...)
        
        if handler.once then
            self:_removeHandler(handler)
        end
    end
end

function Signal:Wait()
    local thread = coroutine.running()
    local connection

    connection = self:Once(function (...)
        task.spawn(thread, ...)
    end)

    return coroutine.yield()
end

function Signal:DisconnectAll()
    table.clear(self._handlers)
end

function Signal:Destroy(args)
    self:DisconnectAll()
end

function Signal:_removeHandler(handler)
    local index = table.find(self._handlers, handler)
    if index then
        table.remove(self._handlers, index)
    end
end

function Connection:Disconnect()
    if not self.Connected then
        return 
    end

    self.Connected = false
    self._signal:_removeHandler(self._handler)
end

return Signal
