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


end
