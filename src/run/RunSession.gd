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
## `--deck=<name>` (T-decks): the debug preset every new run starts with ({} = none, the normal starting deck). The preset's
## `starter` list is used, or its `full` list with `full_deck`. Sticky for the launch like `full_deck`, so Try again keeps it.
static var debug_deck: Dictionary = {}
## The character the next new run is played as ("" = not chosen: the last pick, else the Rogue). Set by `--class`, a
## `--deck` preset's class, a confirmed pick, or a tool. Sticky for the launch like `debug_deck`, so Try again keeps it.
static var selected_character: String = ""
## True when a launch argument (`--class`, or a `--deck` preset, which names a class) fixed the character: a pick screen
## skips itself then, so a tool or a scripted launch never stalls on it.
static var character_forced: bool = false
## `--run-offer=<card>,<card>,...` (capture tooling, BD1-B): the card offer of the FIRST reward screen, instead of the seeded draw
## (for example to show a Keystone on the reward screen without hunting for a seed). Consumed by that one offer.
static var forced_offer: Array[String] = []
## `--relics=<id>+<id>` (BD2-B, capture and sim tooling): new runs start holding these relics. Sticky for the launch like `debug_deck`.
static var start_relics: Array[String] = []
## `--relic-offer=<id>+<id>` (capture tooling): the relic offer of the FIRST relic choice, instead of the seeded draw. Consumed by that one offer.
static var forced_relic_offer: Array[String] = []
## `--relic-cap=N` (capture and test tooling): replaces `relics.max_owned` for this launch (0 = use the data), so the give-one-up step
## can be reached in a short run. Sticky for the launch.
static var relic_cap: int = 0


## `--map` / `--no-map` (MAP1-B): -1 uses data/map.json `enabled`, 1 forces the branching map on, 0 forces the straight run. Sticky for the launch
## like `debug_deck`, so Try again keeps it. A tool or test sets and clears it.
static var map_override: int = -1
## MAP3-B: the number of acts new map runs have. 0 uses data/map.json `acts`; a tool or test sets it (1 = a MAP2 run) and clears it. Sticky like `map_override`.
static var acts_override: int = 0


## True when new runs use the branching map: the launch override, else data/map.json `enabled`.
static func map_on() -> bool:
	if map_override >= 0:
		return map_override == 1
	return MapConfig.enabled()


## The acts a new run has: the override, else data/map.json `acts` (1 when the map is off or the file is broken).
static func acts_total() -> int:
	if not map_on():
		return 1
	return clampi(acts_override, 1, RunState.MAX_ACTS) if acts_override > 0 else MapConfig.acts()


static func has_run() -> bool:
	return current != null


## The character the next new run uses: the selection, else the remembered last pick, else the Rogue.
static func chosen_character() -> String:
	if CharacterDatabase.has(selected_character):
		return selected_character
	return CharacterPick.last_pick()


## The class a debug preset deck is for (its `class` field; the Rogue when it has none).
static func preset_character(preset: Dictionary) -> String:
	return str(preset.get("class", CharacterDatabase.DEFAULT_ID))


## Starts a new run from the shipped config. `seed_value` < 0 uses `forced_seed`, else a random seed. `character`
## "" = `chosen_character()`. A debug preset is used only when it is for the same class (else the class's own starter).
static func begin_new_run(seed_value: int = -1, character: String = "") -> RunState:
	var chosen: int = seed_value
	if chosen < 0:
		chosen = forced_seed
		forced_seed = -1  # used once: "Try again" must get a new seed
	if chosen < 0:
		chosen = new_random_seed()
	var who: String = character if CharacterDatabase.has(character) else chosen_character()
	var deck: Array[String]
	if not debug_deck.is_empty() and preset_character(debug_deck) == who:
		deck = DebugDecks.deck_of(debug_deck, full_deck)
	else:
		deck = CharacterDatabase.full_deck(who) if full_deck else CharacterDatabase.starting_deck(who)
	current = RunState.new_run(chosen, deck, RunConfig.rejects_per_run(), who)
	for relic_id: String in start_relics:
		current.add_relic(relic_id)
	if map_on():
		# The map is made once, from the run seed, and kept in the state. The run opens on the pick of a room-1 node. (A map that fails to
		# generate has already reported itself loudly; the run is then the straight run.)
		var acts: int = acts_total()
		var map: Dictionary = MapGenerator.generate(chosen, {}, {}, 1, acts)
		if not map.is_empty():
			current.map = map
			current.acts_total = acts
			RunNodes.open(current)
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
