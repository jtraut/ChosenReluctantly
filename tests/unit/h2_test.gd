class_name H2Test
extends GdUnitTestSuite
## H2 (gameplay-dev), updated for H3: the dodge switch, the screens that swallow a mashed Space, and the Movement/Utility keys. H2 shipped
## the dodge off with Space on Movement; H3 turned the dodge back on (Space) and moved Movement to Ctrl (Shift+Ctrl swaps), so the
## switch-off cases force the switch off with PlayerConfig.set_dodge_enabled(false). Utility is still F and Shift+F.
## Game Over and the class pick still ignore Space and wait out the arm delay.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const DEFAULTS := "res://data/settings.json"
const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"

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
	ClassPickScreen.enabled_override = false
	GamePause.reset()
	Settings.use_store(_original_store)
	if _main != null and is_instance_valid(_main):
		get_tree().current_scene = null
		_main.free()
	_main = null
	Juice.reset()


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


## A real key event through the viewport dispatch, so the exact-match rule in Player._unhandled_input is what runs.
func _key(code: Key, pressed: bool, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.shift_pressed = shift
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


# ---- The data ----

func test_the_shipped_player_file_is_valid_and_has_the_dodge_on() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PlayerConfig.PATH))
	assert_array(PlayerConfig.validate(parsed)).is_empty()
	assert_bool(typeof((parsed as Dictionary)["dodge"]["enabled"]) == TYPE_BOOL).override_failure_message("the shipped file must state dodge.enabled").is_true()
	assert_bool(bool((parsed as Dictionary)["dodge"]["enabled"])).is_true()
	assert_bool(PlayerConfig.dodge_enabled()).is_true()
	assert_bool(bool(PlayerConfig.DEFAULTS["dodge"]["enabled"])).override_failure_message("the code fallback matches the shipped value").is_true()


func test_enabled_must_be_a_boolean_and_may_be_missing() -> void:
	var good: Dictionary = {"dodge": {"speed": 20.0, "duration": 0.25, "cooldown": 1.2, "block_ticks_after_pause": 2, "charges": 3, "min_charges": 0, "max_charges": 4}}
	assert_array(PlayerConfig.validate(good)).is_empty()
	for value: Variant in [true, false]:
		var copy: Dictionary = good.duplicate(true)
		(copy["dodge"] as Dictionary)["enabled"] = value
		assert_array(PlayerConfig.validate(copy)).is_empty()
	for bad: Variant in ["yes", 1, null]:
		var copy: Dictionary = good.duplicate(true)
		(copy["dodge"] as Dictionary)["enabled"] = bad
		assert_array(PlayerConfig.validate(copy)).override_failure_message("enabled = %s" % str(bad)).is_not_empty()


func test_set_dodge_enabled_flips_the_cache_and_reload_restores_the_file() -> void:
	PlayerConfig.set_dodge_enabled(false)
	assert_bool(PlayerConfig.dodge_enabled()).is_false()
	PlayerConfig.reload()
	assert_bool(PlayerConfig.dodge_enabled()).is_true()


func test_the_shipped_bindings_pass_the_validator_with_the_dodge_on_space() -> void:
	var bindings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(InputBindings.BINDINGS_PATH))
	assert_array(InputLabels.find_conflicts(bindings)).is_empty()
	assert_array(InputLabels.find_missing_required(bindings, PlayerConfig.dodge_enabled())).is_empty()
	assert_bool(bindings.has("dodge")).is_true()
	assert_array(bindings["dodge"] as Array).has_size(1)
	assert_array(InputMap.action_get_events(&"dodge")).has_size(1)
	assert_int(InputBindings.last_conflicts.size()).is_equal(0)


func test_the_validator_rule_for_an_unbound_action() -> void:
	var bindings: Dictionary = {"dodge": [], "slot_1": [{"type": "key", "keycode": "Q"}]}
	assert_array(InputLabels.find_conflicts(bindings)).is_empty()
	assert_array(InputLabels.find_missing_required(bindings, false)).is_empty()
	assert_array(InputLabels.find_missing_required(bindings, true)).has_size(1)
	assert_array(InputLabels.find_missing_required({"slot_1": []}, true)).has_size(1)
	bindings["dodge"] = [{"type": "key", "keycode": "G"}]
	assert_array(InputLabels.find_missing_required(bindings, true)).is_empty()
	# A dodge key that clashes with a slot key is still a conflict.
	bindings["dodge"] = [{"type": "key", "keycode": "Q"}]
	assert_array(InputLabels.find_conflicts(bindings)).has_size(1)


