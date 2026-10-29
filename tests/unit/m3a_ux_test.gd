class_name M3aUxTest
extends GdUnitTestSuite
## Milestone 3a UX: room indicator placement, shape language, prompt rows and behaviour (never over pause or
## Game Over, focused button, keyboard and mouse), tier marker, and the Game Over run line.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const RESOLUTIONS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]


func before_test() -> void:
	RunSession.clear()


func after_test() -> void:
	RunSession.clear()
	Juice.reset()
	GamePause.reset()
	get_tree().paused = false


func _spawn() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _summary(type: String = "combat", healed: float = 0.0) -> Dictionary:
	return {"index": 0, "type": type, "wave_id": "x", "hp": 22.0, "max_hp": 30.0, "healed": healed, "seconds": 75.0}


# ---- layout ----

func test_room_indicator_clears_other_hud_pieces_at_all_resolutions() -> void:
	var cfg := UiConfig.hud()
	for vp in RESOLUTIONS:
		var rect := HudLayout.room_indicator_rect(vp, cfg)
		assert_bool(HudLayout.safe_area(vp, cfg).encloses(rect)).is_true()
		assert_bool(rect.intersects(HudLayout.health_rect(vp, cfg))).is_false()
		assert_bool(rect.intersects(HudLayout.slot_bar_rect(vp, cfg, 5))).is_false()
		var meters := HudLayout.attack_meter_rects(vp, cfg)
		for key: StringName in meters:
			assert_bool(rect.intersects(meters[key])).is_false()
		# The F3 overlay panel starts at y=120 in screen pixels (it is not scaled).
		assert_float(rect.end.y).is_less(120.0 * maxf(1.0, vp.y / 720.0) + 1.0)


func test_indicator_text_fits_its_plate() -> void:
	var cfg := UiConfig.hud()
	var run_ui := UiConfig.run_ui()
	var font := ThemeDB.fallback_font
	var longest := ""
	for type: String in RunConfig.ui()["type_names"].values():
		if type.length() > longest.length():
			longest = type
	var text := "%s  -  %s" % [String(RunConfig.ui()["room_label"]) % [10, 10], longest]
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(run_ui["indicator_font_size"])).x
	var plate: Array = cfg["room_indicator_size"]
	assert_float(width + float(run_ui["indicator_icon_size"]) + 40.0).is_less(float(plate[0]))


# ---- shapes ----

func test_every_room_type_has_a_distinct_shape() -> void:
	var seen: Dictionary = {}
	for type: String in RunConfig.ROOM_TYPES:
		seen[RunIcons.shape_for(type)] = true
	assert_int(seen.size()).is_equal(RunConfig.ROOM_TYPES.size())
	assert_str(RunIcons.shape_for("nonsense")).is_equal(RunIcons.SHAPE_CIRCLE)


func test_polygons_fit_their_radius() -> void:
	for shape: String in [RunIcons.SHAPE_CIRCLE, RunIcons.SHAPE_DIAMOND, RunIcons.SHAPE_PLUS, RunIcons.SHAPE_STAR]:
		var pts := RunIcons.polygon(shape, 10.0)
		assert_int(pts.size()).is_greater_equal(3)
		for p in pts:
			assert_float(p.length()).is_less_equal(10.001)
		assert_int(Geometry2D.triangulate_polygon(pts).size()).is_greater_equal(3)


func test_tier_colours_come_from_run_data() -> void:
	var tiers: Dictionary = RunConfig.get_config()["tiers"]
	var c := RunIcons.color_for("elite", UiConfig.run_ui(), tiers)
	assert_bool(c.is_equal_approx(Color.html(String(tiers["elite"]["marker_color"])))).is_true()
	assert_bool(RunIcons.color_for("rest", UiConfig.run_ui(), tiers).is_equal_approx(Color.html("#8fe388"))).is_true()


# ---- prompt text ----

func test_format_time() -> void:
	assert_str(RunPromptRows.format_time(0.0)).is_equal("0:00")
	assert_str(RunPromptRows.format_time(75.4)).is_equal("1:15")
	assert_str(RunPromptRows.format_time(-5.0)).is_equal("0:00")
	assert_str(RunPromptRows.format_time(NAN)).is_equal("0:00")
	assert_str(RunPromptRows.format_time(600.0)).is_equal("10:00")


