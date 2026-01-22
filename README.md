## Yap: Dialogue system for Love2D.

> [!CAUTION]
> Although I have tried to made this library as general-purpose as possible, this is still a personal library, primarily made for my own projects.

<br>

Parses `.yap` files or builds dialogues programmatically. Emits signals. You handle rendering.

## Installation

Copy the `yap/` folder into your project.

```lua
local yap = require("yap")
```

## Quick Start

```lua
-- Load and run
yap:load("dialogue.yap")
yap:start("label_name")

-- Game loop
if not yap:isWaitingForChoice() and not yap:isComplete() then
    yap:advance()
end

-- Handle choices
yap:choose(1)
```

---

## .yap File Syntax

### Variables

```
@var gold = 100
@var name = "Hero"
@var has_key = false
```

### Characters

```
@character bob
  name: "Bob the Shopkeeper"
  spritesheet: ["sprites/bob.png", 32, 32, 4, 4]
```

### Labels and Jumps

```
# start
@bob: "Hello!"
-> other_label

# other_label
@bob: "Goodbye!"
```

### Dialogue

```
@bob: "Basic dialogue"
@bob [1, 2]: "With portrait row 1, col 2"
@bob: "With metadata" [mood: happy, speed: slow]
@bob: "You have {gold} gold."
```

### Choices

```
[choice]
  * "Option text" -> target_label
  * "Conditional" [if gold > 10] -> buy
[end]
```

### Conditionals

```
[if gold >= 100]
  @bob: "Rich!"
[elseif gold >= 50]
  @bob: "Not bad."
[else]
  @bob: "Broke."
[end]
```

### Set Variables

```
set gold = gold - 10
set has_key = true
set gold = gold + random(1, 10)
```

### Once Blocks

```
[once first_meeting]
  @bob: "Nice to meet you!"
[end]
```

### Random Dialogue

```
[random]
  * @bob: "Hello!"
  * @bob: "Hi there!"
  * [weight: 2] @bob: "Welcome!"
[end]
```

### Random Sequences

```
[random]
  *:
    @narrator: "The door opens."
    @bob: "Welcome!"
  *: [weight: 2]
    @bob: "Back again?"
    @bob: "Good to see you."
[end]
```

### Emit and Await

```
emit door_opened { room: "kitchen" }
await cutscene_done { duration: 2 }
```

### Functions

```
@function greet
  @bob: "Hello!"
@end

@call greet
```

### Imports

```
@import "characters.yap"
```

---

## Programmatic API

Build dialogues in Lua. Can work in sync with `.yap` files.

### Labels

```lua
local greeting = yap.label("greeting")
  :say("bob", "Hello!")
  :say("bob", "Welcome to my shop.")
  :jump("shop_menu")

local shop = yap.label("shop_menu")
  :say("bob", "What do you need?")
  :choice({
    { text = "Buy sword", target = "buy", cond = yap.gte("gold", 30) },
    { text = "Leave", target = "exit" },
  })

yap:registerAll(greeting, shop)
yap:start("greeting")
```

### Dialogue with Options

```lua
:say("bob", "Hello!")
:say("bob", "Hello!", { portrait = {1, 2} })
:say("bob", "Hello!", { portrait = {0, 1}, mood = "happy", speed = "slow" })
```

### Conditions

```lua
-- Helpers
yap.eq("gold", 100)      -- ==
yap.neq("gold", 100)     -- ~=
yap.gt("gold", 50)       -- >
yap.gte("gold", 50)      -- >=
yap.lt("gold", 50)       -- <
yap.lte("gold", 50)      -- <=
yap.is("has_sword")      -- == true
yap.not_("has_sword")    -- not

-- Combinators
yap.and_(yap.gte("gold", 30), yap.not_("has_sword"))
yap.or_(yap.is("vip"), yap.gte("rep", 100))

-- Raw closures
:when(function(state) return state.gold >= 100 end, function(b)
  b:say("bob", "Rich!")
end)
```

### Set Variables

```lua
:set("has_sword", true)
:set("gold", function(gold) return gold - 30 end)
```

### Conditional Blocks

```lua
:when(yap.gte("gold", 100), function(b)
  b:say("bob", "Rich!")
end)
:orWhen(yap.gte("gold", 50), function(b)
  b:say("bob", "Not bad.")
end)
:otherwise(function(b)
  b:say("bob", "Broke.")
end)
```

### Once Blocks

```lua
:once("first_visit", function(b)
  b:say("bob", "Welcome!")
end)
```

### Random

```lua
-- Single line
:random({
  { char = "bob", text = "Hello!" },
  { char = "bob", text = "Hi!", weight = 2 },
})

-- Sequences
:randomSeq({
  {
    { "narrator", "The door opens." },
    { "bob", "Welcome!" },
  },
  {
    { "bob", "Back again?" },
    weight = 2,
  },
})
```

### Other Methods

```lua
:jump("label")
:call("function_name")
:emit("event", { key = "value" })
:await("event", { duration = 2 })
:choice({ { text = "...", target = "...", cond = ... } })
:defVar("gold", 100)
:defChar("bob", { name = "Bob" })
```

### Chains

```lua
local tutorial = yap.chain()
  :add(yap.label("step1"):say("guide", "Welcome!"))
  :add(yap.label("step2"):say("guide", "Here's your inventory."))
  :add(yap.label("step3"):say("guide", "Good luck!"))

yap:register(tutorial)
yap:start("step1")  -- auto-flows through all steps
```

### Mixing with .yap

```lua
yap:load("main.yap")

local dynamic = yap.label("random_quest")
  :say("bob", "I need your help!")
  :set("reward", function() return math.random(50, 100) end)

yap:register(dynamic)

-- Both coexist. Jump between them freely.
```

---

## Lua API Reference

### Loading

```lua
yap:load("file.yap")
yap:loadString(content, "name")
yap:register(label)
yap:registerAll(label1, label2, ...)
```

### Flow Control

```lua
yap:start("label")
yap:advance()
yap:choose(index)
yap:reset()
yap:pause("reason")
yap:resume()
```

### State Queries

```lua
yap:isComplete()
yap:isWaitingForChoice()
yap:getCurrentChoices()
yap:isAwaiting()
yap:getAwaitEvent()
```

### Variables

```lua
yap:setVar("name", value)
yap:getVar("name")
yap:hasVar("name")
yap:getAllVars()
yap:defVar("name", value)
yap:defChar("id", { name = "..." })
```

### History

```lua
yap:hasSeen("once_id")
yap:getVisitCount("label")
yap:forget("id")
```

### Save/Load

```lua
local data = yap:serialize()
yap:deserialize(data)
```

---

## Events

```lua
yap:on("event", callback)
yap:off("event", callback)
```

| Event | Data |
|-------|------|
| `on_line_start` | character, character_name, text, portrait_row, portrait_col, metadata |
| `on_line_end` | character |
| `on_choice_presented` | options |
| `on_choice_made` | index, text, target |
| `on_var_changed` | variable, oldValue, newValue |
| `on_dialogue_end` | |
| `on_pause` | reason |
| `on_await_complete` | event |
| Custom (`emit`) | your params |

---

## Example

See `demo/` folder. Run with Love2D:

```
love .
```

