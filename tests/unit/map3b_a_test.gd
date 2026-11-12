class_name Map3bATest
extends GdUnitTestSuite
## MAP3b sitting A: the engine pieces (rarity, boss-relic offer, card prices, stats, stack cap) tested with fixture cards and relics.
## No shipped data gains rare or legendary cards or boss relics in this sitting, so everything here builds its own.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	return main


func after_test() -> void:
	DodgeSwitch.reset()
	Juice.reset()
	CombatEvents.reset()
	RunSession.clear()
	RunConfig.reset_cache()


# --- housekeeping: co-located solid bodies must not climb ---

func test_a_player_and_an_enemy_on_the_same_spot_do_not_climb() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var enemy: Enemy = auto_free((load("res://scenes/enemies/MeleeChaser.tscn") as PackedScene).instantiate())
	enemy.target = main.player
	main.add_child(enemy)
	enemy.global_position = main.player.global_position
	for frame in range(60):
		await get_tree().physics_frame
	assert_float(enemy.global_position.y).override_failure_message("enemy climbed to y %.2f" % enemy.global_position.y).is_less(1.0)
	assert_float(main.player.global_position.y).override_failure_message("player climbed to y %.2f" % main.player.global_position.y).is_less(1.0)


# --- fixtures ---

func _card(id: String, rarity: String, slot_type: String = "attack_single", pool: String = "rogue") -> Dictionary:
	var card: Dictionary = {"id": id, "name": id, "flavor_text": "", "slot_type": slot_type, "pool": pool, "cooldown_modifier": 0.0,
			"effects": [{"template": "cone", "params": {"damage": 5.0, "damage_type": "physical", "range": 2.0, "half_angle_degrees": 45.0}}]}
	if rarity != "":
		card["rarity"] = rarity
	return card


func _cards(commons: int, rares: int, legendaries: int) -> Array:
	var out: Array = []
	for i in range(commons):
		out.append(_card("c%d" % i, ""))
	for i in range(rares):
		out.append(_card("r%d" % i, "rare"))
	for i in range(legendaries):
		out.append(_card("l%d" % i, "legendary"))
	return out


func _rewards(weights: Dictionary) -> Dictionary:
	return {"offer_size": 3, "unowned_weight": 4.0, "owned_weight": 1.0, "reward_room_types": ["combat"], "rarity_weights": weights, "mini_boss_rarity": {"1": "rare", "2": "legendary"}}


func _offer(cards: Array, rewards: Dictionary, seed_value: int = 1, room: int = 1, act: int = 1, fixed: String = "", removed: Array = []) -> Array[String]:
	return RewardOffer.generate(seed_value, room, [], cards, ["rogue"], {}, rewards, [], removed, act, fixed)


func _rarity_of_id(cards: Array, id: String) -> String:
	for card: Variant in cards:
		if String((card as Dictionary)["id"]) == id:
			return CardSchema.rarity_of(card)
	return ""


func _boss_relic(id: String) -> Dictionary:
	return {"id": id, "name": id, "pool": "neutral", "rarity": "boss", "sources": ["mini_boss"], "rule_text": "Fixture.", "flavor_text": "",
			"modifiers": [{"stat": "move_speed", "modifier_type": "multiplicative", "value": 0.1}]}


func _tier_relic(id: String, tier: String) -> Dictionary:
	return {"id": id, "name": id, "pool": "neutral", "rarity": tier, "sources": ["elite", "relic_room", "merchant"], "rule_text": "Fixture.", "flavor_text": "",
			"modifiers": [{"stat": "move_speed", "modifier_type": "multiplicative", "value": 0.05}]}


## A RunChoices context over fixture cards and relics (the rest of it is the shipped context, so options and text work as in a run).
func _ctx(cards: Array, relics: Array, cap: int = 20) -> Dictionary:
	var ctx: Dictionary = RunChoices.shipped_context(["rogue", "fire", "neutral"])
	var by_id: Dictionary = {}
	for card: Variant in cards:
		by_id[String((card as Dictionary)["id"])] = card
	ctx["cards"] = cards
	ctx["by_id"] = by_id
	var relic_by_id: Dictionary = {}
	for relic: Variant in relics:
		relic_by_id[String((relic as Dictionary)["id"])] = relic
	(ctx["relics"] as Dictionary)["catalog"] = relics
	(ctx["relics"] as Dictionary)["by_id"] = relic_by_id
	(ctx["relics"] as Dictionary)["max_owned"] = cap
	(ctx["relics"] as Dictionary)["enabled"] = true
	var rewards: Dictionary = (ctx["rewards"] as Dictionary).duplicate()
	rewards["rarity_weights"] = {"1": {"common": 100}, "2": {"common": 80, "rare": 20}, "3": {"common": 62, "rare": 30, "legendary": 8}}
	ctx["rewards"] = rewards
	return ctx


func _state(act: int = 1) -> RunState:
	var state: RunState = RunState.new_run(5, [] as Array[String], 3, "rogue")
	state.act = act
	state.acts_total = 3
	state.hp = 20.0
	state.max_hp = 30.0
	return state


# --- rarity in the schema ---

func test_a_card_without_rarity_is_common_and_a_bad_rarity_is_an_error() -> void:
	assert_str(CardSchema.rarity_of(_card("a", ""))).is_equal("common")
	assert_str(CardSchema.rarity_of(_card("a", "rare"))).is_equal("rare")
	assert_str(CardSchema.rarity_of({"rarity": "mythic"})).is_equal("common")
	assert_array(CardSchema.validate(_card("a", "legendary"))).is_empty()
	var bad: Dictionary = _card("a", "mythic")
	assert_array(CardSchema.validate(bad)).is_not_empty()
	bad["rarity"] = 3
	assert_array(CardSchema.validate(bad)).is_not_empty()


