class_name RewardOffer
extends RefCounted
## Builds a card reward offer (Milestone 3b). Pure and static: every input is a parameter, so a test feeds it
## fixture cards and the shared card database is never touched. It handles card ids and the generic card fields
## (`pool`, `slot_type`, `requires`, status ids in effects); it never looks at what a specific card does.
##
## The offer is seeded from the run seed and the room index (its own stream: it never touches the spawner or
## the player RNG), so the same seed with the same deck gives the same offer. Candidates are sorted by id
## before drawing (directory order is not a guarantee). Cards not yet owned weigh `unowned_weight`, owned ones
## `owned_weight` (data), so duplicates are allowed but rarer. Distinct within an offer.
##
## `requires` (optional card field, checked against the current deck and character):
##   slot_types: [ids]       the deck holds at least one card of each slot type
##   pools: [ids]            the character owns each pool
##   status_sources: [ids]   something in the deck, or an owned element pool, applies each status
##
## The status lean (D43 = B, BD3a): a card you do not own yet that applies status S weighs x (1 + status_lean x n_S), capped at
## status_lean_max, where n_S is the number of cards in the deck that apply S (counted per card, like `requires.status_sources`
## reads effects, but the element pool's own status is not counted: only cards). A card that applies several statuses takes the best
## of them. Cards with no status are untouched. Optional `status_lean_skip_starter` (default false): n_S counts only cards beyond the starting deck. `status_lean` missing or 0 turns the lean off, so a fixture or an old config keeps the old offers.


static func offer_seed(run_seed: int, room_index: int) -> int:
	return (run_seed * 2654435 + room_index * 40503 + 977) & RunState.SEED_LIMIT


## `cards`: all card dicts. `deck`: card ids owned. `pools`: owned pool ids. `pool_defs`: pool id -> definition
## (for element status sources). `rewards`: the run.json `rewards` block. Returns up to offer_size distinct ids.
## `starter`: the run's starting deck. Only read when `rewards.status_lean_skip_starter` is true (see `added_cards`).
## `removed`: card ids pruned from the deck this run (D47 = B, GDD 9): never offered again, even when a copy is still in the deck. If that
## leaves fewer than offer_size candidates the offer is just shorter, and an empty one means no reward screen (see RunChoices.open_for_room).
static func generate(run_seed: int, room_index: int, deck: Array, cards: Array, pools: Array, pool_defs: Dictionary, rewards: Dictionary, starter: Array = [], removed: Array = []) -> Array[String]:
	var by_id: Dictionary = {}
	for card: Variant in cards:
		by_id[String((card as Dictionary).get("id", ""))] = card
	var deck_cards: Array[Dictionary] = []
	for card_id: Variant in deck:
		if by_id.has(String(card_id)):
			deck_cards.append(by_id[String(card_id)])
	var candidates: Array[String] = candidate_ids(cards, pools, deck_cards, pool_defs)
	for gone: Variant in removed:
		candidates.erase(String(gone))
	var unowned_weight: float = float(rewards.get("unowned_weight", 1.0))
	var owned_weight: float = float(rewards.get("owned_weight", 1.0))
	var lean: float = maxf(float(rewards.get("status_lean", 0.0)), 0.0)
	var lean_max: float = maxf(float(rewards.get("status_lean_max", DEFAULT_LEAN_MAX)), 1.0)
	var counted_cards: Array[Dictionary] = deck_cards
	if lean > 0.0 and bool(rewards.get("status_lean_skip_starter", false)):
		counted_cards = []
		for card_id: String in added_cards(deck, starter):
			if by_id.has(card_id):
				counted_cards.append(by_id[card_id])
	var owned_by_status: Dictionary = status_counts(counted_cards) if lean > 0.0 else {}
	var lean_factor: Dictionary = {}
	if lean > 0.0:
		for id: String in candidates:
			if not deck.has(id):
				lean_factor[id] = lean_for(by_id[id], owned_by_status, lean, lean_max)
	var rng := RandomNumberGenerator.new()
	rng.seed = offer_seed(run_seed, room_index)
	var out: Array[String] = []
	var size: int = int(rewards.get("offer_size", 3))
	while out.size() < size and not candidates.is_empty():
		var weights: Array[float] = []
		var total: float = 0.0
		for id: String in candidates:
			var w: float = maxf(owned_weight if deck.has(id) else unowned_weight, 0.0) * float(lean_factor.get(id, 1.0))
			weights.append(w)
			total += w
		if total <= 0.0:
			break
		var roll: float = rng.randf() * total
		var picked: int = candidates.size() - 1
		for i in range(candidates.size()):
			roll -= weights[i]
			if roll < 0.0:
				picked = i
				break
		out.append(candidates[picked])
		candidates.remove_at(picked)
	return out


