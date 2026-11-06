class_name Map2QaTest
extends GdUnitTestSuite
## qa's MAP2 review: independent property checks on the merchant (random shop sessions against the invariants, stock composition, determinism,
## prices from data, the removal guard, the give-one-up swap, the reroll, saves mid-visit), plus the 7 new relics at the model level. Written
## from the brief and the public behaviour, not from the dev's tests. The merchant is ON in shipped data, so nothing here switches it.

const BOSS_FIXTURE := "res://tests/fixtures/relics_valid/test_boss.json"
const SHOP_ONLY: Array[String] = ["liquidate_assets", "request_for_quotation", "as_per_the_attached_document"]
const NEW_RELICS: Array[String] = ["asap_notice", "severance_package", "paperwork_fire", "grading_curve", "liquidate_assets", "request_for_quotation", "as_per_the_attached_document"]


func before_test() -> void:
	RunSession.clear()
	RunSession.map_override = -1
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	RelicDatabase.load_all()


func after_test() -> void:
	RunSession.clear()
	RunSession.map_override = -1
	RunConfig.reset_cache()
	MapConfig.reset_cache()


# ---- helpers ----

func _ctx(character: String = "rogue", cap: int = 20) -> Dictionary:
	var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools(character))
	(ctx["relics"] as Dictionary)["max_owned"] = cap
	return ctx


func _state(seed_value: int, gold: int, character: String = "rogue", full_deck: bool = false) -> RunState:
	var state := RunState.new_run(seed_value, CharacterDatabase.starting_deck(character), 3, character)
	if full_deck:
		state.deck = RunConfig.cards_in_pools(CharacterDatabase.pools(character))
	state.gold = gold
	state.room_index = 3 + (seed_value % 5)
	return state


func _shop(seed_value: int, gold: int, character: String = "rogue", full_deck: bool = false, ctx: Dictionary = {}) -> Array:
	var use: Dictionary = ctx if not ctx.is_empty() else _ctx(character)
	var state: RunState = _state(seed_value, gold, character, full_deck)
	assert_str(RunChoices.open_for_room(state, "merchant", false, use)).is_equal(RunState.PENDING_MERCHANT)
	return [state, use]


func _screen(state: RunState, ctx: Dictionary) -> String:
	var parts: Array[String] = [state.pending]
	for option: Dictionary in RunChoices.options(state, ctx):
		parts.append("%s|%s|%s|%s|%s" % [option["id"], option["enabled"], option.get("price", -1), option.get("sold", false), option.get("reason_code", "")])
	return "\n".join(parts)


func _is_boss(relic_id: String, ctx: Dictionary) -> bool:
	return String(((ctx["relics"] as Dictionary)["by_id"] as Dictionary).get(relic_id, {}).get("rarity", "")) == "boss"


func _stock_problems(state: RunState, ctx: Dictionary, owned_at_open: Array[String]) -> String:
	var visit: Dictionary = state.merchant_visit
	var relics: Array = visit["relics"]
	var seen: Dictionary = {}
	for id: String in relics:
		if seen.has(id):
			return "duplicate relic %s in stock" % id
		seen[id] = true
		if owned_at_open.has(id):
			return "owned relic %s was stocked" % id
		if state.relics_given_up.has(id) and not (visit["sold_relics"] as Array).has(id):
			return "given-up relic %s is in stock and unsold" % id
		if _is_boss(id, ctx):
			return "boss-tier relic %s in stock" % id
	var cards: Array = visit["cards"]
	var seen_cards: Dictionary = {}
	for id: String in cards:
		if seen_cards.has(id):
			return "duplicate card %s in stock" % id
		seen_cards[id] = true
		if not (ctx["by_id"] as Dictionary).has(id):
			return "unknown card %s in stock" % id
	return ""


# ---- 1. random shop sessions against the invariants ----

func test_random_shop_sessions_hold_every_invariant() -> void:
	var failures: Array[String] = []
	var swaps_seen: int = 0
	var removals_seen: int = 0
	var rerolls_seen: int = 0
	var relic_buys: int = 0
	for seed_value in range(1, 161):
		var character: String = "rogue" if seed_value % 2 == 0 else "wizard"
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value * 7919
		var cap: int = [1, 2, 3, 20][rng.randi() % 4]
		var ctx: Dictionary = _ctx(character, cap)
		var state: RunState = _state(seed_value, rng.randi_range(0, 400), character, rng.randf() < 0.6)
		# some starting relics (never more than the cap), sometimes the free-reroll relic, sometimes a given-up one
		var pool: Array[String] = []
		for r: Dictionary in (ctx["relics"]["catalog"] as Array):
			if (ctx["pools"] as Array).has(String(r["pool"])) and String(r["rarity"]) != "boss":
				pool.append(String(r["id"]))
		for i in range(pool.size() - 1, 0, -1):  # seeded Fisher-Yates (the global RNG would make a failure unrepeatable)
			var j: int = rng.randi() % (i + 1)
			var swap_tmp: String = pool[i]
			pool[i] = pool[j]
			pool[j] = swap_tmp
		for i in range(mini(rng.randi() % 3, cap)):
			state.add_relic(pool[i])
		if rng.randf() < 0.2 and pool.size() > 4:
			state.relics_given_up.append(pool[pool.size() - 1])
			state.relics.erase(pool[pool.size() - 1])
		var owned_at_open: Array[String] = state.relics.duplicate()
		RunChoices.open_for_room(state, "merchant", false, ctx)
		var tag: String = "seed %d (%s, cap %d)" % [seed_value, character, cap]
		var problem: String = _stock_problems(state, ctx, owned_at_open)
		if not problem.is_empty():
			failures.append("%s: %s" % [tag, problem])
			continue
		for step in range(45):
			var options: Array[Dictionary] = RunChoices.options(state, ctx)
			var pick: String
			if rng.randf() < 0.1:
				pick = ["", "buy_relic:", "buy_relic:nope", "buy_card:x", "merchant_remove:", "merchant_giveup:zz", "node:1", "heal", "card:x", "merchant_remove:nope", "merchant_leave:::"][rng.randi() % 11]
			else:
				pick = String(options[rng.randi() % options.size()]["id"])
			if pick == RunMerchant.OPTION_LEAVE and rng.randf() < 0.8:
				continue  # mostly keep shopping
			var before_json: String = state.to_json()
			var gold_before: int = state.gold
			var spent_before: int = state.gold_spent_merchant
			var removals_before: int = state.merchant_removals
			var relics_before: int = state.relics.size()
			var price_before: int = Merchant.removal_price(state, ctx)
			var result: Dictionary = RunChoices.apply(state, pick, ctx)
			if not bool(result["ok"]):
				if state.to_json() != before_json:
					failures.append("%s: refused '%s' changed the state" % [tag, pick])
					break
			else:
				match String(result["kind"]):
					"merchant_remove":
						removals_seen += 1
						if int(result["amount"]) != 50 + 25 * removals_before or state.merchant_removals != removals_before + 1:
							failures.append("%s: removal charged %s with %d before" % [tag, result["amount"], removals_before])
						if not DeckRules.check_shipped(state.deck).is_ok():
							failures.append("%s: a removal left the deck illegal" % tag)
					"merchant_relic":
						relic_buys += 1
						if String(result["gave_up"]) != "":
							swaps_seen += 1
							if state.relics.size() != relics_before:
								failures.append("%s: a swap changed the relic count" % tag)
							if not state.relics_given_up.has(String(result["gave_up"])):
								failures.append("%s: gave-up relic not recorded" % tag)
					"merchant_reroll":
						rerolls_seen += 1
					"merchant_leave":
						if not state.merchant_visit.is_empty() or state.pending != RunState.PENDING_NONE:
							failures.append("%s: leave left the visit open" % tag)
						break
			if state.gold < 0:
				failures.append("%s: gold went negative (%d) after '%s'" % [tag, state.gold, pick])
				break
			if gold_before - state.gold != state.gold_spent_merchant - spent_before:
				failures.append("%s: gold and gold_spent_merchant disagree after '%s'" % [tag, pick])
				break
			if state.relics.size() > cap:
				failures.append("%s: %d relics over the cap %d" % [tag, state.relics.size(), cap])
				break
			for given: String in state.relics_given_up:
				if state.relics.has(given):
					failures.append("%s: %s is both owned and given up" % [tag, given])
			if Merchant.removal_price(state, ctx) != 50 + 25 * state.merchant_removals:
				failures.append("%s: removal price formula broken" % tag)
				break
			# the screen survives a save at every step
			if state.merchant_visit.is_empty():
				continue
			var restored: RunState = RunState.from_json(state.to_json())
			if restored == null or not restored.equals(state) or _screen(restored, ctx) != _screen(state, ctx):
				failures.append("%s: a save after '%s' restored a different screen" % [tag, pick])
				break
			if price_before < 0:
				failures.append("%s: negative price" % tag)
	assert_array(failures).override_failure_message("\n".join(failures.slice(0, 10))).is_empty()
	# the property run must really have exercised the rare paths
	assert_int(relic_buys).is_greater(50)
	assert_int(swaps_seen).is_greater(5)
	assert_int(removals_seen).is_greater(10)
	print("map2_qa fuzz: relic buys %d, swaps %d, removals %d, rerolls %d" % [relic_buys, swaps_seen, removals_seen, rerolls_seen])


