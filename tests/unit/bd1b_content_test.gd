class_name Bd1bContentTest
extends GdUnitTestSuite
## BD1-B: the 8 new cards (BUILD_DEPTH 5), the 4 archetype debug decks, the condition text and live-condition API
## (SlotSynergy), the buff wording for the new stats, and the plan-aware bot policy (PlanPolicy). Real data; the live
## checks use fabricated views, so no scene is needed except for the two end-to-end casts at the bottom.

const NEW_CARDS: Array[String] = ["fire_fan_the_flames", "fire_kindling", "rogue_drive_by", "rogue_momentum", "fire_heat_sink", "fire_slow_burn", "wizard_parting_gift", "wizard_well_actually"]
const KEYWORDS: Dictionary = {
	"fire_fan_the_flames": ["Keystone"], "fire_kindling": ["Primer"], "rogue_drive_by": ["Keystone", "Payoff"], "rogue_momentum": ["Primer"],
	"fire_heat_sink": ["Keystone", "Payoff"], "fire_slow_burn": [], "wizard_parting_gift": ["Keystone"], "wizard_well_actually": ["Payoff"],
}
const DECKS: Dictionary = {
	"rogue-kindling": ["rogue", "fire_fan_the_flames", "fire_kindling"],
	"rogue-hit-and-run": ["rogue", "rogue_drive_by", "rogue_momentum"],
	"wizard-controlled-burn": ["wizard", "fire_heat_sink", "fire_slow_burn"],
	"wizard-departure-lounge": ["wizard", "wizard_parting_gift", "wizard_well_actually"],
}
const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"


# --- the cards ---------------------------------------------------------------------------------

func test_the_eight_cards_exist_with_their_keywords_and_no_rule_exception() -> void:
	CardDatabase.load_all()
	for id: String in NEW_CARDS:
		var card: Dictionary = CardDatabase.get_card(id)
		assert_bool(card.is_empty()).override_failure_message(id + " is missing").is_false()
		assert_array(CardTags.keywords_of(card)).override_failure_message(id).is_equal(KEYWORDS[id])
		assert_bool(card.has("rule_exception")).override_failure_message(id).is_false()
	assert_array(CardDamageRule.check_shipped()).is_empty()


func test_every_new_attack_card_passes_the_damage_rule_on_its_unconditional_damage() -> void:
	var statuses: Dictionary = {"burn": StatusDatabase.get_status("burn"), "bleed": StatusDatabase.get_status("bleed")}
	var light: Dictionary = AttackDatabase.get_attack("light")
	var light_dps: float = float(light["damage"]) / float(light["interval"])
	for id: String in NEW_CARDS:
		var card: Dictionary = CardDatabase.get_card(id)
		if not CardDamageRule.is_damage_card(card):
			continue
		var base: float = float(SlotTypeDatabase.get_definition(String(card["slot_type"])).get("base_cooldown", 1.0))
		var cycle: float = CardDamageRule.cycle_cooldown(card, base)
		var cast: float = CardDamageRule.cast_damage(card, statuses, cycle)
		assert_float(cast).override_failure_message(id + " cast damage").is_greater_equal(CardDamageRule.CAST_RATIO * float(light["damage"]))
		assert_float(cast / cycle).override_failure_message(id + " DPS").is_greater(light_dps)


func test_tags_of_the_new_cards() -> void:
	assert_array(CardDatabase.tags_for("fire_fan_the_flames")).is_equal(["Area", "Burn", "Keystone"] as Array[String])
	assert_array(CardDatabase.tags_for("rogue_momentum")).is_equal(["Dash", "Buff", "Primer"] as Array[String])
	assert_array(CardDatabase.tags_for("fire_slow_burn")).is_equal(["Zone", "Burn"] as Array[String])
	assert_array(CardDatabase.tags_for("wizard_parting_gift")).is_equal(["Area", "Dash", "Keystone"] as Array[String])
	assert_array(SlotSynergy.chips("rogue_drive_by")).is_equal(["Keystone", "Payoff", "Melee"] as Array[String])


