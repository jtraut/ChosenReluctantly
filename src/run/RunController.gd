class_name RunController
extends Node
## Runs one room of a run inside a Main scene (Milestone 3a). It lives in scenes/main/RunMain.tscn; the plain
## Main.tscn (tests, wave_sim, scenarios) has none, so those keep the endless arena.
##
## Per room: load the shared RunState (RunSession), put its HP and deck on the player, hand the spawner this
## room's finite wave table, and watch for the room being won (all waves out, nothing alive). A won room records
## history, makes the player damage-immune, and waits for `continue_to_next_room()`. The next room is a fresh
## Main scene, so slot cooldowns, the shuffle bag, zones, statuses and timers all start clean while the
## RunState carries HP and the deck. The last room won ends the run (`run_won`); a death ends it (`run_lost`).
##
## For ux: the signals and getters below are the whole UI surface. Nothing in here reads a card's content.

## A room (its wave table, or the rest heal) is set up. `index` is 0-based.
signal room_started(index: int, total: int, room_type: String)
## A non-final room was won (or the rest room finished). `summary`: {index, type, wave_id, hp, max_hp, healed, seconds}.
signal room_cleared(summary: Dictionary)
## A choice is waiting (a card reward, the rest menu, the rest removal list); also re-emitted when the list
## changes (rest menu -> removal list -> Back). `model` is `current_choice()`: see RunChoices for the option format.
signal choice_requested(model: Dictionary)
## A choice was resolved (picked, rejected, healed, removed); the next room loads right after. `result` is
## RunChoices.apply's dict: {ok, kind, card_id, amount, finished}.
signal choice_resolved(result: Dictionary)
## The run's relics changed (a relic was taken, or swapped for another at the cap). `relic_ids` is `RunState.relics` in the order taken.
signal relics_changed(relic_ids: Array[String])
## A relic's trigger fired in this room (forwarded from this room's RelicManager, which is rebuilt every room; connect here once).
## `trigger_index` is the trigger's place in the relic's `triggers`. ux flashes the relic's chip on this.
signal relic_triggered(relic_id: String, trigger_index: int, event_id: String)
## The boss entered the room (3c). Its signals (phase_changed, transition_started, defeated, ...), `health.health_changed`,
## `display_name()` and `phase_thresholds()` are what a boss HP bar needs. Also available any time as `current_boss()`.
signal boss_spawned(boss: Boss)
## The class pick was confirmed (`confirm_class_pick`): the run is (re)started as `character_id`. The scene swaps right after.
signal class_picked(character_id: String)
## The run's gold changed: a fight node paid out (`delta` above 0), or a merchant purchase (`delta` below 0). `total` is `RunState.gold`.
signal gold_changed(total: int, delta: int)
## The last room was won.
signal run_won()
## The player died; Main shows Game Over after its death beat.
signal run_lost()

var _main: Main = null
var _state: RunState = null
var _rooms: Array[Dictionary] = []
var _cleared: bool = false
var _active: bool = false
var _room_seconds: float = 0.0
var _healed: float = 0.0
var _summary: Dictionary = {}
var _ctx: Dictionary = {}
var _boss: Boss = null
var _launch_room: int = 0
var _launch_room_set: bool = false
var _launch_node: int = -1
var _launch_gold: int = -1
var _launch_clear_after: float = -1.0
var _prepared: bool = false
var _launch_ok: bool = true
var _fresh_launch: bool = false
var _relics: RelicManager = null


