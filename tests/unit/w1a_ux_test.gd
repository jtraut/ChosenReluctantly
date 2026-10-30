class_name W1aUxTest
extends GdUnitTestSuite
## W1a ux half: the Wizard bolt's own look, the class pick screen (see ClassPickScreen).

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"
const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const PICK_PATH := "res://scenes/ui/ClassPickScreen.tscn"
const SIZES: Array[Vector2] = [Vector2(1024, 600), Vector2(1280, 720), Vector2(1920, 1080)]


func before_test() -> void:
	_reset_statics()


func after_test() -> void:
	GamePause.resume()
	for child in get_children():
		if child is Main:
			child.queue_free()  # a scene swap leaves the fresh Main behind as a child of this suite
	_reset_statics()
	Juice.reset()
	GamePause.reset()


func _reset_statics() -> void:
	RunSession.clear()
	RunSession.full_deck = false
	RunSession.debug_deck = {}
	RunSession.selected_character = ""
	RunSession.character_forced = false
	RunSession.forced_seed = -1
	CharacterPick.reset()
	CharacterPick.persist_override = false
	ClassPickScreen.reset()


func _frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().physics_frame


# ---- the Wizard bolt ----

func test_bolt_look_validation_rejects_a_bad_colour_and_a_bad_scale() -> void:
	var base: Dictionary = AttackDatabase.get_light("wizard").duplicate(true)
	assert_array(AttackDatabase.validate_entry(base)).is_empty()
	var bad_color: Dictionary = base.duplicate(true)
	bad_color["bolt_look"] = {"color": "not-a-color", "scale": 1.0}
	assert_bool(AttackDatabase.validate_entry(bad_color).is_empty()).is_false()
	var bad_scale: Dictionary = base.duplicate(true)
	bad_scale["bolt_look"] = {"color": "#3fd9ff", "scale": 0.0}
	assert_bool(AttackDatabase.validate_entry(bad_scale).is_empty()).is_false()
	var not_object: Dictionary = base.duplicate(true)
	not_object["bolt_look"] = "cyan"
	assert_bool(AttackDatabase.validate_entry(not_object).is_empty()).is_false()


func test_a_light_without_a_bolt_look_still_validates() -> void:
	var plain: Dictionary = AttackDatabase.get_light("wizard").duplicate(true)
	plain.erase("bolt_look")
	assert_array(AttackDatabase.validate_entry(plain)).is_empty()


func test_the_wizard_bolt_has_its_own_look_apart_from_the_card_bolt_and_enemy_shots() -> void:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	(main.get_node("Player") as Player).character_id = "wizard"
	add_child(main)
	auto_free(main)
	await _frames(2)
	main.player.camera = null
	main.player.rotation = Vector3.ZERO
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	enemy.position = main.player.global_position + Vector3(0.0, 0.0, -6.0)
	main.add_child(enemy)
	enemy.target = null
	await _frames(2)
	main.player.aim_point_override = enemy.global_position
	var bolt: Projectile = null
	for i in range(90):
		await get_tree().physics_frame
		for child in main.get_children():
			if child is Projectile:
				bolt = child
		if bolt != null:
			break
	assert_object(bolt).is_not_null()
	var color: Color = bolt._look["color"]
	var card_bolt: Color = ElementVisuals.visual_for_team("neutral", "player")["color"]
	var enemy_shot: Color = ElementVisuals.visual_for_team("neutral", "enemy")["color"]
	assert_bool(color.is_equal_approx(card_bolt)).is_false()
	assert_bool(color.is_equal_approx(enemy_shot)).is_false()
	assert_bool(color.is_equal_approx(ElementVisuals.color_for_damage_type("fire"))).is_false()


func test_the_look_param_replaces_the_element_look_and_an_empty_one_is_ignored() -> void:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	await _frames(2)
	var context := EffectContext.new(main.player, main, "player")
	var params: Dictionary = {"damage": 1.0, "damage_type": "neutral", "speed": 10.0, "max_range": 5.0, "hit_radius": 0.25, "look": {}}
	EffectTemplates.execute("projectile", params, context)
	var plain: Projectile = null
	for child in main.get_children():
		if child is Projectile:
			plain = child
	assert_object(plain).is_not_null()
	assert_bool((plain._look["color"] as Color).is_equal_approx(ElementVisuals.color_for_damage_type("neutral"))).is_true()
	plain.queue_free()
	params["look"] = {"color": Color(0.1, 0.9, 0.2), "scale": 1.5}
	EffectTemplates.execute("projectile", params, context)
	var tinted: Projectile = null
	for child in main.get_children():
		if child is Projectile and child != plain:
			tinted = child
	assert_object(tinted).is_not_null()
	assert_bool((tinted._look["color"] as Color).is_equal_approx(Color(0.1, 0.9, 0.2))).is_true()


# ---- the class pick screen ----

## Idle frames (a deferred call has run by then; a physics tick count does not promise that).
func _idle(count: int = 2) -> void:
	for i in range(count):
		await get_tree().process_frame


func _run_main() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _run_with_pick() -> Main:
	ClassPickScreen.enabled_override = true
	var main := _run_main()
	await _idle(3)
	return main


