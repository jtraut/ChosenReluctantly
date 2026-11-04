class_name CastInput6aTest
extends GdUnitTestSuite
## Slice 6a: the press / hold / release card input model, in the real Main scene. Events
## go through Input.parse_input_event (TestInput) so they reach Player._unhandled_input
## exactly like keys do. Settings are injected with a temp path: the real user file is
## never read or written.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const DEFAULTS := "res://data/settings.json"
const SLOT_1: StringName = &"slot_1"
const SLOT_2: StringName = &"slot_2"

var _original_store: SettingsStore = null
var _casts: Array = []
var _root_main: Main = null


func before_test() -> void:
	CardDatabase.load_all()
	_original_store = Settings.store
	Settings.use_store(SettingsStore.new(DEFAULTS, "user://tests/never_written_settings.cfg"))
	_casts = []


func after_test() -> void:
	Settings.use_store(_original_store)
	if _root_main != null and is_instance_valid(_root_main):
		get_tree().current_scene = null
		_root_main.free()
	_root_main = null
	Juice.reset()
	TestInput.release(SLOT_1)
	TestInput.release(SLOT_2)


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	# Card effects spawn under current_scene (null under the test runner), so Main goes under the root.
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	_root_main = main
	main.player.card_slots.spawn_parent = main  # captured as null in Player._ready
	return main


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _ready_player() -> Player:
	var main := _spawn_main()
	await _frames(2)
	var player := main.player
	player.camera = null  # facing stays put; the mouse would turn it
	player.card_slots.card_cast.connect(func(slot_type: String, card_id: String) -> void: _casts.append([slot_type, card_id]))
	return player


func _use_press_mode() -> void:
	Settings.set_value(Settings.CAST_TRIGGER, Settings.TRIGGER_PRESS)


# --- the pure model ---------------------------------------------------------------------------

func test_model_release_mode_previews_on_press_and_casts_once_on_release() -> void:
	var input := CastInput.new()
	assert_int(input.press(2, true)).is_equal(CastInput.NONE)
	assert_int(input.preview_slot).is_equal(2)
	assert_int(input.release(2)).is_equal(2)
	assert_bool(input.is_previewing()).is_false()
	assert_int(input.release(2)).is_equal(CastInput.NONE)


func test_model_press_mode_casts_on_press_and_never_previews() -> void:
	var input := CastInput.new()
	assert_int(input.press(1, false)).is_equal(1)
	assert_bool(input.is_previewing()).is_false()
	assert_int(input.release(1)).is_equal(CastInput.NONE)


func test_model_switching_keys_moves_the_preview_and_ignores_the_old_release() -> void:
	var input := CastInput.new()
	input.press(0, true)
	input.press(3, true)
	assert_int(input.preview_slot).is_equal(3)
	assert_int(input.release(0)).is_equal(CastInput.NONE)
	assert_int(input.preview_slot).is_equal(3)
	assert_int(input.release(3)).is_equal(3)


func test_model_cancel_drops_the_preview_and_the_later_release_does_not_cast() -> void:
	var input := CastInput.new()
	input.press(4, true)
	assert_bool(input.cancel()).is_true()
	assert_bool(input.cancel()).is_false()
	assert_int(input.release(4)).is_equal(CastInput.NONE)


# --- release mode in the scene ----------------------------------------------------------------

func test_release_mode_press_only_previews_and_release_casts_exactly_once() -> void:
	var player := await _ready_player()
	TestInput.press(SLOT_1)
	await _frames(3)
	assert_array(_casts).is_empty()
	assert_int(player.cast_input.preview_slot).is_equal(0)
	TestInput.release(SLOT_1)
	await _frames(4)
	assert_array(_casts).has_size(1)
	assert_str(_casts[0][0]).is_equal("attack_single")
	assert_bool(player.cast_input.is_previewing()).is_false()
	await _frames(10)
	assert_array(_casts).has_size(1)


func test_press_and_release_inside_one_tick_still_cast_once() -> void:
	var player := await _ready_player()
	TestInput.tap(SLOT_1)
	await _frames(3)
	assert_array(_casts).has_size(1)
	assert_bool(player.cast_input.is_previewing()).is_false()


func test_release_on_a_cooling_slot_does_not_cast_and_clears_the_preview() -> void:
	var player := await _ready_player()
	var slot := player.card_slots.get_slot("attack_single")
	slot.cooldown_remaining = 30.0
	TestInput.press(SLOT_1)
	await _frames(2)
	assert_int(player.cast_input.preview_slot).is_equal(0)
	TestInput.release(SLOT_1)
	await _frames(3)
	assert_array(_casts).is_empty()
	assert_bool(player.cast_input.is_previewing()).is_false()
	assert_float(slot.cooldown_remaining).is_greater(25.0)