## Called by Main._ready in run mode, after the scene is wired. Starts the current room.
func begin(main: Main) -> void:
	if not prepare(main):
		return  # a bad --deck / --class or --list-decks: the game is quitting (see _apply_launch_args)
	var config: Dictionary = RunConfig.get_config()
	var fresh_launch: bool = _fresh_launch
	_rooms = _build_rooms(config)
	if _state.room_index < 0 or _state.room_index >= _rooms.size():
		push_error("RunController: room index %d is outside the %d-room run; starting a new run" % [_state.room_index, _rooms.size()])
		_state = RunSession.begin_new_run(-1, _state.character_id)
		_rooms = _build_rooms(config)
	if RunNodes.active(_state) and _state.path.is_empty() and not _state.has_pending():
		RunNodes.open(_state)  # a map run opens on the pick of a room-1 node
	_active = true
	_cleared = false
	_room_seconds = 0.0
	var player: Player = main.player
	if not _state.has_hp():
		_state.max_hp = player.health.max_health
		_state.hp = player.health.max_health
	else:
		player.health.max_health = _state.max_hp
		player.health.current_health = clampf(_state.hp, 1.0, _state.max_hp)
		player.health.health_changed.emit(player.health.current_health, player.health.max_health)
	player.card_slots.set_deck(_state.deck)
	_ctx = RunChoices.shipped_context(player.owned_pools)
	_setup_relics(main)
	player.player_died.connect(_on_player_died, CONNECT_ONE_SHOT)
	var room: Dictionary = current_room()
	var spawner: EnemySpawner = main.enemy_spawner
	if _state.has_pending():
		# A reload mid-choice: the room is already won and recorded, so do not fight it again; reopen the choice.
		spawner.process_mode = Node.PROCESS_MODE_DISABLED
		_cleared = true
		player.health.damage_immune = true
		_resume_choice.call_deferred()
	elif String(room["type"]) == "rest" or String(room["type"]) == RunConfig.RELIC_ROOM or String(room["type"]) == RunConfig.MERCHANT_ROOM:
		spawner.process_mode = Node.PROCESS_MODE_DISABLED  # no fight: the room is over at once and its choice opens
		_start_rest.call_deferred()
	else:
		var variant: Dictionary = RunConfig.variant_by_id(config, String(room["type"]), String(room["wave_id"]))
		spawner.tier_configs = (config["tiers"] as Dictionary).duplicate(true)
		spawner.enemy_spawned.connect(_on_enemy_spawned)
		spawner.configure_room(RunConfig.room_wave_config(variant, WaveConfig.get_config()), room_spawn_seed(_state.seed_value, _state.room_index))
		set_process(true)
	room_started.emit(_state.room_index, _rooms.size(), String(room["type"]))
	if not _fresh_launch:
		RunSave.autosave(_state)  # MAP3-A: a room's start is a save point (resuming restarts the room; the first scene of a launch never overwrites a save)
	var relay := CombatLink.events()
	if relay != null:
		relay.notify_room_started(_state.room_index, String(room["type"]))
	if _launch_clear_after >= 0.0 and fresh_launch:
		get_tree().create_timer(_launch_clear_after).timeout.connect(_debug_clear_room)


## The room list the run walks. A straight run: RunGenerator's list. A map run: one entry per room of the map, filled from the path so far
## ({index, type, wave_id, node_id, chest}); the rooms ahead are not chosen yet and read {type: ""}. Before the first pick, room 1 reads as a
## combat room (every room-1 node is one).
func _build_rooms(config: Dictionary) -> Array[Dictionary]:
	if not RunNodes.active(_state):
		return RunGenerator.generate(_state.seed_value, config)
	var rooms: Array[Dictionary] = []
	var boss: Dictionary = MapGraph.node(_state.map, MapGraph.boss_id(_state.map))
	var total: int = int(boss.get("room", 0))
	for index in range(total):
		if index < _state.path.size():
			var node: Dictionary = MapGraph.node(_state.map, _state.path[index])
			rooms.append({"index": index, "type": String(node["type"]), "wave_id": String(node["wave_id"]), "node_id": int(node["id"]), "chest": RunNodes.chest_of(node) if String(node["type"]) == RunConfig.RELIC_ROOM else ""})
		else:
			rooms.append({"index": index, "type": "combat" if index == 0 else "", "wave_id": "", "node_id": -1, "chest": ""})
	return rooms


## Builds this room's RelicManager from the run's relics (BD2). With relics off, or none held, nothing is created, so a run
## without relics is exactly the run it was. The shipped relic files are validated here, so a corrupt one fails at run start.
func _setup_relics(main: Main) -> void:
	if not RunRelics.enabled(_ctx):
		return
	RelicDatabase.problems()  # loads data/relics once; every bad file has already been push_error'd
	if _state.relics.is_empty():
		return
	_create_relic_manager(main)
	_relics.load_relics(_state.relics)


