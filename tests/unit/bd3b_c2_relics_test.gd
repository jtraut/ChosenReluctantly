class_name Bd3bC2RelicsTest
extends GdUnitTestSuite
## BD3b sitting C2: the player_damaged attacker and melee fields, the has_bonus_armor condition, the event_amount scale, the
## swap_penalty_mult stat, and the four relics built on them (Exit Strategy, Thorned Boundary, Reading List, Filing Cabinet).

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"


func before_test() -> void:
	BodyFlag.set_collide(false)
	CombatEvents.reset()
	RelicDatabase.load_all()


func after_test() -> void:
	BodyFlag.reset()
	CombatEvents.reset()
	Juice.reset()
	GamePause.reset()
	Engine.time_scale = 1.0


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	return main


func _manager(main: Main, ids: Array[String]) -> RelicManager:
	var manager := RelicManager.new()
	main.add_child(manager)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	manager.configure(main.player, main, rng, CombatEvents)
	manager.load_relics(ids)
	return manager


func _enemy(main: Main, at: Vector3, hp: float = 100.0) -> RelayTarget:
	var enemy := RelayTarget.new("enemy", hp)
	main.add_child(enemy)
	enemy.global_position = at
	return enemy


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


# --- data ----------------------------------------------------------------------------------------

func test_the_four_relics_load_with_the_wanted_pools_tiers_and_sources() -> void:
	var expected: Dictionary = {"exit_strategy": ["fire", "tier1"], "thorned_boundary": ["neutral", "tier2"], "reading_list": ["wizard", "tier2"], "filing_cabinet": ["wizard", "tier1"]}
	for id: String in expected.keys():
		var relic: Dictionary = RelicDatabase.get_relic(id)
		assert_bool(relic.is_empty()).override_failure_message("%s did not load" % id).is_false()
		assert_str(String(relic["pool"])).is_equal(String((expected[id] as Array)[0]))
		assert_str(String(relic["rarity"])).is_equal(String((expected[id] as Array)[1]))
		assert_array(relic["sources"]).is_equal(["elite", "relic_room", "merchant"])
		assert_array(RelicSchema.validate(relic, id)).is_empty()


func test_thorned_boundary_says_halved_on_elites() -> void:
	assert_str(String(RelicDatabase.get_relic("thorned_boundary")["rule_text"])).contains("(halved on elites)")


func test_the_attacker_target_and_melee_filter_are_only_for_player_damaged() -> void:
	var relic: Dictionary = RelicDatabase.get_relic("thorned_boundary").duplicate(true)
	((relic["triggers"] as Array)[0] as Dictionary)["event"] = "hit_landed"
	var errors: Array[String] = RelicSchema.validate(relic, "thorned_boundary")
	assert_bool(errors.any(func(e: String) -> bool: return e.contains("has no attacker"))).is_true()
	assert_bool(errors.any(func(e: String) -> bool: return e.contains("unknown key 'melee'"))).is_true()


func test_a_scale_by_event_amount_is_for_relic_triggers_only() -> void:
	var effect: Dictionary = {"template": "aoe", "params": {"damage": 0.1, "damage_type": "neutral", "radius": 1.0}, "scale": {"by": "event_amount", "per": 0.1}}
	var card_errors: Array[String] = []
	CardSchema._validate_effect(effect, 0, card_errors)
	assert_bool(card_errors.any(func(e: String) -> bool: return e.contains("relic triggers only"))).is_true()
	var relic: Dictionary = RelicDatabase.get_relic("exit_strategy").duplicate(true)
	((relic["triggers"] as Array)[0] as Dictionary)["effects"] = [effect]
	assert_bool(RelicSchema.validate(relic, "exit_strategy").any(func(e: String) -> bool: return e.contains("carries an amount"))).is_true()


func test_event_amount_scale_is_a_floored_fraction_of_the_hit() -> void:
	var context := EffectContext.new(null, null)
	context.event_amount = 20.0
	var scaled: Dictionary = EffectScale.apply({"by": "event_amount", "per": 0.1}, "aoe", {"damage": 0.1}, context)
	assert_float(float(scaled["damage"])).is_equal_approx(2.0, 0.0001)
	context.event_amount = 0.5
	scaled = EffectScale.apply({"by": "event_amount", "per": 0.1}, "aoe", {"damage": 0.1}, context)
	assert_float(float(scaled["damage"])).is_equal_approx(0.1, 0.0001)


