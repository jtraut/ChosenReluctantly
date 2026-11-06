class_name Map1UxTest
extends GdUnitTestSuite
## MAP1 ux: the map screen (layout at every supported size, shapes and legend for every node type, default focus and keyboard navigation,
## the arm delay, the path/current/reachable states, the view-only pause map), the run HUD gold, and the BD2 playtest carry-overs
## (relic cue, every-Nth counter, chip marks, the pause relic list, wording).

const SCREEN_SCENE := "res://scenes/ui/MapScreen.tscn"
const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const SIZES: Array[Vector2i] = [Vector2i(1024, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]

var _window_size: Vector2i = Vector2i.ZERO


func before_test() -> void:
	RunSession.clear()
	RunSession.map_override = -1
	RelicDatabase.load_all()
	_window_size = get_window().size


func after_test() -> void:
	RunSession.clear()
	RunSession.map_override = -1
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	ClassPickScreen.reset()
	Juice.reset()
	GamePause.reset()
	get_tree().paused = false
	get_window().size = _window_size


func _frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().process_frame


# --- data helpers ----------------------------------------------------------------------------------------

func _ctx() -> Dictionary:
	return {"nodes": RunNodes.shipped_context()}


## Screen data for a generated map: `steps` nodes of the first route already walked (0 = the start pick).
func _generated(seed_value: int, steps: int) -> Dictionary:
	var state := RunState.new_run(seed_value, CharacterDatabase.starting_deck("rogue"), 3)
	state.map = MapGenerator.generate(seed_value)
	var route: Array[int] = MapGraph.first_route(state.map)
	for i in range(steps):
		state.path.append(route[i])
	state.room_index = maxi(steps - 1, 0)
	state.pending = RunState.PENDING_NODE
	var extras: Dictionary = RunNodes.model_extras(state, _ctx())
	extras["gold_earned"] = 0
	return extras


## A seed whose map uses all four lanes (the tallest layout).
func _four_lane_seed() -> int:
	for candidate in range(1, 80):
		if MapLayout.dimensions(MapGenerator.generate(candidate)).y == 4:
			return candidate
	return 1


## A hand-made map: `rooms` rooms of `lanes` nodes, types cycling through every type, one chest size per relic stage. Worst case for the layout.
func _full_grid(rooms: int, lanes: int, reachable_room: int) -> Dictionary:
	var types: Array[String] = ["combat", "elite", "relic_room", "rest", "merchant", "mini_boss", "curse_room", "buff_room"]
	var chests: Array[String] = ["small", "medium", "large"]
	var nodes: Array = []
	var infos: Array[Dictionary] = []
	var edges: Array = []
	var reachable: Array[int] = []
	for room in range(1, rooms + 1):
		for lane in range(lanes):
			var id: int = (room - 1) * lanes + lane
			var type_id: String = "boss" if room == rooms else types[(room * lanes + lane) % types.size()]
			var chest: String = chests[(room + lane) % 3] if type_id == "relic_room" else ""
			var is_reach: bool = room == reachable_room
			nodes.append({"id": id, "room": room, "column": lane, "type": type_id, "wave_id": ""})
			infos.append({
				"id": id, "room": room, "column": lane, "type": type_id, "type_name": String(RunConfig.ui()["type_names"].get(type_id, type_id)),
				"wave_id": "", "chest": chest, "chest_name": chest.capitalize(), "hover": "Room %d lane %d" % [room, lane],
				"gold_low": 0, "gold_high": 0, "reachable": is_reach, "taken": false, "current": false,
			})
			if is_reach:
				reachable.append(id)
			if room < rooms:
				edges.append([id, id + lanes])
	return {"map": {"nodes": nodes, "edges": edges}, "path": [], "reachable": reachable, "nodes": infos, "gold": 0, "gold_earned": 0}


func _spawn_screen() -> MapScreen:
	var screen: MapScreen = (load(SCREEN_SCENE) as PackedScene).instantiate()
	add_child(screen)
	auto_free(screen)
	await _frames(1)
	return screen


func _resize(size: Vector2i) -> void:
	get_window().size = size
	await _frames(3)


func _key(viewport: Viewport, keycode: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = keycode
	down.physical_keycode = keycode  # a real key event has both; the slot actions are bound by physical key
	down.pressed = true
	viewport.push_input(down)
	var up := InputEventKey.new()
	up.keycode = keycode
	up.physical_keycode = keycode
	up.pressed = false
	viewport.push_input(up)


# --- shapes, names and the legend ------------------------------------------------------------------------

func test_every_node_type_has_its_own_shape_name_and_colour() -> void:
	var seen: Dictionary = {}
	var ids: Array[String] = MapConfig.NODE_TYPES.duplicate()
	ids.append("boss")
	for type_id: String in ids:
		seen[RunIcons.shape_for(type_id)] = type_id
		assert_str(String(RunConfig.ui()["type_names"].get(type_id, ""))).override_failure_message("no type name for %s" % type_id).is_not_empty()
		assert_bool(String(UiConfig.run_ui()["type_colors"].get(type_id, "")).is_valid_html_color() or type_id == "elite" or type_id == "boss").override_failure_message("no colour for %s" % type_id).is_true()
		assert_str(String(RunConfig.ui()["map"]["hover"].get(type_id, ""))).is_not_empty()
	assert_int(seen.size()).override_failure_message("two node types share a shape").is_equal(ids.size())
	for shape: String in [RunIcons.SHAPE_SQUARE, RunIcons.SHAPE_TRIANGLE, RunIcons.SHAPE_X, RunIcons.SHAPE_ARROW]:
		var pts: PackedVector2Array = RunIcons.polygon(shape, 10.0)
		assert_int(pts.size()).is_greater_equal(3)
		for p: Vector2 in pts:
			assert_float(p.length()).is_less_equal(10.0 * 1.2)


func test_the_legend_lists_exactly_the_types_on_the_map_in_a_fixed_order() -> void:
	var all: Dictionary = _full_grid(10, 4, 2)
	assert_array(MapLayout.legend_types(all["map"])).is_equal(MapLayout.TYPE_ORDER)
	var small: Dictionary = {"nodes": [{"id": 0, "room": 1, "column": 0, "type": "elite"}, {"id": 1, "room": 2, "column": 0, "type": "combat"}, {"id": 2, "room": 3, "column": 0, "type": "boss"}]}
	assert_array(MapLayout.legend_types(small)).is_equal(["combat", "elite", "boss"] as Array[String])


func test_the_legend_on_screen_has_a_shape_and_a_name_per_type_and_the_chest_key_with_a_relic_stage() -> void:
	var screen: MapScreen = await _spawn_screen()
	screen.show_pick(_full_grid(10, 4, 2))
	await _frames(2)
	assert_int(screen.legend_flow.get_child_count()).is_equal(MapLayout.TYPE_ORDER.size())
	for item: Node in screen.legend_flow.get_children():
		var type_id: String = String(item.get_meta(&"type"))
		assert_str(((item.get_child(1)) as Label).text).is_equal(String(RunConfig.ui()["type_names"][type_id]))
		assert_str((item.get_child(0) as RunTypeIcon).shape).is_equal(RunIcons.shape_for(type_id))
	assert_str(screen.legend_note.text).contains(String(RunConfig.ui()["map"]["legend_chest"]))


func test_a_relic_stage_grows_with_its_chest_and_shows_one_to_three_dots() -> void:
	var scale: Dictionary = UiConfig.map_screen()["chest_scale"]
	var radii: Array[float] = []
	for size_id: String in ["small", "medium", "large"]:
		radii.append(MapLayout.radius_for({"chest": size_id}, 20.0, scale))
	assert_float(radii[0]).is_less(radii[1])
	assert_float(radii[1]).is_less(radii[2])
	assert_float(MapLayout.radius_for({"chest": ""}, 20.0, scale)).is_equal(20.0)
	assert_int(MapLayout.pip_count("small")).is_equal(1)
	assert_int(MapLayout.pip_count("medium")).is_equal(2)
	assert_int(MapLayout.pip_count("large")).is_equal(3)
	assert_int(MapLayout.pip_count("")).is_equal(0)


# --- layout at every size --------------------------------------------------------------------------------

func test_ten_rooms_of_four_nodes_with_the_legend_and_gold_fit_without_scrolling_at_every_size() -> void:
	var screen: MapScreen = await _spawn_screen()
	for size: Vector2i in SIZES:
		await _resize(size)
		screen.show_pick(_full_grid(10, 4, 2))
		await _frames(3)
		var vp: Rect2 = Rect2(Vector2.ZERO, Vector2(get_window().size))
		assert_vector(screen.get_viewport().get_visible_rect().size).override_failure_message("the window did not take size %s" % size).is_equal(Vector2(size))
		var canvas_rect: Rect2 = screen.canvas.get_global_rect()
		assert_bool(vp.encloses(canvas_rect)).override_failure_message("canvas outside the window at %s: %s" % [size, canvas_rect]).is_true()
		var radius: float = screen.canvas.base_radius()
		assert_float(radius).override_failure_message("nodes too small at %s" % size).is_greater_equal(10.0)
		var centres: Array[Vector2] = []
		var radii: Array[float] = []
		for id: int in screen.canvas.buttons().keys():
			var button: MapNodeButton = screen.canvas.button_for(id)
			var own: float = button.radius
			var c: Vector2 = screen.canvas.centre_of(id)
			assert_bool(Rect2(Vector2.ZERO, screen.canvas.size).grow(1.0).encloses(Rect2(c - Vector2(own, own) * 1.4, Vector2(own, own) * 2.8))).override_failure_message("node %d clipped at %s" % [id, size]).is_true()
			centres.append(c)
			radii.append(own)
		for a in range(centres.size()):
			for b in range(a + 1, centres.size()):
				assert_float(centres[a].distance_to(centres[b])).override_failure_message("nodes %d and %d overlap at %s" % [a, b, size]).is_greater_equal((radii[a] + radii[b]) * 1.3)
		# Everything under the map stays on screen, in order, with nothing scrolling.
		var below: Array[Control] = [screen.hover_label, screen.legend_flow, screen.legend_note, screen.hint_label]
		var previous_end: float = canvas_rect.end.y - 1.0
		for label: Control in below:
			var rect: Rect2 = label.get_global_rect()
			assert_float(rect.end.y).override_failure_message("%s runs off the bottom at %s" % [label.name, size]).is_less_equal(vp.size.y + 0.5)
			assert_float(rect.position.y).override_failure_message("%s overlaps the map at %s" % [label.name, size]).is_greater_equal(previous_end)
			previous_end = rect.position.y
		assert_bool(vp.encloses(screen.gold_badge.get_global_rect())).is_true()
		assert_bool(vp.encloses(screen.title_label.get_global_rect())).is_true()
		for label: Label in [screen.title_label, screen.hover_label, screen.hint_label, screen.legend_note]:
			assert_int(label.get_theme_font_size("font_size")).override_failure_message("%s under 12 px at %s" % [label.name, size]).is_greater_equal(12)
		var no_scroll: bool = true
		for node: Node in screen.find_children("*", "ScrollContainer", true, false):
			no_scroll = false
		assert_bool(no_scroll).is_true()
		await _resize(size)
	await _resize(_window_size)


func test_a_real_generated_map_fits_at_1024_by_600_too() -> void:
	var screen: MapScreen = await _spawn_screen()
	await _resize(Vector2i(1024, 600))
	screen.show_pick(_generated(_four_lane_seed(), 0))
	await _frames(3)
	var vp: Rect2 = Rect2(Vector2.ZERO, Vector2(get_window().size))
	assert_bool(vp.encloses(screen.canvas.get_global_rect())).is_true()
	assert_float(screen.hint_label.get_global_rect().end.y).is_less_equal(vp.size.y + 0.5)


# --- states ----------------------------------------------------------------------------------------------

func test_the_taken_path_the_current_node_and_the_reachable_nodes_each_get_their_own_state() -> void:
	var screen: MapScreen = await _spawn_screen()
	var data: Dictionary = _generated(_four_lane_seed(), 3)
	screen.show_pick(data)
	await _frames(2)
	var path: Array = data["path"]
	for id: int in screen.canvas.buttons().keys():
		var button: MapNodeButton = screen.canvas.button_for(id)
		var expected: String = MapLayout.STATE_FUTURE
		if id == int(path[path.size() - 1]):
			expected = MapLayout.STATE_CURRENT
		elif path.has(id):
			expected = MapLayout.STATE_TAKEN
		elif (data["reachable"] as Array).has(id):
			expected = MapLayout.STATE_REACHABLE
		assert_str(button.state()).override_failure_message("node %d" % id).is_equal(expected)
	assert_int((data["reachable"] as Array).size()).is_greater(0)
	# Only the reachable nodes can take focus when picking.
	for id: int in screen.canvas.buttons().keys():
		var focusable: bool = screen.canvas.button_for(id).focus_mode == Control.FOCUS_ALL
		assert_bool(focusable).is_equal((data["reachable"] as Array).has(id))


func test_the_lines_on_the_taken_path_are_told_apart_from_the_reachable_ones() -> void:
	var screen: MapScreen = await _spawn_screen()
	var data: Dictionary = _generated(_four_lane_seed(), 3)
	screen.show_pick(data)
	await _frames(2)
	var path: Array = data["path"]
	assert_int(screen.canvas._edge_kind(int(path[0]), int(path[1]), path, int(path[2]))).is_equal(2)
	var reachable: Array = data["reachable"]
	assert_int(screen.canvas._edge_kind(int(path[2]), int(reachable[0]), path, int(path[2]))).is_equal(1)
	var other_edge: Array = []
	for edge: Variant in (data["map"]["edges"] as Array):
		if not path.has(int((edge as Array)[0])):
			other_edge = edge
			break
	assert_int(screen.canvas._edge_kind(int(other_edge[0]), int(other_edge[1]), path, int(path[2]))).is_equal(0)


func test_hover_text_comes_from_data_and_notes_where_you_are() -> void:
	var screen: MapScreen = await _spawn_screen()
	var data: Dictionary = _generated(_four_lane_seed(), 3)
	screen.show_pick(data)
	await _frames(2)
	var reach_id: int = int((data["reachable"] as Array)[0])
	var info: Dictionary = screen._info_of(reach_id)
	assert_str(screen.hover_text(reach_id)).is_equal(String(RunConfig.ui()["map"]["room_format"]) % [int(info["room"]), String(info["hover"])])
	var here: int = int((data["path"] as Array)[2])
	assert_str(screen.hover_text(here)).contains(String(RunConfig.ui()["map"]["current_note"]))
	assert_str(screen.hover_text(int((data["path"] as Array)[0]))).contains(String(RunConfig.ui()["map"]["taken_note"]))
	assert_str(screen.hover_text(-1)).is_empty()
	screen.canvas.node_hovered.emit(reach_id)
	assert_str(screen.hover_label.text).is_equal(screen.hover_text(reach_id))


# --- keyboard, focus and the arm delay -------------------------------------------------------------------

func test_the_default_focus_is_the_least_surprising_reachable_node() -> void:
	var order: Array = UiConfig.map_screen()["default_focus_order"]
	var infos: Array[Dictionary] = [
		{"id": 10, "room": 2, "column": 0, "type": "elite", "reachable": true},
		{"id": 11, "room": 2, "column": 1, "type": "combat", "reachable": true},
		{"id": 12, "room": 2, "column": 2, "type": "rest", "reachable": true},
		{"id": 13, "room": 2, "column": 3, "type": "combat", "reachable": false},
	]
	assert_int(MapLayout.default_focus(infos, order)).is_equal(11)  # a plain fight beats the elite above it
	infos.remove_at(1)
	assert_int(MapLayout.default_focus(infos, order)).is_equal(12)  # then rest
	infos.remove_at(1)
	assert_int(MapLayout.default_focus(infos, order)).is_equal(10)
	assert_int(MapLayout.default_focus([], order)).is_equal(-1)
	var twin: Array[Dictionary] = [{"id": 5, "room": 2, "column": 2, "type": "combat", "reachable": true}, {"id": 4, "room": 2, "column": 0, "type": "combat", "reachable": true}]
	assert_int(MapLayout.default_focus(twin, order)).is_equal(4)  # a tie goes to the lowest lane


func test_the_map_opens_with_that_node_focused_and_its_text_already_showing() -> void:
	var screen: MapScreen = await _spawn_screen()
	var data: Dictionary = _generated(_four_lane_seed(), 0)
	screen.show_pick(data)
	await _frames(2)
	var expected: int = MapLayout.default_focus(screen._info_list(), UiConfig.map_screen()["default_focus_order"])
	assert_int(screen.focused_node_id()).is_equal(expected)
	assert_str(screen.hover_label.text).is_equal(screen.hover_text(expected))
	assert_str(screen.hover_label.text).is_not_empty()


func test_arrow_keys_cycle_the_reachable_nodes_and_never_land_on_a_dimmed_one() -> void:
	var screen: MapScreen = await _spawn_screen()
	var data: Dictionary = _full_grid(10, 4, 3)
	screen.show_pick(data)
	await _frames(2)
	var reachable: Array = data["reachable"]
	var seen: Dictionary = {}
	var viewport: Viewport = screen.get_viewport()
	for step in range(10):
		seen[screen.focused_node_id()] = true
		_key(viewport, KEY_DOWN)
		await _frames(1)
		assert_bool(reachable.has(screen.focused_node_id())).override_failure_message("focus went to a node you cannot pick").is_true()
	assert_int(seen.size()).is_equal(reachable.size())  # Down visits every reachable node
	var before: int = screen.focused_node_id()
	_key(viewport, KEY_RIGHT)
	await _frames(1)
	assert_int(screen.focused_node_id()).is_not_equal(before)  # Left and Right move too (one room column: they act like Up and Down)
	assert_bool(reachable.has(screen.focused_node_id())).is_true()


func test_a_reflexive_enter_inside_the_arm_delay_picks_nothing_and_a_deliberate_one_does() -> void:
	var screen: MapScreen = await _spawn_screen()
	var picked: Array[int] = []
	screen.node_chosen.connect(func(id: int) -> void: picked.append(id))
	var data: Dictionary = _generated(_four_lane_seed(), 0)
	screen.show_pick(data)
	await _frames(2)
	assert_bool(screen.is_armed()).is_false()
	_key(screen.get_viewport(), KEY_ENTER)
	await _frames(2)
	assert_array(picked).is_empty()
	screen.disarm()
	var default_id: int = screen.focused_node_id()
	_key(screen.get_viewport(), KEY_ENTER)
	await _frames(2)
	assert_array(picked).is_equal([default_id] as Array[int])


class _KeyProbe extends Node:
	var seen: Array[int] = []

	func _unhandled_input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key != null and key.pressed:
			seen.append(key.keycode)


func test_space_and_the_slot_keys_never_reach_the_fight_behind_the_pick_and_space_never_picks() -> void:
	var screen: MapScreen = await _spawn_screen()
	var probe := _KeyProbe.new()
	add_child(probe)
	auto_free(probe)
	var picked: Array[int] = []
	screen.node_chosen.connect(func(id: int) -> void: picked.append(id))
	_key(screen.get_viewport(), KEY_SPACE)
	assert_array(probe.seen).is_equal([KEY_SPACE] as Array[int])  # with the map closed the probe does hear Space: the probe works
	probe.seen.clear()
	screen.show_pick(_generated(_four_lane_seed(), 0))
	await _frames(2)
	screen.disarm()
	for key: Key in [KEY_SPACE, KEY_Q, KEY_E, KEY_F, KEY_R]:
		_key(screen.get_viewport(), key)
	await _frames(2)
	assert_array(probe.seen).override_failure_message("a fight key got past the open map: %s" % [probe.seen]).is_empty()
	assert_array(picked).override_failure_message("Space or a slot key picked a room").is_empty()
	_key(screen.get_viewport(), KEY_ENTER)  # Enter does
	await _frames(2)
	assert_int(picked.size()).is_equal(1)


func test_a_click_on_a_node_you_cannot_pick_does_nothing() -> void:
	var screen: MapScreen = await _spawn_screen()
	var picked: Array[int] = []
	screen.node_chosen.connect(func(id: int) -> void: picked.append(id))
	var data: Dictionary = _generated(_four_lane_seed(), 3)
	screen.show_pick(data)
	screen.disarm()
	await _frames(2)
	var path: Array = data["path"]
	screen.canvas.button_for(int(path[0])).pressed.emit()  # a node already walked
	var far: int = -1
	for info: Dictionary in screen._info_list():
		if int(info["room"]) > int(screen._info_of(int(path[2]))["room"]) + 1:
			far = int(info["id"])
			break
	screen.canvas.button_for(far).pressed.emit()  # a node two rooms ahead
	assert_array(picked).is_empty()
	var reach: int = int((data["reachable"] as Array)[0])
	screen.canvas.button_for(reach).pressed.emit()
	assert_array(picked).is_equal([reach] as Array[int])


func test_escape_does_nothing_to_the_pick_screen_so_the_pause_screen_can_have_it() -> void:
	var screen: MapScreen = await _spawn_screen()
	screen.show_pick(_generated(_four_lane_seed(), 0))
	await _frames(2)
	TestInput.tap(&"pause")
	await _frames(1)
	assert_bool(screen.is_open()).is_true()
	assert_int(screen.mode()).is_equal(MapScreen.Mode.PICK)


func test_a_pick_that_arrives_while_paused_is_held_until_resume() -> void:
	var screen: MapScreen = await _spawn_screen()
	assert_bool(GamePause.pause()).is_true()
	screen.show_pick(_generated(_four_lane_seed(), 0))
	await _frames(2)
	assert_bool(screen.is_open()).is_false()
	assert_bool(screen.pick_pending()).is_true()
	GamePause.resume()
	await _frames(2)
	assert_bool(screen.is_open()).is_true()
	assert_int(screen.mode()).is_equal(MapScreen.Mode.PICK)
	assert_bool(screen.focused_node_id() >= 0).is_true()
	assert_bool(screen.is_armed()).is_false()  # a fresh arm delay after the resume, too


func test_a_pause_while_picking_hides_the_pick_and_the_resume_brings_it_back_with_its_focus() -> void:
	var screen: MapScreen = await _spawn_screen()
	screen.show_pick(_generated(_four_lane_seed(), 0))
	await _frames(2)
	assert_bool(GamePause.pause()).is_true()
	assert_bool(screen.is_open()).is_false()
	GamePause.resume()
	await _frames(2)
	assert_bool(screen.is_open()).is_true()
	assert_int(screen.focused_node_id()).is_equal(screen.default_focus_id())


# --- the view-only map -----------------------------------------------------------------------------------

func test_the_view_only_map_lets_every_node_take_focus_and_picks_nothing() -> void:
	var screen: MapScreen = await _spawn_screen()
	var picked: Array[int] = []
	screen.node_chosen.connect(func(id: int) -> void: picked.append(id))
	var data: Dictionary = _generated(_four_lane_seed(), 3)
	assert_bool(screen.open_view_with(data)).is_true()
	await _frames(2)
	assert_bool(screen.is_view_only()).is_true()
	for id: int in screen.canvas.buttons().keys():
		assert_int(screen.canvas.button_for(id).focus_mode).is_equal(Control.FOCUS_ALL)
	assert_bool(screen.back_button.visible).is_true()
	assert_bool(screen.back_button.has_focus()).is_true()  # Enter closes, it does not go anywhere
	assert_str(screen.title_label.text).is_equal(String(RunConfig.ui()["map"]["view_title"]))
	screen.canvas.button_for(int((data["reachable"] as Array)[0])).pressed.emit()
	assert_array(picked).is_empty()
	assert_int(screen.layer).is_greater(20)  # above the pause screen (layer 20)


func test_the_view_only_map_closes_on_escape_enter_and_back_and_arrows_walk_between_rooms() -> void:
	var screen: MapScreen = await _spawn_screen()
	var data: Dictionary = _generated(_four_lane_seed(), 3)
	var closed: Array[int] = [0]
	screen.view_closed.connect(func() -> void: closed[0] += 1)
	screen.open_view_with(data)
	await _frames(2)
	TestInput.tap(&"pause")
	await _frames(1)
	assert_bool(screen.is_open()).is_false()
	assert_int(closed[0]).is_equal(1)
	screen.open_view_with(data)
	await _frames(2)
	_key(screen.get_viewport(), KEY_ENTER)  # Back has the focus
	await _frames(2)
	assert_bool(screen.is_open()).is_false()
	assert_int(closed[0]).is_equal(2)
	screen.open_view_with(data)
	await _frames(2)
	var path: Array = data["path"]
	screen.canvas.button_for(int(path[1])).grab_focus()
	var room_before: int = int(screen._info_of(int(path[1]))["room"])
	_key(screen.get_viewport(), KEY_RIGHT)
	await _frames(1)
	assert_int(int(screen._info_of(screen.focused_node_id())["room"])).is_equal(room_before + 1)
	_key(screen.get_viewport(), KEY_LEFT)
	_key(screen.get_viewport(), KEY_LEFT)
	await _frames(1)
	assert_int(int(screen._info_of(screen.focused_node_id())["room"])).is_equal(room_before - 1)
	screen.back_button.pressed.emit()
	assert_bool(screen.is_open()).is_false()


func test_neighbours_link_every_focusable_node_and_stay_inside_the_set() -> void:
	var data: Dictionary = _full_grid(10, 4, 0)
	var infos: Array[Dictionary] = []
	var ids: Array[int] = []
	for info: Variant in (data["nodes"] as Array):
		infos.append(info)
		ids.append(int((info as Dictionary)["id"]))
	var links: Dictionary = MapLayout.neighbors(infos, ids)
	assert_int(links.size()).is_equal(ids.size())
	for id: int in links.keys():
		for direction: String in ["up", "down", "left", "right"]:
			var target: int = int((links[id] as Dictionary)[direction])
			assert_bool(target == -1 or ids.has(target)).is_true()
	# Room 1 has nothing to its left, the last room nothing to its right, lane 0 nothing above.
	assert_int(int((links[0] as Dictionary)["left"])).is_equal(-1)
	assert_int(int((links[0] as Dictionary)["up"])).is_equal(-1)
	assert_int(int((links[0] as Dictionary)["right"])).is_equal(4)
	assert_int(int((links[0] as Dictionary)["down"])).is_equal(1)
	# A subset: the nearest focusable room on that side, the nearest lane in it.
	var some: Array[int] = [0, 13, 37]  # rooms 1, 4 (lane 1) and 10 (lane 1)
	var sparse: Dictionary = MapLayout.neighbors(infos, some)
	assert_int(int((sparse[0] as Dictionary)["right"])).is_equal(13)
	assert_int(int((sparse[13] as Dictionary)["right"])).is_equal(37)
	assert_int(int((sparse[13] as Dictionary)["left"])).is_equal(0)


# --- the pause screen's Map button -----------------------------------------------------------------------

func test_the_pause_screen_has_a_map_button_only_in_a_map_run_and_it_opens_the_view_and_returns() -> void:
	RunSession.map_override = 1
	RunSession.begin_new_run(30)
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames(4)
	var settings: SettingsScreen = main.get_node("SettingsScreen")
	var map_screen: MapScreen = main.get_node("MapScreen")
	assert_bool(map_screen.is_open()).is_true()  # the run opens on its pick of a room-1 node
	assert_bool(settings.open()).is_true()
	await _frames(2)
	assert_bool(map_screen.is_open()).is_false()  # the pause screen gets the screen; the pick waits
	assert_bool(map_screen.pick_pending()).is_true()
	assert_bool(settings.map_button.visible).is_true()
	assert_bool(settings.open_map()).is_true()
	await _frames(2)
	assert_bool(map_screen.is_view_only()).is_true()
	TestInput.tap(&"pause")  # Esc closes the map and not the pause screen
	await _frames(2)
	assert_bool(map_screen.is_open()).is_false()
	assert_bool(settings.is_open()).is_true()
	assert_bool(settings.map_button.has_focus()).is_true()
	settings.close()
	await _frames(2)
	assert_bool(map_screen.is_open()).is_true()  # the pick comes back after the pause
	assert_int(map_screen.mode()).is_equal(MapScreen.Mode.PICK)


func test_a_straight_run_and_the_arena_show_no_map_button() -> void:
	RunSession.map_override = 0
	RunSession.begin_new_run(3)
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames(3)
	var settings: SettingsScreen = main.get_node("SettingsScreen")
	settings.open()
	await _frames(1)
	assert_bool(settings.map_button.visible).is_false()
	settings.close()


# --- gold ------------------------------------------------------------------------------------------------

func test_the_gold_float_rises_and_fades_and_is_gone_at_the_end() -> void:
	var start: Dictionary = GoldBadge.float_state(1.6, 1.6, 26.0)
	assert_float(float(start["offset"])).is_equal(0.0)
	assert_float(float(start["alpha"])).is_equal(1.0)
	var end: Dictionary = GoldBadge.float_state(0.1, 1.6, 26.0)
	assert_float(float(end["offset"])).is_greater(20.0)
	assert_float(float(end["alpha"])).is_less(0.3)
	assert_float(float(GoldBadge.float_state(0.0, 1.6, 26.0)["alpha"])).is_equal(0.0)


func test_the_run_hud_shows_gold_in_a_map_run_with_a_plus_n_and_hides_it_in_a_straight_run() -> void:
	RunSession.map_override = 1
	RunSession.begin_new_run(30)
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames(4)
	var hud: RunHud = main.get_node("RunHud")
	assert_bool(hud.gold_badge.visible).is_true()
	assert_int(hud.gold_badge.total()).is_equal(0)
	main.run_controller.gold_changed.emit(30, 12)
	assert_int(hud.gold_badge.total()).is_equal(30)
	assert_str(hud.gold_badge.delta_text()).is_equal("+12")
	assert_str(hud.gold_badge.total_text()).is_equal(String(RunConfig.ui()["map"]["gold_format"]) % 30)
	assert_int(hud.gold_layer.layer).is_greater(9)  # above the reward panels, so "+N" is not dimmed by the screen it lands behind
	for size: Vector2i in SIZES:
		await _resize(size)
		var vp: Rect2 = Rect2(Vector2.ZERO, Vector2(get_window().size))
		var rect: Rect2 = hud.gold_badge.get_global_rect()
		assert_bool(vp.encloses(rect)).override_failure_message("gold off screen at %s" % size).is_true()
		assert_bool(rect.intersects(hud.panel.get_global_rect())).override_failure_message("gold overlaps the room indicator at %s" % size).is_false()
		var slots: Rect2 = HudLayout.slot_bar_rect(vp.size, UiConfig.hud(), 5)
		assert_bool(rect.intersects(slots)).is_false()
	main.queue_free()
	await _frames(2)
	RunSession.clear()
	RunSession.map_override = 0
	RunSession.begin_new_run(3)
	var straight: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(straight)
	auto_free(straight)
	await _frames(3)
	assert_bool((straight.get_node("RunHud") as RunHud).gold_badge.visible).is_false()


func test_the_gold_badge_steps_aside_for_the_class_pick_and_game_over() -> void:
	RunSession.map_override = 1
	RunSession.begin_new_run(30)
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames(4)
	var hud: RunHud = main.get_node("RunHud")
	var class_pick: CanvasLayer = main.get_node("ClassPickScreen")
	var game_over: CanvasLayer = main.get_node("GameOverScreen")
	class_pick.visible = false
	game_over.visible = false
	await _frames(2)
	assert_bool(hud.gold_layer.visible).is_true()
	class_pick.visible = true
	await _frames(2)
	assert_bool(hud.gold_layer.visible).is_false()
	class_pick.visible = false
	game_over.visible = true
	await _frames(2)
	assert_bool(hud.gold_layer.visible).is_false()
	game_over.visible = false
	await _frames(2)
	assert_bool(hud.gold_layer.visible).is_true()


func test_the_condition_tag_above_the_slots_stays_clear_of_the_boss_bar_at_every_size() -> void:
	var cfg: Dictionary = UiConfig.hud()
	for size: Vector2 in [Vector2(1024, 600), Vector2(1280, 720), Vector2(1920, 1080)]:
		var s: float = HudLayout.ui_scale(size, cfg)
		var tag_top: float = HudLayout.slot_bar_rect(size, cfg, 5).position.y - (float(cfg["condition_font_size"]) + 12.0) * s - 3.0 * s
		assert_float(tag_top).override_failure_message("the condition tag would touch the boss bar at %s" % size).is_greater(HudLayout.boss_bar_rect(size, cfg).end.y)
		assert_float(tag_top).is_greater(HudLayout.room_indicator_rect(size, cfg).end.y)


func test_the_map_screen_shows_the_gold_total_and_what_the_last_fight_paid() -> void:
	var screen: MapScreen = await _spawn_screen()
	var data: Dictionary = _generated(_four_lane_seed(), 2)
	data["gold"] = 44
	data["gold_earned"] = 16
	screen.show_pick(data)
	await _frames(2)
	assert_int(screen.gold_badge.total()).is_equal(44)
	assert_str(screen.gold_badge.total_text()).is_equal("44 gold")
	assert_str(screen.earned_label.text).is_equal("+16 gold")
	data["gold_earned"] = 0
	screen.disarm()
	screen.close_view()
	screen.show_pick(data)
	await _frames(2)
	assert_bool(screen.earned_label.visible).is_false()


# --- carry-overs: relic marks, counter, cue --------------------------------------------------------------

func test_relic_chip_marks_never_repeat_inside_a_set() -> void:
	var names: Array[String] = ["Pyre Insurance", "Spite Knuckles", "Heavy Sigh", "Pyre Ice", "Smoldering Grudge", "Second Wind (Unwillingly)", "Lingering Embers"]
	var marks: Array[String] = RelicFlash.unique_marks(names)
	assert_int(marks.size()).is_equal(names.size())
	var seen: Dictionary = {}
	for mark: String in marks:
		seen[mark] = true
	assert_int(seen.size()).override_failure_message("marks repeat: %s" % [marks]).is_equal(names.size())
	assert_str(marks[1]).is_equal("SK")  # a name nobody clashes with keeps its initials
	assert_array(RelicFlash.unique_marks(["Heavy Sigh", "Spite Knuckles"] as Array[String])).is_equal(["HS", "SK"] as Array[String])
	var shipped: Array[String] = []
	for relic_id: String in RelicDatabase.ids():
		shipped.append(String(RelicDatabase.get_relic(relic_id)["name"]))
	var all_marks: Dictionary = {}
	for mark: String in RelicFlash.unique_marks(shipped):
		all_marks[mark] = true
	assert_int(all_marks.size()).is_equal(shipped.size())


func test_the_hud_chips_are_big_enough_to_read_at_1024_by_600() -> void:
	var cfg: Dictionary = UiConfig.hud()
	var s: float = 600.0 / 720.0
	assert_float(float(cfg["relic_chip_size"]) * s).is_greater_equal(24.0)
	assert_int(maxi(roundi(float(cfg["relic_font_size"]) * s), int(cfg["relic_min_font_size"]))).is_greater_equal(12)


func test_the_every_nth_counter_reads_the_n_from_data_and_the_progress_from_the_manager() -> void:
	assert_int(RelicProgress.nth_of("spite_knuckles")).is_equal(4)
	assert_int(RelicProgress.nth_of("pyre_insurance")).is_equal(0)
	assert_int(RelicProgress.nth_of("no_such_relic")).is_equal(0)
	assert_str(RelicProgress.text(0, 4)).is_equal("0/4")
	assert_str(RelicProgress.text(3, 4)).is_equal("3/4")
	assert_str(RelicProgress.text(4, 4)).is_equal("0/4")  # it fired on the 4th
	assert_str(RelicProgress.text(6, 4)).is_equal("2/4")
	assert_str(RelicProgress.text(RelicProgress.NO_PROGRESS, 4)).is_empty()
	assert_str(RelicProgress.text(2, 0)).is_empty()
	var asked: _AskedManager = _AskedManager.new()
	auto_free(asked)
	assert_int(RelicProgress.matches_of(asked, "spite_knuckles")).is_equal(3)
	var legacy: _LegacyManager = _LegacyManager.new()
	auto_free(legacy)
	assert_int(RelicProgress.matches_of(legacy, "spite_knuckles")).is_equal(6)
	assert_int(RelicProgress.matches_of(legacy, "pyre_insurance")).is_equal(RelicProgress.NO_PROGRESS)
	assert_int(RelicProgress.matches_of(null, "spite_knuckles")).is_equal(RelicProgress.NO_PROGRESS)
	# The fallback reads a private field of the real manager; if gameplay renames it, this fails and the counter is then hidden, not wrong.
	var real := RelicManager.new()
	auto_free(real)
	assert_bool(real.get("_triggers") is Array).override_failure_message("RelicManager._triggers is gone: ask for trigger_progress(relic_id)").is_true()


class _AskedManager extends Node:
	func trigger_progress(_relic_id: String) -> int:
		return 3


class _LegacyManager extends Node:
	var _triggers: Array = [{"relic_id": "spite_knuckles", "filter": {"every_nth": 4}, "matches": 6}]


func test_the_chip_of_an_every_nth_relic_shows_its_counter_and_others_do_not() -> void:
	var row := RelicRow.new()
	add_child(row)
	auto_free(row)
	row.configure(UiConfig.hud(), 1.0)
	row.size = Vector2(220.0, 60.0)
	row.set_relics(["spite_knuckles", "pyre_insurance"] as Array[String])
	var manager: _AskedManager = _AskedManager.new()
	auto_free(manager)
	row._manager = null
	row._progress["spite_knuckles"] = 3
	assert_str(row.counter_text("spite_knuckles")).is_equal("3/4")
	assert_str(row.counter_text("pyre_insurance")).is_empty()
	assert_str(row.counter_text("nobody")).is_empty()


func test_cues_merge_one_relic_firing_again_cap_the_count_and_expire() -> void:
	var cues: Array[Dictionary] = []
	var color := Color.WHITE
	RelicCues.add(cues, "pyre_insurance", "Pyre Insurance", Vector3.ZERO, color, 0.6, 2.5, 6)
	RelicCues.add(cues, "pyre_insurance", "Pyre Insurance", Vector3(1, 0, 0), color, 0.6, 2.5, 6)  # same relic, near, soon: merged
	assert_int(cues.size()).is_equal(1)
	assert_str(RelicCues.label(cues[0])).is_equal("Pyre Insurance x2")
	RelicCues.add(cues, "pyre_insurance", "Pyre Insurance", Vector3(9, 0, 0), color, 0.6, 2.5, 6)  # far away: its own cue
	assert_int(cues.size()).is_equal(2)
	RelicCues.add(cues, "heavy_sigh", "Heavy Sigh", Vector3.ZERO, color, 0.6, 2.5, 6)  # another relic
	assert_int(cues.size()).is_equal(3)
	for i in range(10):
		RelicCues.add(cues, "r%d" % i, "R%d" % i, Vector3.ZERO, color, 0.6, 2.5, 6)
	assert_int(cues.size()).is_equal(6)  # capped, oldest dropped
	cues = RelicCues.step(cues, 0.5, 1.5)
	assert_int(cues.size()).is_equal(6)
	cues = RelicCues.step(cues, 1.1, 1.5)
	assert_int(cues.size()).is_equal(0)
	var late: Array[Dictionary] = []
	RelicCues.add(late, "a", "A", Vector3.ZERO, color, 0.6, 2.5, 6)
	late = RelicCues.step(late, 0.7, 1.5)
	RelicCues.add(late, "a", "A", Vector3.ZERO, color, 0.6, 2.5, 6)  # after the merge window: a new cue
	assert_int(late.size()).is_equal(2)


func test_cue_labels_that_would_overlap_are_stacked_upwards_and_the_first_keeps_its_place() -> void:
	var rects: Array[Rect2] = [Rect2(100, 100, 120, 24), Rect2(110, 104, 120, 24), Rect2(105, 98, 120, 24), Rect2(400, 100, 120, 24)]
	var placed: Array[Rect2] = RelicCues.stack(rects, 4.0)
	assert_object(placed[0]).is_equal(rects[0])
	assert_object(placed[3]).is_equal(rects[3])
	for a in range(placed.size()):
		for b in range(a + 1, placed.size()):
			assert_bool(placed[a].intersects(placed[b])).override_failure_message("labels %d and %d overlap" % [a, b]).is_false()


func test_the_cue_fades_out_and_its_ring_is_quick() -> void:
	assert_float(RelicCues.label_alpha(0.0, 1.5, 0.4)).is_equal(1.0)
	assert_float(RelicCues.label_alpha(1.4, 1.5, 0.4)).is_less(0.5)
	assert_float(RelicCues.label_alpha(1.5, 1.5, 0.4)).is_equal(0.0)
	assert_float(float(RelicCues.ring_state(0.0, 0.45)["alpha"])).is_equal(1.0)
	assert_float(float(RelicCues.ring_state(0.45, 0.45)["alpha"])).is_equal(0.0)
	assert_float(float(RelicCues.ring_state(0.2, 0.45)["radius"])).is_between(0.0, 1.0)


func test_a_relic_trigger_in_a_run_puts_a_cue_at_the_spot_of_its_last_effect() -> void:
	RunSession.begin_new_run(3)
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames(3)
	main.run_controller.relics_changed.emit(["pyre_insurance"] as Array[String])
	var cues: RelicCueLayer = main.hud.relic_cues
	assert_object(cues).is_not_null()
	# An effect owned by the relic lands at a point; the trigger that follows is drawn there.
	var spot := Vector3(3.0, 0.0, -2.0)
	CombatEvents.hit_landed.emit(null, 4.0, "fire", &"damage", "relic:pyre_insurance", spot)
	main.run_controller.relic_triggered.emit("pyre_insurance", 0, "status_ended")
	assert_int(cues.cues().size()).is_equal(1)
	assert_object((cues.cues()[0]["world"] as Vector3)).is_equal(spot)
	assert_str(RelicCues.label(cues.cues()[0])).is_equal("Pyre Insurance")
	# With no effect to point at, the player's position is used.
	cues.cues().clear()
	cues._spots.clear()
	main.run_controller.relic_triggered.emit("pyre_insurance", 0, "status_ended")
	assert_object((cues.cues()[0]["world"] as Vector3)).is_equal(main.player.global_position)


# --- carry-overs: wording and the pause list -------------------------------------------------------------

func test_the_relic_skip_says_what_free_means_and_the_slot_condition_names_the_key() -> void:
	var texts: Dictionary = RunConfig.ui()
	assert_str(String(texts["relic"]["skip_detail"])).contains("card rejects")
	var cond: Dictionary = texts["slot_condition"]
	assert_str(ConditionCue.short_text(CardDatabase.get_card("rogue_drive_by"), cond)).is_equal("After Move (%s)" % InputLabels.slot_key("movement"))
	var no_key: Dictionary = cond.duplicate()
	no_key.erase("cast_within_slot_key")
	assert_str(ConditionCue.short_text(CardDatabase.get_card("rogue_drive_by"), no_key)).is_equal("After Move")
	assert_int(int(UiConfig.hud()["condition_min_font_px"])).is_greater_equal(12)


func test_three_relics_all_show_in_the_pause_list_on_a_solid_plate_at_1024_by_600() -> void:
	RelicDatabase.load_all()
	var state := RunSession.begin_new_run(3)
	state.relics = ["pyre_insurance", "spite_knuckles", "heavy_sigh"] as Array[String]
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _resize(Vector2i(1024, 600))
	var screen: SettingsScreen = main.get_node("SettingsScreen")
	screen.open()
	await _frames(3)
	var scroll: ScrollContainer = screen.relic_scroll
	assert_float(scroll.custom_minimum_size.y).override_failure_message("the list is shorter than its three relics").is_greater_equal(screen.relic_list.get_combined_minimum_size().y - 0.5)
	assert_float(screen.relic_list.get_combined_minimum_size().y).is_greater(0.0)
	var vp: Vector2 = screen.get_viewport().get_visible_rect().size
	var slots: Rect2 = HudLayout.slot_bar_rect(vp, UiConfig.hud(), 5)
	assert_float(screen.plate.get_global_rect().end.y).override_failure_message("the plate runs onto the slots").is_less_equal(slots.position.y + 0.5)
	assert_float(screen.plate.get_global_rect().position.y).is_greater_equal(0.0)
	# The plate is opaque, so the room never shows through it; the Map button sits beside Resume.
	var plate_style: StyleBoxFlat = screen.plate.get_theme_stylebox("panel") as StyleBoxFlat
	assert_float(plate_style.bg_color.a).is_equal(1.0)
	assert_bool(screen.resume_button.get_global_rect().end.y <= slots.position.y + 0.5).is_true()
	assert_bool(screen.map_button.get_parent() == screen.resume_button.get_parent()).is_true()
	screen.close()
	await _resize(_window_size)
