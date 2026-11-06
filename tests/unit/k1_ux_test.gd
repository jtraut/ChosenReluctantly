class_name K1UxTest
extends GdUnitTestSuite
## K1 (ux): every key the UI shows comes from InputLabels and follows a rebind; the reward / prompt panel holds
## back slot casts and swaps (it does not pause the tree).

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const SETTINGS_SCENE := "res://scenes/ui/SettingsScreen.tscn"

var _saved: Dictionary = {}


func before_test() -> void:
	RunSession.map_override = 0  # MAP1: these pin the straight run's prompts; with the map on a run opens on the map's pick, which swallows the same keys
	_saved = {}
	for action: StringName in [&"slot_5", &"slot_4", &"slot_2", &"dodge", &"attack_light", &"pause"]:
		_saved[action] = InputMap.action_get_events(action)


func after_test() -> void:
	RunSession.map_override = -1
	for action: StringName in _saved.keys():
		InputMap.action_erase_events(action)
		for event: InputEvent in _saved[action]:
			InputMap.action_add_event(action, event)


func _key(code: Key, shift: bool = false, pressed: bool = true) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.shift_pressed = shift
	e.pressed = pressed
	return e


func _rebind(action: StringName, event: InputEvent) -> void:
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)


func _hud() -> Hud:
	var hud: Hud = (load("res://scenes/ui/Hud.tscn") as PackedScene).instantiate()
	add_child(hud)
	auto_free(hud)
	return hud


# ---- HUD ----

func test_hud_slot_labels_equal_the_live_slot_keys() -> void:
	var hud := _hud()
	await get_tree().process_frame
	for i in range(hud.slot_widgets.size()):
		assert_str(hud.slot_widgets[i].key_label.text).is_equal(InputLabels.slot_key_at(i))
	assert_str(hud.light_meter.label_text).is_equal(InputLabels.for_action(&"attack_light"))
	assert_str(hud.heavy_meter.label_text).is_equal(InputLabels.for_action(&"attack_heavy"))


func test_hud_labels_follow_a_rebind_after_bindings_changed() -> void:
	var hud := _hud()
	await get_tree().process_frame
	_rebind(&"slot_5", _key(KEY_F))
	_rebind(&"slot_2", _key(KEY_Z, true))
	_rebind(&"attack_light", _key(KEY_X))
	InputBindings.bindings_changed.emit()
	assert_str(hud.slot_widgets[4].key_label.text).is_equal("F")
	assert_str(hud.slot_widgets[1].key_label.text).is_equal("Shift+Z")
	assert_str(hud.light_meter.label_text).is_equal("X")


