local yap = require("yap")
local dialogueLog = {}
local maxLog = 15
local font = nil
local titleFont = nil

GOLD = 50
HAS_SWORD = false
HAS_SHIELD = false
HAS_POTION = false

local bgColor = {0.12, 0.1, 0.15}
local bgTargetColor = nil
local bgStartColor = nil
local bgTransitionTime = 0
local bgTransitionElapsed = 0
local isTransitioning = false

local addPurchaseLabels = function()
  local buy_sword = yap.label("buy_sword")
    :when(yap.lt("gold", 30), function(b)
      b:say("bob", "That'll be 30 gold.")
      b:say("inner_voice", "I only have {gold} gold... not enough.")
      b:say("player", "Actually, I don't have enough...")
      b:say("bob", "No worries, come back when you've got the coin!")
      b:jump("shop_menu")
    end)
    :say("player", "I'll take that sword.")
    :randomSeq({
      { { "bob", "Excellent choice! A fine blade, that one." } },
      { { "bob", "Ah, you've got good taste! That's quality steel." } },
      { { "bob", "A wise purchase! This blade has seen many battles." } },
    })
    :set("gold", function(g) return g - 30 end)
    :set("has_sword", true)
    :set("items_bought", function(n) return n + 1 end)
    :say("narrator", "Bob hands you a gleaming steel sword.")
    :randomSeq({
      { { "bob", "30 gold, pleasure doing business!" } },
      { { "bob", "That's 30 gold. Take care of it!" } },
      { { "bob", "30 gold changes hands. She's all yours now." } },
    })
    :randomSeq({
      { { "inner_voice", "This feels good in my hand." } },
      { { "inner_voice", "Now I can defend myself properly." } },
      { { "inner_voice", "A fine weapon indeed." } },
    })
    :emit("item_purchased", { item = "sword", cost = 30 })
    :jump("after_purchase")
    local buy_shield = yap.label("buy_shield")
    :when(yap.lt("gold", 25), function(b)
      b:say("bob", "That shield's 25 gold.")
      b:say("inner_voice", "I'm {gold} gold short... blast.")
      b:say("player", "Hmm, let me think about it...")
      b:say("bob", "Take your time!")
      b:jump("shop_menu")
    end)
    :say("player", "I'd like that shield.")
    :randomSeq({
      { { "bob", "Smart! Protection is important." } },
      { { "bob", "Good thinking! Can't put a price on safety." } },
      { { "bob", "Solid oak, reinforced with iron. You won't regret it." } },
    })
    :set("gold", function(g) return g - 25 end)
    :set("has_shield", true)
    :set("items_bought", function(n) return n + 1 end)
    :say("narrator", "You strap the sturdy wooden shield to your arm.")
    :randomSeq({
      { { "bob", "25 gold, thank you kindly!" } },
      { { "bob", "That's 25 gold. May it serve you well!" } },
      { { "bob", "25 gold it is. Stay safe out there!" } },
    })
    :randomSeq({
      { { "inner_voice", "I feel safer already." } },
      { { "inner_voice", "This should block a few blows." } },
      { { "inner_voice", "Solid and dependable. Just what I needed." } },
    })
    :emit("item_purchased", { item = "shield", cost = 25 })
    :jump("after_purchase")

    local buy_potion = yap.label("buy_potion")
    :when(yap.lt("gold", 15), function(b)
      b:say("bob", "Potions are 15 gold each.")
      b:say("inner_voice", "Can't even afford a potion with {gold} gold...")
      b:say("player", "Maybe next time.")
      b:say("bob", "They'll be here when you need 'em!")
      b:jump("shop_menu")
    end)
    :say("player", "One potion, please.")
    :randomSeq({
      { { "bob", "Wise to be prepared!" } },
      { { "bob", "Always good to have one of these on hand." } },
      { { "bob", "Brewed it myself! Well, my cousin did. Same thing." } },
    })
    :set("gold", function(g) return g - 15 end)
    :set("has_potion", true)
    :set("items_bought", function(n) return n + 1 end)
    :say("narrator", "Bob places a small red vial in your hand.")
    :randomSeq({
      { { "bob", "15 gold. Use it well!" } },
      { { "bob", "That's 15 gold. Drink it when things get rough!" } },
      { { "bob", "15 gold, friend. Hope you never need it!" } },
    })
    :randomSeq({
      { { "inner_voice", "Could save my life someday." } },
      { { "inner_voice", "Better to have it and not need it..." } },
      { { "inner_voice", "The liquid glows faintly. Interesting." } },
    })
    :emit("item_purchased", { item = "potion", cost = 15 })
    :jump("after_purchase")
  yap:registerAll(buy_sword, buy_shield, buy_potion)
