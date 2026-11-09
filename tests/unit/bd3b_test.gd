class_name Bd3bTest
extends GdUnitTestSuite
## BD3a sitting B: the four new Rogue cards, the six new relics and the Spite Knuckles retheme, each through the real effect path,
## the real relay and the real RelicManager (never by reading the JSON), plus the small engine pieces they needed: an on-hit status for
## projectiles and dashes, the dash_passed_through relay event, reduce_cooldown on the light and heavy attacks, and the slot_type filter on hit_landed.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const NEW_CARDS: Array[String] = ["rogue_cut_corners", "rogue_knife_drawer", "rogue_excuse_me", "rogue_blood_money"]
const NEW_RELICS: Array[String] = ["serrated_excuse", "salt_in_the_wound", "per_my_last_email", "chasing_paper", "muscle_memory", "overtime_unpaid"]


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


func _target(main: Node, hp: float = 100.0, at: Vector3 = Vector3.ZERO) -> RelayTarget:
	var target := RelayTarget.new("enemy", hp)
	main.add_child(target)
	target.global_position = at
	return target


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _hit(target: RelayTarget, main: Main, origin: String, kind: StringName = Health.KIND_HIT, amount: float = 1.0) -> void:
	target.hurtbox.receive_damage(amount, "physical", Vector3.ZERO, main.player, kind, origin)


func _cast(card_id: String, caster: Node3D, host: Node) -> void:
	var context := EffectContext.new(caster, host, "player")
	context.origin = "card:" + card_id
	for effect: Dictionary in CardDatabase.get_card(card_id)["effects"]:
		EffectTemplates.execute(String(effect["template"]), effect["params"], context, effect.get("condition", {}))


# --- data ---------------------------------------------------------------------------------------

func test_the_four_cards_and_six_relics_load_clean_with_the_planned_slots_and_tiers() -> void:
	var slots: Dictionary = {"rogue_cut_corners": "attack_aoe", "rogue_knife_drawer": "attack_aoe", "rogue_excuse_me": "movement", "rogue_blood_money": "recovery"}
	for id: String in NEW_CARDS:
		assert_bool(CardDatabase.has_card(id)).is_true()
		assert_str(String(CardDatabase.get_card(id)["slot_type"])).is_equal(String(slots[id]))
		assert_str(String(CardDatabase.get_card(id)["pool"])).is_equal("rogue")
	assert_array(RelicDatabase.problems()).is_empty()
	var tiers: Dictionary = {"serrated_excuse": "tier2", "salt_in_the_wound": "tier1", "per_my_last_email": "tier2", "chasing_paper": "tier1", "muscle_memory": "tier1", "overtime_unpaid": "tier2"}
	var pools: Dictionary = {"serrated_excuse": "rogue", "salt_in_the_wound": "rogue", "per_my_last_email": "rogue", "chasing_paper": "rogue", "muscle_memory": "neutral", "overtime_unpaid": "neutral"}
	for id: String in NEW_RELICS:
		var relic: Dictionary = RelicDatabase.get_relic(id)
		assert_str(String(relic["rarity"])).is_equal(String(tiers[id]))
		assert_str(String(relic["pool"])).is_equal(String(pools[id]))
		assert_array(relic["sources"]).is_equal(["elite", "relic_room", "merchant"])


func test_the_new_attack_cards_pass_the_damage_rule_on_unconditional_damage() -> void:
	assert_array(CardDamageRule.check_shipped()).is_empty()
	var slot_table := JsonDataTable.new("res://data/slot_types.json")
	var statuses: Dictionary = {"bleed": StatusDatabase.get_status("bleed")}
	var light: Dictionary = AttackDatabase.get_attack("light")
	var base: float = float(slot_table.get_raw("attack_aoe")["base_cooldown"])
	for id: String in ["rogue_cut_corners", "rogue_knife_drawer"]:
		assert_array(CardDamageRule.check_card(CardDatabase.get_card(id), base, light, statuses)).is_empty()


