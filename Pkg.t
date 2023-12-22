local Pkg = {}

local random = math.random
math.randomseed(tonumber(tostring(os.time()):reverse():sub(1, 9)))
 
local function capturestdout(command)
    local handle = io.popen(command)
    local output = handle:read("*a")
    handle:close()
    return output:gsub('[\n\r]', '') 
end
 
local user = {}
user.name = capturestdout("git config user.name")
user.email = capturestdout("git config user.email") 
local homedir = capturestdout("echo ~$user")
local terrahome = capturestdout("echo $TERRA_PKG_PATH")
 
local function uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c) 
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end


function Pkg.require(package)
    return require(package..".src."..package)
end

function Pkg.create(pkgname)
 
    --generate package folders
    os.execute("mkdir "..pkgname) --package root folder
    os.execute("mkdir "..pkgname.."/src") --package source folder
    os.execute("mkdir "..pkgname.."/.pkg") --package managing folder

    --generate main source file
    local file = io.open(pkgname.."/src/"..pkgname..".t", "w")
    file:write("local Pkg = require(\"dev.Pkg.src.Pkg\")\n")
    file:write("local Example = Pkg.require(\"Example\")\n\n")
    file:write("local S = {}\n\n")
    file:write("Example.helloterra()\n\n")
    file:write("function S.helloterra()\n")
    file:write("  print(\"hello terra!\")\n")
    file:write("end\n\n")
    file:write("return S")
    file:close()

    --generate Package.toml
    local file = io.open(pkgname.."/Project.toml", "w")
    file:write("name = \""..pkgname.."\"\n")
    file:write("uuid = \""..uuid().."\"\n")
    file:write("authors = [\""..user.name.."<"..user.email..">".."\"]".."\n")
    file:write("version = \"".."0.1.0".."\"\n\n")
    file:write("[deps]\n\n")
    file:write("[compat]\n")
    file:close()
end
  
return Pkg