func _create_relic_manager(main: Main) -> void:
	_relics = RelicManager.new()
	_relics.name = "RelicManager"
	add_child(_relics)
	_relics.configure(main.player, main, main.player.status_rng, CombatLink.events())
	_relics.set_run_stats(_run_stats())
	_relics.relic_triggered.connect(func(relic_id: String, trigger_index: int, event_id: String) -> void: relic_triggered.emit(relic_id, trigger_index, event_id))


## After a relic was taken or swapped: bring this room's manager in line with RunState.relics (creating it when the first relic
## arrives), so the relic is live at once and the next room only has to rebuild from the state. Then tell the UI.
func _sync_relics() -> void:
	if RunRelics.enabled(_ctx) and _main != null and _main.player != null:
		if _relics == null and not _state.relics.is_empty():
			_create_relic_manager(_main)
		if _relics != null:
			_relics.set_run_stats(_run_stats())
			for held: String in _relics.relic_ids():
				if not _state.relics.has(held):
					_relics.remove_relic(held)
			for owned: String in _state.relics:
				if not _relics.has_relic(owned):
					_relics.add_relic(owned)
	relics_changed.emit(_state.relics.duplicate())


## The run-long numbers relic modifiers can scale by (RelicSchema.RUN_STATS), from the RunState.
func _run_stats() -> Dictionary:
	return {"gold_spent_merchant": _state.gold_spent_merchant}


## This room's RelicManager, or null when the run holds no relics (or relics are off). ux connects `relic_triggered` here.
func relic_manager() -> RelicManager:
	return _relics


## Reads the launch args (first scene of a launch only) and makes sure a run exists, so the character is known. Main calls
## this from _enter_tree, before the Player's _ready, because the class decides the Player's pools, HP, body and attacks.
## `begin` calls it too; it only works once. Returns false when the launch must not go on (the tree is quitting).
func prepare(main: Main) -> bool:
	if _prepared:
		return _launch_ok
	_prepared = true
	_main = main
	_fresh_launch = RunSession.current == null
	if _fresh_launch and not _apply_launch_args(main.get_tree()):
		_launch_ok = false
		return false
	_state = RunSession.ensure_run()
	if _fresh_launch and (_launch_room > 0 or (_launch_room_set and RunNodes.active(_state))):
		_state.jump_to_room(_launch_room)  # a map run is laid along the `first` route (no gold for the rooms skipped)
	if _fresh_launch and _launch_node >= 0 and RunNodes.active(_state) and not _state.jump_to_node(_launch_node):
		push_error("RunController: --run-node=%d is not a node of this run's map" % _launch_node)
	if _fresh_launch and _launch_gold >= 0:
		_state.gold = _launch_gold
	return true


## The character of this run (data/characters.json id); "" before `prepare`.
func character_id() -> String:
	return _state.character_id if _state != null else ""


## Confirms the class pick and starts the run as that class (the pick screen's one call). The pick is remembered and
## preselected next time. The same character: nothing restarts. A different one before any room is played: a new run with the
## same seed and start room, as a fresh scene. Later in a run it is refused (a run keeps its class). Returns true when the run
## is (now) that class.
func confirm_class_pick(character: String) -> bool:
	if not CharacterDatabase.has(character):
		push_error("RunController.confirm_class_pick: unknown character '%s'" % character)
		return false
	if _state == null or _main == null:
		return false
	CharacterPick.remember(character)
	RunSession.selected_character = character
	if _state.character_id == character:
		class_picked.emit(character)
		return true
	if not _state.history.is_empty():
		push_error("RunController.confirm_class_pick: a run in progress keeps its class")
		return false
	var room_index: int = _state.room_index
	var had_path: bool = not _state.path.is_empty()
	_active = false
	var fresh: RunState = RunSession.begin_new_run(_state.seed_value, character)
	if room_index > 0 or had_path:
		fresh.jump_to_room(room_index)
	class_picked.emit(character)
	_main.swap_to_fresh_scene()
	return true


