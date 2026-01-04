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

test("tokenize arithmetic operators", function()
  local eval = createEvaluate()
  local tokens = eval:tokenize("1 + 2 - 3 * 4 / 5 % 6")
  T.assertsEqual(11, #tokens, "should have 11 tokens")
  T.assertsEqual("+", tokens[2].value)
  T.assertsEqual("-", tokens[4].value)
  T.assertsEqual("*", tokens[6].value)
  T.assertsEqual("/", tokens[8].value)
  T.assertsEqual("%", tokens[10].value)
end)

test("tokenize comparison operators", function()
  local eval = createEvaluate()
  local tokens = eval:tokenize("a == b")
  T.assertsEqual("==", tokens[2].value)
  tokens = eval:tokenize("a != b")
  T.assertsEqual("!=", tokens[2].value)
  tokens = eval:tokenize("a >= b")
  T.assertsEqual(">=", tokens[2].value)
  tokens = eval:tokenize("a <= b")
  T.assertsEqual("<=", tokens[2].value)
  tokens = eval:tokenize("a > b")
  T.assertsEqual(">", tokens[2].value)
  tokens = eval:tokenize("a < b")
  T.assertsEqual("<", tokens[2].value)
end)

test("tokenize logical operators", function()
  local eval = createEvaluate()
  local tokens = eval:tokenize("a and b or not c")
  T.assertsEqual("and", tokens[2].value)
  T.assertsEqual("or", tokens[4].value)
  T.assertsEqual("not", tokens[5].value)
end)


test("tokenize parentheses", function()
  local eval = createEvaluate()
  local tokens = eval:tokenize("(1 + 2)")
  T.assertsEqual("(", tokens[1].value)
  T.assertsEqual(")", tokens[5].value)
end)

test("tokenize function random", function()
  local eval = createEvaluate()
  local tokens = eval:tokenize("random(1, 10)")
  T.assertsEqual("function", tokens[1].type)
  T.assertsEqual("random", tokens[1].value)
end)

-- Evaluate tests
test("arithmetic", function()
  local eval = createEvaluate()
  T.assertsEqual(5, eval:evaluate("2 + 3"))
  T.assertsEqual(6, eval:evaluate("10 - 4"))
  T.assertsEqual(12, eval:evaluate("3 * 4"))
  T.assertsEqual(5, eval:evaluate("15 / 3"))
  T.assertsEqual(2, eval:evaluate("17 % 5"))
  T.assertsEqual(14, eval:evaluate("2 + 3 * 4"))
  T.assertsEqual(20, eval:evaluate("(2 + 3) * 4"))
end)

test("comparisons", function()
  local eval = createEvaluate()
  T.assertsEqual(true, eval:evaluate("5 == 5"))
  T.assertsEqual(false, eval:evaluate("5 == 6"))
  T.assertsEqual(true, eval:evaluate("5 != 6"))
  T.assertsEqual(true, eval:evaluate("10 > 5"))
  T.assertsEqual(false, eval:evaluate("5 > 10"))
  T.assertsEqual(true, eval:evaluate("5 < 10"))
  T.assertsEqual(true, eval:evaluate("10 >= 10"))
  T.assertsEqual(true, eval:evaluate("10 <= 10"))
end)

test("booleans", function()
  local eval = createEvaluate()
  T.assertsEqual(true, eval:evaluate("true and true"))
  T.assertsEqual(false, eval:evaluate("true and false"))
  T.assertsEqual(true, eval:evaluate("true or false"))
  T.assertsEqual(false, eval:evaluate("false or false"))
  T.assertsEqual(false, eval:evaluate("not true"))
  T.assertsEqual(true, eval:evaluate("not false"))
end)

test("strings", function()
  local eval = createEvaluate()
  T.assertsEqual("hello", eval:evaluate('"hello"'))
  T.assertsEqual(true, eval:evaluate('"foo" == "foo"'))
  T.assertsEqual(false, eval:evaluate('"foo" == "bar"'))
end)

test("variables", function()
  local eval, state = createEvaluate()
  state:set("score", 100)
  state:set("x", 10)
  state:set("health", 50)
  T.assertsEqual(100, eval:evaluate("score"))
  T.assertsEqual(15, eval:evaluate("x + 5"))
  T.assertsEqual(true, eval:evaluate("health > 25"))
  T.assertsEqual(false, eval:evaluate("undefined_var"))
end)

test("random function", function()
  local eval = createEvaluate()
  for _ = 1, 10 do
    local result = eval:evaluate("random(1, 10)")
    if result < 1 or result > 10 then
      error("random out of range: " .. tostring(result))
    end
  end
end)

T:report()
