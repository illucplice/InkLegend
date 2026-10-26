class_name Taunts
extends RefCounted
## What fighters say: a line as the match opens, and a jab after a headshot.

const INTRO := {
	&"quotuk": ["Let's keep this quick.", "Ready when you are."],
	&"klakla": ["Klak klak!", "Snip snip."],
	&"pipmo": ["Pip pip, here I go!", "Small but deadly!"],
	&"fentuk": ["Stand still, would you?", "This won't hurt. Much."],
	&"bomba": ["Things are gonna go boom.", "Stand back. Way back."],
	&"rango": ["Draw, partner.", "This town ain't big enough."],
	&"grak": ["GRAK SMASH.", "Grak hungry."],
	&"plopo": ["Plop!", "Blub blub."],
	&"megu": ["With this treasure, I summon...", "Shadows, come."],
	&"uryo": ["A Quincy never misses.", "Your form is sloppy."],
	&"ryo": ["Show me your strength.", "The answer lies in battle."],
	&"gok": ["Hey! You look strong!", "Let's go all out!"],
	&"egita": ["I am the prince!", "You're beneath me."],
	&"lufi": ["I'm gonna be king!", "Shishishi!"],
	&"ichi": ["I'll protect them all.", "Bankai."],
	&"yuj": ["Let's get this over with.", "Sorry, he's a little angry."],
	&"goj": ["Don't worry, I'm the strongest.", "Throughout heaven and earth..."],
	&"akum": ["Feel the power of the fist!", "Weakling."],
	&"thundr": ["Bring me the storm!", "I'm still worthy."],
	&"capt": ["I can do this all day.", "On your left."],
	&"spydr": ["Your friendly neighbourhood hero!", "Spider-sense tingling."],
	&"batz": ["I'm the night.", "Criminals are a cowardly lot."],
	&"jotar": ["Yare yare...", "Good grief."],
	&"kazma": ["I'll steal your panties. Kidding.", "Luck is a stat too!"],
	&"subaro": ["I'll save everyone this time!", "Nice to meet you!"],
	&"aizon": ["Since when were you under the impression...", "Do not use strong words."],
	&"frierin": ["I'll get this over with.", "...I'm sleepy."],
	&"rimiru": ["Let's settle this peacefully. Or not.", "I'm not a bad slime!"],
	&"kririn": ["I'm the strongest human!", "Let's go! I won't hold back!"],
	&"usoppu": ["I have 8,000 followers!", "My legs aren't shaking, you are!"],
	&"zenitzu": ["I'm gonna die... I'm gonna die!", "Please, someone else fight!"],
	&"robin": ["Holy smokes, let's do this!", "Titans, go!"],
	&"dyo": ["You thought it would be easy?", "I reject my humanity!"],
}

const HIT := {
	&"egita": ["Pathetic!", "Know your place!"],
	&"gok": ["Whoa, nice one!", "You okay?"],
	&"goj": ["Too easy.", "Did that tickle?"],
	&"lufi": ["Gum gum!", "Shishishi!"],
	&"grak": ["GRAK WIN.", "Bonk."],
	&"capt": ["Language!", "Stay down."],
	&"spydr": ["Thwip!", "Nailed it!"],
	&"batz": ["Justice.", "Sloppy."],
	&"jotar": ["ORA!", "Good grief."],
	&"kazma": ["Lucky!", "Steal!"],
	&"subaro": ["Nailed it!", "Beatris, thanks!"],
	&"aizon": ["All according to plan.", "Predictable."],
	&"frierin": ["Zoltraak.", "Ordinary offensive magic."],
	&"rimiru": ["Predator.", "Analysis complete."],
	&"kririn": ["Destructo Disc!", "Ha! Got you!"],
	&"usoppu": ["Sniper King!", "Bullseye, as always!"],
	&"zenitzu": ["Wait, did I do that?", "Thunderclap!"],
	&"robin": ["Birdarang!", "Nailed it!"],
	&"dyo": ["MUDA!", "Useless!"],
	&"thundr": ["Ha! Another!", "Thunder!"],
	&"akum": ["Weak!", "Shun goku!"],
}

const GENERIC_HIT := ["Bullseye!", "Right on the head!", "Ha!", "Too slow!", "Gotcha!"]


static func intro_line(id: StringName, rng: RandomNumberGenerator) -> String:
	var lines: Array = INTRO.get(id, ["Let's do this!", "Bring it on!"])
	return lines[rng.randi() % lines.size()]


static func hit_line(id: StringName, rng: RandomNumberGenerator) -> String:
	var lines: Array = HIT.get(id, GENERIC_HIT)
	return lines[rng.randi() % lines.size()]


