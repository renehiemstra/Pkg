local Pkg = {}

local random = math.random
math.randomseed(tonumber(tostring(os.time()):reverse():sub(1, 9)))
 
function Pkg.capturestdout(command)
    local handle = io.popen(command)
    local output = handle:read("*a")
    handle:close()
    return output:gsub('[\n\r]', '') 
end
 
Pkg.user = {}
Pkg.user.name = Pkg.capturestdout("git config user.name")
Pkg.user.email = Pkg.capturestdout("git config user.email") 
Pkg.homedir = Pkg.capturestdout("echo ~$user")
Pkg.terrahome = Pkg.capturestdout("echo $TERRA_PKG_PATH")
 
--create a universal unique identifier (uuid)
function Pkg.uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c) 
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

function Pkg.validategiturl(url)
    os.execute("git ls-remote "..url.." > /dev/null")
end


--load a terra package
function Pkg.require(package)
    return require(package..".src."..package)
end

--create a terra pkg template
function Pkg.create(pkgname)
print("creating package") 
    --generate package folders
    os.execute("mkdir "..pkgname) --package root folder
    os.execute("mkdir "..pkgname.."/src") --package source folder
    os.execute("mkdir "..pkgname.."/.pkg") --package managing folder

    --generate main source file
    local file = io.open(pkgname.."/src/"..pkgname..".t", "w")
    file:write("local Pkg = require(\"Pkg\")\n")
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
    file:write("uuid = \""..Pkg.uuid().."\"\n")
    file:write("authors = [\""..Pkg.user.name.."<"..Pkg.user.email..">".."\"]".."\n")
    file:write("version = \"".."0.1.0".."\"\n\n")
    file:write("[deps]\n\n")
    file:write("[compat]\n")
    file:close()

    --initialize git repository
    os.execute("cd "..pkgname..";".. 
	"git init"..";"..
  	"git add ."..";"..
	"git commit -m \"Initialized terra package\"")
end
  
return Pkg
