local function opPrecederence(op)
  if op == "or" then return 1 end
  if op == "and" then return 2 end
  if op == "!=" or op == "==" then return 3 end
  if op == ">" or op == "<" or op == ">=" or op == "<=" then return 4 end
  if op == "+" or op == "-" then return 5 end
  if op == "*" or op == "/" or op == "%" then return 6 end
  if op == "not" then return 7 end
  return 0
end

local function isRightAssoc(op)
  return op == "not"
end

local Evaulator = {}
Evaulator.__index = Evaulator

function Evaulator.new(state)
  local self = setmetatable({}, Evaulator)
  self.state = state
  return self
end

function Evaulator:applyOp(output, op)
  local o = op.value
  if o == "not" then
    local a = table.remove(output)
    table.insert(output, not a)
  end

  local b = table.remove(output)
  local a = table.remove(output)
  local result


  if o == "+" then result = (tonumber(a) or 0) + (tonumber(b) or 0)
  elseif o == "-" then result = (tonumber(a) or 0) - (tonumber(b) or 0)
  elseif o == "*" then result = (tonumber(a) or 0) * (tonumber(b) or 0)
  elseif o == "/" then result = (tonumber(a) or 0) / (tonumber(b) or 0)
  elseif o == "%" then result = (tonumber(a) or 0) % (tonumber(b) or 0)
  elseif o == "==" then result = a == b
  elseif o == "!=" then result = a ~= b
  elseif o == ">" then result = (tonumber(a) or 0) > (tonumber(b) or 0)
  elseif o == "<" then result = (tonumber(a) or 0) < (tonumber(b) or 0)
  elseif o == ">=" then result = (tonumber(a) or 0) >= (tonumber(b) or 0)
  elseif o == "<=" then result = (tonumber(a) or 0) <= (tonumber(b) or 0)
  elseif o == "and" then result = a and b
  elseif o == "or" then result = a or b
  end

  table.insert(output, result)
end

function Evaulator:tokenize(expr)
  local tokens = {}
  local i = 1
  local len = #expr

  while i<= len do
    local char = expr:sub(i, i)
    if char:match("%s") then
      i = i + 1
    elseif char:match("%d") or (char == "." and expr:sub(i+1, i+1):match("%d")) then
      local num = ""
      while i <= len and expr:sub(i,i):match("[%d%.]") do
        num = num .. expr:sub(i,i)
        i = i + 1
      end
      table.insert(tokens, {type="number", value = tonumber(num)})
    elseif char == '"' or char == "'" then
      local quote = char
      i = i + 1
      local str = ""
      while i <= len and expr:sub(i, i) ~= quote do
          str = str .. expr:sub(i, i)
          i = i + 1
      end
      i = i + 1
      table.insert(tokens, {type = "string", value = str})
    elseif char == "=" and expr:sub(i+1, i+1) == "=" then
      table.insert(tokens, {type = "operator", value="=="})
      i = i + 2
    elseif char == "!" and expr:sub(i+1, i+1) == "=" then
      table.insert(tokens, {type = "operator", value = "!="})
      i = i + 2
    elseif char == ">" and expr:sub(i+1, i+1) == "=" then
      table.insert(tokens, {type = "operator", value = ">="})
      i = i + 2
    elseif char == "<" and expr:sub(i+1, i+1) == "=" then
      table.insert(tokens, {type = "operator", value = "<="})
      i = i + 2
    elseif char:match("[+%-*/%%(%)><=]") then
      table.insert(tokens, {type = "operator", value = char})
      i = i + 1
    elseif char == "," then
      table.insert(tokens, {type == "comma", value = ","})
    elseif char:match("[%a_]") then
      local ident = ""
      while i <= len and expr:sub(i,i):match("[%w_]") do
        ident = ident .. expr:sub(i,i)
        i=i+1
      end
      if ident == "true" then
        table.insert(tokens, {type = "boolean", value = true})
      elseif ident == "false" then
        table.insert(tokens, {type = "boolean", value = false})
      elseif ident == "and" or ident == "or" or ident == "not" then
        table.insert(tokens, {type = "operator", value = ident})
      elseif ident == "random" then
        table.insert(tokens, {type = "function", value = ident})
      else
        table.insert(tokens, {type = "identifier", value = ident})
      end
    else
      i = i + 1
    end
  end
  return tokens
end

function Evaulator:evaluate(expr)
  local tokens = self:tokenize(expr) or {}
  local output = {}
  local operators = {}

  local i = 1
  while i <= #tokens do
    local token = tokens[i]
    if token.type == "number" or token.type == "string" or token.type == "boolean" then
      table.insert(output, token.value)
    elseif token.type == "identifier" then
      local value = self.state:get(token.value)
      table.insert(output, value ~= nil and value or false)
    elseif token.type == "function" then
      if token.value == 'random' then
        i = i + 1
        if tokens[i] and tokens[i].value == "(" then
          i = i + 1
          local args = {}
          while tokens[i] and tokens[i].value ~= ")" do
              if tokens[i].type == "number" then
                  table.insert(args, tokens[i].value)
              elseif tokens[i].type == "identifier" then
                  table.insert(args, self.state:get(tokens[i].value) or 0)
              end
              i = i + 1
              if tokens[i] and tokens[i].type == "comma" then i = i + 1 end
          end
          local min, max = args[1] or 0, args[2] or 1
          table.insert(output, math.floor(math.random() * (max - min + 1)) + min)
        end
      end
    elseif token.type == "operator" then
      if token.value == "(" then
        table.insert(operators, token)
      elseif token.value == ")" then
        while #operators > 0 and operators[#operators].value ~= "(" do
            self:applyOp(output, table.remove(operators))
        end
        table.remove(operators)
      elseif token.value == "not" then
          table.insert(operators, token)
      else
        while #operators > 0
            and operators[#operators].value ~= "("
            and (opPrecederence(operators[#operators].value) > opPrecederence(token.value)
                 or (opPrecederence(operators[#operators].value) == opPrecederence(token.value)
                     and not isRightAssoc(token.value))) do
            self:applyOp(output, table.remove(operators))
        end
        table.insert(operators, token)
      end
    end

    i = i + 1
  end

  while #operators > 0 do
      self:applyOp(output, table.remove(operators))
  end
  return output[1]

end

return Evaulator
