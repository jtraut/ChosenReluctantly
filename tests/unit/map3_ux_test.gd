class_name Map3UxTest
extends GdUnitTestSuite
## MAP3 ux: "Act N" and "Room N of 30" (ActText, the HUD plate, the map, the reward subtitle), the act transition screen (ActScreen) and its hold on the
## map pick, Continue on the class pick screen (RunSave.summary), the mini-boss node text, and the MAP2 polish fold-ins (merchant coin, shop slack).

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const MAP_SCREEN_PATH := "res://scenes/ui/MapScreen.tscn"
const PATH := "user://tests/map3_ux_run_save.json"
const RESOLUTIONS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440), Vector2(1024, 600)]


## Records the key presses nobody handled: what would have reached the fight behind a screen.
class KeySpy extends Node:
	var presses: int = 0

	func _unhandled_input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key != null and key.pressed:
			presses += 1


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	RunSave.reset()
	RunSave.path = PATH
	RunSave.persist_override = true
	RunSave.delete_save()
	RunSession.clear()
	RunSession.map_override = -1
	RunSession.acts_override = 0
	RelicDatabase.load_all()


func after_test() -> void:
	for child in get_children():
		if child is Main:
			child.queue_free()  # the fresh scenes a Continue or a new run builds are not auto_free'd: they must not outlive the test
	RunSave.delete_save()
	RunSave.reset()
	RunSession.clear()
	RunSession.map_override = -1
	RunSession.acts_override = 0
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	ClassPickScreen.reset()
	CharacterPick.reset()
	RunSession.selected_character = ""  # Continue remembers the loaded run's class: later suites must start as the default
	Juice.reset()
	GamePause.reset()
	get_tree().paused = false  # the class pick pauses the tree; its scene is freed without a resume
	Engine.time_scale = 1.0


func _frames(count: int = 3) -> void:
	for i in range(count):
		await get_tree().process_frame


func _key(keycode: Key, pressed: bool = true, physical: Key = KEY_NONE) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = physical if physical != KEY_NONE else keycode
	event.pressed = pressed
	return event


# ---- wording ----

func test_act_text_reads_from_data_and_a_one_act_run_has_no_act_label() -> void:
	assert_str(ActText.act_label(2, 3)).is_equal("Act 2 of 3")
	assert_str(ActText.act_label(1, 1)).is_empty()
	assert_str(ActText.room_label(14, 30)).is_equal("Room 14 of 30")
	assert_str(ActText.room_label(5, 10)).is_equal("Room 5 of 10")  # a one-act run keeps the old wording


func test_model_room_label_uses_the_whole_run_only_over_several_acts() -> void:
	var three: Dictionary = {"acts_total": 3, "run_room_number": 14, "run_room_total": 30, "room_label": "Room 4 of 10"}
	assert_str(ActText.model_room_label(three)).is_equal("Room 14 of 30")
	var one: Dictionary = {"acts_total": 1, "run_room_number": 4, "run_room_total": 10, "room_label": "Room 4 of 10"}
	assert_str(ActText.model_room_label(one)).is_equal("Room 4 of 10")
	assert_str(ActText.model_room_label({"room_label": "Room 2 of 10"})).is_equal("Room 2 of 10")  # an old fixture without act keys


func test_run_room_offsets_a_nodes_room_by_the_acts_before_it() -> void:
	assert_int(ActText.run_room(4, 1, 30, 3)).is_equal(4)
	assert_int(ActText.run_room(4, 2, 30, 3)).is_equal(14)
	assert_int(ActText.run_room(10, 3, 30, 3)).is_equal(30)
	assert_int(ActText.run_room(4, 1, 10, 1)).is_equal(4)
	assert_int(ActText.run_room(4, 1, 0, 1)).is_equal(4)  # no total known (a view without data): the node's own room


func test_the_hud_plate_text_puts_the_act_on_its_own_line() -> void:
	assert_str(RunHud.indicator_text("", "Room 5 of 10", "Combat")).is_equal("Room 5 of 10  -  Combat")
	var lines: PackedStringArray = RunHud.indicator_text("Act 2 of 3", "Room 14 of 30", "Mini-boss").split(char(10))
	assert_int(lines.size()).is_equal(2)
	assert_str(lines[0]).is_equal("Act 2 of 3")
	assert_str(lines[1]).is_equal("Room 14 of 30  -  Mini-boss")


