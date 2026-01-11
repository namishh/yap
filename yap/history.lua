local History = {}
History.__index = History

function History.new()
  local self = setmetatable({}, History)
  self.seen = {}
  self.visitCounts = {}
  return self
end

function History:markSeen(id)
  self.seen[id] = true
  self.visitCounts[id] = (self.visitCounts[id] or 0) + 1
end

function History:hasSeen(id)
  return self.seen[id] == true
end

function History:getVisitCount(id)
  return self.visitCounts[id] or 0
end

function History:getAll()
  local result = { seen = {}, visitCounts = {} }
  for id in pairs(self.seen) do
      table.insert(result.seen, id)
  end
  for id, count in pairs(self.visitCounts) do
      result.visitCounts[id] = count
  end
  return result
end

function History:loadAll(data)
  if data.seen then
    for _, id in ipairs(data.seen) do
      self.seen[id] = true
    end
  end
  if data.visitCounts then
    for id, count in pairs(data.visitCounts) do
      self.visitCounts[id] = count
    end
  end
end

function History:clear()
  self.seen = {}
  self.visitCounts = {}
end

function History:forget(id)
  self.seen[id] = nil
  self.visitCounts[id] = nil
end

return History