func test_the_new_cards_carry_the_bleed_tag_and_count_as_status_sources() -> void:
	for id: String in ["rogue_cut_corners", "rogue_knife_drawer", "rogue_excuse_me"]:
		assert_bool(CardTags.all_tags(CardDatabase.get_card(id)).has("Bleed")).override_failure_message(id).is_true()
		assert_array(CardSummary.status_ids(CardDatabase.get_card(id))).override_failure_message(id).contains(["bleed"])
	assert_bool(CardTags.all_tags(CardDatabase.get_card("rogue_knife_drawer")).has("Projectile")).is_true()
	assert_bool(CardTags.all_tags(CardDatabase.get_card("rogue_excuse_me")).has("Dash")).is_true()
	assert_bool(CardTags.all_tags(CardDatabase.get_card("rogue_cut_corners")).has("Area")).is_true()
	assert_bool(CardTags.all_tags(CardDatabase.get_card("rogue_blood_money")).has("Heal")).is_true()
	assert_bool(CardTags.all_tags(CardDatabase.get_card("rogue_blood_money")).has("Bleed")).is_false()


func test_the_new_cards_read_in_plain_words() -> void:
	assert_str(CardSummary.effect_line(CardDatabase.get_card("rogue_knife_drawer"))).contains("each hit applies Bleed")
	assert_str(CardSummary.effect_line(CardDatabase.get_card("rogue_excuse_me"))).contains("enemies you pass through get Bleed")


func test_projectile_and_dash_status_validation() -> void:
	var shot: Dictionary = {"damage": 3, "damage_type": "physical", "speed": 18.0, "max_range": 9.0, "hit_radius": 0.2}
	assert_array(EffectTemplates.validate_params("projectile", shot)).is_empty()
	shot["status_id"] = "bleed"
	assert_array(EffectTemplates.validate_params("projectile", shot)).is_not_empty()  # a status without a duration
	shot["status_duration"] = 3.0
	assert_array(EffectTemplates.validate_params("projectile", shot)).is_empty()
	shot["status_id"] = "nope"
	assert_array(EffectTemplates.validate_params("projectile", shot)).is_not_empty()
	var dash: Dictionary = {"distance": 4.0, "speed": 16.0, "status_id": "bleed", "status_duration": 4.0}
	assert_array(EffectTemplates.validate_params("dash", dash)).is_not_empty()  # no hit_radius
	dash["hit_radius"] = 0.9
	assert_array(EffectTemplates.validate_params("dash", dash)).is_empty()  # a dash may cut without dealing damage
	assert_array(EffectTemplates.validate_params("dash", {"distance": 4.0, "speed": 16.0, "hit_radius": 0.9})).is_not_empty()  # a radius with nothing to apply still needs damage


func test_reduce_cooldown_takes_exactly_one_of_slot_type_and_attack_id() -> void:
	assert_array(EffectTemplates.validate_params("reduce_cooldown", {"attack_id": "heavy", "seconds": 0.15})).is_empty()
	assert_array(EffectTemplates.validate_params("reduce_cooldown", {"slot_type": "movement", "seconds": 1.0})).is_empty()
	assert_array(EffectTemplates.validate_params("reduce_cooldown", {"slot_type": "movement", "attack_id": "heavy", "seconds": 1.0})).is_not_empty()
	assert_array(EffectTemplates.validate_params("reduce_cooldown", {"seconds": 1.0})).is_not_empty()
	assert_array(EffectTemplates.validate_params("reduce_cooldown", {"attack_id": "dodge", "seconds": 1.0})).is_not_empty()


func test_the_relay_and_schema_know_the_new_event_and_filter() -> void:
	assert_bool(RelicSchema.is_known_event("dash_passed_through")).is_true()
	var relic: Dictionary = RelicDatabase.get_relic("per_my_last_email").duplicate(true)
	assert_array(RelicSchema.validate(relic, "per_my_last_email")).is_empty()
	((relic["triggers"] as Array)[0] as Dictionary)["filter"] = {"slot_type": "not_a_slot"}
	assert_array(RelicSchema.validate(relic, "per_my_last_email")).is_not_empty()


# --- the attack controller ------------------------------------------------------------------------

func test_the_attack_controller_can_shorten_a_running_cooldown_but_not_a_ready_one() -> void:
	var defs: Dictionary = {&"heavy": AttackDatabase.get_heavy("rogue")}
	var controller := AttackController.new(defs, StatModifiers.new())
	controller.reduce_remaining(&"heavy", 1.0)
	assert_bool(controller.is_ready(&"heavy")).is_true()
	controller.tick(0.016, true, {&"heavy": true}, func(_id: StringName) -> bool: return false)
	var started: float = controller.get_progress(&"heavy")
	assert_bool(controller.is_ready(&"heavy")).is_false()
	controller.reduce_remaining(&"heavy", 0.5)
	assert_float(controller.get_progress(&"heavy")).is_greater(started)
	controller.reduce_remaining(&"heavy", 60.0)
	assert_bool(controller.is_ready(&"heavy")).is_true()


