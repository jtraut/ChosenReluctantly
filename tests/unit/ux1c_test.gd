class_name Ux1cTest
extends GdUnitTestSuite
## UX1c display polish: the Performance Review "Now: +N max HP" readout, the player's hit flash colour, the crowd layout of enemy HP bars,
## and the card strip's more opaque backing.

const FOOT := Vector2(1.6, 0.3)


# --- Performance Review readout ---

func _ctx() -> Dictionary:
	return RunChoices.shipped_context(["neutral", "rogue"] as Array[String])


func test_the_readout_shows_what_the_relic_has_given_so_far() -> void:
	var ctx: Dictionary = _ctx()
	var state := RunState.new()
	state.relics = ["performance_review"] as Array[String]
	for gained: int in [1, 2, 7]:
		state.relic_max_hp["performance_review"] = float(gained)
		var shown: Dictionary = RunRelics.owned_display(state, ctx)[0]
		assert_str(String(shown["now"])).is_equal("Now: +%d max HP" % gained)


func test_the_readout_is_empty_before_the_relic_has_given_anything() -> void:
	var state := RunState.new()
	state.relics = ["performance_review"] as Array[String]
	assert_str(String(RunRelics.owned_display(state, _ctx())[0]["now"])).is_empty()


func test_the_readout_reads_the_run_record_and_the_text_is_data() -> void:
	var ctx: Dictionary = _ctx()
	var state := RunState.new()
	state.relics = ["performance_review"] as Array[String]
	state.relic_max_hp["performance_review"] = 3.0
	assert_str(RunRelics.max_hp_text(state, "performance_review", ctx)).is_equal("Now: +3 max HP")
	assert_str(RunRelics.max_hp_text(state, "heavy_sigh", ctx)).is_empty()  # a relic with no boost record
	var bare: Dictionary = {"relics": {"ui": {"now_format": "Now: %s"}}}  # the format string missing from data: no readout rather than a broken one
	assert_str(RunRelics.max_hp_text(state, "performance_review", bare)).is_empty()


func test_the_readout_follows_the_real_clear_that_gave_the_hp() -> void:
	var state := RunState.new()
	state.relics = ["performance_review"] as Array[String]
	state.max_hp = 30.0
	state.hp = 30.0
	RunMaxHp.on_room_cleared(state, "elite")
	RunMaxHp.on_room_cleared(state, "combat")  # not an elite: nothing
	assert_str(String(RunRelics.owned_display(state, _ctx())[0]["now"])).is_equal("Now: +1 max HP")
	assert_float(state.max_hp).is_equal(31.0)


# --- Hit flash colour ---

func test_the_hit_flash_is_not_a_red_or_pink_enemy_colour_and_keeps_its_timing() -> void:
	var flash: Color = Player.HIT_FLASH_COLOR
	for enemy_color: Color in [Color.html("#ff3d8b"), Color.html("#e2483f"), Color.html("#e0123f"), Color.html("#ff6a1f"), Color(1.0, 0.3, 0.3), Enemy.HIT_FLASH_COLOR]:
		var hue_gap: float = absf(flash.h - enemy_color.h)
		hue_gap = minf(hue_gap, 1.0 - hue_gap)
		assert_bool(hue_gap > 0.15 or enemy_color.s < 0.2).override_failure_message("flash too near %s" % enemy_color.to_html()).is_true()
	assert_float(Player.HIT_FLASH_DURATION).is_equal(0.15)  # colour only: the timing did not move


# --- HP bar crowd layout ---

func test_a_lone_bar_and_far_apart_bars_are_not_lifted() -> void:
	assert_array(HpBarLayout.stack_offsets([Vector2(0, 0)] as Array[Vector2], FOOT, 0.04, 5)).is_equal([0.0])
	var apart: Array[Vector2] = [Vector2(0, 0), Vector2(5, 0), Vector2(0, 3)]
	assert_array(HpBarLayout.stack_offsets(apart, FOOT, 0.04, 5)).is_equal([0.0, 0.0, 0.0])


func test_bars_on_the_same_spot_stack_in_clear_rows() -> void:
	var anchors: Array[Vector2] = []
	for i in range(7):
		anchors.append(Vector2(0.1 * float(i % 3), 0.05 * float(i)))
	var offsets: Array[float] = HpBarLayout.stack_offsets(anchors, FOOT, 0.04, 8)
	var rects: Array[Rect2] = []
	for i in range(anchors.size()):
		assert_float(offsets[i]).is_greater_equal(0.0)
		rects.append(Rect2(Vector2(anchors[i].x - FOOT.x * 0.5, anchors[i].y + offsets[i]), FOOT))
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			assert_bool(rects[i].grow(0.0).intersects(rects[j])).override_failure_message("bars %d and %d overlap" % [i, j]).is_false()


