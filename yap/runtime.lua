local eval = require("eval")

local Runtime = {}
Runtime.__index = Runtime

function Runtime.new(state, characters)
    local self = setmetatable({}, Runtime)
    self.state = state
    self.characters = characters

    self.ast = nil
    self.nodes = {}
    self.position = 0
    self.waitingForChoice = nil
    self.complete = false
    self.callStack = {}
    return self
end