func test_meter_and_dodge_label_columns_grow_for_a_long_key() -> void:
	var font: Font = ThemeDB.fallback_font
	assert_float(HudLayout.key_label_width(font, "LMB", 12, 38.0, 4.0)).is_greater_equal(38.0)
	var wide := HudLayout.key_label_width(font, "Shift+LMB", 12, 38.0, 4.0)
	assert_float(wide).is_greater(font.get_string_size("Shift+LMB", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x)


# ---- Option and prompt text ----

func test_option_text_shows_slot_name_and_live_key_and_follows_a_rebind() -> void:
	var texts: Dictionary = RunConfig.ui()["option"]
	var slot: String = CardSlotController.SLOT_TYPE_ORDER[4]
	assert_str(RunOptionCard.slot_now_text(slot, ["A"], String(texts["slot_now"]))).is_equal("In slot: A")
	_rebind(&"slot_5", _key(KEY_F))
	assert_str(RunOptionCard.slot_now_text(slot, ["A"], String(texts["slot_now"]))).is_equal("In slot: A")
	_rebind(&"slot_5", _key(KEY_F, true))
	assert_str(RunOptionCard.slot_now_text(slot, ["A"], String(texts["slot_now"]))).is_equal("In slot: A")


func test_no_option_template_hardcodes_a_slot_number_or_the_digit_as_the_slot_key() -> void:
	var texts: Dictionary = RunConfig.ui()["option"]
	for key: String in ["slot_now", "slot_key", "slot_label"]:
		assert_str(String(texts[key])).not_contains("%d")
		assert_str(String(texts[key])).not_contains("Slot ")
	assert_str(String(texts["remove_list_hint"])).not_contains("slot")


func test_pause_hint_names_the_live_pause_key() -> void:
	assert_str(String(UiConfig.settings_screen()["hint"])).contains("%s")
	var screen: SettingsScreen = (load(SETTINGS_SCENE) as PackedScene).instantiate()
	add_child(screen)
	auto_free(screen)
	await get_tree().process_frame
	assert_str(screen.hint_label.text).is_equal("Escape also resumes")
	_rebind(&"pause", _key(KEY_P))
	InputBindings.bindings_changed.emit()
	assert_str(screen.hint_label.text).is_equal("P also resumes")


func test_the_dodge_label_is_not_in_data() -> void:
	assert_bool(UiConfig.hud().has("dodge_label")).is_false()


# ---- The prompt holds back slot actions ----

func test_swallow_matches_slot_casts_and_swaps_and_follows_a_rebind() -> void:
	for i in range(5):
		var plain: InputEventKey = InputMap.action_get_events(Player.USE_ACTIONS[i])[0] as InputEventKey
		assert_bool(RunPromptScreen.swallows_slot_action(plain)).is_true()
		var swap: InputEventKey = InputMap.action_get_events(Player.SWAP_ACTIONS[i])[0] as InputEventKey
		assert_bool(RunPromptScreen.swallows_slot_action(swap)).is_true()
	assert_bool(RunPromptScreen.swallows_slot_action(_key(KEY_ENTER))).is_false()
	assert_bool(RunPromptScreen.swallows_slot_action(_key(KEY_G))).is_false()
	_rebind(&"slot_5", _key(KEY_G))
	assert_bool(RunPromptScreen.swallows_slot_action(_key(KEY_G))).is_true()


func _open_main() -> Main:
	RunSession.begin_new_run(42)
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await get_tree().process_frame
	await get_tree().process_frame
	return main


func _action_event(action: StringName, pressed: bool) -> InputEventKey:
	var event: InputEventKey = (InputMap.action_get_events(action)[0] as InputEventKey).duplicate() as InputEventKey
	event.pressed = pressed
	return event


## Pushes one event through the real viewport dispatch and returns how many casts the Player queued.
func _queued_after(main: Main, event: InputEvent) -> int:
	main.player._cast_queue.clear()
	main.get_viewport().push_input(event)
	return main.player._cast_queue.size()


## Taps a slot key (press, then release) and returns the casts queued; 1 for either cast trigger setting when the
## Player sees the key, 0 when something upstream ate it.
func _tap(main: Main, action: StringName) -> int:
	main.player._cast_queue.clear()
	main.player.cast_input.cancel()
	main.get_viewport().push_input(_action_event(action, true))
	main.get_viewport().push_input(_action_event(action, false))
	return main.player._cast_queue.size()


func test_an_open_prompt_keeps_slot_keys_away_from_the_player() -> void:
	var main := await _open_main()
	var prompt := main.get_node("RoomClearedScreen") as RunPromptScreen
	# Control: with no prompt open the same tap reaches the Player (the test would otherwise prove nothing).
	assert_int(_tap(main, &"slot_1")).is_equal(1)
	prompt.show_content({"title": "t", "rows": [], "button": "Continue"})
	assert_bool(prompt.visible).is_true()
	for i in range(5):
		assert_int(_tap(main, Player.USE_ACTIONS[i])).override_failure_message("slot %d tap reached the Player" % (i + 1)).is_equal(0)
	assert_int(main.player.cast_input.preview_slot).is_equal(CastInput.NONE)


func test_number_keys_no_longer_move_the_highlight_and_a_digit_slot_key_still_does_not_cast() -> void:
	var main := await _open_main()
	var prompt := main.get_node("RoomClearedScreen") as RunPromptScreen
	var ctx := RunChoices.shipped_context(["rogue", "fire", "neutral"])
	var state := RunSession.begin_new_run(3)
	state.offer = RewardOffer.generate(state.seed_value, 1, state.deck, ctx["cards"], ctx["pools"], ctx["pool_defs"], ctx["rewards"])
	state.pending = RunState.PENDING_REWARD
	var options: Array[Dictionary] = RunChoices.options(state, ctx)
	prompt.show_content({"title": "t", "rows": [], "options": options, "owned": {}})
	prompt.disarm()
	assert_bool(prompt.has_method("digit_target")).is_false()
	_rebind(&"slot_4", _key(KEY_2))
	var digit_two := _action_event(&"slot_4", true)
	digit_two.keycode = KEY_2
	var focused_before: int = prompt._option_buttons.find(prompt.get_viewport().gui_get_focus_owner())
	assert_int(_queued_after(main, digit_two)).is_equal(0)
	assert_int(prompt._option_buttons.find(prompt.get_viewport().gui_get_focus_owner())).is_equal(focused_before)
