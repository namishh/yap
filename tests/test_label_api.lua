package.path = package.path .. ";./yap/?.lua;./tests/?.lua"

love = { filesystem = { read = function(path)
    local f = io.open(path, "r")
    if not f then return nil, "file not found: " .. path end
    local content = f:read("*a")
    f:close()
    return content
end }}

local T = require("testing")

local Label = require("label")
local Chain = require("chain")
local Cond = require("cond")

local yap = {
  label = Label.new,
  chain = Chain.new,
  eq = Cond.eq,
  neq = Cond.neq,
  gt = Cond.gt,
  gte = Cond.gte,
  lt = Cond.lt,
  lte = Cond.lte,
  is = Cond.is,
  not_ = Cond.not_,
  and_ = Cond.and_,
  or_ = Cond.or_,
}

local t = T.new()

t:test("Cond.eq should return true when equal", function()
  local cond = yap.eq("gold", 100)
  T.assertsEqual(true, cond({ gold = 100 }))
  T.assertsEqual(false, cond({ gold = 50 }))
end)

t:test("Cond.neq should return true when not equal", function()
  local cond = yap.neq("gold", 100)
  T.assertsEqual(false, cond({ gold = 100 }))
  T.assertsEqual(true, cond({ gold = 50 }))
end)

t:test("Cond.gt should return true when greater", function()
  local cond = yap.gt("gold", 50)
  T.assertsEqual(true, cond({ gold = 100 }))
  T.assertsEqual(false, cond({ gold = 50 }))
  T.assertsEqual(false, cond({ gold = 25 }))
end)

t:test("Cond.gte should return true when greater or equal", function()
  local cond = yap.gte("gold", 50)
  T.assertsEqual(true, cond({ gold = 100 }))
  T.assertsEqual(true, cond({ gold = 50 }))
  T.assertsEqual(false, cond({ gold = 25 }))
end)

t:test("Cond.lt should return true when less", function()
  local cond = yap.lt("gold", 50)
  T.assertsEqual(false, cond({ gold = 100 }))
  T.assertsEqual(false, cond({ gold = 50 }))
  T.assertsEqual(true, cond({ gold = 25 }))
end)

t:test("Cond.lte should return true when less or equal", function()
  local cond = yap.lte("gold", 50)
  T.assertsEqual(false, cond({ gold = 100 }))
  T.assertsEqual(true, cond({ gold = 50 }))
  T.assertsEqual(true, cond({ gold = 25 }))
end)

t:test("Cond.is should return true when truthy", function()
  local cond = yap.is("has_sword")
  T.assertsEqual(true, cond({ has_sword = true }))
  T.assertsEqual(false, cond({ has_sword = false }))
end)

t:test("Cond.not_ should return true when falsy", function()
  local cond = yap.not_("has_sword")
  T.assertsEqual(false, cond({ has_sword = true }))
  T.assertsEqual(true, cond({ has_sword = false }))
  T.assertsEqual(true, cond({ has_sword = nil }))
end)

t:test("Cond.and_ should combine conditions", function()
  local cond = yap.and_(yap.gte("gold", 30), yap.not_("has_sword"))
  T.assertsEqual(true, cond({ gold = 50, has_sword = false }))
  T.assertsEqual(false, cond({ gold = 50, has_sword = true }))
  T.assertsEqual(false, cond({ gold = 10, has_sword = false }))
end)

t:test("Cond.or_ should combine conditions", function()
  local cond = yap.or_(yap.gte("gold", 100), yap.is("vip"))
  T.assertsEqual(true, cond({ gold = 100, vip = false }))
  T.assertsEqual(true, cond({ gold = 10, vip = true }))
  T.assertsEqual(false, cond({ gold = 10, vip = false }))
end)

