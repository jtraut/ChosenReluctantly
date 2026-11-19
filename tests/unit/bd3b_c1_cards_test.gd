class_name Bd3bC1CardsTest
extends GdUnitTestSuite
## BD3b sitting C1: the 7 shipped Wizard cards (BUILD_DEPTH 14.3) cast through the real effect executor, and the two new debug decks.

const NEW_CARDS: Array[String] = ["wizard_thesis_defense", "wizard_footnotes", "wizard_citation_needed", "wizard_literature_review", "wizard_spiteful_ward",
		"wizard_hostile_feedback", "wizard_sick_day"]


## A caster with a stat stack, like the player (the buff template needs one).
class BuffCaster extends RelayTarget:
	var stat_modifiers := StatModifiers.new()


func before_test() -> void:
	CombatEvents.reset()


func after_test() -> void:
	CombatEvents.reset()


func _caster(hp: float = 100.0) -> BuffCaster:
	var caster := BuffCaster.new("player", hp)
	add_child(caster)
	auto_free(caster)
	return caster


func _enemy(at: Vector3) -> RelayTarget:
	var target := RelayTarget.new("enemy", 1000.0)
	add_child(target)
	auto_free(target)
	target.global_position = at
	return target


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	return rng


## Runs every effect of a real card the way the slot does, minus the cast bookkeeping.
func _cast(card_id: String, caster: BuffCaster) -> void:
	var card: Dictionary = CardDatabase.get_card(card_id)
	var context := EffectContext.new(caster, self, "player")
	context.origin = "card:" + card_id
	context.rng = _rng()
	for effect: Dictionary in card["effects"]:
		EffectTemplates.execute(String(effect["template"]), effect["params"], context, effect.get("condition", {}), effect.get("scale", {}))


func _lost(target: RelayTarget) -> float:
	return 1000.0 - target.health.current_health


func test_all_seven_cards_load_in_the_wizard_pool_as_common_starters() -> void:
	for id in NEW_CARDS:
		assert_bool(CardDatabase.has_card(id)).override_failure_message(id).is_true()
		var card: Dictionary = CardDatabase.get_card(id)
		assert_str(String(card["pool"])).is_equal("wizard")
		assert_str(String(card["availability"])).is_equal("starter")


func test_the_keywords_match_the_design() -> void:
	var expected: Dictionary = {"wizard_thesis_defense": ["Keystone", "Payoff"], "wizard_footnotes": ["Primer"], "wizard_citation_needed": [],
			"wizard_literature_review": ["Primer"], "wizard_spiteful_ward": ["Keystone"], "wizard_hostile_feedback": ["Payoff"], "wizard_sick_day": []}
	for id: String in expected:
		var keywords: Array = (CardDatabase.get_card(id) as Dictionary).get("keywords", [])
		assert_array(keywords).override_failure_message(id).is_equal(expected[id])


func test_a_primer_gives_three_charge_and_thesis_defense_spends_it() -> void:
	var caster := _caster()
	await _frames(2)
	_cast("wizard_footnotes", caster)
	assert_int(caster.status_manager.stacks_of("charge")).is_equal(3)
	_cast("wizard_literature_review", caster)
	assert_int(caster.status_manager.stacks_of("charge")).is_equal(6)
	var thesis: Dictionary = (CardDatabase.get_card("wizard_thesis_defense") as Dictionary)["effects"][0]
	var context := EffectContext.new(caster, self, "player")
	var scaled: Dictionary = EffectScale.apply(thesis["scale"], "projectile", thesis["params"], context)
	assert_float(float(scaled["damage"])).is_equal_approx(151.0, 0.0001)
	assert_bool(caster.status_manager.has_status("charge")).is_false()


func test_footnotes_and_literature_review_and_citation_needed_cast_without_error() -> void:
	var caster := _caster()
	var near := _enemy(Vector3(1.0, 0, 0))
	await _frames(2)
	for id in ["wizard_footnotes", "wizard_citation_needed", "wizard_thesis_defense"]:
		_cast(id, caster)
	_cast("wizard_literature_review", caster)
	await _frames(30)
	assert_bool(is_instance_valid(near)).is_true()


func test_hostile_feedback_adds_its_second_hit_only_below_half_hp() -> void:
	var healthy := _caster(100.0)
	var enemy := _enemy(Vector3(1.0, 0, 0))
	await _frames(2)
	_cast("wizard_hostile_feedback", healthy)
	assert_float(_lost(enemy)).is_equal_approx(13.0, 0.01)
	var hurt := _caster(100.0)
	hurt.health.current_health = 40.0
	var second := _enemy(Vector3(1.0, 0, 0))
	await _frames(2)
	_cast("wizard_hostile_feedback", hurt)
	assert_float(_lost(second)).is_equal_approx(21.0, 0.01)


func test_sick_day_heals_and_arms() -> void:
	var caster := _caster(100.0)
	caster.health.current_health = 50.0
	_cast("wizard_sick_day", caster)
	assert_float(caster.health.current_health).is_equal_approx(60.0, 0.01)
	assert_float(caster.stat_modifiers.apply("armor", 0.0)).is_equal_approx(15.0, 0.0001)


func test_spiteful_wards_nova_fires_when_the_player_is_hit_during_the_buff() -> void:
	var caster := _caster()
	var enemy := _enemy(Vector3(1.5, 0, 0))
	await _frames(2)
	var host := RelicManager.buff_host(caster, self, _rng(), CombatEvents)
	_cast("wizard_spiteful_ward", caster)
	assert_float(caster.stat_modifiers.apply("armor", 0.0)).is_equal_approx(25.0, 0.0001)
	CombatEvents.notify_player_damaged(5.0, "enemy")
	host.flush()
	assert_float(_lost(enemy)).is_equal_approx(6.0, 0.01)
	CombatEvents.step(5.0)
	CombatEvents.notify_player_damaged(5.0, "enemy")
	host.flush()
	assert_float(_lost(enemy)).override_failure_message("no nova after the buff ends").is_equal_approx(6.0, 0.01)


func test_the_two_debug_decks_are_legal_non_fire_wizard_decks() -> void:
	for deck_name in ["wizard-thesis", "wizard-ward-battlemage"]:
		var file := FileAccess.open("res://data/debug_decks/%s.json" % deck_name, FileAccess.READ)
		var data: Dictionary = JSON.parse_string(file.get_as_text())
		assert_str(String(data["name"])).is_equal(deck_name)
		var cards: Array = data["full"]
		assert_array(cards).is_equal(data["starter"])
		assert_int(cards.size()).is_between(15, 20)
		var per_slot: Dictionary = {}
		for id: String in cards:
			var card: Dictionary = CardDatabase.get_card(id)
			assert_bool(String(card["pool"]) != "fire").override_failure_message("%s: %s is Fire" % [deck_name, id]).is_true()
			var slot: String = String(card["slot_type"])
			per_slot[slot] = int(per_slot.get(slot, 0)) + 1
		for slot: String in per_slot:
			assert_int(int(per_slot[slot])).override_failure_message("%s %s" % [deck_name, slot]).is_greater_equal(3)
