class_name Bd1bPlanTest
extends GdUnitTestSuite
## BD1-B item 9: the plan-aware bot policy (PlanPolicy). Decisions on fabricated slots and views, then each archetype
## deck driven through a real CardSlotController for a few simulated rooms (the same loop as tools/bot_sim.gd --plan).

const SimCasterScript := preload("res://tools/sim_caster.gd")
const DT := 1.0 / 60.0


func before_test() -> void:
	CardDatabase.load_all()


func _slot(slot_type: String, cards: Array[String], ready_in: float = 0.0) -> CardSlot:
	var slot := CardSlot.new(slot_type, 3.0, cards, 1.0, null)
	slot.cooldown_remaining = ready_in
	return slot


func _slots(single: Array[String], aoe: Array[String], movement: Array[String]) -> Dictionary:
	return {
		"attack_single": _slot("attack_single", single), "attack_aoe": _slot("attack_aoe", aoe),
		"utility": _slot("utility", ["fire_hot_head"] as Array[String]), "movement": _slot("movement", movement),
		"recovery": _slot("recovery", ["neutral_healing_potion"] as Array[String]),
	}


func _view(enemies: Array, now: float = 10.0, history: CastHistory = null, zones: int = 0) -> Dictionary:
	return {"now": now, "history": history, "zone_count": zones, "origin": Vector3.ZERO, "forward": Vector3(0, 0, -1), "aim_point": Vector3(0, 0, -2), "arena": Rect2(), "enemies": enemies}


func _enemy(z: float, statuses: Array = []) -> Dictionary:
	return {"pos": Vector3(0, 0, z), "statuses": statuses}


func test_a_payoff_is_cast_at_once_when_its_condition_is_live() -> void:
	var policy := PlanPolicy.new()
	var history := CastHistory.new()
	history.record(9.5, "movement", "rogue_momentum", CardDatabase.tags_for("rogue_momentum"))
	var slots := _slots(["rogue_drive_by"] as Array[String], ["fire_fine_burn_then"] as Array[String], ["rogue_momentum"] as Array[String])
	var decision: String = policy.decide("attack_single", slots["attack_single"], slots, _view([_enemy(-1.0)], 10.0, history), 1.0, false, true)
	assert_str(decision).is_equal(PlanPolicy.CAST)


func test_a_payoff_that_can_pay_off_soon_is_held_then_cast_after_the_hold_limit() -> void:
	var policy := PlanPolicy.new()
	# Momentum is ready in the Movement slot, so Drive-By's condition can come true soon: hold.
	var slots := _slots(["rogue_drive_by"] as Array[String], ["fire_fine_burn_then"] as Array[String], ["rogue_momentum"] as Array[String])
	var enemies: Array = [_enemy(-1.0)]
	assert_str(policy.decide("attack_single", slots["attack_single"], slots, _view(enemies, 10.0), 1.0, false, true)).is_equal(PlanPolicy.WAIT)
	assert_str(policy.decide("attack_single", slots["attack_single"], slots, _view(enemies, 11.0), 1.0, false, true)).is_equal(PlanPolicy.WAIT)  # 1.0 s held
	assert_str(policy.decide("attack_single", slots["attack_single"], slots, _view(enemies, 11.6), 1.0, false, true)).is_equal(PlanPolicy.CAST)  # 1.6 s held
	# The hold clock only runs in a fight: with no enemy there is nothing to hold for.
	var idle := PlanPolicy.new()
	assert_str(idle.decide("attack_single", slots["attack_single"], slots, _view([], 10.0), 1.0, false, true)).is_equal(PlanPolicy.WAIT)
	assert_str(idle.decide("attack_single", slots["attack_single"], slots, _view([], 20.0), 1.0, false, true)).is_equal(PlanPolicy.WAIT)


func test_a_payoff_that_cannot_pay_off_soon_is_swapped_when_the_slot_has_another_card() -> void:
	var policy := PlanPolicy.new()
	# No Movement card is coming (the Movement slot is on a long cooldown), so Drive-By is dead for now.
	var slots := _slots(["rogue_drive_by", "rogue_quick_slash"] as Array[String], ["fire_fine_burn_then"] as Array[String], ["rogue_momentum"] as Array[String])
	slots["attack_single"].current_card_id = "rogue_drive_by"
	(slots["movement"] as CardSlot).cooldown_remaining = 8.0
	assert_str(policy.decide("attack_single", slots["attack_single"], slots, _view([_enemy(-1.0)]), 1.0, false, true)).is_equal(PlanPolicy.SWAP)
	# A slot with only that one card has nothing to swap to: it holds, then casts.
	var lone := _slots(["rogue_drive_by"] as Array[String], ["fire_fine_burn_then"] as Array[String], ["rogue_momentum"] as Array[String])
	(lone["movement"] as CardSlot).cooldown_remaining = 8.0
	assert_str(policy.decide("attack_single", lone["attack_single"], lone, _view([_enemy(-1.0)], 10.0), 1.0, false, true)).is_equal(PlanPolicy.WAIT)


