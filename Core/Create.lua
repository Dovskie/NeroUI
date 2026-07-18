local Create = {}

local DEFERRED_PROPS = {
	Parent = true,
}

function Create.new(className, props, children)
    assert(type(className) == 'string', 'Create butuh className berupa string')
    props = props or {}
    children = children or {}
    local instance = Instance.new(className)

    local deferred = {}
    
    for key, value in props do
        if DEFERRED_PROPS[key] then
            deferred[key] = value
        else
            local success, err = pcall(function()
                instance[key] = value
            end)
            
            if not success then
                warn(("Create(\"%s\"): gagal set property '%s' -> %s"):format(className, key, err))
            end
        end
    end
    
    for _, child in children do
        child.Parent = instance
    end

    for key, value in deferred do
        instance[key] = value
    end

    return instance
end

setmetatable(Create, {
	__call = function(_, ...)
		return Create.new(...)
	end,
})

return Create