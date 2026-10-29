class_name RunSession
extends RefCounted
## Holds the one live RunState between scenes (a room transition replaces the Main scene, so the state cannot
## live in it). A static, not an autoload: nothing here is in the scene tree, and `begin_new_run` is the only
## way to get a fresh state, so "Try again" cannot leak anything from the last run. Tests and tools call
## `clear()` to leave no run behind.

static var current: RunState = null
## Seed for the NEXT new run only (consumed by it) when a tool or launch argument fixes it (-1 = random).
static var forced_seed: int = -1
## `--full-deck`: new runs start with every card of the character's pools instead of the starter list.
## Sticky for the launch (Try again keeps it); a tool or test sets and clears it.
static var full_deck: bool = false


static func has_run() -> bool:
	return current != null


## Starts a new run from the shipped config. `seed_value` < 0 uses `forced_seed`, else a random seed.
static func begin_new_run(seed_value: int = -1) -> RunState:
	var chosen: int = seed_value
	if chosen < 0:
		chosen = forced_seed
		forced_seed = -1  # used once: "Try again" must get a new seed
	if chosen < 0:
		chosen = new_random_seed()
	var deck: Array[String] = RunConfig.cards_in_pools(RunConfig.character_pools()) if full_deck else RunConfig.starting_deck()
	current = RunState.new_run(chosen, deck, RunConfig.rejects_per_run())
	return current


## The live run, or a new one when there is none.
static func ensure_run() -> RunState:
	if current == null:
		begin_new_run()
	return current


static func clear() -> void:
	current = null


static func new_random_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi() & RunState.SEED_LIMIT