func test_target_conditions_read_the_enemies_and_the_other_slots_generically() -> void:
	var policy := PlanPolicy.new()
	# Fan the Flames with nothing burning and nothing in the other slots that lights a fire: swap away.
	var slots := _slots(["rogue_quick_slash"] as Array[String], ["fire_fan_the_flames", "fire_wall"] as Array[String], ["rogue_ugh_fine_moving"] as Array[String])
	slots["attack_aoe"].current_card_id = "fire_fan_the_flames"
	assert_str(policy.decide("attack_aoe", slots["attack_aoe"], slots, _view([_enemy(-1.0)]), 1.0, false, true)).is_equal(PlanPolicy.SWAP)
	# A burning enemy in the area makes it live: cast.
	assert_str(policy.decide("attack_aoe", slots["attack_aoe"], slots, _view([_enemy(-1.0, ["burn"])]), 1.0, false, true)).is_equal(PlanPolicy.CAST)
	# A burning enemy far away (outside the preview area) is not live, but the fire exists, so the card can pay off soon: hold.
	assert_str(policy.decide("attack_aoe", slots["attack_aoe"], slots, _view([_enemy(-1.0), _enemy(-30.0, ["burn"])]), 1.0, false, true)).is_equal(PlanPolicy.WAIT)


func test_zone_conditions_look_for_a_zone_card_in_the_other_slots() -> void:
	var policy := PlanPolicy.new()
	var slots := _slots(["rogue_quick_slash"] as Array[String], ["fire_heat_sink"] as Array[String], ["rogue_ugh_fine_moving"] as Array[String])
	assert_str(policy.decide("attack_aoe", slots["attack_aoe"], slots, _view([_enemy(-1.0)]), 1.0, false, true)).is_equal(PlanPolicy.WAIT)  # lone card: nothing to swap to
	var two := _slots(["rogue_quick_slash"] as Array[String], ["fire_heat_sink", "fire_fine_burn_then"] as Array[String], ["rogue_ugh_fine_moving"] as Array[String])
	two["attack_aoe"].current_card_id = "fire_heat_sink"
	assert_str(policy.decide("attack_aoe", two["attack_aoe"], two, _view([_enemy(-1.0)]), 1.0, false, true)).is_equal(PlanPolicy.SWAP)
	assert_str(policy.decide("attack_aoe", two["attack_aoe"], two, _view([_enemy(-1.0)], 10.0, null, 1), 1.0, false, true)).is_equal(PlanPolicy.CAST)


func test_movement_is_an_escape_unless_a_payoff_wants_it_and_the_dodge_is_not_decided_here() -> void:
	var policy := PlanPolicy.new()
	var plain := _slots(["rogue_quick_slash"] as Array[String], ["fire_fine_burn_then"] as Array[String], ["rogue_ugh_fine_moving"] as Array[String])
	var far: Array = [_enemy(-5.0)]
	assert_str(policy.decide("movement", plain["movement"], plain, _view(far), 1.0, false, true)).is_equal(PlanPolicy.WAIT)
	assert_str(policy.decide("movement", plain["movement"], plain, _view(far), 1.0, true, true)).is_equal(PlanPolicy.WAIT)  # in danger but a dodge charge is ready
	assert_str(policy.decide("movement", plain["movement"], plain, _view(far), 1.0, true, false)).is_equal(PlanPolicy.CAST)  # in danger, no charge: spend the card
	# Hit and Run: Drive-By reads a Movement cast, so a gap to dash across makes the dash an offensive move.
	var hit_run := _slots(["rogue_drive_by"] as Array[String], ["fire_fine_burn_then"] as Array[String], ["rogue_momentum"] as Array[String])
	assert_str(policy.decide("movement", hit_run["movement"], hit_run, _view(far), 1.0, false, true)).is_equal(PlanPolicy.CAST)
	assert_str(policy.decide("movement", hit_run["movement"], hit_run, _view([_enemy(-1.0)]), 1.0, false, true)).is_equal(PlanPolicy.WAIT)  # already on top of it
	assert_str(policy.decide("movement", hit_run["movement"], hit_run, _view([_enemy(-20.0)]), 1.0, false, true)).is_equal(PlanPolicy.WAIT)  # too far


