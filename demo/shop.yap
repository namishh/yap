@import "characters.yap"

@var gold = 50
@var has_sword = false
@var has_shield = false
@var has_potion = false
@var visit_count = 0
@var items_bought = 0

# enter_shop
set visit_count = visit_count + 1
set items_bought = 0

[once first_visit]
  @narrator: "You push open the creaky wooden door."
  @narrator: "A bell chimes overhead as you step into the dusty shop."
  @narrator: "Behind the counter stands a burly man with a thick mustache."
  @bob: "Well, well! A customer!"
  @bob: "Name's Bob. I run this little establishment."
  @bob: "Take a look around, see if anything catches your eye."
  @inner_voice: "He seems friendly enough..."
  -> shop_menu
[end]

[if visit_count == 2]
  @narrator: "You enter the shop again."
  @bob: "Back already? Couldn't stay away, eh?"
  -> shop_menu
[elseif visit_count >= 3]
  @narrator: "The familiar bell chimes as you enter."
  [random]
    * @bob: "Ah, my favorite customer!"
    * @bob: "You again! Always a pleasure."
    * @bob: "Welcome back, friend!"
  [end]
  -> shop_menu
[end]

# shop_menu
@narrator: "You have {gold} gold coins."

[if items_bought >= 3]
  @bob: "You've bought everything I have!"
  @bob: "Come back another day, I might have new stock."
  @inner_voice: "Nothing left to buy here..."
  -> exit_shop
[end]

[if gold <= 0]
  @bob: "Hmm, your pockets look a bit light there."
  @inner_voice: "I'm completely broke..."
  [choice]
    * "I'll come back when I have more gold" -> exit_shop
    * "Just browsing" -> browse
  [end]
[end]

[random]
  * @bob: "What can I get for ya?"
  * @bob: "So, what're you looking for today?"
  * @bob: "See anything that catches your eye?"
  * @bob: "What'll it be, friend?"
[end]

[choice]
  * "Buy a sword (30g)" [if not has_sword] -> buy_sword
  * "Buy a shield (25g)" [if not has_shield] -> buy_shield  
  * "Buy a potion (15g)" [if not has_potion] -> buy_potion
  * "Ask about prices" -> ask_prices
  * "Just browsing" -> browse
  * "Leave the shop" -> exit_shop
[end]

# after_purchase
@narrator: "You now have {gold} gold remaining."

[if gold <= 0]
  @inner_voice: "I'm out of gold..."
  @bob: "Looks like that's all you can afford today!"
  -> exit_prompt
[end]

[if items_bought >= 3]
  @bob: "And that's everything I've got!"
  @inner_voice: "Bought out the whole shop."
  -> exit_shop
[end]

[random]
  * @bob: "Anything else?"
  * @bob: "Need anything else while you're here?"
  * @bob: "What else can I do for ya?"
  * @bob: "Shall I wrap that up, or you want more?"
[end]
[choice]
  * "Let me see what else you have" -> shop_menu
  * "That's all for now" -> exit_shop
[end]

# ask_prices
@bob: "Let me tell ya what I've got:"

[if not has_sword]
  @bob: "A fine steel sword - 30 gold."
[end]
[if not has_shield]
  @bob: "A sturdy oak shield - 25 gold."
[end]
[if not has_potion]
  @bob: "A healing potion - 15 gold."
[end]

[if has_sword and has_shield and has_potion]
  @bob: "Actually... you've bought everything!"
  -> exit_shop
[end]

@bob: "So, what'll it be?"
-> shop_menu

# browse
@narrator: "You look around the shop."

[random]
  * @narrator: "Dust motes float in the sunlight streaming through the window."
  * @narrator: "Various weapons and items line the wooden shelves."
  * @narrator: "You notice a cat sleeping in the corner."
  * @narrator: "Old maps and strange trinkets hang from the walls."
  * @narrator: "The smell of leather and metal fills the air."
  * @narrator: "A suit of armor stands guard by the back door."
[end]

[if not has_sword]
  [random]
    * @inner_voice: "That sword looks well-crafted..."
    * @inner_voice: "I could use a good blade..."
    * @inner_voice: "The sword catches the light nicely."
  [end]
[end]
[if not has_shield]
  [random]
    * @inner_voice: "A shield could come in handy."
    * @inner_voice: "That shield looks sturdy enough."
    * @inner_voice: "Protection might be wise..."
  [end]
[end]

[random]
  * @bob: "See anything you like?"
  * @bob: "Take your time, no rush!"
  * @bob: "Let me know if something catches your eye."
  * @bob: "Quality goods, all of 'em!"
[end]
-> shop_menu

# exit_prompt
[choice]
  * "I should go" -> exit_shop
  * "Let me look around first" -> browse
[end]

# exit_shop
[if items_bought == 0]
  @bob: "Leaving empty-handed? No worries, come back anytime!"
  @inner_voice: "Maybe next time I'll buy something."
[elseif items_bought == 1]
  @bob: "Thanks for your purchase! Safe travels!"
[elseif items_bought == 2]
  @bob: "Two items! You're a good customer. Come back soon!"
[else]
  @bob: "You cleaned me out! Haha, thanks for the business!"
[end]

[once first_exit]
  @bob: "Oh, and be careful out there. Dangerous times."
  @inner_voice: "I'll keep that in mind."
[end]

await exit_transition { duration: 2 }

[random]
  * @narrator: "You step back out into the street."
  * @narrator: "You push through the door into the daylight."
  * @narrator: "The fresh air hits you as you exit."
[end]
[random]
  * @narrator: "The shop door closes behind you with a soft click."
  * @narrator: "The bell chimes one last time as the door shuts."
  * @narrator: "Bob waves from behind the counter as the door closes."
[end]

emit dialogue_complete { visited: true }

# re_enter
@narrator: "You stand outside Bob's shop."
[choice]
  * "Enter the shop" -> enter_shop
  * "Walk away" -> walk_away
[end]

# walk_away
@narrator: "You decide to continue on your way."
@inner_voice: "Maybe I'll come back later."
emit left_area {}
