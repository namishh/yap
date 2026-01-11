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
