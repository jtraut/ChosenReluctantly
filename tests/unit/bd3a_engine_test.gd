class_name Bd3aEngineTest
extends GdUnitTestSuite
## BD3a sitting A: stacking statuses, status_tick_rate, detonate_status, and the four physical Rogue cards.

var _log: RelayLog


func before_test() -> void:
	CombatEvents.reset()
	_log = RelayLog.new(CombatEvents)


func after_test() -> void:
	_log.stop()
	CombatEvents.reset()


func _target(hp: float = 100.0) -> RelayTarget:
	var target := RelayTarget.new("enemy", hp)
	add_child(target)
	auto_free(target)
	return target


func _source() -> StatSource:
	var source := StatSource.new()
	add_child(source)
	auto_free(source)
	return source


func _bleed() -> Dictionary:
	return StatusDatabase.get_status("bleed")


func _burn() -> Dictionary:
	return StatusDatabase.get_status("burn")


# --- stacking -------------------------------------------------------------------------------

func test_burn_and_bleed_do_not_stack_without_a_source() -> void:
	# D25 = A: the shipped data has no stacking block, so reapplying only refreshes.
	for status_id: String in ["burn", "bleed"]:
		var target := _target()
		var source := _source()
		var def: Dictionary = StatusDatabase.get_status(status_id)
		assert_bool(def.has("stacking")).is_false()
		for i in range(5):
			target.status_manager.apply_status(status_id, def, 4.0, source, "card:test")
		assert_int(target.status_manager.stacks_of(status_id)).is_equal(1)
		assert_int(target.status_manager.max_stacks_of(status_id)).is_equal(1)


func test_no_stacking_without_a_source_node_at_all() -> void:
	var target := _target()
	for i in range(3):
		target.status_manager.apply_status("bleed", _bleed(), 4.0)
	assert_int(target.status_manager.stacks_of("bleed")).is_equal(1)


func test_a_max_stacks_stat_on_the_applier_lets_the_status_stack() -> void:
	var target := _target()
	var source := _source()
	source.stat_modifiers.add_modifier("status_max_stacks.bleed", "keystone", StatModifiers.ADDITIVE, 4.0)
	var seen: Array[int] = []
	target.status_manager.status_stacks_changed.connect(func(_id: String, stacks: int) -> void: seen.append(stacks))
	for i in range(7):
		target.status_manager.apply_status("bleed", _bleed(), 4.0, source, "card:test")
	assert_int(target.status_manager.stacks_of("bleed")).is_equal(5)
	assert_int(target.status_manager.max_stacks_of("bleed")).is_equal(5)
	assert_array(seen).is_equal([2, 3, 4, 5])


func test_the_stat_only_affects_its_own_status() -> void:
	var target := _target()
	var source := _source()
	source.stat_modifiers.add_modifier("status_max_stacks.bleed", "keystone", StatModifiers.ADDITIVE, 4.0)
	for i in range(3):
		target.status_manager.apply_status("burn", _burn(), 4.0, source, "card:test")
	assert_int(target.status_manager.stacks_of("burn")).is_equal(1)


func test_a_data_stacking_cap_works_without_any_stat() -> void:
	var target := _target()
	var def: Dictionary = _bleed().duplicate(true)
	def["stacking"] = {"max_stacks": 3}
	for i in range(6):
		target.status_manager.apply_status("bleed", def, 4.0, _source())
	assert_int(target.status_manager.stacks_of("bleed")).is_equal(3)


func test_dot_ticks_are_multiplied_by_stacks() -> void:
	var target := _target()
	var source := _source()
	source.stat_modifiers.add_modifier("status_max_stacks.bleed", "k", StatModifiers.ADDITIVE, 4.0)
	for i in range(3):
		target.status_manager.apply_status("bleed", _bleed(), 4.0, source, "card:test")
	var before: float = target.health.current_health
	target.status_manager._process(0.5)  # one Bleed tick: 1.0 x 3 stacks
	assert_float(before - target.health.current_health).is_equal_approx(3.0, 0.001)