func test_the_slot_keys_and_labels() -> void:
	assert_str(InputLabels.slot_key("movement")).is_equal("Ctrl")
	assert_str(InputLabels.slot_swap_key("movement")).is_equal("Shift+Ctrl")
	assert_str(InputLabels.slot_key("utility")).is_equal("F")
	assert_str(InputLabels.slot_swap_key("utility")).is_equal("Shift+F")
	assert_str(InputLabels.for_action(&"dodge")).is_equal("Space")


# ---- Switch off, in the scene ----

func test_with_the_switch_off_a_dodge_press_does_nothing_and_charges_do_not_tick() -> void:
	PlayerConfig.set_dodge_enabled(false)
	var player := await _spawn()
	assert_bool(player.dodge_enabled()).is_false()
	var state: Dictionary = player.get_dodge_state()
	assert_bool(bool(state["enabled"])).is_false()
	assert_bool(bool(state["available"])).is_false()
	var full: int = player.dodge_charges.current
	TestInput.press(&"dodge")
	await _frames(3)
	TestInput.release(&"dodge")
	assert_float(player._forced_move_time_remaining).is_equal(0.0)
	assert_int(player.dodge_charges.current).is_equal(full)
	# Charges do not tick while off: a spent pool stays spent.
	player.dodge_charges.try_spend(player.dodge_charges_max())
	var spent: int = player.dodge_charges.current
	await _frames(90)
	assert_int(player.dodge_charges.current).override_failure_message("a charge came back with the switch off").is_equal(spent)
	for key: String in ["enabled", "current", "max", "recharging", "recharge_progress", "recharge_remaining", "available"]:
		assert_bool(player.get_dodge_state().has(key)).override_failure_message("get_dodge_state() lost '%s'" % key).is_true()


func test_switching_on_brings_the_dodge_back() -> void:
	DodgeSwitch.enable()
	var player := await _spawn()
	assert_bool(bool(player.get_dodge_state()["enabled"])).is_true()
	TestInput.press(&"dodge")
	await _frames(2)
	TestInput.release(&"dodge")
	assert_bool(player._forced_move_time_remaining > 0.0 or player.dodge_charges.current < player.dodge_charges_max()).is_true()


func test_ctrl_casts_movement_with_hold_to_preview_and_cast_on_release() -> void:
	var player := await _spawn()
	_key(KEY_CTRL, true)
	await _frames(3)
	assert_bool(player.cast_input.is_previewing()).is_true()
	assert_int(player.cast_input.preview_slot).is_equal(CardSlotController.SLOT_TYPE_ORDER.find("movement"))
	assert_array(_casts).is_empty()
	_key(KEY_CTRL, false)
	await _frames(3)
	assert_array(_casts).contains_exactly(["movement"])
	assert_int(player.dodge_charges.current).override_failure_message("Ctrl must not also dodge").is_equal(player.dodge_charges_max())


func test_f_casts_utility() -> void:
	var player := await _spawn()
	_key(KEY_F, true)
	await _frames(2)
	assert_int(player.cast_input.preview_slot).is_equal(CardSlotController.SLOT_TYPE_ORDER.find("utility"))
	_key(KEY_F, false)
	await _frames(3)
	assert_array(_casts).contains_exactly(["utility"])


func test_shift_ctrl_and_shift_f_swap_without_casting_or_previewing() -> void:
	var player := await _spawn()
	for pair: Array in [[KEY_CTRL, "movement"], [KEY_F, "utility"]]:
		var slot_type: String = pair[1]
		assert_float(player.card_slots.get_slot(slot_type).cooldown_remaining).is_equal(0.0)
		_key(pair[0], true, true)
		await _frames(3)
		assert_bool(player.cast_input.is_previewing()).override_failure_message("Shift+%s previewed" % slot_type).is_false()
		assert_float(player.card_slots.get_slot(slot_type).cooldown_remaining).override_failure_message("Shift+%s did not swap" % slot_type).is_greater(0.0)
		_key(pair[0], false, true)
		await _frames(2)
	assert_array(_casts).is_empty()