# --- the event fields -------------------------------------------------------------------------------

func test_an_enemy_melee_cone_reports_the_attacker_and_melee_true() -> void:
	var main := _spawn_main()
	var log := RelayLog.new(CombatEvents)
	var enemy := _enemy(main, Vector3(0, 0, 2))
	main.player.global_position = Vector3.ZERO
	enemy.look_at(main.player.global_position, Vector3.UP)
	var context := EffectContext.new(enemy, main, "enemy")
	context.origin = "enemy"
	EffectTemplates.execute("cone", {"damage": 4.0, "damage_type": "physical", "range": 4.0, "half_angle_degrees": 60.0}, context)
	var damaged := log.named("player_damaged")
	assert_int(damaged.size()).is_equal(1)
	assert_bool(bool(damaged[0]["melee"])).is_true()
	assert_object(damaged[0]["attacker"]).is_same(enemy)


func test_an_enemy_projectile_reports_the_attacker_and_melee_false() -> void:
	var main := _spawn_main()
	var log := RelayLog.new(CombatEvents)
	var enemy := _enemy(main, Vector3(0, 0, 3))
	main.player.global_position = Vector3.ZERO
	enemy.look_at(main.player.global_position, Vector3.UP)
	var context := EffectContext.new(enemy, main, "enemy")
	context.origin = "enemy"
	EffectTemplates.execute("projectile", {"damage": 4.0, "damage_type": "physical", "speed": 30.0, "max_range": 10.0, "hit_radius": 0.8}, context)
	await _frames(30)
	var damaged := log.named("player_damaged")
	assert_int(damaged.size()).is_equal(1)
	assert_bool(bool(damaged[0]["melee"])).is_false()
	assert_object(damaged[0]["attacker"]).is_same(enemy)


func test_a_status_tick_is_not_melee_and_has_no_attacker() -> void:
	var main := _spawn_main()
	var log := RelayLog.new(CombatEvents)
	main.player.health.take_damage(3.0, "fire", Vector3.ZERO, null, Health.KIND_DOT, "status:burn")
	var damaged := log.named("player_damaged")
	assert_int(damaged.size()).is_equal(1)
	assert_bool(bool(damaged[0]["melee"])).is_false()
	assert_object(damaged[0]["attacker"]).is_null()


# --- Thorned Boundary ---------------------------------------------------------------------------------

func _hit_player_in_melee(main: Main, enemy: RelayTarget, amount: float) -> void:
	main.player.health.take_damage(amount, "neutral", Vector3.ZERO, enemy, Health.KIND_HIT, "enemy", true)


func test_thorned_boundary_stuns_and_reflects_a_tenth_with_bonus_armor() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["thorned_boundary"] as Array[String])
	main.player.stat_modifiers.add_modifier("armor", "test_ward", StatModifiers.ADDITIVE, 10.0)
	var enemy := _enemy(main, Vector3(5, 0, 0), 100.0)
	main.player.global_position = Vector3.ZERO
	await _frames(2)
	var before: float = main.player.health.current_health
	_hit_player_in_melee(main, enemy, 10.0)
	manager.flush()
	var taken: float = before - main.player.health.current_health
	assert_float(taken).is_greater(1.0)
	assert_bool(enemy.status_manager.has_status("stun")).is_true()
	assert_float(100.0 - enemy.health.current_health).is_equal_approx(taken * 0.1, 0.01)


func test_thorned_boundary_is_quiet_without_bonus_armor() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["thorned_boundary"] as Array[String])
	var enemy := _enemy(main, Vector3(5, 0, 0), 100.0)
	await _frames(2)
	_hit_player_in_melee(main, enemy, 10.0)
	manager.flush()
	assert_bool(enemy.status_manager.has_status("stun")).is_false()
	assert_float(enemy.health.current_health).is_equal(100.0)


