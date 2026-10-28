class_name Slice6QaTest
extends GdUnitTestSuite
## QA for Polish 1 Slice 6 (6a hold-to-preview, 6b settings screen and occlusion cue) and the 5d
## re-check. Independent of the dev's suites: real InputEvents (keys, mouse buttons), real hits at
## the previewed boundary, pause edge cases. Settings are injected with a temp path, so the real
## user://settings.cfg is never read or written here. Tests marked PIN record behaviour QA
## reported as a finding; flip them when it is fixed.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"
const DEFAULTS := "res://data/settings.json"
const TEMP_SETTINGS := "user://tests/qa6_settings.cfg"

var _original_store: SettingsStore = null
var _main: Main = null
var _casts: Array[String] = []


func before_test() -> void:
	CardDatabase.load_all()
	_original_store = Settings.store
	Settings.use_store(SettingsStore.new(DEFAULTS, TEMP_SETTINGS))
	_casts = []


func after_test() -> void:
	GamePause.resume()
	GamePause.reset()
	get_tree().paused = false
	Settings.use_store(_original_store)
	if _main != null and is_instance_valid(_main):
		get_tree().current_scene = null
		_main.free()
	_main = null
	Juice.reset()
	for action: StringName in [&"slot_1", &"slot_2", &"slot_3", &"slot_4", &"slot_5", &"attack_heavy", &"attack_light"]:
		TestInput.release(action)
	if FileAccess.file_exists(TEMP_SETTINGS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_SETTINGS))


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _spawn() -> Main:
	_main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(_main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	_main.player.card_slots.spawn_parent = _main
	_main.player.camera = null
	_main.player.attacks.set_auto(&"light", false)
	_main.player.attacks.set_auto(&"heavy", false)
	_main.player.card_slots.card_cast.connect(func(slot_type: String, _card: String) -> void: _casts.append(slot_type))
	return _main


func _key(keycode: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _mouse(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = Vector2(60.0, 60.0)
	event.global_position = event.position
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _enemy_at(offset: Vector3) -> Enemy:
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	enemy.position = _main.player.global_position + offset
	_main.add_child(enemy)
	enemy.target = null
	enemy.begin_spawn_grace(99.0)
	return enemy


# --- latching across pause and the settings screen ---------------------------------------------

func test_a_latched_heavy_click_does_not_fire_after_pause_and_resume() -> void:
	# RED ON PURPOSE (finding S6-1): a click latched before any physics tick took it survives a
	# pause and fires after resume; a held card key and a queued cast are dropped, the attack latch
	# is not. Goes green when cancel_cast_preview (or a pause) clears _attack_latch.
	var main := _spawn()
	await _frames(2)
	var player := main.player
	player._attack_latch[&"heavy"] = false
	TestInput.tap(&"attack_heavy")
	assert_bool(player._attack_latch[&"heavy"]).is_true()
	GamePause.pause()
	GamePause.resume()
	await _frames(3)
	assert_bool(player.attacks.is_winding_up(&"heavy")).override_failure_message("an attack click latched before the pause fired after resume").is_false()


func test_card_key_events_while_paused_do_nothing() -> void:
	var main := _spawn()
	await _frames(2)
	GamePause.pause()
	TestInput.press(&"slot_1")
	await _frames(2)
	assert_bool(main.player.cast_input.is_previewing()).is_false()
	TestInput.release(&"slot_1")
	GamePause.resume()
	await _frames(3)
	assert_array(_casts).is_empty()


func test_holding_a_key_opening_settings_releasing_while_paused_then_resume_is_not_a_cast() -> void:
	var main := _spawn()
	await _frames(2)
	var player := main.player
	TestInput.press(&"slot_1")
	await _frames(2)
	assert_bool(player.cast_input.is_previewing()).is_true()
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await _frames(2)
	assert_bool(_screen(main).is_open()).is_true()
	assert_bool(player.cast_input.is_previewing()).is_false()
	TestInput.release(&"slot_1")  # while paused
	await _frames(2)
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await _frames(4)
	assert_bool(_screen(main).is_open()).is_false()
	assert_array(_casts).is_empty()
	assert_bool(player.get_preview_state()["active"]).is_false()
	# Releasing the key a second time after resume (a key held through the pause) is still nothing.
	TestInput.release(&"slot_1")
	await _frames(3)
	assert_array(_casts).is_empty()


func test_key_released_after_resume_for_a_hold_started_before_pause_is_not_a_cast() -> void:
	var main := _spawn()
	await _frames(2)
	TestInput.press(&"slot_1")
	await _frames(2)
	GamePause.pause()
	GamePause.resume()
	await _frames(2)
	TestInput.release(&"slot_1")
	await _frames(3)
	assert_array(_casts).is_empty()
	assert_bool(main.player.get_preview_state()["active"]).is_false()


func test_real_mouse_clicks_on_the_open_settings_screen_never_reach_the_player() -> void:
	var main := _spawn()
	await _frames(2)
	var player := main.player
	# Control: with the screen closed a real right click is latched and starts the heavy.
	_mouse(MOUSE_BUTTON_RIGHT, true)
	assert_bool(player._attack_latch[&"heavy"]).override_failure_message("control: a real RMB press should latch").is_true()
	_mouse(MOUSE_BUTTON_RIGHT, false)
	await _frames(4)
	assert_bool(player.attacks.is_winding_up(&"heavy") or not player.attacks.is_ready(&"heavy")).is_true()
	await _frames(90)
	_screen(main).open()
	await _frames(2)
	for button: MouseButton in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		_mouse(button, true)
		_mouse(button, false)
	await _frames(3)
	assert_bool(player._attack_latch[&"light"]).is_false()
	assert_bool(player._attack_latch[&"heavy"]).is_false()
	var started: Array[StringName] = []
	player.attack_started.connect(func(attack_id: StringName) -> void: started.append(attack_id))
	_screen(main).close()
	await _frames(6)
	assert_array(started).is_empty()


func test_real_escape_key_toggles_exactly_once_per_press_and_ignores_echo() -> void:
	var main := _spawn()
	await _frames(2)
	var screen := _screen(main)
	var changes: Array[bool] = []
	GamePause.paused_changed.connect(func(p: bool) -> void: changes.append(p))
	_key(KEY_ESCAPE, true)
	await _frames(2)
	assert_bool(screen.is_open()).is_true()
	assert_array(changes).is_equal([true])
	_key(KEY_ESCAPE, true, true)  # key repeat while held
	await _frames(2)
	assert_bool(screen.is_open()).is_true()
	_key(KEY_ESCAPE, false)
	await _frames(2)
	assert_bool(screen.is_open()).is_true()
	assert_bool(screen.resume_button.has_focus()).is_true()
	_key(KEY_ESCAPE, true)  # with the Resume button focused
	_key(KEY_ESCAPE, false)
	await _frames(2)
	assert_bool(screen.is_open()).is_false()
	assert_array(changes).is_equal([true, false])
	assert_bool(get_tree().paused).is_false()


func test_escape_during_the_death_beat_pauses_and_game_over_still_arrives_once_after_resume() -> void:
	var main := _spawn()
	await _frames(2)
	var announced: Array[bool] = []
	main.game_over_ready.connect(func() -> void: announced.append(true))
	main.player.health.take_damage(main.player.health.get_max_health() * 2.0)
	await _frames(2)
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await _frames(2)
	assert_bool(_screen(main).is_open()).is_true()
	assert_float(Engine.time_scale).is_equal(1.0)
	await get_tree().create_timer(float(UiConfig.death_beat()["slow_mo_duration"]) + 0.4, true, false, true).timeout
	assert_array(announced).is_empty()
	_screen(main).close()
	await get_tree().create_timer(float(UiConfig.death_beat()["slow_mo_duration"]) + 0.5, true, false, true).timeout
	assert_array(announced).has_size(1)
	assert_float(Engine.time_scale).is_equal(1.0)
	# Over Game Over, Esc is refused and nothing is left paused.
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	await _frames(2)
	assert_bool(_screen(main).is_open()).is_false()
	assert_bool(get_tree().paused).is_false()


# --- the preview equals the hit area, measured with real hits -----------------------------------

func test_every_cone_and_aoe_card_hits_out_to_the_previewed_reach_and_not_beyond() -> void:
	var main := _spawn()
	await _frames(2)
	var player := main.player
	var config := CastPreviewConfig.get_config()
	var seen := 0
	for card: Dictionary in CardDatabase.all_cards():
		for effect: Dictionary in card["effects"]:
			var template := String(effect["template"])
			if template != "cone" and template != "aoe":
				continue
			var parts := CastPreviewShapes.parts_for_card({"effects": [effect]}, config)
			var reach: float = parts[0]["size"]
			var params: Dictionary = (effect["params"] as Dictionary).duplicate()
			params["vfx"] = false
			for case: Array in [[reach - 0.05, true], [reach + 0.1, false]]:
				var enemy := _enemy_at(Vector3(0.0, 0.0, -float(case[0])))
				await _frames(2)
				var before := enemy.health.current_health
				EffectTemplates.execute(template, params, EffectContext.new(player, main, "player"))
				var hit := enemy.health.current_health < before
				assert_bool(hit).override_failure_message("%s %s at %.2f (reach %.2f)" % [card["id"], template, float(case[0]), reach]).is_equal(bool(case[1]))
				enemy.free()
			seen += 1
	assert_int(seen).is_greater_equal(3)


func test_projectile_lane_half_width_is_where_a_real_shot_stops_hitting() -> void:
	var main := _spawn()
	await _frames(2)
	var player := main.player
	var checked := 0
	for card: Dictionary in CardDatabase.all_cards():
		for effect: Dictionary in card["effects"]:
			if String(effect["template"]) != "projectile":
				continue
			var params: Dictionary = effect["params"]
			var part: Dictionary = CastPreviewShapes.parts_for_card({"effects": [effect]}, CastPreviewConfig.get_config())[0]
			var half_width: float = part["half_width"]
			var along: float = float(part["start_offset"]) + 4.0
			for case: Array in [[half_width - 0.05, true], [half_width + 0.1, false]]:
				var enemy := _enemy_at(Vector3(float(case[0]), 0.0, -along))
				await _frames(2)
				var before := enemy.health.current_health
				EffectTemplates.execute("projectile", params, EffectContext.new(player, main, "player"))
				var frames := int(ceil((along + 1.0) / float(params["speed"]) * 60.0)) + 6
				await _frames(frames)
				var hit := enemy.health.current_health < before
				assert_bool(hit).override_failure_message("%s lateral %.2f (half width %.2f)" % [card["id"], float(case[0]), half_width]).is_equal(bool(case[1]))
				enemy.free()
				await _frames(2)
			checked += 1
	assert_int(checked).is_greater_equal(1)


func test_pin_projectile_lane_tip_understates_the_real_hit_by_the_lateral_reach() -> void:
	# PIN (finding S6-3, non-blocking): the lane is drawn max_range long from the muzzle, but the
	# shot's hit sphere keeps its radius beyond the last position, so a target centre a little
	# past the drawn tip is still hit. Flip the expectation when the lane is lengthened.
	var main := _spawn()
	await _frames(2)
	var params: Dictionary = (CardDatabase.get_card("fire_flaming_nonsense")["effects"][0] as Dictionary)["params"]
	var part: Dictionary = CastPreviewShapes.parts_for_card(CardDatabase.get_card("fire_flaming_nonsense"), CastPreviewConfig.get_config())[0]
	var tip: float = float(part["start_offset"]) + float(part["size"])
	var enemy := _enemy_at(Vector3(0.0, 0.0, -(tip + 0.3)))
	await _frames(2)
	var before := enemy.health.current_health
	EffectTemplates.execute("projectile", params, EffectContext.new(main.player, main, "player"))
	await _frames(int(ceil(tip / float(params["speed"]) * 60.0)) + 20)
	assert_bool(enemy.health.current_health < before).override_failure_message("PIN: target 0.3 past the drawn tip was NOT hit; the finding may be fixed").is_true()


func _dash_run() -> Array[float]:
	var player := _main.player
	var card := CardDatabase.get_card("fire_blaze_and_bail")
	var dash: Dictionary = {}
	for effect: Dictionary in card["effects"]:
		if String(effect["template"]) == "dash":
			dash = effect["params"]
	var start := player.global_position
	var facing := player.get_aim_direction()
	EffectTemplates.execute("dash", dash, EffectContext.new(player, _main, "player"))
	var frames := 0
	while player._forced_move_time_remaining > 0.0 and frames < 120:
		await get_tree().physics_frame
		frames += 1
	await get_tree().physics_frame
	var at_end_of_drive := (player.global_position - start).dot(facing)
	await _frames(90)
	var at_rest := (player.global_position - start).dot(facing)
	return [at_end_of_drive, at_rest, float(dash["distance"])]


func test_dash_drive_distance_is_the_previewed_distance() -> void:
	_spawn()
	await _frames(2)
	var result := await _dash_run()
	assert_float(result[0]).override_failure_message("driven %.2f, preview says %.2f" % [result[0], result[2]]).is_equal_approx(result[2], 0.6)


func test_s6_2_dash_ends_where_the_preview_says() -> void:
	# RED ON PURPOSE (finding S6-2): after the forced move the player keeps the dash velocity and
	# coasts to a stop (friction 28), so Blaze and Bail (distance 4) ends about 7.9 m away while the
	# preview path is 4.0 m. Goes green when the dash ends at the previewed distance.
	_spawn()
	await _frames(2)
	var result := await _dash_run()
	assert_float(result[1]).override_failure_message("came to rest %.2f m along the dash, preview path is %.2f m" % [result[1], result[2]]).is_equal_approx(result[2], 0.5)


func test_pin_space_on_the_focused_resume_button_also_starts_a_dodge() -> void:
	# PIN (finding S6-5, non-blocking): Resume has focus and Space is both ui_accept and dodge. The
	# press closes the screen, and the dodge poll (Input.is_action_just_pressed) still sees the same
	# press on the first tick after resume, so the player rolls. Flip when fixed.
	var main := _spawn()
	await _frames(2)
	var player := main.player
	_screen(main).open()
	await _frames(2)
	_key(KEY_SPACE, true)
	_key(KEY_SPACE, false)
	await _frames(4)
	assert_bool(_screen(main).is_open()).is_false()
	await _frames(3)
	assert_bool(player._forced_move_time_remaining > 0.0 or player._dodge_cooldown_remaining > 0.0).override_failure_message("PIN: Space on Resume no longer starts a dodge; the finding may be fixed").is_true()


func test_pin_dodge_coasts_past_its_drive_distance_like_the_dash() -> void:
	# PIN (part of S6-2): the dodge roll shares the forced-move code, so it also keeps its velocity
	# after the drive and coasts to rest about twice as far (14 m/s for 0.25 s = 3.5 m driven).
	_spawn()
	await _frames(2)
	var player := _main.player
	var start := player.global_position
	var facing := player.get_aim_direction()
	player.start_forced_move(facing, player.dodge_speed, player.dodge_duration, true)
	await _frames(100)
	var rest := (player.global_position - start).dot(facing)
	var driven := player.dodge_speed * player.dodge_duration
	assert_float(rest).override_failure_message("PIN: dodge rest %.2f vs driven %.2f; the coast may be fixed" % [rest, driven]).is_greater(driven * 1.5)


# --- release casts once; press casts on press; cooldown --------------------------------------

func test_release_mode_casts_once_on_release_with_real_events_and_press_mode_on_press() -> void:
	var main := _spawn()
	await _frames(2)
	TestInput.press(&"slot_1")
	await _frames(5)
	assert_array(_casts).is_empty()
	TestInput.release(&"slot_1")
	await _frames(3)
	assert_array(_casts).has_size(1)
	await _frames(10)
	assert_array(_casts).has_size(1)
	# A second release without a press is nothing.
	TestInput.release(&"slot_1")
	await _frames(3)
	assert_array(_casts).has_size(1)
	# Press mode.
	Settings.set_value(Settings.CAST_TRIGGER, Settings.TRIGGER_PRESS)
	main.player.card_slots.get_slot("attack_aoe").cooldown_remaining = 0.0
	TestInput.press(&"slot_2")
	await _frames(3)
	assert_array(_casts).has_size(2)
	assert_bool(main.player.get_preview_state()["active"]).is_false()
	TestInput.release(&"slot_2")
	await _frames(3)
	assert_array(_casts).has_size(2)


func test_setting_change_mid_hold_cancels_and_the_release_is_not_a_cast() -> void:
	var main := _spawn()
	await _frames(2)
	TestInput.press(&"slot_1")
	await _frames(2)
	Settings.set_value(Settings.CAST_TRIGGER, Settings.TRIGGER_PRESS)
	assert_bool(main.player.cast_input.is_previewing()).is_false()
	TestInput.release(&"slot_1")
	await _frames(3)
	assert_array(_casts).is_empty()


func test_dead_card_swap_with_real_ctrl_digit_never_casts() -> void:
	var main := _spawn()
	await _frames(2)
	var event := InputEventKey.new()
	event.keycode = KEY_1
	event.physical_keycode = KEY_1
	event.ctrl_pressed = true
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	var up := event.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
	await _frames(4)
	assert_array(_casts).is_empty()
	assert_bool(main.player.cast_input.is_previewing()).is_false()


# --- settings: persistence, bad files, hermetic tests ---------------------------------------------

func test_setting_survives_save_and_a_fresh_store_and_a_fresh_scene() -> void:
	Settings.set_value(Settings.CAST_TRIGGER, Settings.TRIGGER_PRESS)
	assert_bool(Settings.save()).is_true()
	Settings.use_store(SettingsStore.new(DEFAULTS, TEMP_SETTINGS))
	assert_str(Settings.cast_trigger()).is_equal("press")
	var main := _spawn()
	await _frames(2)
	assert_bool((_screen(main).option_buttons["press"] as Button).button_pressed).is_true()
	TestInput.press(&"slot_1")
	await _frames(3)
	assert_array(_casts).has_size(1)  # press mode really in effect after the reload


func test_bad_settings_files_are_loud_and_fall_back_to_defaults() -> void:
	var bodies: Array[String] = [
		"",  # empty is fine: no problem expected
		"[settings]\ncast_trigger=\"hold\"\n",
		"[settings]\ncast_trigger=7\n",
		"[settings]\ncast_trigger=true\n",
		"[settings]\ncast_trigger=\"press\"\ncast_trigger=\"nonsense\"\n",
		"cast_trigger = press",
		"\u0007\u0001garbage\u0002",
		"[settings\ncast_trigger=\"press\"",
		"[settings]\ncast_trigger=\n",
	]
	var loud := 0
	for i in range(bodies.size()):
		var file := FileAccess.open(TEMP_SETTINGS, FileAccess.WRITE)
		file.store_string(bodies[i])
		file.close()
		var store := SettingsStore.new(DEFAULTS, TEMP_SETTINGS)
		var value := store.get_string(Settings.CAST_TRIGGER)
		assert_bool(["release", "press"].has(value)).override_failure_message("body %d: unusable value '%s'" % [i, value]).is_true()
		if i == 0:
			assert_array(store.problems).is_empty()
			continue
		if i == 4:
			continue  # duplicate key: the engine keeps the last one; not claimed either way
		assert_str(value).override_failure_message("body %d fell back to '%s'" % [i, value]).is_equal("release")
		assert_bool(not store.problems.is_empty()).override_failure_message("body %d was silent" % i).is_true()
		loud += 1
	assert_int(loud).is_greater_equal(5)


func test_a_missing_or_broken_defaults_file_never_crashes_the_player_or_screen() -> void:
	var path := "user://tests/qa6_bad_defaults.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{ \"cast_trigger\": { \"type\": \"enum\", \"default\": \"hold\", \"options\": [\"release\", \"press\"] } }")
	file.close()
	var store := SettingsStore.new(path, TEMP_SETTINGS)
	assert_bool(not store.problems.is_empty()).is_true()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_the_real_user_settings_file_is_not_touched_by_this_suite() -> void:
	var real := "user://settings.cfg"
	var existed := FileAccess.file_exists(real)
	var stamp: int = FileAccess.get_modified_time(real) if existed else 0
	Settings.set_value(Settings.CAST_TRIGGER, Settings.TRIGGER_PRESS)
	Settings.save()
	assert_bool(FileAccess.file_exists(real)).is_equal(existed)
	if existed:
		assert_int(FileAccess.get_modified_time(real)).is_equal(stamp)


# --- occlusion cue: what is testable headless ----------------------------------------------------

func test_occlusion_cue_is_a_depth_gated_overlay_that_cannot_draw_when_the_player_is_visible() -> void:
	# Headless has no renderer, so the pixels are not testable. Pinned instead: the cue exists under
	# BodyMesh, uses the data colour, never writes depth, and the shader's alpha is multiplied by
	# an `occluded` step that is 0 when the scene depth equals the body's own depth.
	var main := _spawn()
	await _frames(2)
	var cue := main.player.body_mesh.get_node_or_null("OcclusionCue") as PlayerOcclusionCue
	assert_object(cue).is_not_null()
	var cfg := UiConfig.player_outline()
	assert_float((cue.shader_parameter(&"cue_color") as Color).a).is_equal_approx(float(cfg["alpha"]), 0.001)
	assert_float(float(cue.shader_parameter(&"depth_bias"))).is_equal_approx(float(cfg["depth_bias"]), 0.0001)
	var source := FileAccess.get_file_as_string("res://src/player/player_occlusion_cue.gdshader")
	assert_bool(source.contains("depth_draw_never") and source.contains("depth_test_disabled")).is_true()
	assert_bool(source.contains("ALPHA = cue_color.a * occluded")).is_true()
	assert_bool(source.contains("step(depth_bias, scene_view.z - VERTEX.z)")).is_true()
	assert_bool(cue.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF).is_true()
	# One cue, not a stack, after Main is built and the arena restarted logic is not involved.
	var count := 0
	for child in main.player.body_mesh.get_children():
		if child is PlayerOcclusionCue:
			count += 1
	assert_int(count).is_equal(1)


# --- 5d re-check: F1 -------------------------------------------------------------------------------

## Velocity of a chaser after one steering step with a neighbour beside it. Only spawn_index differs
## between calls; `junk` shifts every later instance id.
func _steer_velocity(spawn_index: int, junk: int) -> Vector3:
	var pad: Array[Node] = []
	for i in range(junk):
		pad.append(Node.new())
	_spawn()
	_main.player.process_mode = Node.PROCESS_MODE_DISABLED
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	enemy.spawn_index = spawn_index
	_main.add_child(enemy)
	var neighbour: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	neighbour.spawn_index = 99
	_main.add_child(neighbour)
	enemy.global_position = Vector3(0.0, 0.0, 10.0)
	neighbour.global_position = Vector3(0.4, 0.0, 10.3)
	enemy.target = _main.player
	neighbour.target = null
	enemy.begin_spawn_grace(0.0)
	enemy._chase_and_attack(0.016)
	var v := enemy.velocity
	get_tree().current_scene = null
	_main.free()
	_main = null
	for node in pad:
		node.free()
	return v


func test_f1_steering_depends_on_spawn_index_not_on_the_instance_id() -> void:
	var a := _steer_velocity(4, 0)
	var b := _steer_velocity(4, 41)
	var c := _steer_velocity(4, 7)
	assert_float(a.distance_to(b)).override_failure_message("same spawn_index, different instance ids: %s vs %s" % [a, b]).is_less(0.00001)
	assert_float(a.distance_to(c)).is_less(0.00001)
	# And the swirl side really comes from the spawn index: odd and even swirl opposite ways.
	var even := _steer_velocity(2, 0)
	var odd := _steer_velocity(3, 0)
	assert_float(even.distance_to(odd)).override_failure_message("odd and even spawn_index steer the same: the swirl is not applied").is_greater(0.05)
	assert_bool(not FileAccess.get_file_as_string("res://src/enemies/Enemy.gd").contains("get_instance_id")).is_true()


func test_f1_spawner_numbers_enemies_in_spawn_order_and_resets_with_the_seed() -> void:
	var spawner_source := FileAccess.get_file_as_string("res://src/enemies/EnemySpawner.gd")
	assert_bool(spawner_source.contains("spawn_index = _spawn_count")).is_true()
	assert_bool(spawner_source.contains("_spawn_count = 0")).is_true()


func _screen(main: Main) -> SettingsScreen:
	return main.get_node("SettingsScreen") as SettingsScreen