func test_the_shipped_cards_are_all_common_until_sitting_b() -> void:
	for card: Variant in CardDatabase.all_cards():
		assert_str(CardSchema.rarity_of(card)).is_equal("common")


# --- verify item: cards may use reduce_cooldown ---

func test_cards_may_use_reduce_cooldown() -> void:
	var card: Dictionary = _card("a", "rare")
	card["effects"] = [
		{"template": "reduce_cooldown", "params": {"attack_id": "heavy", "seconds": 1.0}},
		{"template": "reduce_cooldown", "params": {"slot_type": "movement", "seconds": 0.5}},
	]
	assert_array(CardSchema.validate(card)).is_empty()
	card["effects"] = [{"template": "reduce_cooldown", "params": {"seconds": 1.0}}]
	assert_array(CardSchema.validate(card)).is_not_empty()  # still needs exactly one target


func test_a_card_reduce_cooldown_takes_time_off_a_slot_cooldown() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var player: Player = main.player
	var slot: CardSlot = player.card_slots.get_slot("movement")
	slot.cooldown_remaining = 3.0
	var context := EffectContext.new(player, main, "player")
	EffectTemplates.execute("reduce_cooldown", {"slot_type": "movement", "seconds": 1.0}, context)
	assert_float(slot.cooldown_remaining).is_equal_approx(2.0, 0.0001)
	EffectTemplates.execute("reduce_cooldown", {"slot_type": "movement", "seconds": 9.0}, context)
	assert_float(slot.cooldown_remaining).is_equal(0.0)


# --- the rarity roll ---

func test_a_config_without_weights_draws_exactly_the_old_offer() -> void:
	var cards: Array = _cards(8, 3, 2)  # rares and legendaries exist but the act's row has none of them
	var plain: Array[String] = _offer(cards, _rewards({"1": {"common": 100}}))
	var no_table: Array[String] = _offer(cards, {"offer_size": 3, "unowned_weight": 4.0, "owned_weight": 1.0})
	assert_array(plain).is_equal(no_table)
	for id: String in plain:
		assert_str(_rarity_of_id(cards, id)).is_equal("common")
	# A commons-only pool gives the same ids as before rarity existed, whatever the act's row says (the roll has its own stream).
	var commons: Array = _cards(8, 0, 0)
	assert_array(_offer(commons, _rewards({"1": {"common": 62, "rare": 30, "legendary": 8}}))).is_equal(_offer(commons, {"offer_size": 3, "unowned_weight": 4.0, "owned_weight": 1.0}))


func test_the_per_slot_roll_follows_the_act_weights() -> void:
	var cards: Array = _cards(12, 12, 12)
	var weights: Dictionary = {"1": {"common": 100}, "2": {"common": 80, "rare": 20}, "3": {"common": 62, "rare": 30, "legendary": 8}}
	var counts: Dictionary = {"common": 0, "rare": 0, "legendary": 0}
	for room in range(300):
		for id: String in _offer(cards, _rewards(weights), 7, room, 3):
			var rarity: String = _rarity_of_id(cards, id)
			counts[rarity] = int(counts[rarity]) + 1
	var total: float = float(int(counts["common"]) + int(counts["rare"]) + int(counts["legendary"]))
	assert_float(float(counts["common"]) / total).is_between(0.52, 0.72)
	assert_float(float(counts["rare"]) / total).is_between(0.22, 0.38)
	assert_float(float(counts["legendary"]) / total).is_between(0.03, 0.14)
	for room in range(60):
		for id: String in _offer(cards, _rewards(weights), 7, room, 1):
			assert_str(_rarity_of_id(cards, id)).is_equal("common")  # act 1 is common only
		for id: String in _offer(cards, _rewards(weights), 7, room, 2):
			assert_str(_rarity_of_id(cards, id)).is_not_equal("legendary")  # act 2 has no legendary


func test_an_offer_repeats_for_a_seed_and_has_distinct_cards() -> void:
	var cards: Array = _cards(6, 6, 6)
	var weights: Dictionary = {"3": {"common": 62, "rare": 30, "legendary": 8}}
	var a: Array[String] = _offer(cards, _rewards(weights), 11, 4, 3)
	assert_array(a).is_equal(_offer(cards, _rewards(weights), 11, 4, 3))
	var seen: Dictionary = {}
	for id: String in a:
		assert_bool(seen.has(id)).is_false()
		seen[id] = true


func test_an_empty_rarity_falls_to_the_next_one_down_and_never_up() -> void:
	var weights: Dictionary = {"3": {"legendary": 100}}
	for id: String in _offer(_cards(5, 0, 0), _rewards(weights), 3, 1, 3):
		assert_str(id).starts_with("c")  # legendary -> rare -> common
	var mixed: Array[String] = _offer(_cards(5, 1, 0), _rewards(weights), 3, 1, 3)
	assert_int(mixed.size()).is_equal(3)
	assert_int(mixed.filter(func(id: String) -> bool: return id.begins_with("r")).size()).is_equal(1)
	# No commons at all and a common roll: the slot never rises, so the offer is empty.
	assert_array(_offer(_cards(0, 4, 0), _rewards({"1": {"common": 100}}), 3, 1, 1)).is_empty()


