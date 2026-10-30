class_name A1ArmorTest
extends GdUnitTestSuite
## Slice A1: armor (GDD section 7). Formula, channels, cap, penetration, player armor, DoT, validation, tier parity.

const K := 50.0
const KNOWN_ENEMIES: Array[String] = ["melee_chaser", "ranged_shooter", "fire_resistant_golem", "boss_guardian"]


class Attacker extends Node:
	var stat_modifiers := StatModifiers.new()


func _health(armor: float = 0.0, max_hp: float = 1000.0) -> Health:
	var h: Health = auto_free(Health.new())
	h.max_health = max_hp
	h.current_health = max_hp
	h.base_armor = armor
	return h


func _lost(h: Health, before: float) -> float:
	return before - h.current_health


# ---- Formula ----

func test_formula_zero_k_half_and_never_full() -> void:
	assert_float(CombatMath.armor_reduction(0.0, K, 1.0)).is_equal(0.0)
	assert_float(CombatMath.armor_reduction(K, K, 1.0)).is_equal(0.5)
	assert_float(CombatMath.armor_reduction(1.0e9, K, 1.0)).is_less(1.0)
	assert_float(CombatMath.armor_reduction(1.0e9, K, 1.0)).is_greater(0.999)
	assert_float(CombatMath.armor_reduction(-20.0, K, 1.0)).is_equal(0.0)
	assert_float(CombatMath.apply_armor(10.0, K, 0.0, K, 1.0)).is_equal_approx(5.0, 0.0001)


func test_cap_applies() -> void:
	assert_float(CombatMath.armor_reduction(500.0, K, 0.5)).is_equal(0.5)
	assert_float(CombatMath.apply_armor(10.0, 500.0, 0.0, K, 0.5)).is_equal_approx(5.0, 0.0001)


func test_penetration_is_flat_and_floors_at_zero() -> void:
	assert_float(CombatMath.apply_armor(10.0, 50.0, 50.0, K)).is_equal(10.0)
	assert_float(CombatMath.apply_armor(10.0, 50.0, 500.0, K)).is_equal(10.0)  # armor never goes below 0, so no bonus damage
	assert_float(CombatMath.apply_armor(10.0, 100.0, 50.0, K)).is_equal_approx(5.0, 0.0001)


# ---- Channels, through Health ----

func test_armor_reduces_physical_and_neutral_not_fire() -> void:
	var h := _health(50.0)
	h.take_damage(10.0, "physical")
	assert_float(_lost(h, 1000.0)).is_equal_approx(5.0, 0.0001)
	assert_that(h.last_channel).is_equal(Health.CHANNEL_ARMOR)
	h.take_damage(10.0, "neutral")
	assert_float(_lost(h, 1000.0)).is_equal_approx(10.0, 0.0001)
	var before := h.current_health
	h.take_damage(10.0, "fire")
	assert_float(_lost(h, before)).is_equal(10.0)  # armor never reduces elemental damage
	assert_that(h.last_channel).is_equal(Health.CHANNEL_NONE)


func test_resistance_reduces_fire_not_physical() -> void:
	var h := _health(0.0)
	h.resistances = {"fire": 0.5, "physical": 0.5}
	h.take_damage(10.0, "fire")
	assert_float(_lost(h, 1000.0)).is_equal(5.0)
	assert_that(h.last_channel).is_equal(Health.CHANNEL_RESISTANCE)
	var before := h.current_health
	h.take_damage(10.0, "physical")
	assert_float(_lost(h, before)).is_equal(10.0)  # resistance never reduces non-elemental damage
	before = h.current_health
	h.take_damage(10.0, "neutral")
	assert_float(_lost(h, before)).is_equal(10.0)


func test_non_elemental_set_is_data() -> void:
	assert_bool(ArmorConfig.is_non_elemental("physical")).is_true()
	assert_bool(ArmorConfig.is_non_elemental("neutral")).is_true()
	assert_bool(ArmorConfig.is_non_elemental("fire")).is_false()
	assert_float(ArmorConfig.k()).is_equal(50.0)
	assert_float(ArmorConfig.reduction_cap()).is_equal(0.5)
	for element: String in TierRules.element_ids():
		assert_bool(ArmorConfig.is_non_elemental(element)).is_false()


