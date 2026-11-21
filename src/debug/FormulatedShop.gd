class_name FormulatedShop
extends RefCounted
## SIM2a-2: the "formulated" bot's merchant and removal choices. Pure over the choice model's options, the run state's deck, relics and gold, and DraftPolicy's scorer. No random draws.
##
## One conversion puts every item on one scale, a "margin" (how far over its bar the item is; only margins above 0 are bought, the biggest first, the first of equal margins wins):
##   card      DraftPolicy.score_card - DraftPolicy.skip_threshold(deck size)           (the bar a reward card has to clear)
##   relic     DraftPolicy.score_relic - RELIC_BUY_MIN; one that needs a give-up must also beat the lowest-scoring held relic by SWAP_MARGIN (the smaller margin counts)
##   removal   REMOVE_BELOW - (the lowest-scoring card's score), only above REMOVE_MIN_DECK cards; a curse in the deck is always worth REMOVE_CURSE
## With nothing over its bar and gold of at least REROLL_MIN_GOLD, a free reroll is taken (the gold is kept); then the bot leaves.
## A removal takes the lowest-scoring card of those the list allows (a curse first), each card scored against the deck without that copy.

const TABLE: Dictionary = {
	"RELIC_BUY_MIN": 0.5,
	"SWAP_MARGIN": 0.5,
	"REMOVE_BELOW": 0.6,
	"REMOVE_MIN_DECK": 15,
	"REMOVE_CURSE": 5.0,
	"REROLL_MIN_GOLD": 55,
}


static func _deck_cards(deck_ids: Array[String]) -> Array[Dictionary]:
	var deck: Array[Dictionary] = []
	for card_id: String in deck_ids:
		deck.append(CardDatabase.get_card(card_id))
	return deck


## The score of one deck card against the rest of the deck (one copy of it taken out).
static func card_value(card_id: String, deck_ids: Array[String]) -> float:
	var rest: Array[String] = deck_ids.duplicate()
	rest.erase(card_id)
	return DraftPolicy.score_card(CardDatabase.get_card(card_id), DraftPolicy.profile(_deck_cards(rest)))


## [card id, score] of the deck's lowest-scoring card, a curse counted lowest (score -INF); ["", INF] for an empty deck. The first of equal scores (deck order) wins.
static func lowest_card(deck_ids: Array[String]) -> Array:
	var worst_id: String = ""
	var worst: float = INF
	var seen: Dictionary = {}
	for card_id: String in deck_ids:
		if seen.has(card_id):
			continue
		seen[card_id] = true
		var value: float = -INF if CardSchema.is_curse(CardDatabase.get_card(card_id)) else card_value(card_id, deck_ids)
		if value < worst:
			worst = value
			worst_id = card_id
	return [worst_id, worst]


## The option id for a PENDING_MERCHANT choice.
static func shop_choice(options: Array, state: RunState, free_size: int, no_removal: bool = false) -> String:
	var deck_ids: Array[String] = state.deck
	var deck: Array[Dictionary] = _deck_cards(deck_ids)
	var prof: Dictionary = DraftPolicy.profile(deck)
	var basic_plan: bool = DraftPolicy.deck_plays_basic_attacks(deck)
	var bar: float = DraftPolicy.skip_threshold(deck_ids.size(), free_size)
	var worst_relic: float = INF
	for relic_id: String in state.relics:
		worst_relic = minf(worst_relic, DraftPolicy.score_relic(RelicDatabase.get_relic(relic_id), prof, basic_plan))
	var best_id: String = ""
	var best_margin: float = 0.0
	var leave: String = ""
	var reroll: String = ""
	for option: Variant in options:
		var entry: Dictionary = option
		var margin: float = -INF
		match String(entry.get("kind", "")):
			"buy_card":
				if bool(entry.get("enabled", false)):
					margin = DraftPolicy.score_card(CardDatabase.get_card(String(entry["card_id"])), prof) - bar
			"buy_relic":
				if bool(entry.get("enabled", false)):
					var value: float = DraftPolicy.score_relic(RelicDatabase.get_relic(String(entry["id"]).get_slice(":", 1)), prof, basic_plan)
					margin = value - float(TABLE["RELIC_BUY_MIN"])
					if bool(entry.get("needs_swap", false)):
						margin = minf(margin, value - worst_relic - float(TABLE["SWAP_MARGIN"]))
			"buy_removal":
				if not no_removal and bool(entry.get("enabled", false)) and deck_ids.size() > int(TABLE["REMOVE_MIN_DECK"]):
					var low: Array = lowest_card(deck_ids)
					margin = float(TABLE["REMOVE_CURSE"]) if float(low[1]) == -INF else float(TABLE["REMOVE_BELOW"]) - float(low[1])
			"reroll":
				if bool(entry.get("enabled", false)):
					reroll = String(entry["id"])
			"back":
				leave = String(entry["id"])
		if margin > best_margin:
			best_margin = margin
			best_id = String(entry["id"])
	if best_id != "":
		return best_id
	if reroll != "" and state.gold >= int(TABLE["REROLL_MIN_GOLD"]):
		return reroll
	return leave


## The option id to take from a removal list (a merchant's, a rest's or an event's: options of kind "remove"): a curse first, else the lowest-scoring card the list allows;
## the list's back option when none can go.
static func removal_choice(options: Array, state: RunState) -> String:
	var back: String = ""
	var best_id: String = ""
	var best: float = INF
	for option: Variant in options:
		var entry: Dictionary = option
		match String(entry.get("kind", "")):
			"back":
				back = String(entry["id"])
			"remove":
				if not bool(entry.get("enabled", false)):
					continue
				if bool(entry.get("curse", false)):
					return String(entry["id"])
				var value: float = card_value(String(entry["card_id"]), state.deck)
				if value < best:
					best = value
					best_id = String(entry["id"])
	return best_id if best_id != "" else back