func test_pruned_cards_never_come_back_at_any_rarity() -> void:
	var cards: Array = _cards(6, 4, 0)
	var removed: Array = ["r0", "r1", "r2", "c0"]
	for room in range(40):
		for id: String in _offer(cards, _rewards({"3": {"rare": 100}}), 5, room, 3, "", removed):
			assert_bool(removed.has(id)).is_false()


func test_the_fixed_rarity_offer_is_all_that_rarity_with_fall_down() -> void:
	var cards: Array = _cards(6, 4, 3)
	for id: String in _offer(cards, _rewards({"1": {"common": 100}}), 5, 10, 1, "rare"):
		assert_str(_rarity_of_id(cards, id)).is_equal("rare")
	for id: String in _offer(cards, _rewards({"1": {"common": 100}}), 5, 20, 2, "legendary"):
		assert_str(_rarity_of_id(cards, id)).is_equal("legendary")
	var offer: Array[String] = _offer(_cards(5, 2, 0), _rewards({}), 5, 10, 1, "rare")  # two rares: the third slot falls to a common
	assert_int(offer.size()).is_equal(3)
	assert_int(offer.filter(func(id: String) -> bool: return id.begins_with("r")).size()).is_equal(2)
	assert_int(_offer(_cards(5, 0, 0), _rewards({}), 5, 10, 1, "rare").size()).is_equal(3)  # no rare at all: a common offer


func test_the_lean_still_applies_inside_a_rarity() -> void:
	var burn_card: Dictionary = _card("r_burn", "rare")
	burn_card["effects"] = [{"template": "apply_status", "params": {"status_id": "burn", "duration": 3.0}}]
	var plain: Dictionary = _card("r_plain", "rare")
	var owned: Dictionary = _card("c_burn", "")
	owned["effects"] = [{"template": "apply_status", "params": {"status_id": "burn", "duration": 3.0}}]
	var rewards: Dictionary = _rewards({})
	rewards["status_lean"] = 2.0
	rewards["status_lean_max"] = 5.0
	rewards["offer_size"] = 1
	var wins: int = 0
	for room in range(200):
		var offer: Array[String] = RewardOffer.generate(2, room, ["c_burn"], [burn_card, plain, owned], ["rogue"], {}, rewards, [], [], 2, "rare")
		if offer == ["r_burn"]:
			wins += 1
	assert_int(wins).is_greater(100)  # without the lean it would be about half


func test_the_rarity_config_is_validated() -> void:
	assert_array(RunConfig.validate_rarity_rewards({"rarity_weights": {"1": {"common": 100}}, "mini_boss_rarity": {"1": "rare"}})).is_empty()
	for bad: Dictionary in [
			{"rarity_weights": {}}, {"rarity_weights": {"x": {"common": 1}}}, {"rarity_weights": {"1": {"mythic": 5}}},
			{"rarity_weights": {"1": {"common": 0}}}, {"rarity_weights": {"1": {"common": -1}}}, {"rarity_weights": {"1": 5}},
			{"mini_boss_rarity": {"1": "epic"}}, {"mini_boss_rarity": {"first": "rare"}}, {"mini_boss_rarity": 3}]:
		assert_array(RunConfig.validate_rarity_rewards(bad)).override_failure_message("accepted %s" % str(bad)).is_not_empty()
	var known: Array[String] = ["melee_chaser", "ranged_shooter", "fire_resistant_golem", "boss_guardian", "boss_brute", "boss_duelist"]
	var card_ids: Array[String] = []
	assert_array(RunConfig.validate(RunConfig.get_config(), known, card_ids)).is_empty()
	var broken: Dictionary = RunConfig.get_config().duplicate(true)
	(broken["merchant"] as Dictionary)["card_prices"] = {"common": 90, "rare": 85, "legendary": 125}  # a common dearer than a tier 1 relic
	assert_array(RunConfig.validate(broken, known, card_ids)).is_not_empty()


# --- the mini-boss card offer ---

func test_the_mini_boss_card_offer_is_rare_after_act_1_and_legendary_after_act_2() -> void:
	var cards: Array = _cards(6, 4, 3)
	var ctx: Dictionary = _ctx(cards, [])
	for entry: Array in [[1, "rare"], [2, "legendary"]]:
		var state: RunState = _state(int(entry[0]))
		assert_str(RunChoices.open_for_room(state, "mini_boss", false, ctx)).is_equal(RunState.PENDING_REWARD)
		assert_str(state.offer_rarity).is_equal(String(entry[1]))
		assert_int(state.offer.size()).is_equal(3)
		for id: String in state.offer:
			assert_str(_rarity_of_id(cards, id)).is_equal(String(entry[1]))
		var model: Dictionary = RunChoices.model(state, ctx)
		assert_str(String(model["offer_rarity"])).is_equal(String(entry[1]))
		for option: Dictionary in model["options"]:
			if String(option["kind"]) == "card":
				assert_str(String(option["rarity"])).is_equal(String(entry[1]))


func test_the_mini_boss_card_offer_falls_down_when_the_pool_has_none_and_rejects_work() -> void:
	var ctx: Dictionary = _ctx(_cards(6, 0, 0), [])  # what the shipped data is today: commons only
	var state: RunState = _state(1)
	assert_str(RunChoices.open_for_room(state, "mini_boss", false, ctx)).is_equal(RunState.PENDING_REWARD)
	assert_int(state.offer.size()).is_equal(3)
	for id: String in state.offer:
		assert_str(id).starts_with("c")
	var rejects: int = state.rejects_remaining
	var result: Dictionary = RunChoices.apply(state, "skip", ctx)
	assert_bool(bool(result["ok"])).is_true()
	assert_int(state.rejects_remaining).is_equal(rejects - 1)
	assert_str(state.offer_rarity).is_equal("")  # closing clears it
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)


