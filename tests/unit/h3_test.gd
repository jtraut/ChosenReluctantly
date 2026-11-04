class_name H3Test
extends GdUnitTestSuite
## H3 (gameplay-dev): the dodge returns (Space, Rogue 2 charges, Wizard 1) and Movement moves to Ctrl.
## Ctrl is a held modifier key, so these send key events the way Windows does (measured with real key presses on Godot 4.7.2):
## a modifier key's own event never carries its own flag, and the key pressed second carries the first one's flag
## (Shift down, then Ctrl: the Ctrl event has shift_pressed; Ctrl down, then Shift: the Shift event has ctrl_pressed).
## Left and right Ctrl both arrive as physical KEY_CTRL.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const DEFAULTS := "res://data/settings.json"

var _original_store: SettingsStore = null
var _casts: Array[String] = []
var _main: Main = null


func before_test() -> void:
	CardDatabase.load_all()
	PlayerConfig.reload()
	_original_store = Settings.store
	Settings.use_store(SettingsStore.new(DEFAULTS, "user://tests/never_written_settings.cfg"))
	_casts = []


func after_test() -> void:
	DodgeSwitch.reset()
	GamePause.reset()
	Settings.use_store(_original_store)
	if _main != null and is_instance_valid(_main):
		get_tree().current_scene = null
		_main.free()
	_main = null
	Juice.reset()
	# Leave no key logically down for the next suite.
	for code: Key in [KEY_CTRL, KEY_SHIFT, KEY_W, KEY_SPACE, KEY_Q]:
		_key(code, false)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _spawn() -> Player:
	_main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(_main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_main.player.card_slots.spawn_parent = _main
	await _frames(2)
	_main.player.camera = null
	_main.player.attacks.set_auto(&"light", false)
	_main.player.attacks.set_auto(&"heavy", false)
	_main.player.card_slots.card_cast.connect(func(slot_type: String, _card: String) -> void: _casts.append(slot_type))
	return _main.player


func _key(code: Key, pressed: bool, shift: bool = false, ctrl: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _click(button: MouseButton, pressed: bool, ctrl: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.ctrl_pressed = ctrl
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


# ---- The data ----

func test_the_shipped_data_has_the_dodge_on_with_two_charges_and_per_class_counts() -> void:
	assert_bool(PlayerConfig.dodge_enabled()).is_true()
	assert_int(int(PlayerConfig.dodge()["charges"])).is_equal(2)
	assert_int(CharacterDatabase.dodge_charges("rogue", 99)).is_equal(2)
	assert_int(CharacterDatabase.dodge_charges("wizard", 99)).is_equal(1)


func test_the_shipped_bindings_are_clean_and_label_correctly() -> void:
	var bindings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(InputBindings.BINDINGS_PATH))
	assert_array(InputLabels.find_conflicts(bindings)).is_empty()
	assert_array(InputLabels.find_missing_required(bindings, true)).is_empty()
	assert_int(InputBindings.last_conflicts.size()).is_equal(0)
	assert_str(InputLabels.for_action(&"dodge")).is_equal("Space")
	assert_str(InputLabels.slot_key("movement")).is_equal("Ctrl")
	assert_str(InputLabels.slot_swap_key("movement")).is_equal("Shift+Ctrl")
	assert_str(InputLabels.slot_key("utility")).is_equal("F")


# ---- Space dodges, Ctrl casts Movement ----

func test_space_dodges_and_does_not_cast_movement() -> void:
	var player := await _spawn()
	var full: int = player.dodge_charges.current
	assert_int(full).is_equal(2)
	_key(KEY_SPACE, true)
	await _frames(2)
	_key(KEY_SPACE, false)
	await _frames(2)
	assert_int(player.dodge_charges.current).is_equal(full - 1)
	assert_array(_casts).is_empty()
	assert_bool(player.cast_input.is_previewing()).is_false()


func test_ctrl_alone_previews_then_casts_on_release_and_does_not_dodge() -> void:
	var player := await _spawn()
	_key(KEY_CTRL, true)
	await _frames(3)
	assert_int(player.cast_input.preview_slot).is_equal(CardSlotController.SLOT_TYPE_ORDER.find("movement"))
	assert_array(_casts).is_empty()
	_key(KEY_CTRL, false)
	await _frames(3)
	assert_array(_casts).contains_exactly(["movement"])
	assert_int(player.dodge_charges.current).is_equal(player.dodge_charges_max())


func test_while_ctrl_is_held_wasd_still_moves_and_clicks_still_attack_and_release_casts() -> void:
	var player := await _spawn()
	var light_clicks: Array[int] = [0]
	player.attacks.attack_started.connect(func(_id: StringName) -> void: light_clicks[0] += 1)
	_key(KEY_CTRL, true)
	await _frames(2)
	_key(KEY_W, true, false, true)
	await _frames(2)
	assert_float(Input.get_action_strength(&"move_forward")).override_failure_message("W stopped working with Ctrl held").is_equal(1.0)
	assert_bool(player.cast_input.is_previewing()).is_true()
	_click(MOUSE_BUTTON_LEFT, true, true)
	await _frames(3)
	_click(MOUSE_BUTTON_LEFT, false, true)
	assert_int(light_clicks[0]).override_failure_message("left click did not attack with Ctrl held").is_greater(0)
	assert_bool(player.cast_input.is_previewing()).override_failure_message("a click dropped the preview").is_true()
	_key(KEY_W, false, false, true)
	_key(KEY_CTRL, false)
	await _frames(3)
	assert_array(_casts).contains_exactly(["movement"])


func test_right_click_attacks_with_ctrl_held() -> void:
	var player := await _spawn()
	var heavy_clicks: Array[int] = [0]
	player.attacks.attack_started.connect(func(id: StringName) -> void:
		if id == &"heavy":
			heavy_clicks[0] += 1)
	_key(KEY_CTRL, true)
	await _frames(2)
	_click(MOUSE_BUTTON_RIGHT, true, true)
	await _frames(3)
	_click(MOUSE_BUTTON_RIGHT, false, true)
	assert_int(heavy_clicks[0]).override_failure_message("right click did not attack with Ctrl held").is_greater(0)
	_key(KEY_CTRL, false)


func test_a_slot_key_pressed_while_ctrl_is_held_still_works() -> void:
	var player := await _spawn()
	_key(KEY_CTRL, true)
	await _frames(2)
	_key(KEY_Q, true, false, true)
	await _frames(2)
	assert_int(player.cast_input.preview_slot).override_failure_message("Q ignored while Ctrl held").is_equal(0)
	_key(KEY_Q, false, false, true)
	await _frames(3)
	assert_array(_casts).contains_exactly(["attack_single"])
	_key(KEY_CTRL, false)


# ---- Shift+Ctrl swaps without casting, whichever key goes down first ----

func _assert_swapped_without_cast(player: Player, order: String) -> void:
	assert_float(player.card_slots.get_slot("movement").cooldown_remaining).override_failure_message("%s: no swap" % order).is_greater(0.0)
	assert_array(_casts).override_failure_message("%s: something cast" % order).is_empty()
	assert_bool(player.cast_input.is_previewing()).override_failure_message("%s: preview left" % order).is_false()


func test_shift_then_ctrl_swaps_and_never_casts() -> void:
	var player := await _spawn()
	_key(KEY_SHIFT, true)
	_key(KEY_CTRL, true, true)  # the Ctrl event carries the Shift flag
	await _frames(3)
	_key(KEY_CTRL, false, true)
	_key(KEY_SHIFT, false)
	await _frames(3)
	_assert_swapped_without_cast(player, "shift first")


func test_ctrl_then_shift_swaps_drops_the_preview_and_release_never_casts() -> void:
	var player := await _spawn()
	_key(KEY_CTRL, true)
	await _frames(2)
	assert_bool(player.cast_input.is_previewing()).is_true()
	_key(KEY_SHIFT, true, false, true)  # the Shift event carries the Ctrl flag
	await _frames(3)
	_key(KEY_SHIFT, false, false, true)
	_key(KEY_CTRL, false)
	await _frames(3)
	_assert_swapped_without_cast(player, "ctrl first")


func test_shift_with_no_ctrl_held_swaps_nothing() -> void:
	var player := await _spawn()
	_key(KEY_SHIFT, true)
	await _frames(3)
	_key(KEY_SHIFT, false)
	await _frames(2)
	assert_float(player.card_slots.get_slot("movement").cooldown_remaining).is_equal(0.0)
	assert_float(player.card_slots.get_slot("utility").cooldown_remaining).is_equal(0.0)


func test_shift_q_still_swaps_without_casting() -> void:
	var player := await _spawn()
	_key(KEY_Q, true, true)
	await _frames(3)
	_key(KEY_Q, false, true)
	await _frames(2)
	assert_array(_casts).is_empty()


func test_space_still_dodges_while_ctrl_is_held_for_a_preview() -> void:
	var player := await _spawn()
	_key(KEY_CTRL, true)
	await _frames(2)
	_key(KEY_SPACE, true, false, true)
	await _frames(2)
	_key(KEY_SPACE, false, false, true)
	assert_int(player.dodge_charges.current).override_failure_message("Space did not dodge with Ctrl held").is_equal(player.dodge_charges_max() - 1)
	assert_bool(player.cast_input.is_previewing()).override_failure_message("the dodge dropped the Movement preview").is_true()
	_key(KEY_CTRL, false)


# ---- Fan of regrets: the drawn lanes are the pellets' path (H3 item 3) ----

## Starts a real boss volley with the player parked far off to the side (immune), records the lanes the way Boss draws them
## (origin = boss + MUZZLE along each lane direction, from the locked aim) and checks every pellet, every physics frame of its
## flight, sits on one of those lines and never passes the lane's drawn end.
func test_every_volley_pellet_stays_on_a_drawn_lane_for_its_whole_flight() -> void:
	BossConfig.reset_cache()
	BossStagger.disable()
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	_main = main
	main.player.camera = null
	main.player.health.damage_immune = true
	var boss: Boss = (load("res://scenes/enemies/BossGuardian.tscn") as PackedScene).instantiate()
	boss.position = Vector3(0.0, 0.0, -9.0)
	boss.target = main.player
	main.add_child(boss)
	boss.set_seed(3)
	boss.debug_script_attacks(["volley"] as Array[String])
	boss.begin_spawn_grace(0.0)
	main.player.global_position = Vector3(0.0, 0.0, 0.0)
	var attack: Dictionary = (BossConfig.boss("boss_guardian")["attacks"] as Dictionary)["volley"]
	var angles: Array[float] = BossRules.volley_angles(int(attack["count"]), float(attack["spread_degrees"]))
	var lock_dir: Vector3 = Vector3.ZERO
	var origin: Vector3 = Vector3.ZERO
	var half: float = BossRules.volley_half_width(attack)
	var lane_end: float = BossRules.MUZZLE + float(attack["shot_range"])
	var seen_pellets: int = 0
	var worst_offset: float = 0.0
	for frame in range(400):
		await get_tree().physics_frame
		if boss.state_name() == "WINDUP" and lock_dir == Vector3.ZERO:
			lock_dir = boss._lock_dir
			origin = boss.global_position
		for child in main.get_children():
			if not (child is Projectile) or String((child as Projectile)._exclude_team) != "enemy":
				continue
			seen_pellets += 1
			var rel: Vector3 = (child as Projectile).global_position - origin
			rel.y = 0.0
			var best: float = INF
			for angle: float in angles:
				var dir: Vector3 = lock_dir.rotated(Vector3.UP, deg_to_rad(angle))
				var along: float = rel.dot(dir)
				if along >= -0.01 and along <= lane_end + 0.2:
					best = minf(best, (rel - dir * along).length())
			worst_offset = maxf(worst_offset, best)
		if seen_pellets > 0 and boss.state_name() == "CHASE":
			break
	assert_int(seen_pellets).override_failure_message("no pellets were seen").is_greater(0)
	assert_float(worst_offset).override_failure_message("a pellet left its drawn lane by %.3f m" % worst_offset).is_less(0.03)
	assert_float(half).is_greater(float(attack["hit_radius"]))
