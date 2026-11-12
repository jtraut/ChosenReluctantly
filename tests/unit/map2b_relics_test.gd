class_name Map2bRelicsTest
extends GdUnitTestSuite
## MAP2-B: the seven relics added for the merchant (data/relics) and the generic pieces they use (the hit_landed `tag` filter, the
## `damage_mult` stat, run-stat scaled modifiers). Each relic is checked through the real RelicManager, relay and effect templates.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const POOL_RELICS: Array[String] = ["asap_notice", "severance_package", "paperwork_fire", "grading_curve"]
const SHOP_ONLY: Array[String] = ["liquidate_assets", "request_for_quotation", "as_per_the_attached_document"]


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


func _target(main: Main, hp: float = 100.0, at: Vector3 = Vector3.ZERO) -> RelayTarget:
	var target := RelayTarget.new("enemy", hp)
	main.add_child(target)
	target.global_position = at
	return target


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _hit(target: RelayTarget, main: Main, origin: String, kind: StringName = Health.KIND_HIT, amount: float = 1.0, damage_type: String = "physical") -> void:
	target.hurtbox.receive_damage(amount, damage_type, Vector3.ZERO, main.player, kind, origin)


func _bleed(target: RelayTarget) -> void:
	target.status_manager.apply_status("bleed", StatusDatabase.get_status("bleed"), 30.0, null, "card:x")


# --- the data ------------------------------------------------------------------------------------

func test_the_seven_new_relics_load_clean_with_the_right_pool_tier_and_sources() -> void:
	assert_array(RelicDatabase.problems()).is_empty()
	var expected: Dictionary = {
		"asap_notice": ["neutral", "tier1"], "severance_package": ["rogue", "tier2"], "paperwork_fire": ["wizard", "tier1"], "grading_curve": ["wizard", "tier2"],
		"liquidate_assets": ["neutral", "tier2"], "request_for_quotation": ["neutral", "tier1"], "as_per_the_attached_document": ["neutral", "tier2"],
	}
	for id: String in expected.keys():
		var relic: Dictionary = RelicDatabase.get_relic(id)
		assert_bool(relic.is_empty()).override_failure_message("%s is missing" % id).is_false()
		assert_str(String(relic["pool"])).is_equal((expected[id] as Array)[0])
		assert_str(String(relic["rarity"])).is_equal((expected[id] as Array)[1])
		assert_bool(String(relic["rule_text"]).length() <= RelicSchema.MAX_RULE_TEXT_LENGTH).is_true()
		assert_str(String(relic["flavor_text"])).is_not_empty()
	for id: String in POOL_RELICS:
		assert_array(RelicDatabase.get_relic(id)["sources"]).is_equal(["elite", "relic_room", "merchant"])
		assert_bool(Merchant.is_shop_only(RelicDatabase.get_relic(id))).is_false()
	for id: String in SHOP_ONLY:
		assert_array(RelicDatabase.get_relic(id)["sources"]).is_equal(["merchant"])
		assert_bool(Merchant.is_shop_only(RelicDatabase.get_relic(id))).is_true()


func test_each_class_can_be_offered_eight_relics_from_elites_and_eleven_at_the_merchant() -> void:
	var weights: Dictionary = RelicConfig.tier_weights_for_act(1)
	var rng := RandomNumberGenerator.new()
	var empty: Array[String] = []
	var tiers: Array[String] = ["tier1", "tier2"]
	for who: String in ["rogue", "wizard"]:
		var pools: Array[String] = CharacterDatabase.pools(who)
		var extra: int = 8 if who == "rogue" else 7  # MAP3b B: + Desk Slam and Adrenaline Vial (both classes), and the Wizard's cc: All Staff, Office Supplies and Ergonomic Chair
		#  # BD3a: six new rogue and neutral relics; the Wizard sees only the two neutral ones
		var elite: Array[String] = RelicOffer.offer("elite", 30, rng, weights, empty, empty, pools, RelicDatabase.all_relics(), tiers)
		var shop: Array[String] = RelicOffer.offer("merchant", 30, rng, weights, empty, empty, pools, RelicDatabase.all_relics(), tiers)
		assert_int(elite.size()).is_equal(8 + extra)  # the pool relics only; the three shop-only ones come from the merchant
		assert_int(shop.size()).is_equal(11 + extra)
		for id: String in SHOP_ONLY:
			assert_bool(elite.has(id)).is_false()
			assert_bool(shop.has(id)).is_true()