end

function love.load()
  love.window.setTitle("Shop Demo")
  yap:setDebug(true)
  love.window.setMode(800, 600)
  font = love.graphics.newFont("demo/DungeonFont.ttf", 18)
  titleFont = love.graphics.newFont("demo/DungeonFont.ttf", 28)
  love.graphics.setFont(font)
  yap:on("on_var_changed", function(data)
    if data.variable == "gold" then
      GOLD = data.newValue
    elseif data.variable == "has_sword" then
      HAS_SWORD = data.newValue
    elseif data.variable == "has_shield" then
      HAS_SHIELD = data.newValue
    elseif data.variable == "has_potion" then
      HAS_POTION = data.newValue
    end
  end)
  yap:on("on_line_start", function(data)
    table.insert(dialogueLog, {
      speaker = data.character_name or data.character,
      text = data.text
    })
    while #dialogueLog > maxLog do
      table.remove(dialogueLog, 1)
    end
  end)
  yap:on("exit_transition", function(data)
    bgStartColor = {bgColor[1], bgColor[2], bgColor[3]}
    bgTargetColor = {0.03, 0.07, 0.04}
    bgTransitionTime = data.duration or 2
    bgTransitionElapsed = 0
    isTransitioning = true
  end)
  local ok, err = yap:load("demo/shop.yap")
  if not ok then
    print("ERROR: " .. err)
    return
  end
  addPurchaseLabels()
  yap:setVar("gold", GOLD)
  yap:start("enter_shop")
end


function love.update(dt)
  if isTransitioning and bgTargetColor and bgStartColor then
    bgTransitionElapsed = bgTransitionElapsed + dt
    local t = math.min(bgTransitionElapsed / bgTransitionTime, 1)
    t = t < 0.5 and 2 * t * t or 1 - math.pow(-2 * t + 2, 2) / 2
    bgColor[1] = bgStartColor[1] + (bgTargetColor[1] - bgStartColor[1]) * t
    bgColor[2] = bgStartColor[2] + (bgTargetColor[2] - bgStartColor[2]) * t
    bgColor[3] = bgStartColor[3] + (bgTargetColor[3] - bgStartColor[3]) * t
    if bgTransitionElapsed >= bgTransitionTime then
      isTransitioning = false
      bgColor = {bgTargetColor[1], bgTargetColor[2], bgTargetColor[3]}
      bgTargetColor = nil
      bgStartColor = nil
      if yap:isAwaiting() then
        yap:resume()
      end
    end
  end
end