## Launch arguments for tools and repro (after `--`); they apply to the first run of a launch only:
## `--run-seed=N` fixes the seed, `--run-room=K` starts at room K (1-based), `--full-deck` starts with every card of the character's pools (debug), `--run-clear-after=S` wins the room
## S seconds in (so a screenshot can show the room-cleared prompt or the win screen). `--deck=<name>` starts with a debug
## preset deck from data/debug_decks (its `starter`, or its `full` with `--full-deck`) and `--list-decks` prints them and quits.
## `--run-node=N` (map runs, MAP2-B): start in map node N (the path runs back to room 1 along first predecessors); `--run-gold=N` starts with N gold. Both are for captures
## (for example the merchant: `--merchant --run-seed=54 --run-node=<its id> --run-gold=200`; the map print tool with -Merchant lists the ids).
## `--merchant` turns the merchant on for this launch (MerchantSwitch: data/merchant_on.json merged into the map and run config; the shipped data already has it on, so this is redundant).
## `--class=<rogue|wizard>` plays the run as that character (a `--deck` preset names its class, and a `--class` that disagrees is refused).
## Returns false when the launch must not go on: it has asked the tree to quit (exit 0 for --list-decks, 2 for bad args).
func _apply_launch_args(tree: SceneTree) -> bool:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var directory: Dictionary = DebugDecks.read_dir()
	var launch: Dictionary = DebugDecks.resolve_launch(args, directory)
	for line: String in (launch["lines"] as Array[String]):
		print(line)
	for message: String in (launch["errors"] as Array[String]):
		printerr("Launch refused: " + message)  # plain stderr: a bad launch arg is the caller's error, not an engine error with a stack trace
	RunSave.suppressed = RunSave.args_suppress(args)  # a debug launch never reads, writes or deletes the player's save
	var exit_code: int = int(launch["exit"])
	if exit_code != DebugDecks.EXIT_CONTINUE:
		tree.quit(exit_code)
		return false
	for arg: String in args:
		if arg.begins_with("--run-offer="):
			var offer_ids: Array[String] = []
			for part: String in arg.substr(12).replace("+", ",").split(",", false):  # "+" too: capture_screenshot.ps1 splits its -Extra values on commas
				offer_ids.append(part.strip_edges())
			var offer_problems: Array[String] = RunChoices.forced_offer_problems(offer_ids, RunConfig.offer_size())
			if not offer_problems.is_empty():
				for problem: String in offer_problems:
					printerr("Launch refused: " + problem)
				tree.quit(2)
				return false
			RunSession.forced_offer = offer_ids
	if args.has("--merchant") and not MerchantSwitch.apply():  # MAP2-B: play the merchant before the shipped data turns it on
		printerr("Launch refused: --merchant could not apply data/merchant_on.json")
		tree.quit(2)
		return false
	var map_launch: Dictionary = MapLaunch.resolve(args)
	if not (map_launch["errors"] as Array[String]).is_empty():
		for problem: String in (map_launch["errors"] as Array[String]):
			printerr("Launch refused: " + problem)
		tree.quit(2)
		return false
	var run_launch: Dictionary = MapLaunch.resolve_run_args(args)
	if not (run_launch["errors"] as Array[String]).is_empty():
		for problem: String in (run_launch["errors"] as Array[String]):
			printerr("Launch refused: " + problem)
		tree.quit(2)
		return false
	_launch_node = int(run_launch["node"])
	_launch_gold = int(run_launch["gold"])
	if int(map_launch["override"]) != MapLaunch.OVERRIDE_NONE:
		RunSession.map_override = int(map_launch["override"])
	if not _apply_relic_args(args, tree):
		return false
	if String(launch["deck"]) != "":
		RunSession.debug_deck = (directory["presets"] as Dictionary)[String(launch["deck"])]
	if String(launch["character"]) != "":
		RunSession.selected_character = String(launch["character"])
		RunSession.character_forced = true
	for arg: String in args:
		if arg == "--full-deck":
			RunSession.full_deck = true
		elif arg.begins_with("--run-seed=") and arg.substr(11).is_valid_int():
			RunSession.forced_seed = absi(arg.substr(11).to_int()) & RunState.SEED_LIMIT
		elif arg.begins_with("--run-room=") and arg.substr(11).is_valid_int():
			_launch_room = maxi(arg.substr(11).to_int() - 1, 0)
			_launch_room_set = true
		elif arg.begins_with("--run-clear-after=") and arg.substr(18).is_valid_float():
			_launch_clear_after = maxf(arg.substr(18).to_float(), 0.0)
	return true


