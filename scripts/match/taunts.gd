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