func test_the_four_archetype_decks_are_legal_and_hold_their_core() -> void:
	var directory: Dictionary = DebugDecks.read_dir()
	assert_array((directory["load_problems"] as Array)).is_empty()
	assert_array((directory["problems"] as Dictionary).keys()).is_empty()
	for deck_name: String in DECKS:
		assert_bool((directory["presets"] as Dictionary).has(deck_name)).override_failure_message(deck_name).is_true()
		var preset: Dictionary = (directory["presets"] as Dictionary)[deck_name]
		var spec: Array = DECKS[deck_name]
		assert_str(String(preset["class"])).is_equal(String(spec[0]))
		var pools: Array = RunConfig.character_pools(String(spec[0]))
		for key: String in ["starter", "full"]:
			assert_bool(DeckRules.check_shipped(preset[key]).is_ok()).override_failure_message("%s.%s breaks the deck rules" % [deck_name, key]).is_true()
			assert_bool((preset[key] as Array).size() >= 15).is_true()
			for core: int in range(1, spec.size()):
				assert_bool((preset[key] as Array).has(spec[core])).override_failure_message("%s.%s lacks %s" % [deck_name, key, spec[core]]).is_true()
			for card_id: String in preset[key]:
				assert_bool(pools.has(String(CardDatabase.get_card(card_id).get("pool", "")))).override_failure_message("%s: %s is outside the class pools" % [deck_name, card_id]).is_true()


func test_the_preset_starting_decks_did_not_change() -> void:
	for id: String in NEW_CARDS:
		assert_bool(RunConfig.starting_deck("rogue").has(id) or RunConfig.starting_deck("wizard").has(id)).is_false()


# --- text ----------------------------------------------------------------------------------------

func test_condition_text_comes_from_run_json_for_each_condition_type() -> void:
	var text: Dictionary = SlotSynergy.default_text()
	assert_str(SlotSynergy.condition_display(CardDatabase.get_card("fire_fan_the_flames"), text)).is_equal("If the target has Burn")
	assert_str(SlotSynergy.condition_display(CardDatabase.get_card("rogue_drive_by"), text)).is_equal("If you used your Movement slot in the last 2 s")
	assert_str(SlotSynergy.condition_display(CardDatabase.get_card("fire_heat_sink"), text)).is_equal("While you have a Zone active")
	assert_str(SlotSynergy.condition_display(CardDatabase.get_card("wizard_well_actually"), text)).is_equal("If you used your Movement slot in the last 1.5 s")
	assert_str(SlotSynergy.condition_display(CardDatabase.get_card("fire_slow_burn"), text)).is_equal("")
	var tag_condition: Dictionary = {"type": "cast_within", "tag": "Burn", "seconds": 3.0}
	assert_str(CardSummary.condition_text(tag_condition, text)).is_equal("If you cast a Burn card in the last 3 s")
	# Every string is data: a different run.json wording changes the text, nothing is hardcoded.
	var other: Dictionary = text.duplicate(true)
	(other["condition"] as Dictionary)["zone_active"] = "Zone up"
	assert_str(CardSummary.condition_text({"type": "zone_active"}, other)).is_equal("Zone up")


func test_buff_wording_for_the_new_stats() -> void:
	var text: Dictionary = SlotSynergy.default_text()
	var momentum: String = CardSummary.effect_line(CardDatabase.get_card("rogue_momentum"), 3.0, text)
	assert_str(momentum).contains("Next Attack: Single cast has no cooldown, within 3 s")
	assert_str(momentum).not_contains("Slot cooldown skip")
	var kindling: String = CardSummary.effect_line(CardDatabase.get_card("fire_kindling"), 4.0, text)
	assert_str(kindling).contains("Burn you apply deals +50% damage for 8 s")
	assert_str(kindling).not_contains("Status damage mult")


