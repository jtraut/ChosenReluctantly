class_name FormulatedRoute
extends RefCounted
## SIM2a-2: the "formulated" bot's route. Pure over a map, the path so far, HP, gold and the deck (card ids), so a test feeds it a hand-built map. No random draws.
## At every node pick the bot re-scores each whole path that starts with the nodes it has walked and takes the first node of the best one. A path's score is a list
## compared from the first entry (lexicographic), all counted over the nodes still ahead (the fixed mini-boss or boss at the end is the same on every path):
##   1. rest     HP under REST_BELOW_HP: a rest within the next REST_LOOKAHEAD nodes, the nearer the better (0 when HP is fine or none is near).
##   2. merchant gold of MERCHANT_MIN_GOLD or more (the cheapest card): the path holds a merchant (1), else 0. The stock is unknown until the visit, so this is "there is gold to spend".
##   3. elite    HP at least ELITE_MIN_HP and the deck's build share at least ELITE_MIN_BUILD ("strong"): + the elites on the path; otherwise minus them.
##   4. growth   RELIC_WEIGHT per relic room, COMBAT_WEIGHT per combat, EVENT_WEIGHT per event.
## Ties go to the path listed first by MapGraph.all_paths (lowest columns first), so the same state always picks the same node.
## The deck's build share is the share of its cards that belong to the deck's most common status (a card belongs when it applies the status to enemies or to the caster, or
## needs it to pay off). It reads card data through DraftPolicy.read_card, never ids.

const THRESHOLDS: Dictionary = {
	"REST_BELOW_HP": 0.55,
	"REST_LOOKAHEAD": 3,
	"MERCHANT_MIN_GOLD": 55,
	"ELITE_MIN_HP": 0.70,
	"ELITE_MIN_BUILD": 0.25,
	"RELIC_WEIGHT": 3,
	"COMBAT_WEIGHT": 2,
	"EVENT_WEIGHT": 1,
}


## The share (0..1) of the deck that belongs to its most common status.
static func build_share(deck_ids: Array[String]) -> float:
	if deck_ids.is_empty():
		return 0.0
	var members: Dictionary = {}
	for card_id: String in deck_ids:
		var read: Dictionary = DraftPolicy.read_card(CardDatabase.get_card(card_id))
		var tokens: Dictionary = {}
		for key: String in (read["provides"] as Array):
			if key.begins_with("status:") or key.begins_with("self:"):
				tokens[key.get_slice(":", 1)] = true
		for key: String in (read["needs"] as Array):
			if key.begins_with("status:"):
				tokens[key.get_slice(":", 1)] = true
		for token: Variant in tokens.keys():
			members[token] = int(members.get(token, 0)) + 1
	var best: int = 0
	for token: Variant in members.keys():
		best = maxi(best, int(members[token]))
	return float(best) / float(deck_ids.size())


## True when the bot takes elites: HP and the deck's build share are both at their bars.
static func is_strong(hp_fraction: float, build: float) -> bool:
	return hp_fraction >= float(THRESHOLDS["ELITE_MIN_HP"]) and build >= float(THRESHOLDS["ELITE_MIN_BUILD"])


## The score list of the nodes still ahead (their type ids, in order). `strong` comes from is_strong.
static func score_types(types: Array[String], hp_fraction: float, gold: int, strong: bool) -> Array[int]:
	var rest_term: int = 0
	if hp_fraction < float(THRESHOLDS["REST_BELOW_HP"]):
		var window: int = int(THRESHOLDS["REST_LOOKAHEAD"])
		for i: int in range(mini(window, types.size())):
			if types[i] == "rest":
				rest_term = window - i
				break
	var merchant_term: int = 1 if gold >= int(THRESHOLDS["MERCHANT_MIN_GOLD"]) and types.has("merchant") else 0
	var elites: int = 0
	var growth: int = 0
	for type_id: String in types:
		match type_id:
			"elite":
				elites += 1
			"relic_room":
				growth += int(THRESHOLDS["RELIC_WEIGHT"])
			"combat":
				growth += int(THRESHOLDS["COMBAT_WEIGHT"])
			"event":
				growth += int(THRESHOLDS["EVENT_WEIGHT"])
	return [rest_term, merchant_term, elites if strong else -elites, growth] as Array[int]


## The next node id the bot takes, given the nodes walked so far in this act (`path`; empty at an act's first pick). -1 when no path continues `path`.
static func pick(map: Dictionary, path: Array[int], hp_fraction: float, gold: int, deck_ids: Array[String]) -> int:
	var strong: bool = is_strong(hp_fraction, build_share(deck_ids))
	var best_next: int = -1
	var best_score: Array[int] = []
	for route: Array in MapGraph.all_paths(map):
		if route.size() <= path.size():
			continue
		var matches: bool = true
		for i: int in range(path.size()):
			if int(route[i]) != path[i]:
				matches = false
				break
		if not matches:
			continue
		var types: Array[String] = []
		for i: int in range(path.size(), route.size() - 1):  # the last node (mini-boss or boss) is on every path
			types.append(String(MapGraph.node(map, int(route[i])).get("type", "")))
		var score: Array[int] = score_types(types, hp_fraction, gold, strong)
		if best_next == -1 or _greater(score, best_score):
			best_score = score
			best_next = int(route[path.size()])
	return best_next


## `walked` plus the lowest-column continuation to the act's end (MapGraph's first-route step from the last node). The bot replans at every pick, so the tail is only a placeholder
## that gives the run loop a full-length route to index.
static func fill_route(map: Dictionary, walked: Array[int]) -> Array[int]:
	var route: Array[int] = walked.duplicate()
	if route.is_empty():
		return route
	var next: Dictionary = MapGraph.adjacency(map)
	var boss: int = MapGraph.boss_id(map)
	var id: int = route[route.size() - 1]
	while id != boss:
		var options: Array[int] = next.get(id, [] as Array[int])
		if options.is_empty():
			break
		id = options[0]
		route.append(id)
	return route


static func _greater(a: Array[int], b: Array[int]) -> bool:
	for i: int in range(mini(a.size(), b.size())):
		if a[i] != b[i]:
			return a[i] > b[i]
	return false