function love.draw()
  love.graphics.setBackgroundColor(bgColor[1], bgColor[2], bgColor[3])
  love.graphics.setColor(0.2, 0.18, 0.25)
  love.graphics.rectangle("fill", 0, 0, 800, 50)
  if titleFont then
    love.graphics.setFont(titleFont)
  end
  love.graphics.setColor(0.9, 0.85, 0.7)
  love.graphics.print("Bob's Shop.", 20, 10)
  if font then
    love.graphics.setFont(font)
  end
  love.graphics.setColor(0.7, 0.65, 0.5)
  local sword = HAS_SWORD and "Yes" or "No"
  local shield = HAS_SHIELD and "Yes" or "No"
  local potion = HAS_POTION and "Yes" or "No"
  love.graphics.print(string.format("Gold: %d  |  Sword: %s  |  Shield: %s  |  Potion: %s", GOLD, sword, shield, potion), 400, 18)
  local y = 70
  for i, entry in ipairs(dialogueLog) do
    local alpha = 0.4 + (i / #dialogueLog) * 0.6
    if entry.speaker == "" then
      love.graphics.setColor(0.6 * alpha, 0.55 * alpha, 0.5 * alpha)
      love.graphics.print("* " .. entry.text, 30, y)
    elseif entry.speaker == ">" then
      love.graphics.setColor(0.5 * alpha, 0.7 * alpha, 0.5 * alpha)
      love.graphics.print("> " .. entry.text, 30, y)
    elseif entry.speaker == "(Inner Voice)" then
      love.graphics.setColor(0.5 * alpha, 0.5 * alpha, 0.7 * alpha)
      love.graphics.print("~ " .. entry.text, 30, y)
    else
      love.graphics.setColor(0.8 * alpha, 0.7 * alpha, 0.5 * alpha)
      love.graphics.print(entry.speaker .. ":", 30, y)
      love.graphics.setColor(0.9 * alpha, 0.9 * alpha, 0.85 * alpha)
      love.graphics.print(entry.text, 30 + love.graphics.getFont():getWidth(entry.speaker .. ": "), y)
    end
    y = y + 22
  end
  if yap:isWaitingForChoice() then
    local choices = yap:getCurrentChoices()
    if choices then
      local choiceHeight = 22
      local boxHeight = 30 + (#choices * choiceHeight)
      local boxY = 580 - boxHeight
      love.graphics.setColor(0.3, 0.28, 0.35)
      love.graphics.rectangle("fill", 20, boxY, 760, boxHeight)
      love.graphics.setColor(0.9, 0.85, 0.6)
      love.graphics.print("Choose:", 35, boxY + 5)
      local cy = boxY + 28
      for i, choice in ipairs(choices) do
        love.graphics.setColor(0.7, 0.8, 0.9)
        local text = string.format("[%d] %s", i, choice.text)
        love.graphics.print(text, 50, cy)
        cy = cy + choiceHeight
      end
    end
  elseif yap:isAwaiting() then
    love.graphics.setColor(0.5, 0.6, 0.5)
  elseif yap:isComplete() then
    love.graphics.setColor(0.4, 0.6, 0.4)
    love.graphics.print("Dialogue complete. Press R to restart or Q to quit.", 30, 550)
  else
    love.graphics.setColor(0.5, 0.5, 0.55)
    love.graphics.print("Press SPACE to continue...", 30, 550)
  end
  love.graphics.setColor(0.35, 0.35, 0.4)
  love.graphics.print("SPACE: advance  |  1-9: choose  |  R: restart  |  Q: quit", 20, 580)
end

function love.keypressed(key)
  if key == "q" or key == "escape" then
    love.event.quit()
  elseif key == "r" then
    dialogueLog = {}
    yap:reset()
    GOLD = 50
    HAS_SWORD = false
    HAS_SHIELD = false
    HAS_POTION = false
    yap:setVar("gold", GOLD)
    yap:setVar("has_sword", HAS_SWORD)
    yap:setVar("has_shield", HAS_SHIELD)
    yap:setVar("has_potion", HAS_POTION)
    yap:setVar("visit_count", 0)
    yap:setVar("items_bought", 0)
    yap:forget("first_visit")
    yap:forget("first_exit")
    bgColor = {0.12, 0.1, 0.15}
    bgTargetColor = nil
    bgStartColor = nil
    isTransitioning = false
    yap:start("enter_shop")
  elseif key == "space" then
    if not yap:isWaitingForChoice() and not yap:isComplete() and not yap:isAwaiting() then
      yap:advance()
    end
  elseif key >= "1" and key <= "9" then
    if yap:isWaitingForChoice() then
      local num = tonumber(key)
      local choices = yap:getCurrentChoices()
      if choices and num <= #choices then
        yap:choose(num)
      end
    end
  end
end
