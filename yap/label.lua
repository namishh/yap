local Label = {}
Label.__index = Label

function Label.new(name)
  local self = setmetatable({}, Label)
  self.name = name
  self.nodes = {}
  self.variables = {}
  self.characters = {}
  self._pendingIf = nil 
  return self
end

function Label:_addNode(node)
  if self._pendingIf and node.type ~= "_branch" then
    table.insert(self.nodes, self._pendingIf)
    self._pendingIf = nil
  end
  
  if node.type ~= "_branch" then
    table.insert(self.nodes, node)
  end
  return self
end

function Label:_buildNested(builderFn)
  local nested = Label.new("_nested")
  builderFn(nested)
  if nested._pendingIf then
    table.insert(nested.nodes, nested._pendingIf)
    nested._pendingIf = nil
  end
  return nested.nodes
end

function Label:say(character, text, opts)
  opts = opts or {}
  
  local portrait_row = 0
  local portrait_col = 0
  local metadata = {}
  
  if opts[1] and opts[2] and type(opts[1]) == "number" then
    portrait_row = opts[1]
    portrait_col = opts[2]
  elseif opts.portrait then
    portrait_row = opts.portrait[1] or 0
    portrait_col = opts.portrait[2] or 0
  end
  
  if opts.portrait_row then portrait_row = opts.portrait_row end
  if opts.portrait_col then portrait_col = opts.portrait_col end
  
  for k, v in pairs(opts) do
    if k ~= "portrait" and k ~= "portrait_row" and k ~= "portrait_col" and type(k) == "string" then
      metadata[k] = v
    end
  end
  
  return self:_addNode({
    type = "dialogue",
    character = character,
    text = text,
    portrait_row = portrait_row,
    portrait_col = portrait_col,
    metadata = metadata
  })
end

Label.dialogue = Label.say

function Label:jump(target)
  return self:_addNode({
    type = "jump",
    target = target
  })
end

function Label:set(variable, valueOrFn)
  return self:_addNode({
    type = "set_api",
    variable = variable,
    valueOrFn = valueOrFn
  })
end

function Label:emit(event, params)
  return self:_addNode({
    type = "emit",
    event = event,
    params = params or {}
  })
end

function Label:await(event, params)
  return self:_addNode({
    type = "await",
    event = event,
    params = params or {}
  })
end

function Label:call(funcName)
  return self:_addNode({
    type = "call",
    name = funcName
  })
end

function Label:choice(options)
  local choiceOptions = {}
  for _, opt in ipairs(options) do
    table.insert(choiceOptions, {
      text = opt.text,
      target = opt.target,
      condition = opt.cond,
      weight = opt.weight or 1
    })
  end
  return self:_addNode({
    type = "choice_block_api",
    options = choiceOptions
  })
end

function Label:random(options)
  local randomOptions = {}
  for _, opt in ipairs(options) do
    local dialogue = {
      type = "dialogue",
      character = opt.char,
      text = opt.text,
      portrait_row = opt.portrait and opt.portrait[1] or 0,
      portrait_col = opt.portrait and opt.portrait[2] or 0,
      metadata = opt.metadata or {}
    }
    table.insert(randomOptions, {
      weight = opt.weight or 1,
      dialogue = dialogue
    })
  end
  return self:_addNode({
    type = "random_block",
    options = randomOptions
  })
end

function Label:randomSeq(sequences)
  local seqOptions = {}
  for _, seq in ipairs(sequences) do
    local nodes = {}
    local weight = seq.weight or 1
    
    for _, line in ipairs(seq) do
      if type(line) == "table" and type(line[1]) == "string" then
        local char = line[1]
        local text = line[2]
        local opts = line[3] or {}
        
        local portrait_row = 0
        local portrait_col = 0
        local metadata = {}
        
        if opts.portrait then
          portrait_row = opts.portrait[1] or 0
          portrait_col = opts.portrait[2] or 0
        end
        
        for k, v in pairs(opts) do
          if k ~= "portrait" and type(k) == "string" then
            metadata[k] = v
          end
        end
        
        table.insert(nodes, {
          type = "dialogue",
          character = char,
          text = text,
          portrait_row = portrait_row,
          portrait_col = portrait_col,
          metadata = metadata
        })
      end
    end
    
    table.insert(seqOptions, {
      weight = weight,
      nodes = nodes
    })
  end
  return self:_addNode({
    type = "random_seq_block",
    options = seqOptions
  })
end

function Label:once(id, builderFn)
  local nodes = self:_buildNested(builderFn)
  return self:_addNode({
    type = "once_block",
    id = id,
    nodes = nodes
  })
end

function Label:when(condition, builderFn)
  if self._pendingIf then
    table.insert(self.nodes, self._pendingIf)
  end
  
  local nodes = self:_buildNested(builderFn)
  self._pendingIf = {
    type = "if_block_api",
    branches = {
      { condition = condition, nodes = nodes }
    }
  }
  return self
end

function Label:orWhen(condition, builderFn)
  if not self._pendingIf then
    error("orWhen() must follow when()")
  end
  
  local nodes = self:_buildNested(builderFn)
  table.insert(self._pendingIf.branches, {
    condition = condition,
    nodes = nodes
  })
  return self
end

function Label:otherwise(builderFn)
  if not self._pendingIf then
    error("otherwise() must follow when() or orWhen()")
  end
  
  local nodes = self:_buildNested(builderFn)
  table.insert(self._pendingIf.branches, {
    condition = nil,
    nodes = nodes
  })
  
  table.insert(self.nodes, self._pendingIf)
  self._pendingIf = nil
  return self
end

function Label:defVar(name, value)
  self.variables[name] = value
  return self
end

function Label:defChar(id, props)
  self.characters[id] = props
  return self
end

function Label:build()
  if self._pendingIf then
    table.insert(self.nodes, self._pendingIf)
    self._pendingIf = nil
  end
  
  return {
    name = self.name,
    nodes = self.nodes,
    variables = self.variables,
    characters = self.characters
  }
end

return Label