func test_a_normal_combat_offer_has_no_fixed_rarity() -> void:
	var ctx: Dictionary = _ctx(_cards(6, 4, 3), [])
	var state: RunState = _state(1)
	assert_str(RunChoices.open_for_room(state, "combat", false, ctx)).is_equal(RunState.PENDING_REWARD)
	assert_str(state.offer_rarity).is_equal("")


# --- the boss-relic offer ---

func test_the_mini_boss_offers_boss_relics_with_no_skip() -> void:
	var relics: Array = [_boss_relic("b1"), _boss_relic("b2"), _boss_relic("b3"), _boss_relic("b4"), _tier_relic("t1", "tier1")]
	var ctx: Dictionary = _ctx(_cards(6, 0, 0), relics)
	var state: RunState = _state(1)
	assert_str(RunRelics.open_for_room(state, "mini_boss", false, ctx)).is_equal(RunState.PENDING_RELIC)
	assert_str(state.offer_rarity).is_equal("boss")
	assert_int(state.offer.size()).is_equal(3)
	for id: String in state.offer:
		assert_str(id).starts_with("b")
	var model: Dictionary = RunChoices.model(state, ctx, "mini_boss")
	assert_bool(bool(model["boss_offer"])).is_true()
	var kinds: Array[String] = []
	for option: Dictionary in model["options"]:
		kinds.append(String(option["kind"]))
	assert_bool(kinds.has("relic_skip")).is_false()
	assert_int(kinds.count("relic")).is_equal(3)
	assert_bool(bool(RunChoices.apply(state, "relic_skip", ctx)["ok"])).is_false()
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)  # still open
	var pick: String = state.offer[0]
	var result: Dictionary = RunChoices.apply(state, "relic:" + pick, ctx)
	assert_bool(bool(result["finished"])).is_true()
	assert_bool(state.relics.has(pick)).is_true()
	assert_str(state.offer_rarity).is_equal("")


func test_the_second_boss_offer_excludes_only_the_relic_you_own() -> void:
	var relics: Array = [_boss_relic("b1"), _boss_relic("b2"), _boss_relic("b3"), _boss_relic("b4")]
	var ctx: Dictionary = _ctx(_cards(6, 0, 0), relics)
	var state: RunState = _state(2)
	state.relics = ["b1"] as Array[String]
	RunRelics.open_for_room(state, "mini_boss", false, ctx)
	assert_int(state.offer.size()).is_equal(3)
	assert_bool(state.offer.has("b1")).is_false()


func test_boss_relics_are_never_in_a_normal_offer() -> void:
	var relics: Array = [_boss_relic("b1"), _boss_relic("b2"), _boss_relic("b3"), _tier_relic("t1", "tier1"), _tier_relic("t2", "tier2")]
	var ctx: Dictionary = _ctx(_cards(6, 0, 0), relics)
	for room_type: String in ["elite", "relic_room"]:
		var state: RunState = _state(2)
		RunRelics.open_for_room(state, room_type, false, ctx)
		assert_str(state.offer_rarity).is_equal("")
		for id: String in state.offer:
			assert_str(id).starts_with("t")


func test_with_no_boss_relic_in_the_data_the_mini_boss_keeps_the_interim_tier_offer() -> void:
	var ctx: Dictionary = _ctx(_cards(6, 0, 0), [_tier_relic("t1", "tier1"), _tier_relic("t2", "tier2"), _tier_relic("t3", "tier2")])
	var state: RunState = _state(1)
	assert_str(RunRelics.open_for_room(state, "mini_boss", false, ctx)).is_equal(RunState.PENDING_RELIC)
	assert_str(state.offer_rarity).is_equal("")
	var kinds: Array[String] = []
	for option: Dictionary in RunChoices.options(state, ctx):
		kinds.append(String(option["kind"]))
	assert_bool(kinds.has("relic_skip")).is_true()


func test_at_the_cap_a_boss_pick_asks_for_a_give_up_and_cancel_returns_to_the_offer() -> void:
	var relics: Array = [_boss_relic("b1"), _boss_relic("b2"), _boss_relic("b3"), _tier_relic("t1", "tier1"), _tier_relic("t2", "tier1"), _boss_relic("bo")]
	var ctx: Dictionary = _ctx(_cards(6, 0, 0), relics, 2)
	var state: RunState = _state(1)
	state.relics = ["t1", "t2"] as Array[String]
	RunRelics.open_for_room(state, "mini_boss", false, ctx)
	assert_str(state.offer_rarity).is_equal("boss")
	var offer: Array[String] = state.offer.duplicate()
	var step: Dictionary = RunChoices.apply(state, "relic:" + offer[0], ctx)
	assert_str(String(step["kind"])).is_equal("relic_swap_open")
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC_SWAP)
	assert_str(state.offer_rarity).is_equal("boss")  # the swap step is still the boss offer
	var cancel: Dictionary = RunChoices.apply(state, "giveup_cancel", ctx)
	assert_bool(bool(cancel["ok"])).is_true()
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)  # back to the offer, not out of it
	assert_array(state.offer).is_equal(offer)
	assert_str(state.offer_rarity).is_equal("boss")
	assert_array(state.relics).is_equal(["t1", "t2"])
	# Confirming the swap takes the boss relic and gives one up.
	RunChoices.apply(state, "relic:" + offer[0], ctx)
	var done: Dictionary = RunChoices.apply(state, "giveup:t1", ctx)
	assert_bool(bool(done["finished"])).is_true()
	assert_bool(state.relics.has(offer[0])).is_true()
	assert_bool(state.relics.has("t1")).is_false()
	assert_str(state.offer_rarity).is_equal("")


