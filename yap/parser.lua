local Parser = {}
Parser.__index = Parser

function Parser.new()
    local self = setmetatable({}, Parser)
    self.importedFiles = {} -- check if there is any circular dependency
    return self
end

local function readFile(filepath)
    local success, content = pcall(love.filesystem.read, filepath)
    if not success then
        return nil, "Could not open file: " .. filepath .. " (" .. content .. ")"
    end
    return content
end

local function getDirectory(filepath)
    return filepath:match("(.*/)")  or ""
end

-- See man this is supposed to be a side project for a side project.
-- I am NOT making my own lexer and tokenizer
-- String pattern matching ftw
function Parser:tokenize(line)
  local trimmed = line:match("^%s*(.-)%s*$")

  -- comments or an empty line
  if trimmed == "" or trimmed:match("^%-%-") then
    return {type = "empty"}
  end
  
  -- import syntax
  -- usage:
  -- @import "file.yap"
  local importPath = trimmed:match('^@import%s+"([^"]+)"') or trimmed:match("^@import%s+'([^']+)'")
  if importPath then
      return {type = "import", path = importPath}
  end
  
  -- variables
  -- usage:
  -- @var name = "Alice"
  local varName, varValue = trimmed:match("^@var%s+([%w_]+)%s*=%s*(.+)$")
  if varName then
      return {type = "var_def", name = varName, value = varValue}
  end

  -- character:
  -- usage
  -- @character "mc":
  --  name: "Alice"
  local charId = trimmed:match("^@character%s+([%w_]+)%s*$")
  if charId then
      return {type = "character_start", id = charId}
  end

  if line:match("^%s+") then
      local propName, propValue = trimmed:match("^([%w_]+):%s*(.+)$")
      if propName then
          return {type = "character_prop", name = propName, value = propValue}
      end
  end

  -- function and end funciton
  -- usage
  -- @function add:
  -- @end
  local functionName = trimmed:match("^@function%s+([%w_]+)%s*$")
  if functionName then
    return {type = "function_start", name = functionName}
  end

  if trimmed == "@end" then
        return {type = "block_end"}
  end

  -- a label -> defining a goto block 
  -- for example
  -- # say_hello
  -- -- block of stuff
  --
  -- -> say_hello

    local labelName = trimmed:match("^#%s*([%w_]+)%s*$")
    if labelName then
        return {type = "label", name = labelName}
    end

    local jumpTarget = trimmed:match("^%->%s*([%w_]+)%s*$")
    if jumpTarget then
        return {type = "jump", target = jumpTarget}
    end
 
  -- conditionals.
  -- [if shop_open]
  --   @call greet_player
  --   -> shop_menu
  -- [else]
  --   @call shop_closed
  --   -> exit
  -- [end]

    local ifCondition = trimmed:match("^%[if%s+(.+)%]$")
    if ifCondition then
        return {type = "if", condition = ifCondition}
    end
    local elseifCondition = trimmed:match("^%[elseif%s+(.+)%]$")
    if elseifCondition then
        return {type = "elseif", condition = elseifCondition}
    end
    if trimmed == "[else]" then
        return {type = "else"}
    end
    if trimmed == "[end]" then
        return {type = "end"}
    end

    -- set statement: set var = expression
    local setVar, setExpr = trimmed:match("^set%s+([%w_]+)%s*=%s*(.+)$")
    if setVar then
        return {type = "set", variable = setVar, expression = setExpr}
    end
    
    -- emit statement
    -- emit event_name { params }
    local emitEvent, emitParams = trimmed:match("^emit%s+([%w_]+)%s*{([^}]*)}%s*$")
    if emitEvent then
        local params = {}
        for key, value in emitParams:gmatch("([%w_]+)%s*:%s*([^,}]+)") do
            value = value:match("^%s*(.-)%s*$")
            local num = tonumber(value)
            if num then
                params[key] = num
            elseif value:match('^".*"$') or value:match("^'.*'$") then
                params[key] = value:sub(2, -2)
            else
                params[key] = value
            end
        end
        return {type = "emit", event = emitEvent, params = params}
    end
    

end
