class_name Bd3bD1PoolTagTest
extends GdUnitTestSuite
## BD3b-D1: a pool's card tag lives in data/pools.json ("tag"), not in CardTags.


func _entry(extra: Dictionary) -> Dictionary:
	var entry := {"kind": "class", "display_name": "X", "frame_color": "#d9b48a"}
	entry.merge(extra, true)
	return entry


func test_the_fire_pool_carries_the_fire_tag_from_data() -> void:
	assert_str(PoolDatabase.tag_for_pool("fire")).is_equal("Fire")
	assert_str(PoolDatabase.tag_for_pool("neutral")).is_equal("")
	assert_str(PoolDatabase.tag_for_pool("no_such_pool")).is_equal("")
	assert_array(PoolDatabase.all_pool_tags()).is_equal(["Fire"])


func test_a_fire_pool_card_gets_the_pool_tag_after_derived_tags_and_keywords() -> void:
	var tags: Array[String] = CardTags.all_tags({"pool": "fire", "effects": [{"template": "cone", "params": {}}], "keywords": []})
	assert_array(tags).is_equal(["Melee", "Fire"])
	assert_array(CardTags.all_tags({"pool": "neutral", "effects": []})).is_empty()
	assert_bool(CardTags.is_known_tag("Fire")).is_true()


func test_the_shipped_pools_validate() -> void:
	assert_array(PoolDatabase.validate_all()).is_empty()


func test_a_bad_tag_is_rejected() -> void:
	assert_array(PoolDatabase.validate_entry(_entry({"tag": "Water"}))).is_empty()
	for bad: Variant in ["", " ", "Two Words", 5, "Melee"]:
		assert_array(PoolDatabase.validate_entry(_entry({"tag": bad}))).override_failure_message("tag %s" % str(bad)).is_not_empty()


func test_two_pools_may_not_share_a_tag() -> void:
	var table := {"neutral": _entry({}), "a": _entry({"tag": "Ice"}), "b": _entry({"tag": "Ice"})}
	assert_bool(PoolDatabase.validate_table(table).any(func(e: String) -> bool: return e.contains("already used"))).is_true()
