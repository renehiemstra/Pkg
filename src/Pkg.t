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
Pkg.terrahome = Pkg.capturestdout("echo $TERRA_PKG_ROOT")
 
--create a universal unique identifier (uuid)
function Pkg.uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c) 
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

function Pkg.save(proj, root)
    if type(proj) == "table" then
	--open Project.t and set to stdout
	local file = io.open(root.."/Project.t", "w")
	io.output(file)

	--write main project data to file
	io.write("Project = {\n")
	io.write(string.format("  name = %q,\n", proj.name))
	io.write(string.format("  uuid = %q,\n", proj.uuid)) 
    	-- write author list
	io.write("  ", "authors = {")
	for k,v in pairs(proj.authors) do
	    io.write(string.format("%q, ", v)) 
	end
 	io.write("}, \n")
	--write version
	io.write(string.format("  version = %q,\n", proj.version)) 
	--write dependencies
	io.write("  ", "deps = {\n")
	for k,v in pairs(proj.deps) do
	    io.write(string.format("    %q,\n", v))
	end
	io.write("  }\n")
	io.write("}\n")
	io.write("return Project")

	--close file
	io.close(file)
    else
	error("provide a table")
    end
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

function Pkg.isfile(file)
    local exitcode = Pkg.capturestdout("test -f "..file.."; echo $?")
    return exitcode=="0"
end

function Pkg.isfolder(folder)
    local exitcode = Pkg.capturestdout("test -d "..folder.."; echo $?")
    return exitcode=="0"
end

function Pkg.ispkg(root)
    local pkgname = Pkg.capturestdout("cd "..root.."; echo \"${PWD##*/}\"")
    local c1 = Pkg.isfile(root.."/Project.t")
    local c2 = Pkg.isfile(root.."/src/"..pkgname..".t")
    return c1 and c2
end

function Pkg.getfileextension(file)
    return file:match "[^.]+$"
end

--clone a git-remote terra package. throw an error if input is invalid.
function Pkg.clone(args)
    --check keyword arguments
    if args.root==nil or args.url==nil then
	error("provide `root` and git `url`.\n")
    end
    if type(args.root)~="string" then
        error("provide `root` folder\n")
    elseif type(args.url)~="string" then 
        error("provide git `url`\n")
    end

    --throw an error if repo is not valid
    if not Pkg.validnonemptygitrepo(args.url) then
        error("Provide a non-empty git repository\n")
    end
    --clone remote repo 
    os.execute("mkdir -p "..args.root..";"..
        "cd "..args.root..";"..
        "git clone "..args.url)
       
    --check that cloned repo satisfies basic package structure
    local pkgname = Pkg.namefromgiturl(args.url)          
    if not Pkg.ispkg(args.root.."/"..pkgname) then
        --remove terra cloned repo 
        os.execute("cd "..args.root..";".."rm -rf "..pkgname)  
        --throw error
        error("Cloned repository does not have the structure of a terra pkg.")
    end
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
    local file = io.open(pkgname.."/Project.t", "w")
    file:write("Project = {\n")
    file:write("    name = \""..pkgname.."\",\n")
    file:write("    uuid = \""..Pkg.uuid().."\",\n")
    file:write("    authors = {\""..Pkg.user.name.."<"..Pkg.user.email..">".."\"},\n")
    file:write("    version = \"".."0.1.0".."\",\n")
    file:write("    deps = {}\n")
    file:write("}\n")
    file:write("return Project")
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

testset "read / write project file" do
    local table1 = require("Example/Project")
    Pkg.save(table1, ".")
    local table2 = require("Pkg/src/Project")
    
    local t1 = table1.name == "Example" and table2.name=="Example"
    test t1
    
    local t2 = table1.uuid == table2.uuid
    test t2

    os.execute("rm Project.t") 
end

testset "validate terra pkg" do

    local t1 = Pkg.getfileextension("hello.t")=="t"
    local t2 = Pkg.getfileextension("Project.toml")=="toml"
    test t1 and t2

    local t3 = Pkg.isfile("./Pkg.t")
    test t3 

    local t4 = Pkg.isfolder(".")
    test t4

    local t5 = Pkg.ispkg(Pkg.terrahome.."/dev/Pkg")
    test t5

    Pkg.create("MyPackage")
    local t6 = Pkg.ispkg("./MyPackage")
    test t6
    os.execute("rm -rf ./MyPackage")
end


testset "get repo name from url" do
    local t1 = Pkg.namefromgiturl("git@gitlab.com:group/subgroup/MyPackage.git")
    test t1=="MyPackage"
 
    local t2 = Pkg.namefromgiturl("https://gitlab.com/group/subgroup/MyPackage.git") 
    test t2=="MyPackage"
 
    local t3 = Pkg.namefromgiturl("git@gitlab.com:group/subgroup/MyPackage.git") 
    test t3=="MyPackage" 
 
    local t4 = Pkg.namefromgiturl("https://github.com/group/subgroup/MyPackage.git")
    test t4=="MyPackage"   
end

--[[
testset "validate git remote repo url" do
    local t1 = Pkg.validgitrepo("git@github.com:terralang/terra.git")
    local t2 = Pkg.validgitrepo("git@github.com:terralang/terra.gi")     
    test t1 and not t2
    
    local t3 = Pkg.validemptygitrepo("git@github.com:renehiemstra/EmptyTestRepo.git")
    local t4 = Pkg.validemptygitrepo("git@github.com:renehiemstra/EmptyTestRepo.gi")
    local t5 = Pkg.validemptygitrepo("git@github.com:terralang/terra.git")
    test t3 and not t4 and not t5

    local t6 = Pkg.validnonemptygitrepo("git@github.com:terralang/terra.git")
    local t7 = Pkg.validnonemptygitrepo("git@github.com:terralang/terra.gi")
    local t8 = Pkg.validnonemptygitrepo("git@github.com:renehiemstra/EmptyTestRepo.git")
    test t6 and not t7 and not t8
end]]

testset "clone package" do
    os.execute("rm -rf Pkg")
    local status, err = pcall(Pkg.clone, {root=".", url="git@github.com:renehiemstra/Pkg.git"})
    test status
    os.execute("rm -rf Pkg")
end

end --testenv

return Pkg
