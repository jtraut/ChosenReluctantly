class_name Merchant
extends RefCounted
## The merchant's model (MAP2-A, MAP.md section 4.4), with no UI and no scene. Pure and static over a RunState and the RunChoices context
## (its "merchant" entry, see MerchantConfig.shipped_context), so everything here is testable with fixtures.
##
## A visit (`RunState.merchant_visit`) holds the stock the player sees: relic ids, card ids and which of them are sold. It is created by
## `open_visit` from the run seed and the node id, so the same seed and node always give the same stock, and it lives in the RunState, so
## restoring a save mid-visit gives the same stock back. `close_visit` clears it when the player leaves.
##
## Stock (the numbers are data/run.json `merchant`):
##   - relics: `relic_stock` of them. `shop_only_slots` of the slots hold only shop-only relics (`sources` exactly ["merchant"]), drawn first
##     through RelicOffer; when fewer are eligible those slots fall back to normal merchant stock. The other slots are RelicOffer.offer("merchant").
##     Shop-only relics may also turn up in a normal slot (a normal slot is plain "source merchant"). Boss-tier relics are never sold.
##   - no owned or given-up relic, no duplicate within the stock.
##   - cards: `card_stock`, drawn by the reward weights (RewardOffer) from the character's pools.
##   - card removal: always available; price removal_base + removal_step x removals bought at the merchant this run (rest-room removals
##     do not raise it).
## Buying: gold never goes below 0, any number of purchases in any order. A relic bought at the relic cap returns `needs_giveup` (nothing
## charged) with the giveable relics, and the caller (the run flow, reusing BD2's give-one-up step) calls again with `give_up_id`.
## Reroll hook: `rerolls_left` = ctx["merchant"]["free_rerolls"] (a relic's `merchant.free_rerolls` modifier in MAP2-B) minus the rerolls used
## this visit; `reroll` redraws the unsold relic and card slots, seeded from the run seed, node id and reroll number.
##
## Result dict of every buy / reroll: {ok, kind, id, price, reason, needs_giveup, giveable, gave_up}. `reason` is a code the UI words:
## "no_visit", "not_in_stock", "sold", "unknown_relic", "not_for_sale", "too_expensive", "needs_giveup", "none_giveable", "bad_giveup",
## "not_in_deck", "removal_blocked", "no_rerolls". `items` adds "none_removable" (the removal entry when no card of the deck may be removed).

const KIND_RELIC := "relic"
const KIND_CARD := "card"
const KIND_REMOVAL := "removal"
const SEED_MIX := 15485863
const NODE_MIX := 32452843
const ROLL_MIX := 49979687
const SEED_SALT := 0x5EC7
## Card stock reuses RewardOffer's seeded draw; its "room index" input is this base plus a per-node, per-reroll offset, far from real room indexes.
const CARD_STREAM_BASE := 100000
## Merchant node ids repeat in every act; acts are this far apart in the stock streams (act 1 is unchanged).
const ACT_NODE_STEP := 1000


# --- visit lifecycle -------------------------------------------------------------------------------

static func has_visit(state: RunState) -> bool:
	return not state.merchant_visit.is_empty()


## Opens the visit at map node `node_id`: keeps the stock of an open visit at the same node (a reload), else draws a fresh one.
static func open_visit(state: RunState, node_id: int, ctx: Dictionary) -> Dictionary:
	if has_visit(state) and int(state.merchant_visit["node"]) == node_id:
		return state.merchant_visit
	var stock: Dictionary = draw_stock(state, node_id, 0, ctx, [] as Array[String], [] as Array[String])
	state.merchant_visit = {
		"node": node_id,
		"relics": stock["relics"],
		"cards": stock["cards"],
		"sold_relics": [] as Array[String],
		"sold_cards": [] as Array[String],
		"rerolls_used": 0,
	}
	return state.merchant_visit


static func close_visit(state: RunState) -> void:
	state.merchant_visit = {}


# --- stock -----------------------------------------------------------------------------------------

