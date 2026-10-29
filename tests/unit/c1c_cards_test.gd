class_name C1cCardsTest
extends GdUnitTestSuite
## C1-c: the nine new Fire Rogue cards (placeholder names), their balance against the card-beats-basic
## rule, the neutral palette rule (D11), the preset deck, and the aoe `delay` param they use.

const NEW_CARDS: Array[String] = [
	"rogue_bleed_slash", "rogue_flurry", "fire_fireball", "fire_wall", "rogue_shadow_step",
	"rogue_lunge_strike", "neutral_backward_leap", "neutral_leech", "neutral_regeneration",
]
const FIRE_ROGUE_POOLS: Array[String] = ["rogue", "fire", "neutral"]
const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"


func _statuses() -> Dictionary:
	var table := JsonDataTable.new("res://data/statuses.json")
	var statuses: Dictionary = {}
	for status_id: String in table.ids():
		statuses[status_id] = table.get_entry(status_id)
	return statuses


func _effect(card: Dictionary, template: String) -> Dictionary:
	for effect: Dictionary in card["effects"]:
		if effect["template"] == template:
			return effect["params"]
	return {}


# --- the cards exist and are valid ---------------------------------------------------------------

func test_all_nine_new_cards_load_and_validate() -> void:
	for card_id in NEW_CARDS:
		var card := CardDatabase.get_card(card_id)
		assert_bool(card.is_empty()).override_failure_message("missing card " + card_id).is_false()
		assert_array(CardSchema.validate(card)).override_failure_message(card_id).is_empty()
		assert_array(CardSchema.warnings(card)).override_failure_message(card_id + " name length").is_empty()
		assert_bool(String(card["name"]).length() <= 25).is_true()


func test_slots_and_pools_of_the_new_cards() -> void:
	var expected: Dictionary = {
		"rogue_bleed_slash": ["attack_single", "rogue"], "rogue_flurry": ["attack_single", "rogue"],
		"fire_fireball": ["attack_aoe", "fire"], "fire_wall": ["attack_aoe", "fire"],
		"rogue_shadow_step": ["movement", "rogue"], "rogue_lunge_strike": ["movement", "rogue"],
		"neutral_backward_leap": ["movement", "neutral"], "neutral_leech": ["recovery", "neutral"],
		"neutral_regeneration": ["recovery", "neutral"],
	}
	for card_id: String in expected:
		var card := CardDatabase.get_card(card_id)
		assert_str(String(card["slot_type"])).override_failure_message(card_id).is_equal(expected[card_id][0])
		assert_str(String(card["pool"])).override_failure_message(card_id).is_equal(expected[card_id][1])


func test_every_slot_of_the_fire_rogue_pool_has_at_least_three_unique_cards() -> void:
	var counts: Dictionary = {}
	for card: Dictionary in CardDatabase.all_cards():
		if FIRE_ROGUE_POOLS.has(String(card["pool"])):
			counts[card["slot_type"]] = int(counts.get(card["slot_type"], 0)) + 1
	for slot_type in SlotTypeDatabase.known_ids():
		assert_int(int(counts.get(slot_type, 0))).override_failure_message(slot_type).is_greater_equal(3)
	assert_array(DeckRules.validate_shipped_content()).is_empty()


# --- the neutral palette (D11) ---------------------------------------------------------------------

func test_neutral_cards_reference_no_class_or_element_data() -> void:
	var element_statuses: Array[String] = []
	var element_ids: Array[String] = []
	for pool_id in PoolDatabase.known_ids():
		var def := PoolDatabase.get_definition(pool_id)
		if def.get("kind", "") == "element":
			element_ids.append(pool_id)
			element_statuses.append(String((def["status"] as Dictionary)["status_id"]))
	var class_ids: Array[String] = []
	for pool_id in PoolDatabase.known_ids():
		if PoolDatabase.get_definition(pool_id).get("kind", "") == "class":
			class_ids.append(pool_id)
	var seen := 0
	for card: Dictionary in CardDatabase.all_cards():
		if card["pool"] != "neutral":
			continue
		seen += 1
		for effect: Dictionary in card["effects"]:
			var params: Dictionary = effect["params"]
			assert_str(String(params.get("damage_type", "physical"))).override_failure_message("%s uses an element damage type" % card["id"]).is_equal("physical")
			assert_bool(element_statuses.has(String(params.get("status_id", "")))).override_failure_message("%s applies an element status" % card["id"]).is_false()
			assert_bool(String(params.get("status_id", "")) in ["burn"]).is_false()
			for key: String in ["stat"]:
				var stat := String(params.get(key, ""))
				for id in class_ids + element_ids:
					assert_bool(stat.contains(id)).is_false()
		for id in class_ids + element_ids:
			assert_bool(String(card["id"]).begins_with(id + "_")).override_failure_message("%s is named for %s" % [card["id"], id]).is_false()
	assert_int(seen).is_greater_equal(6)


# --- card beats basic, and the tuning pins ------------------------------------------------------------

