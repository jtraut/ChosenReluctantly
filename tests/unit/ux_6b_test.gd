class_name Ux6bTest
extends GdUnitTestSuite
## Slice 6b: the settings / pause screen, the preview look, the D7 bar mode, and the player
## occlusion cue. Settings are injected (temp file under user://tests), never the real user file.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const DEFAULTS := "res://data/settings.json"
const TEMP_SETTINGS := "user://tests/ux_6b_settings.cfg"

var _original_store: SettingsStore = null
var _root_main: Main = null


func before_test() -> void:
	CardDatabase.load_all()
	DirAccess.make_dir_recursive_absolute("user://tests")
	DirAccess.remove_absolute(TEMP_SETTINGS)
	_original_store = Settings.store
	Settings.use_store(SettingsStore.new(DEFAULTS, TEMP_SETTINGS))


func after_test() -> void:
	GamePause.resume()
	GamePause.reset()
	get_tree().paused = false
	Settings.use_store(_original_store)
	DirAccess.remove_absolute(TEMP_SETTINGS)
	if _root_main != null and is_instance_valid(_root_main):
		get_tree().current_scene = null
		_root_main.free()
	_root_main = null
	Juice.reset()
	TestInput.release(&"slot_1")
	TestInput.release(&"slot_2")


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	_root_main = main
	main.player.card_slots.spawn_parent = main
	main.player.camera = null
	return main


func _screen(main: Main) -> SettingsScreen:
	return main.get_node("SettingsScreen") as SettingsScreen


# --- settings screen ---------------------------------------------------------------------------

