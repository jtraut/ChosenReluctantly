class_name Map4cTest
extends GdUnitTestSuite
## MAP4 sitting C: curse cards (the `curse` flag, the exclusions, the deck rules), the curse and removal outcomes of events (`gain_curse`, `remove_curse`, `remove_card`, `has_curse`),
## the cleanse counter and its cap, the bot's curse rules, The Micromanager with a curse in a slot, and the Dig (the rest's third action). Nothing here ships: the cards are
## tests/fixtures/map4c_cards, the relics and events are built in the test, and no shipped card is a curse, so shipped runs are unchanged.

const CARDS := "res://tests/fixtures/map4c_cards"
const SAVE_PATH := "user://tests/map4c_save.json"
const CURSE := "c_curse_idle"
const CURSE_B := "c_curse_slow"


func before_test() -> void:
	RunSession.clear()
	RunSession.forced_event = ""
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	RelicDatabase.load_all()
	CardDatabase.load_all()
	CharacterDatabase.ids()  # its one-time starting-deck check runs against the real cards, before the fixture cards replace them
	CardDatabase.load_all(CARDS)
	DirAccess.make_dir_recursive_absolute("user://tests")


func after_test() -> void:
	CardDatabase.load_all()
	RelicDatabase.load_all()
	EventDatabase.load_all()
	RunSession.clear()
	RunSession.forced_event = ""
	RunSave.delete_save()
	RunSave.reset()
	RunConfig.reset_cache()
	MapConfig.reset_cache()


# --- helpers ---------------------------------------------------------------------------------------

func _relic(id: String, tier: String, sources: Array, modifiers: Array = []) -> Dictionary:
	return {"id": id, "name": id.capitalize(), "pool": "neutral", "rarity": tier, "sources": sources, "rule_text": "rule of " + id, "flavor_text": "", "keywords": [], "modifiers": modifiers}


func _catalog() -> Array:
	var list: Array = [_relic("dig_spade", "tier2", ["event"], [{"stat": "rest_dig", "modifier_type": "additive", "value": 1}]),
			_relic("event_only", "tier2", ["event"])]
	for letter: String in ["a", "b", "c", "d", "e"]:
		list.append(_relic("n1" + letter, "tier1", ["elite", "relic_room", "merchant"]))
		list.append(_relic("n2" + letter, "tier2", ["elite", "relic_room", "merchant"]))
	return list


func _ctx() -> Dictionary:
	var ctx: Dictionary = RunChoices.shipped_context(["neutral"])
	var relics: Dictionary = ctx["relics"]
	relics["catalog"] = _catalog()
	var by_id: Dictionary = {}
	for relic: Variant in _catalog():
		by_id[String((relic as Dictionary)["id"])] = relic
	relics["by_id"] = by_id
	(ctx["events"] as Dictionary)["catalog"] = {}
	return ctx


func _deck(extra: Array[String] = []) -> Array[String]:
	var deck: Array[String] = ["c_att1", "c_att2", "c_att3", "c_util1", "c_util2", "c_util3"]
	deck.append_array(extra)
	return deck


func _state(extra: Array[String] = [], run_seed: int = 5) -> RunState:
	var state: RunState = RunState.new_run(run_seed, _deck(extra), 3, "rogue")
	state.act = 1
	state.room_index = 3
	state.hp = 30.0
	state.max_hp = 30.0
	state.gold = 500
	return state


func _adhoc(state: RunState, ctx: Dictionary, outcomes: Array, requires: Variant = null) -> void:
	var first: Dictionary = {"label": "Do it", "outcomes": outcomes}
	if requires != null:
		first["requires"] = requires
	var event: Dictionary = {"id": "adhoc", "name": "Adhoc", "flavor": "Made in a test.", "acts": [1, 2, 3], "choices": [first, {"label": "Leave", "outcomes": []}]}
	(ctx["events"]["catalog"] as Dictionary)["adhoc"] = event
	state.event_id = "adhoc"
	state.pending = RunState.PENDING_EVENT


func _pick(state: RunState, ctx: Dictionary, index: int = 0) -> Dictionary:
	return RunChoices.apply(state, "%s:%d" % [EventEngine.OPTION_CHOICE, index], ctx)


func _option(options: Array[Dictionary], option_id: String) -> Dictionary:
	for option: Dictionary in options:
		if String(option["id"]) == option_id:
			return option
	return {}


func _count(deck: Array[String], card_id: String) -> int:
	return deck.count(card_id)


# --- the card flag ---------------------------------------------------------------------------------