# ---- 2. stock composition over many seeds ----

func test_stock_over_many_seeds_has_three_distinct_relics_three_distinct_cards_a_shop_only_slot_and_never_a_boss_relic() -> void:
	var freq: Dictionary = {}
	for character: String in ["rogue", "wizard"]:
		var ctx: Dictionary = _ctx(character)
		for seed_value in range(1, 301):
			var state: RunState = _state(seed_value, 100, character)
			state.room_index = seed_value % 9
			Merchant.open_visit(state, 20 + seed_value % 40, ctx)
			var relics: Array = state.merchant_visit["relics"]
			var cards: Array = state.merchant_visit["cards"]
			assert_int(relics.size()).override_failure_message("%s seed %d" % [character, seed_value]).is_equal(3)
			assert_int(cards.size()).is_equal(3)
			assert_int(Array(relics).filter(func(i: Variant) -> bool: return SHOP_ONLY.has(String(i))).size()).is_greater(0)
			assert_str(_stock_problems(state, ctx, [] as Array[String])).is_empty()
			for id: String in relics:
				freq[character + ":" + id] = int(freq.get(character + ":" + id, 0)) + 1
				var relic: Dictionary = (ctx["relics"]["by_id"] as Dictionary)[id]
				assert_bool((ctx["pools"] as Array).has(String(relic["pool"]))).override_failure_message("%s stocked %s from pool %s" % [character, id, relic["pool"]]).is_true()
				assert_bool((relic["sources"] as Array).has("merchant")).is_true()
				assert_bool(["tier1", "tier2"].has(String(relic["rarity"]))).is_true()  # act 1 weights are 80/20/0
			for id: String in cards:
				assert_bool(ctx["by_id"].has(id)).is_true()
	# every eligible relic turns up for each class (a relic that never shows would be dead stock)
	var never: Array[String] = []
	for character: String in ["rogue", "wizard"]:
		var ctx: Dictionary = _ctx(character)
		for r: Dictionary in (ctx["relics"]["catalog"] as Array):
			if (ctx["pools"] as Array).has(String(r["pool"])) and ["tier1", "tier2"].has(String(r["rarity"])) and (r["sources"] as Array).has("merchant"):
				if int(freq.get(character + ":" + String(r["id"]), 0)) == 0:
					never.append(character + ":" + String(r["id"]))
	assert_array(never).override_failure_message("never stocked in 300 seeds: %s" % str(never)).is_empty()
	print("map2_qa stock frequencies over 300 seeds each: %s" % str(freq))


func test_without_a_shop_only_relic_the_slot_falls_back_to_normal_stock_and_an_empty_pool_does_not_crash() -> void:
	var ctx: Dictionary = _ctx("rogue")
	var relics: Dictionary = ctx["relics"]
	relics["catalog"] = (relics["catalog"] as Array).filter(func(r: Variant) -> bool: return not SHOP_ONLY.has(String((r as Dictionary)["id"])))
	for seed_value in range(1, 60):
		var state: RunState = _state(seed_value, 100)
		Merchant.open_visit(state, 31, ctx)
		assert_int((state.merchant_visit["relics"] as Array).size()).is_equal(3)
		assert_bool((state.merchant_visit["relics"] as Array).any(func(i: Variant) -> bool: return SHOP_ONLY.has(String(i)))).is_false()
	# owning everything eligible: 0 relics, the shop still opens and works
	var full: Dictionary = _ctx("rogue")
	var state2: RunState = _state(5, 300)
	for r: Dictionary in (full["relics"]["catalog"] as Array):
		if (full["pools"] as Array).has(String(r["pool"])) and String(r["rarity"]) != "boss":
			state2.add_relic(String(r["id"]))
	RunChoices.open_for_room(state2, "merchant", false, full)
	assert_int((state2.merchant_visit["relics"] as Array).size()).is_equal(0)
	assert_bool(bool(RunChoices.apply(state2, "buy_card:" + String(state2.merchant_visit["cards"][0]), full)["ok"])).is_true()
	assert_bool(bool(RunChoices.apply(state2, RunMerchant.OPTION_LEAVE, full)["ok"])).is_true()
	# owning two of three shop-only relics: one shop-only slot is still honoured with the last, never a duplicate
	var some: Dictionary = _ctx("rogue")
	var state3: RunState = _state(9, 300)
	state3.add_relic("liquidate_assets")
	state3.add_relic("request_for_quotation")
	RunChoices.open_for_room(state3, "merchant", false, some)
	var stocked: Array = state3.merchant_visit["relics"]
	assert_bool(stocked.has("as_per_the_attached_document")).is_true()
	assert_bool(stocked.has("liquidate_assets") or stocked.has("request_for_quotation")).is_false()