const DEFAULT_LEAN_MAX := 3.0


## The deck's cards beyond the starting deck, by copies: each id is counted (copies in the deck - copies in the starter), never below 0.
## Pruning a starter card and picking it up again counts the re-pick as starter (a copy-count rule, so no per-card tracking is saved).
static func added_cards(deck: Array, starter: Array) -> Array[String]:
	var left: Dictionary = {}
	for id: Variant in starter:
		left[String(id)] = int(left.get(String(id), 0)) + 1
	var out: Array[String] = []
	for id: Variant in deck:
		var key: String = String(id)
		if int(left.get(key, 0)) > 0:
			left[key] = int(left[key]) - 1
		else:
			out.append(key)
	return out


## Status id -> how many of the deck's cards apply it (a card counts once per status, however many of its effects apply it).
## A detonate is not a source (CardSummary.status_ids skips it).
static func status_counts(deck_cards: Array[Dictionary]) -> Dictionary:
	var counts: Dictionary = {}
	for card: Dictionary in deck_cards:
		var seen: Dictionary = {}
		for status_id: String in CardSummary.status_ids(card):
			if not seen.has(status_id):
				seen[status_id] = true
				counts[status_id] = int(counts.get(status_id, 0)) + 1
	return counts


## The weight factor of one unowned candidate: the best of 1 + lean x n_S over the statuses it applies, capped at lean_max (1.0 when it applies none).
static func lean_for(card: Dictionary, counts: Dictionary, lean: float, lean_max: float) -> float:
	var best: float = 1.0
	for status_id: String in CardSummary.status_ids(card):
		best = maxf(best, minf(1.0 + lean * float(counts.get(status_id, 0)), lean_max))
	return best


## Sorted ids of the cards in the owned pools whose `requires` the deck and character meet.
static func candidate_ids(cards: Array, pools: Array, deck_cards: Array[Dictionary], pool_defs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for card: Variant in cards:
		var c: Dictionary = card
		if not pools.has(String(c.get("pool", ""))):
			continue
		if not meets_requires(c.get("requires", {}), pools, deck_cards, pool_defs):
			continue
		out.append(String(c.get("id", "")))
	out.sort()
	return out


static func meets_requires(requires: Variant, pools: Array, deck_cards: Array[Dictionary], pool_defs: Dictionary) -> bool:
	if typeof(requires) != TYPE_DICTIONARY or (requires as Dictionary).is_empty():
		return true
	var r: Dictionary = requires
	for slot_type: Variant in (r.get("slot_types", []) as Array):
		var found: bool = false
		for card: Dictionary in deck_cards:
			if String(card.get("slot_type", "")) == String(slot_type):
				found = true
				break
		if not found:
			return false
	for pool_id: Variant in (r.get("pools", []) as Array):
		if not pools.has(String(pool_id)):
			return false
	var sources: Array[String] = status_sources(pools, deck_cards, pool_defs)
	for status_id: Variant in (r.get("status_sources", []) as Array):
		if not sources.has(String(status_id)):
			return false
	return true


static func status_sources(pools: Array, deck_cards: Array[Dictionary], pool_defs: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for pool_id: Variant in pools:
		var def: Variant = pool_defs.get(String(pool_id), {})
		if typeof(def) == TYPE_DICTIONARY and typeof((def as Dictionary).get("status")) == TYPE_DICTIONARY:
			out.append(String(((def as Dictionary)["status"] as Dictionary).get("status_id", "")))
	for card: Dictionary in deck_cards:
		out.append_array(CardSummary.status_ids(card))
	return out


## Problems with a card's `requires` field (empty = fine). Used by CardSchema.
static func validate_requires(requires: Variant, known_slots: Array, known_pools: Array) -> Array[String]:
	var errors: Array[String] = []
	if typeof(requires) != TYPE_DICTIONARY:
		errors.append("requires must be an object")
		return errors
	for key: Variant in (requires as Dictionary).keys():
		var k: String = String(key)
		if not ["slot_types", "pools", "status_sources"].has(k):
			errors.append("requires: unknown key '%s' (use slot_types, pools, status_sources)" % k)
			continue
		var list: Variant = (requires as Dictionary)[key]
		if typeof(list) != TYPE_ARRAY or (list as Array).is_empty():
			errors.append("requires.%s must be a non-empty array of ids" % k)
			continue
		for entry: Variant in (list as Array):
			if typeof(entry) != TYPE_STRING or String(entry) == "":
				errors.append("requires.%s entries must be non-empty strings" % k)
			elif k == "slot_types" and not known_slots.has(String(entry)):
				errors.append("requires.slot_types: unknown slot type '%s'" % String(entry))
			elif k == "pools" and not known_pools.has(String(entry)):
				errors.append("requires.pools: unknown pool '%s'" % String(entry))
	return errors