func test_every_fixture_card_validates_and_loads() -> void:
	var dir := DirAccess.open(CARDS)
	var seen: int = 0
	for file_name: String in dir.get_files():
		if file_name.ends_with(".json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CARDS.path_join(file_name)))
			assert_array(CardSchema.validate(parsed as Dictionary)).is_empty()
			seen += 1
	assert_int(seen).is_equal(12)
	assert_int(CardDatabase.all_cards().size()).is_equal(12)
	assert_bool(CardSchema.is_curse(CardDatabase.get_card(CURSE))).is_true()
	assert_bool(CardSchema.is_curse(CardDatabase.get_card("c_att1"))).is_false()


func test_an_empty_effect_list_is_allowed_only_on_a_curse() -> void:
	var card: Dictionary = (CardDatabase.get_card("c_att1") as Dictionary).duplicate(true)
	card["effects"] = []
	assert_array(CardSchema.validate(card)).is_not_empty()
	var availability: Variant = card["availability"]
	card.erase("availability")  # 3d-B: a curse carries none
	card["curse"] = true
	assert_array(CardSchema.validate(card)).is_empty()
	card["curse"] = false
	card["availability"] = availability
	assert_array(CardSchema.validate(card)).is_not_empty()


func test_a_curse_must_be_neutral_a_real_bool_and_may_still_be_malformed_elsewhere() -> void:
	var card: Dictionary = (CardDatabase.get_card(CURSE) as Dictionary).duplicate(true)
	card["pool"] = "rogue"
	assert_str(" ".join(CardSchema.validate(card))).contains("neutral")
	card["pool"] = "neutral"
	card["curse"] = "yes"
	assert_str(" ".join(CardSchema.validate(card))).contains("curse must be true or false")
	assert_bool(CardSchema.is_curse(card)).is_false()  # only a real `true` is a curse
	card["curse"] = true
	card["slot_type"] = "nonsense"
	assert_array(CardSchema.validate(card)).is_not_empty()


# --- exclusions ------------------------------------------------------------------------------------

func test_reward_offers_never_hold_a_curse() -> void:
	var ctx: Dictionary = _ctx()
	var candidates: Array[String] = RewardOffer.candidate_ids(ctx["cards"], ["neutral"], [] as Array[Dictionary], ctx["pool_defs"])
	assert_array(candidates).is_not_empty()
	assert_bool(candidates.has(CURSE) or candidates.has(CURSE_B)).is_false()
	for act: int in [1, 2, 3]:
		for run_seed in range(60):
			for id: String in RewardOffer.generate(run_seed, 2, _deck([CURSE, CURSE_B]), ctx["cards"], ["neutral"], ctx["pool_defs"], ctx["rewards"], [], [], act):
				assert_bool(CardSchema.is_curse(CardDatabase.get_card(id))).is_false()


func test_a_mini_boss_card_offer_never_holds_a_curse() -> void:
	var ctx: Dictionary = _ctx()
	for run_seed in range(40):
		var state: RunState = _state([CURSE], run_seed)
		state.act = 1 + (run_seed % 2)  # act 1 offers rare, act 2 legendary
		RunChoices.open_for_room(state, "mini_boss", false, ctx)
		assert_str(state.pending).is_equal(RunState.PENDING_REWARD)
		assert_array(state.offer).is_not_empty()
		for id: String in state.offer:
			assert_bool(CardSchema.is_curse(CardDatabase.get_card(id))).is_false()


func test_the_merchant_stock_and_its_rerolls_never_hold_a_curse() -> void:
	var ctx: Dictionary = _ctx()
	for run_seed in range(25):
		var state: RunState = _state([CURSE], run_seed)
		RunMerchant.open_for_room(state, ctx)
		var visit: Dictionary = state.merchant_visit
		assert_array(visit["cards"] as Array).is_not_empty()
		for round_index in range(4):
			for id: Variant in (visit["cards"] as Array):
				assert_bool(CardSchema.is_curse(CardDatabase.get_card(String(id)))).is_false()
			if not bool(Merchant.reroll(state, ctx)["ok"]):
				break


func test_a_pool_filled_deck_and_the_full_deck_never_hold_a_curse() -> void:
	var caster: Node3D = auto_free(Node3D.new())
	var owned: Array[String] = ["neutral"]
	var controller := CardSlotController.new(caster, caster, "player", StatModifiers.new(), owned)
	var ids: Array[String] = controller.owned_card_ids()
	assert_array(ids).is_not_empty()
	assert_bool(ids.has(CURSE) or ids.has(CURSE_B)).is_false()
	var full: Array[String] = RunConfig.cards_in_pools(["neutral"])
	assert_bool(full.has(CURSE) or full.has(CURSE_B)).is_false()
	assert_bool(full.has("c_att1")).is_true()


# --- deck rules ------------------------------------------------------------------------------------

func test_curses_do_not_count_toward_a_slot_minimum() -> void:
	var deck: Array[String] = ["c_att1", "c_att2", CURSE, CURSE]
	var result: DeckCheck = DeckRules.check_shipped(deck)
	var attack: Dictionary = {}
	for entry: Dictionary in result.slots:
		if String(entry["slot_type"]) == "attack_single":
			attack = entry
	assert_int(int(attack["count"])).is_equal(2)  # not 3 and not 4
	assert_int(int(attack["short"])).is_equal(1)


func test_removing_a_curse_is_always_allowed_and_a_curse_never_props_up_a_minimum() -> void:
	var deck: Array[String] = _deck([CURSE, CURSE, CURSE_B])
	var slot_of: Dictionary = DeckRules.slot_map_from_database()
	var config: Dictionary = DeckRules.shipped_config()
	var known: Array = SlotTypeDatabase.known_ids()
	assert_array(DeckRules.can_remove(deck, CURSE, config, slot_of, known)).is_empty()
	assert_array(DeckRules.can_remove(deck, CURSE_B, config, slot_of, known)).is_empty()
	# the slot holds exactly 3 real cards plus curses: taking a real one is still refused
	assert_array(DeckRules.can_remove(deck, "c_att3", config, slot_of, known)).is_not_empty()
	var swap: Array[String] = DeckRules.can_swap(deck, CURSE, "c_att4", config, slot_of, known)
	assert_array(swap).is_empty()


func test_several_copies_of_one_curse_in_one_slot_cycle_and_come_out_one_at_a_time() -> void:
	var caster: Node3D = auto_free(Node3D.new())
	var owned: Array[String] = ["neutral"]
	var controller := CardSlotController.new(caster, caster, "player", StatModifiers.new(), owned, RandomNumberGenerator.new())
	var stacked: Array[String] = ["c_att1", "c_att2", "c_att3", CURSE, CURSE, CURSE]
	controller.set_deck(stacked)
	var slot: CardSlot = controller.get_slot("attack_single")
	assert_int(slot.owned_card_ids.count(CURSE)).is_equal(3)
	var seen: Array[String] = []
	for step in range(12):
		slot.cooldown_remaining = 0.0
		seen.append(slot.current_card_id)
		assert_str(slot.use_card(0.0)).is_not_empty()
	assert_int(seen.count(CURSE)).is_greater(2)  # every copy comes round each cycle
	assert_array(controller.can_remove(CURSE)).is_empty()
	assert_array(controller.owned_card_ids()).contains([CURSE])


# --- casting and swapping a curse ------------------------------------------------------------------

func test_casting_a_curse_uses_the_slot_like_any_card() -> void:
	var caster: Node3D = auto_free(Node3D.new())
	var owned: Array[String] = ["neutral"]
	var controller := CardSlotController.new(caster, caster, "player", StatModifiers.new(), owned)
	controller.set_deck([CURSE, "c_att1"] as Array[String])
	var slot: CardSlot = controller.get_slot("attack_single")
	if slot.current_card_id != CURSE:
		slot.cooldown_remaining = 0.0
		slot.swap_card()
		slot.cooldown_remaining = 0.0
	assert_str(slot.current_card_id).is_equal(CURSE)
	var casts: Array[String] = []
	controller.card_cast.connect(func(_slot_type: String, card_id: String) -> void: casts.append(card_id))
	assert_bool(controller.try_use("attack_single")).is_true()
	assert_array(casts).is_equal([CURSE])
	assert_float(slot.cooldown_remaining).is_equal_approx(controller.base_cooldown_for("attack_single") + 2.0, 0.001)  # the curse's +2 s modifier
	assert_str(slot.current_card_id).is_equal("c_att1")  # the next card was drawn
	assert_bool(controller.try_use("attack_single")).is_false()  # cooling down


func test_a_curse_swaps_like_any_card_and_a_second_curse_swaps_again() -> void:
	var slot := CardSlot.new("attack_single", 1.0, [CURSE, CURSE, "c_att1"] as Array[String], 1.0, RandomNumberGenerator.new())
	slot.curse_swap_penalty = 2.0
	slot.cooldown_remaining = 0.0
	while slot.current_card_id != CURSE:
		slot.swap_card()
		slot.cooldown_remaining = 0.0
	assert_bool(slot.swap_card()).is_true()
	assert_float(slot.cooldown_remaining).is_equal(2.0)  # 3d: swapping past a curse costs the curse value
	assert_float(slot.last_cooldown_duration).is_equal(2.0)


func test_an_ordinary_swap_stays_at_the_ordinary_penalty_when_a_curse_penalty_is_set() -> void:
	var slot := CardSlot.new("attack_single", 1.0, [CURSE, "c_att1", "c_att2"] as Array[String], 1.0, RandomNumberGenerator.new())
	slot.curse_swap_penalty = 2.0
	while slot.current_card_id == CURSE:
		slot.swap_card()
		slot.cooldown_remaining = 0.0
	slot.cooldown_remaining = 0.0
	assert_float(slot.current_swap_penalty()).is_equal(1.0)
	assert_bool(slot.swap_card()).is_true()
	assert_float(slot.cooldown_remaining).is_equal(1.0)


func test_the_controller_reads_both_swap_penalties_from_run_json() -> void:
	assert_float(RunConfig.swap_penalty()).is_equal(1.0)
	assert_float(RunConfig.curse_swap_penalty()).is_equal(2.0)
	var caster: Node3D = auto_free(Node3D.new())
	var controller := CardSlotController.new(caster, caster, "player", StatModifiers.new(), ["neutral"] as Array[String], RandomNumberGenerator.new())
	controller.set_deck([CURSE, "c_att1", "c_att2"] as Array[String])
	var slot: CardSlot = controller.get_slot("attack_single")
	assert_float(slot.swap_penalty).is_equal(1.0)
	assert_float(slot.curse_swap_penalty).is_equal(2.0)


func test_the_swap_penalties_in_run_json_are_validated() -> void:
	var config: Dictionary = RunConfig.get_config().duplicate(true)
	for bad: Variant in [-1.0, "x", 99.0, null]:
		config["curses"] = {"max_cleanses": -1, "swap_penalty": 1.0, "curse_swap_penalty": bad}
		assert_str(" ".join(RunConfig.validate(config, [] as Array[String], [] as Array[String]))).contains("curse_swap_penalty")


func test_the_micromanager_plus_a_curse_keeps_the_slot_cycling() -> void:
	var caster: Node3D = auto_free(Node3D.new())
	var owned: Array[String] = ["neutral"]
	var modifiers := StatModifiers.new()
	var controller := CardSlotController.new(caster, caster, "player", modifiers, owned, RandomNumberGenerator.new())
	controller.set_deck(["c_att1", "c_att2", CURSE, CURSE] as Array[String])
	modifiers.add_modifier(CardSlotController.SWAP_LOCKED_STAT, "the_micromanager", StatModifiers.ADDITIVE, 1.0)
	assert_bool(controller.swap_locked()).is_true()
	var slot: CardSlot = controller.get_slot("attack_single")
	var policy := PlanPolicy.new()
	policy.swap_locked = true
	var view: Dictionary = {"now": 5.0, "history": null, "zone_count": 0, "origin": Vector3.ZERO, "enemies": []}
	var curse_casts: int = 0
	var real_casts: int = 0
	var shown: Array[String] = []
	for step in range(30):
		slot.cooldown_remaining = 0.0  # the slot is ready each step; the cooldown it started is checked below
		var current: String = slot.current_card_id
		shown.append(current)
		assert_bool(controller.try_swap("attack_single")).is_false()  # no swap while locked, so the bot may not rely on one
		var decision: String = policy.decide("attack_single", slot, {"attack_single": slot}, view, 1.0, false, true)
		if CardSchema.is_curse(CardDatabase.get_card(current)):
			assert_str(decision).is_equal(PlanPolicy.CAST)  # the only way past a curse
			assert_bool(controller.try_use("attack_single")).is_true()
			curse_casts += 1
			assert_float(slot.cooldown_remaining).is_greater(0.0)
		else:
			assert_str(slot.use_card(0.0, modifiers)).is_equal(current)  # a real card is cast by the sim as usual (no enemies here to take a hit)
			real_casts += 1
		assert_str(slot.current_card_id).is_not_empty()
	assert_int(curse_casts).is_greater(5)
	assert_int(real_casts).is_greater(5)


# --- the bot ---------------------------------------------------------------------------------------

func test_the_plan_bot_swaps_a_curse_away_and_casts_it_when_swaps_are_locked_or_the_slot_has_nothing_else() -> void:
	var slot := CardSlot.new("attack_single", 1.0, [CURSE, "c_att1"] as Array[String], 1.0, RandomNumberGenerator.new())
	slot.current_card_id = CURSE
	slot.cooldown_remaining = 0.0
	var view: Dictionary = {"now": 5.0, "history": null, "zone_count": 0, "origin": Vector3.ZERO, "enemies": []}
	var policy := PlanPolicy.new()
	assert_str(policy.decide("attack_single", slot, {"attack_single": slot}, view, 1.0, false, true)).is_equal(PlanPolicy.SWAP)  # even with no enemy in reach
	policy.swap_locked = true
	assert_str(policy.decide("attack_single", slot, {"attack_single": slot}, view, 1.0, false, true)).is_equal(PlanPolicy.CAST)
	policy.swap_locked = false
	var only: CardSlot = CardSlot.new("attack_single", 1.0, [CURSE, CURSE] as Array[String], 1.0, RandomNumberGenerator.new())
	only.current_card_id = CURSE
	only.cooldown_remaining = 0.0
	assert_str(policy.decide("attack_single", only, {"attack_single": only}, view, 1.0, false, true)).is_equal(PlanPolicy.CAST)  # nothing to swap to
	slot.cooldown_remaining = 0.5
	assert_str(policy.decide("attack_single", slot, {"attack_single": slot}, view, 1.0, false, true)).is_equal(PlanPolicy.WAIT)


func test_the_bot_removes_a_curse_first_then_a_spare_copy_then_any_card() -> void:
	var curse_option: Dictionary = {"id": "event_remove:" + CURSE, "kind": "remove", "enabled": true, "count": 1, "curse": true}
	var spare: Dictionary = {"id": "event_remove:c_att1", "kind": "remove", "enabled": true, "count": 2, "curse": false}
	var plain: Dictionary = {"id": "event_remove:c_att2", "kind": "remove", "enabled": true, "count": 1, "curse": false}
	var greyed: Dictionary = {"id": "event_remove:c_att3", "kind": "remove", "enabled": false, "count": 3, "curse": false}
	assert_str(RouteBot.removal_choice([plain, spare, curse_option])).is_equal("event_remove:" + CURSE)
	assert_str(RouteBot.removal_choice([plain, spare])).is_equal("event_remove:c_att1")
	assert_str(RouteBot.removal_choice([greyed, plain])).is_equal("event_remove:c_att2")
	assert_str(RouteBot.removal_choice([greyed])).is_equal("")
	var ctx: Dictionary = _ctx()
	var state: RunState = _state([CURSE])
	state.deck.append("c_att4")
	_adhoc(state, ctx, [{"type": "remove_card"}])
	_pick(state, ctx)
	var model_options: Array[Dictionary] = RunChoices.options(state, ctx)
	assert_str(RouteBot.removal_choice(model_options)).is_equal("event_remove:" + CURSE)  # the real model carries the `curse` flag the bot reads


# --- outcomes: gain_curse --------------------------------------------------------------------------

func test_gain_curse_with_an_id_adds_that_curse_and_a_random_one_is_seeded_and_uniform() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	_adhoc(state, ctx, [{"type": "gain_curse", "id": CURSE_B}, {"type": "gain_curse", "id": CURSE_B}])
	var result: Dictionary = _pick(state, ctx)
	assert_bool(bool(result["finished"])).is_true()
	assert_int(_count(state.deck, CURSE_B)).is_equal(2)  # copies stack
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)
	var seen: Dictionary = {}
	for run_seed in range(60):
		var random_state: RunState = _state([], run_seed)
		_adhoc(random_state, ctx, [{"type": "gain_curse"}])
		_pick(random_state, ctx)
		var gained: Array[String] = []
		for id: String in random_state.deck:
			if CardSchema.is_curse(CardDatabase.get_card(id)):
				gained.append(id)
		assert_int(gained.size()).is_equal(1)
		seen[gained[0]] = int(seen.get(gained[0], 0)) + 1
		var again: RunState = _state([], run_seed)
		_adhoc(again, ctx, [{"type": "gain_curse"}])
		_pick(again, ctx)
		assert_array(again.deck).is_equal(random_state.deck)  # the same seed and room give the same curse
	assert_int(seen.size()).is_equal(2)
	assert_int(int(seen[CURSE])).is_greater(10)
	assert_int(int(seen[CURSE_B])).is_greater(10)


