class_name Ux1cQaTest
extends GdUnitTestSuite
## qa review of UX1c: readout after 0/1/2 elite clears, other relics, a save round trip, the crowd layout switch and bar lifecycle.

func _ctx() -> Dictionary:
	return RunChoices.shipped_context(["neutral", "rogue"] as Array[String])


func _now(state: RunState, id: String) -> String:
	for shown: Dictionary in RunRelics.owned_display(state, _ctx()):
		if String(shown.get("relic_id", "")) == id:
			return String(shown["now"])
	return "<missing>"


func test_readout_after_zero_one_two_elite_clears() -> void:
	var state := RunState.new()
	state.relics = ["performance_review"] as Array[String]
	state.max_hp = 30.0
	state.hp = 30.0
	assert_str(_now(state, "performance_review")).is_empty()
	RunMaxHp.on_room_cleared(state, "elite")
	assert_str(_now(state, "performance_review")).is_equal("Now: +1 max HP")
	RunMaxHp.on_room_cleared(state, "elite")
	assert_str(_now(state, "performance_review")).is_equal("Now: +2 max HP")


func test_readout_survives_a_save_round_trip() -> void:
	var state := RunState.new()
	state.relics = ["performance_review"] as Array[String]
	state.max_hp = 30.0
	state.hp = 30.0
	RunMaxHp.on_room_cleared(state, "elite")
	RunMaxHp.on_room_cleared(state, "elite")
	var loaded: RunState = RunState.from_dict(state.to_dict())
	assert_str(_now(loaded, "performance_review")).is_equal("Now: +2 max HP")


func test_a_relic_without_a_boost_record_gets_no_line() -> void:
	var state := RunState.new()
	state.relics = ["heavy_sigh"] as Array[String]
	assert_str(_now(state, "heavy_sigh")).is_empty()


func test_stack_max_rows_zero_means_no_lift_in_layout_math() -> void:
	var anchors: Array[Vector2] = [Vector2(0, 0), Vector2(0, 0), Vector2(0.1, 0), Vector2(0, 0.05)]
	var offsets: Array[float] = HpBarLayout.stack_offsets(anchors, Vector2(1.6, 0.3), 0.04, 0)
	for o: float in offsets:
		assert_float(o).is_equal(0.0)


func test_layout_is_deterministic_and_finite() -> void:
	var anchors: Array[Vector2] = []
	for i in range(12):
		anchors.append(Vector2(float(i % 3) * 0.2, float(i % 4) * 0.05))
	var a: Array[float] = HpBarLayout.stack_offsets(anchors, Vector2(1.6, 0.3), 0.04, 5)
	var b: Array[float] = HpBarLayout.stack_offsets(anchors, Vector2(1.6, 0.3), 0.04, 5)
	assert_array(a).is_equal(b)
	for o: float in a:
		assert_bool(is_nan(o) or is_inf(o)).is_false()
		assert_float(o).is_between(0.0, 5.0 * 0.34 + 0.0001)


func test_a_freed_bar_leaves_the_stacker() -> void:
	var host := Node3D.new()
	add_child(host)
	var bar := EnemyHpBar.new()
	host.add_child(bar)
	assert_bool(HpBarStacker._bars.has(bar)).is_true()
	host.remove_child(bar)
	assert_bool(HpBarStacker._bars.has(bar)).is_false()
	bar.free()
	host.queue_free()


func test_a_flat_max_hp_relic_shows_its_given_amount_via_the_real_gain_path() -> void:
	# Documents behaviour: wellness_pack records relic_max_hp on gain, so the readout shows for it too (not only Performance Review).
	var state := RunState.new()
	state.max_hp = 30.0
	state.hp = 30.0
	state.add_relic("wellness_pack")
	assert_str(_now(state, "wellness_pack")).is_equal("Now: +4 max HP")
