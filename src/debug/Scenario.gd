class_name Scenario
extends Node
## Scripted test scene driven through real systems (Health, StatusEffectManager,
## enemy scenes). Definitions live in data/scenarios.json. Added by Main only
## when --scenario=<id> is passed.

const DATA_PATH := "res://data/scenarios.json"

var _main: Node3D
var _def: Dictionary = {}
var _enemies: Array[Enemy] = []
var _elapsed: float = 0.0
var _late_hit_done: bool = false
var _stun_done: bool = false
var _kill_done: bool = false
var _heavy_press_done: bool = false
var _heavy_release_at: float = -1.0
var _cast_index: int = 0
var _preview_index: int = 0
## Scripted key releases still to send: {"at": float, "action": StringName}.
var _preview_releases: Array[Dictionary] = []
## Slot cooling checks queued by casts: {"at": float, "slot": String, "before": float, "card": String}.
var _cooling_checks: Array[Dictionary] = []


static func has_scenario(scenario_id: String) -> bool:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return typeof(parsed) == TYPE_DICTIONARY and (parsed as Dictionary).has(scenario_id)


static func load_def(scenario_id: String) -> Dictionary:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Scenario: could not open " + DATA_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has(scenario_id):
		push_error("Scenario: unknown scenario '%s'" % scenario_id)
		return {}
	var def: Dictionary = (parsed as Dictionary)[scenario_id]
	var problems := ScenarioSchema.validate(scenario_id, def)
	if not problems.is_empty():
		for problem in problems:
			push_error("Scenario: " + problem)
		return {}
	return def


## Builds the scenario inside `main` (which must have a Player) and returns the
## Scenario node (already a child of main) so callers can inspect enemies.
static func setup(main: Node3D, scenario_id: String) -> Scenario:
	var def := load_def(scenario_id)
	if def.is_empty():
		return null
	var scenario := Scenario.new()
	scenario.name = "Scenario"
	scenario._main = main
	scenario._def = def
	main.add_child(scenario)
	# Held-key captures need the release trigger whatever the dev saved (memory only, never saved).
	if def.has("previews"):
		Settings.set_value(Settings.CAST_TRIGGER, Settings.TRIGGER_RELEASE)
	scenario._build()
	return scenario


var _settings_opened: bool = false


func enemies() -> Array[Enemy]:
	return _enemies


