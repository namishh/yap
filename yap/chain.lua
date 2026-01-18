local Chain = {}
Chain.__index = Chain

function Chain.new()
  local self = setmetatable({}, Chain)
  self.labels = {}
  return self
end

function Chain:add(label)
  table.insert(self.labels, label)
  return self
end

function Chain:build()
  local builtLabels = {}
  
  for i, label in ipairs(self.labels) do
    local built = label:build()
    
    if i < #self.labels then
      local lastNode = built.nodes[#built.nodes]
      local needsJump = true
      
      if lastNode then
        if lastNode.type == "jump" or 
           lastNode.type == "choice_block" or 
           lastNode.type == "choice_block_api" or
           lastNode.type == "await" then
          needsJump = false
        end
      end
      
      if needsJump then
        local nextLabel = self.labels[i + 1]
        local nextBuilt = nextLabel:build()
        table.insert(built.nodes, {
          type = "jump",
          target = nextBuilt.name
        })
      end
    end
    
    table.insert(builtLabels, built)
  end
  
  return builtLabels
end

function Chain:getLabelNames()
  local names = {}
  for _, label in ipairs(self.labels) do
    table.insert(names, label.name)
  end
  return names
end

function Chain:getFirstLabelName()
  if #self.labels > 0 then
    return self.labels[1].name
  end
  return nil
end

return Chain

