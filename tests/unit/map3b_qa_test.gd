class_name Map3bQaTest
extends GdUnitTestSuite
## MAP3b qa review: the shipped data (not fixtures) through the mini-boss reward, the boss-relic rules, the fall-down rule, the stack-cap worst
## case for Exsanguinate, and the mini-boss reward across a save and Continue. Independent of the sitting A and B suites.

const CLASSES: Array[String] = ["rogue", "wizard"]
const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const PATH := "user://tests/map3b_qa_save.json"


func before_test() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	RunSave.reset()
	RunSave.path = PATH
	RunSave.persist_override = true
	RunSave.delete_save()
	RunSession.clear()
	RunSession.map_override = -1
	RunSession.acts_override = 0
	RelicDatabase.load_all()


func after_test() -> void:
	RunSave.delete_save()
	RunSave.reset()
	RunSession.clear()
	RunSession.map_override = -1
	RunSession.acts_override = 0
	RunSession.forced_relic_offer = []
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	ClassPickScreen.reset()
	Juice.reset()
	GamePause.reset()
	CombatEvents.reset()
	get_tree().paused = false


func _ctx(character: String, cap: int = -1) -> Dictionary:
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools(character))
	if cap > 0:
		(ctx["relics"] as Dictionary)["max_owned"] = cap
	return ctx


func _state(character: String, seed_value: int, act: int) -> RunState:
	var state: RunState = RunState.new_run(seed_value, CharacterDatabase.starting_deck(character), 3, character)
	state.act = act
	state.acts_total = 3
	state.hp = 20.0
	state.max_hp = 30.0
	return state


func _rarity_of_relic(id: String) -> String:
	return String(RelicDatabase.get_relic(id)["rarity"])


func _kinds(state: RunState, ctx: Dictionary) -> Array[String]:
	var kinds: Array[String] = []
	for option: Dictionary in RunChoices.options(state, ctx):
		kinds.append(String(option["kind"]))
	return kinds


# --- 4. exactly 2 boss relics, and only boss relics in a boss offer ---

func test_two_mini_bosses_give_exactly_two_boss_relics_and_the_offers_are_boss_only() -> void:
	for character_id: String in CLASSES:
		var pools: Array[String] = CharacterDatabase.pools(character_id)
		for seed_value in range(1, 31):
			var ctx: Dictionary = _ctx(character_id)
			var state: RunState = _state(character_id, seed_value, 1)
			var first_offer: Array[String] = []
			for act in [1, 2]:
				state.act = act
				assert_str(RunRelics.open_for_room(state, "mini_boss", false, ctx)).is_equal(RunState.PENDING_RELIC)
				assert_int(state.offer.size()).is_equal(3)
				for id: String in state.offer:
					assert_str(_rarity_of_relic(id)).override_failure_message("%s in a boss offer is %s" % [id, _rarity_of_relic(id)]).is_equal("boss")
					assert_bool(pools.has(String(RelicDatabase.get_relic(id)["pool"]))).is_true()
					assert_bool(state.relics.has(id)).is_false()
				assert_bool(_kinds(state, ctx).has("relic_skip")).is_false()
				if act == 1:
					first_offer = state.offer.duplicate()
				var result: Dictionary = RunChoices.apply(state, "relic:" + state.offer[seed_value % 3], ctx)
				assert_bool(bool(result["finished"])).is_true()
			var boss_count: int = 0
			for id: String in state.relics:
				if _rarity_of_relic(id) == "boss":
					boss_count += 1
			assert_int(boss_count).override_failure_message("%s seed %d holds %d boss relics" % [character_id, seed_value, boss_count]).is_equal(2)
			assert_int(first_offer.size()).is_equal(3)


# --- 5. rarity: fixed-rarity mini-boss card offers, fall-down, rejects (shipped cards) ---

func test_shipped_mini_boss_card_offers_are_rare_then_legendary_and_every_slot_obeys_the_rule() -> void:
	for character_id: String in CLASSES:
		var ctx: Dictionary = _ctx(character_id)
		for seed_value in range(1, 41):
			for entry: Array in [[1, "rare"], [2, "legendary"]]:
				var state: RunState = _state(character_id, seed_value, int(entry[0]))
				assert_str(RunChoices.open_for_room(state, "mini_boss", false, ctx)).is_equal(RunState.PENDING_REWARD)
				assert_str(state.offer_rarity).is_equal(String(entry[1]))
				assert_int(state.offer.size()).is_equal(3)
				for id: String in state.offer:
					assert_str(CardSchema.rarity_of(CardDatabase.get_card(id))).is_equal(String(entry[1]))


