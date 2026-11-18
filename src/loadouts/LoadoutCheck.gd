class_name LoadoutCheck
extends RefCounted
## Rule checks for one loadout (3d, GDD sections 4 and 9). Pure over plain data: every function takes the character id and reads the shipped
## databases, and the unique-card rules go through DeckRules/DeckCheck only (change E), so the editor shows the checker's own counts and messages.
##
## An entry is {name: String, deck: Array[String], plan: Array[String], starter_relic: String ("" = none), passive_allocation: {version: 1}}.

const PASSIVE_VERSION := 1
const ENTRY_KEYS: Array[String] = ["name", "deck", "plan", "starter_relic", "passive_allocation"]


## A fresh, normalised entry. `starter_relic` "" means none.
static func make_entry(entry_name: String, deck: Array, plan: Array = [], starter_relic: String = "") -> Dictionary:
	var deck_ids: Array[String] = []
	for id: Variant in deck:
		deck_ids.append(String(id))
	var plan_ids: Array[String] = []
	for id: Variant in plan:
		plan_ids.append(String(id))
	return {"name": entry_name, "deck": deck_ids, "plan": plan_ids, "starter_relic": starter_relic, "passive_allocation": {"version": PASSIVE_VERSION}}


## The unique-card check of a deck, from the deck rules (live counts "Movement 4/3" and the shortfall messages).
static func deck_check(deck: Array) -> DeckCheck:
	return DeckRules.check_shipped(deck)


## All problems with a starting deck, as messages for the editor. Empty means it may be saved. Size and copies are counted with copies;
## the per-slot and group minimums are the DeckRules ones, worded by DeckCheck.
static func deck_problems(character_id: String, deck: Array) -> Array[String]:
	var problems: Array[String] = []
	var minimum: int = LoadoutRules.deck_min()
	var maximum: int = LoadoutRules.deck_max()
	if deck.size() < minimum:
		problems.append("Deck has %d cards, needs at least %d" % [deck.size(), minimum])
	elif deck.size() > maximum:
		problems.append("Deck has %d cards, at most %d" % [deck.size(), maximum])
	var seen: Dictionary = {}
	var starters: Array[String] = LoadoutCollection.starter_cards(character_id)
	var all_known: Array[String] = LoadoutCollection.collection(character_id)
	for entry: Variant in deck:
		if typeof(entry) != TYPE_STRING:
			problems.append("Deck holds an entry that is not a card id")
			continue
		var card_id: String = entry
		seen[card_id] = int(seen.get(card_id, 0)) + 1
	var ids: Array = seen.keys()
	ids.sort()
	for key: Variant in ids:
		var id: String = String(key)
		if not CardDatabase.has_card(id):
			problems.append("Unknown card '%s'" % id)
		elif CardSchema.is_curse(CardDatabase.get_card(id)):
			problems.append("'%s' is a curse and cannot be in a loadout" % id)
		elif not all_known.has(id):
			problems.append("'%s' is not in this class's collection" % id)
		elif not starters.has(id):
			problems.append("'%s' is %s only, not a starter card" % [id, LoadoutCollection.availability(id)])
		if int(seen[key]) > LoadoutRules.max_copies():
			problems.append("'%s' appears %d times, at most %d copies" % [id, int(seen[key]), LoadoutRules.max_copies()])
	problems.append_array(deck_check(deck).problems)
	return problems


## Problems with a plan (reward and locked cards only, one of each). Empty means fine.
static func plan_problems(character_id: String, plan: Array) -> Array[String]:
	var problems: Array[String] = []
	var plan_cards: Array[String] = LoadoutCollection.plan_cards(character_id)
	var seen: Dictionary = {}
	for entry: Variant in plan:
		if typeof(entry) != TYPE_STRING:
			problems.append("Plan holds an entry that is not a card id")
			continue
		var id: String = entry
		if seen.has(id):
			problems.append("Plan lists '%s' twice" % id)
		seen[id] = true
		if not CardDatabase.has_card(id):
			problems.append("Plan: unknown card '%s'" % id)
		elif CardSchema.is_curse(CardDatabase.get_card(id)):
			problems.append("Plan: '%s' is a curse" % id)
		elif not plan_cards.has(id):
			problems.append("Plan: '%s' is not a reward or locked card of this class" % id)
	return problems


static func name_problems(entry_name: Variant) -> Array[String]:
	var problems: Array[String] = []
	if typeof(entry_name) != TYPE_STRING or String(entry_name).strip_edges().is_empty():
		problems.append("A loadout needs a name")
	elif String(entry_name).strip_edges().length() > LoadoutRules.name_max_length():
		problems.append("The name is over %d characters" % LoadoutRules.name_max_length())
	return problems


## A starter relic id or "" (none). Anything else must be one of the character's starter relics.
static func relic_problems(character_id: String, relic_id: Variant) -> Array[String]:
	var problems: Array[String] = []
	if typeof(relic_id) != TYPE_STRING:
		problems.append("starter_relic must be a relic id or empty")
	elif not String(relic_id).is_empty() and not LoadoutCollection.is_starter_relic(character_id, String(relic_id)):
		problems.append("'%s' is not a starter relic for this class" % String(relic_id))
	return problems


## Every problem with a whole entry read from a file or built by the editor: its shape, then the name, deck, plan and relic rules.
static func entry_problems(character_id: String, entry: Variant) -> Array[String]:
	var problems: Array[String] = []
	if typeof(entry) != TYPE_DICTIONARY:
		problems.append("the entry is not an object")
		return problems
	var data: Dictionary = entry
	for key: Variant in data.keys():
		if not ENTRY_KEYS.has(String(key)):
			problems.append("unknown key '%s'" % str(key))
	for key: String in ENTRY_KEYS:
		if not data.has(key):
			problems.append("missing '%s'" % key)
	if not problems.is_empty():
		return problems
	problems.append_array(name_problems(data["name"]))
	if typeof(data["deck"]) != TYPE_ARRAY:
		problems.append("deck must be a list of card ids")
	else:
		problems.append_array(deck_problems(character_id, data["deck"]))
	if typeof(data["plan"]) != TYPE_ARRAY:
		problems.append("plan must be a list of card ids")
	else:
		problems.append_array(plan_problems(character_id, data["plan"]))
	problems.append_array(relic_problems(character_id, data["starter_relic"]))
	var passive: Variant = data["passive_allocation"]
	if typeof(passive) != TYPE_DICTIONARY or not UserJson.is_whole((passive as Dictionary).get("version")) or int((passive as Dictionary)["version"]) < 1:
		problems.append("passive_allocation must be an object with a whole-number version")
	return problems


## A clean copy of a valid entry (floats from JSON turned into ints, ids into strings). Call only when entry_problems is empty.
static func normalised(entry: Dictionary) -> Dictionary:
	var passive: Dictionary = (entry["passive_allocation"] as Dictionary).duplicate(true)
	passive["version"] = int(passive["version"])
	var result: Dictionary = make_entry(String(entry["name"]).strip_edges(), entry["deck"], entry["plan"], String(entry["starter_relic"]))
	result["passive_allocation"] = passive
	return result