func test_the_taller_plate_clears_the_other_hud_pieces_and_its_text_fits() -> void:
	var cfg := UiConfig.hud()
	for vp: Vector2 in RESOLUTIONS:
		var rect := HudLayout.room_indicator_rect(vp, cfg, true)
		var plain := HudLayout.room_indicator_rect(vp, cfg, false)
		assert_float(rect.size.y).is_greater(plain.size.y)
		assert_float(rect.size.x).is_equal(plain.size.x)
		assert_bool(HudLayout.safe_area(vp, cfg).encloses(rect)).is_true()
		assert_bool(rect.intersects(HudLayout.health_rect(vp, cfg))).is_false()
		var meters := HudLayout.attack_meter_rects(vp, cfg)
		for key: StringName in meters:
			assert_bool(rect.intersects(meters[key])).is_false()
		assert_float(rect.end.y).is_less(120.0 * maxf(1.0, vp.y / 720.0) + 1.0)  # the F3 overlay starts at y=120
		var gold := HudLayout.gold_rect(vp, cfg, UiConfig.map_screen(), true)
		assert_float(gold.position.y).is_greater_equal(rect.end.y)
	var run_ui := UiConfig.run_ui()
	var font := ThemeDB.fallback_font
	var longest := ""
	for type_name: String in RunConfig.ui()["type_names"].values():
		if type_name.length() > longest.length():
			longest = type_name
	var text: String = RunHud.indicator_text(ActText.act_label(3, 3), ActText.room_label(30, 30), longest)
	var plate: Array = cfg["room_indicator_size_acts"]
	var size_px: int = int(run_ui["indicator_font_size"])
	var widest: float = 0.0
	for line: String in text.split(char(10)):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x)
	assert_float(widest + float(run_ui["indicator_icon_size"]) + 40.0).is_less(float(plate[0]))
	assert_float(font.get_height(size_px) * 2.0 + 4.0).is_less(float(plate[1]))


func test_the_hud_on_a_three_act_run_says_act_and_the_whole_run_room() -> void:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(31)
	state.jump_to_room(13)  # act 2, room 4
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames()
	var hud: RunHud = main.get_node("RunHud") as RunHud
	assert_str(hud.label.text).starts_with("Act 2 of 3").contains("Room 14 of 30")
	assert_float(hud.panel.size.y).is_greater(UiConfig.hud()["room_indicator_size"][1] as float - 1.0)
	assert_float(hud.panel.size.y).is_equal_approx(float(UiConfig.hud()["room_indicator_size_acts"][1]) * HudLayout.ui_scale(hud.get_viewport().get_visible_rect().size, UiConfig.hud()), 0.01)


func test_the_hud_on_a_one_act_run_reads_as_before() -> void:
	RunSession.map_override = 1
	RunSession.acts_override = 1
	RunSession.begin_new_run(31)
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames()
	var hud: RunHud = main.get_node("RunHud") as RunHud
	assert_str(hud.label.text).is_equal("Room 1 of 10  -  Combat")


# ---- the map ----

func _map_data(act: int, acts_total: int, nodes: Array[Dictionary]) -> Dictionary:
	var map_nodes: Array = []
	var edges: Array = []
	for info: Dictionary in nodes:
		map_nodes.append({"id": info["id"], "room": info["room"], "column": info["column"], "type": info["type"], "wave_id": ""})
	return {"map": {"nodes": map_nodes, "edges": edges}, "path": [0], "reachable": [], "nodes": nodes, "gold": 0, "gold_earned": 0,
			"act": act, "acts_total": acts_total, "run_room_total": acts_total * 10}


func _info(id: int, room: int, type_id: String, reachable: bool) -> Dictionary:
	return {"id": id, "room": room, "column": 0, "type": type_id, "type_name": type_id, "wave_id": "", "chest": "", "chest_name": "", "hover": "hover %d" % id,
			"gold_low": 0, "gold_high": 0, "reachable": reachable, "taken": false, "current": false}


