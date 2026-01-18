package.path = package.path .. ";./yap/?.lua;./tests/?.lua"

love = { filesystem = { read = function(path)
    local f = io.open(path, "r")
    if not f then return nil, "file not found: " .. path end
    local content = f:read("*a")
    f:close()
    return content
end }}

local T = require("testing")

local Parser = require("parser")
local Label = require("label")
local Cond = require("cond")

local yap = {
  label = Label.new,
  eq = Cond.eq, neq = Cond.neq,
  gt = Cond.gt, gte = Cond.gte,
  lt = Cond.lt, lte = Cond.lte,
  is = Cond.is, not_ = Cond.not_,
  and_ = Cond.and_, or_ = Cond.or_,
}

local t = T.new()

t:test("Parser should parse *: sequence blocks", function()
  local parser = Parser.new()
  local content = [[
# test
[random]
  *:
    @narrator: "Line 1"
    @bob: "Line 2"
  *: [weight: 2]
    @alice: "Line 3"
[end]
]]
  
  local ast = parser:parse(content, "test", "")
  T.assertNotNil(ast)
  T.assertsEqual(2, #ast.nodes)  -- label + random_block
  T.assertsEqual("random_block", ast.nodes[2].type)
  T.assertsEqual(2, #ast.nodes[2].options)
  T.assertsEqual(2, #ast.nodes[2].options[1].nodes)
  T.assertsEqual(2, ast.nodes[2].options[2].weight)
end)

t:test("Parser should parse mixed single and sequence options", function()
  local parser = Parser.new()
  local content = [[
# test
[random]
  * @bob: "Single line"
  *:
    @narrator: "Sequence line 1"
    @bob: "Sequence line 2"
  * @alice: "Another single"
[end]
]]
  
  local ast = parser:parse(content, "test", "")
  T.assertNotNil(ast)
  local randomBlock = ast.nodes[2]
  T.assertsEqual("random_block", randomBlock.type)
  T.assertsEqual(3, #randomBlock.options)
  T.assertNotNil(randomBlock.options[1].dialogue)
  T.assertsEqual(nil, randomBlock.options[1].nodes)
  T.assertsEqual(nil, randomBlock.options[2].dialogue)
  T.assertNotNil(randomBlock.options[2].nodes)
  T.assertsEqual(2, #randomBlock.options[2].nodes)
  T.assertNotNil(randomBlock.options[3].dialogue)
end)

t:test("Label.randomSeq should create correct AST structure", function()
  local label = yap.label("test")
    :randomSeq({
      {
        { "narrator", "Line 1" },
        { "bob", "Line 2" },
      },
      {
        { "alice", "Line 3" },
        weight = 2,
      },
    })
  
  local built = label:build()
  T.assertsEqual(1, #built.nodes)
  T.assertsEqual("random_seq_block", built.nodes[1].type)
  T.assertsEqual(2, #built.nodes[1].options)
  T.assertsEqual(1, built.nodes[1].options[1].weight)
  T.assertsEqual(2, #built.nodes[1].options[1].nodes)
  T.assertsEqual("narrator", built.nodes[1].options[1].nodes[1].character)
  T.assertsEqual("Line 1", built.nodes[1].options[1].nodes[1].text)
  T.assertsEqual(2, built.nodes[1].options[2].weight)
  T.assertsEqual(1, #built.nodes[1].options[2].nodes)
end)

t:test("Label.randomSeq with portraits and metadata", function()
  local label = yap.label("test")
    :randomSeq({
      {
        { "bob", "Hello!", { portrait = {1, 2}, mood = "happy" } },
      },
    })
  
  local built = label:build()
  local dialogue = built.nodes[1].options[1].nodes[1]
  T.assertsEqual(1, dialogue.portrait_row)
  T.assertsEqual(2, dialogue.portrait_col)
  T.assertsEqual("happy", dialogue.metadata.mood)
end)

t:test("Label.choice with condition functions", function()
  local label = yap.label("test")
    :choice({
      { text = "Buy sword", target = "buy", cond = yap.gte("gold", 30) },
      { text = "Leave", target = "exit" },
    })
  
  local built = label:build()
  T.assertsEqual("choice_block_api", built.nodes[1].type)
  T.assertsEqual(2, #built.nodes[1].options)
  T.assertsEqual("function", type(built.nodes[1].options[1].condition))
  T.assertsEqual(true, built.nodes[1].options[1].condition({ gold = 50 }))
  T.assertsEqual(false, built.nodes[1].options[1].condition({ gold = 20 }))
  T.assertsEqual(nil, built.nodes[1].options[2].condition)
end)

t:test("Label conditional blocks structure", function()
  local label = yap.label("test")
    :when(yap.gte("gold", 100), function(b)
      b:say("bob", "Rich!")
    end)
    :orWhen(yap.gte("gold", 50), function(b)
      b:say("bob", "OK.")
    end)
    :otherwise(function(b)
      b:say("bob", "Poor.")
    end)
  
  local built = label:build()
  T.assertsEqual(1, #built.nodes)
  T.assertsEqual("if_block_api", built.nodes[1].type)
  T.assertsEqual(3, #built.nodes[1].branches)
  
  local branch1 = built.nodes[1].branches[1]
  T.assertsEqual("function", type(branch1.condition))
  T.assertsEqual(true, branch1.condition({ gold = 150 }))
  T.assertsEqual(false, branch1.condition({ gold = 50 }))
  
  local branch2 = built.nodes[1].branches[2]
  T.assertsEqual(true, branch2.condition({ gold = 75 }))
  
  local branch3 = built.nodes[1].branches[3]
  T.assertsEqual(nil, branch3.condition)
end)

t:report()

return t