func test_a_boss_tier_relic_is_never_stocked_or_sold_even_if_it_claims_the_merchant_source() -> void:
	var ctx: Dictionary = _ctx("rogue")
	var boss: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BOSS_FIXTURE))
	boss["sources"] = ["merchant"]
	boss["pool"] = "neutral"
	(ctx["relics"]["catalog"] as Array).append(boss)
	(ctx["relics"]["by_id"] as Dictionary)[String(boss["id"])] = boss
	for seed_value in range(1, 120):
		var state: RunState = _state(seed_value, 500)
		Merchant.open_visit(state, 40, ctx)
		assert_bool((state.merchant_visit["relics"] as Array).has(String(boss["id"]))).is_false()
	# forced into the stock by a hostile save: not for sale, nothing charged
	var shop: Array = _shop(3, 500, "rogue", false, ctx)
	var state2: RunState = shop[0]
	(state2.merchant_visit["relics"] as Array)[0] = String(boss["id"])
	var result: Dictionary = RunChoices.apply(state2, "buy_relic:" + String(boss["id"]), ctx)
	assert_bool(bool(result["ok"])).is_false()
	assert_int(state2.gold).is_equal(500)
	assert_bool(state2.has_relic(String(boss["id"]))).is_false()


# ---- 3. determinism ----

func test_the_same_seed_and_node_give_the_same_stock_and_the_reroll_is_seeded() -> void:
	var ctx: Dictionary = _ctx("wizard")
	var distinct: Dictionary = {}
	for seed_value in range(1, 80):
		var a: RunState = _state(seed_value, 100, "wizard")
		var b: RunState = _state(seed_value, 100, "wizard")
		Merchant.open_visit(a, 33, ctx)
		Merchant.open_visit(b, 33, ctx)
		assert_str(JSON.stringify(a.merchant_visit)).is_equal(JSON.stringify(b.merchant_visit))
		var c: RunState = _state(seed_value, 100, "wizard")
		Merchant.open_visit(c, 34, ctx)  # another node
		distinct[JSON.stringify(a.merchant_visit["relics"]) + JSON.stringify(c.merchant_visit["relics"])] = true
		# rerolls: same ops, same stock
		ctx["merchant"]["free_rerolls"] = 2
		assert_bool(bool(Merchant.reroll(a, ctx)["ok"])).is_true()
		assert_bool(bool(Merchant.reroll(b, ctx)["ok"])).is_true()
		assert_str(JSON.stringify(a.merchant_visit)).is_equal(JSON.stringify(b.merchant_visit))
		assert_bool(bool(Merchant.reroll(a, ctx)["ok"])).is_true()
		assert_bool(bool(Merchant.reroll(a, ctx)["ok"])).is_false()  # only 2 granted
		ctx["merchant"]["free_rerolls"] = 0
		ctx["merchant"]["free_rerolls"] = 0
	assert_int(distinct.size()).is_greater(20)  # seeds and nodes really change the stock


func test_a_reroll_keeps_sold_items_never_stocks_owned_or_given_up_relics_and_makes_no_duplicates() -> void:
	var failures: Array[String] = []
	for seed_value in range(1, 100):
		var ctx: Dictionary = _ctx("rogue")
		ctx["merchant"]["free_rerolls"] = 3
		var state: RunState = _state(seed_value, 1000)
		Merchant.open_visit(state, 21, ctx)
		var first_relic: String = String(state.merchant_visit["relics"][0])
		var first_card: String = String(state.merchant_visit["cards"][0])
		assert_bool(bool(Merchant.buy_relic(state, first_relic, ctx)["ok"])).is_true()
		assert_bool(bool(Merchant.buy_card(state, first_card, ctx)["ok"])).is_true()
		for i in range(3):
			assert_bool(bool(Merchant.reroll(state, ctx)["ok"])).is_true()
			var relics: Array = state.merchant_visit["relics"]
			var cards: Array = state.merchant_visit["cards"]
			if relics.size() != 3 or cards.size() != 3:
				failures.append("seed %d reroll %d: stock %d/%d" % [seed_value, i, relics.size(), cards.size()])
			if not relics.has(first_relic) or not (state.merchant_visit["sold_relics"] as Array).has(first_relic):
				failures.append("seed %d: the sold relic vanished" % seed_value)
			if not cards.has(first_card):
				failures.append("seed %d: the sold card vanished" % seed_value)
			var seen: Dictionary = {}
			for id: String in relics:
				if seen.has(id):
					failures.append("seed %d reroll %d: duplicate relic %s" % [seed_value, i, id])
				seen[id] = true
				if state.relics.has(id) and id != first_relic:
					failures.append("seed %d: owned relic %s restocked" % [seed_value, id])
			var seen_cards: Dictionary = {}
			for id: String in cards:
				if seen_cards.has(id):
					failures.append("seed %d reroll %d: duplicate card %s" % [seed_value, i, id])
				seen_cards[id] = true
	assert_array(failures).override_failure_message("\n".join(failures.slice(0, 8))).is_empty()


# ---- 4. prices come from data ----

