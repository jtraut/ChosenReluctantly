class_name PoolFrameColorTest
extends GdUnitTestSuite
## Card frame colour per pool (GDD §4, D17): validation and the card -> pool -> colour accessor.

const FIRE := Color("#ff6a1f")
const CLASS_POOL := Color("#d9b48a")
const NEUTRAL := Color("#9a9a9a")


func _entry(frame: Variant) -> Dictionary:
	var entry := {"kind": "class", "display_name": "X"}
	if frame != null:
		entry["frame_color"] = frame
	return entry


func test_missing_or_bad_frame_color_fails() -> void:
	assert_array(PoolDatabase.validate_entry(_entry(null))).is_not_empty()
	assert_array(PoolDatabase.validate_entry(_entry("nope"))).is_not_empty()
	assert_array(PoolDatabase.validate_entry(_entry(5))).is_not_empty()
	assert_array(PoolDatabase.validate_entry(_entry(""))).is_not_empty()
	assert_array(PoolDatabase.validate_entry(_entry("#d9b48a"))).is_empty()


func test_table_with_a_pool_lacking_frame_color_fails() -> void:
	var table := {
		"neutral": {"kind": "neutral", "display_name": "N", "frame_color": "#9a9a9a"},
		"rogue": {"kind": "class", "display_name": "R"},
	}
	var errors := PoolDatabase.validate_table(table)
	assert_array(errors).is_not_empty()
	assert_bool("; ".join(errors).contains("frame_color")).is_true()


func test_every_shipped_pool_has_a_valid_frame_color() -> void:
	assert_array(PoolDatabase.validate_all()).is_empty()
	for pool_id: Variant in PoolDatabase.known_ids():
		var raw: Variant = PoolDatabase.get_definition(String(pool_id)).get("frame_color")
		assert_bool(typeof(raw) == TYPE_STRING and Color.html_is_valid(String(raw))).override_failure_message(String(pool_id)).is_true()


func test_pool_colours_are_the_director_values() -> void:
	assert_object(PoolDatabase.frame_color_for_pool("fire")).is_equal(FIRE)
	assert_object(PoolDatabase.frame_color_for_pool("rogue")).is_equal(CLASS_POOL)
	assert_object(PoolDatabase.frame_color_for_pool("wizard")).is_equal(CLASS_POOL)
	assert_object(PoolDatabase.frame_color_for_pool("neutral")).is_equal(NEUTRAL)


func test_card_accessor_maps_card_to_its_pool_colour() -> void:
	for card: Variant in CardDatabase.all_cards():
		var data: Dictionary = card
		var expected := PoolDatabase.frame_color_for_pool(String(data["pool"]))
		assert_object(PoolDatabase.frame_color_for_card(String(data["id"]))).override_failure_message(String(data["id"])).is_equal(expected)
	var seen: Dictionary = {}
	for card: Variant in CardDatabase.all_cards():
		seen[String(PoolDatabase.frame_color_for_card(String((card as Dictionary)["id"])).to_html(false))] = true
	assert_bool(seen.has("ff6a1f") and seen.has("d9b48a") and seen.has("9a9a9a")).is_true()


func test_unknown_card_or_pool_falls_back_to_neutral() -> void:
	assert_object(PoolDatabase.frame_color_for_card("no_such_card")).is_equal(NEUTRAL)
	assert_object(PoolDatabase.frame_color_for_pool("no_such_pool")).is_equal(NEUTRAL)
