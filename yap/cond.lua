local Cond = {}

function Cond.eq(varName, value)
  return function(state)
    return state[varName] == value
  end
end

function Cond.neq(varName, value)
  return function(state)
    return state[varName] ~= value
  end
end

function Cond.gt(varName, value)
  return function(state)
    return (state[varName] or 0) > value
  end
end

function Cond.gte(varName, value)
  return function(state)
    return (state[varName] or 0) >= value
  end
end

function Cond.lt(varName, value)
  return function(state)
    return (state[varName] or 0) < value
  end
end

function Cond.lte(varName, value)
  return function(state)
    return (state[varName] or 0) <= value
  end
end

function Cond.is(varName)
  return function(state)
    return state[varName] == true
  end
end

function Cond.not_(varName)
  return function(state)
    return not state[varName]
  end
end

function Cond.and_(...)
  local conditions = {...}
  return function(state)
    for _, cond in ipairs(conditions) do
      if type(cond) == "function" then
        if not cond(state) then return false end
      else
        if not cond then return false end
      end
    end
    return true
  end
end

function Cond.or_(...)
  local conditions = {...}
  return function(state)
    for _, cond in ipairs(conditions) do
      if type(cond) == "function" then
        if cond(state) then return true end
      else
        if cond then return true end
      end
    end
    return false
  end
end

return Cond