func test_esc_opens_and_closes_the_screen_and_pauses_and_resumes() -> void:
	var main := _main()
	await _frames(2)
	var screen := _screen(main)
	assert_bool(screen.is_open()).is_false()
	TestInput.tap(&"pause")
	await _frames(1)
	assert_bool(screen.is_open()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_bool(GamePause.is_paused()).is_true()
	TestInput.tap(&"pause")
	await _frames(1)
	assert_bool(screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_resume_button_closes_and_has_focus_by_default() -> void:
	var main := _main()
	await _frames(2)
	var screen := _screen(main)
	assert_bool(screen.open()).is_true()
	assert_bool(screen.resume_button.has_focus()).is_true()
	screen.resume_button.pressed.emit()
	assert_bool(screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_pause_action_is_bound_to_escape() -> void:
	var keys: Array[int] = []
	for event: InputEvent in InputMap.action_get_events(&"pause"):
		if event is InputEventKey:
			keys.append((event as InputEventKey).physical_keycode)
	assert_array(keys).contains([KEY_ESCAPE])


func test_options_come_from_the_definition_and_the_stored_value_is_marked() -> void:
	var main := _main()
	await _frames(2)
	var screen := _screen(main)
	var definition := Settings.get_definition(Settings.CAST_TRIGGER)
	assert_str(screen.option_label.text).is_equal(String(definition["label"]) + ":")
	assert_array(screen.option_buttons.keys()).is_equal(definition["options"])
	for option: String in screen.option_buttons:
		var button: Button = screen.option_buttons[option]
		assert_bool(button.text.ends_with(String(definition["option_labels"][option]))).is_true()
	var cfg := UiConfig.settings_screen()
	assert_bool((screen.option_buttons["release"] as Button).text.begins_with(String(cfg["selected_marker"]))).is_true()
	assert_bool((screen.option_buttons["press"] as Button).text.begins_with(String(cfg["unselected_marker"]))).is_true()


func test_toggling_changes_the_setting_and_saves_it_at_once() -> void:
	var main := _main()
	await _frames(2)
	var screen := _screen(main)
	screen.open()
	(screen.option_buttons["press"] as Button).button_pressed = true
	assert_str(Settings.cast_trigger()).is_equal("press")
	assert_bool(FileAccess.file_exists(TEMP_SETTINGS)).is_true()
	# A fresh store reading the same file sees the change: it was saved, not just held in memory.
	assert_str(SettingsStore.new(DEFAULTS, TEMP_SETTINGS).get_string(Settings.CAST_TRIGGER)).is_equal("press")
	assert_bool((screen.option_buttons["press"] as Button).text.begins_with(String(UiConfig.settings_screen()["selected_marker"]))).is_true()
	(screen.option_buttons["release"] as Button).button_pressed = true
	assert_str(Settings.cast_trigger()).is_equal("release")


func test_opening_the_screen_does_not_save_anything() -> void:
	var main := _main()
	await _frames(2)
	_screen(main).open()
	assert_bool(FileAccess.file_exists(TEMP_SETTINGS)).is_false()


func test_it_refuses_to_open_over_game_over() -> void:
	var main := _main()
	await _frames(2)
	main._game_over_announced = true
	var screen := _screen(main)
	assert_bool(screen.open()).is_false()
	TestInput.tap(&"pause")
	await _frames(1)
	assert_bool(screen.is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


func test_opening_over_a_hit_stop_shows_normal_time_and_closing_gives_the_rest_back() -> void:
	var main := _main()
	await _frames(2)
	var screen := _screen(main)
	Juice.hit_stop(0.8, 0.1)
	assert_float(Engine.time_scale).is_less(1.0)
	assert_bool(screen.open()).is_true()
	assert_float(Engine.time_scale).is_equal(1.0)
	screen.close()
	assert_float(Engine.time_scale).is_less(1.0)


func test_opening_cancels_a_held_preview_without_casting() -> void:
	var main := _main()
	await _frames(2)
	var casts: Array[String] = []
	main.player.card_slots.card_cast.connect(func(slot_type: String, _card: String) -> void: casts.append(slot_type))
	TestInput.press(&"slot_1")
	await _frames(2)
	assert_bool(main.player.cast_input.is_previewing()).is_true()
	_screen(main).open()
	assert_bool(main.player.cast_input.is_previewing()).is_false()
	_screen(main).close()
	TestInput.release(&"slot_1")
	await _frames(3)
	assert_array(casts).is_empty()


func test_screen_text_is_data_and_fits_a_720p_viewport() -> void:
	var main := _main()
	await _frames(2)
	var screen := _screen(main)
	var cfg := UiConfig.settings_screen()
	screen.open()
	await _frames(2)
	assert_str(screen.title_label.text).is_equal(String(cfg["title"]))
	assert_str(screen.resume_button.text).is_equal(String(cfg["resume"]))
	var column_size: Vector2 = screen.column.get_combined_minimum_size()
	var viewport := Vector2(1280, 720)
	assert_float(column_size.x).is_less(viewport.x)
	assert_float(column_size.y).is_less(viewport.y)
	for option: String in screen.option_buttons:
		assert_float((screen.option_buttons[option] as Button).get_combined_minimum_size().y).is_greater_equal(44.0)
	assert_float(screen.backdrop.color.a).is_greater(0.5)


# --- D7 ----------------------------------------------------------------------------------------

func test_shipped_hp_bar_mode_is_elite_boss_always() -> void:
	assert_str(UiConfig.hp_bars()["visibility_mode"]).is_equal("elite_boss_always")
	assert_bool(EnemyHpBar.MODES.has("elite_boss_always")).is_true()
	# normal at full HP: hidden; the same normal once hurt: shown; an elite or boss: always.
	assert_bool(EnemyHpBar.should_show("elite_boss_always", false, false, 1.0, "normal")).is_false()
	assert_bool(EnemyHpBar.should_show("elite_boss_always", false, true, 0.9, "normal")).is_true()
	assert_bool(EnemyHpBar.should_show("elite_boss_always", false, false, 1.0, "boss")).is_true()


# --- preview look ------------------------------------------------------------------------------

func test_preview_uses_the_player_element_colour_and_sits_over_enemies() -> void:
	var config := CastPreviewConfig.get_config()
	assert_str(config["color_source"]).is_equal("player_element")
	assert_bool(bool(config["over_enemies"])).is_true()
	assert_array(CastPreviewConfig.validate(config)).is_empty()


func test_preview_dims_when_not_ready_and_keeps_its_size() -> void:
	var main := _main()
	await _frames(2)
	var player := main.player
	var card_id := "fire_ember_whatever"
	var slot_type: String = CardDatabase.get_card(card_id)["slot_type"]
	var slot: CardSlot = player.card_slots.get_slot(slot_type)
	slot.current_card_id = card_id
	var action := StringName("slot_%d" % (CardSlotController.SLOT_TYPE_ORDER.find(slot_type) + 1))
	TestInput.press(action)
	await _frames(3)
	var preview := player.cast_preview
	var ready_edge := preview.edge_color(0)
	var ready_fill := preview.fill_color(0)
	var ready_scale := preview.fill_node(0).scale
	assert_bool((preview.fill_node(0).material_override as StandardMaterial3D).no_depth_test).is_true()
	slot.cooldown_remaining = 5.0
	await _frames(2)
	var dim_edge := preview.edge_color(0)
	assert_float(dim_edge.a).is_less(ready_edge.a)
	assert_float(preview.fill_color(0).a).is_less(ready_fill.a)
	assert_float(dim_edge.a).is_equal_approx(ready_edge.a * float(CastPreviewConfig.get_config()["not_ready_alpha_scale"]), 0.001)
	assert_vector(preview.fill_node(0).scale).is_equal(ready_scale)
	slot.cooldown_remaining = 0.0
	await _frames(2)
	assert_float(preview.edge_color(0).a).is_equal_approx(ready_edge.a, 0.001)


func test_dimmed_helper() -> void:
	var c := CastPreview.dimmed(Color(1.0, 0.0, 0.0, 0.8), 0.5, 1.0)
	assert_float(c.a).is_equal_approx(0.4, 0.0001)
	assert_float(c.r).is_equal_approx(c.g, 0.0001)
	var same := CastPreview.dimmed(Color(0.2, 0.4, 0.6, 0.5), 1.0, 0.0)
	assert_bool(same.is_equal_approx(Color(0.2, 0.4, 0.6, 0.5))).is_true()


# --- player occlusion cue ----------------------------------------------------------------------

func test_occlusion_cue_is_attached_from_data_and_a_3d_object() -> void:
	var main := _main()
	await _frames(2)
	var cue := main.player.body_mesh.get_node_or_null("OcclusionCue") as PlayerOcclusionCue
	assert_object(cue).is_not_null()
	var config := UiConfig.player_outline()
	var color: Color = cue.shader_parameter(&"cue_color")
	assert_bool(color.is_equal_approx(Color(Color.html(String(config["color"])), float(config["alpha"])))).is_true()
	assert_float(cue.shader_parameter(&"depth_bias")).is_equal_approx(float(config["depth_bias"]), 0.0001)
	# Plain bool compare, not assert_object(cue.mesh): gdUnit's object assert keeps a reference to the
	# mesh, and freeing the Main afterwards made the renderer print 'Parameter "material" is null' x4.
	assert_bool(cue.mesh == main.player.body_mesh.mesh).is_true()
	# It lives in the 3D world, so it can never be drawn over a Control (the HUD).
	assert_bool(cue is Node3D).is_true()


func test_occlusion_cue_shader_only_draws_where_scene_depth_is_nearer() -> void:
	# The visibility rule lives in the shader (it cannot run headless), so pin its shape: it
	# compares against the depth texture and writes alpha through the "occluded" factor.
	var shader: Shader = load(PlayerOcclusionCue.SHADER_PATH)
	var code := shader.code
	assert_bool(code.contains("hint_depth_texture")).is_true()
	assert_bool(code.contains("depth_test_disabled")).is_true()
	assert_bool(code.contains("depth_draw_never")).is_true()
	assert_bool(code.contains("ALPHA = cue_color.a * occluded")).is_true()
	assert_bool(code.contains("step(depth_bias, scene_view.z - VERTEX.z)")).is_true()


func test_player_outline_config_validates_and_bad_values_are_rejected() -> void:
	var block := UiConfig.DEFAULT_PLAYER_OUTLINE.duplicate()
	assert_array(UiConfig.validate_player_outline(block)).is_empty()
	assert_array(UiConfig.validate_player_outline(UiConfig.player_outline())).is_empty()
	block["alpha"] = 2.0
	block["color"] = "nope"
	assert_array(UiConfig.validate_player_outline(block)).has_size(2)
