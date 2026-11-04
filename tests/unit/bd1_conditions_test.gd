class_name Bd1ConditionsTest
extends GdUnitTestSuite
## BD1-A item 3 (caster side): condition validation, CastHistory, cast_within and zone_active through EffectTemplates,
## and cast_within through a real CardSlotController (test-only fixture cards in tests/fixtures/bd1_cards).

const FIXTURES := "res://tests/fixtures/bd1_cards"
const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"


class StatCaster extends TestCaster:
	var stat_modifiers := StatModifiers.new()


func after_test() -> void:
	CardDatabase.load_all()  # a fixture directory must not leak into later suites
	CombatEvents.reset()


func _wounded_caster() -> StatCaster:
	var caster: StatCaster = auto_free(StatCaster.new())
	caster.health.current_health = 10.0
	return caster


func _controller(caster: StatCaster, deck: Array[String]) -> CardSlotController:
	CardDatabase.load_all(FIXTURES)
	CombatEvents.reset()
	var owned: Array[String] = ["neutral"]
	var controller := CardSlotController.new(caster, caster, "player", caster.stat_modifiers, owned)
	controller.set_deck(deck)
	return controller


# --- validation -------------------------------------------------------------------------

func _valid(condition: Variant, template_id: String = "heal") -> Array[String]:
	return EffectCondition.validate(condition, template_id)


func test_each_type_validates() -> void:
	assert_array(_valid({"type": "cast_within", "slot_type": "movement", "seconds": 2.0})).is_empty()
	assert_array(_valid({"type": "cast_within", "tag": "Dash", "seconds": 1.5})).is_empty()
	assert_array(_valid({"type": "cast_within", "tag": "Primer", "seconds": 6})).is_empty()
	assert_array(_valid({"type": "zone_active"}, "aoe")).is_empty()
	assert_array(_valid({"type": "target_has_status", "status_id": "burn"}, "aoe")).is_empty()


func test_unknown_or_missing_type_is_an_error() -> void:
	assert_array(_valid({"type": "hp_below", "fraction": 0.5})).is_not_empty()
	assert_array(_valid({})).is_not_empty()
	assert_array(_valid("zone_active")).is_not_empty()


func test_cast_within_needs_exactly_one_of_slot_type_or_tag() -> void:
	assert_array(_valid({"type": "cast_within", "seconds": 2.0})).is_not_empty()
	assert_array(_valid({"type": "cast_within", "slot_type": "movement", "tag": "Dash", "seconds": 2.0})).is_not_empty()


func test_cast_within_slot_and_tag_must_be_known() -> void:
	assert_array(_valid({"type": "cast_within", "slot_type": "nonsense", "seconds": 2.0})).is_not_empty()
	assert_array(_valid({"type": "cast_within", "tag": "Nonsense", "seconds": 2.0})).is_not_empty()
	assert_array(_valid({"type": "cast_within", "tag": "dash", "seconds": 2.0})).is_not_empty()  # tags are Capitalised


func test_cast_within_seconds_range() -> void:
	for bad: Variant in [0, -1.0, 6.5, "2", null, NAN, INF]:
		assert_array(_valid({"type": "cast_within", "slot_type": "movement", "seconds": bad})).is_not_empty()
	assert_array(_valid({"type": "cast_within", "slot_type": "movement"})).is_not_empty()
	assert_array(_valid({"type": "cast_within", "slot_type": "movement", "seconds": CastHistory.MAX_SECONDS})).is_empty()


func test_target_condition_needs_a_known_status_and_a_target_template() -> void:
	assert_array(_valid({"type": "target_has_status", "status_id": "nope"}, "aoe")).is_not_empty()
	assert_array(_valid({"type": "target_has_status"}, "aoe")).is_not_empty()
	for template_id: String in ["heal", "buff", "dash", "pass_through"]:
		assert_array(_valid({"type": "target_has_status", "status_id": "burn"}, template_id)).is_not_empty()
	for template_id: String in ["cone", "aoe", "projectile", "zone", "apply_status"]:
		assert_array(_valid({"type": "target_has_status", "status_id": "burn"}, template_id)).is_empty()


func test_unsupported_params_are_rejected() -> void:
	assert_array(_valid({"type": "target_has_status", "status_id": "burn", "min_stacks": 2}, "aoe")).is_not_empty()
	assert_array(_valid({"type": "zone_active", "tag": "Burn"})).is_not_empty()
	assert_array(_valid({"type": "cast_within", "slot_type": "movement", "seconds": 2, "extra": 1})).is_not_empty()