func test_armor_stat_and_stacking_cap() -> void:
	var h := _health(0.0)
	h.stat_modifiers = StatModifiers.new()
	h.stat_modifiers.add_modifier("armor", "gear", StatModifiers.ADDITIVE, 50.0)
	assert_float(h.get_armor()).is_equal(50.0)
	assert_float(h.get_armor_reduction()).is_equal(0.5)
	h.stat_modifiers.add_modifier("armor", "gear2", StatModifiers.ADDITIVE, 400.0)
	assert_float(h.get_armor_reduction()).is_equal(0.5)  # capped
	h.stat_modifiers.add_modifier("armor", "curse", StatModifiers.ADDITIVE, -1000.0)
	assert_float(h.get_armor()).is_equal(0.0)  # floored


func test_attacker_penetration_reduces_target_armor() -> void:
	var h := _health(50.0)
	var attacker: Attacker = auto_free(Attacker.new())
	attacker.stat_modifiers.add_modifier("armor_penetration", "pen", StatModifiers.ADDITIVE, 50.0)
	h.take_damage(10.0, "physical", Vector3.ZERO, attacker)
	assert_float(_lost(h, 1000.0)).is_equal_approx(10.0, 0.0001)
	assert_that(h.last_channel).is_equal(Health.CHANNEL_NONE)


func test_player_armor_mitigates_enemy_physical_hits() -> void:
	var player: Player = auto_free((load("res://scenes/player/Player.tscn") as PackedScene).instantiate())
	add_child(player)
	assert_float(player.health.get_armor()).is_equal(0.0)
	var before := player.health.current_health
	player.health.take_damage(10.0, "physical")
	assert_float(before - player.health.current_health).is_equal(10.0)
	player.stat_modifiers.add_modifier("armor", "test", StatModifiers.ADDITIVE, 50.0)
	assert_float(player.health.get_armor()).is_equal(50.0)
	before = player.health.current_health
	player.health.take_damage(10.0, "physical")
	assert_float(before - player.health.current_health).is_equal_approx(5.0, 0.0001)


func test_heals_are_untouched_by_armor() -> void:
	var h := _health(50.0, 100.0)
	h.take_damage(40.0, "neutral")
	var before := h.current_health
	h.heal(10.0)
	assert_float(h.current_health - before).is_equal(10.0)


# ---- DoT ----

func test_bleed_goes_through_armor_burn_through_resistance() -> void:
	var h := _health(50.0)
	h.resistances = {"fire": 0.5}
	var manager: StatusEffectManager = auto_free(StatusEffectManager.new())
	manager.health = h
	manager.apply_status("bleed", {"damage_per_tick": 1.0, "damage_type": "physical", "tick_interval": 1.0}, 1.0)
	manager._process(1.0)
	assert_float(_lost(h, 1000.0)).is_equal_approx(0.5, 0.0001)  # floats flow through: no rounding to zero
	assert_that(h.last_kind).is_equal(Health.KIND_DOT)
	assert_that(h.last_channel).is_equal(Health.CHANNEL_ARMOR)
	var before := h.current_health
	manager.apply_status("burn", {"damage_per_tick": 2.0, "damage_type": "fire", "tick_interval": 1.0}, 1.0)
	manager._process(1.0)
	assert_float(_lost(h, before)).is_equal_approx(1.0, 0.0001)
	assert_that(h.last_channel).is_equal(Health.CHANNEL_RESISTANCE)


# ---- Validation ----

func test_armor_config_validation_fails_loud() -> void:
	var good: Dictionary = {"k": 50.0, "armor_reduction_cap": 0.5, "non_elemental_types": ["physical"]}
	assert_array(ArmorConfig.validate(good)).is_empty()
	var bad_cases: Array[Dictionary] = [
		{"k": 0.0}, {"k": -5.0}, {"k": null}, {"armor_reduction_cap": 1.5}, {"armor_reduction_cap": -0.1}, {"armor_reduction_cap": null},
		{"non_elemental_types": []}, {"non_elemental_types": "physical"},
	]
	for patch: Dictionary in bad_cases:
		var cfg := good.duplicate(true)
		for key: Variant in patch:
			if patch[key] == null:
				cfg.erase(key)
			else:
				cfg[key] = patch[key]
		assert_array(ArmorConfig.validate(cfg)).is_not_empty()
	assert_array(ArmorConfig.validate("nope")).is_not_empty()