t:test("Label.say should add dialogue node", function()
  local label = yap.label("test")
    :say("bob", "Hello!")
  
  local built = label:build()
  T.assertsEqual("test", built.name)
  T.assertsEqual(1, #built.nodes)
  T.assertsEqual("dialogue", built.nodes[1].type)
  T.assertsEqual("bob", built.nodes[1].character)
  T.assertsEqual("Hello!", built.nodes[1].text)
end)

t:test("Label.say with portrait should set portrait coords", function()
  local label = yap.label("test")
    :say("bob", "Hello!", { portrait = {1, 2} })
  
  local built = label:build()
  T.assertsEqual(1, built.nodes[1].portrait_row)
  T.assertsEqual(2, built.nodes[1].portrait_col)
end)

t:test("Label.say with metadata should set metadata", function()
  local label = yap.label("test")
    :say("bob", "Hello!", { mood = "happy", speed = "slow" })
  
  local built = label:build()
  T.assertsEqual("happy", built.nodes[1].metadata.mood)
  T.assertsEqual("slow", built.nodes[1].metadata.speed)
end)

t:test("Label.jump should add jump node", function()
  local label = yap.label("test")
    :jump("other_label")
  
  local built = label:build()
  T.assertsEqual("jump", built.nodes[1].type)
  T.assertsEqual("other_label", built.nodes[1].target)
end)

t:test("Label.set with literal should add set node", function()
  local label = yap.label("test")
    :set("has_sword", true)
  
  local built = label:build()
  T.assertsEqual("set_api", built.nodes[1].type)
  T.assertsEqual("has_sword", built.nodes[1].variable)
  T.assertsEqual(true, built.nodes[1].valueOrFn)
end)

t:test("Label.set with function should add set node", function()
  local label = yap.label("test")
    :set("gold", function(g) return g - 30 end)
  
  local built = label:build()
  T.assertsEqual("set_api", built.nodes[1].type)
  T.assertsEqual("function", type(built.nodes[1].valueOrFn))
  -- Test the function works
  T.assertsEqual(70, built.nodes[1].valueOrFn(100))
end)

t:test("Label.choice should add choice_block_api node", function()
  local label = yap.label("test")
    :choice({
      { text = "Option 1", target = "label1" },
      { text = "Option 2", target = "label2", cond = yap.gte("gold", 50) },
    })
  
  local built = label:build()
  T.assertsEqual("choice_block_api", built.nodes[1].type)
  T.assertsEqual(2, #built.nodes[1].options)
  T.assertsEqual("Option 1", built.nodes[1].options[1].text)
  T.assertsEqual("label1", built.nodes[1].options[1].target)
end)

t:test("Label.random should add random_block node", function()
  local label = yap.label("test")
    :random({
      { char = "bob", text = "Hello!" },
      { char = "bob", text = "Hi!", weight = 2 },
    })
  
  local built = label:build()
  T.assertsEqual("random_block", built.nodes[1].type)
  T.assertsEqual(2, #built.nodes[1].options)
  T.assertsEqual(1, built.nodes[1].options[1].weight)
  T.assertsEqual(2, built.nodes[1].options[2].weight)
end)

t:test("Label.randomSeq should add random_seq_block node", function()
  local label = yap.label("test")
    :randomSeq({
      {
        { "narrator", "The door opens." },
        { "bob", "Welcome!" },
      },
      {
        { "bob", "Hey there!" },
        weight = 2,
      },
    })
  
  local built = label:build()
  T.assertsEqual("random_seq_block", built.nodes[1].type)
  T.assertsEqual(2, #built.nodes[1].options)
  T.assertsEqual(2, #built.nodes[1].options[1].nodes)
  T.assertsEqual(1, #built.nodes[1].options[2].nodes)
  T.assertsEqual(2, built.nodes[1].options[2].weight)
end)

t:test("Label.once should add once_block node", function()
  local label = yap.label("test")
    :once("first_visit", function(b)
      b:say("bob", "Welcome!")
    end)
  
  local built = label:build()
  T.assertsEqual("once_block", built.nodes[1].type)
  T.assertsEqual("first_visit", built.nodes[1].id)
  T.assertsEqual(1, #built.nodes[1].nodes)
end)

t:test("Label.when/orWhen/otherwise should add if_block_api node", function()
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
  T.assertsEqual("if_block_api", built.nodes[1].type)
  T.assertsEqual(3, #built.nodes[1].branches)
  T.assertNotNil(built.nodes[1].branches[1].condition)
  T.assertNotNil(built.nodes[1].branches[2].condition)
  T.assertsEqual(nil, built.nodes[1].branches[3].condition)  -- else branch
end)

t:test("Label.defVar should add to variables", function()
  local label = yap.label("test")
    :defVar("gold", 100)
    :defVar("has_sword", false)
  
  local built = label:build()
  T.assertsEqual(100, built.variables.gold)
  T.assertsEqual(false, built.variables.has_sword)
end)

t:test("Label.defChar should add to characters", function()
  local label = yap.label("test")
    :defChar("bob", { name = "Bob the Shopkeeper" })
  
  local built = label:build()
  T.assertsEqual("Bob the Shopkeeper", built.characters.bob.name)
end)

t:test("Chain should auto-connect labels", function()
  local chain = yap.chain()
    :add(yap.label("step1"):say("guide", "Step 1"))
    :add(yap.label("step2"):say("guide", "Step 2"))
    :add(yap.label("step3"):say("guide", "Step 3"))
  
  local builtLabels = chain:build()
  T.assertsEqual(3, #builtLabels)
  
  local lastNode1 = builtLabels[1].nodes[#builtLabels[1].nodes]
  T.assertsEqual("jump", lastNode1.type)
  T.assertsEqual("step2", lastNode1.target)
  
  local lastNode2 = builtLabels[2].nodes[#builtLabels[2].nodes]
  T.assertsEqual("jump", lastNode2.type)
  T.assertsEqual("step3", lastNode2.target)
  
  local lastNode3 = builtLabels[3].nodes[#builtLabels[3].nodes]
  T.assertsEqual("dialogue", lastNode3.type)
end)

t:test("Chain should not add jump if label ends with jump", function()
  local chain = yap.chain()
    :add(yap.label("step1"):say("guide", "Step 1"):jump("somewhere"))
    :add(yap.label("step2"):say("guide", "Step 2"))
  
  local builtLabels = chain:build()
  
  T.assertsEqual(2, #builtLabels[1].nodes)
  T.assertsEqual("somewhere", builtLabels[1].nodes[2].target)
end)

t:report()

return t

