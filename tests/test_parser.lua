package.path = package.path .. ";./yap/?.lua"

local Parser = require("parser")

love = { filesystem = { read = function(path)
    local f = io.open(path, "r")
    if not f then return nil, "file not found: " .. path end
    local content = f:read("*a")
    f:close()
    return content
end }}

local function dump(t, indent)
    indent = indent or 0
    local prefix = string.rep("  ", indent)
    if type(t) ~= "table" then
        print(prefix .. tostring(t))
        return
    end
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(prefix .. tostring(k) .. ":")
            dump(v, indent + 1)
        else
            print(prefix .. tostring(k) .. " = " .. tostring(v))
        end
    end
end

local parser = Parser.new()
local ast, err = parser:parseFile("tests/test.yap", "")

if err then
    print("ERROR: " .. err)
    os.exit(1)
else
    print("Parsed successfully!\n")
    dump(ast)
end