func test_gain_curse_after_a_chance_and_inside_a_chance_branch_both_work() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	_adhoc(state, ctx, [{"type": "chance", "p": 1.0, "win": [{"type": "gain_curse", "id": CURSE}], "lose": []}])
	_pick(state, ctx)
	assert_int(_count(state.deck, CURSE)).is_equal(1)


# --- outcomes: remove_curse / remove_card ----------------------------------------------------------

func test_remove_curse_opens_a_pick_of_only_the_curses_and_counts_the_cleanse() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state([CURSE, CURSE, CURSE_B])
	_adhoc(state, ctx, [{"type": "lose_gold", "amount": 10}, {"type": "remove_curse"}, {"type": "gain_gold", "amount": 7}])
	var opened: Dictionary = _pick(state, ctx)
	assert_bool(bool(opened["finished"])).is_false()
	assert_str(state.pending).is_equal(RunState.PENDING_EVENT_REMOVE)
	assert_int(state.gold).is_equal(490)  # paid on confirm
	assert_int(state.event_queue.size()).is_equal(2)  # the removal itself and the gold after it
	var options: Array[Dictionary] = RunChoices.options(state, ctx)
	assert_int(options.size()).is_equal(2)  # distinct curses only
	for option: Dictionary in options:
		assert_bool(bool(option["curse"])).is_true()
	var model: Dictionary = RunChoices.model(state, ctx)
	assert_str(String(model["event_screen"])).is_equal("remove")
	assert_str(String(model["remove_kind"])).is_equal("remove_curse")
	var picked: Dictionary = RunChoices.apply(state, "event_remove:" + CURSE, ctx)
	assert_bool(bool(picked["ok"]) and bool(picked["finished"])).is_true()
	assert_str(String(picked["kind"])).is_equal("event_remove")
	assert_int(_count(state.deck, CURSE)).is_equal(1)  # one copy only
	assert_int(state.cleanses).is_equal(1)
	assert_int(state.gold).is_equal(497)  # the outcome after the pick ran
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)
	assert_array(state.removed_cards).is_empty()  # a curse is not a "removed card" (it is never offered anyway)
	assert_bool(state.event_queue.is_empty()).is_true()