func test_the_fall_down_rule_uses_the_next_rarity_down_when_the_shipped_pool_runs_dry_and_never_rises() -> void:
	var ctx: Dictionary = _ctx("rogue")
	var all_rare: Array[String] = []
	var all_legendary: Array[String] = []
	for entry: Variant in CardDatabase.all_cards():
		var card: Dictionary = entry
		if CardSchema.rarity_of(card) == "rare":
			all_rare.append(String(card["id"]))
		elif CardSchema.rarity_of(card) == "legendary":
			all_legendary.append(String(card["id"]))
	# Every legendary pruned: a legendary offer falls to rare.
	var state: RunState = _state("rogue", 7, 2)
	state.removed_cards = all_legendary.duplicate()
	RunChoices.open_for_room(state, "mini_boss", false, ctx)
	assert_int(state.offer.size()).is_equal(3)
	for id: String in state.offer:
		assert_str(CardSchema.rarity_of(CardDatabase.get_card(id))).is_equal("rare")
	# Every legendary and rare pruned: down to common.
	var both: RunState = _state("rogue", 7, 2)
	both.removed_cards = all_legendary + all_rare
	RunChoices.open_for_room(both, "mini_boss", false, ctx)
	assert_int(both.offer.size()).is_equal(3)
	for id: String in both.offer:
		assert_str(CardSchema.rarity_of(CardDatabase.get_card(id))).is_equal("common")
	# A rare offer with every rare pruned never rises to a legendary.
	var rare_dry: RunState = _state("rogue", 7, 1)
	rare_dry.removed_cards = all_rare.duplicate()
	RunChoices.open_for_room(rare_dry, "mini_boss", false, ctx)
	for id: String in rare_dry.offer:
		assert_str(CardSchema.rarity_of(CardDatabase.get_card(id))).is_equal("common")


func test_a_mini_boss_card_offer_rejects_cost_a_reject_and_stop_at_zero() -> void:
	var ctx: Dictionary = _ctx("wizard")
	var state: RunState = _state("wizard", 3, 1)
	RunChoices.open_for_room(state, "mini_boss", false, ctx)
	var before: int = state.rejects_remaining
	var skip: Dictionary = RunChoices.apply(state, "skip", ctx)
	assert_bool(bool(skip["ok"])).is_true()
	assert_int(state.rejects_remaining).is_equal(before - 1)
	var empty: RunState = _state("wizard", 3, 1)
	empty.rejects_remaining = 0
	RunChoices.open_for_room(empty, "mini_boss", false, ctx)
	var refused: Dictionary = RunChoices.apply(empty, "skip", ctx)
	assert_bool(bool(refused["ok"])).is_false()
	assert_str(empty.pending).is_equal(RunState.PENDING_REWARD)
	assert_int(empty.rejects_remaining).is_equal(0)


# --- 6. cap: Cancel during a boss offer, and no deadlock (shipped relics) ---