# --- ASAP Notice ---------------------------------------------------------------------------------

func test_asap_notice_takes_fifteen_percent_off_the_movement_cooldown_only() -> void:
	var main := _spawn_main()
	var movement: CardSlot = main.player.card_slots.get_slot("movement")
	var utility: CardSlot = main.player.card_slots.get_slot("utility")
	var plain: float = main.player.stat_modifiers.apply("slot_cooldown.movement", movement.base_cooldown)
	assert_float(plain).is_equal(movement.base_cooldown)
	var manager := _manager(main, ["asap_notice"] as Array[String])
	assert_float(main.player.stat_modifiers.apply("slot_cooldown.movement", movement.base_cooldown)).is_equal_approx(movement.base_cooldown * 0.85, 0.0001)
	assert_float(main.player.stat_modifiers.apply("slot_cooldown.utility", utility.base_cooldown)).is_equal(utility.base_cooldown)
	manager.remove_relic("asap_notice")  # given up: back to normal
	assert_float(main.player.stat_modifiers.apply("slot_cooldown.movement", movement.base_cooldown)).is_equal(movement.base_cooldown)


# --- Severance Package ---------------------------------------------------------------------------

func test_severance_package_bursts_bleed_from_a_bleeding_enemy_that_dies() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["severance_package"] as Array[String])
	var doomed := _target(main, 3.0, Vector3(0, 0, -5))
	var neighbour := _target(main, 100.0, Vector3(1, 0, -5))
	var far := _target(main, 100.0, Vector3(9, 0, -5))
	var calm := _target(main, 2.0, Vector3(0, 0, 5))
	var calm_neighbour := _target(main, 100.0, Vector3(1, 0, 5))
	await _frames(2)  # let the physics server learn where the targets are
	_hit(calm, main, "light", Health.KIND_HIT, 50.0)  # dies without Bleed: nothing happens
	manager.flush()
	assert_float(calm_neighbour.health.current_health).is_equal(100.0)
	_bleed(doomed)
	_hit(doomed, main, "light", Health.KIND_HIT, 50.0)
	manager.flush()
	assert_float(neighbour.health.current_health).is_equal_approx(98.0, 0.001)
	assert_bool(neighbour.status_manager.has_status("bleed")).is_true()
	assert_bool(far.status_manager.has_status("bleed")).is_false()
	assert_float(far.health.current_health).is_equal(100.0)


func test_a_bleed_a_burst_started_that_kills_bursts_again_and_the_chain_ends_with_the_enemies() -> void:
	# The recursion guard looks at the event origin. A kill by a Bleed tick has the origin status:bleed, so a relic-started Bleed that
	# kills can burst again. The chain is bounded by the enemies left, not by the guard: this pins that it ends.
	var main := _spawn_main()
	var manager := _manager(main, ["severance_package"] as Array[String])
	var first := _target(main, 3.0, Vector3(0, 0, -5))
	var second := _target(main, 3.0, Vector3(1.5, 0, -5))
	var third := _target(main, 50.0, Vector3(3.0, 0, -5))
	await _frames(2)
	_bleed(first)
	_hit(first, main, "light", Health.KIND_HIT, 50.0)
	manager.flush()
	assert_bool(second.status_manager.has_status("bleed")).is_true()
	second.status_manager._process(10.0)  # its Bleed ticks it to death
	manager.flush()
	assert_bool(third.status_manager.has_status("bleed")).is_true()  # the second one's burst reached the third
	assert_float(third.health.current_health).is_greater(0.0)


# --- Paperwork Fire ------------------------------------------------------------------------------

