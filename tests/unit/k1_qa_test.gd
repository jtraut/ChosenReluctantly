class_name K1QaTest
extends GdUnitTestSuite
## K1 (qa): all five slot keys (Q, E, 1, 2, R today) preview on press and cast once on release, and their Shift swaps
## only swap; rebinds (a different key, a Shift combo, a mouse button) reach the HUD, the reward text and the pause
## hint with no code change. Keys are read from the live InputMap, never typed here.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const DEFAULTS := "res://data/settings.json"

var _original_store: SettingsStore = null
var _casts: Array = []
var _root_main: Main = null
var _saved: Dictionary = {}


func before_test() -> void:
	CardDatabase.load_all()
	_original_store = Settings.store
	Settings.use_store(SettingsStore.new(DEFAULTS, "user://tests/never_written_settings.cfg"))
	_casts = []
	_saved = {}
	for action: StringName in [&"slot_5", &"attack_heavy", &"pause", &"dodge"]:
		_saved[action] = InputMap.action_get_events(action)


func after_test() -> void:
	Settings.use_store(_original_store)
	for action: StringName in _saved.keys():
		InputMap.action_erase_events(action)
		for event: InputEvent in _saved[action]:
			InputMap.action_add_event(action, event)
	if _root_main != null and is_instance_valid(_root_main):
		get_tree().current_scene = null
		_root_main.free()
	_root_main = null
	Juice.reset()


func _ready_player() -> Player:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	_root_main = main
	main.player.card_slots.spawn_parent = main
	for i in range(2):
		await get_tree().physics_frame
	main.player.camera = null
	main.player.card_slots.card_cast.connect(func(slot_type: String, card_id: String) -> void: _casts.append([slot_type, card_id]))
	return main.player


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _event(action: StringName, pressed: bool, shift: bool = false) -> InputEventKey:
	var e: InputEventKey = (InputMap.action_get_events(action)[0] as InputEventKey).duplicate() as InputEventKey
	e.pressed = pressed
	if shift:
		e.shift_pressed = true
	return e


func test_every_slot_key_previews_on_press_and_casts_once_on_release() -> void:
	var player := await _ready_player()
	for i in range(Player.USE_ACTIONS.size()):
		_casts.clear()
		player._unhandled_input(_event(Player.USE_ACTIONS[i], true))
		assert_int(player.cast_input.preview_slot).override_failure_message("slot %d press did not preview" % (i + 1)).is_equal(i)
		await _frames(2)
		assert_array(_casts).override_failure_message("slot %d cast before release" % (i + 1)).is_empty()
		player._unhandled_input(_event(Player.USE_ACTIONS[i], false))
		await _frames(3)
		assert_array(_casts).override_failure_message("slot %d: expected exactly one cast on release" % (i + 1)).has_size(1)
		assert_str(String((_casts[0] as Array)[0])).is_equal(CardSlotController.slot_type_at_index(i))
		assert_bool(player.cast_input.is_previewing()).is_false()


func test_every_shift_swap_only_swaps_and_never_casts_or_previews() -> void:
	var player := await _ready_player()
	for i in range(Player.SWAP_ACTIONS.size()):
		var slot_type: String = CardSlotController.slot_type_at_index(i)
		assert_float(player.card_slots.get_slot(slot_type).cooldown_remaining).is_equal(0.0)
		player._unhandled_input(_event(Player.USE_ACTIONS[i], true, true))
		await _frames(3)
		assert_array(_casts).override_failure_message("Shift+key %d cast" % (i + 1)).is_empty()
		assert_bool(player.cast_input.is_previewing()).override_failure_message("Shift+key %d previewed" % (i + 1)).is_false()
		assert_float(player.card_slots.get_slot(slot_type).cooldown_remaining).override_failure_message("Shift+key %d did not swap (no penalty)" % (i + 1)).is_greater(0.0)
		player._unhandled_input(_event(Player.USE_ACTIONS[i], false, true))
		await _frames(2)
		assert_array(_casts).is_empty()


func test_recovery_label_follows_f_a_shift_combo_and_a_mouse_button_everywhere() -> void:
	var texts: Dictionary = RunConfig.ui()["option"]
	var hud: Hud = (load("res://scenes/ui/Hud.tscn") as PackedScene).instantiate()
	add_child(hud)
	auto_free(hud)
	await get_tree().process_frame
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	var shift_f := InputEventKey.new()
	shift_f.physical_keycode = KEY_F
	shift_f.shift_pressed = true
	var plain_f := InputEventKey.new()
	plain_f.physical_keycode = KEY_F
	for pair: Array in [[plain_f, "F"], [shift_f, "Shift+F"], [mouse, "MMB"]]:
		InputMap.action_erase_events(&"slot_5")
		InputMap.action_add_event(&"slot_5", pair[0])
		InputBindings.bindings_changed.emit()
		var key_text: String = pair[1]
		assert_str(hud.slot_widgets[4].key_label.text).is_equal(key_text)
		assert_str(InputLabels.slot_label("recovery")).is_equal("Recovery (%s)" % key_text)
		assert_str(RunOptionCard.slot_now_text("recovery", ["A"], String(texts["slot_now"]))).is_equal("In slot: A")
		assert_str(String(texts["slot_label"]) % [InputLabels.slot_name("recovery"), InputLabels.slot_key("recovery")]).is_equal("Recovery (%s)" % key_text)


func test_the_dodge_and_heavy_labels_follow_rebinds() -> void:
	var f := InputEventKey.new()
	f.physical_keycode = KEY_F
	InputMap.action_erase_events(&"dodge")
	InputMap.action_add_event(&"dodge", f)
	assert_str(InputLabels.for_action(&"dodge")).is_equal("F")
	var rmb_to_x := InputEventKey.new()
	rmb_to_x.physical_keycode = KEY_X
	InputMap.action_erase_events(&"attack_heavy")
	InputMap.action_add_event(&"attack_heavy", rmb_to_x)
	assert_str(InputLabels.for_action(&"attack_heavy")).is_equal("X")


func test_load_bindings_with_a_conflicting_file_reports_every_conflict_and_does_not_quit() -> void:
	var path := "user://tests/k1_bad_bindings.json"
	DirAccess.make_dir_recursive_absolute("user://tests")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"k1_a": [{"type":"key","keycode":"F9"}], "k1_b": [{"type":"key","keycode":"F9"}], "k1_c": [{"type":"key","keycode":"F9","shift":true}]}')
	f.close()
	InputBindings.load_bindings(path)
	var conflicts: Array[String] = InputBindings.last_conflicts.duplicate()
	for name_s in ["k1_a", "k1_b", "k1_c"]:
		if InputMap.has_action(name_s):
			InputMap.erase_action(name_s)
	InputBindings.load_bindings(InputBindings.BINDINGS_PATH)
	assert_array(conflicts).has_size(1)
	assert_str(conflicts[0]).contains("k1_a").contains("k1_b").contains("F9")
	assert_array(InputBindings.last_conflicts).is_empty()
