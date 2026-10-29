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
var _launch_room: int = 0
var _launch_clear_after: float = -1.0


## Called by Main._ready in run mode, after the scene is wired. Starts the current room.
func begin(main: Main) -> void:
	_main = main
	var config: Dictionary = RunConfig.get_config()
	var fresh_launch: bool = RunSession.current == null
	if fresh_launch:
		_apply_launch_args()
	_state = RunSession.ensure_run()
	if fresh_launch and _launch_room > 0:
		_state.room_index = _launch_room
	_rooms = RunGenerator.generate(_state.seed_value, config)
	if _state.room_index < 0 or _state.room_index >= _rooms.size():
		push_error("RunController: room index %d is outside the %d-room run; starting a new run" % [_state.room_index, _rooms.size()])
		_state = RunSession.begin_new_run()
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
	player.player_died.connect(_on_player_died, CONNECT_ONE_SHOT)
	var room: Dictionary = current_room()
	var spawner: EnemySpawner = main.enemy_spawner
	if String(room["type"]) == "rest":
		spawner.process_mode = Node.PROCESS_MODE_DISABLED
		_start_rest.call_deferred()
	else:
		var variant: Dictionary = RunConfig.variant_by_id(config, String(room["type"]), String(room["wave_id"]))
		spawner.tier_configs = (config["tiers"] as Dictionary).duplicate(true)
		spawner.configure_room(RunConfig.room_wave_config(variant, WaveConfig.get_config()), room_spawn_seed(_state.seed_value, _state.room_index))
		set_process(true)
	room_started.emit(_state.room_index, _rooms.size(), String(room["type"]))
	if _launch_clear_after >= 0.0 and fresh_launch:
		get_tree().create_timer(_launch_clear_after).timeout.connect(_debug_clear_room)


## Launch arguments for tools and repro (after `--`); they apply to the first run of a launch only:
## `--run-seed=N` fixes the seed, `--run-room=K` starts at room K (1-based), `--run-clear-after=S` wins the room
## S seconds in (so a screenshot can show the room-cleared prompt or the win screen).
func _apply_launch_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--run-seed=") and arg.substr(11).is_valid_int():
			RunSession.forced_seed = absi(arg.substr(11).to_int()) & RunState.SEED_LIMIT
		elif arg.begins_with("--run-room=") and arg.substr(11).is_valid_int():
			_launch_room = maxi(arg.substr(11).to_int() - 1, 0)
		elif arg.begins_with("--run-clear-after=") and arg.substr(18).is_valid_float():
			_launch_clear_after = maxf(arg.substr(18).to_float(), 0.0)


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
	if not _active or _cleared:
		return
	var health: Health = _main.player.health
	var before: float = health.current_health
	health.heal(health.max_health * RunConfig.rest_heal_fraction())
	_finish_room(health.current_health - before)


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
	if _state.room_index >= _rooms.size() - 1:
		_state.outcome = "won"
		run_won.emit()
	else:
		room_cleared.emit(_summary)


## The Continue button: advance the room index and swap in a fresh Main for the next room.
func continue_to_next_room() -> void:
	if not _active or not _cleared or _state.is_over():
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
	run_lost.emit()


# ---- Getters for the UI ----

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


## "Room 3 of 8" text from data (ui.room_label).
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
