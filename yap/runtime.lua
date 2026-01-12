local PATH = (...):match("(.-)[^%.]+$") or ""
local Eval = require(PATH .. "eval")

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

  for id, props in pairs(ast.characters) do
    if not self.characters:has(id) then
      self.characters:register(id, props)
    end
  end

  for name, func in pairs(ast.functions) do
    if not self.functions:has(name) then
      self.functions:register(name, func.body)
    end
  end
end

function Runtime:jumpTo(labelName)
  if not self.ast or not self.ast.labels then
    return false
  end
  local labelIndex = self.ast.labels[labelName]
  if labelIndex then
    self.position = labelIndex
    self.waitingForChoice = false
    self.complete = false
    self.history:markSeen(labelName)
    return true
  end
  return false
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

function Runtime:evalCondition(condition)
  if not condition then return true end
  return self.evaluator:evaluate(condition) and true or false
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
      metadata = node.metadata or {}
    }
    self.signals:emit("on_line_start", data)
    return data

  elseif node.type == "set" then
    local value = self.evaluator:evaluate(node.expression)
    local oldValue = self.state:get(node.variable)
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

  elseif node.type == "jump" then
    self:jumpTo(node.target)
    return self:processNode()

  elseif node.type == "call" then
    local func = self.functions:get(node.name)
    if func then
      table.insert(self.callStack, { nodes = self.nodes, position = self.position })
      self.nodes = func.body
      self.position = 0
    end
    return nil

  elseif node.type == "if_block" then
    for _, branch in ipairs(node.branches) do
      if branch.condition == nil or self:evalCondition(branch.condition) then
        if #branch.nodes > 0 then
          table.insert(self.callStack, { nodes = self.nodes, position = self.position })
          self.nodes = branch.nodes
          self.position = 0
        end
        return nil
      end
    end
    return nil

  elseif node.type == "once_block" then
    if not self.history:hasSeen(node.id) then
      self.history:markSeen(node.id)
      if #node.nodes > 0 then
        table.insert(self.callStack, { nodes = self.nodes, position = self.position })
        self.nodes = node.nodes
        self.position = 0
      end
    end
    return nil

  elseif node.type == "random_block" then
    local totalWeight = 0
    for _, option in ipairs(node.options) do
      totalWeight = totalWeight + (option.weight or 1)
    end

    local roll = math.random() * totalWeight
    local cumulative = 0
    local selected = nil

    for _, option in ipairs(node.options) do
      cumulative = cumulative + (option.weight or 1)
      if roll <= cumulative then
        selected = option
        break
      end
    end

    if selected and selected.dialogue then
      local char = self.characters:get(selected.dialogue.character)
      local data = {
        type = "dialogue",
        character = selected.dialogue.character,
        character_name = char and char.name or selected.dialogue.character,
        text = self:replaceVars(selected.dialogue.text),
        portrait_row = selected.dialogue.portrait_row or 0,
        portrait_col = selected.dialogue.portrait_col or 0,
        metadata = selected.dialogue.metadata or {}
      }
      self.signals:emit("on_line_start", data)
      return data
    end
    return nil

  elseif node.type == "choice_block" then
    local validChoices = {}
    for idx, option in ipairs(node.options) do
      if not option.condition or self:evalCondition(option.condition) then
        table.insert(validChoices, {
          index = idx,
          text = self:replaceVars(option.text),
          target = option.target
        })
      end
    end

    if #validChoices > 0 then
      self.waitingForChoice = true
      self.currentChoices = { options = validChoices, originalOptions = node.options }
      self.signals:emit("on_choice_presented", validChoices)
      return { type = "choice", choices = validChoices }
    end
    return nil
  end

  return nil
end

function Runtime:advance()
  if self.complete then return nil end
  if self.waitingForChoice then
    return { type = "choice", choices = self.currentChoices.options }
  end

  if self.position > 0 and self.position <= #self.nodes then
    local prevNode = self.nodes[self.position]
    if prevNode.type == "dialogue" then
      self.signals:emit("on_line_end", { character = prevNode.character })
    end
  end

  self.position = self.position + 1

  while self.position > #self.nodes do
    if #self.callStack > 0 then
      local context = table.remove(self.callStack)
      self.nodes = context.nodes
      self.position = context.position + 1
    else
      self.complete = true
      self.signals:emit("on_dialogue_end", {})
      return nil
    end
  end

  local data = self:processNode()

  while data == nil and not self.complete and not self.waitingForChoice do
    self.position = self.position + 1
    while self.position > #self.nodes do
      if #self.callStack > 0 then
        local context = table.remove(self.callStack)
        self.nodes = context.nodes
        self.position = context.position + 1
      else
        self.complete = true
        self.signals:emit("on_dialogue_end", {})
        return nil
      end
    end
    data = self:processNode()
  end

  return data
end

function Runtime:choose(choiceIndex)
  if not self.waitingForChoice or not self.currentChoices then return nil end

  local validChoices = self.currentChoices.options
  if choiceIndex < 1 or choiceIndex > #validChoices then return nil end

  local chosen = validChoices[choiceIndex]
  self.signals:emit("on_choice_made", {
    index = choiceIndex,
    text = chosen.text,
    target = chosen.target
  })

  self.waitingForChoice = false
  self.currentChoices = nil

  if chosen.target then
    self:jumpTo(chosen.target)
    return self:advance()
  end
  return self:advance()
end

function Runtime:isWaitingForChoice()
  return self.waitingForChoice
end

function Runtime:isComplete()
  return self.complete
end

function Runtime:getCurrentChoices()
  if self.waitingForChoice and self.currentChoices then
    return self.currentChoices.options
  end
  return nil
end

function Runtime:reset()
  self.position = 0
  self.waitingForChoice = false
  self.currentChoices = nil
  self.complete = false
  self.callStack = {}
end

return Runtime
