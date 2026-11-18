class_name LoadoutStart
extends RefCounted
## Starts a run from a saved loadout (3d sitting C). Goes through the same doors a run already has: the deck replaces the starting deck (the run-start check in
## Main._check_starting_deck still runs on it), the plan is stored on the RunState, and the starter relic is added with `RunState.add_relic` (the path a debug `--relics` start,
## a relic pick and a merchant purchase use), so the relic cap, no duplicates and the save round trip all apply. The preset and run 1 get no relic.


## Applies `entry` (a LoadoutStore entry) to a fresh `state`. Returns the problems; empty means applied. With any problem nothing changes (the run keeps the preset).
## Rechecks the shipped loadout rules and the entry against the current data, because the files and the cards may have changed since it was saved.
static func apply(state: RunState, entry: Dictionary) -> Array[String]:
	var problems: Array[String] = LoadoutRules.shipped_problems()
	if not problems.is_empty():
		return problems
	problems = LoadoutCheck.entry_problems(state.character_id, entry)
	if not problems.is_empty():
		return problems
	var normal: Dictionary = LoadoutCheck.normalised(entry)
	var deck: Array[String] = []
	deck.assign(normal["deck"])
	var plan: Array[String] = []
	plan.assign(normal["plan"])
	state.deck = deck
	state.plan = plan
	var relic_id: String = String(normal["starter_relic"])
	if not relic_id.is_empty():
		state.add_relic(relic_id)
	return problems