## `--relics=<id>+<id>`, `--relic-offer=<id>+<id>` and `--relic-cap=N` (BD2-B; "+" or "," between ids): a run that starts holding those
## relics, the first relic choice offering exactly those, and a lower relic cap (so the give-one-up step shows in a short run).
## An unknown id, a repeated id, an offer longer than `relics.offer_count` or a cap below 1 is refused (exit 2) like a bad `--run-offer`.
func _apply_relic_args(args: PackedStringArray, tree: SceneTree) -> bool:
	var problems: Array[String] = []
	for arg: String in args:
		if arg.begins_with("--relics="):
			var held: Array[String] = RelicArgs.parse_ids(arg.substr(9))
			problems.append_array(RelicArgs.id_problems("--relics", held, 0))
			RunSession.start_relics = held
		elif arg.begins_with("--relic-offer="):
			var offered: Array[String] = RelicArgs.parse_ids(arg.substr(14))
			problems.append_array(RelicArgs.id_problems("--relic-offer", offered, RelicConfig.offer_count()))
			RunSession.forced_relic_offer = offered
		elif arg.begins_with("--relic-cap="):
			if not arg.substr(12).is_valid_int() or arg.substr(12).to_int() < 1:
				problems.append("--relic-cap needs a whole number from 1, as --relic-cap=2")
			else:
				RunSession.relic_cap = arg.substr(12).to_int()
	if problems.is_empty():
		return true
	for problem: String in problems:
		printerr("Launch refused: " + problem)
	tree.quit(2)
	return false


func _on_enemy_spawned(enemy: Enemy, _alive_count: int) -> void:
	if enemy is Boss:
		_boss = enemy as Boss
		boss_spawned.emit(_boss)


## The boss of this room while it lives, else null.
func current_boss() -> Boss:
	return _boss if _boss != null and is_instance_valid(_boss) and not _boss.is_defeated() else null


func _debug_clear_room() -> void:
	if _active and not _cleared and not _main.player.is_dead():
		_finish_room(0.0)


## The spawner seed of one room, from the run seed (pure).
static func room_spawn_seed(run_seed: int, room_index: int) -> int:
	return (run_seed * 31 + room_index * 7919 + 17) & RunState.SEED_LIMIT


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not _active or _cleared:
		return
	_room_seconds += delta
	if _main.player.is_dead():
		return
	if _main.enemy_spawner.room_cleared():
		_finish_room(0.0)


func _start_rest() -> void:
	if _active and not _cleared:
		_finish_room(0.0)


func _resume_choice() -> void:
	if _active and _state.has_pending():
		choice_requested.emit(current_choice())


func _finish_room(healed: float) -> void:
	_cleared = true
	_healed = healed
	var health: Health = _main.player.health
	health.damage_immune = true  # a projectile still in the air must not kill a player who won
	var room: Dictionary = current_room()
	_state.hp = health.current_health
	_state.max_hp = health.max_health
	_state.record_room(room, health.current_health, _room_seconds)
	# MAP1-B: a won fight node pays gold, rolled from the run seed and the node id (so a reload can't pay twice: this runs once per room).
	var earned: int = 0
	if RunNodes.active(_state):
		earned = RunNodes.roll_gold(_state.seed_value, int(room.get("node_id", -1)), String(room["type"]), RunConfig.gold())
		_state.gold += earned
	_summary = {
		"index": int(room["index"]), "type": String(room["type"]), "wave_id": String(room["wave_id"]),
		"hp": health.current_health, "max_hp": health.max_health, "healed": healed, "seconds": _room_seconds,
		"gold": earned, "node_id": int(room.get("node_id", -1)),
	}
	if earned > 0:
		gold_changed.emit(_state.gold, earned)
	var relay := CombatLink.events()
	if relay != null:
		relay.notify_room_cleared(int(room["index"]), String(room["type"]))
	if _state.room_index >= _rooms.size() - 1:
		_state.outcome = "won"
		RunSave.delete_save()
		run_won.emit()
		return
	if RunRelics.open_for_room(_state, String(room["type"]), false, _ctx) != RunState.PENDING_NONE:
		choice_requested.emit(current_choice())
	else:
		room_cleared.emit(_summary)


