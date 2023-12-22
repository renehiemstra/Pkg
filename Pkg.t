local Pkg = {}

local function capturestdout(command)
    local handle = io.popen(command)
    local output = handle:read("*a")
    handle:close()
    return output:gsub('[\n\r]', '') 
end

--path to local packages
local PKG_PATH = capturestdout("echo $TERRA_PKG_PATH")
print(PKG_PATH)

function Pkg.require(package)
    return require(package..".src."..package)
end

return Pkg
