class_name MerchantPolicy
extends RefCounted
## The bot's merchant choices (MAP2-B; wave sim `-Run` with the merchant on). Pure over the choice model's options and the RunState, so a test can drive it
## with plain dictionaries. It draws no random numbers and keeps no state of its own: what it already bought this visit is read from the run's choice log.
##
## Per route policy (RouteBot):
##   relic          relics first (cheapest first, as many as the gold allows), then a card removal, then a card.
##   anything else  (safe, first, random) a card removal, then a card. No relics: those routes are not relic hunters, and `safe` is the brief's
##                  "a removal, then a card".
## A removal or card is bought at most once per visit. The removal picks a card with spare copies first, else any card the deck rules allow.

const RELIC_FIRST := "relic"


## The option id to answer a merchant choice with. `choice` is the model's `choice` (a RunState merchant pending value).
static func choose(choice: String, options: Array, state: RunState, route_policy: String) -> String:
	match choice:
		RunState.PENDING_MERCHANT:
			return _shop(options, state, route_policy)
		RunState.PENDING_MERCHANT_REMOVE:
			return _removal(options)
		RunState.PENDING_MERCHANT_SWAP:
			return RelicPolicy.giveup_choice(options)
	return ""


static func _shop(options: Array, state: RunState, route_policy: String) -> String:
	var steps: Array[String] = ["removal", "card"]
	if route_policy == RELIC_FIRST:
		steps = ["relic", "removal", "card"]
	var leave: String = ""
	for option: Variant in options:
		if String((option as Dictionary).get("kind", "")) == "leave":
			leave = String((option as Dictionary)["id"])
	for step: String in steps:
		var picked: String = ""
		match step:
			"relic":
				picked = _cheapest(options, "buy_relic")
			"removal":
				if _bought_this_visit(state, "merchant_remove") == 0:
					picked = _first_enabled(options, "buy_removal")
			"card":
				if _bought_this_visit(state, "merchant_card") == 0:
					picked = _card(options, state.deck)
		if picked != "":
			return picked
	return leave


static func _bought_this_visit(state: RunState, kind: String) -> int:
	var count: int = 0
	for entry: Dictionary in state.choice_log:
		if String(entry["kind"]) == kind and int(entry["index"]) == state.room_index:
			count += 1
	return count


static func _first_enabled(options: Array, kind: String) -> String:
	for option: Variant in options:
		var entry: Dictionary = option
		if String(entry.get("kind", "")) == kind and bool(entry.get("enabled", false)):
			return String(entry["id"])
	return ""


static func _cheapest(options: Array, kind: String) -> String:
	var best: String = ""
	var best_price: int = 1 << 30
	for option: Variant in options:
		var entry: Dictionary = option
		if String(entry.get("kind", "")) == kind and bool(entry.get("enabled", false)) and int(entry.get("price", 0)) < best_price:
			best = String(entry["id"])
			best_price = int(entry.get("price", 0))
	return best


## A card the deck does not own yet, else the first one on offer.
static func _card(options: Array, deck: Array[String]) -> String:
	var first: String = ""
	for option: Variant in options:
		var entry: Dictionary = option
		if String(entry.get("kind", "")) != "buy_card" or not bool(entry.get("enabled", false)):
			continue
		if first == "":
			first = String(entry["id"])
		if not deck.has(String(entry.get("card_id", ""))):
			return String(entry["id"])
	return first


static func _removal(options: Array) -> String:
	var spare: String = ""
	var any: String = ""
	var back: String = ""
	for option: Variant in options:
		var entry: Dictionary = option
		match String(entry.get("kind", "")):
			"back":
				back = String(entry["id"])
			"remove":
				if bool(entry.get("enabled", false)):
					if any == "":
						any = String(entry["id"])
					if spare == "" and int(entry.get("count", 0)) > 1:
						spare = String(entry["id"])
	return spare if spare != "" else (any if any != "" else back)