func test_a_card_not_in_the_list_or_a_real_card_is_refused_by_remove_curse() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state([CURSE])
	_adhoc(state, ctx, [{"type": "remove_curse"}])
	_pick(state, ctx)
	var refused: Dictionary = RunChoices.apply(state, "event_remove:c_att1", ctx)
	assert_bool(bool(refused["ok"])).is_false()
	assert_str(state.pending).is_equal(RunState.PENDING_EVENT_REMOVE)
	assert_int(state.cleanses).is_equal(0)
	assert_bool(bool(RunChoices.apply(state, "skip", ctx)["ok"])).is_false()  # no way out but the pick: the cost is paid


func test_remove_card_goes_through_can_remove_and_a_picked_curse_counts_as_a_cleanse() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state([CURSE])
	state.deck.append("c_att4")  # attack_single now holds 4 different real cards, utility exactly 3
	_adhoc(state, ctx, [{"type": "remove_card"}])
	_pick(state, ctx)
	assert_str(state.pending).is_equal(RunState.PENDING_EVENT_REMOVE)
	var options: Array[Dictionary] = RunChoices.options(state, ctx)
	assert_bool(bool(_option(options, "event_remove:c_att1")["enabled"])).is_true()
	var blocked: Dictionary = _option(options, "event_remove:c_util1")
	assert_bool(bool(blocked["enabled"])).is_false()  # utility needs 3 different cards
	assert_str(String(blocked["reason"])).is_not_empty()
	assert_bool(bool(_option(options, "event_remove:" + CURSE)["enabled"])).is_true()
	var refused: Dictionary = RunChoices.apply(state, "event_remove:c_util1", ctx)
	assert_bool(bool(refused["ok"])).is_false()
	assert_str(state.pending).is_equal(RunState.PENDING_EVENT_REMOVE)
	var removed: Dictionary = RunChoices.apply(state, "event_remove:c_att1", ctx)
	assert_bool(bool(removed["finished"])).is_true()
	assert_bool(state.deck.has("c_att1")).is_false()
	assert_array(state.removed_cards).contains(["c_att1"])
	assert_int(state.cleanses).is_equal(0)  # a real card is not a cleanse
	var curse_state: RunState = _state([CURSE])
	_adhoc(curse_state, ctx, [{"type": "remove_card"}])
	_pick(curse_state, ctx)
	RunChoices.apply(curse_state, "event_remove:" + CURSE, ctx)
	assert_int(curse_state.cleanses).is_equal(1)  # a curse picked by remove_card is
	assert_bool(curse_state.deck.has(CURSE)).is_false()


