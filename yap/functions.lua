local Functions = {}
Functions.__index = Functions

function Functions.new()
  local self = setmetatable({}, Functions)
  return self
end

function Functions:register(name, nodes)
  self.functions[name] = { name = name, body = nodes }
end

function Functions:get(name)
  return self.functions[name]
end

function Functions:has(name)
  return self.functions[name] ~= nil
end

function Functions:getAllNames()
  local names = {}
  for name in pairs(self.functions) do
    table.insert(names, name)
  end
  return names
end

function Functions:clear()
  self.functions = {}
end

return Functions