func test_cleared_rows_combat_and_rest() -> void:
	var text: Dictionary = RunConfig.ui()["room_cleared"]
	var combat := RunPromptRows.cleared_rows(_summary("combat"), text)
	assert_str(combat[0]["value"]).is_equal("22 / 30")
	assert_str(combat[1]["value"]).is_equal("1:15")
	var rest := RunPromptRows.cleared_rows(_summary("rest", 9.0), text)
	assert_str(rest[1]["value"]).is_equal("+9")
	assert_int(rest.size()).is_equal(2)  # no time row on a rest room


func test_win_rows_sum_the_history() -> void:
	var history: Array = [{"seconds": 30.0}, {"seconds": 45.0}]
	var rows := RunPromptRows.win_rows(history, 8, _summary(), RunConfig.ui()["win"])
	assert_str(rows[0]["value"]).is_equal("2 / 8")
	assert_str(rows[1]["value"]).is_equal("1:15")
	assert_str(rows[2]["value"]).is_equal("22 / 30")


# ---- prompt behaviour ----

func test_cleared_prompt_opens_focused_and_the_button_confirms() -> void:
	RunSession.begin_new_run(42)
	var main := _spawn()
	await get_tree().process_frame
	var prompt := main.get_node("RoomClearedScreen") as RunPromptScreen
	prompt.show_content({"title": "t", "rows": [{"label": "a", "value": "b"}], "button": "Go"})
	assert_bool(prompt.visible).is_true()
	assert_bool(prompt.button.has_focus()).is_true()
	assert_int(prompt.stats.get_child_count()).is_equal(2)
	assert_int(prompt.root.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	var confirmed: Array[bool] = []
	prompt.confirmed.connect(func() -> void: confirmed.append(true))
	prompt.button.pressed.emit()  # a mouse click and Enter or Space both end in pressed
	assert_array(confirmed).has_size(1)
	assert_bool(prompt.visible).is_false()


func test_prompt_waits_out_a_pause_and_regains_focus() -> void:
	RunSession.begin_new_run(42)
	var main := _spawn()
	await get_tree().process_frame
	var prompt := main.get_node("RoomClearedScreen") as RunPromptScreen
	GamePause.pause()
	prompt.show_content({"title": "t", "button": "Go"})
	assert_bool(prompt.visible).is_false()
	GamePause.resume()
	assert_bool(prompt.visible).is_true()
	assert_bool(prompt.button.has_focus()).is_true()
	GamePause.pause()
	prompt.button.release_focus()
	GamePause.resume()
	await get_tree().process_frame
	assert_bool(prompt.button.has_focus()).is_true()


func test_prompt_never_opens_over_game_over() -> void:
	RunSession.begin_new_run(42)
	var main := _spawn()
	await get_tree().process_frame
	var prompt := main.get_node("RoomClearedScreen") as RunPromptScreen
	main.player.health.take_damage(100000.0)
	await get_tree().process_frame
	prompt.show_content({"title": "t", "button": "Go"})
	assert_bool(prompt.visible).is_false()


func test_win_screen_lists_run_stats() -> void:
	RunSession.begin_new_run(42)
	var main := _spawn()
	await get_tree().process_frame
	var win := main.get_node("WinScreen") as RunPromptScreen
	main.run_controller.state().record_room({"index": 0, "type": "combat", "wave_id": "x"}, 20.0, 61.0)
	win.call("_show_win")
	assert_bool(win.visible).is_true()
	assert_int(win.stats.get_child_count()).is_equal(6)
	assert_str(win.button.text).is_equal(String(RunConfig.ui()["win"]["button"]))


# ---- tier marker and Game Over ----

func test_tier_marker_is_a_flat_shape_and_replaces_itself() -> void:
	var holder := Node3D.new()
	auto_free(holder)
	var tiers: Dictionary = RunConfig.get_config()["tiers"]
	var marker := TierMarker.attach(holder, "boss", tiers["boss"])
	assert_str(String(marker.name)).is_equal("TierMarker")
	assert_object(marker.mesh).is_not_null()
	assert_float(marker.mesh.get_aabb().size.z).is_less(0.05)  # flat: it can never read as a body
	TierMarker.attach(holder, "elite", tiers["elite"])
	assert_int(holder.get_child_count()).is_equal(1)
	assert_bool(holder.get_child(0).mesh != marker.mesh).is_true()


func test_game_over_shows_the_room_reached_in_a_run_only() -> void:
	RunSession.begin_new_run(42)
	var main := _spawn()
	await get_tree().process_frame
	var screen := main.get_node("GameOverScreen") as GameOverScreen
	assert_str(screen.run_line()).contains("room 1 of 8")
	var arena := (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	add_child(arena)
	auto_free(arena)
	assert_str((arena.get_node("GameOverScreen") as GameOverScreen).run_line()).is_equal("")