# --- cards through the real effect path -------------------------------------------------------------

func test_cutting_corners_hits_everything_around_you_and_makes_it_bleed() -> void:
	var main := _spawn_main()
	var near := _target(main, 100.0, Vector3(1.5, 0, 0.5))
	var behind := _target(main, 100.0, Vector3(-1.5, 0, 1.0))
	var far := _target(main, 100.0, Vector3(6, 0, 0))
	await _frames(2)
	_cast("rogue_cut_corners", main.player, main)
	for hit: RelayTarget in [near, behind]:
		assert_float(hit.health.current_health).is_less(100.0)
		assert_bool(hit.status_manager.has_status("bleed")).is_true()
	assert_float(far.health.current_health).is_equal(100.0)
	assert_bool(far.status_manager.has_status("bleed")).is_false()


func test_the_knife_drawer_fans_five_knives_and_each_hit_makes_the_target_bleed() -> void:
	var main := _spawn_main()
	var ahead := _target(main, 100.0, Vector3(0, 0, -5))  # on the centre knife's line
	var wide := _target(main, 100.0, Vector3(-3.0, 0, -7.0))  # about 23 degrees off the line, on the outer knife's
	var behind := _target(main, 100.0, Vector3(0, 0, 5))
	await _frames(2)
	var launched: Array[Node] = []
	main.child_entered_tree.connect(func(node: Node) -> void: if node is Projectile: launched.append(node))
	_cast("rogue_knife_drawer", main.player, main)
	assert_int(launched.size()).is_equal(5)
	await _frames(40)
	assert_bool(ahead.status_manager.has_status("bleed")).is_true()
	assert_bool(wide.status_manager.has_status("bleed")).is_true()
	assert_float(100.0 - ahead.health.current_health).is_greater_equal(3.0)
	assert_bool(behind.status_manager.has_status("bleed")).is_false()
	assert_float(behind.health.current_health).is_equal(100.0)


func test_excuse_me_makes_everything_it_passes_through_bleed_and_deals_no_damage() -> void:
	var main := _spawn_main()
	main.player.global_position = Vector3.ZERO
	var passed := _target(main, 100.0, Vector3(0, 0, -2))
	var off_line := _target(main, 100.0, Vector3(4, 0, -2))
	var beyond := _target(main, 100.0, Vector3(0, 0, -9))
	await _frames(2)
	var log := RelayLog.new(CombatEvents)
	_cast("rogue_excuse_me", main.player, main)
	await _frames(30)  # 4 m at 16 m/s is 0.25 s
	assert_bool(passed.status_manager.has_status("bleed")).is_true()
	for hit: Dictionary in log.named("hit_landed"):
		assert_str(String(hit["kind"])).is_equal(String(Health.KIND_DOT))  # the dash itself deals nothing; only Bleed ticks land
	assert_bool(off_line.status_manager.has_status("bleed")).is_false()
	assert_bool(beyond.status_manager.has_status("bleed")).is_false()
	assert_int(log.named("dash_ended").size()).is_equal(1)
	log.stop()


func test_blood_money_heals_and_starts_leech() -> void:
	var main := _spawn_main()
	var health: Health = main.player.get_node("Health")
	health.current_health = 10.0
	_cast("rogue_blood_money", main.player, main)
	assert_float(health.current_health).is_equal_approx(16.0, 0.001)
	assert_bool((main.player.get_node("StatusEffectManager") as StatusEffectManager).has_status("leech")).is_true()


# --- the dash_passed_through event ------------------------------------------------------------------

func test_a_card_dash_reports_the_enemies_it_passed_and_a_clear_dash_reports_nothing() -> void:
	var main := _spawn_main()
	main.player.global_position = Vector3.ZERO
	var in_the_way := _target(main, 100.0, Vector3(0, 0, -2))
	await _frames(2)
	var log := RelayLog.new(CombatEvents)
	var seen: Array[Dictionary] = []
	CombatEvents.dash_passed_through.connect(func(card_id: String, count: int, _at: Vector3) -> void: seen.append({"card": card_id, "count": count}))
	_cast("rogue_ugh_fine_moving", main.player, main)
	await _frames(40)
	assert_int(seen.size()).is_equal(1)
	assert_str(String(seen[0]["card"])).is_equal("rogue_ugh_fine_moving")
	assert_int(int(seen[0]["count"])).is_equal(1)
	# a second dash toward a clear lane: nothing to report
	in_the_way.queue_free()
	await _frames(2)
	main.player.global_position = Vector3(20, 0, 20)
	await _frames(2)
	seen.clear()
	_cast("rogue_ugh_fine_moving", main.player, main)
	await _frames(40)
	assert_int(seen.size()).is_equal(0)
	log.stop()


