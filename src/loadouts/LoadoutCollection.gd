class_name LoadoutCollection
extends RefCounted
## What a character may put in a loadout (3d, GDD section 9). Reads the card and relic databases only:
## - the collection is every non-curse card in the character's pools (`RunConfig.cards_in_pools`),
## - the starting deck holds only `starter` cards, the plan holds `reward` and `locked` cards (`CardSchema.availability_of`),
## - the starter relics are the tier 1 relics of the character's pools that list "starter" in `sources`.
## Flipping D52 (which rarities are starter) is a data change in data/cards/, never here.


## Every card id the character may collect, sorted. Curses are not in it.
static func collection(character_id: String) -> Array[String]:
	return RunConfig.cards_in_pools(CharacterDatabase.pools(character_id))


## The collection's `starter` cards: what a starting deck may hold.
static func starter_cards(character_id: String) -> Array[String]:
	return _with_availability(character_id, [CardSchema.AVAILABILITY_STARTER])


## The collection's `reward` and `locked` cards: what a plan may hold.
static func plan_cards(character_id: String) -> Array[String]:
	return _with_availability(character_id, [CardSchema.AVAILABILITY_REWARD, CardSchema.AVAILABILITY_LOCKED])


## A card's availability ("starter", "reward", "locked"; "" for an unknown card or a curse).
static func availability(card_id: String) -> String:
	return CardSchema.availability_of(CardDatabase.get_card(card_id))


## The starter relic ids the character may open a run with, sorted.
static func starter_relics(character_id: String) -> Array[String]:
	var out: Array[String] = []
	var pools: Array[String] = CharacterDatabase.pools(character_id)
	for relic: Dictionary in RelicDatabase.all_relics():
		if is_starter_relic_data(relic) and pools.has(String(relic.get("pool", ""))):
			out.append(String(relic["id"]))
	out.sort()
	return out


static func is_starter_relic(character_id: String, relic_id: String) -> bool:
	return starter_relics(character_id).has(relic_id)


static func is_starter_relic_data(relic: Dictionary) -> bool:
	var sources: Variant = relic.get("sources", [])
	return String(relic.get("rarity", "")) == "tier1" and typeof(sources) == TYPE_ARRAY and (sources as Array).has("starter")


static func _with_availability(character_id: String, wanted: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for card_id: String in collection(character_id):
		if wanted.has(availability(card_id)):
			out.append(card_id)
	return out