func _run_problems(config: Dictionary) -> Array[String]:
	var cards: Array[String] = []
	for card: Variant in CardDatabase.all_cards():
		cards.append(String((card as Dictionary)["id"]))
	return RunConfig.validate(config, KNOWN_ENEMIES, cards)


func test_tier_armor_validation() -> void:
	var shipped: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RunConfig.PATH))
	assert_array(_run_problems(shipped)).is_empty()
	for tier_id: String in ["elite", "boss"]:
		var missing := shipped.duplicate(true)
		(missing["tiers"][tier_id] as Dictionary).erase("armor")
		assert_array(_run_problems(missing)).is_not_empty()
		var negative := shipped.duplicate(true)
		negative["tiers"][tier_id]["armor"] = -1.0
		assert_array(_run_problems(negative)).is_not_empty()
		var drifted := shipped.duplicate(true)  # armor changed without the resistance: parity fails
		drifted["tiers"][tier_id]["armor"] = float(shipped["tiers"][tier_id]["armor"]) + 15.0
		assert_array(_run_problems(drifted)).is_not_empty()
		var drifted_res := shipped.duplicate(true)  # resistance changed without the armor
		drifted_res["tiers"][tier_id]["resistance_floor"] = 0.5
		assert_array(_run_problems(drifted_res)).is_not_empty()


func test_boss_and_enemy_armor_validation() -> void:
	var shipped: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BossConfig.PATH))
	assert_array(BossConfig.validate(shipped, KNOWN_ENEMIES)).is_empty()
	var missing := shipped.duplicate(true)
	(missing["bosses"]["boss_guardian"] as Dictionary).erase("armor")
	assert_array(BossConfig.validate(missing, KNOWN_ENEMIES)).is_not_empty()
	var negative := shipped.duplicate(true)
	negative["bosses"]["boss_guardian"]["armor"] = -5.0
	assert_array(BossConfig.validate(negative, KNOWN_ENEMIES)).is_not_empty()
	var drifted := shipped.duplicate(true)
	drifted["bosses"]["boss_guardian"]["armor"] = 20.0
	assert_array(BossConfig.validate(drifted, KNOWN_ENEMIES)).is_not_empty()
	var stats: Dictionary = EnemyConfig.stats_for("melee_chaser").duplicate()
	assert_array(EnemyConfig.validate_stats("x", stats)).is_empty()
	stats["armor"] = 8.0
	assert_array(EnemyConfig.validate_stats("x", stats)).is_empty()
	stats["armor"] = -1.0
	assert_array(EnemyConfig.validate_stats("x", stats)).is_not_empty()


# ---- Parity of the shipped data ----

func test_shipped_tier_armor_matches_resistance_within_two_points() -> void:
	var run: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RunConfig.PATH))
	var boss: Dictionary = BossConfig.boss("boss_guardian")
	var cases: Array[Dictionary] = [
		{"label": "elite", "armor": float(run["tiers"]["elite"]["armor"]), "res": float(run["tiers"]["elite"]["resistance_floor"])},
		{"label": "boss tier", "armor": float(run["tiers"]["boss"]["armor"]), "res": float(run["tiers"]["boss"]["resistance_floor"])},
		{"label": "final boss", "armor": float(boss["armor"]), "res": float(boss["resistance"])},
	]
	for c: Dictionary in cases:
		var reduction := CombatMath.armor_reduction(float(c["armor"]), ArmorConfig.k(), ArmorConfig.reduction_cap())
		assert_float(absf(reduction - float(c["res"]))).override_failure_message("%s: armor %s -> %s vs resistance %s" % [c["label"], c["armor"], reduction, c["res"]]).is_less(0.02)
	assert_array(ArmorConfig.parity_errors("t", 17.0, 0.5, 50.0, 0.02)).is_not_empty()  # the check itself can fail
