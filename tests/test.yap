@import "characters.yap"
@import "functions.yap"

@var player_name = "Hero"
@var gold = 100
@var has_sword = false

# start
@narrator: "You enter the shop."
@call greet

[if gold >= 50]
  @alice: "You look like you can afford something!"
[else]
  @alice: "Browsing today?"
[end]

-> menu

# menu
@alice: "What would you like?" [duration: 2.5, mood: "happy"]

[choice]
  * "Buy sword (50g)" [if gold >= 50] -> buy_sword
  * "Just looking" -> browse
  * "Leave" -> exit
[end]

# buy_sword
set gold = gold - 50
set has_sword = true
@alice [1, 0]: "Here's your sword!"
emit item_bought { item: "sword", cost: 50 }
-> menu

# browse
@narrator: "You look around."

[random]
  * @alice: "Take your time!"
  * @alice [0, 1]: "See anything you like?"
  * [weight: 2] @alice: "We have great deals today."
[end]

-> menu

# exit
[once first_goodbye]
  @alice: "First time leaving? Here's a tip!"
  set gold = gold + 10
[end]

@call farewell
emit dialogue_end {}