## Each fighter's rival: the boss at the end of their arcade ladder.
const RIVALS := {
	&"gok": &"egita", &"egita": &"gok", &"ryo": &"akum", &"akum": &"ryo",
	&"ichi": &"aizon", &"aizon": &"ichi", &"uryo": &"ichi", &"jotar": &"dyo", &"dyo": &"jotar",
	&"goj": &"yuj", &"yuj": &"goj", &"megu": &"yuj", &"lufi": &"gok",
	&"thundr": &"capt", &"capt": &"thundr", &"spydr": &"batz", &"batz": &"spydr",
	&"kazma": &"subaro", &"subaro": &"kazma", &"frierin": &"rimiru", &"rimiru": &"frierin",
	&"quotuk": &"grak", &"grak": &"quotuk", &"klakla": &"pipmo", &"pipmo": &"klakla",
	&"fentuk": &"rango", &"rango": &"fentuk", &"bomba": &"plopo", &"plopo": &"bomba",
	&"kririn": &"gok", &"usoppu": &"lufi", &"zenitzu": &"kazma", &"robin": &"batz",
}

## The face-off when rivals meet: [what the first says, how the second answers].
const RIVAL_LINES := {
	"gok>egita": ["Egita! Ready to go all out?", "This time I surpass you, Kakarot!"],
	"egita>gok": ["Kakarot! Today you fall!", "Heh, I was hoping you'd say that!"],
	"ryo>akum": ["I won't give in to the darkness.", "Then you will die, Ryo."],
	"akum>ryo": ["Embrace the Satsui no Hado.", "My fists are my own, Akum."],
	"ichi>aizon": ["Aizon! This ends now!", "You were always part of my plan."],
	"aizon>ichi": ["Show me how far you have come.", "Far enough to beat you!"],
	"uryo>ichi": ["A Quincy doesn't lose to a Soul Reaper.", "Still keeping score, Uryo?"],
	"jotar>dyo": ["Your time's up, Dyo.", "Oh? You're approaching me?"],
	"dyo>jotar": ["I'll crush you, Jotar!", "Yare yare... let's finish this."],
	"goj>yuj": ["Let me see that cursed energy.", "Today I beat you, sensei!"],
	"yuj>goj": ["Sensei, I'm not holding back!", "Good. Neither am I."],
	"megu>yuj": ["Don't go easy on me, Yuj.", "Wasn't planning to!"],
	"lufi>gok": ["You're strong! Let's fight!", "Haha! Rubber versus ki!"],
	"thundr>capt": ["Let us see if you are worthy.", "I can do this all day."],
	"capt>thundr": ["No more talk, Thundr.", "Then let the storm speak!"],
	"spydr>batz": ["Nice cape. Wanna trade?", "I don't do jokes."],
	"batz>spydr": ["Stay out of my city.", "Your city? I'm just passing through!"],
	"kazma>subaro": ["Another isekai guy? Lame.", "At least I don't steal panties!"],
	"subaro>kazma": ["I'll win, no matter how many tries!", "Luck beats tries, buddy."],
	"frierin>rimiru": ["Your mana is... strange.", "I could say the same about you."],
	"rimiru>frierin": ["Let's see whose magic wins.", "Zoltraak doesn't care whose."],
	"quotuk>grak": ["You again, big guy?", "GRAK REMEMBER YOU."],
	"grak>quotuk": ["GRAK WIN THIS TIME.", "We'll see about that."],
	"klakla>pipmo": ["Klak! Tiny one!", "Pip! Who are you calling tiny?"],
	"pipmo>klakla": ["Pip pip! Rematch!", "Klak klak!"],
	"fentuk>rango": ["Draw your weapon.", "I was born ready, partner."],
	"rango>fentuk": ["This town ain't big enough.", "Then I'll clear some room."],
	"bomba>plopo": ["Stand back, blob!", "Blub? Blub blub!"],
	"plopo>bomba": ["Plop! Plop!", "Ugh, not the slime again."],
	"kririn>gok": ["Gok! Let's see how strong you've got!", "Kririn! Don't hold back!"],
	"usoppu>lufi": ["I won't lose to you, Lufi!", "Shishishi! Come on, Usoppu!"],
	"zenitzu>kazma": ["I'm gonna die! You too?", "Probably, yeah."],
	"robin>batz": ["Time to prove I'm ready, Batz.", "You're not ready."],
}


static func rival_of(id: StringName) -> StringName:
	return RIVALS.get(id, &"")


## The two lines for a rivals' face-off (empty if these two aren't rivals).
static func rival_lines(first: StringName, second: StringName) -> Array:
	return RIVAL_LINES.get("%s>%s" % [first, second], [])