func test_a_choice_that_could_not_carry_out_its_removal_is_greyed_with_the_reason() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()  # the deck holds exactly the minimums: no card may go, and there is no curse
	_adhoc(state, ctx, [{"type": "lose_gold", "amount": 30}, {"type": "remove_card"}])
	var option: Dictionary = RunChoices.options(state, ctx)[0]
	assert_bool(bool(option["enabled"])).is_false()
	assert_str(String(option["reason"])).contains("deck minimums")
	assert_int(state.gold).is_equal(500)
	var refused: Dictionary = _pick(state, ctx)
	assert_bool(bool(refused["ok"])).is_false()
	assert_int(state.gold).is_equal(500)  # nothing was charged
	_adhoc(state, ctx, [{"type": "remove_curse"}])
	assert_str(String(RunChoices.options(state, ctx)[0]["reason"])).is_equal("You have no curse")


func test_has_curse_enables_a_choice_only_while_the_deck_holds_one() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	_adhoc(state, ctx, [{"type": "remove_curse"}], {"has_curse": true})
	var options: Array[Dictionary] = RunChoices.options(state, ctx)
	assert_bool(bool(options[0]["enabled"])).is_false()
	assert_str(String(options[0]["reason"])).is_equal("You have no curse")
	assert_bool(bool(options[1]["enabled"])).is_true()  # the leave choice keeps the event finishable
	state.deck.append(CURSE)
	assert_bool(bool(RunChoices.options(state, ctx)[0]["enabled"])).is_true()


func test_the_event_lines_name_the_curse_or_say_random_and_cover_both_removals() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	var named: Array[String] = EventEngine.lines_for([{"type": "gain_curse", "id": CURSE}], state, ctx)
	assert_array(named).is_equal(["Gain the curse Idle Curse (a dud card in one slot)"])
	assert_array(EventEngine.lines_for([{"type": "gain_curse"}], state, ctx)).is_equal(["Gain a random curse (a dud card in one slot)"])
	assert_array(EventEngine.lines_for([{"type": "remove_curse"}], state, ctx)).is_equal(["Remove one of your curses"])
	assert_array(EventEngine.lines_for([{"type": "remove_card"}], state, ctx)).is_equal(["Remove a card"])


# --- the cleanse counter ---------------------------------------------------------------------------

func test_the_rest_removal_counts_a_curse_but_not_a_card() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state([CURSE])
	state.deck.append("c_att4")
	state.pending = RunState.PENDING_REST_REMOVE
	var curse_option: Dictionary = _option(RunChoices.options(state, ctx), "remove:" + CURSE)
	assert_bool(bool(curse_option["curse"])).is_true()
	assert_bool(bool(curse_option["enabled"])).is_true()
	RunChoices.apply(state, "remove:" + CURSE, ctx)
	assert_int(state.cleanses).is_equal(1)
	state.pending = RunState.PENDING_REST_REMOVE
	RunChoices.apply(state, "remove:c_att4", ctx)
	assert_int(state.cleanses).is_equal(1)