func test_the_give_up_step_never_lists_a_boss_relic() -> void:
	var relics: Array = [_boss_relic("b1"), _boss_relic("b2"), _boss_relic("b3"), _boss_relic("b4"), _tier_relic("t1", "tier1")]
	var ctx: Dictionary = _ctx(_cards(6, 0, 0), relics, 2)
	var state: RunState = _state(1)
	state.relics = ["b4", "t1"] as Array[String]
	RunRelics.open_for_room(state, "mini_boss", false, ctx)
	RunChoices.apply(state, "relic:" + state.offer[0], ctx)
	var giveable: Array[String] = RunRelics.giveable_ids(state, ctx)
	assert_array(giveable).is_equal(["t1"])


# --- saves ---

func test_the_boss_offer_the_cancel_state_and_the_card_offer_round_trip_in_a_save() -> void:
	RelicDatabase.load_all()
	var relics: Array = [_boss_relic("b1"), _boss_relic("b2"), _boss_relic("b3"), _tier_relic("t1", "tier1")]
	var ctx: Dictionary = _ctx(_cards(6, 4, 3), relics, 1)
	var state: RunState = _state(1)
	state.relics = ["heavy_sigh"] as Array[String]  # a shipped relic id: the save loader checks owned relics against the data
	(ctx["relics"] as Dictionary)["catalog"].append(_tier_relic("heavy_sigh", "tier1"))
	((ctx["relics"] as Dictionary)["by_id"] as Dictionary)["heavy_sigh"] = _tier_relic("heavy_sigh", "tier1")
	RunRelics.open_for_room(state, "mini_boss", false, ctx)
	var back: RunState = RunState.from_dict(JSON.parse_string(state.to_json()))
	assert_str(back.pending).is_equal(RunState.PENDING_RELIC)
	assert_str(back.offer_rarity).is_equal("boss")
	assert_array(back.offer).is_equal(state.offer)
	# The give-up step (at a cap of 1) saves as the same boss offer's swap.
	RunChoices.apply(state, "relic:" + state.offer[0], ctx)
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC_SWAP)
	var swap: RunState = RunState.from_dict(JSON.parse_string(state.to_json()))
	assert_str(swap.pending).is_equal(RunState.PENDING_RELIC_SWAP)
	assert_str(swap.offer_rarity).is_equal("boss")
	assert_str(swap.relic_incoming).is_equal(state.relic_incoming)
	# The fixed-rarity card offer.
	var rewarded: RunState = _state(2)
	RunChoices.open_for_room(rewarded, "mini_boss", false, ctx)
	var card_back: RunState = RunState.from_dict(JSON.parse_string(rewarded.to_json()))
	assert_str(card_back.pending).is_equal(RunState.PENDING_REWARD)
	assert_str(card_back.offer_rarity).is_equal("legendary")
	assert_array(card_back.offer).is_equal(rewarded.offer)


func test_an_old_save_has_no_offer_rarity_and_a_bad_one_is_dropped_loudly() -> void:
	var state: RunState = _state(1)
	state.pending = RunState.PENDING_REWARD
	state.offer = ["c0"] as Array[String]
	var data: Dictionary = state.to_dict()
	data.erase("offer_rarity")
	var old: RunState = RunState.from_dict(data)
	assert_str(old.offer_rarity).is_equal("")
	assert_str(old.pending).is_equal(RunState.PENDING_REWARD)
	for bad: Variant in ["boss", "mythic", 7, null, ["rare"]]:
		var broken: Dictionary = state.to_dict()
		broken["offer_rarity"] = bad
		var loaded: RunState = RunState.from_dict(broken)
		assert_object(loaded).is_not_null()
		assert_str(loaded.offer_rarity).is_equal("")
		assert_str(loaded.pending).is_equal(RunState.PENDING_REWARD)  # the choice stays open as a normal offer
	assert_str(RunState._offer_rarity_for(RunState.PENDING_NONE, "rare")).is_equal("")


# --- card prices ---

func test_card_prices_by_rarity_and_every_price_is_below_its_relic_tier() -> void:
	var cards: Array = _cards(2, 2, 2)
	var ctx: Dictionary = _ctx(cards, [])
	assert_int(Merchant.card_price(ctx, "c0")).is_equal(55)
	assert_int(Merchant.card_price(ctx, "r0")).is_equal(85)
	assert_int(Merchant.card_price(ctx, "l0")).is_equal(125)
	assert_int(Merchant.card_price(ctx)).is_equal(55)
	var prices: Dictionary = RunConfig.get_config()["merchant"]["card_prices"]
	var relic_prices: Dictionary = RunConfig.get_config()["relics"]["prices"]
	assert_bool(int(prices["common"]) < int(relic_prices["tier1"])).is_true()
	assert_bool(int(prices["rare"]) < int(relic_prices["tier2"])).is_true()
	assert_bool(int(prices["legendary"]) < int(relic_prices["tier3"])).is_true()
	assert_array(MerchantConfig.validate_card_vs_relic_prices(prices, relic_prices)).is_empty()
	assert_array(MerchantConfig.validate_card_vs_relic_prices({"common": 80, "rare": 85, "legendary": 125}, relic_prices)).is_not_empty()
	assert_array(MerchantConfig.validate_card_vs_relic_prices({"common": 55, "rare": 120, "legendary": 125}, relic_prices)).is_not_empty()
	assert_array(MerchantConfig.validate_card_vs_relic_prices({"common": 55, "rare": 85, "legendary": 170}, relic_prices)).is_not_empty()


