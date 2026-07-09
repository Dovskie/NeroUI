local Cache = {}

local function Import(path)
    if Cache[path] then
        return Cache[path]
    end

    local url = BASE_URL .. path .. ".lua"
    
    local ok, source = pcall(game.HttpGet, game, url)
    assert(ok, ("NeroUI: gagal fetch module '%s' -> %s"):format(path, tostring(source)))

    local chunk, compileErr = loadstring(source, "=" .. path)
    assert(chunk, ("NeroUI: gagal compile module '%s' -> %s"):format(path, tostring(compileErr)))

    local result = chunk(Import)
    Cache[path] = result

    return result
end

return Import