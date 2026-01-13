local Signals = {}
Signals.__index = Signals

function Signals.new()
  local self = setmetatable({}, Signals)
  self.listeners = {}
  return self
end

function Signals:on(event, callback)
  if not self.listeners[event] then
    self.listeners[event] = {}
  end
  table.insert(self.listeners[event], callback)
  return function ()
    self:off(event, callback)
  end
end

function Signals:off(event, callback)
  if not self.listeners[event] then return end
  for i, cb in ipairs(self.listeners[event]) do
    if cb == callback then
      table.remove(self.listeners[event], i)
      return
    end
  end
end

function Signals:emit(event, data)
  if not self.listeners[event] then return end
  for _, callback in ipairs(self.listeners[event]) do
    callback(data)
  end
end

return Signals
