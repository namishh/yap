local Eval = require("yap.eval")

local Runtime = {}
Runtime.__index = Runtime

function Runtime.new(signals, state, history, characters, functions)
  local self = setmetatable({}, Runtime)
  self.signals = signals
  self.state = state
  self.history = history
  self.characters = characters
  self.functions = functions
  self.evaluator = Eval.new(state)

  self.ast = nil
  self.nodes = {}
  self.position = 0
  self.waitingForChoice = false
  self.currentChoices = nil
  self.complete = false
  self.callStack = {}
  return self
end

-- loading an AST 
function Runtime:load(ast)
    self.ast = ast
    self.nodes = ast.nodes
    self.position = 0
    self.waitingForChoice = false
    self.currentChoices = nil
    self.complete = false
    self.callStack = {}

    for name, value in pairs(ast.variables) do
      if not self.state:has(name) then
        self.state:set(name, value)
      end
    end
end

function Runtime:replaceVars(text)
  if not text then return "" end
  return text:gsub("{([%w_]+)}", function(varName)
    local value = self.state:get(varName)
    if value ~= nil then
      return tostring(value)
    end
    return "{" .. varName .. "}"
  end)
end

function Runtime:processNode()
  if self.position < 1 or self.position > #self.nodes then
    return nil
  end

  local node = self.nodes[self.position]
  if node.type == "label" then
    return nil
  elseif node.type == "dialogue" then
    local char = self.characters:get(node.character)
    local data = {
      type = "dialogue",
      character = node.character,
      character_name = char and char.name or node.character,
      text = self:replaceVars(node.text),
      portrait_row = node.portrait_row or 0,
      portrait_col = node.portrait_col or 0,
      duration = node.duration
    }
    self.signals:emit("on_line_start", data)
    return data
  elseif node.type == "set" then
    local value = self.evaluator:evaluate(node.expression)
    local oldValue = self.state:get(node.value)
    self.state:set(node.variable, value)
    self.signals:emit("on_var_changed", {
      variable = node.variable,
      oldValue = oldValue,
      newValue = value
    })
    return nil
  elseif node.type == "emit" then
      self.signals:emit(node.event, node.params)
      return nil
  end
end