func test_reapplying_adds_a_stack_and_refreshes_the_duration() -> void:
	var target := _target()
	var source := _source()
	source.stat_modifiers.add_modifier("status_max_stacks.bleed", "k", StatModifiers.ADDITIVE, 4.0)
	target.status_manager.apply_status("bleed", _bleed(), 2.0, source, "card:test")
	target.status_manager._process(1.5)
	target.status_manager.apply_status("bleed", _bleed(), 2.0, source, "card:test")
	assert_int(target.status_manager.stacks_of("bleed")).is_equal(2)
	assert_float(target.status_manager.status_time_left("bleed")).is_equal_approx(2.0, 0.001)


func test_stacks_stay_when_the_cap_drops_but_no_stack_is_added() -> void:
	var target := _target()
	var source := _source()
	source.stat_modifiers.add_modifier("status_max_stacks.bleed", "k", StatModifiers.ADDITIVE, 4.0)
	for i in range(4):
		target.status_manager.apply_status("bleed", _bleed(), 4.0, source, "card:test")
	source.stat_modifiers.remove_modifier("status_max_stacks.bleed", "k")
	target.status_manager.apply_status("bleed", _bleed(), 4.0, source, "card:test")
	assert_int(target.status_manager.stacks_of("bleed")).is_equal(4)


func test_stacks_of_an_inactive_status_is_zero() -> void:
	assert_int(_target().status_manager.stacks_of("bleed")).is_equal(0)


# --- status_tick_rate -------------------------------------------------------------------------

func test_a_tick_rate_stat_shortens_the_tick_interval() -> void:
	var source := _source()
	source.stat_modifiers.add_modifier("status_tick_rate.bleed", "k", StatModifiers.MULTIPLICATIVE, 0.5)  # x1.5
	var fast := _target()
	fast.status_manager.apply_status("bleed", _bleed(), 4.0, source, "card:test")
	var normal := _target()
	normal.status_manager.apply_status("bleed", _bleed(), 4.0, _source(), "card:test")
	fast.status_manager._process(0.34)  # 0.5 / 1.5 = 0.333 s per tick
	normal.status_manager._process(0.34)
	assert_float(100.0 - fast.health.current_health).is_equal_approx(1.0, 0.001)
	assert_float(100.0 - normal.health.current_health).is_equal_approx(0.0, 0.001)
	fast.status_manager._process(0.34)
	assert_float(100.0 - fast.health.current_health).is_equal_approx(2.0, 0.001)


func test_a_tick_rate_of_one_changes_nothing() -> void:
	var target := _target()
	target.status_manager.apply_status("bleed", _bleed(), 4.0, _source(), "card:test")
	target.status_manager._process(0.5)
	assert_float(100.0 - target.health.current_health).is_equal_approx(1.0, 0.001)


func test_the_tick_rate_never_goes_to_zero() -> void:
	var source := _source()
	source.stat_modifiers.add_modifier("status_tick_rate.bleed", "k", StatModifiers.MULTIPLICATIVE, -5.0)
	var target := _target()
	target.status_manager.apply_status("bleed", _bleed(), 4.0, source, "card:test")
	target.status_manager._process(0.1)  # must not divide by zero or go negative
	assert_float(target.health.current_health).is_equal(100.0)


# --- remaining ticks and detonate_status --------------------------------------------------------

func test_remaining_ticks_counts_the_ticks_left() -> void:
	var target := _target()
	target.status_manager.apply_status("bleed", _bleed(), 4.0, _source(), "card:test")
	assert_int(target.status_manager.remaining_ticks("bleed")).is_equal(8)
	for i in range(4):
		target.status_manager._process(0.25)  # one frame fires at most one tick, so step finely
	assert_int(target.status_manager.remaining_ticks("bleed")).is_equal(6)
	target.status_manager._process(0.25)
	assert_int(target.status_manager.remaining_ticks("bleed")).is_equal(6)  # ticks at 0.25, 0.75 ... 2.75 s are left
	target.status_manager._process(0.25)
	assert_int(target.status_manager.remaining_ticks("bleed")).is_equal(5)
	assert_int(target.status_manager.remaining_ticks("burn")).is_equal(0)


func test_detonate_deals_remaining_ticks_times_multiplier_and_removes_the_status() -> void:
	var target := _target()
	var source := _source()
	target.status_manager.apply_status("bleed", _bleed(), 4.0, source, "card:test")
	var dealt: float = target.status_manager.detonate_status("bleed", 2.0, source, "card:open")
	assert_float(dealt).is_equal_approx(16.0, 0.001)  # 8 ticks x 1 x 2
	assert_float(target.health.current_health).is_equal_approx(84.0, 0.001)
	assert_bool(target.status_manager.has_status("bleed")).is_false()