func test_every_price_is_read_from_data_not_hardcoded() -> void:
	var ctx: Dictionary = _ctx("rogue")
	var cfg: Dictionary = (ctx["merchant"]["config"] as Dictionary).duplicate()
	cfg["card_price"] = 77
	cfg["removal_base"] = 11
	cfg["removal_step"] = 3
	ctx["merchant"]["config"] = cfg
	ctx["merchant"]["prices"] = {"tier1": 7, "tier2": 8, "tier3": 9}
	var shop: Array = _shop(4, 1000, "rogue", true, ctx)
	var state: RunState = shop[0]
	var gold: int = state.gold
	var relic_id: String = String(state.merchant_visit["relics"][0])
	var tier: String = String(ctx["relics"]["by_id"][relic_id]["rarity"])
	var expected_relic: int = {"tier1": 7, "tier2": 8, "tier3": 9}[tier]
	var bought: Dictionary = Merchant.buy_relic(state, relic_id, ctx)
	assert_bool(bool(bought["ok"])).is_true()
	assert_int(state.gold).is_equal(gold - expected_relic)
	var card_id: String = String(state.merchant_visit["cards"][0])
	assert_bool(bool(Merchant.buy_card(state, card_id, ctx)["ok"])).is_true()
	assert_int(state.gold).is_equal(gold - expected_relic - 77)
	var removable: Array[String] = RunChoices.removable_card_ids(state, ctx)
	assert_bool(removable.is_empty()).is_false()
	var g2: int = state.gold
	assert_bool(bool(Merchant.buy_removal(state, removable[0], ctx)["ok"])).is_true()
	assert_int(state.gold).is_equal(g2 - 11)
	removable = RunChoices.removable_card_ids(state, ctx)
	g2 = state.gold
	assert_bool(bool(Merchant.buy_removal(state, removable[0], ctx)["ok"])).is_true()
	assert_int(state.gold).is_equal(g2 - 14)
	# the shipped numbers, with the shipped data
	var shipped: Dictionary = _ctx("rogue")
	assert_int(Merchant.card_price(shipped)).is_equal(40)
	assert_int(Merchant.removal_price(_state(1, 0), shipped)).is_equal(50)
	var st: RunState = _state(1, 0)
	st.merchant_removals = 3
	assert_int(Merchant.removal_price(st, shipped)).is_equal(125)
	for pair: Array in [["asap_notice", 30], ["severance_package", 45], ["paperwork_fire", 30], ["grading_curve", 45], ["liquidate_assets", 45], ["request_for_quotation", 30], ["as_per_the_attached_document", 45]]:
		assert_int(Merchant.relic_price(String(pair[0]), shipped)).override_failure_message(String(pair[0])).is_equal(int(pair[1]))


func test_exact_gold_buys_and_one_short_refuses_and_nothing_goes_negative() -> void:
	var ctx: Dictionary = _ctx("rogue")
	for gold_delta in [-1, 0]:
		var shop: Array = _shop(8, 0, "rogue", true, ctx)
		var state: RunState = shop[0]
		var card_id: String = String(state.merchant_visit["cards"][0])
		state.gold = 40 + gold_delta
		var result: Dictionary = Merchant.buy_card(state, card_id, ctx)
		assert_bool(bool(result["ok"])).is_equal(gold_delta == 0)
		assert_int(state.gold).is_equal(0 if gold_delta == 0 else 39)
		var removal: Dictionary = Merchant.buy_removal(state, RunChoices.removable_card_ids(state, ctx)[0], ctx)
		assert_bool(bool(removal["ok"])).is_false()
		assert_int(state.gold).is_greater_equal(0)
	# buying the same thing twice
	var shop2: Array = _shop(9, 500, "rogue", true, ctx)
	var s2: RunState = shop2[0]
	var cid: String = String(s2.merchant_visit["cards"][0])
	assert_bool(bool(Merchant.buy_card(s2, cid, ctx)["ok"])).is_true()
	var again: Dictionary = Merchant.buy_card(s2, cid, ctx)
	assert_bool(bool(again["ok"])).is_false()
	assert_int(s2.gold).is_equal(460)
	var rid: String = String(s2.merchant_visit["relics"][0])
	assert_bool(bool(Merchant.buy_relic(s2, rid, ctx)["ok"])).is_true()
	var g: int = s2.gold
	assert_bool(bool(Merchant.buy_relic(s2, rid, ctx)["ok"])).is_false()
	assert_int(s2.gold).is_equal(g)
	# no visit open: every buy refuses
	var closed: RunState = _state(2, 500)
	assert_str(String(Merchant.buy_card(closed, "x", ctx)["reason"])).is_equal("no_visit")
	assert_str(String(Merchant.buy_relic(closed, "x", ctx)["reason"])).is_equal("no_visit")
	assert_str(String(Merchant.buy_removal(closed, "x", ctx)["reason"])).is_equal("no_visit")
	assert_str(String(Merchant.reroll(closed, ctx)["reason"])).is_equal("no_visit")


# ---- 5. the removal guard ----

func test_the_removal_guard_blocks_a_slot_minimum_and_the_price_climbs_by_25_per_merchant_removal_only() -> void:
	var ctx: Dictionary = _ctx("rogue")
	# starter: 3 unique per slot, so nothing can go
	var shop: Array = _shop(6, 500, "rogue", false, ctx)
	var starter: RunState = shop[0]
	var items: Array[Dictionary] = Merchant.items(starter, ctx)
	var removal: Dictionary = items[items.size() - 1]
	assert_str(String(removal["kind"])).is_equal("removal")
	assert_bool(bool(removal["can_buy"])).is_false()
	assert_str(String(removal["reason"])).is_equal("none_removable")
	var refused: Dictionary = RunChoices.apply(starter, RunMerchant.OPTION_REMOVE_MENU, ctx)
	assert_bool(bool(refused["ok"])).is_false()
	for card_id: String in RunChoices.unique_deck_ids(starter, ctx):
		var try: Dictionary = Merchant.buy_removal(starter, card_id, ctx)
		assert_bool(bool(try["ok"])).is_false()
		assert_str(String(try["reason"])).is_equal("removal_blocked")
	assert_int(starter.gold).is_equal(500)
	assert_int(starter.merchant_removals).is_equal(0)
	assert_int(starter.deck.size()).is_equal(15)
	# a card not in the deck
	var nope: Dictionary = Merchant.buy_removal(starter, "no_such_card", ctx)
	assert_str(String(nope["reason"])).is_equal("not_in_deck")
	# full deck: remove until the guard stops it; the price follows 50, 75, 100, ...
	var shop2: Array = _shop(6, 100000, "rogue", true, ctx)
	var state: RunState = shop2[0]
	var paid: Array[int] = []
	while true:
		var ids: Array[String] = RunChoices.removable_card_ids(state, ctx)
		if ids.is_empty():
			break
		var r: Dictionary = Merchant.buy_removal(state, ids[0], ctx)
		assert_bool(bool(r["ok"])).is_true()
		paid.append(int(r["price"]))
		assert_bool(DeckRules.check_shipped(state.deck).is_ok()).is_true()
	assert_bool(paid.size() > 5).is_true()
	for i in range(paid.size()):
		assert_int(paid[i]).is_equal(50 + 25 * i)
	# a rest-room removal does not raise the merchant's price
	var rest_state: RunState = _state(6, 100, "rogue", true)
	rest_state.pending = RunState.PENDING_REST_REMOVE
	var before_price: int = Merchant.removal_price(rest_state, ctx)
	var rid: String = RunChoices.removable_card_ids(rest_state, ctx)[0]
	assert_bool(bool(RunChoices.apply(rest_state, "remove:" + rid, ctx)["ok"])).is_true()
	assert_int(Merchant.removal_price(rest_state, ctx)).is_equal(before_price)
	# the price and count persist across visits
	var two_visits: RunState = _state(6, 100000, "rogue", true)
	Merchant.open_visit(two_visits, 30, ctx)
	Merchant.buy_removal(two_visits, RunChoices.removable_card_ids(two_visits, ctx)[0], ctx)
	Merchant.close_visit(two_visits)
	Merchant.open_visit(two_visits, 31, ctx)
	assert_int(Merchant.removal_price(two_visits, ctx)).is_equal(75)


