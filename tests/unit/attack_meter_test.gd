class_name AttackMeterTest
extends GdUnitTestSuite
## Slice 3 UI: attack meters (light/heavy), slot ready/cooling visual state,
## mouse pass-through, and layout inside the safe area.

const RESOLUTIONS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]
const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"


func after_test() -> void:
	Juice.reset()
	TestInput.release(&"attack_heavy")


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	return main


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func test_fill_fraction_and_state_are_pure_and_clamped() -> void:
	assert_float(AttackMeter.fill_fraction(-1.0)).is_equal(0.0)
	assert_float(AttackMeter.fill_fraction(0.4)).is_equal(0.4)
	assert_float(AttackMeter.fill_fraction(7.0)).is_equal(1.0)
	assert_str(String(AttackMeter.state_for(true, false))).is_equal("ready")
	assert_str(String(AttackMeter.state_for(false, false))).is_equal("cooling")
	assert_str(String(AttackMeter.state_for(false, true))).is_equal("windup")


func test_slot_cooldown_progress_math() -> void:
	assert_float(CardSlotWidget.cooldown_progress(0.0, 2.0)).is_equal(1.0)
	assert_float(CardSlotWidget.cooldown_progress(1.0, 2.0)).is_equal_approx(0.5, 0.0001)
	assert_float(CardSlotWidget.cooldown_progress(2.0, 2.0)).is_equal(0.0)
	assert_float(CardSlotWidget.cooldown_progress(1.0, 0.0)).is_equal(1.0)


func test_meters_track_player_and_heavy_ready_state() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	await get_tree().process_frame
	var player := main.player
	player.camera = null
	var heavy := main.hud.heavy_meter
	var light := main.hud.light_meter
	assert_str(String(heavy.state())).is_equal("ready")
	assert_float(heavy.progress_value()).is_equal(1.0)
	TestInput.press(&"attack_heavy")
	await _frames(2)
	TestInput.release(&"attack_heavy")
	await get_tree().process_frame
	assert_str(String(heavy.state())).is_equal("windup")
	assert_float(heavy.progress_value()).is_equal_approx(player.get_attack_progress(&"heavy"), 0.05)
	assert_float(heavy.progress_value()).is_less(1.0)
	# Wait for the cooldown to end: heavy is ready again and pulses once.
	var deadline := Time.get_ticks_msec() + 4000
	while not player.is_attack_ready(&"heavy") and Time.get_ticks_msec() < deadline:
		await _frames(1)
	await get_tree().process_frame
	assert_str(String(heavy.state())).is_equal("ready")
	assert_float(heavy.pulse_value()).is_greater(0.0)
	assert_float(light.pulse_value()).is_equal(0.0)


func test_slot_widget_ready_vs_cooling_state() -> void:
	var widget: CardSlotWidget = (load("res://scenes/ui/CardSlotWidget.tscn") as PackedScene).instantiate()
	add_child(widget)
	auto_free(widget)
	await get_tree().process_frame
	var cfg := UiConfig.hud()
	var slot := CardSlot.new("attack_single", 1.0, ["quick_slash", "quick_slash"] as Array[String])
	widget.update_from_slot(slot)
	assert_bool(widget.is_ready_state()).is_true()
	assert_float(widget.modulate.r).is_equal(1.0)
	assert_float(widget.cooldown_bar.value).is_equal(1.0)
	slot.use_card(0.0)
	widget.update_from_slot(slot)
	assert_bool(widget.is_ready_state()).is_false()
	assert_float(widget.modulate.r).is_equal_approx(float(cfg["slot_cooling_dim"]), 0.001)
	assert_float(widget.cooldown_bar.value).is_less(1.0)
	slot.advance(1000.0)
	widget.update_from_slot(slot)
	assert_bool(widget.is_ready_state()).is_true()


func test_new_hud_controls_ignore_mouse() -> void:
	var sub := SubViewport.new()
	sub.size = Vector2i(1280, 720)
	sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(sub)
	auto_free(sub)
	var hud: Hud = (load("res://scenes/ui/Hud.tscn") as PackedScene).instantiate()
	sub.add_child(hud)
	await get_tree().process_frame
	var checked := 0
	var stack: Array[Node] = [hud]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Control:
			checked += 1
			assert_int((n as Control).mouse_filter).override_failure_message("%s blocks mouse" % n.get_path()).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(checked).is_greater(10)


func test_meters_inside_safe_area_and_clear_of_other_hud() -> void:
	var cfg := UiConfig.hud()
	for vp in RESOLUTIONS:
		var safe := HudLayout.safe_area(vp, cfg)
		var rects := HudLayout.attack_meter_rects(vp, cfg)
		var hp := HudLayout.health_rect(vp, cfg)
		var bar := HudLayout.slot_bar_rect(vp, cfg, 5)
		var light: Rect2 = rects[&"light"]
		var heavy: Rect2 = rects[&"heavy"]
		for r in [light, heavy]:
			assert_bool(safe.encloses(r)).override_failure_message("meter %s outside %s at %s" % [r, safe, vp]).is_true()
			assert_bool((r as Rect2).intersects(hp)).is_false()
			assert_bool((r as Rect2).intersects(bar)).is_false()
		assert_bool(light.intersects(heavy)).is_false()
		# Keeps the centre of the screen clear: left third only, top quarter.
		assert_float(heavy.end.x).is_less(vp.x * 0.33)
		assert_float(heavy.end.y).is_less(vp.y * 0.3)


func test_real_hud_meters_inside_safe_area_at_all_resolutions() -> void:
	var cfg := UiConfig.hud()
	for vp in RESOLUTIONS:
		var sub := SubViewport.new()
		sub.size = Vector2i(vp)
		sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(sub)
		auto_free(sub)
		var hud: Hud = (load("res://scenes/ui/Hud.tscn") as PackedScene).instantiate()
		sub.add_child(hud)
		await get_tree().process_frame
		await get_tree().process_frame
		var safe := HudLayout.safe_area(vp, cfg).grow(0.5)
		for m: AttackMeter in [hud.light_meter, hud.heavy_meter]:
			var rect := m.get_global_rect()
			assert_bool(safe.encloses(rect)).override_failure_message("%s %s outside %s at %s" % [m.name, rect, safe, vp]).is_true()
		var font := ThemeDB.fallback_font
		var label_px := roundi(float(cfg["meter_font_size"]) * HudLayout.ui_scale(vp, cfg))
		assert_float(font.get_height(label_px)).is_less_equal(hud.heavy_meter.size.y + 1.0)
		assert_float(font.get_string_size("READY", HORIZONTAL_ALIGNMENT_LEFT, -1.0, label_px).x).is_less(hud.heavy_meter.size.x - float(cfg["meter_label_width"]) * HudLayout.ui_scale(vp, cfg))
		hud.queue_free()
		sub.queue_free()


func test_preview_min_font_is_ten() -> void:
	assert_int(int(UiConfig.hud()["preview_min_font_size"])).is_equal(10)