func test_the_dodge_roll_never_reports_a_pass_through() -> void:
	var main := _spawn_main()
	main.player.global_position = Vector3.ZERO
	_target(main, 100.0, Vector3(0, 0, -1.5))
	await _frames(2)
	var seen: Array[int] = []
	CombatEvents.dash_passed_through.connect(func(_card_id: String, count: int, _at: Vector3) -> void: seen.append(count))
	main.player.start_forced_move(Vector3(0, 0, -1), 14.0, 0.3, true)  # what the dodge calls: no card, no pass-through
	await _frames(30)
	assert_int(seen.size()).is_equal(0)


# --- relics ---------------------------------------------------------------------------------------------

func test_serrated_excuse_lets_the_players_bleed_stack_to_five() -> void:
	var main := _spawn_main()
	var target := _target(main, 1000.0)
	for i in range(7):
		target.status_manager.apply_status("bleed", StatusDatabase.get_status("bleed"), 4.0, main.player, "card:x")
	assert_int(target.status_manager.stacks_of("bleed")).is_equal(1)  # D25 = A: nothing stacks without a source
	var manager := _manager(main, ["serrated_excuse"] as Array[String])
	var second := _target(main, 1000.0)
	for i in range(7):
		second.status_manager.apply_status("bleed", StatusDatabase.get_status("bleed"), 4.0, main.player, "card:x")
	assert_int(second.status_manager.stacks_of("bleed")).is_equal(5)
	var burning := _target(main, 1000.0)
	for i in range(3):
		burning.status_manager.apply_status("burn", StatusDatabase.get_status("burn"), 4.0, main.player, "card:x")
	assert_int(burning.status_manager.stacks_of("burn")).is_equal(1)  # Burn is untouched
	manager.remove_relic("serrated_excuse")
	var third := _target(main, 1000.0)
	for i in range(3):
		third.status_manager.apply_status("bleed", StatusDatabase.get_status("bleed"), 4.0, main.player, "card:x")
	assert_int(third.status_manager.stacks_of("bleed")).is_equal(1)


func test_salt_in_the_wound_adds_a_quarter_to_card_hits_on_bleeding_enemies_only() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["salt_in_the_wound"] as Array[String])
	var bleeding := _target(main, 1000.0, Vector3(0, 0, -5))
	var plain := _target(main, 1000.0, Vector3(3, 0, -5))
	var burning := _target(main, 1000.0, Vector3(-3, 0, -5))
	bleeding.status_manager.apply_status("bleed", StatusDatabase.get_status("bleed"), 30.0, null, "card:x")
	burning.status_manager.apply_status("burn", StatusDatabase.get_status("burn"), 30.0, null, "card:x")
	for target: RelayTarget in [bleeding, plain, burning]:
		_hit(target, main, "card:x", Health.KIND_HIT, 10.0)
	assert_float(1000.0 - bleeding.health.current_health).is_equal_approx(12.5, 0.001)
	assert_float(1000.0 - plain.health.current_health).is_equal_approx(10.0, 0.001)
	assert_float(1000.0 - burning.health.current_health).is_equal_approx(10.0, 0.001)
	var before: float = bleeding.health.current_health
	_hit(bleeding, main, "light", Health.KIND_HIT, 10.0)  # a light attack is not a card hit
	assert_float(before - bleeding.health.current_health).is_equal_approx(10.0, 0.001)
	manager.remove_relic("salt_in_the_wound")