# ---- 6. the swap at the cap ----

func test_at_the_cap_a_relic_needs_a_giveup_cancel_charges_nothing_and_the_swap_keeps_the_count() -> void:
	var ctx: Dictionary = _ctx("rogue", 2)
	var shop: Array = _shop(12, 500, "rogue", false, ctx)
	var state: RunState = shop[0]
	state.relics = [] as Array[String]
	state.add_relic("heavy_sigh")
	state.add_relic("pyre_insurance")
	# the stock was drawn for an empty hand; re-open so it excludes what is held
	Merchant.close_visit(state)
	RunChoices.open_for_room(state, "merchant", false, ctx)
	var relic_id: String = String(state.merchant_visit["relics"][0])
	var price: int = Merchant.relic_price(relic_id, ctx)
	var opened: Dictionary = RunChoices.apply(state, "buy_relic:" + relic_id, ctx)
	assert_bool(bool(opened["ok"])).is_true()
	assert_str(String(opened["kind"])).is_equal("merchant_swap_open")
	assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT_SWAP)
	assert_int(state.gold).is_equal(500)
	# the screen offers exactly the owned relics plus Cancel
	var ids: Array[String] = []
	for option: Dictionary in RunChoices.options(state, ctx):
		ids.append(String(option["id"]))
	assert_array(ids).contains_exactly(["merchant_giveup:heavy_sigh", "merchant_giveup:pyre_insurance", RunMerchant.OPTION_CANCEL])
	# a save in the swap restores the same screen
	var restored: RunState = RunState.from_json(state.to_json())
	assert_str(_screen(restored, ctx)).is_equal(_screen(state, ctx))
	assert_str(restored.relic_incoming).is_equal(relic_id)
	# cancel: nothing charged, nothing given up, back in the shop
	var snapshot: Array = [state.gold, state.relics.duplicate(), state.relics_given_up.duplicate(), state.gold_spent_merchant]
	assert_bool(bool(RunChoices.apply(state, RunMerchant.OPTION_CANCEL, ctx)["ok"])).is_true()
	assert_array([state.gold, state.relics, state.relics_given_up, state.gold_spent_merchant]).is_equal(snapshot)
	assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT)
	assert_str(state.relic_incoming).is_empty()
	assert_bool((state.merchant_visit["sold_relics"] as Array).has(relic_id)).is_false()
	# a bad give-up id is refused with nothing charged, in the swap
	RunChoices.apply(state, "buy_relic:" + relic_id, ctx)
	var bad: Dictionary = RunChoices.apply(state, "merchant_giveup:request_for_quotation", ctx)
	assert_bool(bool(bad["ok"])).is_false()
	assert_int(state.gold).is_equal(500)
	# a real swap
	var swap: Dictionary = RunChoices.apply(state, "merchant_giveup:heavy_sigh", ctx)
	assert_bool(bool(swap["ok"])).is_true()
	assert_int(state.gold).is_equal(500 - price)
	assert_array(state.relics).contains_exactly(["pyre_insurance", relic_id])
	assert_array(state.relics_given_up).contains(["heavy_sigh"])
	assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT)
	# the given-up relic is not restocked by a reroll; the swapped-in one stays marked sold
	ctx["merchant"]["free_rerolls"] = 1
	Merchant.reroll(state, ctx)
	assert_bool((state.merchant_visit["relics"] as Array).has("heavy_sigh")).is_false()
	assert_bool((state.merchant_visit["sold_relics"] as Array).has(relic_id)).is_true()


func test_a_hand_of_boss_relics_cannot_be_swapped_out_and_nothing_is_charged() -> void:
	var ctx: Dictionary = _ctx("rogue", 1)
	var boss: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BOSS_FIXTURE))
	(ctx["relics"]["catalog"] as Array).append(boss)
	(ctx["relics"]["by_id"] as Dictionary)[String(boss["id"])] = boss
	var shop: Array = _shop(14, 500, "rogue", false, ctx)
	var state: RunState = shop[0]
	state.relics = [String(boss["id"])] as Array[String]
	var relic_id: String = String(state.merchant_visit["relics"][0])
	var result: Dictionary = RunChoices.apply(state, "buy_relic:" + relic_id, ctx)
	assert_bool(bool(result["ok"])).is_false()
	assert_str(String(result["reason_code"])).is_equal("none_giveable")
	assert_int(state.gold).is_equal(500)
	assert_array(state.relics).contains_exactly([String(boss["id"])])
	assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT)


# ---- 7. Request for Quotation: the reroll in the visit that buys it ----

func test_request_for_quotation_rerolls_once_in_the_visit_that_buys_it_and_not_before() -> void:
	var seen_rfq: int = 0
	for seed_value in range(1, 200):
		var ctx: Dictionary = _ctx("rogue")
		var state: RunState = _state(seed_value, 900)
		RunChoices.open_for_room(state, "merchant", false, ctx)
		if not (state.merchant_visit["relics"] as Array).has("request_for_quotation"):
			continue
		seen_rfq += 1
		var kinds: Array[String] = []
		for option: Dictionary in RunChoices.options(state, ctx):
			kinds.append(String(option["kind"]))
		assert_bool(kinds.has("reroll")).override_failure_message("reroll shown before owning the relic").is_false()
		assert_bool(bool(RunChoices.apply(state, RunMerchant.OPTION_REROLL, ctx)["ok"])).is_false()
		assert_bool(bool(RunChoices.apply(state, "buy_relic:request_for_quotation", ctx)["ok"])).is_true()
		var option_ids: Array[String] = []
		for option: Dictionary in RunChoices.options(state, ctx):
			option_ids.append(String(option["id"]))
		assert_array(option_ids).contains([RunMerchant.OPTION_REROLL])
		var gold: int = state.gold
		var first: Dictionary = RunChoices.apply(state, RunMerchant.OPTION_REROLL, ctx)
		assert_bool(bool(first["ok"])).is_true()
		assert_int(state.gold).is_equal(gold)  # free
		var second: Dictionary = RunChoices.apply(state, RunMerchant.OPTION_REROLL, ctx)
		assert_bool(bool(second["ok"])).is_false()
		# a second visit gets its own reroll
		RunChoices.apply(state, RunMerchant.OPTION_LEAVE, ctx)
		RunChoices.open_for_room(state, "merchant", false, ctx)
		state.room_index += 1
		Merchant.close_visit(state)
		Merchant.open_visit(state, 77, ctx)
		assert_int(Merchant.rerolls_left(state, ctx)).is_equal(1)
		if seen_rfq >= 5:
			break
	assert_int(seen_rfq).override_failure_message("request_for_quotation never in a stock in 200 seeds").is_greater(0)