func test_card_schema_validates_conditions_and_names_the_effect() -> void:
	var card: Dictionary = {"id": "x", "name": "X", "slot_type": "recovery", "pool": "neutral", "cooldown_modifier": 0.0, "flavor_text": "f",
			"effects": [{"template": "heal", "params": {"amount": 1}, "condition": {"type": "bogus"}}]}
	var errors := CardSchema.validate(card)
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("effects[0]")
	((card["effects"] as Array)[0] as Dictionary)["condition"] = {"type": "zone_active"}
	assert_array(CardSchema.validate(card)).is_empty()


func test_damage_rule_ignores_conditional_effects() -> void:
	var card: Dictionary = {"slot_type": "attack_single", "cooldown_modifier": 0.0, "effects": [
		{"template": "cone", "params": {"damage": 6.0, "damage_type": "physical", "range": 2.0, "half_angle_degrees": 45}},
		{"template": "cone", "params": {"damage": 12.0, "damage_type": "physical", "range": 2.0, "half_angle_degrees": 45}, "condition": {"type": "zone_active"}},
	]}
	assert_float(CardDamageRule.cast_damage(card, {}, 1.0)).is_equal(6.0)


# --- CastHistory (explicit clock) --------------------------------------------------------

func test_history_matches_slot_type_and_tag() -> void:
	var history := CastHistory.new()
	var tags: Array[String] = ["Dash", "Buff"]
	history.record(10.0, "movement", "m", tags)
	assert_bool(history.cast_within(11.0, 2.0, "movement")).is_true()
	assert_bool(history.cast_within(11.0, 2.0, "", "Dash")).is_true()
	assert_bool(history.cast_within(11.0, 2.0, "utility")).is_false()
	assert_bool(history.cast_within(11.0, 2.0, "", "Burn")).is_false()
	assert_bool(history.cast_within(11.0, 2.0, "movement", "Burn")).is_false()


func test_history_window_is_inclusive_and_expires() -> void:
	var history := CastHistory.new()
	history.record(10.0, "movement", "m", [] as Array[String])
	assert_bool(history.cast_within(12.0, 2.0, "movement")).is_true()
	assert_bool(history.cast_within(12.01, 2.0, "movement")).is_false()


func test_history_finds_an_older_match_behind_newer_non_matches() -> void:
	var history := CastHistory.new()
	history.record(10.0, "movement", "m", [] as Array[String])
	history.record(10.5, "attack_single", "a", [] as Array[String])
	assert_bool(history.cast_within(11.0, 2.0, "movement")).is_true()


func test_history_drops_old_entries_and_caps_size() -> void:
	var history := CastHistory.new()
	history.record(0.0, "movement", "m", [] as Array[String])
	history.record(CastHistory.WINDOW + 1.0, "utility", "u", [] as Array[String])
	assert_int(history.size()).is_equal(1)
	for i in range(CastHistory.MAX_ENTRIES + 10):
		history.record(100.0, "utility", "u", [] as Array[String])
	assert_int(history.size()).is_equal(CastHistory.MAX_ENTRIES)
	history.clear()
	assert_int(history.size()).is_equal(0)


# --- caster conditions through EffectTemplates ---------------------------------------------

func _heal_if(condition: Dictionary, context: EffectContext) -> void:
	EffectTemplates.execute("heal", {"amount": 5}, context, condition)


func test_cast_within_false_without_history_true_with_a_recent_cast() -> void:
	var caster := _wounded_caster()
	var context := EffectContext.new(caster, caster, "player")
	var condition: Dictionary = {"type": "cast_within", "slot_type": "movement", "seconds": 2.0}
	_heal_if(condition, context)  # no history object at all
	assert_float(caster.health.current_health).is_equal(10.0)
	var history := CastHistory.new()
	context.cast_history = history
	context.now = 5.0
	_heal_if(condition, context)  # empty history
	assert_float(caster.health.current_health).is_equal(10.0)
	history.record(4.0, "movement", "m", [] as Array[String])
	_heal_if(condition, context)
	assert_float(caster.health.current_health).is_equal(15.0)
	context.now = 7.0  # 3 s after the cast: outside the 2 s window
	_heal_if(condition, context)
	assert_float(caster.health.current_health).is_equal(15.0)


