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
	_rooms = RunGenerator.generate(_state.seed_value, config)
	if _state.room_index < 0 or _state.room_index >= _rooms.size():
		push_error("RunController: room index %d is outside the %d-room run; starting a new run" % [_state.room_index, _rooms.size()])
		_state = RunSession.begin_new_run(-1, _state.character_id)
		_rooms = RunGenerator.generate(_state.seed_value, config)
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
	elif String(room["type"]) == "rest" or String(room["type"]) == RunConfig.RELIC_ROOM:
		spawner.process_mode = Node.PROCESS_MODE_DISABLED  # no fight: the room is over at once and its choice opens
		_start_rest.call_deferred()
	else:
		var variant: Dictionary = RunConfig.variant_by_id(config, String(room["type"]), String(room["wave_id"]))
		spawner.tier_configs = (config["tiers"] as Dictionary).duplicate(true)
		spawner.enemy_spawned.connect(_on_enemy_spawned)
		spawner.configure_room(RunConfig.room_wave_config(variant, WaveConfig.get_config()), room_spawn_seed(_state.seed_value, _state.room_index))
		set_process(true)
	room_started.emit(_state.room_index, _rooms.size(), String(room["type"]))
	var relay := CombatLink.events()
	if relay != null:
		relay.notify_room_started(_state.room_index, String(room["type"]))
	if _launch_clear_after >= 0.0 and fresh_launch:
		get_tree().create_timer(_launch_clear_after).timeout.connect(_debug_clear_room)


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
	_relics.relic_triggered.connect(func(relic_id: String, trigger_index: int, event_id: String) -> void: relic_triggered.emit(relic_id, trigger_index, event_id))


## After a relic was taken or swapped: bring this room's manager in line with RunState.relics (creating it when the first relic
## arrives), so the relic is live at once and the next room only has to rebuild from the state. Then tell the UI.
func _sync_relics() -> void:
	if RunRelics.enabled(_ctx) and _main != null and _main.player != null:
		if _relics == null and not _state.relics.is_empty():
			_create_relic_manager(_main)
		if _relics != null:
			for held: String in _relics.relic_ids():
				if not _state.relics.has(held):
					_relics.remove_relic(held)
			for owned: String in _state.relics:
				if not _relics.has_relic(owned):
					_relics.add_relic(owned)
	relics_changed.emit(_state.relics.duplicate())


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
	if _fresh_launch and _launch_room > 0:
		_state.room_index = _launch_room
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
	_active = false
	var fresh: RunState = RunSession.begin_new_run(_state.seed_value, character)
	fresh.room_index = room_index
	class_picked.emit(character)
	_main.swap_to_fresh_scene()
	return true


## Launch arguments for tools and repro (after `--`); they apply to the first run of a launch only:
## `--run-seed=N` fixes the seed, `--run-room=K` starts at room K (1-based), `--full-deck` starts with every card of the character's pools (debug), `--run-clear-after=S` wins the room
## S seconds in (so a screenshot can show the room-cleared prompt or the win screen). `--deck=<name>` starts with a debug
## preset deck from data/debug_decks (its `starter`, or its `full` with `--full-deck`) and `--list-decks` prints them and quits.
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
	_summary = {
		"index": int(room["index"]), "type": String(room["type"]), "wave_id": String(room["wave_id"]),
		"hp": health.current_health, "max_hp": health.max_health, "healed": healed, "seconds": _room_seconds,
	}
	var relay := CombatLink.events()
	if relay != null:
		relay.notify_room_cleared(int(room["index"]), String(room["type"]))
	if _state.room_index >= _rooms.size() - 1:
		_state.outcome = "won"
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
	var result: Dictionary = RunChoices.apply(_state, option_id, _ctx)
	if not bool(result["ok"]):
		return result
	if ["relic_pick", "relic_swap"].has(String(result["kind"])):
		_sync_relics()
	var health: Health = _main.player.health
	if String(result["kind"]) == "heal" and float(result["amount"]) > 0.0:
		health.heal(float(result["amount"]))
	_state.hp = health.current_health
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
	_active = false
	_state.room_index += 1
	_main.swap_to_fresh_scene()


func _on_player_died() -> void:
	if not _active:
		return
	_active = false
	set_process(false)
	_state.outcome = "lost"
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
	if _state == null or _state.room_index + 1 >= _rooms.size():
		return ""
	var next_room: Dictionary = _rooms[_state.room_index + 1]
	return String(RunConfig.ui()["next_line"]) % [_state.room_index + 2, _rooms.size(), room_type_name(String(next_room["type"]))]

## The room type after this one ("combat", "elite", "rest", "boss"), or "" after the last room.
func next_room_type() -> String:
	if _state == null or _state.room_index + 1 >= _rooms.size():
		return ""
	return String((_rooms[_state.room_index + 1] as Dictionary)["type"])


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
