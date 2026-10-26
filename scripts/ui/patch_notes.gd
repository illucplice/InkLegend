class_name PatchNotes
extends RefCounted
## What changed in each version, newest first, for the in-game Patch Notes screen.
## Add a new entry at the top whenever something ships.

const NOTES := [
	{"version": "v0.2", "title": "Legends Arrive", "notes": [
		"New Mythic fighter Frierin: throw a mana orb, then press while it flies to drop a Zoltraak beam (body hits only). Her special lifts her into the sky to rain bursting mana spheres over every wall. Mana Release at 50 HP: a barrier blocks a quarter of every enemy hit, the drop beam bursts wide, and each miss lengthens her aim guide a step (at full it shows the whole path and drop point, then resets).",
		"New Mythic fighter Aizon: his basic is a sphere of Reiatsu you can detonate mid-air; every two hits put the enemy under Spiritual Pressure, so their next throw is wobbly. Kyoka Suigetsu adds a stack of pressure and swaps places just before a throw hits, so the thrower takes their own hit; it lasts until it triggers, steals their buffs and heals him 5. Below 40 HP he evolves with butterfly wings and a stronger Hado: the enemy's aim stays wobbly for the rest of the game, and every two hits crush them for damage over 3 turns and take away their aim guide for a turn.",
		"New Mythic fighter Rimiru: his Slime Spear (a long, sharp spear of slime) arcs like a throw, and a press while it flies recalls it straight back through anyone in the way. Hits leave Predator Marks (three in a row burst for 12; a miss wipes them) and build Adaptation: each stack (up to 3) adds 3% to his basic throws and takes 4% off every hit he takes; a miss fades one. Beelzebuth throws a black orb that opens a devouring vortex, dragging the enemy in, eating their shield and marks, then collapsing for 30. Predator: when it hits, he devours their weapon and throws it at once as a free extra throw, 5% harder (not when Kyoka Suigetsu turns it on him). Slime Regeneration: the first blow that would knock him out leaves him on 1 HP, free of every ailment. Below 40 HP he becomes the Shadow Sovereign, rising on great wings in his cracked mask: faster Gluttony's Maw blades (20), three marks snap shut for 20 and heal him 3, Adaptation goes to 4 stacks (+4% basic damage and 5% less damage taken each), three basic hits in a row arm Gluttony to devour the enemy's next basic throw as it nears him, and Beelzebuth hits for 40. Fatality: Imaginary Space.
",
		"New Rare fighters: Kririn (precise ki shots that bend in on the enemy; Destructo Disc slices straight through obstacles), Usoppu (Pop Green pellets that burst; Impact Dial blasts the enemy far back), Zenitzu (throws his sword; Sleeping Thunder sends him to sleep for 3 throws of lightning-fast Thunder Breathing slashes) and Robin (Birdarangs that curve back; a Smoke Pellet leaves the enemy without an aim guide). Each has their own fatality and rival.",
		"New Legendary fighters: Jotar and Dyo (time stop with stands), Kazma (lucky throws and a shield), Subaro (Emilla's icicles from the sky).",
		"New Epic heroes: Thundr, Capt, Spydr and Batz.",
		"Tiers are now Common, Rare, Epic, Legendary and Mythic. Bomba and Pipmo moved up to Rare.",
		"Bigger maps where the fighters often stand on ledges at different heights (one high, one low) and are sometimes much further apart; aim can now go down to -15 degrees.",
		"Specials like time stop, Kyoka Suigetsu and blessings happen the moment you press the button.",
		"You can now use your special for the FINISH THEM throw, and a special or Kyoka Suigetsu knockout goes straight to the fatality.",
		"Every fighter has a victory pose, one for a normal win and one after a fatality.",
		"Target Practice has a Test Fatality button.",
		"A chime plays when your special is ready, plus character voices, crowd cheers and per-map music.",
		"Ichi now fires Getsuga Tensho slashes from Zangetsu (blue-white, black and red with his Hollow mask on), doing 24 / 42; his special is a huge Getsuga Tensho that tears straight through obstacles and mountains.",
		"Specials that hit the ground now blast a crater and splash anyone nearby.",
		"New Arcade mode: five fights that get harder, then your fighter's rival (Gok and Egita, Ryo and Akum, Ichi and Aizon, Jotar and Dyo and more), and rivals have their own face-off lines in every mode.",
		"Tournaments are now 13 rounds, climbing from Common to Mythic opponents as the AI gets harder, then your Champion shadow. Every round shows and pays its own prize, and the champion wins a Golden chest.",
		"New 2v2 Tag mode, against the AI or a friend on the same device: each side picks two fighters. The partners take turns, swapping in automatically after every turn, the one resting gets a little health back, and when a fighter is knocked out their partner jumps in. The match (and the fatality) comes when a whole team is down.",
		"New Survival mode: one fighter against endless opponents on one health bar. Each win gives back 30 health and pays more coins (with big bonuses at 10, 25 and 50 wins), the AI gets harder as your streak grows, and your best run is saved.",
		"Chaos mutators: switch Chaos on from the map screen for a random twist (Low Gravity, Giant Weapons, Storm, Sudden Death, Overcharged, Bouncy or Glass Cannon), and every daily challenge now comes with its own mutator.",
		"New Boss Rush: Frierin in Mana Release, Dyo, evolved Aizon and the Shadow Sovereign back to back, each already powered up. No retries: lose and the run is over. Clearing it wins a Golden chest.",
		"Fighter mastery: every match with a fighter earns them mastery XP. Levels unlock +10% coins, new colour schemes (pick them with Colours on the fighter screen), a signature trail and, at level 5, a golden Master aura.",
		"The fighter screen is sorted by tier, with each fighter's tier on their card. Style opens a fighter's look: equip the colour schemes mastery unlocks, and give each fighter their own trail (any Shop trail you own, or their signature trail).",
		"Fatality Gallery: every fatality you land is saved and can be replayed from the new Fatalities tab.",
		"Finished a tournament or arcade? Play again straight from the result screen.",
		"Sounds: Aizon's pressure and evolution, time stop and other big moments have their own sounds now; the knockout sound only plays on knockouts.",
		"Vs AI: choose your opponent (any fighter, even ones you don't own yet) or leave it to chance.",
		"Game feel: headshots freeze the frame for a blink, damage numbers grow and run hot with bigger hits, the crowd jumps up for big moments, and a flawless win gets a PERFECT!",
		"Gok's Mega Wave, Egita's Big Bang Attack (now charged in front of his outstretched hand), Ryo's Shinku Hadoken and Akum's Gou Hadoken now zoom in on the hands as the energy charges, and so does Ryo's fatality. Shinku and Gou Hadoken hit softer, with smaller blasts.",
		"Every special can now land: Lufi's Gum Barrage follows its aim guide instead of flying long, and Hollow Purple no longer passes through an enemy it drags in, or pulls them off their ledge.",
		"Victory poses: Aizon floats facing you with his arms spread wide after a fatality, and Frierin dozes off and falls asleep.",
		"Fixes: a time-stop special used on the FINISH THEM throw now lands and plays the fatality; Dyo's knife storm hits harder, with 30% critical hits per knife; special meters charge once per turn (no more Klakla special spam); Kyoka Suigetsu now hurts the attacker with explosions too; homing throws and Frierin's drop work on the finishing throw; time stop always ends in practice; the game no longer stays slow after a fatality.",
	]},
	{"version": "v0.1", "title": "Ink Legends", "notes": [
		"The first release: turn-based stickman throwing battles, VS AI, 1v1, tournaments, Target Practice and daily challenges.",
		"Chests, coins, fighter levels, trophies and fatalities.",
	]},
]
