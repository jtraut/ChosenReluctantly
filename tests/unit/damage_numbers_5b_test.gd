class_name DamageNumbers5bTest
extends GdUnitTestSuite
## Slice 5b: damage number data, merge and cap rules.


func _entry(pos: Vector3, type: String, idle: float) -> Dictionary:
	return {"pos": pos, "type": type, "idle": idle}


func test_shipped_config_is_valid_and_readable_size() -> void:
	var cfg: Dictionary = UiConfig.damage_numbers()
	assert_array(UiConfig.validate_damage_numbers(cfg)).is_empty()
	# Cap height in pixels at 720p, ortho camera size 14 (720 / 14 px per meter): must clear 14 px.
	var cap_height_m: float = 0.72 * float(cfg["font_size"]) * float(cfg["pixel_size"])
	assert_float(cap_height_m * 720.0 / 14.0).is_greater(14.0)


func test_validator_rejects_bad_values() -> void:
	var bad: Dictionary = UiConfig.DEFAULT_DAMAGE_NUMBERS.duplicate()
	bad["pixel_size"] = 0.0
	assert_array(UiConfig.validate_damage_numbers(bad)).is_not_empty()
	bad = UiConfig.DEFAULT_DAMAGE_NUMBERS.duplicate()
	bad["outline_color"] = "nope"
	assert_array(UiConfig.validate_damage_numbers(bad)).is_not_empty()
	bad = UiConfig.DEFAULT_DAMAGE_NUMBERS.duplicate()
	bad["color_lighten"] = 1.5
	assert_array(UiConfig.validate_damage_numbers(bad)).is_not_empty()
	bad = UiConfig.DEFAULT_DAMAGE_NUMBERS.duplicate()
	bad.erase("max_alive")
	assert_array(UiConfig.validate_damage_numbers(bad)).is_not_empty()


func test_merge_picks_nearest_same_type_young_number() -> void:
	var entries: Array = [
		_entry(Vector3(0, 2, 0), "physical", 0.1),
		_entry(Vector3(0.3, 2, 0), "physical", 0.1),
		_entry(Vector3(0.1, 2, 0), "fire", 0.0),
	]
	assert_int(DamageNumber.find_merge_index(entries, Vector3(0.25, 3.0, 0), "physical", 0.8, 0.3)).is_equal(1)  # height ignored
	assert_int(DamageNumber.find_merge_index(entries, Vector3(0.1, 2, 0), "fire", 0.8, 0.3)).is_equal(2)


func test_merge_ignores_far_old_and_other_type() -> void:
	var entries: Array = [_entry(Vector3(0, 2, 0), "physical", 0.1), _entry(Vector3(0.2, 2, 0), "physical", 0.5)]
	assert_int(DamageNumber.find_merge_index(entries, Vector3(2.0, 2, 0), "physical", 0.8, 0.3)).is_equal(-1)  # too far
	assert_int(DamageNumber.find_merge_index(entries, Vector3(0.2, 2, 0), "fire", 0.8, 0.3)).is_equal(-1)  # other type
	assert_int(DamageNumber.find_merge_index([_entry(Vector3.ZERO, "physical", 0.3)], Vector3.ZERO, "physical", 0.8, 0.3)).is_equal(-1)  # idle at the window
	assert_int(DamageNumber.find_merge_index([], Vector3.ZERO, "physical", 0.8, 0.3)).is_equal(-1)


func test_evict_count_keeps_room_for_one_more() -> void:
	assert_int(DamageNumber.evict_count(0, 16)).is_equal(0)
	assert_int(DamageNumber.evict_count(15, 16)).is_equal(0)
	assert_int(DamageNumber.evict_count(16, 16)).is_equal(1)
	assert_int(DamageNumber.evict_count(20, 16)).is_equal(5)
	assert_int(DamageNumber.evict_count(3, 0)).is_equal(3)  # a cap below 1 acts as 1


func test_merge_hit_sums_and_extends_life() -> void:
	var number: DamageNumber = auto_free(DamageNumber.new())
	add_child(number)  # global_position needs a tree (qa: the suite logged an engine ERROR without this)
	number.configure(UiConfig.damage_numbers())
	number.show_amount(3.0, "physical", Color.WHITE, false)
	number._elapsed = 0.7
	number.merge_hit(5.0, false)
	assert_str(number.text).is_equal("8")
	assert_float(number.idle_time()).is_less_equal(0.8 * DamageNumber.MERGE_REFRESH + 0.0001)
	number.merge_hit(4.0, true)
	assert_str(number.text).is_equal("12")
	assert_float(number.scale.x).is_equal_approx(float(UiConfig.damage_numbers()["big_scale"]), 0.0001)


func test_color_follows_element_data() -> void:
	var fire: Color = DamageNumber.color_for("fire", 0.0)
	assert_object(fire).is_equal(ElementVisuals.color_for_damage_type("fire"))
	assert_float(DamageNumber.color_for("fire", 1.0).g).is_equal_approx(1.0, 0.0001)


func test_damage_numbers_config_is_cached_not_rebuilt_per_hit() -> void:
	# S5-7: the same dictionary comes back on every call (no per-hit merge, validate or duplicate).
	var first: Dictionary = UiConfig.damage_numbers()
	assert_bool(UiConfig.damage_numbers() == first).is_true()
	assert_bool(is_same(UiConfig.damage_numbers(), first)).is_true()