func test_cancel_at_the_cap_returns_to_the_boss_offer_and_boss_only_holdings_leave_a_way_out() -> void:
	for character_id: String in CLASSES:
		var ctx: Dictionary = _ctx(character_id, 1)
		var held: String = "heavy_sigh"  # a neutral tier 1 relic the shipped pools both own
		assert_bool(RelicDatabase.get_relic(held).is_empty()).is_false()
		var state: RunState = _state(character_id, 11, 1)
		state.relics = [held] as Array[String]
		RunRelics.open_for_room(state, "mini_boss", false, ctx)
		var offer: Array[String] = state.offer.duplicate()
		assert_int(offer.size()).is_equal(3)
		var step: Dictionary = RunChoices.apply(state, "relic:" + offer[1], ctx)
		assert_str(String(step["kind"])).is_equal("relic_swap_open")
		assert_array(RunRelics.giveable_ids(state, ctx)).is_equal([held])
		var cancel: Dictionary = RunChoices.apply(state, "giveup_cancel", ctx)
		assert_bool(bool(cancel["ok"])).is_true()
		assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
		assert_array(state.offer).is_equal(offer)
		assert_str(state.offer_rarity).is_equal("boss")
		assert_bool(_kinds(state, ctx).has("relic_skip")).is_false()
		assert_array(state.relics).is_equal([held])
		RunChoices.apply(state, "relic:" + offer[1], ctx)
		var done: Dictionary = RunChoices.apply(state, "giveup:" + held, ctx)
		assert_bool(bool(done["finished"])).is_true()
		assert_array(state.relics).is_equal([offer[1]])
		# Act 2: only a boss relic is held, at the cap. Nothing can be given up, so the skip must exist.
		state.act = 2
		RunRelics.open_for_room(state, "mini_boss", false, ctx)
		assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
		assert_bool(_kinds(state, ctx).has("relic_skip")).is_true()
		assert_bool(bool(RunChoices.apply(state, "relic:" + state.offer[0], ctx)["ok"])).is_false()
		var skipped: Dictionary = RunChoices.apply(state, "relic_skip", ctx)
		assert_bool(bool(skipped["finished"])).is_true()
		assert_str(state.pending).is_equal(RunState.PENDING_NONE)


# --- 9. worst-case detonate at the stack hard cap ---

func test_worst_case_exsanguinate_detonate_at_the_bleed_hard_cap() -> void:
	var source := StatSource.new()
	add_child(source)
	auto_free(source)
	# Everything that raises Bleed's cap or speed, at once: Blood Oath +9, Serrated Excuse +4, Bad Influence +4, Thousand Memos +4; Synergy
	# Workshop and Bad Influence tick 50% faster each.
	source.stat_modifiers.add_modifier("status_max_stacks.bleed", "oath", StatModifiers.ADDITIVE, 9.0)
	source.stat_modifiers.add_modifier("status_max_stacks.bleed", "serrated", StatModifiers.ADDITIVE, 4.0)
	source.stat_modifiers.add_modifier("status_max_stacks.bleed", "influence", StatModifiers.ADDITIVE, 4.0)
	source.stat_modifiers.add_modifier("status_max_stacks.bleed", "memos", StatModifiers.ADDITIVE, 4.0)
	source.stat_modifiers.add_modifier("status_tick_rate.bleed", "workshop", StatModifiers.MULTIPLICATIVE, 0.5)
	source.stat_modifiers.add_modifier("status_tick_rate.bleed", "influence", StatModifiers.MULTIPLICATIVE, 0.5)
	var target := RelayTarget.new("enemy", 100000.0)
	add_child(target)
	auto_free(target)
	var bleed: Dictionary = StatusDatabase.get_status("bleed")
	for i in range(30):
		target.status_manager.apply_status("bleed", bleed, 4.0, source, "card:test")  # 4 s is the longest Bleed any shipped card or relic applies
	assert_int(target.status_manager.stacks_of("bleed")).is_equal(10)  # the data hard cap, not the 21 the stats would allow
	var ticks: int = target.status_manager.remaining_ticks("bleed")
	var dealt: float = target.status_manager.detonate_status("bleed", 3.0, source, "card:rogue_exsanguinate")
	print("QA worst-case Exsanguinate detonate: %d ticks x 1 x 10 stacks x 3 = %.1f (plus the 21 direct damage hit)" % [ticks, dealt])
	assert_float(dealt).is_equal_approx(float(ticks) * 1.0 * 10.0 * 3.0, 0.001)
	assert_float(dealt).is_less(1000.0)
	assert_bool(is_finite(dealt)).is_true()
	# Composed: the detonate is a card hit (origin card:...), so the source's card_damage_mult_vs_status.bleed (Blood Oath +25%, Salt in the Wound
	# +25%, Synergy Workshop +15%, Hemorrhage Clause +20%) and damage_mult (The Micromanager +25%, Action Item +25%) multiply it in Health.take_damage.
	source.stat_modifiers.add_modifier("card_damage_mult_vs_status.bleed", "oath", StatModifiers.MULTIPLICATIVE, 0.25)
	source.stat_modifiers.add_modifier("card_damage_mult_vs_status.bleed", "salt", StatModifiers.MULTIPLICATIVE, 0.25)
	source.stat_modifiers.add_modifier("card_damage_mult_vs_status.bleed", "workshop", StatModifiers.MULTIPLICATIVE, 0.15)
	source.stat_modifiers.add_modifier("card_damage_mult_vs_status.bleed", "hemorrhage", StatModifiers.MULTIPLICATIVE, 0.20)
	source.stat_modifiers.add_modifier("damage_mult", "micromanager", StatModifiers.MULTIPLICATIVE, 0.25)
	source.stat_modifiers.add_modifier("damage_mult", "action_item", StatModifiers.MULTIPLICATIVE, 0.25)
	var victim := RelayTarget.new("enemy", 100000.0)
	add_child(victim)
	auto_free(victim)
	for i in range(30):
		victim.status_manager.apply_status("bleed", bleed, 4.0, source, "card:test")
	var hp_before: float = victim.health.current_health
	victim.status_manager.detonate_status("bleed", 3.0, source, "card:rogue_exsanguinate")
	var composed: float = hp_before - victim.health.current_health
	print("QA worst-case Exsanguinate detonate with every shipped damage amplifier (+85%% vs Bleeding, +50%% damage_mult): %.1f HP removed (before armor)" % composed)
	assert_float(composed).is_greater(dealt)
	assert_bool(is_finite(composed)).is_true()