func test_only_way_on_names_the_boss_or_the_mini_boss() -> void:
	var boss: Array[Dictionary] = [_info(0, 9, "combat", false), _info(1, 10, "boss", true)]
	assert_str(MapLayout.only_way_on(boss)).is_equal("boss")
	var mini: Array[Dictionary] = [_info(0, 9, "combat", false), _info(1, 10, "mini_boss", true)]
	assert_str(MapLayout.only_way_on(mini)).is_equal("mini_boss")
	var two: Array[Dictionary] = [_info(0, 9, "mini_boss", true), _info(1, 9, "combat", true)]
	assert_str(MapLayout.only_way_on(two)).is_empty()
	var none: Array[Dictionary] = [_info(0, 9, "combat", true)]
	assert_str(MapLayout.only_way_on(none)).is_empty()


func _spawn_map() -> MapScreen:
	var screen: MapScreen = (load(MAP_SCREEN_PATH) as PackedScene).instantiate()
	add_child(screen)
	auto_free(screen)
	await _frames(1)
	return screen


func test_the_map_title_and_hover_carry_the_act_and_the_whole_run_room() -> void:
	var screen: MapScreen = await _spawn_map()
	var nodes: Array[Dictionary] = [_info(0, 4, "combat", true), _info(1, 4, "elite", true)]
	screen.show_pick(_map_data(2, 3, nodes))
	await _frames(1)
	assert_str(screen.title_label.text).contains("Act 2 of 3")
	assert_str(screen.hover_text(0)).contains("Room 14")
	assert_str(screen.line_label.text).contains("mini-boss")  # acts 1 and 2 end in the mini-boss, not the boss
	var third: MapScreen = await _spawn_map()
	third.show_pick(_map_data(3, 3, nodes))
	await _frames(1)
	assert_str(third.line_label.text).contains("boss").not_contains("mini-boss")
	assert_str(third.hover_text(0)).contains("Room 24")


func test_a_one_act_map_has_no_act_in_its_title() -> void:
	var screen: MapScreen = await _spawn_map()
	var nodes: Array[Dictionary] = [_info(0, 4, "combat", true), _info(1, 4, "elite", true)]
	screen.show_pick(_map_data(1, 1, nodes))
	await _frames(1)
	assert_str(screen.title_label.text).is_equal(String(RunConfig.ui()["map"]["title"]))
	assert_str(screen.hover_text(0)).contains("Room 4")


func test_the_mini_boss_as_the_only_way_on_says_so() -> void:
	var screen: MapScreen = await _spawn_map()
	var nodes: Array[Dictionary] = [_info(0, 9, "combat", false), _info(1, 10, "mini_boss", true)]
	screen.show_pick(_map_data(1, 3, nodes))
	await _frames(1)
	assert_str(screen.title_label.text).starts_with(String(RunConfig.ui()["map"]["mini_boss_title"]))
	assert_str(screen.line_label.text).is_equal(String(RunConfig.ui()["map"]["mini_boss_line"]))


func test_the_mini_boss_has_its_own_shape_colour_name_and_hover_text() -> void:
	var shapes: Dictionary = {}
	for type_id: String in MapLayout.TYPE_ORDER:
		shapes[RunIcons.shape_for(type_id)] = type_id
	assert_int(shapes.size()).override_failure_message("two map node types share a shape").is_equal(MapLayout.TYPE_ORDER.size())
	assert_str(RunIcons.shape_for("mini_boss")).is_not_equal(RunIcons.shape_for("elite")).is_not_equal(RunIcons.shape_for("boss"))
	assert_str(String(RunConfig.ui()["type_names"]["mini_boss"])).is_equal("Mini-boss")
	assert_str(String(RunConfig.ui()["map"]["hover"]["mini_boss"])).is_not_empty()
	var tiers: Dictionary = RunConfig.get_config().get("tiers", {})
	var colours: Dictionary = {}
	for type_id: String in ["elite", "boss", "mini_boss"]:
		colours[RunIcons.color_for(type_id, UiConfig.run_ui(), tiers).to_html()] = type_id
	assert_int(colours.size()).is_equal(3)