func test_per_my_last_email_makes_attack_single_hits_bleed_only_after_a_primer() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["per_my_last_email"] as Array[String])
	var target := _target(main, 1000.0, Vector3(0, 0, -5))
	_hit(target, main, "card:rogue_quick_slash")
	manager.flush()
	assert_bool(target.status_manager.has_status("bleed")).is_false()  # no Primer cast yet
	CombatEvents.notify_card_cast("utility", "rogue_bad_influence")  # a Primer (Keystone, Primer)
	var other_slot := _target(main, 1000.0, Vector3(3, 0, -5))
	_hit(other_slot, main, "card:rogue_everyone_calm_down")
	_hit(other_slot, main, "light")
	manager.flush()
	assert_bool(other_slot.status_manager.has_status("bleed")).is_false()  # an AoE card and a light attack are not Attack: Single
	_hit(target, main, "card:rogue_quick_slash")
	manager.flush()
	assert_bool(target.status_manager.has_status("bleed")).is_true()
	# the Primer is old news after its 6 s
	CombatEvents.step(7.0)
	var late := _target(main, 1000.0, Vector3(-3, 0, -5))
	_hit(late, main, "card:rogue_quick_slash")
	manager.flush()
	assert_bool(late.status_manager.has_status("bleed")).is_false()


func test_chasing_paper_gives_move_speed_only_after_a_dash_that_passed_an_enemy() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["chasing_paper"] as Array[String])
	main.player.global_position = Vector3.ZERO
	var base: float = main.player.stat_modifiers.apply("move_speed", 1.0)
	_target(main, 100.0, Vector3(0, 0, -2))
	await _frames(2)
	_cast("rogue_ugh_fine_moving", main.player, main)
	await _frames(40)
	manager.flush()
	assert_float(main.player.stat_modifiers.apply("move_speed", 1.0)).is_equal_approx(base * 1.3, 0.0001)
	await get_tree().create_timer(2.3, true, true).timeout
	assert_float(main.player.stat_modifiers.apply("move_speed", 1.0)).is_equal_approx(base, 0.0001)
	# a dash down a clear lane gives nothing
	main.player.global_position = Vector3(30, 0, 30)
	await _frames(2)
	_cast("rogue_ugh_fine_moving", main.player, main)
	await _frames(40)
	manager.flush()
	assert_float(main.player.stat_modifiers.apply("move_speed", 1.0)).is_equal_approx(base, 0.0001)


func test_muscle_memory_takes_a_sliver_off_the_heavy_cooldown_per_light_swing() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["muscle_memory"] as Array[String])
	var target := _target(main, 1000.0, Vector3(0, 0, -5))
	main.player.attacks.tick(0.016, true, {&"heavy": true}, func(_id: StringName) -> bool: return false)
	var interval: float = main.player.attacks.get_interval(&"heavy")
	var start: float = main.player.attacks.get_progress(&"heavy")
	_hit(target, main, "light")
	manager.flush()
	assert_float(main.player.attacks.get_progress(&"heavy") - start).is_equal_approx(0.15 / interval, 0.002)
	_hit(target, main, "heavy")  # only light hits count
	manager.flush()
	assert_float(main.player.attacks.get_progress(&"heavy") - start).is_equal_approx(0.15 / interval, 0.002)


func test_overtime_speeds_the_light_attack_and_slows_every_card_slot() -> void:
	var main := _spawn_main()
	var light_before: float = main.player.attacks.get_interval(&"light")
	var cooldowns: Dictionary = {}
	for slot_type: String in CardSlotController.SLOT_TYPE_ORDER:
		cooldowns[slot_type] = main.player.stat_modifiers.apply("slot_cooldown." + slot_type, 10.0)
	var manager := _manager(main, ["overtime_unpaid"] as Array[String])
	assert_float(main.player.attacks.get_interval(&"light")).is_equal_approx(light_before * 0.75, 0.0001)
	for slot_type: String in CardSlotController.SLOT_TYPE_ORDER:
		assert_float(main.player.stat_modifiers.apply("slot_cooldown." + slot_type, 10.0)).is_equal_approx(float(cooldowns[slot_type]) * 1.1, 0.0001)
	manager.remove_relic("overtime_unpaid")
	assert_float(main.player.attacks.get_interval(&"light")).is_equal_approx(light_before, 0.0001)


func test_the_new_relics_state_their_rule_in_one_line() -> void:
	for id: String in NEW_RELICS:
		var rule: String = String(RelicDatabase.get_relic(id)["rule_text"])
		assert_bool(rule.length() > 10 and rule.length() <= RelicSchema.MAX_RULE_TEXT_LENGTH).override_failure_message(id).is_true()


# --- the debug decks --------------------------------------------------------------------------------------