func test_unconditional_cards_follow_simple_rules_and_a_busy_slot_waits() -> void:
	var policy := PlanPolicy.new()
	var slots := _slots(["rogue_quick_slash"] as Array[String], ["fire_fine_burn_then"] as Array[String], ["rogue_ugh_fine_moving"] as Array[String])
	assert_str(policy.decide("attack_single", slots["attack_single"], slots, _view([_enemy(-1.0)]), 1.0, false, true)).is_equal(PlanPolicy.CAST)
	assert_str(policy.decide("attack_single", slots["attack_single"], slots, _view([_enemy(-9.0)]), 1.0, false, true)).is_equal(PlanPolicy.WAIT)  # nothing in reach
	assert_str(policy.decide("recovery", slots["recovery"], slots, _view([_enemy(-1.0)]), 0.9, false, true)).is_equal(PlanPolicy.WAIT)
	assert_str(policy.decide("recovery", slots["recovery"], slots, _view([_enemy(-1.0)]), 0.4, false, true)).is_equal(PlanPolicy.CAST)
	assert_str(policy.decide("utility", slots["utility"], slots, _view([_enemy(-3.0)]), 1.0, false, true)).is_equal(PlanPolicy.CAST)
	(slots["attack_single"] as CardSlot).cooldown_remaining = 0.5
	assert_str(policy.decide("attack_single", slots["attack_single"], slots, _view([_enemy(-1.0)]), 1.0, false, true)).is_equal(PlanPolicy.WAIT)


# --- the whole loop on each archetype deck ----------------------------------------------------------

func _play(deck_name: String, seed_value: int, ticks: int) -> Dictionary:
	var preset: Dictionary = (DebugDecks.read_dir()["presets"] as Dictionary)[deck_name]
	var caster: Node3D = auto_free(SimCasterScript.new())
	add_child(caster)
	var health := Health.new()
	health.name = "Health"
	health.max_health = 30.0
	caster.add_child(health)
	var relay: CombatEventsRelay = CombatLink.events()
	assert_object(relay).is_not_null()  # the autoload exists at run time
	relay.reset()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pools: Array[String] = [RunSession.preset_character(preset), "fire", "neutral"]
	var controller := CardSlotController.new(caster, caster, "player", caster.get("stat_modifiers"), pools, rng)
	controller.status_rng = RandomNumberGenerator.new()
	controller.status_rng.seed = 7
	controller.set_deck(DebugDecks.deck_of(preset, false))
	var policy := PlanPolicy.new()
	var casts: int = 0
	var swaps: int = 0
	var live_payoffs: int = 0
	for tick in range(ticks):
		relay.step(DT)
		controller.advance(DT)
		var now: float = relay.now()
		var view: Dictionary = _view([{"pos": Vector3(0, 0, -2), "statuses": ["burn"] if relay.history.cast_within(now, 4.0, "", "Burn") else []}], now, relay.history, 1 if relay.history.cast_within(now, 4.0, "", "Zone") else 0)
		var decisions: Dictionary = policy.decide_all(controller.slots, view, 1.0, (tick / 90) % 3 == 0, false)
		for slot_type: String in CardSlotController.SLOT_TYPE_ORDER:
			var card: Dictionary = CardDatabase.get_card(controller.get_slot(slot_type).current_card_id)
			var live: bool = SlotSynergy.is_live(card, view)
			match String(decisions.get(slot_type, PlanPolicy.WAIT)):
				PlanPolicy.CAST:
					if controller.try_use(slot_type):
						casts += 1
						live_payoffs += 1 if live else 0
				PlanPolicy.SWAP:
					if controller.try_swap(slot_type):
						swaps += 1
		assert_bool(is_nan(controller.get_slot("attack_single").cooldown_remaining)).is_false()
		assert_int(relay.history.size()).is_less_equal(CastHistory.MAX_ENTRIES)
	return {"casts": casts, "swaps": swaps, "live_payoffs": live_payoffs, "dashes": int(caster.get("dashes"))}


func test_the_plan_bot_plays_each_archetype_deck_and_cashes_in_its_payoffs() -> void:
	for deck_name: String in ["rogue-kindling", "rogue-hit-and-run", "wizard-controlled-burn", "wizard-departure-lounge"]:
		var total_casts: int = 0
		var total_live: int = 0
		for seed_value in range(1, 6):
			var result: Dictionary = _play(deck_name, seed_value, 900)  # 15 s
			total_casts += int(result["casts"])
			total_live += int(result["live_payoffs"])
		assert_int(total_casts).override_failure_message(deck_name + " cast nothing").is_greater(20)
		assert_int(total_live).override_failure_message(deck_name + " never cast a payoff with its condition live").is_greater(0)


func test_hit_and_run_dashes_in_before_it_stabs() -> void:
	var result: Dictionary = _play("rogue-hit-and-run", 3, 1200)
	assert_int(int(result["dashes"])).is_greater(0)  # Movement spent offensively, with no danger flag from the fight itself
