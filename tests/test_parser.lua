package.path = package.path .. ";./yap/?.lua;./tests/?.lua"

local Parser = require("parser")
local testing = require("testing")

love = { filesystem = { read = function(path)
    local f = io.open(path, "r")
    if not f then return nil, "file not found: " .. path end
    local content = f:read("*a")
    f:close()
    return content
end }}

local T = testing.new()
local function test(name, fn) T:test(name, fn) end

local function createParser()
  return Parser.new()
end

test("tokenize empty and comments", function()
  local parser = createParser()
  T.assertsEqual("empty", parser:tokenize("").type)
  T.assertsEqual("empty", parser:tokenize("   ").type)
  T.assertsEqual("empty", parser:tokenize("-- this is a comment").type)
  T.assertsEqual("empty", parser:tokenize("  -- indented comment").type)
end)

test("tokenize imports", function()
  local parser = createParser()
  local token = parser:tokenize('@import "file.yap"')
  T.assertsEqual("import", token.type)
  T.assertsEqual("file.yap", token.path)

  token = parser:tokenize("@import 'other.yap'")
  T.assertsEqual("import", token.type)
  T.assertsEqual("other.yap", token.path)
end)

test("tokenize variables", function()
  local parser = createParser()
  local token = parser:tokenize('@var name = "Alice"')
  T.assertsEqual("var_def", token.type)
  T.assertsEqual("name", token.name)
  T.assertsEqual('"Alice"', token.value)

  token = parser:tokenize("@var gold = 100")
  T.assertsEqual("var_def", token.type)
  T.assertsEqual("gold", token.name)
  T.assertsEqual("100", token.value)

  token = parser:tokenize("@var has_key = true")
  T.assertsEqual("var_def", token.type)
  T.assertsEqual("has_key", token.name)
  T.assertsEqual("true", token.value)
end)

test("tokenize characters", function()
  local parser = createParser()
  local token = parser:tokenize("@character alice")
  T.assertsEqual("character_start", token.type)
  T.assertsEqual("alice", token.id)

  token = parser:tokenize("  name: \"Alice\"")
  T.assertsEqual("character_prop", token.type)
  T.assertsEqual("name", token.name)
  T.assertsEqual('"Alice"', token.value)
end)

test("tokenize functions", function()
  local parser = createParser()
  local token = parser:tokenize("@function greet")
  T.assertsEqual("function_start", token.type)
  T.assertsEqual("greet", token.name)

  token = parser:tokenize("@end")
  T.assertsEqual("block_end", token.type)
end)

test("tokenize labels and jumps", function()
  local parser = createParser()
  local token = parser:tokenize("# start")
  T.assertsEqual("label", token.type)
  T.assertsEqual("start", token.name)

  token = parser:tokenize("-> menu")
  T.assertsEqual("jump", token.type)
  T.assertsEqual("menu", token.target)
end)

test("tokenize conditionals", function()
  local parser = createParser()
  local token = parser:tokenize("[if gold >= 50]")
  T.assertsEqual("if", token.type)
  T.assertsEqual("gold >= 50", token.condition)

  token = parser:tokenize("[elseif has_key]")
  T.assertsEqual("elseif", token.type)
  T.assertsEqual("has_key", token.condition)

  token = parser:tokenize("[else]")
  T.assertsEqual("else", token.type)

  token = parser:tokenize("[end]")
  T.assertsEqual("end", token.type)
end)

test("tokenize set statement", function()
  local parser = createParser()
  local token = parser:tokenize("set gold = gold - 50")
  T.assertsEqual("set", token.type)
  T.assertsEqual("gold", token.variable)
  T.assertsEqual("gold - 50", token.expression)
end)

test("tokenize emit statement", function()
  local parser = createParser()
  local token = parser:tokenize('emit item_bought { item: "sword", cost: 50 }')
  T.assertsEqual("emit", token.type)
  T.assertsEqual("item_bought", token.event)
  T.assertsEqual("sword", token.params.item)
  T.assertsEqual(50, token.params.cost)
end)

test("tokenize once block", function()
  local parser = createParser()
  local token = parser:tokenize("[once first_visit]")
  T.assertsEqual("once", token.type)
  T.assertsEqual("first_visit", token.id)
end)

test("tokenize random and choice blocks", function()
  local parser = createParser()
  local token = parser:tokenize("[random]")
  T.assertsEqual("random", token.type)

  token = parser:tokenize("[choice]")
  T.assertsEqual("choice", token.type)
end)

test("tokenize options", function()
  local parser = createParser()
  local token = parser:tokenize('* "Buy sword" -> shop')
  T.assertsEqual("option", token.type)
  T.assertsEqual("Buy sword", token.text)
  T.assertsEqual("shop", token.target)
  T.assertsEqual(1, token.weight)

  token = parser:tokenize('* [weight: 3] @alice: "Hello!"')
  T.assertsEqual("option", token.type)
  T.assertsEqual(3, token.weight)
  T.assertsEqual("dialogue", token.dialogue.type)
end)

test("tokenize dialogue", function()
  local parser = createParser()
  local token = parser:tokenize('@alice: "Hello there!"')
  T.assertsEqual("dialogue", token.type)
  T.assertsEqual("alice", token.character)
  T.assertsEqual("Hello there!", token.text)

  token = parser:tokenize('@bob [1, 2]: "Welcome!"')
  T.assertsEqual("dialogue", token.type)
  T.assertsEqual("bob", token.character)
  T.assertsEqual(1, token.portrait_row)
  T.assertsEqual(2, token.portrait_col)
  T.assertsEqual("Welcome!", token.text)
end)

