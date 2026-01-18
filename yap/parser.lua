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

    -- await statement (emit + wait for resume)
    -- await event_name { params }
    local awaitEvent, awaitParams = trimmed:match("^await%s+([%w_]+)%s*{([^}]*)}%s*$")
    if awaitEvent then
        local params = {}
        for key, value in awaitParams:gmatch("([%w_]+)%s*:%s*([^,}]+)") do
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
        return {type = "await", event = awaitEvent, params = params}
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

    local seqOptionMatch = trimmed:match("^%*:%s*(.*)$")
    if seqOptionMatch then
        local option = {type = "seq_option_start"}
        local weight = seqOptionMatch:match("^%[weight:%s*(%d+)%]")
        option.weight = weight and tonumber(weight) or 1
        return option
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

  local lines = {}
  for line in content:gmatch("([^\n]*)\n?") do
      table.insert(lines, line)
  end

  local i = 1
  local currCharacter = nil
  local currFunction = nil

  local blockStack = {}

  local function getCurrentNodes()
      if #blockStack > 0 then
          return blockStack[#blockStack].nodes
      elseif currFunction then
          return currFunction.body
      else
          return ast.nodes
      end
  end

  while i <= #lines do
    local line = lines[i]
    local token = self:tokenize(line)
    token.line = i
    token.source = sourcePath

    if token.type == "empty" then
      -- do nothing
    elseif token.type == "import" then
      local importedAst, importErr = self:parseFile(token.path, baseDir)
      if not importedAst then
          return nil, sourcePath .. ":" .. i .. ": " .. (importErr or "Import failed")
      end
      table.insert(ast.imports, token.path)
      for k, v in pairs(importedAst.variables) do ast.variables[k] = v end
      for k, v in pairs(importedAst.characters) do ast.characters[k] = v end
      for k, v in pairs(importedAst.functions) do ast.functions[k] = v end
      for k, v in pairs(importedAst.labels) do ast.labels[k] = v end
    elseif token.type == "var_def" then
      local value = token.value
      if value == "true" then value = true
      elseif value == "false" then value = false
      elseif tonumber(value) then value = tonumber(value)
      elseif value:match('^".*"$') or value:match("^'.*'$") then
          value = value:sub(2, -2)
      end
      ast.variables[token.name] = value

    elseif token.type == "function_start" then
      currFunction = { name = token.name, body = {} }
      currCharacter = nil
    elseif token.type == "block_end" then
      if currFunction then
          ast.functions[currFunction.name] = currFunction
          currFunction = nil
      end
    elseif token.type == "label" then
      currCharacter = nil
      local labelNode = { type = "label", name = token.name, line = i, source = sourcePath }
      ast.labels[token.name] = #ast.nodes + 1
      table.insert(getCurrentNodes(), labelNode)
    elseif token.type == "character_start" then
      if currCharacter then
        ast.characters[currCharacter.id] = currCharacter.properties
      end
      currCharacter = { id = token.id, properties = {} }
    elseif token.type == "character_prop" then
      if currCharacter then
        local value = token.value
          if token.name == "spritesheet" then
              local path, w, h, rows, cols = value:match('%[%s*"([^"]+)"%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%]')
              if path then
                  value = {path, tonumber(w), tonumber(h), tonumber(rows), tonumber(cols)}
              end
          elseif tonumber(value) then
              value = tonumber(value)
          elseif value:match('^".*"$') or value:match("^'.*'$") then
              value = value:sub(2, -2)
          end
          currCharacter.properties[token.name] = value
      end
    elseif token.type == "if" then
      currCharacter = nil
      local ifBlock = { type = "if_block", branches = {{ condition = token.condition, nodes = {} }}, line = i }
      table.insert(getCurrentNodes(), ifBlock)
      table.insert(blockStack, {type = "if", block = ifBlock, nodes = ifBlock.branches[1].nodes})
    elseif token.type == "elseif" then
      if #blockStack > 0 and blockStack[#blockStack].type == "if" then
          local ifBlock = blockStack[#blockStack].block
          local newBranch = {condition = token.condition, nodes = {}}
          table.insert(ifBlock.branches, newBranch)
          blockStack[#blockStack].nodes = newBranch.nodes
      end
    elseif token.type == "else" then
      if #blockStack > 0 and blockStack[#blockStack].type == "if" then
          local ifBlock = blockStack[#blockStack].block
          local elseBranch = {condition = nil, nodes = {}}
          table.insert(ifBlock.branches, elseBranch)
          blockStack[#blockStack].nodes = elseBranch.nodes
      end
    elseif token.type == "end" then
      if #blockStack > 0 then
          local current = blockStack[#blockStack]
          if current.type == "random" and current.seqNodes then
              table.insert(current.block.options, {
                  weight = current.seqWeight,
                  nodes = current.seqNodes,
                  line = current.seqLine
              })
              current.seqNodes = nil
          end
          table.remove(blockStack)
      end
    elseif token.type == "once" then
      currCharacter = nil
      local onceBlock = { type = "once_block", id = token.id, nodes = {}, line = i }
      table.insert(getCurrentNodes(), onceBlock)
      table.insert(blockStack, {type = "once", block = onceBlock, nodes = onceBlock.nodes})
    elseif token.type == "random" then
      currCharacter = nil
      local randomBlock = { type = "random_block", options = {}, line = i }
      table.insert(getCurrentNodes(), randomBlock)
      table.insert(blockStack, {type = "random", block = randomBlock, nodes = randomBlock.options})
    elseif token.type == "choice" then
      currCharacter = nil
      local choiceBlock = { type = "choice_block", options = {}, line = i }
      table.insert(getCurrentNodes(), choiceBlock)
      table.insert(blockStack, {type = "choice", block = choiceBlock, nodes = choiceBlock.options})
    elseif token.type == "seq_option_start" then
      if #blockStack > 0 then
        local current = blockStack[#blockStack]
        if current.type == "random" then
            if current.seqNodes then
                table.insert(current.block.options, {
                    weight = current.seqWeight,
                    nodes = current.seqNodes,
                    line = current.seqLine
                })
            end
            current.seqNodes = {}
            current.seqWeight = token.weight
            current.seqLine = i
            current.nodes = current.seqNodes
        end
      end
    elseif token.type == "option" then
      if #blockStack > 0 then
        local current = blockStack[#blockStack]
        if current.type == "random" then
            if current.seqNodes then
                table.insert(current.block.options, {
                    weight = current.seqWeight,
                    nodes = current.seqNodes,
                    line = current.seqLine
                })
                current.seqNodes = nil
                current.seqWeight = nil
                current.seqLine = nil
                current.nodes = current.block.options
            end
            table.insert(current.block.options, {
                weight = token.weight,
                dialogue = token.dialogue,
                line = i
            })
        elseif current.type == "choice" then
            table.insert(current.block.options, {
                text = token.text,
                condition = token.condition,
                target = token.target,
                weight = token.weight,
                line = i
            })
        end
      end
    elseif token.type == "dialogue" then
      currCharacter = nil
      table.insert(getCurrentNodes(), token)
    elseif token.type == "set" then
      currCharacter = nil
      table.insert(getCurrentNodes(), token)
    elseif token.type == "emit" then
      currCharacter = nil
      table.insert(getCurrentNodes(), token)
    elseif token.type == "await" then
      currCharacter = nil
      table.insert(getCurrentNodes(), token)
    elseif token.type == "jump" then
      currCharacter = nil
      table.insert(getCurrentNodes(), token)
    elseif token.type == "call" then
        currCharacter = nil
        table.insert(getCurrentNodes(), token)
    end

    if currCharacter and token.type ~= "character_start" and token.type ~= "character_prop" and token.type ~= "empty" then
            ast.characters[currCharacter.id] = currCharacter.properties
            currCharacter = nil
     end

    i = i + 1
  end

  if currCharacter then
    ast.characters[currCharacter.id] = currCharacter.properties
  end

  return ast
end

function Parser:reset()
  self.importedFiles = {}
end

return Parser