func _build() -> void:
	var player: Player = _main.get_node("Player")
	if bool(_def.get("disable_spawner", true)):
		var spawner: Node = _main.get_node_or_null("EnemySpawner")
		if spawner != null:
			spawner.process_mode = Node.PROCESS_MODE_DISABLED
	# Capture-only: the real spawner at a fast, ungated pace (first wave at 0.5 s, every stage back to
	# back) so a still shows the density cap without waiting on kills. The cap itself is unchanged.
	if bool(_def.get("dense_waves", false)) and _main.get("enemy_spawner") != null:
		var spawner: EnemySpawner = _main.enemy_spawner
		var config: Dictionary = WaveConfig.get_config().duplicate(true)
		config["first_wave_delay"] = 0.5
		config["spawn_gap"] = 0.15
		for stage: Dictionary in (config["stages"] as Array):
			stage["delay"] = 0.0
			stage.erase("until_alive_at_most")
		spawner.set_seed(int(_def.get("wave_seed", 1)))
		spawner.plan = WavePlan.new(config, spawner.rng())
	# Keep the player alive for the whole capture.
	player.health.set_max_health(float(_def.get("player_max_health", 9999.0)))
	player.health.heal(player.health.get_max_health())
	# Capture-only: stop mouse aim so the player keeps facing -Z.
	if bool(_def.get("freeze_aim", false)):
		player.camera = null
	# Capture-only: fixed seed so the heavy's element-status rolls repeat between runs.
	if _def.has("status_seed"):
		player.status_rng.seed = int(_def["status_seed"])
	# Capture-only: use another class's heavy (the Wizard targeted_aoe proof; no class is built).
	if _def.has("heavy_class"):
		player.use_heavy_class(String(_def["heavy_class"]))
	# Capture-only: the heavy's ground aim point, as an [x, z] offset from the player.
	if _def.has("aim_point_offset"):
		var aim_values: Array = _def["aim_point_offset"]
		player.aim_point_override = player.global_position + Vector3(float(aim_values[0]), 0.0, float(aim_values[1]))
	# Capture-only: with frozen aim, still show the aim reticle this far ahead.
	var indicator: AimIndicator = _main.get_node_or_null("AimIndicator")
	if indicator != null:
		indicator.preview_distance = float(_def.get("aim_preview_distance", 0.0))

	var offset_values: Array = _def.get("origin_offset", [3.0, 0.0, -2.0])
	var origin := Vector3(float(offset_values[0]), float(offset_values[1]), float(offset_values[2]))
	var spacing_values: Array = _def.get("spacing", [1.3, 1.2])
	var spacing := Vector2(float(spacing_values[0]), float(spacing_values[1]))
	var columns: int = maxi(int(_def.get("columns", 3)), 1)
	var index := 0
	for group: Dictionary in _def.get("groups", []):
		var packed: PackedScene = load(String(group["scene"]))
		for i in range(int(group.get("count", 1))):
			var enemy: Enemy = packed.instantiate()
			_main.add_child(enemy)
			enemy.global_position = player.global_position + origin + Vector3(
				float(index % columns) * spacing.x, 0.0, float(index / columns) * spacing.y)
			# Capture-only: idle enemies keep their spread positions for readable shots.
			enemy.target = null if bool(_def.get("enemies_idle", false)) else player
			_enemies.append(enemy)
			index += 1

	# Capture-only: no automatic light attack, so it neither knocks the enemies out
	# of the cards' reach nor draws its own flash over the card visuals.
	if bool(_def.get("disable_auto_attack", false)):
		player.attacks.set_auto(&"light", false)

	# Capture-only: tough enemies so the player's auto attack does not clear the stage.
	if _def.has("enemy_max_health"):
		for enemy in _enemies:
			enemy.health.set_max_health(float(_def["enemy_max_health"]))
			enemy.health.heal(enemy.health.get_max_health())
	# Capture-only: start below full HP so a heal is observable.
	if _def.has("player_start_damage"):
		player.health.take_damage(float(_def["player_start_damage"]), "physical")

	var fractions: Array = _def.get("hp_fractions", [])
	for i in range(mini(fractions.size(), _enemies.size())):
		var health: Health = _enemies[i].health
		var lost: float = health.get_max_health() * (1.0 - float(fractions[i]))
		if lost > 0.0:
			health.take_damage(lost, "physical")

	# Capture-only: ranks and a scripted stun (stun_indices at stun_at seconds), for the stun cue shots.
	for boss_index: int in _def.get("boss_indices", []):
		if boss_index < _enemies.size():
			_enemies[boss_index].status_manager.rank = "boss"

	for burn_index: int in _def.get("burn_indices", []):
		if burn_index < _enemies.size():
			var manager: StatusEffectManager = _enemies[burn_index].get_node("StatusEffectManager")
			manager.apply_status("burn", StatusDatabase.get_status("burn"), float(_def.get("burn_duration", 8.0)))


func _process(delta: float) -> void:
	_elapsed += delta
	# Scenario-only death trigger (capture tooling; there is no debug key for it).
	if not _kill_done and _def.has("kill_player_at") and _elapsed >= float(_def["kill_player_at"]):
		_kill_done = true
		var player: Player = _main.get_node("Player")
		player.health.take_damage(player.health.get_max_health() * 2.0, "physical")
	# Scenario-only scripted right click (heavy attack) for captures.
	if not _heavy_press_done and _def.has("heavy_at") and _elapsed >= float(_def["heavy_at"]):
		_heavy_press_done = true
		_heavy_release_at = _elapsed + 0.1
		_send_action(&"attack_heavy", true)
	if _heavy_release_at >= 0.0 and _elapsed >= _heavy_release_at:
		_heavy_release_at = -1.0
		_send_action(&"attack_heavy", false)
	_process_stuns()
	_process_casts()
	_process_previews()
	if not _settings_opened and _def.has("open_settings_at") and _elapsed >= float(_def["open_settings_at"]):
		_settings_opened = true
		_send_action(&"pause", true)
		_send_action(&"pause", false)
		print("Scenario: t=%.2f pause key (settings screen)" % _elapsed)
	var late: Dictionary = _def.get("late_hit", {})
	if late.is_empty() or _late_hit_done or _elapsed < float(late.get("at", 2.4)):
		return
	_late_hit_done = true
	for hit_index: int in late.get("indices", []):
		if hit_index < _enemies.size() and is_instance_valid(_enemies[hit_index]):
			_enemies[hit_index].health.take_damage(float(late.get("amount", 5.0)), "physical")