# ---- Space still reaches the Player after every screen that used it (it is ui_accept too) ----

func _run_main() -> Main:
	RunSession.begin_new_run(42)
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames(3)
	main.player.card_slots.card_cast.connect(func(slot_type: String, _card: String) -> void: _casts.append(slot_type))
	return main


## No Control may hold focus during play (it would take Space as ui_accept), and Ctrl press then release casts Movement once.
func _assert_ctrl_casts_movement_once(main: Main, where: String) -> void:
	assert_object(main.get_viewport().gui_get_focus_owner()).override_failure_message("%s: a Control still has focus" % where).is_null()
	_casts.clear()
	main.player.card_slots.get_slot("movement").cooldown_remaining = 0.0
	_key(KEY_CTRL, true)
	await _frames(2)
	_key(KEY_CTRL, false)
	await _frames(3)
	assert_array(_casts).override_failure_message("%s: Ctrl did not cast Movement exactly once" % where).contains_exactly(["movement"])


func test_ctrl_casts_movement_after_the_class_pick_closes() -> void:
	ClassPickScreen.enabled_override = true
	var main: Main = await _run_main()
	var screen := main.get_node("ClassPickScreen") as ClassPickScreen
	assert_bool(screen.is_open()).is_true()
	screen.disarm()
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	await _frames(2)
	assert_bool(screen.is_open()).override_failure_message("Space confirmed the class pick").is_true()
	screen.confirm()
	await _frames(3)
	assert_bool(screen.is_open()).is_false()
	await _assert_ctrl_casts_movement_once(main, "after the class pick")


func test_ctrl_casts_movement_after_a_run_prompt_closes() -> void:
	var main: Main = await _run_main()
	var prompt := main.get_node("RoomClearedScreen") as RunPromptScreen
	prompt.show_content({"title": "t", "rows": [], "button": "Continue"})
	prompt.disarm()
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	await _frames(2)
	assert_bool(prompt.visible).override_failure_message("Space confirmed the prompt").is_true()
	prompt.button.pressed.emit()
	await _frames(3)
	await _assert_ctrl_casts_movement_once(main, "after Continue")


func test_ctrl_casts_movement_after_resuming_from_the_pause_screen() -> void:
	var main: Main = await _run_main()
	var settings := main.get_node("SettingsScreen") as SettingsScreen
	settings.open()
	await _frames(2)
	assert_bool(settings.is_open()).is_true()
	# Pause and settings keep Space as ui_accept: on the focused Resume button it closes the screen (deliberate menu), and
	# it must not also cast on the way out.
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	await _frames(4)
	assert_bool(settings.is_open()).is_false()
	assert_array(_casts).override_failure_message("Space on Resume also cast").is_empty()
	await _frames(8)  # past the post-resume dodge/cast block ticks
	await _assert_ctrl_casts_movement_once(main, "after Resume")


# ---- Game Over ----

func test_game_over_waits_out_the_arm_delay_and_space_never_confirms() -> void:
	var stub := GameOverStub.new()
	add_child(stub)
	auto_free(stub)
	var screen: GameOverScreen = (load("res://scenes/ui/GameOverScreen.tscn") as PackedScene).instantiate()
	screen.bind(stub)
	add_child(screen)
	auto_free(screen)
	stub.game_over_ready.emit()
	assert_bool(screen.is_armed()).is_false()
	screen.try_again.pressed.emit()  # Enter or a click inside the delay
	assert_int(stub.restarts).is_equal(0)
	# Space is swallowed even when armed: a focused Button would take it as ui_accept.
	screen.disarm()
	assert_bool(screen.is_armed()).is_true()
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	await get_tree().process_frame
	assert_int(stub.restarts).override_failure_message("Space confirmed Game Over").is_equal(0)
	screen.try_again.pressed.emit()
	assert_int(stub.restarts).is_equal(1)


func test_the_game_over_hint_does_not_offer_space() -> void:
	assert_str(String(UiConfig.game_over()["hint"])).not_contains("Space")


class GameOverStub extends Node:
	signal game_over_ready()
	var restarts: int = 0

	func is_game_over() -> bool:
		return false

	func restart_arena() -> void:
		restarts += 1