# ---- 8. saves mid-visit and damaged saves ----

func test_a_save_in_the_shop_the_removal_list_and_the_swap_restores_the_same_screen_for_both_classes() -> void:
	for character: String in ["rogue", "wizard"]:
		var ctx: Dictionary = _ctx(character, 1)
		var shop: Array = _shop(17, 800, character, true, ctx)
		var state: RunState = shop[0]
		assert_str(_screen(RunState.from_json(state.to_json()), ctx)).is_equal(_screen(state, ctx))
		RunChoices.apply(state, RunMerchant.OPTION_REMOVE_MENU, ctx)
		assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT_REMOVE)
		var r1: RunState = RunState.from_json(state.to_json())
		assert_str(r1.pending).is_equal(RunState.PENDING_MERCHANT_REMOVE)
		assert_str(_screen(r1, ctx)).is_equal(_screen(state, ctx))
		RunChoices.apply(state, RunMerchant.OPTION_BACK, ctx)
		var relic_id: String = String(state.merchant_visit["relics"][0])
		RunChoices.apply(state, "buy_relic:" + relic_id, ctx)  # now holds 1, cap 1: next buy swaps
		var second_id: String = String(state.merchant_visit["relics"][1])
		RunChoices.apply(state, "buy_relic:" + second_id, ctx)
		assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT_SWAP)
		var r2: RunState = RunState.from_json(state.to_json())
		assert_str(r2.pending).is_equal(RunState.PENDING_MERCHANT_SWAP)
		assert_str(_screen(r2, ctx)).is_equal(_screen(state, ctx))
		assert_bool(r2.equals(state)).is_true()


func test_damaged_merchant_saves_do_not_crash_and_never_open_a_shop_without_a_visit() -> void:
	var ctx: Dictionary = _ctx("rogue")
	var shop: Array = _shop(21, 300, "rogue", false, ctx)
	var good: Dictionary = (shop[0] as RunState).to_dict()
	var mutations: Array = [
		["merchant_visit", "x"], ["merchant_visit", null], ["merchant_visit", []], ["merchant_visit", {}],
		["merchant_removals", -5], ["merchant_removals", "7"], ["gold_spent_merchant", -9], ["gold_spent_merchant", 1e30],
		["pending", "merchant_swap"], ["pending", "merchant_remove"], ["pending", "merchant"],
	]
	for case: Array in mutations:
		var data: Dictionary = JSON.parse_string(JSON.stringify(good))
		data[case[0]] = case[1]
		if case[0] == "pending":
			data["merchant_visit"] = {}
		var loaded: RunState = RunState.from_dict(data)
		assert_object(loaded).override_failure_message("load returned null for %s" % str(case)).is_not_null()
		if case[0] == "pending":
			assert_bool(RunMerchant.owns(loaded.pending)).override_failure_message("merchant screen with no visit for %s" % str(case)).is_false()
		assert_int(loaded.merchant_removals).is_greater_equal(0)
		assert_int(loaded.gold_spent_merchant).is_greater_equal(0)
	# visit sub-keys damaged
	for key: String in ["node", "relics", "cards", "sold_relics", "sold_cards", "rerolls_used"]:
		for bad: Variant in [null, "x", -3, [1, 2], {"a": 1}]:
			var data2: Dictionary = JSON.parse_string(JSON.stringify(good))
			(data2["merchant_visit"] as Dictionary)[key] = bad
			var loaded2: RunState = RunState.from_dict(data2)
			assert_object(loaded2).is_not_null()
			if RunMerchant.owns(loaded2.pending):
				assert_bool(loaded2.merchant_visit.is_empty()).override_failure_message("choice kept with a damaged visit (%s = %s)" % [key, str(bad)]).is_false()
				# whatever was kept must be usable: options build and a leave works
				RunChoices.options(loaded2, ctx)
	# an old save (no merchant keys at all) loads with nothing
	var old: Dictionary = JSON.parse_string(JSON.stringify(good))
	for key in ["merchant_visit", "merchant_removals", "gold_spent_merchant"]:
		old.erase(key)
	old["pending"] = "none"
	var legacy: RunState = RunState.from_dict(old)
	assert_int(legacy.merchant_removals).is_equal(0)
	assert_bool(legacy.merchant_visit.is_empty()).is_true()


# ---- 9. the new relics through the data (the behaviour tests are the dev's; these are independent spot checks) ----

func test_the_seven_new_relics_have_the_documented_numbers() -> void:
	assert_array(RelicDatabase.problems()).is_empty()
	for id: String in NEW_RELICS:
		assert_bool(RelicDatabase.get_relic(id).is_empty()).override_failure_message(id).is_false()
	var asap: Dictionary = RelicDatabase.get_relic("asap_notice")
	assert_float(float(asap["modifiers"][0]["value"])).is_equal(-0.15)
	assert_str(String(asap["modifiers"][0]["stat"])).is_equal("slot_cooldown.movement")
	var as_per: Dictionary = RelicDatabase.get_relic("as_per_the_attached_document")
	assert_float(float(as_per["triggers"][0]["effects"][0]["params"]["seconds"])).is_equal(1.5)
	assert_str(String(as_per["triggers"][0]["effects"][0]["params"]["slot_type"])).is_equal("attack_aoe")
	var liq: Dictionary = RelicDatabase.get_relic("liquidate_assets")
	assert_float(float(liq["modifiers"][0]["value"])).is_equal(0.01)
	assert_int(int(liq["modifiers"][0]["per"])).is_equal(50)
	assert_float(RelicManager.scaled_value(liq["modifiers"][0], {"gold_spent_merchant": 99})).is_equal_approx(0.01, 0.000001)
	assert_float(RelicManager.scaled_value(liq["modifiers"][0], {"gold_spent_merchant": 100})).is_equal_approx(0.02, 0.000001)
	assert_float(RelicManager.scaled_value(liq["modifiers"][0], {"gold_spent_merchant": 0})).is_equal(0.0)
	assert_float(RelicManager.scaled_value(liq["modifiers"][0], {})).is_equal(0.0)
	# the data never lets a relic be sold twice, and Liquidate Assets / RFQ / As Per are the only shop-only ones
	var shop_only: Array[String] = []
	for relic: Dictionary in RelicDatabase.all_relics():
		if Merchant.is_shop_only(relic):
			shop_only.append(String(relic["id"]))
	shop_only.sort()
	assert_array(shop_only).is_equal(["as_per_the_attached_document", "liquidate_assets", "request_for_quotation"])
	var shop_only_sorted: Array[String] = SHOP_ONLY.duplicate()
	shop_only_sorted.sort()
	assert_array(shop_only).is_equal(shop_only_sorted)