# --- 7. save and Continue in the middle of the mini-boss reward ---

func _spawn() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _frames(count: int = 3) -> void:
	for i in range(count):
		await get_tree().process_frame


func _win_room(main: Main) -> void:
	var table: Dictionary = WaveConfig.get_config().duplicate(true)
	table["stages"] = [{"delay": 0.0, "spawns": [{"enemy": "melee_chaser", "count": 1}]}]
	table["first_wave_delay"] = 0.0
	table["finite"] = true
	table["loop_from_stage"] = 0
	main.enemy_spawner.configure_room(table, 1)
	main.enemy_spawner._process(1.0)
	for child in main.get_children():
		if child is Enemy:
			(child as Enemy).health.take_damage(100000.0)
	await _frames(2)


func test_quit_at_the_boss_relic_offer_and_at_the_card_offer_then_continue_gives_the_same_offer() -> void:
	# The game saves only at a boundary (a map screen or a room's start; RunSave refuses "a choice open"), so quitting inside the mini-boss reward
	# resumes at the mini-boss room's start. The reward must then come back identical (same seed, same stream), and the state of an open offer must
	# still round-trip through RunState (the sitting A test covers the fixture form; this is the shipped-data form).
	RunSession.map_override = 1
	var state: RunState = RunSession.begin_new_run(31)
	state.jump_to_room(9)  # the act 1 mini-boss; entering the room autosaves
	var main: Main = _spawn()
	await _frames()
	assert_str(main.run_controller.room_type()).is_equal("mini_boss")
	assert_bool(RunSave.has_save()).is_true()
	await _win_room(main)
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
	assert_str(state.offer_rarity).is_equal("boss")
	var boss_offer: Array[String] = state.offer.duplicate()
	var at_offer: RunState = RunState.from_dict(JSON.parse_string(state.to_json()))
	assert_str(at_offer.pending).is_equal(RunState.PENDING_RELIC)
	assert_str(at_offer.offer_rarity).is_equal("boss")
	assert_array(at_offer.offer).is_equal(boss_offer)
	assert_bool(RunSave.autosave(state)).is_false()  # not a save point: the room-start save stays in place
	var pick: String = boss_offer[0]
	main.run_controller.pick_relic(pick)
	assert_str(state.pending).is_equal(RunState.PENDING_REWARD)
	assert_str(state.offer_rarity).is_equal("rare")
	var card_offer: Array[String] = state.offer.duplicate()
	var at_cards: RunState = RunState.from_dict(JSON.parse_string(state.to_json()))
	assert_str(at_cards.pending).is_equal(RunState.PENDING_REWARD)
	assert_str(at_cards.offer_rarity).is_equal("rare")
	assert_array(at_cards.offer).is_equal(card_offer)
	# quit here (with the card offer open) and Continue: the save is the room's start
	RunSession.clear()
	main.queue_free()
	await _frames()
	assert_bool(RunSave.load_save()).is_true()
	var resumed_state: RunState = RunSession.current
	assert_str(resumed_state.pending).is_equal(RunState.PENDING_NONE)
	assert_int(resumed_state.relics.size()).is_equal(0)  # the boss relic is not held yet: the pick was never saved
	var resumed: Main = _spawn()
	await _frames()
	assert_str(resumed.run_controller.room_type()).is_equal("mini_boss")
	await _win_room(resumed)
	assert_str(resumed_state.pending).is_equal(RunState.PENDING_RELIC)
	assert_array(resumed_state.offer).is_equal(boss_offer)
	assert_str(resumed_state.offer_rarity).is_equal("boss")
	resumed.run_controller.pick_relic(pick)
	assert_array(resumed_state.offer).is_equal(card_offer)
	assert_str(resumed_state.offer_rarity).is_equal("rare")


