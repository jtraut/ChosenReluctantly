class_name LoadoutDraft
extends RefCounted
## A loadout being edited (3d sitting C): the model behind the editor screen (the bare one now, ux's in sitting E). A pure RefCounted over the deck APIs and the databases,
## so the screens stay thin and a test needs no scene.
##
## What the editor shows and calls:
##   collection_by_slot(character_id)  every card the class may collect, grouped by slot: [{slot_type, slot_name, cards: [{id, name, slot_type, rarity, availability, unlock, flavor}]}]
##   add_card(id) / remove_card(id)    a `starter` card goes in the deck (at most `max_copies`, at most `deck_max` cards); a `reward` or `locked` card goes on the plan (one each).
##                                     Both return "" or the reason it was refused.
##   copies(id), in_plan(id)           what the draft holds now
##   slot_counts()                     the live "Movement 4/3": [{slot_type, display_name, count, required, short}] from the deck rules (unique cards per slot)
##   size_text()                       "Deck 15 of 15-20"
##   problems()                        every reason it can't be saved yet, in the checker's own words; empty means saveable
##   save(store)                       saves into `slot` of the store; returns the problems (empty = saved)
##   starter_relic_options()           the class's starter relics: [{id, name, rule_text}] (set `starter_relic` to one, or "" for none)

var character_id: String = ""
## The store slot this draft saves to (0-based).
var slot: int = 0
var loadout_name: String = ""
var deck: Array[String] = []
var plan: Array[String] = []
## A starter relic id, or "" for none.
var starter_relic: String = ""


## A new, empty draft for a class, to be saved in `slot`.
static func create(for_character: String, for_slot: int) -> LoadoutDraft:
	var draft := LoadoutDraft.new()
	draft.character_id = for_character
	draft.slot = for_slot
	return draft


## A draft that starts as the class's preset deck (the quickest way to a legal deck).
static func from_preset(for_character: String, for_slot: int) -> LoadoutDraft:
	var draft: LoadoutDraft = create(for_character, for_slot)
	draft.deck.assign(CharacterDatabase.starting_deck(for_character))
	return draft


## A draft of a saved (usable) entry.
static func from_entry(for_character: String, for_slot: int, entry: Dictionary) -> LoadoutDraft:
	var draft: LoadoutDraft = create(for_character, for_slot)
	draft.loadout_name = String(entry.get("name", ""))
	draft.deck.assign(entry.get("deck", []))
	draft.plan.assign(entry.get("plan", []))
	draft.starter_relic = String(entry.get("starter_relic", ""))
	return draft


## Every collectable card of the class, grouped by slot in slot order, cards by name.
static func collection_by_slot(for_character: String) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	var names: Dictionary = DeckRules.slot_names_from_database()
	for slot_id: Variant in SlotTypeDatabase.known_ids():
		var cards: Array[Dictionary] = []
		for card_id: String in LoadoutCollection.collection(for_character):
			var card: Dictionary = CardDatabase.get_card(card_id)
			if String(card.get("slot_type", "")) != String(slot_id):
				continue
			cards.append({"id": card_id, "name": String(card.get("name", card_id)), "slot_type": String(slot_id), "rarity": CardSchema.rarity_of(card),
					"availability": LoadoutCollection.availability(card_id), "unlock": CardSchema.unlock_text_of(card), "flavor": String(card.get("flavor_text", ""))})
		cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["name"]) < String(b["name"]))
		groups.append({"slot_type": String(slot_id), "slot_name": String(names.get(slot_id, slot_id)), "cards": cards})
	return groups


func copies(card_id: String) -> int:
	return deck.count(card_id)


func in_plan(card_id: String) -> bool:
	return plan.has(card_id)


## Adds a card: to the deck when it is a `starter` card, to the plan when it is `reward` or `locked`. "" when it went in, else why not.
func add_card(card_id: String) -> String:
	if not LoadoutCollection.collection(character_id).has(card_id):
		return "'%s' is not in this class's collection" % card_id
	if LoadoutCollection.availability(card_id) == CardSchema.AVAILABILITY_STARTER:
		if deck.count(card_id) >= LoadoutRules.max_copies():
			return "at most %d copies of a card" % LoadoutRules.max_copies()
		if deck.size() >= LoadoutRules.deck_max():
			return "the deck is full (%d cards)" % LoadoutRules.deck_max()
		deck.append(card_id)
		return ""
	if plan.has(card_id):
		return "already on the plan"
	plan.append(card_id)
	return ""


## Takes one copy out of the deck, or the card off the plan. "" when something was removed.
func remove_card(card_id: String) -> String:
	if deck.has(card_id):
		deck.erase(card_id)  # Array.erase removes the first match only: one copy
		return ""
	if plan.has(card_id):
		plan.erase(card_id)
		return ""
	return "'%s' is not in the loadout" % card_id


## The live per-slot counts from the deck rules ("Movement 4/3"): the checker's own numbers.
func slot_counts() -> Array[Dictionary]:
	return LoadoutCheck.deck_check(deck).slots


## "Deck 16 of 15-20".
func size_text() -> String:
	return "Deck %d of %d-%d" % [deck.size(), LoadoutRules.deck_min(), LoadoutRules.deck_max()]


## The entry as it would be saved.
func entry() -> Dictionary:
	return LoadoutCheck.make_entry(loadout_name.strip_edges(), deck, plan, starter_relic)


## Every reason this draft can't be saved yet; empty means it can.
func problems() -> Array[String]:
	return LoadoutCheck.entry_problems(character_id, entry())


func can_save() -> bool:
	return problems().is_empty()


## Saves into the draft's slot. Returns the problems (empty = saved); nothing is written while there are any.
func save(store: LoadoutStore) -> Array[String]:
	return store.save_entry(character_id, slot, entry())


## The class's starter relics for the picker: [{id, name, rule_text}].
func starter_relic_options() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for relic_id: String in LoadoutCollection.starter_relics(character_id):
		var relic: Dictionary = RelicDatabase.get_relic(relic_id)
		out.append({"id": relic_id, "name": String(relic.get("name", relic_id)), "rule_text": String(relic.get("rule_text", ""))})
	return out