func test_effect_line_groups_conditional_effects_under_their_condition() -> void:
	var text: Dictionary = SlotSynergy.default_text()
	var fan: String = CardSummary.effect_line(CardDatabase.get_card("fire_fan_the_flames"), 2.5, text)
	assert_str(fan).contains("If the target has Burn: ")
	assert_str(fan).contains("10 fire damage (area)")
	assert_str(fan).ends_with("Cooldown 3 s")
	# A card without a condition reads exactly as before.
	assert_str(CardSummary.effect_line(CardDatabase.get_card("rogue_quick_slash"), 1.0, text)).not_contains("If ")


func test_ui_effect_strings_are_validated() -> void:
	assert_array(RunConfig.load_problems()).is_empty()
	var ui: Dictionary = RunConfig.ui().duplicate(true)
	((ui["effect"] as Dictionary)["condition"] as Dictionary).erase("zone_active")
	assert_array(RunConfig._validate_ui(ui)).is_not_empty()


# --- the live-condition check ------------------------------------------------------------------------

func _view(enemies: Array = [], history: CastHistory = null, now: float = 10.0, zones: int = 0) -> Dictionary:
	return {"now": now, "history": history, "zone_count": zones, "origin": Vector3.ZERO, "forward": Vector3(0, 0, -1),
			"aim_point": Vector3(0, 0, -6), "arena": Rect2(), "enemies": enemies}


func _enemy(pos: Vector3, statuses: Array = []) -> Dictionary:
	return {"pos": pos, "statuses": statuses}


func test_cast_within_is_live_only_inside_the_window_and_for_the_right_slot() -> void:
	var card: Dictionary = CardDatabase.get_card("rogue_drive_by")
	var history := CastHistory.new()
	assert_bool(SlotSynergy.is_live(card, _view([], history))).is_false()
	history.record(8.5, "movement", "rogue_momentum", CardDatabase.tags_for("rogue_momentum"))
	assert_bool(SlotSynergy.is_live(card, _view([], history, 10.0))).is_true()  # 1.5 s ago, window 2 s
	assert_bool(SlotSynergy.is_live(card, _view([], history, 10.6))).is_false()  # 2.1 s ago
	var other := CastHistory.new()
	other.record(9.9, "utility", "fire_kindling", CardDatabase.tags_for("fire_kindling"))
	assert_bool(SlotSynergy.is_live(card, _view([], other, 10.0))).is_false()  # wrong slot
	assert_bool(SlotSynergy.is_live(card, _view([], null))).is_false()  # no history: never live


func test_zone_active_is_live_with_a_zone() -> void:
	var card: Dictionary = CardDatabase.get_card("fire_heat_sink")
	assert_bool(SlotSynergy.is_live(card, _view([], null, 0.0, 0))).is_false()
	assert_bool(SlotSynergy.is_live(card, _view([], null, 0.0, 1))).is_true()


func test_target_condition_needs_a_burning_enemy_inside_the_preview_area() -> void:
	var fan: Dictionary = CardDatabase.get_card("fire_fan_the_flames")  # area r3.0 around the caster
	assert_bool(SlotSynergy.is_live(fan, _view([_enemy(Vector3(0, 0, -2.0), ["burn"])]))).is_true()
	assert_bool(SlotSynergy.is_live(fan, _view([_enemy(Vector3(0, 0, -2.0), [])]))).is_false()  # in range, not burning
	assert_bool(SlotSynergy.is_live(fan, _view([_enemy(Vector3(0, 0, -9.0), ["burn"])]))).is_false()  # burning, outside
	assert_bool(SlotSynergy.is_live(fan, _view([_enemy(Vector3(0, 0, -9.0), ["burn"]), _enemy(Vector3(1, 0, 1), ["burn"])]))).is_true()
	assert_bool(SlotSynergy.is_live(fan, _view([]))).is_false()


