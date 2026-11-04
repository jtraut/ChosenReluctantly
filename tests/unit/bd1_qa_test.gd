class_name Bd1QaTest
extends GdUnitTestSuite
## BD1 qa: gaps found while reviewing the gameplay-dev and ux suites.
##  1. A zone re-checks its target condition on EVERY tick (the dev test only covers the placement tick).
##  2. A projectile that fails its condition is spent: it does not carry on to a qualifying target behind it.
##  3. D39 = A end to end through a real Player: a real dodge neither enters the cast history as a Movement cast nor
##     eats a Movement prime, while a real Movement card does both (the control that keeps the test from being vacuous).
##  4. Content: the new cards' numbers match BUILD_DEPTH section 5, and conditional damage is strictly extra on top of
##     an unconditional hit (so a payoff is never a dead card).
##  5. status_damage_mult edge values (zero, a large value) never produce NaN, INF or negative damage.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"
const MARK := {"type": "target_has_status", "status_id": "leech"}

var _main: Main = null


class StatCaster extends TestCaster:
	var stat_modifiers := StatModifiers.new()


func before_test() -> void:
	CardDatabase.load_all()
	BodyFlag.set_collide(false)


func after_test() -> void:
	DodgeSwitch.reset()
	BodyFlag.reset()
	Juice.reset()
	Engine.time_scale = 1.0
	CombatEvents.reset()
	if _main != null and is_instance_valid(_main):
		get_tree().current_scene = null
		_main.free()
	_main = null


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _spawn_main() -> Main:
	_main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(_main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	return _main


func _caster(main: Main) -> TestCaster:
	var caster := TestCaster.new()
	main.add_child(caster)
	caster.global_position = main.player.global_position + Vector3(8.0, 0.0, 0.0)
	return caster


func _still_enemy(main: Main, caster: Node3D, forward: float, sideways: float = 0.0) -> Enemy:
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	main.add_child(enemy)
	enemy.global_position = caster.global_position + Vector3(sideways, 0.0, -forward)
	enemy.set_physics_process(false)  # stays where it is, so a zone or a shot is the only thing that touches it
	return enemy


func _context(main: Main, caster: Node3D) -> EffectContext:
	var context := EffectContext.new(caster, main, "player")
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = 11
	return context


func _lost(enemy: Enemy) -> float:
	return enemy.health.get_max_health() - enemy.health.current_health


# --- 1. zone: the condition is checked per tick ------------------------------------------------------------

func test_a_zone_rechecks_its_condition_on_every_tick() -> void:
	var main := _spawn_main()
	var caster := _caster(main)
	var enemy := _still_enemy(main, caster, 3.0)
	await _frames(3)
	var context := _context(main, caster)
	context.aim_point = caster.global_position + Vector3(0.0, 0.0, -3.0)
	var params: Dictionary = {"shape": "circle", "radius": 2.0, "duration": 8.0, "tick_interval": 0.5, "damage": 2.0, "damage_type": "physical", "max_range": 6.0}
	EffectTemplates.execute("zone", params, context, MARK)
	await _frames(40)  # 0.67 s, a tick has passed with the target unmarked
	assert_float(_lost(enemy)).override_failure_message("an unmarked target was hit by a conditional zone tick").is_equal(0.0)
	enemy.status_manager.apply_status("leech", StatusDatabase.get_status("leech"), 0.8)
	await _frames(60)  # 1.0 s: the mark was up for 0.8 s of it, then it expired
	var while_marked := _lost(enemy)
	assert_float(while_marked).override_failure_message("a later tick should hit once the target became marked").is_greater_equal(2.0)
	await _frames(60)
	assert_float(_lost(enemy)).override_failure_message("ticks kept hitting after the mark expired").is_equal(while_marked)


# --- 2. projectile: a failed condition spends the shot -------------------------------------------------------

func test_a_projectile_that_fails_its_condition_is_spent_and_does_not_reach_the_target_behind() -> void:
	var main := _spawn_main()
	var caster := _caster(main)
	var front := _still_enemy(main, caster, 3.0)
	var behind := _still_enemy(main, caster, 6.0)
	behind.status_manager.apply_status("leech", StatusDatabase.get_status("leech"), 30.0)
	await _frames(3)
	var params: Dictionary = {"damage": 3.0, "damage_type": "physical", "speed": 20.0, "max_range": 12.0, "hit_radius": 0.4}
	EffectTemplates.execute("projectile", params, _context(main, caster), MARK)
	await get_tree().create_timer(0.9).timeout
	assert_float(_lost(front)).is_equal(0.0)
	assert_float(_lost(behind)).override_failure_message("the spent shot kept flying and hit the marked target").is_equal(0.0)
	# Control: the same shot with no condition does reach the front target, so the zeros above are not a missed shot.
	EffectTemplates.execute("projectile", params, _context(main, caster))
	await get_tree().create_timer(0.9).timeout
	assert_float(_lost(front)).is_equal_approx(3.0, 0.001)


# --- 3. D39 = A through a real Player -------------------------------------------------------------------------

func test_a_real_dodge_is_not_a_movement_cast_and_does_not_eat_a_movement_prime() -> void:
	DodgeSwitch.enable()
	var main := _spawn_main()
	var player: Player = main.player
	player.camera = null
	await _frames(2)
	CombatEvents.reset()
	player.stat_modifiers.add_primed_modifier("slot_cooldown_skip.movement", "qa_prime", StatModifiers.ADDITIVE, 1.0, "movement", 1, 30.0)
	var relay: CombatEventsRelay = CombatLink.events()
	var charges: int = player.dodge_charges.current
	TestInput.press(&"dodge")
	await _frames(2)
	TestInput.release(&"dodge")
	assert_int(player.dodge_charges.current).override_failure_message("the dodge did not fire; the test would prove nothing").is_less(charges)
	assert_bool(relay.history.cast_within(relay.now(), 2.0, "movement")).override_failure_message("a dodge counted as a Movement cast").is_false()
	assert_int(player.stat_modifiers.primed_state().size()).override_failure_message("a dodge consumed a Movement prime").is_equal(1)
	var drive_by: Dictionary = CardDatabase.get_card("rogue_drive_by")
	assert_bool(SlotSynergy.is_live(drive_by, {"now": relay.now(), "history": relay.history})).is_false()


func test_a_real_movement_card_does_both_the_control_for_the_dodge_test() -> void:
	var main := _spawn_main()
	var player: Player = main.player
	player.camera = null
	await _frames(2)
	CombatEvents.reset()
	player.stat_modifiers.add_primed_modifier("slot_cooldown_skip.movement", "qa_prime", StatModifiers.ADDITIVE, 1.0, "movement", 1, 30.0)
	var relay: CombatEventsRelay = CombatLink.events()
	assert_bool(player.card_slots.try_use("movement")).is_true()
	assert_bool(relay.history.cast_within(relay.now(), 2.0, "movement")).is_true()
	# Not is_empty(): the arena Player's Movement slot may roll Momentum, which adds its own (Attack: Single) prime.
	assert_bool(player.stat_modifiers.primed_ids().has("qa_prime")).override_failure_message("a Movement cast should use the Movement prime").is_false()


# --- 4. card numbers vs BUILD_DEPTH section 5 ----------------------------------------------------------------------

func _effects(id: String) -> Array:
	return CardDatabase.get_card(id)["effects"] as Array


func _params(id: String, index: int) -> Dictionary:
	return (_effects(id)[index] as Dictionary)["params"] as Dictionary


func test_new_card_numbers_match_build_depth_section_5() -> void:
	var fan: Dictionary = CardDatabase.get_card("fire_fan_the_flames")
	assert_str(String(fan["slot_type"])).is_equal("attack_aoe")
	assert_float(float(fan["cooldown_modifier"])).is_equal(0.5)
	var unconditional_aoe := _params("fire_fan_the_flames", 2)
	assert_float(float(unconditional_aoe["radius"])).is_equal(3.0)
	assert_float(float(unconditional_aoe["damage"])).is_equal(10.0)
	assert_float(float(_params("fire_fan_the_flames", 3)["duration"])).is_equal(4.0)  # applies Burn 4 s
	assert_float(float(_params("fire_fan_the_flames", 0)["damage"])).is_equal(10.0)  # +10 on a Burning target
	assert_float(float(_params("fire_fan_the_flames", 1)["duration"])).is_equal(5.0)  # Burn refreshes to 5 s
	assert_float(float(_params("fire_kindling", 0)["value"])).is_equal(0.5)
	assert_float(float(_params("fire_kindling", 0)["duration"])).is_equal(8.0)
	assert_str(String(_params("fire_kindling", 0)["stat"])).is_equal("status_damage_mult.burn")
	assert_float(float(CardDatabase.get_card("rogue_drive_by")["cooldown_modifier"])).is_equal(0.1)
	assert_float(float(_params("rogue_drive_by", 1)["damage"])).is_equal(6.0)
	assert_float(float(_params("rogue_drive_by", 0)["damage"])).is_equal(12.0)  # +12 after a Movement cast
	assert_float(float(((_effects("rogue_drive_by")[0] as Dictionary)["condition"] as Dictionary)["seconds"])).is_equal(2.0)
	assert_float(float(_params("rogue_drive_by", 0)["knockback_strength"])).is_equal(3.0)
	assert_float(float(_params("rogue_momentum", 0)["distance"])).is_equal(4.0)
	assert_bool(bool(_params("rogue_momentum", 0)["pass_through"])).is_true()
	assert_float(float(_params("rogue_momentum", 1)["duration"])).is_equal(3.0)
	assert_float(float(CardDatabase.get_card("fire_heat_sink")["cooldown_modifier"])).is_equal(0.5)
	assert_float(float(_params("fire_heat_sink", 1)["radius"])).is_equal(2.5)
	assert_float(float(_params("fire_heat_sink", 1)["max_range"])).is_equal(8.0)
	assert_float(float(_params("fire_heat_sink", 0)["damage"])).is_equal(10.0)  # +10 while a Zone is up
	assert_float(float(_params("fire_heat_sink", 2)["duration"])).is_equal(4.0)
	var slow := _params("fire_slow_burn", 0)
	assert_float(float(slow["radius"])).is_equal(2.5)
	assert_float(float(slow["duration"])).is_equal(4.0)
	assert_float(float(slow["damage"])).is_equal(2.5)
	assert_float(float(slow["tick_interval"])).is_equal(0.5)
	assert_float(float(slow["status_chance"])).is_equal(1.0)
	assert_float(float(CardDatabase.get_card("fire_slow_burn")["cooldown_modifier"])).is_equal(0.8)
	assert_float(float(_params("wizard_parting_gift", 1)["distance"])).is_equal(5.0)
	assert_bool(bool(_params("wizard_parting_gift", 1)["invulnerable"])).is_true()
	assert_float(float(_params("wizard_parting_gift", 0)["radius"])).is_equal(2.2)
	assert_float(float(_params("wizard_parting_gift", 0)["damage"])).is_equal(10.0)
	assert_float(float(_params("wizard_parting_gift", 0)["delay"])).is_equal(0.6)
	assert_str(String(_params("wizard_parting_gift", 0)["anchor"])).is_equal("caster")
	assert_float(float(CardDatabase.get_card("wizard_well_actually")["cooldown_modifier"])).is_equal(0.0)
	assert_float(float(_params("wizard_well_actually", 1)["radius"])).is_equal(3.0)
	assert_float(float(_params("wizard_well_actually", 1)["damage"])).is_equal(13.0)
	assert_float(float(_params("wizard_well_actually", 0)["damage"])).is_equal(8.0)
	assert_float(float(_params("wizard_well_actually", 0)["knockback_strength"])).is_equal(6.0)
	assert_float(float(((_effects("wizard_well_actually")[0] as Dictionary)["condition"] as Dictionary)["seconds"])).is_equal(1.5)


func test_every_new_conditional_effect_is_extra_on_top_of_an_unconditional_hit_of_the_same_kind() -> void:
	for id: String in ["fire_fan_the_flames", "rogue_drive_by", "fire_heat_sink", "wizard_well_actually"]:
		var effects: Array = _effects(id)
		var has_conditional := false
		var has_unconditional_damage := false
		for effect: Variant in effects:
			var block: Dictionary = effect
			var params: Dictionary = block["params"]
			if block.has("condition"):
				has_conditional = true
			elif float(params.get("damage", 0.0)) > 0.0:
				has_unconditional_damage = true
		assert_bool(has_conditional).override_failure_message(id + " has no conditional effect").is_true()
		assert_bool(has_unconditional_damage).override_failure_message(id + " would be a dead card when its condition is off").is_true()


# --- 5. status_damage_mult edge values -------------------------------------------------------------------------

func _tick_once(mult: float) -> float:
	var caster: StatCaster = auto_free(StatCaster.new())
	caster.stat_modifiers.add_modifier("status_damage_mult.burn", "m", StatModifiers.MULTIPLICATIVE, mult)
	var health: Health = auto_free(Health.new())
	health.max_health = 1000000.0
	health.current_health = 1000000.0
	var manager: StatusEffectManager = auto_free(StatusEffectManager.new())
	manager.health = health
	manager.apply_status("burn", StatusDatabase.get_status("burn"), 10.0, caster)
	manager._process(1.0)
	return health.max_health - health.current_health


func test_status_damage_mult_zero_large_and_below_minus_one_never_give_nan_inf_or_healing() -> void:
	for mult: float in [0.0, 1.0, 1000.0, -1.0, -5.0]:
		var dealt := _tick_once(mult)
		assert_bool(is_nan(dealt) or is_inf(dealt)).override_failure_message("mult %s gave %s" % [mult, dealt]).is_false()
		assert_float(dealt).override_failure_message("mult %s dealt negative damage (healed the target)" % mult).is_greater_equal(0.0)
	assert_float(_tick_once(0.0)).is_equal_approx(2.0, 0.001)  # +0% is the plain tick
	assert_float(_tick_once(1000.0)).is_equal_approx(2002.0, 0.01)


# --- 6. keywords.json failure paths (the dev suite only checks the shipped file) -----------------------------------

const KEYWORD_FIXTURES := "res://tests/fixtures/bd1_keywords/"


func _problems_with(fixture: String) -> Array[String]:
	var saved: JsonDataTable = KeywordDatabase._table
	KeywordDatabase._table = JsonDataTable.new(KEYWORD_FIXTURES + fixture)
	var problems: Array[String] = KeywordDatabase.validate_table()
	KeywordDatabase._table = saved
	return problems


func test_a_keyword_with_empty_rule_text_or_no_name_is_reported_by_field() -> void:
	var empty_text := _problems_with("empty_text.json")
	assert_int(empty_text.size()).is_equal(1)
	assert_str(empty_text[0]).contains("Primer").contains("rule_text")
	var no_name := _problems_with("missing_name.json")
	assert_int(no_name.size()).is_equal(1)
	assert_str(no_name[0]).contains("Primer").contains("display_name")


func test_a_keyword_that_collides_with_a_derived_tag_is_reported() -> void:
	var problems := _problems_with("derived_collision.json")
	assert_int(problems.size()).is_equal(1)
	assert_str(problems[0]).contains("Burn").contains("derived tag")


func test_a_malformed_keywords_file_fails_loudly_and_every_keyword_becomes_unknown() -> void:
	var saved: JsonDataTable = KeywordDatabase._table
	KeywordDatabase._table = JsonDataTable.new(KEYWORD_FIXTURES + "malformed.json")
	assert_bool(KeywordDatabase.has("Primer")).is_false()
	assert_bool(KeywordDatabase.has("Keystone")).is_false()
	# A card naming a keyword is then rejected by the schema (never accepted silently).
	var card: Dictionary = (CardDatabase.get_card("fire_fan_the_flames") as Dictionary).duplicate(true)
	var errors: Array[String] = CardSchema.validate(card)
	KeywordDatabase._table = saved
	assert_array(errors).is_not_empty()