func test_thorned_boundary_ignores_a_ranged_hit_and_hits_only_the_attacker() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["thorned_boundary"] as Array[String])
	main.player.stat_modifiers.add_modifier("armor", "test_ward", StatModifiers.ADDITIVE, 10.0)
	var attacker := _enemy(main, Vector3(5, 0, 0), 100.0)
	var bystander := _enemy(main, Vector3(5, 0, 3), 100.0)
	await _frames(2)
	main.player.health.take_damage(10.0, "neutral", Vector3.ZERO, attacker, Health.KIND_HIT, "enemy", false)
	manager.flush()
	assert_bool(attacker.status_manager.has_status("stun")).is_false()
	_hit_player_in_melee(main, attacker, 10.0)
	manager.flush()
	assert_bool(attacker.status_manager.has_status("stun")).is_true()
	assert_float(bystander.health.current_health).is_equal(100.0)
	assert_bool(bystander.status_manager.has_status("stun")).is_false()


func test_thorned_boundary_with_the_attacker_already_gone_does_nothing() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["thorned_boundary"] as Array[String])
	main.player.stat_modifiers.add_modifier("armor", "test_ward", StatModifiers.ADDITIVE, 10.0)
	var bystander := _enemy(main, Vector3.ZERO, 100.0)  # standing on the player: an aoe that fell back to the player would hit it
	await _frames(2)
	manager.handle_event({"event": "player_damaged", "amount": 10.0, "origin": "enemy", "melee": true, "attacker": null})
	manager.flush()
	assert_float(bystander.health.current_health).is_equal(100.0)


# --- Exit Strategy ----------------------------------------------------------------------------------------

func test_exit_strategy_lays_a_fire_line_along_a_dash() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["exit_strategy"] as Array[String])
	main.player.global_position = Vector3(4, 0, 0)
	manager.handle_event({"event": "dash_ended", "card_id": "x", "position": Vector3(4, 0, 0), "path_start": Vector3(0, 0, 0), "origin": ""})
	manager.flush()
	var zones: ZoneManager = ZoneManager.find_in_world(main)
	assert_object(zones).is_not_null()
	assert_int(zones.live_count_for(main.player.get_instance_id())).is_equal(1)


# --- Reading List ------------------------------------------------------------------------------------------

func test_reading_list_lifts_the_charge_cap_to_15() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["reading_list"] as Array[String])
	var status_manager: StatusEffectManager = main.player.get_node("StatusEffectManager") as StatusEffectManager
	for i in range(20):
		status_manager.apply_status("charge", StatusDatabase.get_status("charge"), 30.0, main.player, "card:x")
	assert_int(status_manager.stacks_of("charge")).is_equal(15)
	assert_bool(manager.has_relic("reading_list")).is_true()


# --- Filing Cabinet --------------------------------------------------------------------------------------------

func _slot_after_swap(controller: CardSlotController, slot_type: String) -> float:
	var slot: CardSlot = controller.get_slot(slot_type)
	slot.cooldown_remaining = 0.0
	assert_bool(controller.try_swap(slot_type)).is_true()
	return slot.cooldown_remaining


func test_filing_cabinet_frees_utility_and_movement_swaps_but_not_attack() -> void:
	var main := _spawn_main()
	var controller: CardSlotController = main.player.card_slots
	_manager(main, ["filing_cabinet"] as Array[String])
	assert_float(_slot_after_swap(controller, "utility")).is_equal(0.0)
	assert_float(_slot_after_swap(controller, "movement")).is_equal(0.0)
	assert_float(_slot_after_swap(controller, "attack_single")).is_equal_approx(RunConfig.swap_penalty(), 0.0001)


func test_without_filing_cabinet_swaps_cost_the_ordinary_penalty() -> void:
	var main := _spawn_main()
	var controller: CardSlotController = main.player.card_slots
	assert_float(_slot_after_swap(controller, "utility")).is_equal_approx(RunConfig.swap_penalty(), 0.0001)


func test_filing_cabinet_zeroes_the_curse_penalty_on_utility_and_attack_keeps_it() -> void:
	var main := _spawn_main()
	var controller: CardSlotController = main.player.card_slots
	_manager(main, ["filing_cabinet"] as Array[String])
	var utility_curse: String = ""
	var attack_curse: String = ""
	for card: Variant in CardDatabase.all_cards():
		var data: Dictionary = card
		if not CardSchema.is_curse(data):
			continue
		if String(data["slot_type"]) == "utility" and utility_curse.is_empty():
			utility_curse = String(data["id"])
		elif String(data["slot_type"]) == "attack_single" and attack_curse.is_empty():
			attack_curse = String(data["id"])
	assert_str(utility_curse).is_not_empty()
	assert_str(attack_curse).is_not_empty()
	var utility: CardSlot = controller.get_slot("utility")
	utility.current_card_id = utility_curse
	assert_float(utility.current_swap_penalty()).is_equal_approx(RunConfig.curse_swap_penalty(), 0.0001)
	assert_float(utility.current_swap_penalty(main.player.stat_modifiers)).is_equal(0.0)
	var attack: CardSlot = controller.get_slot("attack_single")
	attack.current_card_id = attack_curse
	assert_float(attack.current_swap_penalty(main.player.stat_modifiers)).is_equal_approx(RunConfig.curse_swap_penalty(), 0.0001)