# --- 11. watch item: how often a real act 3 merchant stocks a legendary or a rare card (shipped data, measured) ---

func test_a_real_act_3_merchant_stock_can_hold_a_legendary_and_never_a_card_above_its_act() -> void:
	for character_id: String in CLASSES:
		var ctx: Dictionary = _ctx(character_id)
		var counts: Dictionary = {1: [0, 0, 0], 2: [0, 0, 0], 3: [0, 0, 0]}  # per act: [common, rare, legendary] cards stocked
		var with_legendary: int = 0
		for seed_value in range(1, 201):
			for act in [1, 2, 3]:
				var state: RunState = _state(character_id, seed_value, act)
				var stock: Dictionary = Merchant.draw_stock(state, 30 + seed_value % 7, 0, ctx, [] as Array[String], [] as Array[String])
				var saw_legendary: bool = false
				for id: String in (stock["cards"] as Array):
					var rarity: String = CardSchema.rarity_of(CardDatabase.get_card(id))
					(counts[act] as Array)[["common", "rare", "legendary"].find(rarity)] += 1
					saw_legendary = saw_legendary or rarity == "legendary"
				if act == 3 and saw_legendary:
					with_legendary += 1
		print("QA merchant card stock by act (common, rare, legendary) for %s: %s; act 3 shops with a legendary: %d of 200" % [character_id, str(counts), with_legendary])
		assert_int(int((counts[1] as Array)[1]) + int((counts[1] as Array)[2])).is_equal(0)  # act 1 weights are common only
		assert_int(int((counts[2] as Array)[2])).is_equal(0)  # act 2 has no legendary weight
		assert_int(int((counts[3] as Array)[2])).is_greater(0)


# --- regression (qa finding, open): the sim bot at a lowered cap with only a boss relic held ---

## `run_wave_sim.ps1 -Run -Seed 1 -Runs 2 -Class rogue -Route first -RelicCap 1` crashes in act 2 ("the bot choice 'relic:...' was refused: Nothing
## you hold can be given up"). A boss relic can't be given up, so at a cap of 1 with one held, a normal relic offer can't be taken, but the model still
## lists its relic options as enabled and `RelicPolicy.offer_choice` picks the first. The fix is either in the policy (skip when nothing can be
## taken) or in the model (mark the option disabled). Remove `do_skip` when it is fixed: this test fails until then (verified before it was skipped).
func test_the_bot_never_picks_a_relic_it_cannot_take_at_the_cap_with_only_a_boss_relic_held(do_skip := true, skip_reason := "open qa finding: RelicPolicy at -RelicCap 1 with a boss relic held (MAP3b review 2026-11-12)") -> void:
	var ctx: Dictionary = _ctx("rogue", 1)
	var state: RunState = _state("rogue", 5, 2)
	state.relics = ["the_micromanager"] as Array[String]
	assert_str(RunRelics.open_for_room(state, "elite", false, ctx)).is_equal(RunState.PENDING_RELIC)
	var choice: String = RelicPolicy.offer_choice(RunChoices.options(state, ctx), state.deck)
	var result: Dictionary = RunChoices.apply(state, choice, ctx)
	assert_bool(bool(result["ok"])).override_failure_message("the bot chose '%s' and the game refused it" % choice).is_true()