func test_a_placed_area_is_checked_where_the_aim_point_puts_it() -> void:
	# Heat Sink's disc lands at the aim point (6 m ahead, max range 8); its zone condition is not a target condition,
	# so use Slow Burn's shape through the shared containment helper.
	var part: Dictionary = {"shape": "aoe", "size": 2.5, "placed": true, "range": 8.0}
	assert_bool(SlotSynergy.part_contains(part, _view(), Vector3(0, 0, -6.5))).is_true()
	assert_bool(SlotSynergy.part_contains(part, _view(), Vector3(0, 0, -1.0))).is_false()
	var cone: Dictionary = {"shape": "cone", "size": 2.0, "half_angle_degrees": 45.0}
	assert_bool(SlotSynergy.part_contains(cone, _view(), Vector3(0.5, 0, -1.5))).is_true()
	assert_bool(SlotSynergy.part_contains(cone, _view(), Vector3(2.0, 0, -0.5))).is_false()  # 76 degrees off
	assert_bool(SlotSynergy.part_contains(cone, _view(), Vector3(0, 0, 1.0))).is_false()  # behind


func test_a_card_without_a_condition_is_never_live_and_slot_info_says_so() -> void:
	var text: Dictionary = SlotSynergy.default_text()
	var info: Dictionary = SlotSynergy.slot_info("attack_single", "rogue_quick_slash", _view([_enemy(Vector3(0, 0, -1))]), [] as Array[Dictionary], text)
	assert_bool(bool(info["has_condition"])).is_false()
	assert_bool(bool(info["condition_live"])).is_false()
	assert_str(String(info["condition_text"])).is_equal("")
	assert_bool(bool(info["primed"])).is_false()


func test_slot_info_reports_chips_condition_liveness_and_primed_state() -> void:
	var text: Dictionary = SlotSynergy.default_text()
	var history := CastHistory.new()
	history.record(9.0, "movement", "rogue_momentum", CardDatabase.tags_for("rogue_momentum"))
	var mods := StatModifiers.new()
	mods.add_primed_modifier("slot_cooldown_skip.attack_single", "p", StatModifiers.ADDITIVE, 1.0, "attack_single", 1, 3.0)
	mods.advance(1.0)
	var info: Dictionary = SlotSynergy.slot_info("attack_single", "rogue_drive_by", _view([], history, 10.0), mods.primed_state(), text)
	assert_array(info["chips"]).is_equal(["Keystone", "Payoff", "Melee"] as Array[String])
	assert_array(info["keywords"]).is_equal(["Keystone", "Payoff"] as Array[String])
	assert_str(String((info["keyword_rules"] as Dictionary)["Keystone"])).is_not_empty()
	assert_bool(bool(info["has_condition"])).is_true()
	assert_bool(bool(info["condition_live"])).is_true()
	assert_str(String(info["condition_text"])).is_equal("If you used your Movement slot in the last 2 s")
	assert_bool(bool(info["primed"])).is_true()
	assert_float(float(info["primed_time_left"])).is_equal_approx(2.0, 0.001)
	assert_float(float(info["primed_duration"])).is_equal_approx(3.0, 0.001)
	assert_int(int(info["primed_charges"])).is_equal(1)
	# The prime sits on Attack: Single only; another slot's card is not primed by it.
	var other: Dictionary = SlotSynergy.slot_info("attack_aoe", "fire_fine_burn_then", _view(), mods.primed_state(), text)
	assert_bool(bool(other["primed"])).is_false()


func test_primed_matching_is_the_one_rule_the_engine_uses() -> void:
	assert_bool(StatModifiers.matches_cast("slot_cooldown_skip.attack_single", "attack_single", "attack_single", [] as Array[String])).is_true()
	assert_bool(StatModifiers.matches_cast("slot_cooldown_skip.attack_single", "Dash", "movement", ["Dash"] as Array[String])).is_false()  # wrong slot for a skip
	assert_bool(StatModifiers.matches_cast("armor", "Dash", "movement", ["Dash"] as Array[String])).is_true()  # a tag match for a plain stat
	assert_bool(StatModifiers.matches_cast("armor", "utility", "movement", [] as Array[String])).is_false()


# --- end to end: the conditional cards really behave -----------------------------------------------------

func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	return main