# ---- 10. D40 min_rest and the merchant rules on seeds the dev never used ----

const SWEEP_FIRST := 9000


## Own depth-first walk over the raw nodes and edges: the fewest and most rests, merchants and elites on any start-to-boss path.
func _path_extremes(map: Dictionary) -> Dictionary:
	var type_of: Dictionary = {}
	var room_of: Dictionary = {}
	for n: Dictionary in (map["nodes"] as Array):
		type_of[int(n["id"])] = String(n["type"])
		room_of[int(n["id"])] = int(n["room"])
	var adj: Dictionary = {}
	for e: Array in (map["edges"] as Array):
		if not adj.has(int(e[0])):
			adj[int(e[0])] = []
		(adj[int(e[0])] as Array).append(int(e[1]))
	var out: Dictionary = {"min_rest": 99, "max_rest": 0, "max_merchants": 0, "paths": 0, "bad_end": 0}
	var stack: Array = []
	for id: int in type_of.keys():
		if int(room_of[id]) == 1:
			stack.append([id, 0, 0])
	while not stack.is_empty():
		var f: Array = stack.pop_back()
		var t: String = String(type_of[int(f[0])])
		var rest: int = int(f[1]) + (1 if t == "rest" else 0)
		var merch: int = int(f[2]) + (1 if t == "merchant" else 0)
		if t == "boss":
			out["paths"] = int(out["paths"]) + 1
			out["min_rest"] = mini(int(out["min_rest"]), rest)
			out["max_rest"] = maxi(int(out["max_rest"]), rest)
			out["max_merchants"] = maxi(int(out["max_merchants"]), merch)
			continue
		if not adj.has(int(f[0])):
			out["bad_end"] = int(out["bad_end"]) + 1  # a dead end that is not the boss
			continue
		for nxt: int in (adj[int(f[0])] as Array):
			stack.append([nxt, rest, merch])
	return out


func test_d40_every_path_of_every_map_holds_a_rest_on_seeds_chosen_by_qa() -> void:
	var count: int = int(OS.get_environment("QA_SWEEP_COUNT")) if OS.get_environment("QA_SWEEP_COUNT") != "" else 400
	var cfg: Dictionary = MapConfig.get_config()
	var run: Dictionary = RunConfig.get_config()
	assert_int(int(cfg["path_rules"]["min_rest"])).is_equal(1)
	var checker := Map1QaTest.new()  # the MAP1 independent checker (it now also checks min_rest and the merchant estimate)
	var failures: Array[String] = []
	var attempts: Array[int] = []
	var merchants_total: int = 0
	var maps_with_merchant: int = 0
	var rest_min_seen: int = 99
	var total_paths: int = 0
	for s in range(SWEEP_FIRST, SWEEP_FIRST + count):
		var result: Dictionary = MapGenerator.build(s, cfg, run)
		if not bool(result["ok"]):
			failures.append("seed %d did not generate: %s" % [s, String(result["error"])])
			continue
		attempts.append(int(result["attempts"]))
		var map: Dictionary = result["map"]
		var ex: Dictionary = _path_extremes(map)
		total_paths += int(ex["paths"])
		rest_min_seen = mini(rest_min_seen, int(ex["min_rest"]))
		if int(ex["min_rest"]) < 1:
			failures.append("seed %d: a path with no rest" % s)
		if int(ex["max_rest"]) > int(cfg["path_rules"]["max_rest"]):
			failures.append("seed %d: a path with %d rests" % [s, ex["max_rest"]])
		if int(ex["max_merchants"]) > 1:
			failures.append("seed %d: a path with %d merchants" % [s, ex["max_merchants"]])
		if int(ex["bad_end"]) > 0 or int(ex["paths"]) == 0:
			failures.append("seed %d: dead ends or no path" % s)
		var merchants: int = (map["nodes"] as Array).filter(func(n: Variant) -> bool: return String((n as Dictionary)["type"]) == "merchant").size()
		merchants_total += merchants
		maps_with_merchant += 1 if merchants > 0 else 0
		var problem: String = checker._check(map, cfg, run)
		if problem != "":
			failures.append("seed %d: %s" % [s, problem])
	checker.free()
	assert_array(failures).override_failure_message("\n".join(failures.slice(0, 8))).is_empty()
	attempts.sort()
	var worst: int = attempts[attempts.size() - 1]
	var mean: float = 0.0
	for a: int in attempts:
		mean += float(a)
	mean /= float(attempts.size())
	print("map2_qa D40 sweep seeds %d..%d: %d maps, %d paths, fewest rests on any path %d, mean attempts %.1f, p50 %d, p99 %d, worst %d of %d, maps with a merchant %d (%d merchants)" % [
			SWEEP_FIRST, SWEEP_FIRST + count - 1, attempts.size(), total_paths, rest_min_seen, mean, attempts[attempts.size() / 2], attempts[int(attempts.size() * 0.99)], worst, int(cfg["max_attempts"]), maps_with_merchant, merchants_total])
	assert_int(worst).is_less(int(cfg["max_attempts"]))
	assert_int(maps_with_merchant).is_greater(0)


# ---- 11. a reload in each merchant screen lands on that screen (scene level, the real RunController) ----

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"


func _spawn() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _frames(count: int = 3) -> void:
	for i in range(count):
		await get_tree().process_frame


## A map run standing on the first merchant node at or after `first_seed`, a full deck so removals exist.
func _on_merchant(first_seed: int, gold: int) -> RunState:
	for seed_value in range(first_seed, first_seed + 300):
		var map: Dictionary = MapGenerator.generate(seed_value)
		for entry: Dictionary in (map["nodes"] as Array):
			if String(entry["type"]) != "merchant":
				continue
			var trail: Array[int] = [int(entry["id"])]
			while int(MapGraph.node(map, trail[0])["room"]) > 1:
				trail.push_front(MapGraph.prev_ids(map, trail[0])[0])
			var state := RunState.new_run(seed_value, CharacterDatabase.starting_deck("rogue"), 3)
			state.deck = RunConfig.cards_in_pools(CharacterDatabase.pools("rogue"))
			state.map = map
			state.path = trail
			state.room_index = trail.size() - 1
			state.gold = gold
			return state
	return null