test("tokenize dialogue with metadata", function()
  local parser = createParser()
  local token = parser:tokenize('@alice: "Hello!" [duration: 2.5, mood: "happy"]')
  T.assertsEqual("dialogue", token.type)
  T.assertsEqual("alice", token.character)
  T.assertsEqual(2.5, token.metadata.duration)
  T.assertsEqual("happy", token.metadata.mood)
end)

test("tokenize function call", function()
  local parser = createParser()
  local token = parser:tokenize("@call greet")
  T.assertsEqual("call", token.type)
  T.assertsEqual("greet", token.name)
end)

test("parse variables", function()
  local parser = createParser()
  local ast = parser:parse([[
@var name = "Alice"
@var gold = 100
@var active = true
]], "test", "") or {}
  T.assertsEqual("Alice", ast.variables.name)
  T.assertsEqual(100, ast.variables.gold)
  T.assertsEqual(true, ast.variables.active)
end)

test("parse characters", function()
  local parser = createParser()
  local ast = parser:parse([[
@character alice
  name: "Alice"
  voice: "alice.wav"
]], "test", "") or {}
  T.assertNotNil(ast.characters.alice)
  T.assertsEqual("Alice", ast.characters.alice.name)
  T.assertsEqual("alice.wav", ast.characters.alice.voice)
end)

test("parse functions", function()
  local parser = createParser()
  local ast = parser:parse([[
@function greet
  @alice: "Hello!"
  @alice: "Welcome."
@end
]], "test", "") or {}
  T.assertNotNil(ast.functions.greet)
  T.assertsEqual(2, #ast.functions.greet.body)
  T.assertsEqual("dialogue", ast.functions.greet.body[1].type)
end)

test("parse labels and jumps", function()
  local parser = createParser()
  local ast = parser:parse([[
# start
@alice: "Hello!"
-> end_scene

# end_scene
@alice: "Goodbye!"
]], "test", "") or {}
  T.assertNotNil(ast.labels.start)
  T.assertNotNil(ast.labels.end_scene)
  T.assertsEqual("jump", ast.nodes[3].type)
  T.assertsEqual("end_scene", ast.nodes[3].target)
end)

test("parse conditionals", function()
  local parser = createParser()
  local ast = parser:parse([[
[if gold >= 50]
  @alice: "You're rich!"
[elseif gold >= 20]
  @alice: "Not bad."
[else]
  @alice: "You're broke."
[end]
]], "test", "") or {}
  T.assertsEqual(1, #ast.nodes)
  T.assertsEqual("if_block", ast.nodes[1].type)
  T.assertsEqual(3, #ast.nodes[1].branches)
  T.assertsEqual("gold >= 50", ast.nodes[1].branches[1].condition)
  T.assertsEqual("gold >= 20", ast.nodes[1].branches[2].condition)
  T.assertsEqual(nil, ast.nodes[1].branches[3].condition)
end)

test("parse choice block", function()
  local parser = createParser()
  local ast = parser:parse([[
[choice]
  * "Option A" -> label_a
  * "Option B" [if has_key] -> label_b
[end]
]], "test", "") or {}
  T.assertsEqual(1, #ast.nodes)
  T.assertsEqual("choice_block", ast.nodes[1].type)
  T.assertsEqual(2, #ast.nodes[1].options)
  T.assertsEqual("Option A", ast.nodes[1].options[1].text)
  T.assertsEqual("label_a", ast.nodes[1].options[1].target)
  T.assertsEqual("has_key", ast.nodes[1].options[2].condition)
end)

test("parse random block", function()
  local parser = createParser()
  local ast = parser:parse([[
[random]
  * @alice: "Option 1"
  * [weight: 2] @alice: "Option 2"
[end]
]], "test", "") or {}
  T.assertsEqual(1, #ast.nodes)
  T.assertsEqual("random_block", ast.nodes[1].type)
  T.assertsEqual(2, #ast.nodes[1].options)
  T.assertsEqual(1, ast.nodes[1].options[1].weight)
  T.assertsEqual(2, ast.nodes[1].options[2].weight)
end)

test("parse once block", function()
  local parser = createParser()
  local ast = parser:parse([[
[once first_time]
  @alice: "First visit!"
[end]
]], "test", "") or {}
  T.assertsEqual(1, #ast.nodes)
  T.assertsEqual("once_block", ast.nodes[1].type)
  T.assertsEqual("first_time", ast.nodes[1].id)
  T.assertsEqual(1, #ast.nodes[1].nodes)
end)

test("parse set and emit", function()
  local parser = createParser()
  local ast = parser:parse([[
set gold = gold + 10
emit level_up { level: 5 }
]], "test", "") or {}
  T.assertsEqual(2, #ast.nodes)
  T.assertsEqual("set", ast.nodes[1].type)
  T.assertsEqual("gold", ast.nodes[1].variable)
  T.assertsEqual("emit", ast.nodes[2].type)
  T.assertsEqual("level_up", ast.nodes[2].event)
end)

test("parse file integration", function()
  local parser = createParser()
  local ast = parser:parseFile("tests/test.yap", "") or {}
  T.assertNotNil(ast, "should parse test.yap")
  -- Check imports worked
  T.assertNotNil(ast.characters.alice)
  T.assertNotNil(ast.characters.bob)
  T.assertNotNil(ast.functions.greet)
  T.assertNotNil(ast.functions.farewell)
  -- Check variables
  T.assertsEqual("Hero", ast.variables.player_name)
  T.assertsEqual(100, ast.variables.gold)
  T.assertsEqual(false, ast.variables.has_sword)
end)

T:report()