func test_slot_that_becomes_ready_while_held_casts_on_release() -> void:
	var player := await _ready_player()
	var slot := player.card_slots.get_slot("attack_single")
	slot.cooldown_remaining = 0.1
	TestInput.press(SLOT_1)
	await _frames(20)
	TestInput.release(SLOT_1)
	await _frames(3)
	assert_array(_casts).has_size(1)


func test_switching_keys_previews_the_newest_and_only_its_release_casts() -> void:
	var player := await _ready_player()
	TestInput.press(SLOT_1)
	await _frames(2)
	TestInput.press(SLOT_2)
	await _frames(2)
	assert_int(player.cast_input.preview_slot).is_equal(1)
	TestInput.release(SLOT_1)
	await _frames(2)
	assert_array(_casts).is_empty()
	assert_int(player.cast_input.preview_slot).is_equal(1)
	TestInput.release(SLOT_2)
	await _frames(3)
	assert_array(_casts).has_size(1)
	assert_str(_casts[0][0]).is_equal("attack_aoe")


# --- press mode ---------------------------------------------------------------------------------

func test_press_mode_casts_on_press_with_no_preview_and_release_does_nothing() -> void:
	var player := await _ready_player()
	_use_press_mode()
	TestInput.press(SLOT_1)
	await _frames(3)
	assert_array(_casts).has_size(1)
	assert_bool(player.cast_input.is_previewing()).is_false()
	TestInput.release(SLOT_1)
	await _frames(3)
	assert_array(_casts).has_size(1)


func test_press_mode_on_a_cooling_slot_does_not_cast() -> void:
	var player := await _ready_player()
	_use_press_mode()
	player.card_slots.get_slot("attack_single").cooldown_remaining = 30.0
	TestInput.tap(SLOT_1)
	await _frames(3)
	assert_array(_casts).is_empty()


# --- cancel cases -------------------------------------------------------------------------------

func test_death_cancels_the_preview_without_casting() -> void:
	var player := await _ready_player()
	TestInput.press(SLOT_1)
	await _frames(2)
	assert_bool(player.cast_input.is_previewing()).is_true()
	player.health.take_damage(player.health.get_max_health() * 2.0)
	assert_bool(player.cast_input.is_previewing()).is_false()
	TestInput.release(SLOT_1)
	await _frames(3)
	assert_array(_casts).is_empty()
	# A dead player cannot start a new preview either (the Game Over screen is up by then).
	TestInput.press(SLOT_1)
	await _frames(2)
	assert_bool(player.cast_input.is_previewing()).is_false()


func test_cancel_cast_preview_is_what_a_settings_screen_or_pause_calls() -> void:
	var player := await _ready_player()
	TestInput.press(SLOT_1)
	await _frames(2)
	player.cancel_cast_preview()
	assert_bool(player.cast_input.is_previewing()).is_false()
	TestInput.release(SLOT_1)
	await _frames(3)
	assert_array(_casts).is_empty()


func test_cancel_also_drops_a_cast_already_latched_for_the_next_tick() -> void:
	var player := await _ready_player()
	TestInput.press(SLOT_1)
	TestInput.release(SLOT_1)
	player.cancel_cast_preview()
	await _frames(3)
	assert_array(_casts).is_empty()


func test_changing_the_cast_setting_mid_hold_cancels_the_preview() -> void:
	var player := await _ready_player()
	TestInput.press(SLOT_1)
	await _frames(2)
	_use_press_mode()
	assert_bool(player.cast_input.is_previewing()).is_false()
	TestInput.release(SLOT_1)
	await _frames(3)
	assert_array(_casts).is_empty()


func test_dead_card_swap_never_casts_and_leaves_the_preview_alone() -> void:
	var player := await _ready_player()
	TestInput.press(SLOT_2)
	await _frames(2)
	TestInput.press(&"dead_card_swap_1")
	await _frames(3)
	assert_array(_casts).is_empty()
	assert_int(player.cast_input.preview_slot).is_equal(1)
	assert_float(player.card_slots.get_slot("attack_single").cooldown_remaining).is_greater(0.0)


## The physical key bound to a slot action, read from the live InputMap (built from data/input_bindings.json),
## ignoring bindings that need a modifier (those are the swap actions).
func _slot_key(action: StringName) -> Key:
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event := event as InputEventKey
		if key_event != null and not key_event.shift_pressed and not key_event.ctrl_pressed and not key_event.alt_pressed:
			return key_event.physical_keycode
	assert_bool(false).override_failure_message("no plain key bound to %s" % action).is_true()
	return KEY_NONE