# --- Hot Streak and its engine ------------------------------------------------------------------------------------

func test_hot_streak_validates_and_a_fire_pool_card_carries_the_fire_tag() -> void:
	var relic: Dictionary = RelicDatabase.get_relic("hot_streak")
	assert_bool(relic.is_empty()).is_false()
	assert_array(RelicSchema.validate(relic, "hot_streak")).is_empty()
	assert_array(relic["sources"]).is_equal(["elite", "relic_room", "merchant"])
	assert_bool(CardTags.is_known_tag("Fire")).is_true()
	assert_bool(CardDatabase.has_tag("fire_fireball", "Fire")).is_true()
	assert_bool(CardDatabase.has_tag("fire_fireball", "Bleed")).is_false()


func test_count_within_counts_casts_in_the_window() -> void:
	var history := CastHistory.new()
	history.record(1.0, "attack_single", "a", ["Fire"] as Array[String])
	history.record(2.0, "utility", "b", ["Fire"] as Array[String])
	history.record(3.0, "movement", "c", ["Dash"] as Array[String])
	history.record(4.0, "attack_aoe", "d", ["Fire"] as Array[String])
	assert_int(history.count_within(4.0, 4.0, "", "Fire")).is_equal(3)
	assert_int(history.count_within(4.0, 2.5, "", "Fire")).is_equal(2)
	assert_int(history.count_within(4.0, 4.0, "", "Fire", 2)).is_equal(2)  # stops at the limit
	assert_bool(history.cast_within(4.0, 0.5, "movement")).is_false()


func test_a_trigger_condition_neither_counts_nor_starts_the_cooldown_while_false() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["hot_streak"] as Array[String])
	var fired: Array[String] = []
	manager.effect_runner = func(_trigger: Dictionary, _event: Dictionary) -> void: fired.append("x")
	var event: Dictionary = {"event": "card_cast", "slot_type": "attack_single", "card_id": "fire_fireball", "tags": ["Fire"], "origin": ""}
	# One and two Fire casts in the history: the condition is false, so nothing fires and no 8 s cooldown starts.
	CombatEvents.notify_card_cast("attack_single", "fire_fireball")
	manager.handle_event(event)
	CombatEvents.notify_card_cast("attack_single", "fire_fireball")
	manager.handle_event(event)
	manager.flush()
	assert_int(fired.size()).is_equal(0)
	CombatEvents.notify_card_cast("attack_single", "fire_fireball")
	manager.handle_event(event)
	manager.flush()
	assert_int(fired.size()).is_equal(1)
	# The 8 s internal cooldown: a fourth Fire cast right away does not fire again.
	CombatEvents.notify_card_cast("attack_single", "fire_fireball")
	manager.handle_event(event)
	manager.flush()
	assert_int(fired.size()).is_equal(1)


func test_hot_streak_resets_the_attack_aoe_cooldown_on_the_third_fire_cast() -> void:
	var main := _spawn_main()
	_manager(main, ["hot_streak"] as Array[String])
	var slot: CardSlot = main.player.card_slots.get_slot("attack_aoe")
	slot.cooldown_remaining = 2.0
	for i in range(3):
		CombatEvents.notify_card_cast("attack_single", "fire_fireball")
	await _frames(2)
	assert_float(slot.cooldown_remaining).is_equal(0.0)


func test_hot_streak_ignores_non_fire_casts() -> void:
	var main := _spawn_main()
	_manager(main, ["hot_streak"] as Array[String])
	var slot: CardSlot = main.player.card_slots.get_slot("attack_aoe")
	slot.cooldown_remaining = 2.0
	for i in range(3):
		CombatEvents.notify_card_cast("movement", "rogue_bleed_slash")
	await _frames(2)
	assert_float(slot.cooldown_remaining).is_greater(1.0)
