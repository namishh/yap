package.path = package.path .. ";./yap/?.lua;./tests/testing.lua"

local Evaluator = require("eval")
local State = require("state")

local testing = require("testing")

local T = testing.new()
local function test(name, fn) T:test(name, fn) end

local function createEvaluate()
  local state = State.new()  
  local eval = Evaluator.new(state)

  eval = setmetatable({ state = state }, Evaluator)
  return eval, state 
end

test("tokenize numbers", function()
  local eval = createEvaluate()
  local tokens = eval:tokenize("42") or {}
  T.assertNotNil(tokens, "tokens should not be nil")
  T.assertsEqual(1, #tokens, "should have 1 token")
  T.assertsEqual("number", tokens[1].type)
  T.assertsEqual(42, tokens[1].value)
end)

test("tokenize decimals", function()
  local eval = createEvaluate()
  local tokens = eval:tokenize("3.14") or {}
  T.assertsEqual("number", tokens[1].type)
  T.assertsEqual(3.14, tokens[1].value)
end)

test("tokenize strings", function ()
  local eval = createEvaluate()
  local tokens = eval:tokenize("\"hello\" 'world'")
  T.assertsEqual("string", tokens[1].type)
  T.assertsEqual("hello", tokens[1].value)

  T.assertsEqual("string", tokens[2].type)
  T.assertsEqual("world", tokens[2].value)
end)

test("tokenize booleans", function ()
  local eval = createEvaluate()
  local tokens = eval:tokenize("false true")
  T.assertsEqual("boolean", tokens[1].type)
  T.assertsEqual(false, tokens[1].value)

  T.assertsEqual("boolean", tokens[2].type)
  T.assertsEqual(true, tokens[2].value)
end)


-- Evaluate tests
test("addition", function ()
  local eval = createEvaluate()
  local res = eval:evaluate("34 + 33")
  T.assertsEqual(67, res)
end)
