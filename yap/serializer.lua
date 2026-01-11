local Serializer = {}
Serializer.__index = Serializer

function Serializer.new(state, history)
  local self = setmetatable({}, Serializer)
  self.state = state
  self.history = history
  return self
end

function Serializer:serialize()
  return {
    version = 1,
    state = self.state:getAll(),
    history = self.history:getAll()
  }
end

function Serializer:deserialize(data)
  if not data then return false, "No data provided" end
  if data.state then self.state:loadAll(data.state) end
  if data.history then self.history:loadAll(data.history) end
  return true
end

function Serializer:clear()
  self.state:clear()
  self.history:clear()
end

return Serializer