func test_the_merchant_removal_counts_a_curse_and_still_costs_the_usual_price() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state([CURSE])
	RunMerchant.open_for_room(state, ctx)
	var price: int = Merchant.removal_price(state, ctx)
	var gold: int = state.gold
	var bought: Dictionary = Merchant.buy_removal(state, CURSE, ctx)
	assert_bool(bool(bought["ok"])).is_true()
	assert_int(state.cleanses).is_equal(1)
	assert_int(state.gold).is_equal(gold - price)
	assert_bool(state.deck.has(CURSE)).is_false()
	assert_int(Merchant.removal_price(state, ctx)).is_greater(price)  # the price still rises per removal bought


func test_with_no_cap_every_curse_can_be_removed() -> void:
	var ctx: Dictionary = _ctx()
	assert_int(int(ctx["max_cleanses"])).is_equal(-1)  # the shipped value
	var state: RunState = _state([CURSE, CURSE, CURSE, CURSE])
	for step in range(4):
		state.pending = RunState.PENDING_REST_REMOVE
		assert_bool(bool(RunChoices.apply(state, "remove:" + CURSE, ctx)["ok"])).is_true()
	assert_int(state.cleanses).is_equal(4)
	assert_int(RunChoices.cleanses_left(state, ctx)).is_equal(-1)


func test_at_the_cap_a_curse_is_greyed_with_a_reason_on_every_path() -> void:
	var ctx: Dictionary = _ctx()
	ctx["max_cleanses"] = 1
	var state: RunState = _state([CURSE, CURSE, CURSE_B])
	state.deck.append("c_att4")
	state.pending = RunState.PENDING_REST_REMOVE
	RunChoices.apply(state, "remove:" + CURSE, ctx)
	assert_int(state.cleanses).is_equal(1)
	assert_int(RunChoices.cleanses_left(state, ctx)).is_equal(0)
	# the rest list
	state.pending = RunState.PENDING_REST_REMOVE
	var rest_options: Array[Dictionary] = RunChoices.options(state, ctx)
	var rest_curse: Dictionary = _option(rest_options, "remove:" + CURSE)
	assert_bool(bool(rest_curse["enabled"])).is_false()
	assert_str(String(rest_curse["reason"])).contains("any more curses")
	assert_bool(bool(_option(rest_options, "remove:c_att4")["enabled"])).is_true()  # real cards are not capped
	assert_bool(bool(RunChoices.apply(state, "remove:" + CURSE, ctx)["ok"])).is_false()
	# the merchant
	RunMerchant.open_for_room(state, ctx)
	var refused: Dictionary = Merchant.buy_removal(state, CURSE_B, ctx)
	assert_bool(bool(refused["ok"])).is_false()
	assert_str(String(refused["reason"])).is_equal("removal_blocked")
	var merchant_curse: Dictionary = _option(RunMerchant._removal_options(state, ctx), RunMerchant.OPTION_REMOVE + ":" + CURSE_B)
	assert_bool(bool(merchant_curse["enabled"])).is_false()
	assert_str(String(merchant_curse["reason"])).contains("any more curses")
	# an event: the choice itself is greyed, so nothing is charged
	_adhoc(state, ctx, [{"type": "lose_gold", "amount": 10}, {"type": "remove_curse"}])
	var choice: Dictionary = RunChoices.options(state, ctx)[0]
	assert_bool(bool(choice["enabled"])).is_false()
	assert_str(String(choice["reason"])).contains("any more curses")
	# remove_card can still run, but its curses are greyed
	_adhoc(state, ctx, [{"type": "remove_card"}])
	_pick(state, ctx)
	var pick_options: Array[Dictionary] = RunChoices.options(state, ctx)
	assert_bool(bool(_option(pick_options, "event_remove:" + CURSE)["enabled"])).is_false()
	assert_bool(bool(_option(pick_options, "event_remove:c_att4")["enabled"])).is_true()
	# the model tells the screen
	assert_int(int(RunChoices.model(state, ctx)["cleanses_left"])).is_equal(0)


func test_at_the_cap_a_deck_of_only_capped_curses_locks_the_rest_menu_with_the_reason() -> void:
	var ctx: Dictionary = _ctx()
	ctx["max_cleanses"] = 0
	var state: RunState = _state([CURSE])
	state.pending = RunState.PENDING_REST
	var menu: Dictionary = _option(RunChoices.options(state, ctx), "remove_menu")
	assert_bool(bool(menu["enabled"])).is_false()  # every real card is held by a minimum and the only curse is capped
	assert_str(String(menu["reason"])).is_not_empty()


func test_the_cleanse_cap_in_run_json_is_validated() -> void:
	var config: Dictionary = RunConfig.get_config().duplicate(true)
	assert_array(RunConfig.validate(config, [] as Array[String], [] as Array[String])).is_empty()
	for bad: Variant in [1.5, "x", -2, 5000, null]:
		config["curses"] = {"max_cleanses": bad, "swap_penalty": 1.0, "curse_swap_penalty": 2.0}
		assert_str(" ".join(RunConfig.validate(config, [] as Array[String], [] as Array[String]))).contains("max_cleanses")
	config["curses"] = {"max_cleanses": 3, "swap_penalty": 1.0, "curse_swap_penalty": 2.0, "extra": 1}
	assert_str(" ".join(RunConfig.validate(config, [] as Array[String], [] as Array[String]))).contains("unknown key")
	config["curses"] = {"max_cleanses": -1, "swap_penalty": 1.0, "curse_swap_penalty": 2.0}
	assert_array(RunConfig.validate(config, [] as Array[String], [] as Array[String])).is_empty()
	assert_int(RunConfig.max_cleanses()).is_equal(-1)