func test_paperwork_fire_burns_the_target_on_every_fifth_card_projectile_hit_only() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["paperwork_fire"] as Array[String])
	var victim := _target(main, 1000.0)
	assert_bool(CardDatabase.tags_for("wizard_bolt_volley").has("Projectile")).is_true()
	for i in range(1, 11):
		_hit(victim, main, "card:wizard_bolt_volley", Health.KIND_HIT, 1.0, "fire")
		manager.flush()
		assert_bool(victim.status_manager.has_status("burn")).override_failure_message("after projectile hit %d" % i).is_equal(i == 5 or i == 10)
		if i == 5:
			victim.status_manager.consume_status("burn")  # put it out: the 10th must light it again
			assert_bool(victim.status_manager.has_status("burn")).is_false()
	assert_bool(victim.status_manager.has_status("burn")).is_true()
	# light and heavy attacks, a card's zone ticks (not a Projectile card), Bleed ticks and relic damage do not count
	var other := _target(main, 1000.0, Vector3(5, 0, 5))
	var others: Array[String] = ["light", "heavy", "card:fire_wall", "status:bleed", "relic:x", "enemy"]
	for i in range(12):
		_hit(other, main, others[i % others.size()], Health.KIND_DOT if i % 6 == 2 else Health.KIND_HIT)
		manager.flush()
	assert_bool(other.status_manager.has_status("burn")).is_false()


func test_the_tag_filter_on_hit_landed_is_validated_and_read_from_the_card_behind_the_origin() -> void:
	assert_array(RelicSchema.validate(RelicDatabase.get_relic("paperwork_fire"), "paperwork_fire")).is_empty()
	var relic: Dictionary = RelicDatabase.get_relic("paperwork_fire").duplicate(true)
	((relic["triggers"] as Array)[0]["filter"] as Dictionary)["tag"] = "NotATag"
	assert_array(RelicSchema.validate(relic, "paperwork_fire")).is_not_empty()
	assert_array(RelicManager._origin_tags("light")).is_empty()
	assert_array(RelicManager._origin_tags("card:nope")).is_empty()
	assert_bool(RelicManager._origin_tags("card:wizard_bolt_volley").has("Projectile")).is_true()


# --- Grading Curve -------------------------------------------------------------------------------

func test_grading_curve_leaves_a_two_second_burning_zone_where_the_heavy_lands() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["grading_curve"] as Array[String])
	var zones := ZoneManager.for_world(main)
	await _frames(2)
	manager.handle_event({"event": "attack_fired", "attack_id": "light", "position": Vector3(0, 0, -5), "origin": ""})
	manager.flush()
	assert_int(zones.live_zones().size()).is_equal(0)  # a light attack leaves nothing
	manager.handle_event({"event": "attack_fired", "attack_id": "heavy", "position": Vector3(0, 0, -5), "origin": ""})
	manager.flush()
	var live: Array[Dictionary] = zones.live_zones()
	assert_int(live.size()).is_equal(1)
	assert_float(float(live[0]["duration"])).is_equal(2.0)
	assert_str(String(live[0]["damage_type"])).is_equal("fire")
	assert_float((live[0]["center"] as Vector3).distance_to(Vector3(0, 0, -5))).is_less(0.01)
	zones.clear()


# --- As Per the Attached Document ----------------------------------------------------------------

func test_as_per_the_attached_document_takes_one_and_a_half_seconds_off_attack_aoe_once_per_swing() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["as_per_the_attached_document"] as Array[String])
	var aoe: CardSlot = main.player.card_slots.get_slot("attack_aoe")
	var single: CardSlot = main.player.card_slots.get_slot("attack_single")
	aoe.cooldown_remaining = 4.0
	single.cooldown_remaining = 4.0
	var a := _target(main, 1000.0, Vector3(0, 0, -5))
	var b := _target(main, 1000.0, Vector3(1, 0, -5))
	_hit(a, main, "light")
	manager.flush()
	assert_float(aoe.cooldown_remaining).is_equal(4.0)  # a light hit does nothing
	_hit(a, main, "heavy")
	_hit(b, main, "heavy")  # the same swing hits two: the internal cooldown makes it count once
	manager.flush()
	assert_float(aoe.cooldown_remaining).is_equal_approx(2.5, 0.0001)
	assert_float(single.cooldown_remaining).is_equal(4.0)
	assert_int(manager.fired_total()).is_equal(1)


