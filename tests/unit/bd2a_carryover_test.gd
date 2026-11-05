class_name Bd2aCarryoverTest
extends GdUnitTestSuite
## BD2-A carry-overs from the BD1 qa review: JsonDataTable's typed get_entry, the status_damage_mult validator floor.

const KEYWORD_FIXTURES := "res://tests/fixtures/bd1_keywords/"


func test_a_keyword_entry_that_is_not_an_object_is_reported_not_crashed_on() -> void:
	var saved: JsonDataTable = KeywordDatabase._table
	KeywordDatabase._table = JsonDataTable.new(KEYWORD_FIXTURES + "not_an_object.json")
	var problems: Array[String] = KeywordDatabase.validate_table()
	KeywordDatabase._table = saved
	assert_array(problems).is_not_empty()
	assert_str(problems[0]).contains("Primer").contains("must be an object")


func test_get_raw_returns_the_value_as_filed_and_null_for_unknown() -> void:
	var table := JsonDataTable.new(KEYWORD_FIXTURES + "not_an_object.json")
	assert_that(table.get_raw("Primer")).is_equal("just a string")
	assert_that(table.get_raw("Nope")).is_null()
	assert_bool(table.has("Primer")).is_true()


func test_get_entry_on_a_real_object_and_unknown_id_is_unchanged() -> void:
	var table := JsonDataTable.new("res://data/keywords.json")
	assert_bool(table.get_entry("Primer").is_empty()).is_false()
	assert_bool(table.get_entry("NoSuchKeyword").is_empty()).is_true()


func _buff(stat: String, kind: String, value: float) -> Array[String]:
	return EffectTemplates.validate_params("buff", {"stat": stat, "modifier_type": kind, "value": value, "duration": 5.0})


func test_status_damage_mult_buff_at_or_below_minus_one_is_rejected() -> void:
	for value: float in [-1.0, -1.5, -5.0]:
		var errors := _buff("status_damage_mult.burn", StatModifiers.MULTIPLICATIVE, value)
		assert_int(errors.size()).is_equal(1)
		assert_str(errors[0]).contains("status_damage_mult.burn")
	assert_array(_buff("status_damage_mult.burn", StatModifiers.ADDITIVE, -1.0)).is_not_empty()


func test_status_damage_mult_buff_above_the_floor_and_other_stats_pass() -> void:
	assert_array(_buff("status_damage_mult.burn", StatModifiers.MULTIPLICATIVE, 0.5)).is_empty()
	assert_array(_buff("status_damage_mult.burn", StatModifiers.MULTIPLICATIVE, -0.9)).is_empty()
	assert_array(_buff("move_speed", StatModifiers.MULTIPLICATIVE, -2.0)).is_empty()