func test_detonate_respects_stacks() -> void:
	var target := _target()
	var source := _source()
	source.stat_modifiers.add_modifier("status_max_stacks.bleed", "k", StatModifiers.ADDITIVE, 4.0)
	for i in range(3):
		target.status_manager.apply_status("bleed", _bleed(), 4.0, source, "card:test")
	var dealt: float = target.status_manager.detonate_status("bleed", 2.0, source, "card:open")
	assert_float(dealt).is_equal_approx(48.0, 0.001)  # 8 ticks x 1 x 3 stacks x 2


func test_detonate_bleed_goes_through_armor_and_burn_through_resistance() -> void:
	var bleeder := _target(1000.0)
	bleeder.health.base_armor = 20.0
	bleeder.status_manager.apply_status("bleed", _bleed(), 4.0, _source(), "card:test")
	var raw_bleed: float = bleeder.status_manager.detonate_status("bleed", 2.0, null, "card:open")
	assert_float(1000.0 - bleeder.health.current_health).is_less(raw_bleed)
	assert_float(1000.0 - bleeder.health.current_health).is_greater(0.0)
	var burner := _target(1000.0)
	burner.health.resistances = {"fire": 0.5}
	burner.status_manager.apply_status("burn", _burn(), 4.0, _source(), "card:test")
	var raw_burn: float = burner.status_manager.detonate_status("burn", 2.0, null, "card:open")
	assert_float(raw_burn).is_equal_approx(16.0, 0.001)  # 4 ticks x 2 x 2
	assert_float(1000.0 - burner.health.current_health).is_equal_approx(8.0, 0.001)  # fire resistance 50%


func test_detonate_with_no_status_does_nothing() -> void:
	var target := _target()
	assert_float(target.status_manager.detonate_status("bleed", 2.0)).is_equal(0.0)
	assert_float(target.health.current_health).is_equal(100.0)


func test_detonate_ends_the_status_with_the_detonated_reason_not_expired() -> void:
	var target := _target()
	target.status_manager.apply_status("burn", _burn(), 4.0, _source(), "card:test")
	target.status_manager.detonate_status("burn", 2.0, null, "card:open")
	var ended := _log.named("status_ended")
	assert_int(ended.size()).is_equal(1)
	assert_str(String(ended[0]["reason"])).is_equal("detonated")
	assert_str(String(ended[0]["status_id"])).is_equal("burn")


func test_pyre_insurance_does_not_listen_for_detonated() -> void:
	var relic: Dictionary = RelicDatabase.get_relic("pyre_insurance")
	var reasons: Array = relic["triggers"][0]["filter"]["reason"]
	assert_bool(reasons.has("detonated")).is_false()
	assert_bool(CombatEventsRelay.STATUS_END_REASONS.has("detonated")).is_true()


func test_the_burst_lands_while_the_status_is_still_on_so_a_kill_counts_as_a_bleeding_death() -> void:
	var target := _target(5.0)
	target.status_manager.apply_status("bleed", _bleed(), 4.0, _source(), "card:test")
	target.status_manager.detonate_status("bleed", 2.0, null, "card:open")
	var kills := _log.named("enemy_killed")
	assert_int(kills.size()).is_equal(1)
	assert_bool((kills[0]["statuses"] as Array).has("bleed")).is_true()
	# One end event for the status, and it is the detonation (not owner_died, not expired).
	var ended := _log.named("status_ended")
	assert_int(ended.size()).is_equal(1)
	assert_str(String(ended[0]["reason"])).is_equal("detonated")


func test_a_detonate_signal_reports_the_burst_and_the_stacks() -> void:
	var target := _target()
	var seen: Array = []
	target.status_manager.status_detonated.connect(func(id: String, amount: float, stacks: int) -> void: seen.append([id, amount, stacks]))
	target.status_manager.apply_status("bleed", _bleed(), 2.0, _source(), "card:test")
	target.status_manager.detonate_status("bleed", 2.0)
	assert_int(seen.size()).is_equal(1)
	assert_str(seen[0][0]).is_equal("bleed")
	assert_float(seen[0][1]).is_equal_approx(8.0, 0.001)  # 4 ticks x 2
	assert_int(seen[0][2]).is_equal(1)