func test_the_merchant_block_needs_all_three_card_prices() -> void:
	var good: Dictionary = (RunConfig.get_config()["merchant"] as Dictionary).duplicate(true)
	assert_array(MerchantConfig.validate_block(good)).is_empty()
	for bad: Variant in [{"common": 55, "rare": 85}, {"common": 55, "rare": 85, "legendary": 0}, {"common": 55, "rare": 85, "legendary": 125, "epic": 1}, "55", 55]:
		var block: Dictionary = good.duplicate(true)
		block["card_prices"] = bad
		assert_array(MerchantConfig.validate_block(block)).override_failure_message("accepted %s" % str(bad)).is_not_empty()
	var old: Dictionary = good.duplicate(true)
	old.erase("card_prices")
	old["card_price"] = 40
	assert_array(MerchantConfig.validate_block(old)).is_not_empty()  # the flat price is gone


func test_a_rare_costs_its_rarity_price_in_the_shop_and_gold_goes_down_by_it() -> void:
	var cards: Array = _cards(3, 3, 0)
	var ctx: Dictionary = _ctx(cards, [])
	var state: RunState = _state(1)
	state.gold = 100
	Merchant.open_visit(state, 3, ctx)
	state.merchant_visit["cards"] = ["r0", "c0"]
	var items: Array[Dictionary] = Merchant.items(state, ctx)
	var rare_item: Dictionary = items.filter(func(item: Dictionary) -> bool: return String(item["id"]) == "r0")[0]
	assert_int(int(rare_item["price"])).is_equal(85)
	assert_str(String(rare_item["rarity"])).is_equal("rare")
	var result: Dictionary = Merchant.buy_card(state, "r0", ctx)
	assert_bool(bool(result["ok"])).is_true()
	assert_int(state.gold).is_equal(15)
	assert_bool(bool(Merchant.buy_card(state, "c0", ctx)["ok"])).is_false()  # 55 > 15


# --- the new stats ---

func test_attack_damage_mult_scales_light_and_heavy_separately() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var attacks: AttackController = main.player.attacks
	var light: float = attacks.get_damage(&"light")
	var heavy: float = attacks.get_damage(&"heavy")
	assert_float(light).is_greater(0.0)
	main.player.stat_modifiers.add_modifier("attack_damage_mult.light", "t", StatModifiers.ADDITIVE, 0.5)
	assert_float(attacks.get_damage(&"light")).is_equal_approx(light * 1.5, 0.0001)
	assert_float(attacks.get_damage(&"heavy")).is_equal_approx(heavy, 0.0001)
	main.player.stat_modifiers.add_modifier("attack_damage_mult.heavy", "t", StatModifiers.ADDITIVE, 1.0)
	assert_float(attacks.get_damage(&"heavy")).is_equal_approx(heavy * 2.0, 0.0001)


func test_a_light_hit_really_deals_the_scaled_damage() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var player: Player = main.player
	player.attacks.set_auto(&"light", false)
	player.attacks.set_auto(&"heavy", false)
	var dummy: RelayTarget = RelayTarget.new("enemy", 500.0)
	main.add_child(dummy)
	dummy.global_position = player.global_position + Vector3(0.0, 0.0, -1.0)
	player.global_transform.basis = Basis.looking_at(Vector3(0.0, 0.0, -1.0), Vector3.UP)
	await get_tree().physics_frame
	player.stat_modifiers.add_modifier("attack_damage_mult.light", "t", StatModifiers.ADDITIVE, 1.0)
	var before: float = dummy.health.current_health
	player._on_attack_fired(&"light")
	var dealt_scaled: float = before - dummy.health.current_health
	player.stat_modifiers.remove_modifier("attack_damage_mult.light", "t")
	var middle: float = dummy.health.current_health
	player._on_attack_fired(&"light")
	var dealt_base: float = middle - dummy.health.current_health
	assert_float(dealt_base).is_greater(0.0)
	assert_float(dealt_scaled).is_equal_approx(dealt_base * 2.0, 0.01)


func test_the_attack_damage_stat_is_validated_like_a_factor_stat() -> void:
	var buff: Dictionary = {"stat": "attack_damage_mult.light", "modifier_type": "additive", "value": 0.25, "duration": 5.0}
	assert_array(EffectTemplates.validate_params("buff", buff)).is_empty()
	buff["stat"] = "attack_damage_mult.heavy"
	assert_array(EffectTemplates.validate_params("buff", buff)).is_empty()
	buff["stat"] = "attack_damage_mult.dodge"
	assert_array(EffectTemplates.validate_params("buff", buff)).is_not_empty()
	buff["stat"] = "attack_damage_mult.light"
	buff["value"] = -1.0
	assert_array(EffectTemplates.validate_params("buff", buff)).is_not_empty()  # the factor would be zero