# --- Liquidate Assets ----------------------------------------------------------------------------

func test_a_scaled_modifier_is_the_value_times_whole_steps_of_the_run_stat() -> void:
	var entry: Dictionary = {"stat": "damage_mult", "modifier_type": "multiplicative", "value": 0.01, "per_run_stat": "gold_spent_merchant", "per": 50}
	assert_float(RelicManager.scaled_value(entry, {})).is_equal(0.0)
	assert_float(RelicManager.scaled_value(entry, {"gold_spent_merchant": 49})).is_equal(0.0)
	assert_float(RelicManager.scaled_value(entry, {"gold_spent_merchant": 50})).is_equal_approx(0.01, 0.00001)
	assert_float(RelicManager.scaled_value(entry, {"gold_spent_merchant": 149})).is_equal_approx(0.02, 0.00001)
	assert_float(RelicManager.scaled_value(entry, {"gold_spent_merchant": 500})).is_equal_approx(0.10, 0.00001)
	assert_float(RelicManager.scaled_value({"stat": "x", "modifier_type": "additive", "value": 2.0}, {"gold_spent_merchant": 500})).is_equal(2.0)  # unscaled


func test_liquidate_assets_adds_one_percent_damage_per_fifty_gold_spent_at_the_merchant() -> void:
	var main := _spawn_main()
	var manager := _manager(main, ["liquidate_assets"] as Array[String])
	var victim := _target(main, 100000.0)
	_hit(victim, main, "light", Health.KIND_HIT, 100.0)
	assert_float(100000.0 - victim.health.current_health).is_equal_approx(100.0, 0.001)  # nothing spent yet
	manager.set_run_stats({"gold_spent_merchant": 250})  # +5%
	var before: float = victim.health.current_health
	_hit(victim, main, "light", Health.KIND_HIT, 100.0)
	assert_float(before - victim.health.current_health).is_equal_approx(105.0, 0.001)
	before = victim.health.current_health
	_hit(victim, main, "card:x", Health.KIND_HIT, 100.0, "fire")  # every damage source counts
	assert_float(before - victim.health.current_health).is_equal_approx(105.0, 0.001)
	manager.set_run_stats({"gold_spent_merchant": 90})  # a lower number lowers it again (re-applied, not stacked)
	before = victim.health.current_health
	_hit(victim, main, "light", Health.KIND_HIT, 100.0)
	assert_float(before - victim.health.current_health).is_equal_approx(101.0, 0.001)


func test_the_scaled_modifier_keys_are_validated() -> void:
	var good: Dictionary = RelicDatabase.get_relic("liquidate_assets").duplicate(true)
	assert_array(RelicSchema.validate(good, "liquidate_assets")).is_empty()
	var cases: Array[Dictionary] = [{"per": 50}, {"per_run_stat": "gold_spent_merchant"}, {"per_run_stat": "nope", "per": 50}, {"per_run_stat": "gold_spent_merchant", "per": 0}, {"per_run_stat": "gold_spent_merchant", "per": 2.5}]
	for case: Dictionary in cases:
		var relic: Dictionary = good.duplicate(true)
		var modifier: Dictionary = (relic["modifiers"] as Array)[0]
		modifier.erase("per_run_stat")
		modifier.erase("per")
		modifier.merge(case)
		assert_array(RelicSchema.validate(relic, "liquidate_assets")).override_failure_message(str(case)).is_not_empty()
	# the factor stat cannot be pushed to zero or below
	var broken: Dictionary = good.duplicate(true)
	((broken["modifiers"] as Array)[0] as Dictionary)["value"] = -1.0
	assert_array(RelicSchema.validate(broken, "liquidate_assets")).is_not_empty()
