


local function opPrecederence(op)
  if op == "or" then return 1 end
  if op == "and" then return 2 end
  if op == "!=" or op == "==" then return 3 end
  if op == ">" or op == "<" or op == ">=" or op == "<=" then return 4 end
  if op == "+" or op == "-" then return 5 end
  if op == "*" or op == "/" or op == "%" then return 6 end
  if op == "not" then return 7 end
  return 0
end

local  
