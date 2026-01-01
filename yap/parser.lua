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

    local onceId = trimmed:match("^%[once%s+([%w_]+)%]$")
    if onceId then
        return {type = "once", id = onceId}
    end

    if trimmed == "[random]" then
        return {type = "random"}
    end

    if trimmed == "[choice]" then
        return {type = "choice"}
    end

    local optionMatch = trimmed:match("^%*%s*(.+)$")
    if optionMatch then
        local option = {type = "option"}
        local weight, rest = optionMatch:match("^%[weight:%s*(%d+)%]%s*(.+)$")
        if weight then
            option.weight = tonumber(weight)
            optionMatch = rest
        else
            option.weight = 1
        end
        if optionMatch:match("^@") then
            local dialogueToken = self:tokenize(optionMatch)
            if dialogueToken.type == "dialogue" then
                option.dialogue = dialogueToken
            end
        else
            local text = optionMatch:match('^"([^"]*)"') or optionMatch:match("^'([^']*)'")
            option.text = text or optionMatch
            local condition = optionMatch:match("%[if%s+([^%]]+)%]")
            if condition then
                option.condition = condition
            end
            local target = optionMatch:match("%->%s*([%w_]+)%s*$")
            if target then
                option.target = target
            end
        end
        return option
    end

    -- function call 
    -- @call function_name
    local callName = trimmed:match("^@call%s+([%w_]+)%s*$")
    if callName then
        return {type = "call", name = callName}
    end

    local charMatch = trimmed:match("^@([%w_]+)")
    if charMatch then
        local dialogue = {
            type = "dialogue",
            character = charMatch,
            portrait_row = 0,
            portrait_col = 0,
            metadata = {}
        }
        local afterChar = trimmed:sub(#charMatch + 2)
        local row, col, rest = afterChar:match("^%s*%[%s*(%d+)%s*,%s*(%d+)%s*%](.*)$")
        if row and col then
            dialogue.portrait_row = tonumber(row)
            dialogue.portrait_col = tonumber(col)
            afterChar = rest
        end
        local colonPos = afterChar:find(":")
        if colonPos then
            local textPart = afterChar:sub(colonPos + 1):match("^%s*(.+)$")
            if textPart then
                local text = textPart:match('^"([^"]*)"') or textPart:match("^'([^']*)'")
                dialogue.text = text or ""
                local metadataStr = textPart:match("%[([^%]]+)%]%s*$")
                if metadataStr then
                    for key, value in metadataStr:gmatch("([%w_]+)%s*:%s*([^,]+)") do
                        value = value:match("^%s*(.-)%s*$")
                        if value == "true" then
                            dialogue.metadata[key] = true
                        elseif value == "false" then
                            dialogue.metadata[key] = false
                        elseif tonumber(value) then
                            dialogue.metadata[key] = tonumber(value)
                        elseif value:match('^".*"$') or value:match("^'.*'$") then
                            dialogue.metadata[key] = value:sub(2, -2)
                        else
                            dialogue.metadata[key] = value
                        end
                    end
                end
            end
        end
        return dialogue
    end

    return {type = "unknown", raw = trimmed}
end

function Parser:parse(content, sourcePath, baseDir)
  local ast = {
    type = "root",
    source = sourcePath,
    imports = {},
    variables = {},
    characters = {},
    functions = {},
    labels = {},
    nodes = {}
  }

  return ast
end

function Parser:parseFile(filepath, baseDir)
    baseDir = baseDir or ""
    local fullPath = baseDir .. filepath
    if self.importedFiles[fullPath] then
        return nil, "Circular import detected: " .. fullPath
    end
    self.importedFiles[fullPath] = true
    local content, err = readFile(fullPath)
    if not content then
        return nil, err
    end
    local fileDir = getDirectory(fullPath)
    return self:parse(content, fullPath, fileDir)
end