func test_detonate_hit_is_credited_to_the_source_with_the_card_origin() -> void:
	var target := _target()
	var source := _source()
	target.status_manager.apply_status("bleed", _bleed(), 4.0, source, "card:test")
	target.status_manager.detonate_status("bleed", 2.0, source, "card:rogue_open_a_vein")
	var hits := _log.named("hit_landed")
	assert_int(hits.size()).is_equal(1)
	assert_str(String(hits[0]["origin"])).is_equal("card:rogue_open_a_vein")
	assert_str(String(hits[0]["damage_type"])).is_equal("physical")


# --- the effect template ------------------------------------------------------------------------

func test_template_detonates_every_target_in_last_hits() -> void:
	var caster := _source()
	var a := _target()
	var b := _target()
	var c := _target()
	for t: RelayTarget in [a, b]:
		t.status_manager.apply_status("bleed", _bleed(), 4.0, caster, "card:test")
	var context := EffectContext.new(caster, self, "player")
	context.origin = "card:rogue_open_a_vein"
	context.last_hits = [a.hurtbox, b.hurtbox, c.hurtbox]
	EffectTemplates.execute("detonate_status", {"status_id": "bleed", "multiplier": 2.0}, context)
	assert_float(a.health.current_health).is_equal_approx(84.0, 0.001)
	assert_float(b.health.current_health).is_equal_approx(84.0, 0.001)
	assert_float(c.health.current_health).is_equal(100.0)
	assert_bool(a.status_manager.has_status("bleed")).is_false()


func test_template_validation() -> void:
	assert_bool(EffectTemplates.is_known_template("detonate_status")).is_true()
	assert_array(EffectTemplates.validate_params("detonate_status", {"status_id": "bleed", "multiplier": 2.0})).is_empty()
	assert_array(EffectTemplates.validate_params("detonate_status", {"status_id": "nope", "multiplier": 2.0})).is_not_empty()
	assert_array(EffectTemplates.validate_params("detonate_status", {"status_id": "stun", "multiplier": 2.0})).is_not_empty()
	assert_array(EffectTemplates.validate_params("detonate_status", {"status_id": "bleed", "multiplier": 0.0})).is_not_empty()
	assert_array(EffectTemplates.validate_params("detonate_status", {"status_id": "bleed", "multiplier": 2.0, "x": 1})).is_not_empty()


func test_status_stacking_data_validation() -> void:
	var good: Dictionary = _bleed().duplicate(true)
	good["stacking"] = {"max_stacks": 5}
	assert_array(StatusDatabase.validate_entry(good)).is_empty()
	for bad: Variant in [{"max_stacks": 0}, {"max_stacks": 2.5}, {"max_stacks": 100}, {}, {"max_stacks": 2, "decay_after": 4}, 7]:
		var entry: Dictionary = _bleed().duplicate(true)
		entry["stacking"] = bad
		assert_array(StatusDatabase.validate_entry(entry)).is_not_empty()
	var stun: Dictionary = StatusDatabase.get_status("stun").duplicate(true)
	stun["stacking"] = {"max_stacks": 2}
	assert_array(StatusDatabase.validate_entry(stun)).is_not_empty()


func test_tick_rate_buffs_must_keep_the_factor_above_zero() -> void:
	assert_array(EffectTemplates.validate_params("buff", {"stat": "status_tick_rate.bleed", "modifier_type": "multiplicative", "value": 0.5, "duration": 6.0})).is_empty()
	assert_array(EffectTemplates.validate_params("buff", {"stat": "status_tick_rate.bleed", "modifier_type": "multiplicative", "value": -1.0, "duration": 6.0})).is_not_empty()


# --- attack stats and the four cards ---------------------------------------------------------------

func test_light_speed_and_heavy_cooldown_stats_exist_and_move_the_attack_timers() -> void:
	var modifiers := StatModifiers.new()
	var controller := AttackController.new({&"light": AttackDatabase.get_attack("light"), &"heavy": AttackDatabase.get_heavy("rogue")}, modifiers)
	var light_before: float = controller.get_interval(&"light")
	var heavy_before: float = controller.get_interval(&"heavy")
	modifiers.add_modifier("attack_interval.light", "w", StatModifiers.MULTIPLICATIVE, -0.3)
	modifiers.add_modifier("attack_cooldown.heavy", "w", StatModifiers.MULTIPLICATIVE, -0.3)
	assert_float(controller.get_interval(&"light")).is_equal_approx(light_before * 0.7, 0.001)
	assert_float(controller.get_interval(&"heavy")).is_equal_approx(heavy_before * 0.7, 0.001)