func _cast(card_id: String, context: EffectContext) -> void:
	for effect: Dictionary in CardDatabase.get_card(card_id)["effects"]:
		EffectTemplates.execute(effect["template"], effect["params"], context, effect.get("condition", {}))


func test_fan_the_flames_deals_double_to_a_burning_target_and_refreshes_its_burn() -> void:
	BodyFlag.set_collide(false)
	var main := _spawn_main()
	var caster := TestCaster.new()
	main.add_child(caster)
	caster.global_position = main.player.global_position + Vector3(8.0, 0.0, 0.0)
	var burning: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	var plain: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	main.add_child(burning)
	main.add_child(plain)
	burning.global_position = caster.global_position + Vector3(-0.5, 0.0, -1.5)
	plain.global_position = caster.global_position + Vector3(0.5, 0.0, -1.5)
	burning.status_manager.apply_status("burn", StatusDatabase.get_status("burn"), 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var context := EffectContext.new(caster, main, "player")
	context.rng = RandomNumberGenerator.new()
	_cast("fire_fan_the_flames", context)
	assert_float(burning.health.get_max_health() - burning.health.current_health).is_equal_approx(20.0, 0.001)
	assert_float(plain.health.get_max_health() - plain.health.current_health).is_equal_approx(10.0, 0.001)
	assert_bool(plain.status_manager.has_status("burn")).is_true()  # everyone caught is lit
	assert_float(burning.status_manager.status_time_left("burn")).is_greater(4.5)  # refreshed to 5 s
	assert_float(plain.status_manager.status_time_left("burn")).is_less_equal(4.0)
	BodyFlag.reset()
	Juice.reset()


func test_parting_gift_leaves_its_blast_at_the_start_point() -> void:
	BodyFlag.set_collide(false)
	var main := _spawn_main()
	var caster := TestCaster.new()
	main.add_child(caster)
	caster.global_position = main.player.global_position + Vector3(8.0, 0.0, 0.0)
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	main.add_child(enemy)
	enemy.global_position = caster.global_position + Vector3(0.0, 0.0, -1.0)
	await get_tree().physics_frame
	var context := EffectContext.new(caster, main, "player")
	var parting: Dictionary = (CardDatabase.get_card("wizard_parting_gift")["effects"] as Array)[0]
	EffectTemplates.execute(parting["template"], parting["params"], context)
	caster.global_position += Vector3(5.0, 0.0, 0.0)  # the blink: far from the start point by the time the blast lands
	for i in range(50):
		await get_tree().physics_frame
	assert_float(enemy.health.get_max_health() - enemy.health.current_health).is_equal_approx(10.0, 0.001)
	BodyFlag.reset()
	Juice.reset()


# --- D39: the dodge and Movement casts ----------------------------------------------------------------------

func test_the_dodge_is_not_a_movement_cast_unless_the_one_switch_says_so() -> void:
	var relay: CombatEventsRelay = CombatLink.events()
	relay.reset()
	assert_bool(PlayerConfig.dodge_counts_as_movement_cast()).is_false()  # the shipped default (D39 = A)
	relay.notify_dodge()
	assert_bool(relay.history.cast_within(relay.now(), 2.0, "movement")).is_false()
	PlayerConfig.dodge()["counts_as_movement_cast"] = true  # option B
	relay.notify_dodge()
	assert_bool(relay.history.cast_within(relay.now(), 2.0, "movement")).is_true()
	assert_bool(SlotSynergy.is_live(CardDatabase.get_card("rogue_drive_by"), {"now": relay.now(), "history": relay.history})).is_true()
	PlayerConfig.reload()
	relay.reset()
	assert_bool(PlayerConfig.dodge_counts_as_movement_cast()).is_false()
	assert_array(PlayerConfig.validate({"dodge": {"enabled": true, "counts_as_movement_cast": "yes", "speed": 20.0, "duration": 0.25, "cooldown": 1.2, "block_ticks_after_pause": 2, "charges": 2, "min_charges": 0, "max_charges": 4}})).is_not_empty()