func test_the_legend_draws_the_merchants_coin_like_the_map_node() -> void:
	var screen: MapScreen = await _spawn_map()
	var nodes: Array[Dictionary] = [_info(0, 1, "combat", true), _info(1, 1, "merchant", true)]
	screen.show_pick(_map_data(1, 1, nodes))
	await _frames(1)
	var coins: int = 0
	var icons: int = 0
	for item: Node in screen.legend_flow.get_children():
		var icon: RunTypeIcon = item.get_child(0) as RunTypeIcon
		icons += 1
		if icon.coin:
			coins += 1
			assert_str(String(item.get_meta(&"type"))).is_equal("merchant")
	assert_int(icons).is_equal(2)
	assert_int(coins).is_equal(1)
	assert_str(String(RunConfig.ui()["map"]["spend_line"])).contains("coin")


# ---- the reward subtitle and the deck-minimum step ----

func test_a_removal_that_no_card_can_take_tells_the_player_what_to_do() -> void:
	var merchant: Dictionary = RunConfig.ui()["merchant"]
	assert_str(String(merchant["tile_reasons"]["none_removable"])).contains("Add a card")
	assert_str(String(merchant["reasons"]["none_removable"])).contains("Add a card")
	assert_str(String(RunConfig.ui()["rest"]["remove_none"])).contains("Add a card")


# ---- the act screen ----

func _act_summary(act: int) -> Dictionary:
	return {"act": act, "acts_total": 3, "title": "Act %d" % act, "line": "HP 22 of 30, 140 gold, relics: 1"}


func test_the_act_screen_shows_title_and_summary_and_waits_for_its_arm_delay() -> void:
	var host := Node.new()
	add_child(host)
	auto_free(host)
	var screen := ActScreen.new()
	screen.name = "ActScreen"
	host.add_child(screen)
	await _frames(1)
	var closed: Array[int] = [0]
	screen.closed.connect(func() -> void: closed[0] += 1)
	screen.show_act(_act_summary(2))
	assert_bool(screen.is_open()).is_true()
	assert_str(screen.title_label.text).is_equal("Act 2")
	assert_str(screen.line_label.text).is_equal("HP 22 of 30, 140 gold, relics: 1")
	assert_str(screen.button.text).is_equal("Continue")
	assert_str(screen.hint_label.text).is_equal("Enter to continue")
	assert_bool(screen.dismiss()).is_false()  # armed only after prompt_option_arm_delay
	assert_bool(screen.is_open()).is_true()
	screen.disarm()
	screen.get_viewport().push_input(_key(KEY_ENTER))
	await _frames(1)
	assert_bool(screen.is_open()).is_false()
	assert_int(closed[0]).is_equal(1)


func test_the_act_screen_swallows_slot_keys_and_space_so_nothing_casts_behind_it() -> void:
	var host := Node.new()
	add_child(host)
	auto_free(host)
	var spy := KeySpy.new()
	host.add_child(spy)
	var screen := ActScreen.new()
	screen.name = "ActScreen"
	host.add_child(screen)
	await _frames(1)
	screen.show_act(_act_summary(2))
	screen.disarm()
	var slot_key: InputEventKey = null
	for event: InputEvent in InputMap.action_get_events(Player.USE_ACTIONS[0]):
		if event is InputEventKey:
			slot_key = (event as InputEventKey).duplicate() as InputEventKey
			break
	assert_object(slot_key).is_not_null()
	slot_key.pressed = true
	screen.get_viewport().push_input(slot_key)
	var space := _key(KEY_SPACE)
	screen.get_viewport().push_input(space)
	await _frames(1)
	assert_int(spy.presses).is_equal(0)
	assert_bool(screen.is_open()).is_true()  # Space does not continue
	screen.get_viewport().push_input(_key(KEY_ENTER))
	await _frames(1)
	assert_int(spy.presses).is_equal(0)  # Enter is consumed too, so it never reaches the map under it
	assert_bool(screen.is_open()).is_false()