func test_warm_up_buffs_light_speed_and_heavy_cooldown_when_cast() -> void:
	var caster := _source()
	var controller := AttackController.new({&"light": AttackDatabase.get_attack("light"), &"heavy": AttackDatabase.get_heavy("rogue")}, caster.stat_modifiers)
	var light_before: float = controller.get_interval(&"light")
	var heavy_before: float = controller.get_interval(&"heavy")
	var context := EffectContext.new(caster, self, "player")
	for effect: Dictionary in CardDatabase.get_card("rogue_warm_up")["effects"]:
		EffectTemplates.execute(String(effect["template"]), effect["params"], context)
	assert_float(controller.get_interval(&"light")).is_equal_approx(light_before * 0.7, 0.001)
	assert_float(controller.get_interval(&"heavy")).is_equal_approx(heavy_before * 0.7, 0.001)


func test_bad_influence_lets_bleed_stack_to_five_and_tick_faster() -> void:
	var caster := _source()
	var context := EffectContext.new(caster, self, "player")
	for effect: Dictionary in CardDatabase.get_card("rogue_bad_influence")["effects"]:
		EffectTemplates.execute(String(effect["template"]), effect["params"], context)
	var target := _target()
	for i in range(8):
		target.status_manager.apply_status("bleed", _bleed(), 4.0, caster, "card:test")
	assert_int(target.status_manager.stacks_of("bleed")).is_equal(5)
	target.status_manager._process(0.34)  # 1.5x tick rate: one tick by 0.34 s, 5 stacks
	assert_float(100.0 - target.health.current_health).is_equal_approx(5.0, 0.001)


func test_the_four_cards_load_with_the_right_slots() -> void:
	for id: String in ["rogue_open_a_vein", "rogue_paper_cuts", "rogue_bad_influence", "rogue_warm_up"]:
		assert_bool(CardDatabase.has_card(id)).is_true()
		assert_str(String(CardDatabase.get_card(id)["pool"])).is_equal("rogue")
	assert_str(String(CardDatabase.get_card("rogue_open_a_vein")["slot_type"])).is_equal("attack_single")
	assert_str(String(CardDatabase.get_card("rogue_paper_cuts")["slot_type"])).is_equal("attack_single")
	assert_str(String(CardDatabase.get_card("rogue_bad_influence")["slot_type"])).is_equal("utility")
	assert_str(String(CardDatabase.get_card("rogue_warm_up")["slot_type"])).is_equal("utility")


func test_the_new_attack_cards_pass_the_damage_rule() -> void:
	assert_array(CardDamageRule.check_shipped()).is_empty()
	var slot_table := JsonDataTable.new("res://data/slot_types.json")
	var statuses: Dictionary = {"bleed": StatusDatabase.get_status("bleed")}
	var light: Dictionary = AttackDatabase.get_attack("light")
	var base: float = float(slot_table.get_raw("attack_single")["base_cooldown"])
	for id: String in ["rogue_open_a_vein", "rogue_paper_cuts"]:
		assert_array(CardDamageRule.check_card(CardDatabase.get_card(id), base, light, statuses)).is_empty()


func test_the_cards_carry_the_right_tags() -> void:
	var vein: Array[String] = CardTags.all_tags(CardDatabase.get_card("rogue_open_a_vein"))
	assert_bool(vein.has("Bleed")).is_true()
	assert_bool(vein.has("Keystone")).is_true()
	assert_bool(vein.has("Payoff")).is_true()
	assert_bool(CardTags.all_tags(CardDatabase.get_card("rogue_paper_cuts")).has("Bleed")).is_true()
	assert_bool(CardTags.all_tags(CardDatabase.get_card("rogue_bad_influence")).has("Primer")).is_true()


func test_a_detonate_is_not_a_status_source() -> void:
	# Open a Vein detonates Bleed, it does not apply it: it must not count for requires.status_sources or the D43 lean.
	assert_array(CardSummary.status_ids(CardDatabase.get_card("rogue_open_a_vein"))).is_empty()
	assert_array(CardSummary.status_ids(CardDatabase.get_card("rogue_paper_cuts"))).is_equal(["bleed"])