func test_the_two_bd3a_decks_are_legal_and_hold_their_core() -> void:
	var directory: Dictionary = DebugDecks.read_dir()
	assert_array((directory["load_problems"] as Array)).is_empty()
	assert_array((directory["problems"] as Dictionary).keys()).is_empty()
	var presets: Dictionary = directory["presets"]
	var bleed_out: Dictionary = presets["rogue-bleed-out"]
	var brawler: Dictionary = presets["rogue-grudge-brawler"]
	assert_str(String(bleed_out["class"])).is_equal("rogue")
	assert_str(String(brawler["class"])).is_equal("rogue")
	for id: String in ["rogue_open_a_vein", "rogue_paper_cuts", "rogue_bad_influence", "rogue_cut_corners", "rogue_knife_drawer", "rogue_excuse_me", "rogue_blood_money"]:
		assert_array(bleed_out["starter"]).contains([id])
	for id: String in ["rogue_warm_up", "rogue_quick_slash", "rogue_overhand_whatever"]:
		assert_array(brawler["starter"]).contains([id])
	var fire: int = 0
	for id: String in bleed_out["starter"]:
		if String(CardDatabase.get_card(id)["pool"]) == "fire":
			fire += 1
	assert_int(fire).is_less_equal(2)  # BUILD_DEPTH 9a: the Bleed Out deck needs no more than 2 Fire cards (it has none)
	assert_int(DebugDecks.pool_counts(bleed_out["starter"]).get("fire", 0)).is_equal(0)


# --- D43 = B: the offer lean ----------------------------------------------------------------------------------

func _fixture_cards() -> Array:
	var cards: Array = []
	for i in range(4):
		cards.append({"id": "bleed_%d" % i, "pool": "rogue", "slot_type": "attack_single", "effects": [{"template": "apply_status", "params": {"status_id": "bleed", "duration": 3.0}}]})
	for i in range(4):
		cards.append({"id": "plain_%d" % i, "pool": "rogue", "slot_type": "attack_single", "effects": [{"template": "cone", "params": {"damage": 5}}]})
	cards.append({"id": "burn_0", "pool": "rogue", "slot_type": "attack_single", "effects": [{"template": "apply_status", "params": {"status_id": "burn", "duration": 3.0}}]})
	cards.append({"id": "both_0", "pool": "rogue", "slot_type": "attack_single", "effects": [
		{"template": "apply_status", "params": {"status_id": "bleed", "duration": 3.0}}, {"template": "apply_status", "params": {"status_id": "burn", "duration": 3.0}}]})
	cards.append({"id": "vein", "pool": "rogue", "slot_type": "attack_single", "effects": [{"template": "detonate_status", "params": {"status_id": "bleed", "multiplier": 2.0}}]})
	return cards


func _share(deck: Array, id: String, rewards: Dictionary, seeds: int = 600) -> float:
	var hits: int = 0
	var total: int = 0
	for run_seed in range(1, seeds + 1):
		for offered: String in RewardOffer.generate(run_seed, 1, deck, _fixture_cards(), ["rogue"], {}, rewards):
			total += 1
			hits += 1 if offered == id else 0
	return float(hits) / float(total)


func test_the_lean_is_off_by_default_so_an_old_config_gives_the_old_offers() -> void:
	var deck: Array = ["bleed_0", "bleed_1"]
	var old: Dictionary = {"offer_size": 3, "unowned_weight": 4.0, "owned_weight": 1.0}
	var zero: Dictionary = old.duplicate()
	zero["status_lean"] = 0.0
	zero["status_lean_max"] = 3.0
	for run_seed in range(1, 40):
		assert_array(RewardOffer.generate(run_seed, 2, deck, _fixture_cards(), ["rogue"], {}, old)).is_equal(RewardOffer.generate(run_seed, 2, deck, _fixture_cards(), ["rogue"], {}, zero))
	assert_float(RunConfig.rewards().get("status_lean", -1.0) as float).is_equal(0.25)  # the shipped values
	assert_float(RunConfig.rewards().get("status_lean_max", -1.0) as float).is_equal(3.0)


func test_an_unowned_card_applying_a_status_the_deck_applies_is_offered_more_often() -> void:
	var deck: Array = ["bleed_0", "bleed_1"]  # n_bleed = 2
	var base: Dictionary = {"offer_size": 3, "unowned_weight": 4.0, "owned_weight": 1.0}
	var leaning: Dictionary = base.duplicate()
	leaning["status_lean"] = 0.25
	leaning["status_lean_max"] = 3.0
	var before: float = _share(deck, "bleed_2", base)
	var after: float = _share(deck, "bleed_2", leaning)
	assert_float(after).is_greater(before * 1.2)  # weight x1.5
	# a card with no status and a card that applies a status the deck does not have are not helped
	assert_float(_share(deck, "plain_0", leaning)).is_less(_share(deck, "plain_0", base))
	assert_float(_share(deck, "burn_0", leaning)).is_less(_share(deck, "burn_0", base) * 1.05)