func test_the_map_pick_waits_behind_the_act_screen_and_opens_on_continue() -> void:
	var host := Node.new()
	add_child(host)
	auto_free(host)
	var act_screen := ActScreen.new()
	act_screen.name = "ActScreen"
	host.add_child(act_screen)
	var map_screen: MapScreen = (load(MAP_SCREEN_PATH) as PackedScene).instantiate()
	host.add_child(map_screen)
	await _frames(1)
	act_screen.show_act(_act_summary(2))
	var nodes: Array[Dictionary] = [_info(0, 1, "combat", true), _info(1, 1, "elite", true)]
	map_screen.show_pick(_map_data(2, 3, nodes))
	assert_bool(map_screen.is_open()).is_false()
	assert_bool(map_screen.pick_pending()).is_true()
	act_screen.disarm()
	assert_bool(act_screen.dismiss()).is_true()
	assert_bool(map_screen.is_open()).is_true()
	assert_int(map_screen.mode()).is_equal(MapScreen.Mode.PICK)


func test_a_pause_and_resume_does_not_open_the_held_pick_under_the_act_screen() -> void:
	var host := Node.new()
	add_child(host)
	auto_free(host)
	var act_screen := ActScreen.new()
	act_screen.name = "ActScreen"
	host.add_child(act_screen)
	var map_screen: MapScreen = (load(MAP_SCREEN_PATH) as PackedScene).instantiate()
	host.add_child(map_screen)
	await _frames(1)
	act_screen.show_act(_act_summary(2))
	var nodes: Array[Dictionary] = [_info(0, 1, "combat", true), _info(1, 1, "elite", true)]
	map_screen.show_pick(_map_data(2, 3, nodes))
	GamePause.pause()
	GamePause.resume()
	assert_bool(map_screen.is_open()).is_false()
	assert_bool(map_screen.pick_pending()).is_true()
	act_screen.disarm()
	act_screen.dismiss()
	assert_bool(map_screen.is_open()).is_true()


func test_the_win_screen_of_a_three_act_run_counts_over_the_whole_run() -> void:
	var rows: Array[Dictionary] = RunPromptRows.win_rows([{}, {}, {}], 30, {}, RunConfig.ui()["win"])
	assert_str(String(rows[0]["value"])).is_equal("3 / 30")
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(31)
	state.jump_to_room(29)  # the final boss
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames()
	# the win screen reads run_room_total (30), not room_total (the act's 10): "30 / 10" would be wrong
	assert_int(main.run_controller.run_room_total()).is_equal(30)
	assert_int(main.run_controller.room_total()).is_equal(10)


func test_clearing_the_mini_boss_opens_the_act_screen_over_a_held_map() -> void:
	(RunConfig.get_config()["acts"] as Dictionary)["start_heal"] = 0.0  # this test reads the MAP3 summary line (HP carried over unchanged); the D45 heal has its own tests
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(31)
	state.jump_to_room(9)  # the act 1 mini-boss
	state.hp = 22.0
	state.max_hp = 30.0
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames()
	var controller: RunController = main.run_controller
	var act_screen: ActScreen = main.get_node("ActScreen") as ActScreen
	var map_screen: MapScreen = main.get_node("MapScreen") as MapScreen
	var table: Dictionary = WaveConfig.get_config().duplicate(true)
	table["stages"] = [{"delay": 0.0, "spawns": [{"enemy": "melee_chaser", "count": 1}]}]
	table["first_wave_delay"] = 0.0
	table["finite"] = true
	table["loop_from_stage"] = 0
	main.enemy_spawner.configure_room(table, 1)
	main.enemy_spawner._process(1.0)
	for child in main.get_children():
		if child is Enemy:
			(child as Enemy).health.take_damage(100000.0)
	await _frames(2)
	controller.pick_relic(state.offer[0])
	controller.choose("skip")
	assert_bool(act_screen.is_open()).is_true()
	assert_str(act_screen.title_label.text).is_equal("Act 2")
	assert_str(act_screen.line_label.text).contains("22 of 30")
	assert_bool(map_screen.is_open()).is_false()
	assert_bool(map_screen.pick_pending()).is_true()
	act_screen.disarm()
	act_screen.dismiss()
	assert_bool(map_screen.is_open()).is_true()
	assert_str(map_screen.title_label.text).contains("Act 2 of 3")


# ---- Continue ----

func _saved_run(seed_value: int, rooms_picked: int) -> RunState:
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(seed_value, "wizard")
	state.jump_to_room(rooms_picked - 1)
	state.max_hp = 30.0
	state.hp = 21.0
	return state


