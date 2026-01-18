local PATH = (...):match("(.-)[^%.]+$")
if PATH == "" then PATH = (...) .. "." end

local Signals = require(PATH .. "signals")
local State = require(PATH .. "state")
local History = require(PATH .. "history")
local Characters = require(PATH .. "chars")
local Functions = require(PATH .. "functions")
local Parser = require(PATH .. "parser")
local Runtime = require(PATH .. "runtime")
local Serializer = require(PATH .. "serializer")
local Label = require(PATH .. "label")
local Chain = require(PATH .. "chain")
local Cond = require(PATH .. "cond")

local Yap = {}
Yap.__index = Yap

function Yap.new()
  local self = setmetatable({}, Yap)
  self.signals = Signals.new()
  self.state = State.new()
  self.history = History.new()
  self.characters = Characters.new()
  self.functions = Functions.new()
  self.parser = Parser.new()
  self.serializer = Serializer.new(self.state, self.history)
  self.runtime = Runtime.new(self.signals, self.state, self.history, self.characters, self.functions)
  self.loadedFile = nil
  return self
end

function Yap:load(filepath)
  self.parser:reset()
  local ast, err = self.parser:parseFile(filepath)
  if not ast then return false, err end
  self.runtime:load(ast)
  self.loadedFile = filepath
  return true
end

function Yap:loadString(content, sourceName)
  self.parser:reset()
  local ast, err = self.parser:parse(content, sourceName or "<string>", "")
  if not ast then return false, err end
  self.runtime:load(ast)
  self.loadedFile = sourceName
  return true
end

function Yap:on(event, callback)
  return self.signals:on(event, callback)
end

function Yap:off(event, callback)
  self.signals:off(event, callback)
end

function Yap:emit(event, data)
  self.signals:emit(event, data)
end

function Yap:start(labelName)
  if self.runtime:jumpTo(labelName) then
    return self.runtime:advance()
  end
  return nil
end

function Yap:advance()
  return self.runtime:advance()
end

function Yap:choose(index)
  return self.runtime:choose(index)
end

function Yap:isWaitingForChoice()
  return self.runtime:isWaitingForChoice()
end

function Yap:isComplete()
  return self.runtime:isComplete()
end

function Yap:getCurrentChoices()
  return self.runtime:getCurrentChoices()
end

function Yap:reset()
  self.runtime:reset()
end

function Yap:isAwaiting()
  return self.runtime:isAwaiting()
end

function Yap:getAwaitEvent()
  return self.runtime:getAwaitEvent()
end

function Yap:pause(reason)
  self.runtime:pause(reason)
end

function Yap:resume()
  return self.runtime:resume()
end

function Yap:getVar(name)
  return self.state:get(name)
end

function Yap:setVar(name, value)
  local oldValue = self.state:get(name)
  self.state:set(name, value)
  self.signals:emit("on_var_changed", { variable = name, oldValue = oldValue, newValue = value })
end

function Yap:hasVar(name)
  return self.state:has(name)
end

function Yap:getAllVars()
  return self.state:getAll()
end

function Yap:hasSeen(id)
  return self.history:hasSeen(id)
end

function Yap:getVisitCount(id)
  return self.history:getVisitCount(id)
end

function Yap:getHistory()
  return self.history:getAll()
end

function Yap:forget(id)
  self.history:forget(id)
end

function Yap:serialize()
  return self.serializer:serialize()
end

function Yap:deserialize(data)
  return self.serializer:deserialize(data)
end

-- Programmatic API methods

-- Define a variable
function Yap:defVar(name, value)
  self.state:set(name, value)
  return self
end

-- Define a character
function Yap:defChar(id, props)
  self.characters:register(id, props)
  return self
end

-- Register a label or chain
function Yap:register(labelOrChain)
  -- Initialize AST if not exists
  if not self.runtime.ast then
    self.runtime.ast = {
      type = "root",
      source = "<api>",
      imports = {},
      variables = {},
      characters = {},
      functions = {},
      labels = {},
      nodes = {}
    }
    self.runtime.nodes = self.runtime.ast.nodes
  end

  -- Handle Chain
  if labelOrChain.build and labelOrChain.labels then
    local builtLabels = labelOrChain:build()
    for _, built in ipairs(builtLabels) do
      self:_registerBuiltLabel(built)
    end
    return self
  end

  -- Handle single Label
  local built = labelOrChain:build()
  self:_registerBuiltLabel(built)
  return self
end

-- Internal: register a built label
function Yap:_registerBuiltLabel(built)
  local ast = self.runtime.ast

  -- Register variables
  for name, value in pairs(built.variables) do
    if not self.state:has(name) then
      self.state:set(name, value)
    end
  end

  -- Register characters
  for id, props in pairs(built.characters) do
    if not self.characters:has(id) then
      self.characters:register(id, props)
    end
  end

  -- Add label node and register in labels table
  local labelNode = { type = "label", name = built.name }
  ast.labels[built.name] = #ast.nodes + 1
  table.insert(ast.nodes, labelNode)

  -- Add all nodes from the label
  for _, node in ipairs(built.nodes) do
    table.insert(ast.nodes, node)
  end
end

-- Register multiple labels/chains
function Yap:registerAll(...)
  for _, item in ipairs({...}) do
    self:register(item)
  end
  return self
end

local default = Yap.new()

return setmetatable({
  new = Yap.new,
  -- Builders
  label = Label.new,
  chain = Chain.new,
  -- Condition helpers
  eq = Cond.eq,
  neq = Cond.neq,
  gt = Cond.gt,
  gte = Cond.gte,
  lt = Cond.lt,
  lte = Cond.lte,
  is = Cond.is,
  not_ = Cond.not_,
  and_ = Cond.and_,
  or_ = Cond.or_,
}, { __index = default })