func test_the_factor_is_one_plus_lean_times_the_owned_count_capped_and_a_detonate_is_not_a_source() -> void:
	var cards: Dictionary = {}
	for card: Dictionary in _fixture_cards():
		cards[String(card["id"])] = card
	var deck_cards: Array[Dictionary] = [cards["bleed_0"], cards["bleed_1"], cards["both_0"], cards["vein"], cards["plain_0"]]
	var counts: Dictionary = RewardOffer.status_counts(deck_cards)
	assert_int(int(counts["bleed"])).is_equal(3)  # bleed_0, bleed_1 and both_0; Open-a-Vein style detonates do not count
	assert_int(int(counts["burn"])).is_equal(1)
	assert_float(RewardOffer.lean_for(cards["bleed_2"], counts, 0.25, 3.0)).is_equal_approx(1.75, 0.0001)
	assert_float(RewardOffer.lean_for(cards["bleed_2"], counts, 1.0, 3.0)).is_equal_approx(3.0, 0.0001)  # capped
	assert_float(RewardOffer.lean_for(cards["plain_1"], counts, 0.25, 3.0)).is_equal(1.0)
	assert_float(RewardOffer.lean_for(cards["vein"], counts, 0.25, 3.0)).is_equal(1.0)  # a detonate applies nothing
	assert_float(RewardOffer.lean_for(cards["both_0"], counts, 0.25, 3.0)).is_equal_approx(1.75, 0.0001)  # the best of its statuses, not the product


func test_owned_cards_and_the_element_pools_own_status_are_not_leaned() -> void:
	var deck: Array = ["bleed_0", "bleed_1"]
	var base: Dictionary = {"offer_size": 3, "unowned_weight": 4.0, "owned_weight": 1.0}
	var leaning: Dictionary = base.duplicate()
	leaning["status_lean"] = 0.5
	# owned copies keep weight 1: their share does not rise with the lean
	assert_float(_share(deck, "bleed_0", leaning)).is_less(_share(deck, "bleed_0", base) * 1.05)
	# a Fire pool's own status (pool_defs) is not an owned card: n_burn stays 0, so a Burn card is not helped
	var defs: Dictionary = {"fire": {"status": {"status_id": "burn", "base_chance": 0.2}}}
	var hits_off: int = 0
	var hits_on: int = 0
	for run_seed in range(1, 400):
		hits_off += 1 if RewardOffer.generate(run_seed, 1, deck, _fixture_cards(), ["rogue", "fire"], defs, base).has("burn_0") else 0
		hits_on += 1 if RewardOffer.generate(run_seed, 1, deck, _fixture_cards(), ["rogue", "fire"], defs, leaning).has("burn_0") else 0
	assert_int(hits_on).is_less_equal(hits_off + 2)


func test_run_config_validates_the_lean_keys_and_an_old_block_without_them_stays_valid() -> void:
	var cards: Array[String] = []
	var config: Dictionary = RunConfig.get_config().duplicate(true)
	assert_array(RunConfig.validate(config, [], cards)).is_empty()
	(config["rewards"] as Dictionary).erase("status_lean")
	(config["rewards"] as Dictionary).erase("status_lean_max")
	assert_array(RunConfig.validate(config, [], cards)).is_empty()  # an old save or config without the keys
	for bad: Variant in [-0.1, 11, "x", null]:
		var broken: Dictionary = RunConfig.get_config().duplicate(true)
		(broken["rewards"] as Dictionary)["status_lean"] = bad
		assert_array(RunConfig.validate(broken, [], cards)).override_failure_message("status_lean %s" % str(bad)).is_not_empty()
	for bad: Variant in [0.5, 101, "x"]:
		var broken: Dictionary = RunConfig.get_config().duplicate(true)
		(broken["rewards"] as Dictionary)["status_lean_max"] = bad
		assert_array(RunConfig.validate(broken, [], cards)).override_failure_message("status_lean_max %s" % str(bad)).is_not_empty()


# --- the plan-aware relic picks -----------------------------------------------------------------------------------