func test_the_resume_summary_counts_the_room_you_will_be_in_next() -> void:
	RunSession.acts_override = 3
	var state: RunState = _saved_run(5, 14)  # act 2, the 4th room picked: in the room, pending none
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)
	var in_room: Dictionary = RunSave.summary_of(state)
	assert_int(int(in_room["act"])).is_equal(2)
	assert_int(int(in_room["acts_total"])).is_equal(3)
	assert_int(int(in_room["room"])).is_equal(14)  # a room's start restarts that room
	assert_int(int(in_room["room_total"])).is_equal(30)
	assert_str(String(in_room["character"])).is_equal("wizard")
	assert_str(String(in_room["character_name"])).is_equal(CharacterDatabase.display_name("wizard"))
	RunNodes.open(state)  # at the map screen the 4 rooms are done
	assert_int(int(RunSave.summary_of(state)["room"])).is_equal(15)
	var fresh_act: RunState = RunSession.begin_new_run(6, "rogue")
	fresh_act.jump_to_room(9)
	RunNodes.advance_act(fresh_act)  # the map screen at the start of act 2: nothing picked yet
	var at_start: Dictionary = RunSave.summary_of(fresh_act)
	assert_int(int(at_start["act"])).is_equal(2)
	assert_int(int(at_start["room"])).is_equal(11)
	assert_dict(RunSave.summary_of(null)).is_empty()


func test_summary_reads_the_file_and_is_empty_without_one() -> void:
	assert_dict(RunSave.summary()).is_empty()
	RunSession.acts_override = 3
	var state: RunState = _saved_run(7, 12)
	RunNodes.open(state)
	assert_bool(RunSave.write(state)).is_true()
	var read: Dictionary = RunSave.summary()
	assert_int(int(read["act"])).is_equal(2)
	assert_int(int(read["room"])).is_equal(13)
	RunSave.persist_override = false
	assert_dict(RunSave.summary()).is_empty()  # a launch that does not use the file shows no Continue


func test_continue_detail_names_class_act_and_room_and_drops_the_act_of_a_one_act_save() -> void:
	var cfg: Dictionary = UiConfig.class_pick()
	var info: Dictionary = {"character_name": "Wizard", "act": 2, "acts_total": 3, "room": 14, "room_total": 30}
	assert_str(ClassPickScreen.continue_detail(info, cfg)).is_equal("Wizard  -  Act 2 of 3  -  Room 14 of 30")
	info = {"character_name": "Rogue", "act": 1, "acts_total": 1, "room": 5, "room_total": 10}
	assert_str(ClassPickScreen.continue_detail(info, cfg)).is_equal("Rogue  -  Room 5 of 10")


func _spawn_pick_host() -> Main:
	ClassPickScreen.enabled_override = true
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _frames(3)
	return main


func test_the_class_pick_offers_continue_when_a_save_exists_and_starts_on_it() -> void:
	RunSession.acts_override = 3
	var saved: RunState = _saved_run(9, 14)
	RunNodes.open(saved)
	assert_bool(RunSave.write(saved)).is_true()
	RunSession.clear()
	var main: Main = await _spawn_pick_host()
	var pick: ClassPickScreen = main.get_node("ClassPickScreen") as ClassPickScreen
	assert_bool(pick.is_open()).is_true()
	assert_bool(pick.has_continue()).is_true()
	assert_str(pick.continue_text()).contains("Wizard").contains("Act 2 of 3").contains("Room 15 of 30")
	assert_str(pick._start_label.text).is_equal(String(UiConfig.class_pick()["continue_start"]))
	# the arrow keys cycle the cards and then Continue; a class card says it replaces the saved run
	pick._step(-1)
	assert_str(pick.highlighted_id()).is_not_empty()
	assert_str(pick._start_label.text).contains("replaces your saved run")
	pick._step(1)
	assert_str(pick.highlighted_id()).is_empty()