func test_dead_card_swap_locked_refuses_the_swap_and_the_plan_bot_never_asks_for_one() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var controller: CardSlotController = main.player.card_slots
	assert_bool(controller.swap_locked()).is_false()
	var slot: CardSlot = controller.get_slot("attack_single")
	slot.cooldown_remaining = 0.0
	var first: String = slot.current_card_id
	assert_bool(controller.try_swap("attack_single")).is_true()
	assert_bool(slot.cooldown_remaining > 0.0).is_true()
	slot.cooldown_remaining = 0.0
	main.player.stat_modifiers.add_modifier(CardSlotController.SWAP_LOCKED_STAT, "lock", StatModifiers.ADDITIVE, 1.0)
	assert_bool(controller.swap_locked()).is_true()
	var shown: String = slot.current_card_id
	assert_bool(controller.try_swap("attack_single")).is_false()
	assert_str(slot.current_card_id).is_equal(shown)
	assert_float(slot.cooldown_remaining).is_equal(0.0)  # no penalty either
	main.player.stat_modifiers.remove_modifier(CardSlotController.SWAP_LOCKED_STAT, "lock")
	assert_bool(controller.swap_locked()).is_false()
	assert_str(first).is_not_empty()


func test_plan_policy_decides_cast_or_wait_instead_of_swap_while_locked() -> void:
	# Drive By wants a Movement cast within 2 s; with no Movement card coming, the plan bot swaps it away. Locked, it must not.
	var slot := CardSlot.new("attack_single", 1.0, ["rogue_drive_by", "rogue_quick_slash"] as Array[String], 1.0)
	slot.current_card_id = "rogue_drive_by"
	slot.cooldown_remaining = 0.0
	var view: Dictionary = {"now": 5.0, "history": null, "zone_count": 0, "origin": Vector3.ZERO, "forward": Vector3(0, 0, -1), "aim_point": Vector3(0, 0, -2), "arena": Rect2(),
			"enemies": [{"pos": Vector3(0, 0, -5), "statuses": [], "stacks": {}}]}
	var free_policy := PlanPolicy.new()
	assert_bool(free_policy.swap_locked).is_false()
	assert_str(free_policy.decide("attack_single", slot, {"attack_single": slot}, view, 1.0, false, true)).is_equal(PlanPolicy.SWAP)
	var locked_policy := PlanPolicy.new()
	locked_policy.swap_locked = true
	for step in range(6):
		view["now"] = 5.0 + float(step)
		assert_str(locked_policy.decide("attack_single", slot, {"attack_single": slot}, view, 1.0, false, true)).is_not_equal(PlanPolicy.SWAP)


# --- verify item: a relic-applied primed buff is consumed by a card cast (Sabbatical Fund) ---

func test_a_primed_buff_applied_by_a_relic_is_used_up_by_the_next_matching_card_cast() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var relic: Dictionary = {"id": "fund", "name": "Fund", "pool": "neutral", "rarity": "tier3", "sources": ["elite"], "rule_text": "x", "flavor_text": "",
			"triggers": [{"event": "card_cast", "filter": {"slot_type": "movement"}, "at": "player", "effects": [
				{"template": "buff", "params": {"stat": "slot_cooldown_skip.attack_single", "modifier_type": "additive", "value": 1.0, "duration": 10.0, "consume_on_cast": "attack_single"}}]}]}
	assert_array(RelicSchema.validate(relic)).is_empty()
	var manager := RelicManager.new()
	main.add_child(manager)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	manager.configure(main.player, main, rng, CombatEvents, {"fund": relic})
	manager.load_relics(["fund"] as Array[String])
	var controller: CardSlotController = main.player.card_slots
	CombatEvents.card_cast.emit("movement", "x", [] as Array[String])
	manager.flush()
	assert_array(main.player.stat_modifiers.primed_ids()).has_size(1)  # the relic's buff is primed
	var slot: CardSlot = controller.get_slot("attack_single")
	slot.cooldown_remaining = 0.0
	assert_bool(controller.try_use("attack_single")).is_true()
	assert_float(slot.cooldown_remaining).override_failure_message("the primed cooldown skip was not used by the cast").is_less_equal(CardSlot.MIN_COOLDOWN + 0.0001)
	assert_array(main.player.stat_modifiers.primed_ids()).is_empty()  # consumed
	slot.cooldown_remaining = 0.0
	assert_bool(controller.try_use("attack_single")).is_true()
	assert_float(slot.cooldown_remaining).is_greater(CardSlot.MIN_COOLDOWN + 0.1)  # the next cast pays its cooldown again


# --- verify item: relic-spawned projectiles follow the aim, not the body's facing ---

func test_a_relic_projectile_flies_toward_the_reticle_not_where_the_body_faces() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var player: Player = main.player
	player.attacks.set_auto(&"light", false)
	player.attacks.set_auto(&"heavy", false)
	player.global_transform.basis = Basis.looking_at(Vector3(0.0, 0.0, -1.0), Vector3.UP)  # the body faces -z
	player.aim_point_override = player.global_position + Vector3(10.0, 0.0, 0.0)  # the reticle is at +x
	var relic: Dictionary = {"id": "bolt", "name": "Bolt", "pool": "neutral", "rarity": "tier3", "sources": ["elite"], "rule_text": "x", "flavor_text": "",
			"triggers": [{"event": "card_cast", "at": "player", "effects": [
				{"template": "projectile", "params": {"damage": 1.0, "damage_type": "physical", "speed": 1.0, "max_range": 3.0, "hit_radius": 0.3}}]}]}
	assert_array(RelicSchema.validate(relic)).is_empty()
	var manager := RelicManager.new()
	main.add_child(manager)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	manager.configure(main.player, main, rng, CombatEvents, {"bolt": relic})
	manager.load_relics(["bolt"] as Array[String])
	var before: Array[Node] = main.find_children("*", "Projectile", true, false)
	CombatEvents.card_cast.emit("utility", "x", [] as Array[String])
	manager.flush()
	var after: Array[Node] = main.find_children("*", "Projectile", true, false)
	var fresh: Array[Node] = after.filter(func(node: Node) -> bool: return not before.has(node))
	assert_int(fresh.size()).is_equal(1)
	var bolt: Projectile = fresh[0]
	assert_float(bolt._direction.dot(Vector3(1.0, 0.0, 0.0))).override_failure_message("the bolt flew %s" % bolt._direction).is_greater(0.99)