func test_the_lowest_bar_keeps_its_place_and_the_result_does_not_depend_on_input_order() -> void:
	var forward: Array[Vector2] = [Vector2(0, 0), Vector2(0.2, 0.1), Vector2(-0.2, 0.2)]
	var backward: Array[Vector2] = [Vector2(-0.2, 0.2), Vector2(0.2, 0.1), Vector2(0, 0)]
	var a: Array[float] = HpBarLayout.stack_offsets(forward, FOOT, 0.04, 5)
	var b: Array[float] = HpBarLayout.stack_offsets(backward, FOOT, 0.04, 5)
	assert_float(a[0]).is_equal(0.0)  # the one standing lowest on screen stays on its owner's head
	assert_float(a[1]).is_equal(b[1])
	assert_float(a[2]).is_equal(b[0])
	assert_float(a[2]).is_greater(a[1])


func test_the_lift_is_capped_so_a_deep_pile_does_not_become_a_tower() -> void:
	var anchors: Array[Vector2] = []
	for i in range(20):
		anchors.append(Vector2(0.0, 0.01 * float(i)))
	var cap: float = 3.0 * (FOOT.y + 0.04)
	for lift: float in HpBarLayout.stack_offsets(anchors, FOOT, 0.04, 3):
		assert_float(lift).is_less_equal(cap + 0.0001)
	for lift: float in HpBarLayout.stack_offsets(anchors, FOOT, 0.04, 0):
		assert_float(lift).is_equal(0.0)


func test_smoothing_lands_exactly_and_never_overshoots() -> void:
	assert_float(HpBarLayout.smooth(0.0, 1.0, 0.0, 0.016)).is_equal(1.0)  # rate 0 snaps
	var value: float = 0.0
	for _i in range(600):
		value = HpBarLayout.smooth(value, 0.7, 14.0, 0.016)
		assert_float(value).is_less_equal(0.7)
	assert_float(value).is_equal(0.7)


func test_the_stack_settings_are_in_data_and_validated() -> void:
	var cfg: Dictionary = UiConfig.hp_bars()
	for key: String in ["stack_row_height", "stack_gap", "stack_max_rows", "stack_smooth"]:
		assert_bool(cfg.has(key)).is_true()
	assert_array(UiConfig.validate_hp_bars(cfg)).is_empty()
	var bad: Dictionary = cfg.duplicate(true)
	bad["stack_max_rows"] = 2.5
	bad["stack_row_height"] = 0
	assert_int(UiConfig.validate_hp_bars(bad).size()).is_equal(2)
	assert_float(EnemyHpBar.footprint().y).is_equal_approx(float(cfg["stack_row_height"]), 0.0001)


func test_a_bar_lifts_along_the_camera_up_axis_and_comes_back() -> void:
	var host := Node3D.new()
	add_child(host)
	host.global_position = Vector3(2.0, 0.0, 3.0)
	var bar := EnemyHpBar.new()
	host.add_child(bar)
	var base: Vector3 = bar.base_global_position()
	assert_vector(base).is_equal(Vector3(2.0, float(UiConfig.hp_bars()["y_offset"]), 3.0))
	var up := Vector3(0.0, 0.8, -0.6)
	bar.set_lift(0.5, up)
	assert_vector(bar.global_position).is_equal_approx(base + up * 0.5, Vector3(0.001, 0.001, 0.001))
	bar.set_lift(0.0, up)
	assert_vector(bar.global_position).is_equal_approx(base, Vector3(0.001, 0.001, 0.001))
	host.queue_free()


# --- Card strip backing ---

func test_the_card_plates_are_dense_enough_for_text_over_an_enemy_and_ready_still_differs_from_cooling() -> void:
	var cfg: Dictionary = UiConfig.hud()
	var ready: float = Color.html(String(cfg["slot_plate_ready_color"])).a
	var cooling: float = Color.html(String(cfg["slot_plate_cooling_color"])).a
	assert_float(ready).is_greater_equal(0.6)  # an enemy behind a card no longer competes with its text
	assert_float(cooling - ready).is_greater_equal(0.15)  # the ready-versus-cooling cue (plate density) stays