func test_continue_resumes_the_saved_run_and_the_new_scene_does_not_ask_again() -> void:
	RunSession.acts_override = 3
	var saved: RunState = _saved_run(9, 14)
	RunNodes.open(saved)
	assert_bool(RunSave.write(saved)).is_true()
	var expected_json: String = saved.to_json()
	RunSession.clear()
	var main: Main = await _spawn_pick_host()
	var pick: ClassPickScreen = main.get_node("ClassPickScreen") as ClassPickScreen
	assert_bool(pick.continue_run()).is_false()  # armed only after the arm delay
	pick.disarm()
	assert_bool(pick.continue_run()).is_true()
	await _frames(3)
	assert_str(RunSession.current.to_json()).is_equal(expected_json)
	var resumed: Main = null
	for child in get_children():
		if child is Main and child != main and not child.is_queued_for_deletion():
			resumed = child as Main
	assert_object(resumed).is_not_null()
	assert_str(resumed.run_controller.character_id()).is_equal("wizard")
	assert_int(resumed.run_controller.current_act()).is_equal(2)
	assert_bool((resumed.get_node("ClassPickScreen") as ClassPickScreen).is_open()).is_false()
	assert_bool((resumed.get_node("MapScreen") as MapScreen).is_open()).is_true()  # the save was at the map screen


func test_continue_at_an_acts_first_map_screen_does_not_reopen_the_class_pick() -> void:
	RunSession.acts_override = 3
	var state: RunState = RunSession.begin_new_run(11, "rogue")
	state.jump_to_room(9)
	state.max_hp = 30.0
	state.hp = 25.0
	assert_bool(RunNodes.advance_act(state)).is_true()
	assert_bool(state.path.is_empty()).is_true()
	assert_bool(RunSave.write(state)).is_true()
	RunSession.clear()
	var main: Main = await _spawn_pick_host()
	var pick: ClassPickScreen = main.get_node("ClassPickScreen") as ClassPickScreen
	pick.disarm()
	assert_bool(pick.continue_run()).is_true()
	await _frames(3)
	# the resumed state has an empty path in act 2: only the remembered run keeps the pick from asking for a class again
	assert_bool(ClassPickScreen.should_open(RunSession.current)).is_false()
	var resumed: Main = null
	for child in get_children():
		if child is Main and child != main and not child.is_queued_for_deletion():
			resumed = child as Main
	assert_object(resumed).is_not_null()
	assert_bool((resumed.get_node("ClassPickScreen") as ClassPickScreen).is_open()).is_false()
	assert_int(resumed.run_controller.current_act()).is_equal(2)


func test_a_new_run_leaves_the_save_alone_until_its_first_save_point_then_replaces_it() -> void:
	RunSession.acts_override = 3
	var saved: RunState = _saved_run(9, 14)
	RunNodes.open(saved)
	assert_bool(RunSave.write(saved)).is_true()
	RunSession.clear()
	var main: Main = await _spawn_pick_host()
	var pick: ClassPickScreen = main.get_node("ClassPickScreen") as ClassPickScreen
	pick.disarm()
	pick.confirm("rogue")  # a card: a new run (the class pick of a different class restarts it; the same class just closes)
	await _frames(3)
	assert_bool(RunSave.read_state().equals(saved)).is_true()  # the pick itself overwrote nothing
	var latest: Main = null
	for child in get_children():
		if child is Main and not child.is_queued_for_deletion():
			latest = child as Main
	var controller: RunController = latest.run_controller
	controller.pick_node(controller.reachable_nodes()[0])
	await _frames(3)
	var after: RunState = RunSave.read_state()
	assert_int(after.seed_value).is_not_equal(saved.seed_value)  # the first room's start replaced it
	assert_str(after.character_id).is_equal("rogue")


func test_without_a_save_the_class_pick_has_no_continue() -> void:
	var main: Main = await _spawn_pick_host()
	var pick: ClassPickScreen = main.get_node("ClassPickScreen") as ClassPickScreen
	assert_bool(pick.is_open()).is_true()
	assert_bool(pick.has_continue()).is_false()
	assert_str(pick._start_label.text).is_equal(String(UiConfig.class_pick()["start_format"]) % CharacterDatabase.display_name(pick.highlighted_id()))


# ---- the shop ----

func test_the_shop_may_run_a_few_pixels_over_before_it_scrolls() -> void:
	var slack: float = float(UiConfig.run_ui().get("shop_scroll_slack", 0.0))
	assert_float(slack).is_greater(0.0)
	assert_float(slack).is_less(0.1)  # a few percent: a real overflow (a long removal list) still scrolls