func test_shipped_damage_cards_including_the_new_ones_beat_the_light_attack() -> void:
	assert_array(CardDamageRule.check_shipped()).is_empty()
	for card_id in ["rogue_bleed_slash", "rogue_flurry", "fire_fireball", "fire_wall"]:
		assert_bool(CardDamageRule.is_damage_card(CardDatabase.get_card(card_id))).is_true()
		assert_str(String(CardDatabase.get_card(card_id).get("rule_exception", ""))).is_empty()  # none opted out


func test_balance_numbers_of_the_new_damage_cards() -> void:
	var statuses := _statuses()
	var light := AttackDatabase.get_attack("light")
	var light_dps: float = float(light["damage"]) / float(light["interval"])
	# card id -> [cycle seconds, per-cast damage under the rule]
	var expected: Dictionary = {
		"rogue_bleed_slash": [1.2, 7.0], "rogue_flurry": [1.3, 8.0], "fire_fireball": [3.1, 20.0], "fire_wall": [3.3, 20.0],
	}
	for card_id: String in expected:
		var card := CardDatabase.get_card(card_id)
		var base := float(SlotTypeDatabase.get_definition(String(card["slot_type"]))["base_cooldown"])
		var cycle := CardDamageRule.cycle_cooldown(card, base)
		var cast := CardDamageRule.cast_damage(card, statuses, cycle)
		assert_float(cycle).override_failure_message(card_id).is_equal_approx(float(expected[card_id][0]), 0.001)
		assert_float(cast).override_failure_message(card_id).is_equal_approx(float(expected[card_id][1]), 0.001)
		assert_float(cast / cycle).override_failure_message(card_id).is_greater(light_dps)


func test_multi_hit_and_timed_cards_fit_inside_their_own_cooldowns() -> void:
	var flurry := CardDatabase.get_card("rogue_flurry")
	var cone := _effect(flurry, "cone")
	var window := float(cone["hit_interval"]) * (int(cone["hits"]) - 1)
	assert_float(window).is_less(float(SlotTypeDatabase.get_definition("attack_single")["base_cooldown"]) + float(flurry["cooldown_modifier"]))
	# Timed buffs and statuses are shorter than the cooldown that recasts them, so none is always on.
	var timed: Dictionary = {
		"rogue_shadow_step": [float(_effect(CardDatabase.get_card("rogue_shadow_step"), "pass_through")["duration"]), "movement"],
		"neutral_leech": [float(_effect(CardDatabase.get_card("neutral_leech"), "apply_status")["duration"]), "recovery"],
		"neutral_regeneration": [float(_effect(CardDatabase.get_card("neutral_regeneration"), "apply_status")["duration"]), "recovery"],
	}
	for card_id: String in timed:
		var card := CardDatabase.get_card(card_id)
		var cooldown := float(SlotTypeDatabase.get_definition(timed[card_id][1])["base_cooldown"]) + float(card["cooldown_modifier"])
		assert_float(float(timed[card_id][0])).override_failure_message(card_id).is_less(cooldown)


func test_recovery_value_per_second_is_in_the_band_of_the_existing_recovery_cards() -> void:
	var statuses := _statuses()
	var potion := CardDatabase.get_card("neutral_healing_potion")
	var potion_hps := float(_effect(potion, "heal")["amount"]) / (8.0 + float(potion["cooldown_modifier"]))
	var nap := CardDatabase.get_card("rogue_nap_time")
	var nap_hps := float(_effect(nap, "heal")["amount"]) / (8.0 + float(nap["cooldown_modifier"]))
	var regen_card := CardDatabase.get_card("neutral_regeneration")
	var regen_def: Dictionary = statuses["regeneration"]
	var regen_params := _effect(regen_card, "apply_status")
	var regen_total := floorf(float(regen_params["duration"]) / float(regen_def["tick_interval"])) * float(regen_def["heal_per_tick"])
	var regen_hps := regen_total / (8.0 + float(regen_card["cooldown_modifier"]))
	assert_float(regen_hps).is_greater(nap_hps)
	assert_float(regen_hps).is_less_equal(potion_hps)  # slower than the instant heal
	assert_float(regen_total).is_equal_approx(14.0, 0.001)


func test_recovery_keeps_the_longest_effective_cooldown() -> void:
	var shortest_recovery := INF
	var longest_other := 0.0
	for card: Dictionary in CardDatabase.all_cards():
		var cooldown := float(SlotTypeDatabase.get_definition(String(card["slot_type"]))["base_cooldown"]) + float(card["cooldown_modifier"])
		if card["slot_type"] == "recovery":
			shortest_recovery = minf(shortest_recovery, cooldown)
		else:
			longest_other = maxf(longest_other, cooldown)
	assert_float(shortest_recovery).is_greater(longest_other)


