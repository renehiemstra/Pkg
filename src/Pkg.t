import "terratest"

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

local function esc(string)
  return "\""..string.."\""
end

function Pkg.giturlexitcode(url)
    return Pkg.capturestdout("git ls-remote --exit-code "..url.." &> /dev/null; echo $?")
end

function Pkg.validemptygitrepo(url)
    local exitcode = Pkg.giturlexitcode(url)
    return exitcode=="2"
end

function Pkg.validnonemptygitrepo(url)
    local exitcode = Pkg.giturlexitcode(url)
    return exitcode=="0"
end

--check if the git-url points to a valid repository
function Pkg.validgitrepo(url)
    local exitcode = Pkg.giturlexitcode(url)
    return exitcode=="0" or exitcode=="2"
end

--extract the pkg name from the git url
function Pkg.namefromgiturl(url)
    return string.sub(Pkg.capturestdout("echo $(basename "..esc(url)..")"), 1, -5)
end

--load a terra package
function Pkg.require(package)
    return require(package..".src."..package)
end

function isfile(file)
    local exitcode = Pkg.capturestdout("test -f "..file.."; echo $?")
    return exitcode=="0"
end

function isfolder(folder)
    local exitcode = Pkg.capturestdout("test -d "..folder.."; echo $?")
    return exitcode=="0"
end

function Pkg.ispkg(root)
    local pkgname = Pkg.capturestdout("cd "..root.."; echo \"${PWD##*/}\"")
    local c1 = isfile(root.."/Project.toml")
    local c2 = isfile(root.."/src/"..pkgname..".t")
    return c1 and c2
end

--generate main source file
local function gensrcfile(pkgname)
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
end

--generate package folders
local function genpkgfolders(pkgname)
    os.execute("mkdir "..pkgname) --package root folder
    os.execute("mkdir "..pkgname.."/src") --package source folder
    os.execute("mkdir "..pkgname.."/.pkg") --package managing folder
end

--generate Package.toml
local function genpkgtoml(pkgname)
    local file = io.open(pkgname.."/Project.toml", "w")
    file:write("name = \""..pkgname.."\"\n")
    file:write("uuid = \""..Pkg.uuid().."\"\n")
    file:write("authors = [\""..Pkg.user.name.."<"..Pkg.user.email..">".."\"]".."\n")
    file:write("version = \"".."0.1.0".."\"\n\n")
    file:write("[deps]\n\n")
    file:write("[compat]\n")
    file:close()  
end

--initialize git repository
local function initgitrepo(pkgname)
    os.execute("cd "..pkgname..";".. 
        "git init"..";"..          
        "git add ."..";"..         
        "git commit -m \"Initialized terra package\"")
end

--create a terra pkg template
function Pkg.create(pkgname)
    genpkgfolders(pkgname)
    gensrcfile(pkgname)
    genpkgtoml(pkgname)
    initgitrepo(pkgname)
end

testenv "Pkg testsuite" do

testset "validate terra pkg" do
    local t1 = isfile("./Pkg.t")
    test t1 

    local t2 = isfolder(".")
    test t2

    local t3 = Pkg.ispkg("..")
    test t3

    Pkg.create("MyPackage")
    local t4 = Pkg.ispkg("./MyPackage")
    test t4
    os.execute("rm -rf ./MyPackage")
end


testset "get repo name from url" do
    local t5 = Pkg.namefromgiturl("git@gitlab.com:group/subgroup/MyPackage.git")
    test t5=="MyPackage"
 
    local t6 = Pkg.namefromgiturl("https://gitlab.com/group/subgroup/MyPackage.git") 
    test t6=="MyPackage"
 
    local t7 = Pkg.namefromgiturl("git@gitlab.com:group/subgroup/MyPackage.git") 
    test t7=="MyPackage" 
 
    local t8 = Pkg.namefromgiturl("https://github.com/group/subgroup/MyPackage.git")
    test t6=="MyPackage"   
end

testset "validate git remote repo url" do
    local t9 = Pkg.validgitrepo("git@github.com:terralang/terra.git")
    local t10 = Pkg.validgitrepo("git@github.com:terralang/terra.gi")     
    test t9 and not t10
    
    local t11 = Pkg.validemptygitrepo("git@github.com:renehiemstra/EmptyTestRepo.git")
    local t12 = Pkg.validemptygitrepo("git@github.com:renehiemstra/EmptyTestRepo.gi")
    local t13 = Pkg.validemptygitrepo("git@github.com:terralang/terra.git")
    test t11 and not t12 and not t13

    local t14 = Pkg.validnonemptygitrepo("git@github.com:terralang/terra.git")
    local t15 = Pkg.validnonemptygitrepo("git@github.com:terralang/terra.gi")
    local t16 = Pkg.validnonemptygitrepo("git@github.com:renehiemstra/EmptyTestRepo.git")
    test t14 and not t15 and not t16
end

end --testenv

return Pkg