func _pick_of(main: Main) -> ClassPickScreen:
	return main.get_node("ClassPickScreen") as ClassPickScreen


func _other_main(old_id: int) -> Main:
	for child in get_children():
		if child is Main and child.get_instance_id() != old_id and not child.is_queued_for_deletion():
			return child as Main
	return null


## A standalone screen in a sized viewport (no run behind it), opened by hand.
func _standalone(size: Vector2) -> ClassPickScreen:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size)
	add_child(viewport)
	auto_free(viewport)
	var screen: ClassPickScreen = (load(PICK_PATH) as PackedScene).instantiate()
	viewport.add_child(screen)
	await _idle(2)
	screen.open()
	await _idle(4)
	return screen


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	return event


func test_it_does_not_open_headless_or_when_the_class_was_forced() -> void:
	# Headless (the suite): never opens, so no existing run test or sim can stall on it.
	var main := _run_main()
	await _idle(3)
	assert_bool(_pick_of(main).is_open()).is_false()
	assert_bool(GamePause.is_paused()).is_false()
	# A real game with a forced class (--class / --deck): skipped.
	ClassPickScreen.enabled_override = true
	RunSession.clear()
	RunSession.selected_character = "wizard"
	RunSession.character_forced = true
	var forced := _run_main()
	await _idle(3)
	assert_bool(_pick_of(forced).is_open()).is_false()
	assert_bool(GamePause.is_paused()).is_false()
	assert_str(forced.run_controller.character_id()).is_equal("wizard")


func test_a_real_game_opens_it_over_a_paused_room_with_the_last_pick_preselected() -> void:
	ClassPickScreen.enabled_override = true
	CharacterPick.remember("wizard")
	var main := _run_main()
	await _idle(3)
	var screen := _pick_of(main)
	assert_bool(screen.is_open()).is_true()
	assert_bool(GamePause.is_paused()).override_failure_message("the room must be held while the pick is open").is_true()
	assert_array(screen.character_ids()).is_equal(CharacterDatabase.ids())
	assert_str(screen.highlighted_id()).is_equal("wizard")
	assert_str(main.run_controller.character_id()).is_equal("wizard")  # the run already started as the preselection


func test_a_fresh_run_defaults_to_the_rogue() -> void:
	var main := await _run_with_pick()
	assert_str(_pick_of(main).highlighted_id()).is_equal(CharacterDatabase.DEFAULT_ID)


func test_it_shows_name_hp_swatch_description_and_the_attack_style_from_data() -> void:
	var screen := await _standalone(Vector2(1280, 720))
	var cfg: Dictionary = UiConfig.class_pick()
	for entry: Dictionary in CharacterDatabase.list():
		var card := screen.card_for(String(entry["id"]))
		assert_object(card).is_not_null()
		assert_str(card.name_label.text).is_equal(String(entry["display_name"]))
		assert_str(card.hp_label.text).is_equal(String(cfg["hp_format"]) % roundi(float(entry["max_hp"])))
		assert_str(card.description_label.text).is_equal(String(entry["description"]))
		var style: StyleBoxFlat = card.swatch.get_theme_stylebox("panel") as StyleBoxFlat
		assert_bool(style.bg_color.is_equal_approx(entry["body_color"])).is_true()
		var shape: String = String(AttackDatabase.get_light(CharacterDatabase.light_variant(String(entry["id"])))["shape"])
		assert_str(card.attack_label.text).contains(String((cfg["attack_styles"] as Dictionary)[shape]))
	assert_str(screen.card_for("rogue").attack_label.text).contains("Melee swing")
	assert_str(screen.card_for("wizard").attack_label.text).contains("Magic bolt at the reticle")


func test_keys_and_arrows_move_the_highlight_and_never_confirm() -> void:
	var screen := await _standalone(Vector2(1280, 720))
	screen.disarm()
	screen._input(_key(KEY_2))
	assert_str(screen.highlighted_id()).is_equal("wizard")
	screen._input(_key(KEY_1))
	assert_str(screen.highlighted_id()).is_equal("rogue")
	screen._input(_key(KEY_RIGHT))
	assert_str(screen.highlighted_id()).is_equal("wizard")
	screen._input(_key(KEY_RIGHT))
	assert_str(screen.highlighted_id()).override_failure_message("arrows wrap").is_equal("rogue")
	screen._input(_key(KEY_LEFT))
	assert_str(screen.highlighted_id()).is_equal("wizard")
	assert_bool(screen.is_open()).is_true()


func test_presses_are_ignored_until_the_arm_delay_has_passed() -> void:
	var main := await _run_with_pick()
	var screen := _pick_of(main)
	assert_bool(screen.options_armed()).is_false()
	screen.confirm()
	screen.card_for("rogue").pressed.emit()
	assert_bool(screen.is_open()).override_failure_message("an early press must do nothing").is_true()
	assert_bool(GamePause.is_paused()).is_true()
	await TestClock.wait_real(get_tree(), float(UiConfig.run_ui()["prompt_option_arm_delay"]) + 0.15)
	assert_bool(screen.options_armed()).is_true()
	screen.confirm()
	assert_bool(screen.is_open()).is_false()


