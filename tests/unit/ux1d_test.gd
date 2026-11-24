class_name Ux1dTest
extends GdUnitTestSuite
## UX1d: the game never starts a room for the player (GDD §9). A map with one reachable node keeps that node focused and waits for a press, however long it idles.
## UX1b's single-option beat, which picked it after a second, is gone.

const SCREEN_SCENE := "res://scenes/ui/MapScreen.tscn"


func after_test() -> void:
	GamePause.reset()
	get_tree().paused = false


## A hand-made pick: `reachable_count` nodes in room 2, all reachable.
func _pick_data(reachable_count: int) -> Dictionary:
	var nodes: Array = []
	var infos: Array[Dictionary] = []
	var reachable: Array[int] = []
	for i in range(reachable_count):
		nodes.append({"id": i, "room": 2, "column": i, "type": "combat", "wave_id": ""})
		infos.append({"id": i, "room": 2, "column": i, "type": "combat", "type_name": "Combat", "wave_id": "", "chest": "", "chest_name": "", "hover": "Room",
			"gold_low": 0, "gold_high": 0, "reachable": true, "taken": false, "current": false})
		reachable.append(i)
	return {"map": {"nodes": nodes, "edges": []}, "path": [], "reachable": reachable, "nodes": infos, "gold": 0, "gold_earned": 0}


func _spawn() -> MapScreen:
	var screen: MapScreen = (load(SCREEN_SCENE) as PackedScene).instantiate()
	add_child(screen)
	auto_free(screen)
	await get_tree().process_frame
	return screen


func _idle(seconds: float) -> void:
	var end_msec: int = Time.get_ticks_msec() + roundi(seconds * 1000.0)
	while Time.get_ticks_msec() < end_msec:
		await get_tree().process_frame


func test_a_single_option_map_waits_in_pick_mode_with_no_room_started() -> void:
	var screen: MapScreen = await _spawn()
	var chosen: Array[int] = []
	screen.node_chosen.connect(func(id: int) -> void: chosen.append(id))
	screen.show_pick(_pick_data(1))
	screen.disarm()  # armed: a press would be accepted, so only the absence of a press is what keeps it waiting
	await _idle(3.0)
	assert_int(screen.mode()).is_equal(MapScreen.Mode.PICK)
	assert_bool(screen.is_open()).is_true()
	assert_bool(screen.pick_pending()).is_true()
	assert_array(chosen).is_empty()


func test_the_one_node_is_focused_so_one_enter_starts_it() -> void:
	var screen: MapScreen = await _spawn()
	var chosen: Array[int] = []
	screen.node_chosen.connect(func(id: int) -> void: chosen.append(id))
	screen.show_pick(_pick_data(1))
	screen.disarm()
	assert_int(screen.focused_node_id()).is_equal(0)
	screen._on_node_pressed(0)  # what Enter or a click on the focused node does
	assert_array(chosen).is_equal([0] as Array[int])


func test_a_key_that_is_not_enter_does_not_pick() -> void:
	var screen: MapScreen = await _spawn()
	var chosen: Array[int] = []
	screen.node_chosen.connect(func(id: int) -> void: chosen.append(id))
	screen.show_pick(_pick_data(1))
	screen.disarm()
	var event := InputEventKey.new()
	event.keycode = KEY_X
	event.physical_keycode = KEY_X
	event.pressed = true
	screen._input(event)
	assert_array(chosen).is_empty()
	assert_bool(screen.pick_pending()).is_true()


func test_the_single_option_map_uses_the_normal_line_and_hint() -> void:
	var screen: MapScreen = await _spawn()
	screen.show_pick(_pick_data(1))
	var texts: Dictionary = (screen._texts() as Dictionary)
	assert_str(screen.hint_label.text).is_equal(String(texts["pick_hint"]))
	assert_bool(texts.has("beat_line")).is_false()
	assert_bool(texts.has("beat_hint")).is_false()


func test_the_beat_is_gone_from_data_and_code() -> void:
	assert_bool(UiConfig.map_screen().has("auto_advance_seconds")).is_false()
	assert_bool(UiConfig.DEFAULT_MAP_SCREEN.has("auto_advance_seconds")).is_false()
	var src: String = FileAccess.get_file_as_string("res://src/ui/MapScreen.gd")
	assert_bool(src.contains("_start_beat") or src.contains("skip_beat") or src.contains("beat_enabled")).is_false()