## Resolves one option of the open choice (by its `id`). When it finishes the choice the next room loads at once.
## Returns RunChoices.apply's dict; `ok` is false (and nothing changes) for a disabled or unknown option.
func choose(option_id: String) -> Dictionary:
	if not _active or not _cleared or not _state.has_pending():
		return {"ok": false, "kind": "", "card_id": "", "amount": 0.0, "finished": false, "reason": "no choice is open"}
	var gold_before: int = _state.gold
	var spent_before: int = _state.gold_spent_merchant
	var result: Dictionary = RunChoices.apply(_state, option_id, _ctx)
	if not bool(result["ok"]):
		return result
	if ["relic_pick", "relic_swap", "merchant_relic"].has(String(result["kind"])):
		_sync_relics()
	elif _state.gold_spent_merchant != spent_before and _relics != null:
		_relics.set_run_stats(_run_stats())  # any merchant purchase (a card, a removal) moves the run stats a relic scales by (Liquidate Assets)
	if _state.gold != gold_before:
		gold_changed.emit(_state.gold, _state.gold - gold_before)  # a merchant purchase: a negative delta
	var health: Health = _main.player.health
	if String(result["kind"]) == "heal" and float(result["amount"]) > 0.0:
		health.heal(float(result["amount"]))
	_state.hp = health.current_health
	if bool(result["finished"]) and String(result["kind"]) == RunNodes.OPTION_NODE:
		choice_resolved.emit(result)
		_active = false  # RunNodes.apply has moved the path and the room index on: the picked room is a fresh scene
		_main.swap_to_fresh_scene()
		return result
	if bool(result["finished"]):
		if not _state.history.is_empty():
			(_state.history[_state.history.size() - 1] as Dictionary)["hp_end"] = _state.hp  # the room ends when the choice does
		choice_resolved.emit(result)
		continue_to_next_room()
	else:
		choice_requested.emit(current_choice())
	return result


## The Continue button: advance the room index and swap in a fresh Main for the next room.
func continue_to_next_room(force: bool = false) -> void:
	if not _active or not _cleared or _state.is_over():
		return
	if _state.has_pending():
		if not force:
			return  # a choice is open: only `choose` ends it (force = tests and debug only)
		_state.pending = RunState.PENDING_NONE
		_state.offer = []
	if RunNodes.active(_state):
		RunNodes.open(_state)  # a map run never walks on by itself: the player picks the next node (`pick_node`)
		RunSave.autosave(_state)  # MAP3-A: the map screen is a save point
		choice_requested.emit(current_choice())
		return
	_active = false
	_state.room_index += 1
	_main.swap_to_fresh_scene()


func _on_player_died() -> void:
	if not _active:
		return
	_active = false
	set_process(false)
	_state.outcome = "lost"
	RunSave.delete_save()
	run_lost.emit()


# ---- Getters for the UI ----

## The open choice as a model for the screen (RunChoices.model plus the room texts), or {} when none is open.
func current_choice() -> Dictionary:
	if _state == null or not _state.has_pending():
		return {}
	var model: Dictionary = RunChoices.model(_state, _ctx, room_type())
	model["room_label"] = room_label()
	model["room_type"] = room_type()
	model["room_type_name"] = room_type_name()
	model["next_line"] = next_room_line()
	model["next_room_type"] = next_room_type()
	model["gold"] = _state.gold
	return model


# ---- Relic data for the UI (BD2-B) ----

## The relic offer waiting now (an offer, or the give-up step's underlying offer), as display dictionaries
## {relic_id, name, tier, tier_name, pool, pool_name, rule_text, flavor, keywords, boss, giveable}; [] when no relic choice is open.
func relic_offer() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	if _state != null and _state.has_relic_choice():
		for relic_id: String in _state.offer:
			list.append(RunRelics.display(relic_id, _ctx))
	return list


## The give-one-up step: {active, incoming (display dict, {} when inactive), giveable (display dicts), owned_count, max_owned}.
## `active` is true only after a relic was chosen at the cap. Confirm with `give_up_relic`, back out with `cancel_relic_swap`.
func relic_swap_state() -> Dictionary:
	var active: bool = _state != null and _state.pending == RunState.PENDING_RELIC_SWAP
	var giveable: Array[Dictionary] = []
	if active:
		for relic_id: String in RunRelics.giveable_ids(_state, _ctx):
			giveable.append(RunRelics.display(relic_id, _ctx))
	return {
		"active": active, "incoming": RunRelics.display(_state.relic_incoming, _ctx) if active else {}, "giveable": giveable,
		"owned_count": _state.relics.size() if _state != null else 0, "max_owned": RunRelics.max_owned(_ctx),
	}