func _relic_options(ids: Array[String]) -> Array:
	var options: Array = []
	for id: String in ids:
		options.append({"kind": "relic", "id": id, "enabled": true, "keywords": RelicDatabase.get_relic(id).get("keywords", [])})
	options.append({"kind": "relic_skip", "id": "skip"})
	return options


func test_the_bot_takes_a_bleed_relic_when_the_deck_is_a_bleed_deck() -> void:
	var deck: Array[String] = ["rogue_bleed_slash", "rogue_paper_cuts", "rogue_cut_corners", "rogue_quick_slash"]
	var options: Array = _relic_options(["asap_notice", "salt_in_the_wound", "pyre_insurance"] as Array[String])
	assert_str(RelicPolicy.offer_choice(options, deck)).is_equal("salt_in_the_wound")
	assert_str(RelicPolicy.offer_choice(options, ["rogue_quick_slash"] as Array[String])).is_equal("asap_notice")  # no plan: the first offered


func test_the_bot_takes_a_basic_attack_relic_when_the_deck_buffs_the_basic_attacks() -> void:
	var brawler: Array[String] = ["rogue_quick_slash", "rogue_warm_up", "rogue_nap_time"]
	assert_bool(RelicPolicy.plays_basic_attacks(brawler)).is_true()
	assert_bool(RelicPolicy.plays_basic_attacks(["rogue_quick_slash", "rogue_bad_influence"] as Array[String])).is_false()
	var options: Array = _relic_options(["asap_notice", "overtime_unpaid", "pyre_insurance"] as Array[String])
	assert_str(RelicPolicy.offer_choice(options, brawler)).is_equal("overtime_unpaid")
	assert_str(RelicPolicy.offer_choice(options, ["rogue_quick_slash"] as Array[String])).is_equal("asap_notice")
	for id: String in ["muscle_memory", "overtime_unpaid", "spite_knuckles", "heavy_sigh"]:
		assert_bool(RelicPolicy.is_basic_attack_relic(RelicDatabase.get_relic(id))).override_failure_message(id).is_true()
	for id: String in ["serrated_excuse", "salt_in_the_wound", "chasing_paper", "asap_notice", "pyre_insurance"]:
		assert_bool(RelicPolicy.is_basic_attack_relic(RelicDatabase.get_relic(id))).override_failure_message(id).is_false()


func test_a_trigger_aimed_at_an_enemy_that_was_freed_before_it_runs_does_not_error() -> void:
	# The trigger runs deferred; by then a killed enemy has been freed. This was a script error ("Trying to cast a freed object") in the wave sim.
	var main := _spawn_main()
	var manager := _manager(main, ["spite_knuckles"] as Array[String])
	var victim := _target(main, 100.0, Vector3(0, 0, -5))
	victim.free()
	for i in range(4):
		manager.handle_event({"event": "hit_landed", "target": victim, "amount": 1.0, "damage_type": "physical", "kind": "hit", "origin": "light", "position": Vector3.ZERO, "tags": [] as Array[String], "slot_type": ""})
	manager.flush()
	assert_bool(is_instance_valid(manager)).is_true()


func test_a_fan_of_identical_shots_reads_once_with_a_count() -> void:
	var line: String = CardSummary.effect_line(CardDatabase.get_card("rogue_knife_drawer"))
	assert_str(line).starts_with("5 times: 3 physical damage (shot), each hit applies Bleed for 3 s")
	assert_int(line.count("physical damage")).is_equal(1)
	# distinct neighbours are not merged
	assert_bool(CardSummary.effect_line(CardDatabase.get_card("rogue_cut_corners")).contains(" times: ")).is_false()


func test_with_no_plan_match_the_bot_prefers_a_relic_that_works_in_any_deck() -> void:
	var burn_deck: Array[String] = ["fire_ember_whatever", "fire_fine_burn_then", "rogue_quick_slash"]  # fewer than 3 Burn cards: no keyword plan
	var options: Array = _relic_options(["serrated_excuse", "chasing_paper", "asap_notice"] as Array[String])
	assert_str(RelicPolicy.offer_choice(options, burn_deck)).is_equal("asap_notice")  # the Bleed and Dash relics do nothing here
	var only_off_plan: Array = _relic_options(["serrated_excuse", "chasing_paper"] as Array[String])
	assert_str(RelicPolicy.offer_choice(only_off_plan, burn_deck)).is_equal("serrated_excuse")  # nothing generic: the first offered, as before