## Scripted stun (scenario "stun_indices" at "stun_at" seconds, base length "stun_duration"),
## through the real status path, so rank and diminishing returns apply (a boss shows IMMUNE).
func _process_stuns() -> void:
	if _stun_done or not _def.has("stun_indices") or _elapsed < float(_def.get("stun_at", 0.5)):
		return
	_stun_done = true
	for stun_index: int in _def["stun_indices"]:
		if stun_index < _enemies.size() and is_instance_valid(_enemies[stun_index]):
			_enemies[stun_index].status_manager.apply_status("stun", StatusDatabase.get_status("stun"), float(_def.get("stun_duration", 0.6)))


## Scripted held keys (scenario "previews": [{at, slot, card, release_at}]): the named card is
## forced into the slot, then the slot's key is pressed and (at release_at) released as real
## input events, so the Player's latch, the preview and the release cast all run for real.
func _process_previews() -> void:
	var previews: Array = _def.get("previews", [])
	var player: Player = _main.get_node("Player")
	while _preview_index < previews.size() and _elapsed >= float((previews[_preview_index] as Dictionary)["at"]):
		var preview: Dictionary = previews[_preview_index]
		_preview_index += 1
		var slot_type := String(preview["slot"])
		var slot: CardSlot = player.card_slots.get_slot(slot_type)
		var slot_number: int = CardSlotController.SLOT_TYPE_ORDER.find(slot_type) + 1
		if slot == null or slot_number <= 0:
			push_error("Scenario: unknown slot '%s'" % slot_type)
			continue
		slot.current_card_id = String(preview["card"])
		slot.cooldown_remaining = 0.0
		var action := StringName("slot_%d" % slot_number)
		_send_action(action, true)
		print("Scenario: t=%.2f hold %s (%s) in %s" % [_elapsed, action, preview["card"], slot_type])
		if preview.has("release_at"):
			_preview_releases.append({"at": float(preview["release_at"]), "action": action})
	var pending: Array[Dictionary] = []
	for release in _preview_releases:
		if _elapsed >= float(release["at"]):
			_send_action(release["action"], false)
			print("Scenario: t=%.2f release %s" % [_elapsed, release["action"]])
		else:
			pending.append(release)
	_preview_releases = pending


## Scripted card casts (scenario "casts": [{at, slot, card}]). The named card is
## forced into the slot's revealed position (deck order is random otherwise), then
## cast through the real CardSlotController. Half a second later the slot's
## remaining cooldown is re-read and must have dropped, which verifies cooling
## live; the result is printed ("Scenario: ...") and a failure is a push_error.
func _process_casts() -> void:
	var casts: Array = _def.get("casts", [])
	var player: Player = _main.get_node("Player")
	while _cast_index < casts.size() and _elapsed >= float((casts[_cast_index] as Dictionary)["at"]):
		var cast: Dictionary = casts[_cast_index]
		_cast_index += 1
		var slot_type := String(cast["slot"])
		var slot: CardSlot = player.card_slots.get_slot(slot_type)
		if slot == null:
			push_error("Scenario: unknown slot '%s'" % slot_type)
			continue
		slot.current_card_id = String(cast["card"])
		slot.cooldown_remaining = 0.0
		var ok: bool = player.card_slots.try_use(slot_type)
		print("Scenario: t=%.2f cast %s in %s ok=%s cooldown=%.2f" % [_elapsed, cast["card"], slot_type, ok, slot.cooldown_remaining])
		if not ok:
			push_error("Scenario: cast of '%s' failed" % cast["card"])
			continue
		_cooling_checks.append({"at": _elapsed + 0.5, "slot": slot_type, "before": slot.cooldown_remaining, "card": cast["card"]})
	var remaining: Array[Dictionary] = []
	for check in _cooling_checks:
		if _elapsed < float(check["at"]):
			remaining.append(check)
			continue
		var now: float = player.card_slots.get_slot(String(check["slot"])).cooldown_remaining
		var cooled: bool = now < float(check["before"])
		print("Scenario: t=%.2f slot %s cooling %.2f -> %.2f %s" % [_elapsed, check["slot"], check["before"], now, "OK" if cooled else "FAIL"])
		if not cooled:
			push_error("Scenario: slot '%s' did not cool after casting '%s'" % [check["slot"], check["card"]])
	_cooling_checks = remaining


## A real InputEventAction through the viewport, so it reaches the Player's
## _unhandled_input latch like a click would (Input.action_press emits no event).
static func _send_action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
