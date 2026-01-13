local yap = require("yap")

local currentLine = nil
local dialogueLog = {}
local maxLog = 15
local font = nil
local titleFont = nil

function love.load()
  love.window.setTitle("Shop Demo")
  love.window.setMode(800, 600)
  
  font = love.graphics.newFont("demo/DungeonFont.ttf", 18)
  titleFont = love.graphics.newFont("demo/DungeonFont.ttf", 28)
  love.graphics.setFont(font)
  
  yap:on("on_line_start", function(data)
    currentLine = data
    table.insert(dialogueLog, {
      speaker = data.character_name or data.character,
      text = data.text
    })
    while #dialogueLog > maxLog do
      table.remove(dialogueLog, 1)
    end
  end)
  
  local ok, err = yap:load("demo/shop.yap")
  if not ok then
    print("ERROR: " .. err)
    return
  end
  
  yap:start("enter_shop")
end

function love.update(dt)
end

function love.draw()
  love.graphics.setBackgroundColor(0.12, 0.1, 0.15)
  
  love.graphics.setColor(0.2, 0.18, 0.25)
  love.graphics.rectangle("fill", 0, 0, 800, 50)
  
  love.graphics.setFont(titleFont)
  love.graphics.setColor(0.9, 0.85, 0.7)
  love.graphics.print("Bob's Shop", 20, 10)
  love.graphics.setFont(font)
  
  love.graphics.setColor(0.7, 0.65, 0.5)
  local gold = yap:getVar("gold") or 0
  local sword = yap:getVar("has_sword") and "Yes" or "No"
  local shield = yap:getVar("has_shield") and "Yes" or "No"
  local potion = yap:getVar("has_potion") and "Yes" or "No"
  love.graphics.print(string.format("Gold: %d  |  Sword: %s  |  Shield: %s  |  Potion: %s", gold, sword, shield, potion), 400, 18)
  
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
    yap:setVar("gold", 50)
    yap:setVar("has_sword", false)
    yap:setVar("has_shield", false)
    yap:setVar("has_potion", false)
    yap:setVar("visit_count", 0)
    yap:setVar("items_bought", 0)
    yap:forget("first_visit")
    yap:forget("first_exit")
    print("\n=== Restarted ===\n")
    yap:start("enter_shop")
  elseif key == "space" then
    if not yap:isWaitingForChoice() and not yap:isComplete() then
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