## The relics the run holds, in the order taken, and the ones it gave up, as display dictionaries (the HUD row and the pause list).
func owned_relics() -> Array[Dictionary]:
	return RunRelics.owned_display(_state, _ctx) if _state != null else ([] as Array[Dictionary])


func given_up_relics() -> Array[Dictionary]:
	return RunRelics.given_up_display(_state, _ctx) if _state != null else ([] as Array[Dictionary])


## Takes an offered relic (at the cap this opens the give-up step instead; the result's kind is "relic_swap_open").
func pick_relic(relic_id: String) -> Dictionary:
	return choose(RunRelics.OPTION_RELIC + ":" + relic_id)


## Skips the relic offer (free: no reject is spent).
func skip_relic_offer() -> Dictionary:
	return choose(RunRelics.OPTION_SKIP)


## Gives up an owned relic to take the one being swapped in.
func give_up_relic(relic_id: String) -> Dictionary:
	return choose(RunRelics.OPTION_GIVEUP + ":" + relic_id)


## Backs out of the give-up step: everything is kept and the offer is shown again.
func cancel_relic_swap() -> Dictionary:
	return choose(RunRelics.OPTION_CANCEL)


func has_choice() -> bool:
	return _state != null and _state.has_pending()


## "Next: Room 4 of 10 - Elite" (data ui.next_line), or "" after the last room.
func next_room_line() -> String:
	if _state == null or RunNodes.active(_state) or _state.room_index + 1 >= _rooms.size():
		return ""
	var next_room: Dictionary = _rooms[_state.room_index + 1]
	return String(RunConfig.ui()["next_line"]) % [_state.room_index + 2, _rooms.size(), room_type_name(String(next_room["type"]))]

## The room type after this one ("combat", "elite", "rest", "boss"), or "" after the last room.
func next_room_type() -> String:
	if _state == null or RunNodes.active(_state) or _state.room_index + 1 >= _rooms.size():
		return ""
	return String((_rooms[_state.room_index + 1] as Dictionary)["type"])


# ---- Map data for the UI (MAP1-B) ----

## True when this run walks a branching map (its RunState holds one). False for the straight run: nothing below applies then.
func map_on() -> bool:
	return RunNodes.active(_state)


## The map {nodes: [{id, room, column, type, wave_id, chest?}], edges: [[from_id, to_id]]}, or {} for a straight run. Read-only for the UI.
func map() -> Dictionary:
	return _state.map if _state != null else {}


## The node the player is in now, or -1 before the first pick (the start of a map run).
func current_node_id() -> int:
	if _state == null or _state.path.is_empty():
		return -1
	return _state.path[_state.path.size() - 1]


## The node ids taken so far, in order (the current node is the last).
func taken_path() -> Array[int]:
	return _state.path.duplicate() if _state != null else ([] as Array[int])


## The node ids the player can pick now (only while the pick-next-node choice is open; [] otherwise), lowest column first.
func reachable_nodes() -> Array[int]:
	if _state == null or _state.pending != RunState.PENDING_NODE:
		return [] as Array[int]
	return RunNodes.reachable_ids(_state)


## One node for the map screen: {id, room, column, type, type_name, wave_id, chest, chest_name, hover, gold_low, gold_high, reachable, taken, current}.
## `hover` is the data text for the hover or focus line ("Elite: a relic, 30-40 gold"). {} for an unknown id.
func node_info(node_id: int) -> Dictionary:
	if _state == null or not RunNodes.active(_state):
		return {}
	return RunNodes.node_info(_state, node_id, _ctx)


## Every node of the map as `node_info` dictionaries, in map order (rooms, then columns).
func node_infos() -> Array[Dictionary]:
	var infos: Array[Dictionary] = []
	if _state == null or not RunNodes.active(_state):
		return infos
	for entry: Variant in (_state.map["nodes"] as Array):
		infos.append(RunNodes.node_info(_state, int((entry as Dictionary)["id"]), _ctx))
	return infos


