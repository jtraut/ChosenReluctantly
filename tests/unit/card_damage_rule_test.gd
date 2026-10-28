class_name CardDamageRuleTest
extends GdUnitTestSuite
## The cards-beat-light rule (GDD §3) and the click-rate cap (3b-1).

const LIGHT := {"damage": 3.0, "interval": 0.6}
const SLOTS := {"attack_single": {"base_cooldown": 1.0}, "attack_aoe": {"base_cooldown": 2.5}, "utility": {"base_cooldown": 4.0}}
const STATUSES := {"burn": {"effect_type": "damage_over_time", "damage_per_tick": 2.0, "tick_interval": 1.0}}


func _card(id: String, slot: String, modifier: float, effects: Array) -> Dictionary:
	return {"id": id, "slot_type": slot, "cooldown_modifier": modifier, "effects": effects}


func _cone(damage: float) -> Dictionary:
	return {"template": "cone", "params": {"damage": damage}}


func test_shipped_cards_obey_the_rule() -> void:
	CardDatabase.load_all()
	assert_array(CardDamageRule.check_shipped()).is_empty()


func test_shipped_damage_cards_are_found() -> void:
	CardDatabase.load_all()
	var count := 0
	for card: Dictionary in CardDatabase.all_cards():
		if CardDamageRule.is_damage_card(card):
			count += 1
	assert_int(count).is_equal(8)


func test_compliant_fixture_passes() -> void:
	var card := _card("ok", "attack_single", 0.0, [_cone(6.0)])
	assert_array(CardDamageRule.check_all([card], SLOTS, LIGHT, STATUSES)).is_empty()


func test_fails_on_cast_below_one_and_a_half_light() -> void:
	# 4 < 4.5 even though 4 / 0.6 s is fine DPS.
	var card := _card("weak", "attack_single", -0.4, [_cone(4.0)])
	var problems := CardDamageRule.check_all([card], SLOTS, LIGHT, STATUSES)
	assert_int(problems.size()).is_equal(1)
	assert_str(problems[0]).contains("weak").contains("below")


func test_fails_on_slow_cycle_dps() -> void:
	# Cast 8 passes (a) but 8 / 2.5 = 3.2 DPS loses to light's 5.
	var card := _card("slow", "attack_aoe", 0.0, [{"template": "aoe", "params": {"damage": 8.0}}])
	var problems := CardDamageRule.check_all([card], SLOTS, LIGHT, STATUSES)
	assert_int(problems.size()).is_equal(1)
	assert_str(problems[0]).contains("DPS")


func test_dps_must_be_strictly_above_light() -> void:
	# 5 / 1.0 == light 5 DPS exactly: not enough.
	var card := _card("tie", "attack_single", 0.0, [_cone(5.0)])
	assert_int(CardDamageRule.check_all([card], SLOTS, LIGHT, STATUSES).size()).is_equal(1)


func test_status_damage_counts_whole_ticks() -> void:
	var card := _card("burny", "attack_single", 0.0, [_cone(1.0), {"template": "apply_status", "params": {"status_id": "burn", "duration": 4.5}}])
	# 1 direct + 4 ticks x 2.
	assert_float(CardDamageRule.cast_damage(card, STATUSES)).is_equal(9.0)


func test_status_damage_lets_a_low_direct_card_pass() -> void:
	var card := _card("burny", "attack_single", 0.0, [_cone(1.0), {"template": "apply_status", "params": {"status_id": "burn", "duration": 4.0}}])
	assert_array(CardDamageRule.check_all([card], SLOTS, LIGHT, STATUSES)).is_empty()


func test_exempt_slots_and_exception_reason() -> void:
	var utility := _card("util", "utility", 0.0, [_cone(0.5)])
	assert_array(CardDamageRule.check_all([utility], SLOTS, LIGHT, STATUSES)).is_empty()
	var fast := _card("fast", "attack_single", -0.9, [_cone(1.0)])
	assert_int(CardDamageRule.check_all([fast], SLOTS, LIGHT, STATUSES).size()).is_greater(0)
	fast["rule_exception"] = "fast filler, logged in DECISIONS"
	assert_array(CardDamageRule.check_all([fast], SLOTS, LIGHT, STATUSES)).is_empty()
	fast["rule_exception"] = "  "
	assert_int(CardDamageRule.check_all([fast], SLOTS, LIGHT, STATUSES).size()).is_greater(0)


func test_cooldown_modifier_can_be_negative() -> void:
	assert_float(CardDamageRule.cycle_cooldown(_card("q", "attack_single", -0.4, []), 1.0)).is_equal_approx(0.6, 0.0001)
