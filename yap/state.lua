local State = {}
State.__index = State

function State.new()
  local self = setmetatable({}, State)
  self.variables = {}

  return self
end

function State:set(name, value)
  self.variables[name] = value
end

function State:get(name)
  return self.variables[name]
end

function State:has(name)
  return self.variables[name] ~= nil
end

function State:getAll()
  local copy = {}
  for k, v in pairs(self.variables) do
      copy[k] = v
  end
  return copy
end

function State:loadAll(data)
  for k, v in pairs(data) do
      self.variables[k] = v
  end
end

function State:clear()
  self.variables = {}
end

return State
