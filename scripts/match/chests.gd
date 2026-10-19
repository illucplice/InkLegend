class_name Chests
extends RefCounted
## Chests bought with coins. Each one rolls a rarity by its odds, then a random fighter
## of that rarity. A fighter you already own turns into coins instead.

const RARITIES := [&"common", &"rare", &"legendary"]
const RARITY_NAMES := {&"common": "Common", &"rare": "Rare", &"legendary": "Legendary"}
const RARITY_COLORS := {&"common": Color(0.75, 0.78, 0.85), &"rare": Color(0.35, 0.6, 1.0), &"legendary": Color(1.0, 0.72, 0.2)}
## Coins paid back for a duplicate.
const DUPLICATE_COINS := {&"common": 50, &"rare": 120, &"legendary": 300}

## id -> {name, price, colour, odds (common, rare, legendary percentages)}.
const KINDS := {
	"wood": {"name": "Wooden chest", "price": 150, "color": Color(0.7, 0.48, 0.28), "odds": [80, 18, 2]},
	"silver": {"name": "Silver chest", "price": 400, "color": Color(0.72, 0.76, 0.85), "odds": [45, 45, 10]},
	"gold": {"name": "Golden chest", "price": 900, "color": Color(1.0, 0.75, 0.22), "odds": [10, 55, 35]},
}
const ORDER := ["wood", "silver", "gold"]


## Picks a rarity using the chest's odds, then a fighter of that rarity (falling back
## to any rarity that has fighters). Pure: give it a seeded rng to make it repeatable.
static func roll(kind: String, roster: Array[FighterData], rng: RandomNumberGenerator) -> FighterData:
	var odds: Array = KINDS[kind]["odds"]
	var pick := rng.randi_range(1, 100)
	var rarity: StringName = RARITIES[0]
	var total := 0
	for i in odds.size():
		total += int(odds[i])
		if pick <= total:
			rarity = RARITIES[i]
			break
	var pool: Array[FighterData] = []
	for fighter in roster:
		if fighter.rarity == rarity:
			pool.append(fighter)
	if pool.is_empty():
		pool = roster.duplicate()
	return pool[rng.randi_range(0, pool.size() - 1)]


## Buys and opens a chest for `save`. Returns {fighter, new (bool), coins (refund)},
## or an empty Dictionary if it can't be afforded.
static func open(kind: String, roster: Array[FighterData], save: Node, rng: RandomNumberGenerator) -> Dictionary:
	var price: int = KINDS[kind]["price"]
	if save.coins < price:
		return {}
	save.coins -= price
	var fighter := roll(kind, roster, rng)
	var is_new: bool = not save.is_unlocked(fighter)
	var refund := 0
	if is_new:
		save.unlocked.append(String(fighter.id))
	else:
		refund = DUPLICATE_COINS.get(fighter.rarity, 50)
		save.coins += refund
	save.save_progress()
	return {"fighter": fighter, "new": is_new, "coins": refund}