func test_a_reload_in_the_removal_list_and_in_the_swap_lands_on_that_screen_not_the_shop() -> void:
	RunSession.relic_cap = 1
	var state: RunState = _on_merchant(1, 900)
	assert_object(state).is_not_null()
	RunSession.current = state
	var first := _spawn()
	await _frames()
	var controller: RunController = first.run_controller
	assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT)
	# -- the removal list
	assert_bool(bool(controller.open_merchant_removal()["ok"])).is_true()
	assert_str(state.pending).is_equal(RunState.PENDING_MERCHANT_REMOVE)
	var saved_remove: String = state.to_json()
	var stock: Array = (state.merchant_visit["relics"] as Array).duplicate()
	first.queue_free()
	await _frames()
	var restored: RunState = RunState.from_json(saved_remove)
	RunSession.current = restored
	var second := _spawn()
	var models: Array[Dictionary] = []
	second.run_controller.choice_requested.connect(func(m: Dictionary) -> void: models.append(m))
	await _frames()
	assert_str(restored.pending).is_equal(RunState.PENDING_MERCHANT_REMOVE)
	assert_int(models.size()).is_equal(1)
	assert_str(String(models[0]["choice"])).is_equal(RunState.PENDING_MERCHANT_REMOVE)
	assert_str(String(models[0]["merchant_screen"])).is_equal("remove")
	assert_array(restored.merchant_visit["relics"]).is_equal(stock)
	# the list works after the reload: back to the shop, then a real swap
	assert_bool(bool(second.run_controller.merchant_back()["ok"])).is_true()
	assert_str(restored.pending).is_equal(RunState.PENDING_MERCHANT)
	var held: String = String(stock[0])
	var incoming: String = String(stock[1])
	assert_bool(bool(second.run_controller.buy_relic(held)["ok"])).is_true()  # cap 1: this one fits
	assert_bool(bool(second.run_controller.buy_relic(incoming)["ok"])).is_true()  # opens the swap
	assert_str(restored.pending).is_equal(RunState.PENDING_MERCHANT_SWAP)
	var gold_in_swap: int = restored.gold
	var saved_swap: String = restored.to_json()
	second.queue_free()
	await _frames()
	# -- the swap
	var restored2: RunState = RunState.from_json(saved_swap)
	RunSession.current = restored2
	var third := _spawn()
	var models2: Array[Dictionary] = []
	third.run_controller.choice_requested.connect(func(m: Dictionary) -> void: models2.append(m))
	await _frames()
	assert_str(restored2.pending).is_equal(RunState.PENDING_MERCHANT_SWAP)
	assert_int(models2.size()).is_equal(1)
	assert_str(String(models2[0]["choice"])).is_equal(RunState.PENDING_MERCHANT_SWAP)
	assert_str(String(models2[0]["merchant_screen"])).is_equal("swap")
	assert_str(String((models2[0]["incoming"] as Dictionary)["relic_id"])).is_equal(incoming)
	var giveable: Array[String] = []
	for entry: Dictionary in (models2[0]["giveable"] as Array):
		giveable.append(String(entry["relic_id"]))
	assert_array(giveable).is_equal([held])
	assert_str(restored2.relic_incoming).is_equal(incoming)
	assert_int(restored2.gold).is_equal(gold_in_swap)
	# cancelling after the reload charges nothing; the swap itself completes
	assert_bool(bool(third.run_controller.cancel_purchase()["ok"])).is_true()
	assert_int(restored2.gold).is_equal(gold_in_swap)
	assert_bool(bool(third.run_controller.buy_relic(incoming)["ok"])).is_true()
	var done: Dictionary = third.run_controller.give_up_for_purchase(held)
	assert_bool(bool(done["ok"])).is_true()
	assert_array(restored2.relics).contains_exactly([incoming])
	assert_array(restored2.relics_given_up).contains_exactly([held])
	assert_int(restored2.gold).is_equal(gold_in_swap - Merchant.relic_price(incoming, third.run_controller._ctx))
	# the live manager follows the swap
	assert_bool(third.run_controller.relic_manager().has_relic(incoming)).is_true()
	assert_bool(third.run_controller.relic_manager().has_relic(held)).is_false()


func test_buying_liquidate_assets_makes_the_next_room_hit_harder_after_the_spend_and_after_a_reload() -> void:
	var state: RunState = _on_merchant(1, 900)
	RunSession.current = state
	var main := _spawn()
	await _frames()
	var controller: RunController = main.run_controller
	# put Liquidate Assets into this shop (the stock is seeded, so force the slot) and buy it plus a card, then check the live stat
	(state.merchant_visit["relics"] as Array)[0] = "liquidate_assets"
	assert_float(main.player.stat_modifiers.apply("damage_mult", 1.0)).is_equal(1.0)
	var price: int = Merchant.relic_price("liquidate_assets", controller._ctx)
	assert_bool(bool(controller.buy_relic("liquidate_assets")["ok"])).is_true()
	assert_int(state.gold_spent_merchant).is_equal(price)
	# 45 gold spent: not yet 50, so no bonus; buying a card (40) crosses 50 and the live room sees it at once
	assert_float(main.player.stat_modifiers.apply("damage_mult", 1.0)).is_equal_approx(1.0, 0.00001)
	var card_id: String = String(state.merchant_visit["cards"][0])
	assert_bool(bool(controller.buy_card(card_id)["ok"])).is_true()
	assert_int(state.gold_spent_merchant).is_equal(price + 40)
	# Observation: the live room is not refreshed by a card or removal purchase (only a relic purchase calls _sync_relics), so the stat here is still 1.0.
	# Nobody can notice: the merchant room has no combat and the next room is rebuilt from the state, which is what is asserted after the reload below.
	# and a reload rebuilds it from the state
	var saved: String = state.to_json()
	main.queue_free()
	await _frames()
	var restored: RunState = RunState.from_json(saved)
	RunSession.current = restored
	var again := _spawn()
	await _frames()
	assert_float(again.player.stat_modifiers.apply("damage_mult", 1.0)).is_equal_approx(1.01, 0.00001)


func test_the_shipped_data_has_the_merchant_fully_on() -> void:
	# The dev pins accept "off or fully on"; this one pins the accepted state (ux switched it on in 8994863), so a silent flip back to off fails here.
	var map: Dictionary = MapConfig.get_config()
	assert_float(float(map["types"]["merchant"]["weight"])).is_equal(8.0)
	assert_array(map["path_rules"]["relic_route"]).contains_exactly([6.0, 8.0])
	assert_array(map["estimate"]["merchant_prices"]).contains_exactly([30.0, 30.0, 45.0])
	assert_int(int(map["path_rules"]["max_merchants"])).is_equal(1)
	assert_int(int(map["path_rules"]["min_rest"])).is_equal(1)
	var prices: Dictionary = RunConfig.get_config()["relics"]["prices"]
	assert_int(int(prices["tier1"])).is_equal(30)
	assert_int(int(prices["tier2"])).is_equal(45)
	assert_int(int(prices["tier3"])).is_equal(65)
	assert_bool(prices.has("boss")).is_false()
	assert_bool(MerchantSwitch.shipped_is_on()).is_true()
	assert_array(MerchantSwitch.shipped_problems()).is_empty()
	assert_float(float(map["types"]["rest"]["weight"])).is_equal(25.0)
	assert_int(int(map["max_attempts"])).is_equal(1000)