## Picks the next node while the pick-next-node choice is open. Moves the run into that room (a fresh scene). Returns RunChoices.apply's dict
## ({ok, kind: "node", node_id, finished, reason}); a node that is not reachable changes nothing and returns ok = false.
func pick_node(node_id: int) -> Dictionary:
	return choose("%s:%d" % [RunNodes.OPTION_NODE, node_id])


# ---- Merchant data and calls for the UI (MAP2-B) ----

## True while a merchant choice is open (the shop, its removal list or the give-one-up step).
func merchant_open() -> bool:
	return _state != null and _state.has_merchant_choice()


## Everything a merchant panel draws: see RunMerchant.view (items with price, sold, can_buy and a reason code, gold, the removal list with the
## per-card reason, rerolls, the give-up step). {} when no merchant choice is open.
func merchant_view() -> Dictionary:
	if not merchant_open():
		return {}
	return RunMerchant.view(_state, _ctx)


## Buys a stocked relic. At the relic cap this opens the give-up step instead (result kind "merchant_swap_open"); then call `give_up_for_purchase`.
func buy_relic(relic_id: String) -> Dictionary:
	return choose(RunMerchant.OPTION_BUY_RELIC + ":" + relic_id)


func buy_card(card_id: String) -> Dictionary:
	return choose(RunMerchant.OPTION_BUY_CARD + ":" + card_id)


## Opens the card removal list (the shop screen's removal entry).
func open_merchant_removal() -> Dictionary:
	return choose(RunMerchant.OPTION_REMOVE_MENU)


## Buys the removal of one copy of a card (from the removal list, or straight from the shop).
func buy_removal(card_id: String) -> Dictionary:
	return choose(RunMerchant.OPTION_REMOVE + ":" + card_id)


## Back from the removal list to the shop.
func merchant_back() -> Dictionary:
	return choose(RunMerchant.OPTION_BACK)


## Uses a free reroll of the unsold stock (needs a relic that grants one).
func reroll_merchant() -> Dictionary:
	return choose(RunMerchant.OPTION_REROLL)


## In the give-up step: gives up an owned relic to take the one being bought.
func give_up_for_purchase(relic_id: String) -> Dictionary:
	return choose(RunMerchant.OPTION_GIVEUP + ":" + relic_id)


## Backs out of the give-up step; nothing is charged.
func cancel_purchase() -> Dictionary:
	return choose(RunMerchant.OPTION_CANCEL)


## Leaves the merchant: the visit closes and the run goes on to the map.
func leave_merchant() -> Dictionary:
	return choose(RunMerchant.OPTION_LEAVE)


## Gold earned this run (0 in a straight run).
func gold() -> int:
	return _state.gold if _state != null else 0


## "12 gold" from data (ui.map.gold_format).
func gold_text() -> String:
	var texts: Dictionary = RunConfig.ui().get("map", {})
	return String(texts.get("gold_format", "%d")) % gold()


func state() -> RunState:
	return _state


func rooms() -> Array[Dictionary]:
	return _rooms


## The current room: {index, type, wave_id}.
func current_room() -> Dictionary:
	if _state == null or _state.room_index >= _rooms.size():
		return {"index": 0, "type": "combat", "wave_id": ""}
	return _rooms[_state.room_index]


func room_type() -> String:
	return String(current_room()["type"])


## 1-based number for display.
func room_number() -> int:
	return _state.room_index + 1 if _state != null else 1


func room_total() -> int:
	return _rooms.size()


## "Room 3 of 10" text from data (ui.room_label).
func room_label() -> String:
	return String(RunConfig.ui()["room_label"]) % [room_number(), room_total()]


## The display name of a room type from data (ui.type_names).
func room_type_name(room_type_id: String = "") -> String:
	var id: String = room_type_id if room_type_id != "" else room_type()
	return String((RunConfig.ui()["type_names"] as Dictionary).get(id, id))


func is_cleared() -> bool:
	return _cleared


func is_last_room() -> bool:
	return _state != null and _state.room_index >= _rooms.size() - 1


## The summary of the room just cleared (empty before a clear).
func last_summary() -> Dictionary:
	return _summary


func rejects_remaining() -> int:
	return _state.rejects_remaining if _state != null else 0