## The stream of one draw: the run seed, the node and the reroll number (0 = the first stock).
static func stock_rng(run_seed: int, node_id: int, reroll_index: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = (run_seed * SEED_MIX + node_id * NODE_MIX + reroll_index * ROLL_MIX + SEED_SALT) & RunState.SEED_LIMIT
	return rng


## Draws a stock: {relics: Array[String], cards: Array[String]}. `kept_relics` / `kept_cards` are ids already in the shop (sold ones during a
## reroll); they count toward the slots and are never drawn again. Does not touch the state.
static func draw_stock(state: RunState, node_id: int, reroll_index: int, ctx: Dictionary, kept_relics: Array[String], kept_cards: Array[String]) -> Dictionary:
	var cfg: Dictionary = (ctx.get("merchant", {}) as Dictionary).get("config", {})
	var relics_ctx: Dictionary = ctx.get("relics", {})
	var relics: Array[String] = []
	if bool(relics_ctx.get("enabled", false)):
		relics = _draw_relics(state, node_id, reroll_index, ctx, cfg, kept_relics)
	var cards: Array[String] = _draw_cards(state, node_id, reroll_index, ctx, cfg, kept_cards)
	return {"relics": relics, "cards": cards}


static func _draw_relics(state: RunState, node_id: int, reroll_index: int, ctx: Dictionary, cfg: Dictionary, kept: Array[String]) -> Array[String]:
	var relics_ctx: Dictionary = ctx["relics"]
	var catalog: Array = relics_ctx["catalog"]
	var by_id: Dictionary = relics_ctx.get("by_id", {})
	var weights: Dictionary = RunRelics.weights_for(state, relics_ctx)
	var pools: Array[String] = []
	for pool_id: Variant in (ctx.get("pools", []) as Array):
		pools.append(String(pool_id))
	var rng: RandomNumberGenerator = stock_rng(state.seed_value, node_id + ACT_NODE_STEP * (state.act - 1), reroll_index)
	var excluded: Array[String] = state.relics.duplicate()
	excluded.append_array(kept)
	var total: int = int(cfg.get("relic_stock", 3))
	var kept_shop_only: int = 0
	for id: String in kept:
		if is_shop_only(by_id.get(id, {})):
			kept_shop_only += 1
	var shop_only_catalog: Array = catalog.filter(func(r: Variant) -> bool: return is_shop_only(r))
	var needed: int = maxi(total - kept.size(), 0)
	var shop_slots: int = mini(maxi(int(cfg.get("shop_only_slots", 1)) - kept_shop_only, 0), needed)
	var shop_picks: Array[String] = RelicOffer.offer("merchant", shop_slots, rng, weights, excluded, state.relics_given_up, pools, shop_only_catalog)
	var taken: Array[String] = excluded.duplicate()
	taken.append_array(shop_picks)
	var normal_picks: Array[String] = RelicOffer.offer("merchant", needed - shop_picks.size(), rng, weights, taken, state.relics_given_up, pools, catalog)
	var result: Array[String] = normal_picks.duplicate()
	result.append_array(shop_picks)
	return result


static func _draw_cards(state: RunState, node_id: int, reroll_index: int, ctx: Dictionary, cfg: Dictionary, kept: Array[String]) -> Array[String]:
	var wanted: int = int(cfg.get("card_stock", 3))
	var needed: int = maxi(wanted - kept.size(), 0)
	var result: Array[String] = []
	if needed == 0:
		return result
	var rewards: Dictionary = (ctx["rewards"] as Dictionary).duplicate()
	rewards["offer_size"] = needed + kept.size()  # asks for the kept ids too, then drops them, so a reroll never repeats one
	var stream: int = CARD_STREAM_BASE + (node_id + ACT_NODE_STEP * (state.act - 1)) * 64 + reroll_index
	for card_id: String in RewardOffer.generate(state.seed_value, stream, state.deck, ctx["cards"], ctx["pools"], ctx["pool_defs"], rewards, CharacterDatabase.starting_deck(state.character_id), state.removed_cards, state.act):
		if not kept.has(card_id) and result.size() < needed:
			result.append(card_id)
	return result


## True for a relic dictionary whose `sources` are exactly ["merchant"].
static func is_shop_only(relic: Variant) -> bool:
	if typeof(relic) != TYPE_DICTIONARY:
		return false
	var sources: Variant = (relic as Dictionary).get("sources", [])
	return typeof(sources) == TYPE_ARRAY and (sources as Array).size() == 1 and String((sources as Array)[0]) == "merchant"


# --- prices ----------------------------------------------------------------------------------------

## A relic's price from its tier, or -1 when it is not for sale (boss tier, unknown relic).
static func relic_price(relic_id: String, ctx: Dictionary) -> int:
	var relic: Dictionary = ((ctx.get("relics", {}) as Dictionary).get("by_id", {}) as Dictionary).get(relic_id, {})
	if relic.is_empty():
		return -1
	return RelicConfig.price_for_tier(String(relic.get("rarity", "")), (ctx.get("merchant", {}) as Dictionary).get("prices", {}))


## A card's price by its rarity (`merchant.card_prices`, MAP3b); the common price when no card id is given or the card is unknown.
static func card_price(ctx: Dictionary, card_id: String = "") -> int:
	var prices: Dictionary = ((ctx.get("merchant", {}) as Dictionary).get("config", {}) as Dictionary).get("card_prices", {})
	var rarity: String = CardSchema.rarity_of(((ctx.get("by_id", {}) as Dictionary).get(card_id, {}))) if not card_id.is_empty() else CardSchema.RARITY_COMMON
	return int(prices.get(rarity, 0))


## The price of the next removal: removal_base + removal_step x removals already bought.
static func removal_price(state: RunState, ctx: Dictionary) -> int:
	var cfg: Dictionary = (ctx.get("merchant", {}) as Dictionary).get("config", {})
	return int(cfg.get("removal_base", 0)) + int(cfg.get("removal_step", 0)) * state.merchant_removals


# --- buying ----------------------------------------------------------------------------------------

static func blank_result(kind: String, id: String) -> Dictionary:
	return {"ok": false, "kind": kind, "id": id, "price": 0, "reason": "", "needs_giveup": false, "giveable": [] as Array[String], "gave_up": ""}


static func _refuse(result: Dictionary, reason: String) -> Dictionary:
	result["reason"] = reason
	return result


## Buys a relic from the stock. At the relic cap it returns ok false with `needs_giveup` true and the giveable relic ids (nothing charged);
## call again with `give_up_id` (one of them) to swap: that relic is given up, the new one taken and the gold paid in one step.
static func buy_relic(state: RunState, relic_id: String, ctx: Dictionary, give_up_id: String = "") -> Dictionary:
	var result: Dictionary = blank_result(KIND_RELIC, relic_id)
	if not has_visit(state):
		return _refuse(result, "no_visit")
	if not (state.merchant_visit["relics"] as Array).has(relic_id):
		return _refuse(result, "not_in_stock")
	if (state.merchant_visit["sold_relics"] as Array).has(relic_id) or state.has_relic(relic_id):
		return _refuse(result, "sold")
	if not ((ctx.get("relics", {}) as Dictionary).get("by_id", {}) as Dictionary).has(relic_id):
		return _refuse(result, "unknown_relic")  # a stocked id the data no longer has (an old save): not buyable
	var price: int = relic_price(relic_id, ctx)
	if price < 0:
		return _refuse(result, "not_for_sale")
	result["price"] = price
	if price > state.gold:
		return _refuse(result, "too_expensive")
	if RelicOffer.needs_swap(state.relics.size(), RunRelics.max_owned(ctx)):
		var giveable: Array[String] = RunRelics.giveable_ids(state, ctx)
		result["giveable"] = giveable
		if giveable.is_empty():
			return _refuse(result, "none_giveable")
		if give_up_id.is_empty():
			result["needs_giveup"] = true
			return _refuse(result, "needs_giveup")
		if not giveable.has(give_up_id):
			return _refuse(result, "bad_giveup")
		state.give_up_relic(give_up_id)
		result["gave_up"] = give_up_id
	state.add_relic(relic_id)
	_pay(state, price)
	(state.merchant_visit["sold_relics"] as Array).append(relic_id)
	state.log_choice("merchant_relic", relic_id, float(price))
	result["ok"] = true
	return result


static func buy_card(state: RunState, card_id: String, ctx: Dictionary) -> Dictionary:
	var result: Dictionary = blank_result(KIND_CARD, card_id)
	if not has_visit(state):
		return _refuse(result, "no_visit")
	if not (state.merchant_visit["cards"] as Array).has(card_id):
		return _refuse(result, "not_in_stock")
	if (state.merchant_visit["sold_cards"] as Array).has(card_id):
		return _refuse(result, "sold")
	var price: int = card_price(ctx, card_id)
	result["price"] = price
	if price > state.gold:
		return _refuse(result, "too_expensive")
	state.deck.append(card_id)
	_pay(state, price)
	(state.merchant_visit["sold_cards"] as Array).append(card_id)
	state.log_choice("merchant_card", card_id, float(price))
	result["ok"] = true
	return result


## Removes one copy of `card_id` from the deck. Goes through the same guard as the rest room (RunChoices.removal_problems, so a slot minimum
## still holds); the price rises by removal_step after each removal. Needs an open visit.
static func buy_removal(state: RunState, card_id: String, ctx: Dictionary) -> Dictionary:
	var result: Dictionary = blank_result(KIND_REMOVAL, card_id)
	if not has_visit(state):
		return _refuse(result, "no_visit")
	if not state.deck.has(card_id):
		return _refuse(result, "not_in_deck")
	var price: int = removal_price(state, ctx)
	result["price"] = price
	if not RunChoices.removal_problems(state, card_id, ctx).is_empty():
		return _refuse(result, "removal_blocked")
	if price > state.gold:
		return _refuse(result, "too_expensive")
	state.deck.erase(card_id)  # one copy
	state.record_removal(card_id)
	# D47: a copy of the pruned card already on the shelf (unsold) goes too, so it can't be bought straight back in the same visit.
	if not (state.merchant_visit["sold_cards"] as Array).has(card_id):
		(state.merchant_visit["cards"] as Array).erase(card_id)
	state.merchant_removals += 1
	_pay(state, price)
	state.log_choice("merchant_remove", card_id, float(price))
	result["ok"] = true
	return result


static func _pay(state: RunState, price: int) -> void:
	state.gold -= price
	state.gold_spent_merchant += price


# --- reroll hook -----------------------------------------------------------------------------------

## Free rerolls left in this visit (0 with no visit).
static func rerolls_left(state: RunState, ctx: Dictionary) -> int:
	if not has_visit(state):
		return 0
	var granted: int = int((ctx.get("merchant", {}) as Dictionary).get("free_rerolls", 0))
	return maxi(granted - int(state.merchant_visit["rerolls_used"]), 0)


## Redraws the unsold relic and card slots (sold ones stay, shown as sold), seeded from the run seed, node and reroll number, so the same
## visit rerolled the same way always gives the same stock. Returns ok false ("no_rerolls") when none is left.
static func reroll(state: RunState, ctx: Dictionary) -> Dictionary:
	var result: Dictionary = blank_result("reroll", "")
	if not has_visit(state):
		return _refuse(result, "no_visit")
	if rerolls_left(state, ctx) <= 0:
		return _refuse(result, "no_rerolls")
	var visit: Dictionary = state.merchant_visit
	var index: int = int(visit["rerolls_used"]) + 1
	var sold_relics: Array[String] = _ids(visit["sold_relics"])
	var sold_cards: Array[String] = _ids(visit["sold_cards"])
	var fresh: Dictionary = draw_stock(state, int(visit["node"]), index, ctx, sold_relics, sold_cards)
	visit["relics"] = _refill(_ids(visit["relics"]), sold_relics, fresh["relics"])
	visit["cards"] = _refill(_ids(visit["cards"]), sold_cards, fresh["cards"])
	visit["rerolls_used"] = index
	result["ok"] = true
	return result


## `old` with every unsold slot replaced by the next id of `fresh` (a slot with nothing left to fill it is dropped).
static func _refill(old: Array[String], sold: Array[String], fresh: Array[String]) -> Array[String]:
	var out: Array[String] = []
	var next: int = 0
	for id: String in old:
		if sold.has(id):
			out.append(id)
		elif next < fresh.size():
			out.append(fresh[next])
			next += 1
	return out


static func _ids(value: Variant) -> Array[String]:
	var out: Array[String] = []
	for item: Variant in (value as Array):
		out.append(String(item))
	return out


# --- what the UI draws -----------------------------------------------------------------------------

## The stock as a list of item dictionaries for a panel: {kind, id, name, price, sold, can_buy, reason, needs_giveup}. Relics first, then cards,
## then the removal entry (id ""). `reason` is empty when the item can be bought now ("needs_giveup" is not a refusal: `can_buy` stays true).
static func items(state: RunState, ctx: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not has_visit(state):
		return out
	var visit: Dictionary = state.merchant_visit
	for relic_id: String in _ids(visit["relics"]):
		var price: int = relic_price(relic_id, ctx)
		var sold: bool = (visit["sold_relics"] as Array).has(relic_id)
		var reason: String = ""
		if sold:
			reason = "sold"
		elif price < 0:
			reason = "not_for_sale"
		elif price > state.gold:
			reason = "too_expensive"
		var at_cap: bool = RelicOffer.needs_swap(state.relics.size(), RunRelics.max_owned(ctx))
		if reason.is_empty() and at_cap and RunRelics.giveable_ids(state, ctx).is_empty():
			reason = "none_giveable"  # at the cap with nothing that can be given up (boss relics can't): the same refusal buy_relic gives
		out.append({"kind": KIND_RELIC, "id": relic_id, "name": String(RunRelics.display(relic_id, ctx)["name"]), "price": price, "sold": sold,
				"can_buy": reason.is_empty(), "reason": reason, "needs_giveup": reason.is_empty() and at_cap})
	for card_id: String in _ids(visit["cards"]):
		var card_cost: int = card_price(ctx, card_id)
		var card_sold: bool = (visit["sold_cards"] as Array).has(card_id)
		var card_reason: String = "sold" if card_sold else ("too_expensive" if card_cost > state.gold else "")
		var card: Dictionary = (ctx["by_id"] as Dictionary).get(card_id, {})
		out.append({"kind": KIND_CARD, "id": card_id, "name": String(card.get("name", card_id)), "rarity": CardSchema.rarity_of(card), "price": card_cost, "sold": card_sold,
				"can_buy": card_reason.is_empty(), "reason": card_reason, "needs_giveup": false})
	var removal: int = removal_price(state, ctx)
	var removal_reason: String = ""
	if RunChoices.removable_card_ids(state, ctx).is_empty():
		removal_reason = "none_removable"  # no gold helps: every card is needed for a slot minimum (the list says which, per card)
	elif removal > state.gold:
		removal_reason = "too_expensive"
	out.append({"kind": KIND_REMOVAL, "id": "", "name": "", "price": removal, "sold": false, "can_buy": removal_reason.is_empty(),
			"reason": removal_reason, "needs_giveup": false})
	return out


## The card removal list for a panel, one entry per distinct card in deck order: {card_id, name, slot_type, slot_name, count, price, can_buy, reason,
## problems, reason_text}. `reason` is "removal_blocked" (a slot minimum; `problems` and `reason_text` say which and what to do, the same words as the
## rest room list), else "too_expensive", else "". Blocked wins over too expensive, since gold does not fix it.
static func removal_entries(state: RunState, ctx: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var price: int = removal_price(state, ctx)
	for card_id: String in RunChoices.unique_deck_ids(state, ctx):
		var card: Dictionary = (ctx["by_id"] as Dictionary).get(card_id, {})
		var slot_type: String = String(card.get("slot_type", ""))
		var problems: Array[String] = RunChoices.removal_problems(state, card_id, ctx)
		var reason: String = ""
		var reason_text: String = ""
		if not problems.is_empty():
			reason = "removal_blocked"
			reason_text = RunChoices.removal_reason(state, card_id, problems, ctx)
		elif price > state.gold:
			reason = "too_expensive"
		out.append({"card_id": card_id, "name": String(card.get("name", card_id)), "slot_type": slot_type,
				"slot_name": String((ctx["slot_names"] as Dictionary).get(slot_type, slot_type)), "count": state.deck.count(card_id), "price": price,
				"can_buy": reason.is_empty(), "reason": reason, "problems": problems, "reason_text": reason_text})
	return out
