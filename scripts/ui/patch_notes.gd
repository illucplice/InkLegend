class_name PatchNotes
extends RefCounted
## What changed in each version, newest first, for the in-game Patch Notes screen.
## Add a new entry at the top whenever something ships.

const NOTES := [
	{"version": "v0.2", "title": "Legends Arrive", "notes": [
		"New Mythic fighter Frierin: throw a mana orb, then press while it flies to drop a Zoltraak beam (body hits only). Her special lifts her into the sky to rain bursting mana spheres over every wall. Mana Release at 50 HP: a barrier blocks a quarter of every enemy hit, the drop beam bursts wide, and each miss lengthens her aim guide a step (at full it shows the whole path and drop point, then resets).",
		"New Mythic fighter Aizon: his basic is a sphere of Reiatsu you can detonate mid-air; every two hits put the enemy under Spiritual Pressure, so their next throw is wobbly. Kyoka Suigetsu adds a stack of pressure and swaps places just before a throw hits, so the thrower takes their own hit; it lasts until it triggers, steals their buffs and heals him 5. Below 40 HP he evolves with butterfly wings and a stronger Hado: the enemy's aim stays wobbly for the rest of the game, and every two hits crush them for damage over 3 turns and take away their aim guide for a turn.",
		"New Legendary fighters: Jotar and Dyo (time stop with stands), Kazma (lucky throws and a shield), Subaro (Emilla's icicles from the sky).",
		"New Epic heroes: Thundr, Capt, Spydr and Batz.",
		"Tiers are now Common, Rare, Epic, Legendary and Mythic. Bomba and Pipmo moved up to Rare.",
		"Bigger maps with mountains between the fighters; aim can now go down to -15 degrees.",
		"Specials like time stop, Kyoka Suigetsu and blessings happen the moment you press the button.",
		"You can now use your special for the FINISH THEM throw, and a special or Kyoka Suigetsu knockout goes straight to the fatality.",
		"Every fighter has a victory pose, one for a normal win and one after a fatality.",
		"Target Practice has a Test Fatality button.",
		"A chime plays when your special is ready, plus character voices, crowd cheers and per-map music.",
		"Ichi now fires Getsuga Tensho slashes from Zangetsu (blue-white, black and red with his Hollow mask on), doing 24 / 42; his special is a huge Getsuga Tensho that tears straight through obstacles and mountains.",
		"Specials that hit the ground now blast a crater and splash anyone nearby.",
		"Fixes: a time-stop special used on the FINISH THEM throw now lands and plays the fatality; Dyo's knife storm hits harder, with 30% critical hits per knife; special meters charge once per turn (no more Klakla special spam); Kyoka Suigetsu now hurts the attacker with explosions too; homing throws and Frierin's drop work on the finishing throw; time stop always ends in practice; the game no longer stays slow after a fatality.",
	]},
	{"version": "v0.1", "title": "Ink Legends", "notes": [
		"The first release: turn-based stickman throwing battles, VS AI, 1v1, tournaments, Target Practice and daily challenges.",
		"Chests, coins, fighter levels, trophies and fatalities.",
	]},
]