# --- save and resume -------------------------------------------------------------------------------

func _state_on_event(first_seed: int = 1) -> RunState:
	var cfg: Dictionary = MapConfig.get_config().duplicate(true)
	(cfg["types"]["event"] as Dictionary)["weight"] = 12
	for seed_value in range(first_seed, first_seed + 200):
		var map: Dictionary = MapGenerator.generate(seed_value, cfg)
		for entry: Dictionary in (map["nodes"] as Array):
			if String(entry["type"]) != "event":
				continue
			var trail: Array[int] = [int(entry["id"])]
			while int(MapGraph.node(map, trail[0])["room"]) > 1:
				trail.push_front(MapGraph.prev_ids(map, trail[0])[0])
			var state := RunState.new_run(seed_value, _deck([CURSE, CURSE_B]), 3, "rogue")
			state.map = map
			state.path = trail
			state.room_index = trail.size() - 1
			state.hp = 30.0
			state.max_hp = 30.0
			return state
	return null


func _enable_saves() -> void:
	RunSave.reset()
	RunSave.path = SAVE_PATH
	RunSave.persist_override = true
	RunSave.delete_save()


func test_a_pending_removal_pick_round_trips_through_the_save_file_and_is_a_boundary() -> void:
	_enable_saves()
	var ctx: Dictionary = _ctx()
	var state: RunState = _state_on_event(1)
	assert_object(state).is_not_null()
	state.cleanses = 2
	_adhoc(state, ctx, [{"type": "lose_gold", "amount": 10}, {"type": "remove_curse"}, {"type": "gain_gold", "amount": 7}])
	state.gold = 100
	_pick(state, ctx)
	assert_str(state.pending).is_equal(RunState.PENDING_EVENT_REMOVE)
	assert_bool(RunSave.choice_is_savable(state)).is_true()
	assert_bool(RunSave.is_boundary(state)).is_true()
	assert_bool(RunSave.write(state)).is_true()
	var loaded: RunState = RunSave.read_state()
	assert_object(loaded).is_not_null()
	assert_str(RunSave.last_problem).is_empty()
	assert_bool(loaded.equals(state)).is_true()
	assert_str(loaded.pending).is_equal(RunState.PENDING_EVENT_REMOVE)
	assert_int(loaded.cleanses).is_equal(2)
	assert_int(loaded.event_queue.size()).is_equal(2)
	assert_int(loaded.gold).is_equal(90)  # the cost stays paid
	# resuming finishes the way the live run would
	var live_ctx: Dictionary = ctx
	(live_ctx["events"]["catalog"] as Dictionary)["adhoc"] = (ctx["events"]["catalog"] as Dictionary)["adhoc"]
	RunChoices.apply(loaded, "event_remove:" + CURSE, ctx)
	RunChoices.apply(state, "event_remove:" + CURSE, ctx)
	assert_bool(loaded.equals(state)).is_true()
	assert_int(loaded.gold).is_equal(97)
	assert_int(loaded.cleanses).is_equal(3)


func test_a_pending_remove_card_pick_also_round_trips() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state_on_event(1)
	state.deck.append("c_att4")
	_adhoc(state, ctx, [{"type": "remove_card"}])
	_pick(state, ctx)
	var loaded: RunState = RunState.from_json(state.to_json())
	assert_object(loaded).is_not_null()
	assert_bool(loaded.equals(state)).is_true()
	assert_str(loaded.pending).is_equal(RunState.PENDING_EVENT_REMOVE)


func test_a_removal_pick_that_does_not_fit_is_dropped_loudly_and_never_traps_the_run() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state_on_event(1)
	_adhoc(state, ctx, [{"type": "remove_curse"}])
	_pick(state, ctx)
	assert_str(state.pending).is_equal(RunState.PENDING_EVENT_REMOVE)
	var data: Dictionary = state.to_dict()
	var empty_queue: Dictionary = data.duplicate(true)
	empty_queue["event_queue"] = []
	var no_queue: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(empty_queue)) as Dictionary)
	assert_object(no_queue).is_not_null()
	assert_str(no_queue.pending).is_equal(RunState.PENDING_NODE)  # a map run reopens the pick-next-node choice
	var no_curse: Dictionary = data.duplicate(true)
	no_curse["deck"] = _deck()
	var curseless: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(no_curse)) as Dictionary)
	assert_object(curseless).is_not_null()
	assert_str(curseless.pending).is_equal(RunState.PENDING_NODE)
	assert_bool(curseless.event_queue.is_empty()).is_true()
	var wrong_head: Dictionary = data.duplicate(true)
	wrong_head["event_queue"] = [{"type": "gain_gold", "amount": 5}]
	var misfit: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(wrong_head)) as Dictionary)
	assert_object(misfit).is_not_null()
	assert_str(misfit.pending).is_equal(RunState.PENDING_NODE)


func test_the_cleanse_counter_is_saved_and_a_wrong_value_falls_back_to_zero() -> void:
	var state: RunState = _state([CURSE])
	state.cleanses = 4
	var again: RunState = RunState.from_json(state.to_json())
	assert_int(again.cleanses).is_equal(4)
	for bad: Variant in ["x", -3, 1.5, null, [1]]:
		var data: Dictionary = state.to_dict()
		data["cleanses"] = bad
		var loaded: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(data)) as Dictionary)
		assert_object(loaded).is_not_null()
		assert_int(loaded.cleanses).is_equal(0)
	var old: Dictionary = state.to_dict()
	old.erase("cleanses")
	assert_int(RunState.from_dict(JSON.parse_string(JSON.stringify(old)) as Dictionary).cleanses).is_equal(0)  # an old save has none


# --- the Dig ---------------------------------------------------------------------------------------