func test_space_is_swallowed_and_never_confirms() -> void:
	var main := await _run_with_pick()
	var screen := _pick_of(main)
	screen.disarm()
	# The real input path: a focused Button would take Space as ui_accept if the screen let it through.
	Input.parse_input_event(_key(KEY_SPACE))
	await _idle(3)
	assert_bool(screen.is_open()).is_true()
	assert_bool(GamePause.is_paused()).is_true()
	assert_str(main.run_controller.character_id()).is_equal("rogue")


func test_confirming_the_same_class_closes_and_resumes() -> void:
	var main := await _run_with_pick()
	var screen := _pick_of(main)
	screen.disarm()
	var picked: Array[String] = []
	main.run_controller.class_picked.connect(func(id: String) -> void: picked.append(id))
	var run_before: RunState = RunSession.current
	screen.confirm()
	assert_bool(screen.is_open()).is_false()
	assert_bool(GamePause.is_paused()).is_false()
	assert_array(picked).is_equal(["rogue"])
	assert_object(RunSession.current).is_same(run_before)  # nothing restarted


func test_confirming_another_class_restarts_once_and_the_fresh_scene_does_not_ask_again() -> void:
	var main := await _run_with_pick()
	var screen := _pick_of(main)
	screen.disarm()
	var seed_value: int = RunSession.current.seed_value
	var old_id: int = main.get_instance_id()
	var opened_count: Array[int] = [0]
	screen.opened.connect(func() -> void: opened_count[0] += 1)
	screen.confirm("wizard")
	assert_bool(screen.is_open()).override_failure_message("stays up until the scene is replaced").is_true()
	await _idle(4)
	var fresh := _other_main(old_id)
	assert_object(fresh).is_not_null()
	assert_int(RunSession.current.seed_value).is_equal(seed_value)
	assert_str(RunSession.current.character_id).is_equal("wizard")
	assert_str((fresh.get_node("Player") as Player).character_id).is_equal("wizard")
	assert_bool(_pick_of(fresh).is_open()).override_failure_message("the screen must not flash twice").is_false()
	assert_bool(GamePause.is_paused()).is_false()
	assert_int(opened_count[0]).is_equal(0)
	assert_str(CharacterPick.last_pick()).is_equal("wizard")


func test_try_again_and_new_run_show_it_again() -> void:
	var main := await _run_with_pick()
	var screen := _pick_of(main)
	screen.disarm()
	screen.confirm()
	await _idle(2)
	assert_bool(screen.is_open()).is_false()
	var old_id: int = main.get_instance_id()
	main.restart_arena()  # what Try again and New run call: a new run in a fresh scene
	await _idle(4)
	var fresh := _other_main(old_id)
	assert_object(fresh).is_not_null()
	assert_bool(_pick_of(fresh).is_open()).is_true()
	assert_bool(GamePause.is_paused()).is_true()


func test_a_run_in_progress_never_asks() -> void:
	ClassPickScreen.enabled_override = true
	var state := RunSession.begin_new_run(5)
	state.record_room({"index": 0, "type": "combat", "wave_id": "x"}, 20.0, 10.0)
	assert_bool(ClassPickScreen.should_open(state)).is_false()
	assert_bool(ClassPickScreen.should_open(RunSession.begin_new_run(5))).is_true()


func test_the_endless_arena_never_gets_one() -> void:
	ClassPickScreen.enabled_override = true
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	main.run_mode = false  # the arena: the run nodes are removed
	add_child(main)
	auto_free(main)
	await _idle(3)
	assert_bool(GamePause.is_paused()).is_false()


func test_it_fits_without_scrolling_at_the_small_and_common_sizes() -> void:
	for size in SIZES:
		var screen := await _standalone(size)
		var label := "%dx%d" % [int(size.x), int(size.y)]
		var rect: Rect2 = screen.panel_screen_rect()
		assert_float(rect.position.x).override_failure_message("%s: left %s" % [label, rect]).is_greater_equal(-0.5)
		assert_float(rect.position.y).override_failure_message("%s: top %s" % [label, rect]).is_greater_equal(-0.5)
		assert_float(rect.end.x).override_failure_message("%s: right %s" % [label, rect]).is_less_equal(size.x + 0.5)
		assert_float(rect.end.y).override_failure_message("%s: bottom %s" % [label, rect]).is_less_equal(size.y + 0.5)
		assert_float(screen.fit_factor()).override_failure_message("%s: shrunk too far" % label).is_greater_equal(0.7)
		for card: ClassPickCard in screen._cards:
			assert_float(card.size.y).is_greater_equal(card.get_combined_minimum_size().y - 0.5)
		screen.close()


func test_the_class_pick_data_validates_and_bad_data_is_reported() -> void:
	assert_array(UiConfig.validate_class_pick(UiConfig.class_pick())).is_empty()
	var bad: Dictionary = UiConfig.class_pick().duplicate(true)
	bad["card_width"] = 0
	bad["start_format"] = "no placeholder"
	bad["attack_styles"] = {}
	assert_int(UiConfig.validate_class_pick(bad).size()).is_equal(3)