# --- the stack ceiling and the slot view ---

func test_stacking_hard_cap_clamps_the_stat_raised_cap() -> void:
	assert_int(int(StatusDatabase.get_status("bleed")["stacking"]["hard_cap"])).is_equal(10)
	assert_int(int(StatusDatabase.get_status("burn")["stacking"]["hard_cap"])).is_equal(10)
	var main := _spawn_main()
	await get_tree().process_frame
	main.player.stat_modifiers.add_modifier("status_max_stacks.bleed", "a", StatModifiers.ADDITIVE, 30.0)
	var target := RelayTarget.new("enemy", 10000.0)
	main.add_child(target)
	for i in range(25):
		target.status_manager.apply_status("bleed", StatusDatabase.get_status("bleed"), 5.0, main.player, "card:x")
	assert_int(target.status_manager.stacks_of("bleed")).is_equal(10)
	assert_int(target.status_manager.max_stacks_of("bleed")).is_equal(10)


func test_a_hard_cap_alone_is_a_valid_stacking_block_and_a_bad_one_is_refused() -> void:
	var entry: Dictionary = (StatusDatabase.get_status("bleed") as Dictionary).duplicate(true)
	entry["stacking"] = {"hard_cap": 4}
	assert_array(StatusDatabase._validate_stacking(entry["stacking"], true)).is_empty()
	assert_array(StatusDatabase._validate_stacking({"max_stacks": 3, "hard_cap": 6}, true)).is_empty()
	assert_array(StatusDatabase._validate_stacking({"hard_cap": 0}, true)).is_not_empty()
	assert_array(StatusDatabase._validate_stacking({"hard_cap": 1.5}, true)).is_not_empty()
	assert_array(StatusDatabase._validate_stacking({}, true)).is_not_empty()
	assert_array(StatusDatabase._validate_stacking({"cap": 3}, true)).is_not_empty()


func test_the_slot_view_carries_stack_counts_for_a_detonate_card() -> void:
	var card: Dictionary = CardDatabase.get_card("rogue_open_a_vein")
	assert_str(SlotSynergy.detonate_status_of(card)).is_equal("bleed")
	assert_str(SlotSynergy.detonate_status_of(_card("plain", ""))).is_equal("")
	var view: Dictionary = {"origin": Vector3.ZERO, "forward": Vector3(0, 0, -1), "aim_point": Vector3(0, 0, -1), "arena": Rect2(),
			"enemies": [{"pos": Vector3(0, 0, -1.2), "statuses": ["bleed"], "stacks": {"bleed": 4}}, {"pos": Vector3(0, 0, -1.0), "statuses": ["bleed"], "stacks": {"bleed": 7}},
					{"pos": Vector3(0, 0, -9.0), "statuses": ["bleed"], "stacks": {"bleed": 9}}]}
	assert_int(SlotSynergy.stacks_in_area(card, "bleed", view)).is_equal(7)  # the far one is out of the cone
	var info: Dictionary = SlotSynergy.slot_info("attack_single", "rogue_open_a_vein", view, [] as Array[Dictionary], SlotSynergy.default_text())
	assert_str(String(info["detonate_status"])).is_equal("bleed")
	assert_int(int(info["detonate_stacks"])).is_equal(7)
	var plain_info: Dictionary = SlotSynergy.slot_info("attack_single", "rogue_quick_slash", view, [] as Array[Dictionary], SlotSynergy.default_text())
	assert_str(String(plain_info["detonate_status"])).is_equal("")
	assert_int(int(plain_info["detonate_stacks"])).is_equal(0)


# --- common only in pool-filled decks ---

func test_a_pool_filled_deck_takes_only_common_cards() -> void:
	var all: Array = CardDatabase.all_cards()
	var original: Dictionary = {}
	for card: Variant in all:
		original[String((card as Dictionary)["id"])] = (card as Dictionary).get("rarity", "")
	# Mark one rogue attack card rare in the loaded database for this test, build a pool-filled controller, then restore it.
	var target: Dictionary = CardDatabase.get_card("rogue_quick_slash")
	target["rarity"] = "rare"
	var caster := Node3D.new()
	add_child(caster)
	auto_free(caster)
	var controller := CardSlotController.new(caster, caster, "player", StatModifiers.new(), ["rogue", "fire", "neutral"] as Array[String])
	var ids: Array[String] = controller.owned_card_ids()
	assert_bool(ids.has("rogue_quick_slash")).is_false()
	assert_bool(ids.has("rogue_flurry") or ids.has("rogue_cut_corners") or ids.size() > 5).is_true()
	# A preset or --full-deck path (set_deck) keeps every card it is given.
	var placed: Array[String] = controller.set_deck(["rogue_quick_slash"] as Array[String])
	assert_array(placed).is_equal(["rogue_quick_slash"])
	target.erase("rarity")
	if String(original["rogue_quick_slash"]) != "":
		target["rarity"] = original["rogue_quick_slash"]