func test_shift_slot_key_is_a_swap_not_a_cast_and_a_shift_release_still_ends_the_hold() -> void:
	var player := await _ready_player()
	var swap := InputEventKey.new()
	swap.physical_keycode = _slot_key(SLOT_1)
	swap.shift_pressed = true
	swap.pressed = true
	player._unhandled_input(swap)
	await _frames(3)
	assert_array(_casts).is_empty()
	assert_bool(player.cast_input.is_previewing()).is_false()
	assert_float(player.card_slots.get_slot("attack_single").cooldown_remaining).is_greater(0.0)
	# Plain slot-2 key held, Shift pressed meanwhile, then 2 released with Shift down: still ends the hold.
	var down := InputEventKey.new()
	down.physical_keycode = _slot_key(SLOT_2)
	down.pressed = true
	player._unhandled_input(down)
	assert_int(player.cast_input.preview_slot).is_equal(1)
	var up := InputEventKey.new()
	up.physical_keycode = _slot_key(SLOT_2)
	up.shift_pressed = true
	up.pressed = false
	player._unhandled_input(up)
	await _frames(3)
	assert_array(_casts).has_size(1)


func test_ctrl_held_does_not_block_a_slot_key_and_plain_slot_key_previews() -> void:
	# H3: Ctrl is the Movement key and is held during previews, so a slot key pressed with Ctrl down must still work
	# (it used to be dropped by the exact-match rule). Shift is what turns a slot key into a swap.
	var player := await _ready_player()
	var ctrl := InputEventKey.new()
	ctrl.physical_keycode = _slot_key(SLOT_1)
	ctrl.ctrl_pressed = true
	ctrl.pressed = true
	player._unhandled_input(ctrl)
	await _frames(3)
	assert_int(player.cast_input.preview_slot).is_equal(0)
	assert_float(player.card_slots.get_slot("attack_single").cooldown_remaining).override_failure_message("Ctrl+slot key must not swap").is_equal(0.0)
	var up := InputEventKey.new()
	up.physical_keycode = _slot_key(SLOT_1)
	up.ctrl_pressed = true
	up.pressed = false
	player._unhandled_input(up)
	await _frames(3)
	assert_int(_casts.size()).override_failure_message("Ctrl+slot key release must cast once").is_equal(1)
	var plain := InputEventKey.new()
	plain.physical_keycode = _slot_key(SLOT_1)
	plain.pressed = true
	player._unhandled_input(plain)
	assert_int(player.cast_input.preview_slot).is_equal(0)


func test_among_the_game_bindings_shift_is_used_only_by_the_five_swap_actions() -> void:
	var bindings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/input_bindings.json"))
	for action_name: String in bindings.keys():
		var action := StringName(action_name)
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey and (event as InputEventKey).shift_pressed:
				assert_bool(String(action).begins_with("dead_card_swap_")).override_failure_message("%s uses Shift" % action).is_true()


# --- UI consuming input ---------------------------------------------------------------------------

class Consumer extends Node:
	func _input(event: InputEvent) -> void:
		if not (event is InputEventMouseMotion):
			get_viewport().set_input_as_handled()


func test_input_consumed_by_a_ui_screen_does_not_cast_or_preview_or_attack() -> void:
	var player := await _ready_player()
	var consumer: Consumer = auto_free(Consumer.new())
	add_child(consumer)
	TestInput.tap(SLOT_1)
	TestInput.press(SLOT_2)
	TestInput.tap(&"attack_heavy")
	await _frames(4)
	assert_array(_casts).is_empty()
	assert_bool(player.cast_input.is_previewing()).is_false()
	assert_bool(player.attacks.is_winding_up(&"heavy")).is_false()
	TestInput.release(SLOT_2)
	# Control: once the screen is gone the same input works.
	consumer.free()
	TestInput.tap(SLOT_1)
	await _frames(3)
	assert_array(_casts).has_size(1)


func test_heavy_click_is_latched_until_a_physics_tick_takes_it() -> void:
	var player := await _ready_player()
	var click := InputEventAction.new()
	click.action = &"attack_heavy"
	click.pressed = true
	player._unhandled_input(click)
	assert_bool(player.attacks.is_winding_up(&"heavy")).is_false()
	player._physics_process(0.016)
	assert_bool(player.attacks.is_winding_up(&"heavy")).is_true()