func test_cast_within_by_tag() -> void:
	var caster := _wounded_caster()
	var context := EffectContext.new(caster, caster, "player")
	var history := CastHistory.new()
	history.record(1.0, "utility", "u", ["Burn"] as Array[String])
	context.cast_history = history
	context.now = 2.0
	_heal_if({"type": "cast_within", "tag": "Burn", "seconds": 2.0}, context)
	assert_float(caster.health.current_health).is_equal(15.0)
	_heal_if({"type": "cast_within", "tag": "Dash", "seconds": 2.0}, context)
	assert_float(caster.health.current_health).is_equal(15.0)


func test_a_skipped_effect_does_not_touch_last_hits() -> void:
	var caster := _wounded_caster()
	var context := EffectContext.new(caster, caster, "player")
	var kept: Array[Hurtbox] = [auto_free(Hurtbox.new())]
	context.last_hits = kept
	_heal_if({"type": "zone_active"}, context)
	assert_int(context.last_hits.size()).is_equal(1)


func test_zone_active_true_only_while_the_casters_own_zone_lives() -> void:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	var caster: StatCaster = StatCaster.new()
	main.add_child(caster)
	caster.health.current_health = 10.0
	var other: StatCaster = StatCaster.new()
	main.add_child(other)
	other.health.current_health = 10.0
	var context := EffectContext.new(caster, main, "player")
	var other_context := EffectContext.new(other, main, "player")
	var condition: Dictionary = {"type": "zone_active"}
	EffectTemplates.execute("heal", {"amount": 5}, context, condition)  # no manager at all yet
	assert_float(caster.health.current_health).is_equal(10.0)
	var zone_params: Dictionary = {"shape": "circle", "radius": 1.0, "duration": 4.0, "tick_interval": 1.0, "damage": 1.0, "damage_type": "physical", "max_range": 3.0}
	EffectTemplates.execute("zone", zone_params, context)
	EffectTemplates.execute("heal", {"amount": 5}, context, condition)
	assert_float(caster.health.current_health).is_equal(15.0)
	EffectTemplates.execute("heal", {"amount": 5}, other_context, condition)  # someone else's zone does not count
	assert_float(other.health.current_health).is_equal(10.0)
	(ZoneManager.find_in_world(main) as ZoneManager).clear()
	EffectTemplates.execute("heal", {"amount": 5}, context, condition)
	assert_float(caster.health.current_health).is_equal(15.0)


# --- through a real controller ----------------------------------------------------------------

func test_payoff_pays_only_after_a_movement_cast_and_history_follows_the_cast() -> void:
	var caster := _wounded_caster()
	var controller := _controller(caster, ["bd1_prime_move", "bd1_payoff_single"] as Array[String])
	assert_bool(controller.try_use("attack_single")).is_true()
	assert_float(caster.health.current_health).is_equal(10.0)  # nothing in the history yet
	controller.advance(5.0)
	assert_bool(controller.try_use("movement")).is_true()
	assert_int(CombatEvents.history.size()).is_equal(2)
	assert_bool(controller.try_use("attack_single")).is_true()
	assert_float(caster.health.current_health).is_equal(15.0)


func test_a_cards_own_cast_is_not_in_the_history_its_conditions_read() -> void:
	var caster := _wounded_caster()
	var controller := _controller(caster, ["bd1_self_aware"] as Array[String])
	assert_bool(controller.try_use("recovery")).is_true()
	assert_float(caster.health.current_health).is_equal(10.0)  # its own cast (a Heal) did not count
	controller.advance(60.0)
	assert_bool(controller.try_use("recovery")).is_true()
	assert_float(caster.health.current_health).is_equal(15.0)  # the first cast did


func test_combat_events_emits_card_cast_with_tags_and_resets() -> void:
	var caster := _wounded_caster()
	var controller := _controller(caster, ["bd1_prime_move"] as Array[String])
	var seen: Array = []
	var relay: CombatEventsRelay = CombatLink.events()
	relay.card_cast.connect(func(slot_type: String, card_id: String, tags: Array[String]) -> void: seen.append([slot_type, card_id, tags]))
	controller.try_use("movement")
	assert_int(seen.size()).is_equal(1)
	assert_str(seen[0][0]).is_equal("movement")
	assert_str(seen[0][1]).is_equal("bd1_prime_move")
	assert_array(seen[0][2]).is_equal(["Buff", "Primer"])
	assert_int(CombatEvents.history.size()).is_equal(1)
	CombatEvents.reset()
	assert_int(CombatEvents.history.size()).is_equal(0)
	assert_float(CombatEvents.now()).is_equal(0.0)