func test_a_rest_has_no_dig_without_the_spade_and_a_third_action_with_it() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	state.pending = RunState.PENDING_REST
	var plain: Array[Dictionary] = RunChoices.options(state, ctx)
	assert_int(plain.size()).is_equal(2)
	assert_bool(RunChoices.dig_enabled(state, ctx)).is_false()
	state.relics.append("dig_spade")
	assert_bool(RunChoices.dig_enabled(state, ctx)).is_true()
	var options: Array[Dictionary] = RunChoices.options(state, ctx)
	assert_int(options.size()).is_equal(3)
	var dig: Dictionary = _option(options, "dig")
	assert_str(String(dig["kind"])).is_equal("dig")
	assert_str(String(dig["label"])).is_equal("Dig")
	assert_bool(bool(dig["enabled"])).is_true()
	assert_str(String(dig["detail"])).is_not_empty()


func test_the_dig_offers_three_relics_at_the_acts_odds_without_event_only_relics_and_a_pick_ends_the_rest() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	state.relics.append("dig_spade")
	state.hp = 12.0
	state.pending = RunState.PENDING_REST
	var opened: Dictionary = RunChoices.apply(state, "dig", ctx)
	assert_bool(bool(opened["ok"])).is_true()
	assert_bool(bool(opened["finished"])).is_false()
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
	assert_str(state.offer_rarity).is_equal(RunState.OFFER_DIG)
	assert_int(state.offer.size()).is_equal(3)
	assert_bool(state.offer.has("event_only") or state.offer.has("dig_spade")).is_false()
	var model: Dictionary = RunChoices.model(state, ctx)
	assert_str(String(model["title"])).is_equal("Dig")
	var options: Array[Dictionary] = RunChoices.options(state, ctx)
	assert_bool(_option(options, RunRelics.OPTION_SKIP).is_empty()).is_false()  # skip is allowed
	assert_bool(RunSave.choice_is_savable(state)).is_false()  # nothing was paid: not a boundary
	var picked_id: String = state.offer[0]
	var picked: Dictionary = RunChoices.apply(state, "relic:" + picked_id, ctx)
	assert_bool(bool(picked["ok"]) and bool(picked["finished"])).is_true()
	assert_array(state.relics).is_equal(["dig_spade", picked_id])
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)
	assert_float(state.hp).is_equal(12.0)  # no heal: the dig replaced it
	assert_array(state.removed_cards).is_empty()  # and no removal


func test_the_dig_can_be_skipped_and_the_same_rest_gives_the_same_offer_after_a_reload() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	state.relics.append("dig_spade")
	state.pending = RunState.PENDING_REST
	RunChoices.apply(state, "dig", ctx)
	var first: Array[String] = state.offer.duplicate()
	var skipped: Dictionary = RunChoices.apply(state, RunRelics.OPTION_SKIP, ctx)
	assert_bool(bool(skipped["finished"])).is_true()
	assert_str(state.pending).is_equal(RunState.PENDING_NONE)
	assert_array(state.relics).is_equal(["dig_spade"])
	var again: RunState = _state()
	again.relics.append("dig_spade")
	again.pending = RunState.PENDING_REST
	RunChoices.apply(again, "dig", ctx)
	assert_array(again.offer).is_equal(first)  # seeded by the run and room


func test_a_dig_offer_survives_the_round_trip_with_its_kind() -> void:
	var state: RunState = _state_on_event(1)
	state.pending = RunState.PENDING_RELIC
	state.offer = ["n1a", "n1b", "n2a"] as Array[String]
	state.offer_rarity = RunState.OFFER_DIG
	var loaded: RunState = RunState.from_json(state.to_json())
	assert_object(loaded).is_not_null()
	assert_str(loaded.offer_rarity).is_equal(RunState.OFFER_DIG)
	assert_str(loaded.pending).is_equal(RunState.PENDING_RELIC)


func test_the_dig_at_the_relic_cap_asks_for_a_give_up_first_and_is_greyed_when_nothing_is_left() -> void:
	var ctx: Dictionary = _ctx()
	(ctx["relics"] as Dictionary)["max_owned"] = 2
	var state: RunState = _state()
	state.relics.append("dig_spade")
	state.relics.append("n1a")
	state.pending = RunState.PENDING_REST
	RunChoices.apply(state, "dig", ctx)
	var target: String = ""
	for id: String in state.offer:
		target = id
	var step: Dictionary = RunChoices.apply(state, "relic:" + target, ctx)
	assert_str(String(step["kind"])).is_equal("relic_swap_open")  # the usual cap-20 step
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC_SWAP)
	var given: Dictionary = RunChoices.apply(state, "giveup:n1a", ctx)
	assert_bool(bool(given["finished"])).is_true()
	assert_array(state.relics_given_up).is_equal(["n1a"])
	assert_bool(state.relics.has(target)).is_true()
	# every normal relic held or given up: nothing to dig up
	var empty_state: RunState = _state()
	empty_state.relics.append("dig_spade")
	var big: Dictionary = _ctx()
	(big["relics"] as Dictionary)["max_owned"] = 99
	for relic: Variant in _catalog():
		if not empty_state.relics.has(String((relic as Dictionary)["id"])):
			empty_state.relics.append(String((relic as Dictionary)["id"]))
	empty_state.pending = RunState.PENDING_REST
	var dig: Dictionary = _option(RunChoices.options(empty_state, big), "dig")
	assert_bool(bool(dig["enabled"])).is_false()
	assert_str(String(dig["reason"])).is_equal("Nothing left to dig up")
	assert_bool(bool(RunChoices.apply(empty_state, "dig", big)["ok"])).is_false()


func test_a_stat_mod_run_modifier_can_give_the_dig_too() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _state()
	state.run_mods.append({"stat": "rest_dig", "modifier_type": "additive", "value": 1.0})
	assert_bool(RunChoices.dig_enabled(state, ctx)).is_true()
	state.run_mods.clear()
	state.run_mods.append({"stat": "rest_dig", "modifier_type": "multiplicative", "value": 1.0})
	assert_bool(RunChoices.dig_enabled(state, ctx)).is_false()  # only an additive total above 0 counts
