class_name RelicOffer
extends RefCounted
## Which relics a source offers (BUILD_DEPTH 4.6), as pure functions of their inputs: no scene, no autoload, and the only
## randomness is the RandomNumberGenerator passed in, so the same seed gives the same offer.
##
## An offer holds only relics that
##   - are in one of the run's pools (its class, its element and neutral),
##   - list `source` in their `sources`,
##   - are not owned and were not given up this run (no duplicates, no return, D34),
##   - are of an offered rarity and, for tier1..tier3, have a weight above 0 for the act.
## They are drawn without replacement, weighted by the act's tier weights. Fewer than `count` are returned when fewer are
## eligible, and an empty list when none are.
##
## Judgment calls (see DECISIONS): the eligible relics are sorted by id before drawing so the offer never depends on
## directory order; a tier with weight 0 is ineligible; boss relics have no weights and are drawn uniformly, and are
## only offered when the caller asks for the "boss" rarity (a mini-boss reward).

const DEFAULT_RARITIES: Array[String] = ["tier1", "tier2", "tier3"]
const BOSS_RARITY := "boss"


## The pure core. `catalog` is an array of relic dictionaries (RelicDatabase.all_relics()), `weights` the act's
## {tier1, tier2, tier3} row (RelicConfig.tier_weights_for_act). Returns up to `count` relic ids in the order drawn.
static func offer(source: String, count: int, rng: RandomNumberGenerator, weights: Dictionary, owned: Array[String], given_up: Array[String],
		pools: Array[String], catalog: Array, rarities: Array[String] = DEFAULT_RARITIES) -> Array[String]:
	var result: Array[String] = []
	if count <= 0:
		return result
	var candidates: Array[Dictionary] = eligible(source, weights, owned, given_up, pools, catalog, rarities)
	var pool_weights: Array[float] = []
	for relic: Dictionary in candidates:
		pool_weights.append(_weight_of(relic, weights))
	while result.size() < count and not candidates.is_empty():
		var total: float = 0.0
		for w: float in pool_weights:
			total += w
		var roll: float = rng.randf() * total
		var picked: int = candidates.size() - 1  # the last one if rounding leaves the roll past the end
		var running: float = 0.0
		for i in range(candidates.size()):
			running += pool_weights[i]
			if roll < running:
				picked = i
				break
		result.append(String(candidates[picked]["id"]))
		candidates.remove_at(picked)
		pool_weights.remove_at(picked)
	return result


## The relics `offer` may draw from, sorted by id. Exposed so tests and the UI can ask "is anything left to offer".
static func eligible(source: String, weights: Dictionary, owned: Array[String], given_up: Array[String], pools: Array[String],
		catalog: Array, rarities: Array[String] = DEFAULT_RARITIES) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry: Variant in catalog:
		var relic: Dictionary = entry
		var id: String = String(relic.get("id", ""))
		if id.is_empty() or owned.has(id) or given_up.has(id):
			continue
		if not pools.has(String(relic.get("pool", ""))):
			continue
		if not (relic.get("sources", []) as Array).has(source):
			continue
		var rarity: String = String(relic.get("rarity", ""))
		if not rarities.has(rarity):
			continue
		if _weight_of(relic, weights) <= 0.0:
			continue
		found.append(relic)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) < String(b["id"]))
	return found


## Offer for a run: the pools of its character, its owned and given-up relics, the act's weights and the shipped relics.
static func for_run(source: String, count: int, rng: RandomNumberGenerator, act: int, state: RunState, rarities: Array[String] = DEFAULT_RARITIES) -> Array[String]:
	return offer(source, count, rng, RelicConfig.tier_weights_for_act(act), state.relics, state.relics_given_up,
			CharacterDatabase.pools(state.character_id), RelicDatabase.all_relics(), rarities)


static func _weight_of(relic: Dictionary, weights: Dictionary) -> float:
	var rarity: String = String(relic.get("rarity", ""))
	if rarity == BOSS_RARITY:
		return 1.0
	return float(weights.get(rarity, 0.0))


# --- the swap at the cap ------------------------------------------------------------------------

## True when taking one more relic first needs a give-up (the run already holds `max_owned`).
static func needs_swap(owned_count: int, max_owned: int) -> bool:
	return owned_count >= max_owned


## Boss-tier relics can't be given up (so the two a run earns stay, MAP.md 4.5). `relic` is the relic dictionary.
static func can_give_up(relic: Dictionary) -> bool:
	return String(relic.get("rarity", "")) != BOSS_RARITY


## The owned relics a swap may remove, in the order owned. Ids not in the catalog count as removable (a relic removed from
## the data must not trap a save).
static func giveable(owned: Array[String], catalog: Array) -> Array[String]:
	var by_id: Dictionary = {}
	for entry: Variant in catalog:
		by_id[String((entry as Dictionary).get("id", ""))] = entry
	var result: Array[String] = []
	for id: String in owned:
		if not by_id.has(id) or can_give_up(by_id[id]):
			result.append(id)
	return result


## True when a relic can be taken now: there is room, or at the cap at least one owned relic can be given up.
static func can_take(owned: Array[String], max_owned: int, catalog: Array) -> bool:
	return not needs_swap(owned.size(), max_owned) or not giveable(owned, catalog).is_empty()