func test_dash_cards_travel_their_data_distances() -> void:
	var lunge := _effect(CardDatabase.get_card("rogue_lunge_strike"), "dash")
	assert_float(float(lunge["distance"])).is_equal_approx(3.0, 0.001)
	assert_bool(lunge.has("damage")).is_true()
	var leap := _effect(CardDatabase.get_card("neutral_backward_leap"), "dash")
	assert_float(float(leap["distance"])).is_between(6.0, 7.0)
	assert_str(String(leap["direction_mode"])).is_equal("away_from_aim")
	assert_bool(leap.has("damage")).is_false()
	var step := CardDatabase.get_card("rogue_shadow_step")
	assert_int((step["effects"] as Array).size()).override_failure_message("pass_through only").is_equal(1)
	assert_str(String(step["effects"][0]["template"])).is_equal("pass_through")


func test_new_status_numbers_are_valid_and_tuned() -> void:
	var statuses := _statuses()
	assert_float(float(statuses["bleed"]["damage_per_tick"]) / float(statuses["bleed"]["tick_interval"])).is_equal_approx(2.0, 0.001)
	assert_str(String(statuses["bleed"]["damage_type"])).is_equal("physical")
	assert_float(float(statuses["leech"]["fraction"])).is_equal_approx(0.4, 0.001)
	assert_float(float(statuses["leech"]["max_heal_per_hit"])).is_equal_approx(3.0, 0.001)
	assert_float(float(statuses["regeneration"]["heal_per_tick"])).is_equal_approx(2.0, 0.001)


# --- the aoe delay param ---------------------------------------------------------------------------

func test_aoe_delay_schema() -> void:
	var base: Dictionary = {"damage": 5, "damage_type": "fire", "radius": 2.0, "max_range": 8.0}
	assert_array(EffectTemplates.validate_params("aoe", base.merged({"delay": 0.4}))).is_empty()
	for bad: Variant in [0.0, -1.0, 99.0, "slow", null, NAN]:
		assert_array(EffectTemplates.validate_params("aoe", base.merged({"delay": bad}))).override_failure_message(str(bad)).is_not_empty()


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	return main


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func test_a_delayed_aoe_lands_on_the_locked_spot_only_after_the_delay() -> void:
	var main := _spawn_main()
	var enemy: Enemy = (load("res://scenes/enemies/MeleeChaser.tscn") as PackedScene).instantiate()
	var bystander: Enemy = (load("res://scenes/enemies/MeleeChaser.tscn") as PackedScene).instantiate()
	main.add_child(enemy)
	main.add_child(bystander)
	enemy.global_position = Vector3(0, 0, -6.0)
	bystander.global_position = Vector3(6.0, 0, -6.0)
	await _frames(2)
	var context := EffectContext.new(main.player, main, "player")
	context.aim_point = enemy.global_position
	context.arena = main.player.get_arena_rect()
	var before := enemy.health.current_health
	EffectTemplates.execute("aoe", {"damage": 7.0, "damage_type": "fire", "radius": 1.5, "max_range": 8.0, "delay": 0.3}, context)
	assert_float(enemy.health.current_health).override_failure_message("nothing lands at cast time").is_equal(before)
	await _frames(10)
	assert_float(enemy.health.current_health).override_failure_message("still winding up").is_equal(before)
	await _frames(20)
	assert_float(enemy.health.current_health).override_failure_message("hit after the delay").is_less(before)
	assert_float(bystander.health.current_health).override_failure_message("outside the disc").is_equal(before)


func test_a_caster_that_dies_during_the_delay_cancels_the_hit() -> void:
	var main := _spawn_main()
	var enemy: Enemy = (load("res://scenes/enemies/MeleeChaser.tscn") as PackedScene).instantiate()
	main.add_child(enemy)
	enemy.global_position = main.player.global_position + Vector3(0, 0, -4.0)
	await _frames(2)
	var context := EffectContext.new(main.player, main, "player")
	context.aim_point = enemy.global_position
	context.arena = main.player.get_arena_rect()
	var before := enemy.health.current_health
	EffectTemplates.execute("aoe", {"damage": 7.0, "damage_type": "fire", "radius": 1.5, "max_range": 8.0, "delay": 0.3}, context)
	main.player.health.take_damage(10000.0)
	await _frames(40)
	assert_float(enemy.health.current_health).is_equal(before)


# --- the preset deck ---------------------------------------------------------------------------------

func test_the_preset_deck_holds_every_fire_rogue_pool_card_and_starts_unblocked() -> void:
	var main := _spawn_main()
	await _frames(1)
	var owned: Array[String] = main.player.card_slots.owned_card_ids()
	var expected: Array[String] = []
	for card: Dictionary in CardDatabase.all_cards():
		if FIRE_ROGUE_POOLS.has(String(card["pool"])):
			expected.append(String(card["id"]))
	owned.sort()
	expected.sort()
	assert_array(owned).is_equal(expected)
	for card_id in NEW_CARDS:
		assert_bool(owned.has(card_id)).override_failure_message(card_id).is_true()
	assert_bool(main.run_blocked).is_false()
	assert_bool(main.player.card_slots.deck_check().is_ok()).is_true()
