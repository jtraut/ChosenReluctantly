class_name RunMerchant
extends RefCounted
## The merchant half of a map run's flow (MAP2-B). Pure and static over a RunState and the same context Dictionary RunChoices uses (its "merchant"
## entry, see MerchantConfig.shipped_context), so the whole visit is testable without a scene. The buying rules are Merchant's; this turns them into
## the generic choice model the run screen and the bots already speak.
##
## A merchant node is a room with no fight. Entering it opens the choice `RunState.PENDING_MERCHANT` (the shop), with the visit's stock in
## `RunState.merchant_visit`. Three screens, each its own pending value so a save/restore lands on the same one:
##   PENDING_MERCHANT         the shop: one option per stocked relic and card, the removal entry, the free reroll (when a relic grants one), Leave.
##   PENDING_MERCHANT_REMOVE  the card removal list (the rest room's list with a price), and Back.
##   PENDING_MERCHANT_SWAP    a relic bought at the relic cap: pick which owned relic to give up (BD2's step), or Cancel. `relic_incoming` is the relic.
## Buying several items in one visit, in any order, is just several choices; Leaving (`finished`) closes the visit and the run picks its next node.
##
## Option ids (kind in brackets): "buy_relic:<id>" [buy_relic], "buy_card:<id>" [buy_card], "merchant_remove_menu" [buy_removal],
## "merchant_remove:<card_id>" [remove] (accepted from the shop too), "merchant_reroll" [reroll], "merchant_leave" [back], "merchant_back" [back],
## "merchant_giveup:<relic_id>" [giveup], "merchant_cancel" [back]. Every option carries `price`, `reason_code` ("" when buyable, else a Merchant reason
## code or "sold") and, as the usual `reason`, the words for it from data/run.json `ui.merchant.reasons`. A refused apply returns ok false with `reason`
## (the words) and `reason_code`.
##
## Result kinds of `apply`: "merchant_relic" (`relic_id`, `gave_up` set after a swap), "merchant_card" (`card_id`), "merchant_remove" (`card_id`),
## "merchant_reroll", "merchant_menu" (opened the removal list), "merchant_swap_open", "merchant_cancel", "merchant_back", "merchant_leave" (finished).

const OPTION_BUY_RELIC := "buy_relic"
const OPTION_BUY_CARD := "buy_card"
const OPTION_REMOVE_MENU := "merchant_remove_menu"
const OPTION_REMOVE := "merchant_remove"
const OPTION_REROLL := "merchant_reroll"
const OPTION_LEAVE := "merchant_leave"
const OPTION_BACK := "merchant_back"
const OPTION_GIVEUP := "merchant_giveup"
const OPTION_CANCEL := "merchant_cancel"
## The relic modifier stat that grants free rerolls of the stock per visit (Request for Quotation).
const FREE_REROLLS_STAT := "merchant.free_rerolls"


static func owns(pending: String) -> bool:
	return RunState.MERCHANT_PENDING.has(pending)


# --- context and opening ------------------------------------------------------------------------

## Free rerolls per visit the owned relics grant: the sum of their `merchant.free_rerolls` modifiers.
static func free_rerolls(state: RunState, ctx: Dictionary) -> int:
	var by_id: Dictionary = (ctx.get("relics", {}) as Dictionary).get("by_id", {})
	var total: float = 0.0
	for relic_id: String in state.relics:
		for entry: Variant in ((by_id.get(relic_id, {}) as Dictionary).get("modifiers", []) as Array):
			if String((entry as Dictionary).get("stat", "")) == FREE_REROLLS_STAT:
				total += float((entry as Dictionary).get("value", 0.0))
	return maxi(roundi(total), 0)


## Puts the free rerolls the owned relics grant into the context (`ctx["merchant"]["free_rerolls"]`), where Merchant reads them. Called at the
## top of every entry point, so a relic bought in the visit counts at once.
static func sync(state: RunState, ctx: Dictionary) -> void:
	if not ctx.has("merchant"):
		ctx["merchant"] = {}
	(ctx["merchant"] as Dictionary)["free_rerolls"] = free_rerolls(state, ctx)


## Opens the visit at the node the run is in and the shop choice. Returns the pending value.
static func open_for_room(state: RunState, ctx: Dictionary) -> String:
	sync(state, ctx)
	var node_id: int = state.path[state.path.size() - 1] if not state.path.is_empty() else state.room_index
	Merchant.open_visit(state, node_id, ctx)
	state.offer = []
	state.offer_rarity = ""
	state.relic_incoming = ""
	state.pending = RunState.PENDING_MERCHANT
	return state.pending


# --- text ---------------------------------------------------------------------------------------

static func _ui(ctx: Dictionary) -> Dictionary:
	return (ctx.get("ui", {}) as Dictionary).get("merchant", {})


static func _config(ctx: Dictionary) -> Dictionary:
	return (ctx.get("merchant", {}) as Dictionary).get("config", {})


## The words for a reason code (`ui.merchant.reasons`), or the code itself when data has none.
static func reason_text(code: String, ctx: Dictionary) -> String:
	if code.is_empty():
		return ""
	return String(((_ui(ctx).get("reasons", {})) as Dictionary).get(code, code))


static func title_and_line(state: RunState, ctx: Dictionary) -> Dictionary:
	var ui: Dictionary = _ui(ctx)
	match state.pending:
		RunState.PENDING_MERCHANT_REMOVE:
			return {"title": String(ui.get("remove_title", "")), "line": String(ui.get("remove_line", "")) % Merchant.removal_price(state, ctx)}
		RunState.PENDING_MERCHANT_SWAP:
			var relic_ui: Dictionary = (ctx.get("relics", {}) as Dictionary).get("ui", {})
			var incoming: Dictionary = RunRelics.display(state.relic_incoming, ctx)
			var line_key: String = "swap_line_one" if (state.relics.size() == 1 and relic_ui.has("swap_line_one")) else "swap_line"
			return {"title": String(relic_ui.get("swap_title", "")), "line": String(relic_ui.get(line_key, "")) % [state.relics.size(), String(incoming["name"])]}
	return {"title": String(ui.get("title", "")), "line": String(ui.get("line", "")) % state.gold}


# --- options ------------------------------------------------------------------------------------

static func options(state: RunState, ctx: Dictionary) -> Array[Dictionary]:
	sync(state, ctx)
	match state.pending:
		RunState.PENDING_MERCHANT:
			return _shop_options(state, ctx)
		RunState.PENDING_MERCHANT_REMOVE:
			return _removal_options(state, ctx)
		RunState.PENDING_MERCHANT_SWAP:
			return _swap_options(state, ctx)
	return [] as Array[Dictionary]


static func _shop_options(state: RunState, ctx: Dictionary) -> Array[Dictionary]:
	var ui: Dictionary = _ui(ctx)
	var out: Array[Dictionary] = []
	for item: Dictionary in Merchant.items(state, ctx):
		var kind: String = String(item["kind"])
		var option: Dictionary
		match kind:
			Merchant.KIND_RELIC:
				option = RunRelics.relic_option(OPTION_BUY_RELIC + ":" + String(item["id"]), OPTION_BUY_RELIC, String(item["id"]), ctx)
				option["needs_swap"] = bool(item["needs_giveup"])
				option["label"] = String(ui.get("item_format", "%s - %d")) % [String(option["label"]), int(item["price"])]
			Merchant.KIND_CARD:
				option = RunChoices.card_option(OPTION_BUY_CARD + ":" + String(item["id"]), OPTION_BUY_CARD, String(item["id"]), ctx)
				option["owned"] = state.deck.count(String(item["id"]))
				option["label"] = String(ui.get("item_format", "%s - %d")) % [String(option["label"]), int(item["price"])]
			_:
				option = RunChoices.blank_option(OPTION_REMOVE_MENU, "buy_removal")
				option["label"] = String(ui.get("removal_format", "%d")) % int(item["price"])
				option["detail"] = String(ui.get("removal_detail", "")) % int(_config(ctx).get("removal_step", 0))
				option["opens_list"] = true
		option["price"] = int(item["price"])
		option["sold"] = bool(item["sold"])
		option["reason_code"] = String(item["reason"])
		option["enabled"] = bool(item["can_buy"])
		option["reason"] = reason_text(String(item["reason"]), ctx)
		out.append(option)
	var granted: int = int((ctx.get("merchant", {}) as Dictionary).get("free_rerolls", 0))
	if granted > 0:
		var left: int = Merchant.rerolls_left(state, ctx)
		var reroll: Dictionary = RunChoices.blank_option(OPTION_REROLL, "reroll")
		reroll["label"] = String(ui.get("reroll_label", ""))
		reroll["detail"] = String(ui.get("reroll_detail", "")) % left
		reroll["price"] = 0
		reroll["enabled"] = left > 0
		reroll["reason_code"] = "" if left > 0 else "no_rerolls"
		reroll["reason"] = reason_text(String(reroll["reason_code"]), ctx)
		out.append(reroll)
	# Kind "back" on purpose: the run screen puts a "back" option in its footer, which is always on screen, so Leave stays reachable by mouse however many
	# items the shop holds (the row of items can be wider than the screen). Tell it from the removal list's Back by its id.
	var leave: Dictionary = RunChoices.blank_option(OPTION_LEAVE, "back")
	leave["label"] = String(ui.get("leave_label", ""))
	leave["detail"] = String(ui.get("leave_detail", ""))
	out.append(leave)
	return out


static func _removal_options(state: RunState, ctx: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in Merchant.removal_entries(state, ctx):
		var option: Dictionary = RunChoices.card_option(OPTION_REMOVE + ":" + String(entry["card_id"]), "remove", String(entry["card_id"]), ctx)
		option["count"] = int(entry["count"])
		option["price"] = int(entry["price"])
		option["reason_code"] = String(entry["reason"])
		option["enabled"] = bool(entry["can_buy"])
		option["reason"] = String(entry["reason_text"]) if String(entry["reason"]) == "removal_blocked" else reason_text(String(entry["reason"]), ctx)
		out.append(option)
	var back: Dictionary = RunChoices.blank_option(OPTION_BACK, "back")
	back["label"] = String(_ui(ctx).get("back_label", ""))
	out.append(back)
	return out


static func _swap_options(state: RunState, ctx: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for relic_id: String in RunRelics.giveable_ids(state, ctx):
		out.append(RunRelics.relic_option(OPTION_GIVEUP + ":" + relic_id, "giveup", relic_id, ctx))
	var cancel: Dictionary = RunChoices.blank_option(OPTION_CANCEL, "back")
	cancel["label"] = String(((ctx.get("relics", {}) as Dictionary).get("ui", {}) as Dictionary).get("cancel_label", ""))
	out.append(cancel)
	return out


# --- the data hook for the panel ----------------------------------------------------------------

## Everything a merchant panel draws, in one dictionary (the model's `merchant` key; RunController.merchant_view()):
##   open: bool, gold: int, relic_count, relic_max
##   items: Array of {kind "relic"|"card"|"removal", id, name, price, sold, can_buy, reason (code), reason_text, needs_giveup}, relics first, then cards,
##          then the removal entry (id "")
##   removal: {price, bought, step, can_buy, reason, reason_text, entries: Array of {card_id, name, slot_type, slot_name, count, price, can_buy, reason,
##          problems, reason_text}} (reason "none_removable" on the entry when no card can go; per-card "removal_blocked" in `entries`)
##   rerolls: {granted, left, used}
##   swap: {active, incoming (a relic display dict, {} when inactive), giveable (display dicts)}
## Reason codes: "sold", "too_expensive", "not_for_sale", "none_removable", "removal_blocked", "no_rerolls", plus the refusals of a buy call
## ("needs_giveup" is not a refusal: the item is buyable and `needs_giveup` is true).
static func view(state: RunState, ctx: Dictionary) -> Dictionary:
	sync(state, ctx)
	var open: bool = Merchant.has_visit(state)
	var items: Array[Dictionary] = []
	for item: Dictionary in Merchant.items(state, ctx):
		var shown: Dictionary = item.duplicate()
		shown["reason_text"] = reason_text(String(item["reason"]), ctx)
		items.append(shown)
	var cfg: Dictionary = _config(ctx)
	var removal_entry: Dictionary = {}
	for item: Dictionary in items:
		if String(item["kind"]) == Merchant.KIND_REMOVAL:
			removal_entry = item
	var granted: int = int((ctx.get("merchant", {}) as Dictionary).get("free_rerolls", 0))
	var swapping: bool = state.pending == RunState.PENDING_MERCHANT_SWAP
	var giveable: Array[Dictionary] = []
	if swapping:
		for relic_id: String in RunRelics.giveable_ids(state, ctx):
			giveable.append(RunRelics.display(relic_id, ctx))
	return {
		"open": open, "gold": state.gold, "relic_count": state.relics.size(), "relic_max": RunRelics.max_owned(ctx),
		"items": items,
		"removal": {
			"price": Merchant.removal_price(state, ctx), "bought": state.merchant_removals, "step": int(cfg.get("removal_step", 0)),
			"can_buy": bool(removal_entry.get("can_buy", false)), "reason": String(removal_entry.get("reason", "")),
			"reason_text": String(removal_entry.get("reason_text", "")), "entries": Merchant.removal_entries(state, ctx),
		},
		"rerolls": {"granted": granted, "left": Merchant.rerolls_left(state, ctx), "used": int(state.merchant_visit.get("rerolls_used", 0)) if open else 0},
		"swap": {"active": swapping, "incoming": RunRelics.display(state.relic_incoming, ctx) if swapping else {}, "giveable": giveable},
	}


## Extra model keys of a merchant choice: `merchant` (see `view`), the owned relics and the cap, and in the give-up step the relic keys the relic
## give-up screen reads (`relic_choice` "giveup", `incoming`, `giveable`).
static func model_extras(state: RunState, ctx: Dictionary) -> Dictionary:
	var extras: Dictionary = {
		"merchant": view(state, ctx), "merchant_screen": "shop",
		"relics_owned": RunRelics.owned_display(state, ctx), "relics_given_up": RunRelics.given_up_display(state, ctx), "relic_max_owned": RunRelics.max_owned(ctx),
	}
	match state.pending:
		RunState.PENDING_MERCHANT_REMOVE:
			extras["merchant_screen"] = "remove"
		RunState.PENDING_MERCHANT_SWAP:
			extras["merchant_screen"] = "swap"
			var swap: Dictionary = (extras["merchant"] as Dictionary)["swap"]
			extras["relic_choice"] = "giveup"
			extras["incoming"] = swap["incoming"]
			extras["giveable"] = swap["giveable"]
	return extras


# --- resolving ----------------------------------------------------------------------------------

static func _refused(result: Dictionary, code: String, ctx: Dictionary) -> Dictionary:
	result["ok"] = false
	result["reason_code"] = code
	result["reason"] = reason_text(code, ctx)
	return result


## Resolves one option of a merchant choice. Same result dict as RunChoices.apply, plus `reason_code` and `gave_up`. A refused buy changes nothing.
static func apply(state: RunState, option_id: String, ctx: Dictionary) -> Dictionary:
	sync(state, ctx)
	var result: Dictionary = RunChoices.blank_result()
	result["reason_code"] = ""
	result["gave_up"] = ""
	var head: String = option_id.get_slice(":", 0)
	var tail: String = option_id.substr(head.length() + 1) if option_id.contains(":") else ""
	var pending: String = state.pending
	if not Merchant.has_visit(state):
		return _refused(result, "no_visit", ctx)
	if pending == RunState.PENDING_MERCHANT_SWAP:
		match head:
			OPTION_GIVEUP:
				var swapped: Dictionary = Merchant.buy_relic(state, state.relic_incoming, ctx, tail)
				if not bool(swapped["ok"]):
					return _refused(result, String(swapped["reason"]), ctx)
				state.relic_incoming = ""
				state.pending = RunState.PENDING_MERCHANT
				result["kind"] = "merchant_relic"
				result["relic_id"] = String(swapped["id"])
				result["gave_up"] = String(swapped["gave_up"])
				result["amount"] = float(swapped["price"])
				result["ok"] = true
				return result
			OPTION_CANCEL:
				state.relic_incoming = ""
				state.pending = RunState.PENDING_MERCHANT
				result["kind"] = "merchant_cancel"
				result["ok"] = true
				return result
		result["reason"] = "no such option '%s' in the %s choice" % [option_id, pending]
		return result
	match head:
		OPTION_BUY_RELIC:
			if pending != RunState.PENDING_MERCHANT:
				result["reason"] = "no such option '%s' in the %s choice" % [option_id, pending]
				return result
			var bought: Dictionary = Merchant.buy_relic(state, tail, ctx)
			if bool(bought["needs_giveup"]):
				state.relic_incoming = tail
				state.pending = RunState.PENDING_MERCHANT_SWAP
				result["kind"] = "merchant_swap_open"
				result["relic_id"] = tail
				result["ok"] = true
				return result
			if not bool(bought["ok"]):
				return _refused(result, String(bought["reason"]), ctx)
			sync(state, ctx)
			result["kind"] = "merchant_relic"
			result["relic_id"] = tail
			result["amount"] = float(bought["price"])
			result["ok"] = true
			return result
		OPTION_BUY_CARD:
			if pending != RunState.PENDING_MERCHANT:
				result["reason"] = "no such option '%s' in the %s choice" % [option_id, pending]
				return result
			var card: Dictionary = Merchant.buy_card(state, tail, ctx)
			if not bool(card["ok"]):
				return _refused(result, String(card["reason"]), ctx)
			result["kind"] = "merchant_card"
			result["card_id"] = tail
			result["amount"] = float(card["price"])
			result["ok"] = true
			return result
		OPTION_REMOVE_MENU:
			if pending != RunState.PENDING_MERCHANT:
				result["reason"] = "no such option '%s' in the %s choice" % [option_id, pending]
				return result
			var entry: Dictionary = {}
			for item: Dictionary in Merchant.items(state, ctx):
				if String(item["kind"]) == Merchant.KIND_REMOVAL:
					entry = item
			if not bool(entry.get("can_buy", false)):
				return _refused(result, String(entry.get("reason", "none_removable")), ctx)
			state.pending = RunState.PENDING_MERCHANT_REMOVE
			result["kind"] = "merchant_menu"
			result["ok"] = true
			return result
		OPTION_REMOVE:
			var removed: Dictionary = Merchant.buy_removal(state, tail, ctx)
			if not bool(removed["ok"]):
				var code: String = String(removed["reason"])
				result["reason"] = RunChoices.removal_reason(state, tail, RunChoices.removal_problems(state, tail, ctx), ctx) if code == "removal_blocked" else reason_text(code, ctx)
				result["reason_code"] = code
				return result
			state.pending = RunState.PENDING_MERCHANT
			result["kind"] = "merchant_remove"
			result["card_id"] = tail
			result["amount"] = float(removed["price"])
			result["ok"] = true
			return result
		OPTION_BACK:
			if pending != RunState.PENDING_MERCHANT_REMOVE:
				result["reason"] = "no such option '%s' in the %s choice" % [option_id, pending]
				return result
			state.pending = RunState.PENDING_MERCHANT
			result["kind"] = "merchant_back"
			result["ok"] = true
			return result
		OPTION_REROLL:
			if pending != RunState.PENDING_MERCHANT:
				result["reason"] = "no such option '%s' in the %s choice" % [option_id, pending]
				return result
			var rolled: Dictionary = Merchant.reroll(state, ctx)
			if not bool(rolled["ok"]):
				return _refused(result, String(rolled["reason"]), ctx)
			state.log_choice("merchant_reroll")
			result["kind"] = "merchant_reroll"
			result["ok"] = true
			return result
		OPTION_LEAVE:
			if pending != RunState.PENDING_MERCHANT:
				result["reason"] = "no such option '%s' in the %s choice" % [option_id, pending]
				return result
			Merchant.close_visit(state)
			RunChoices.close(state)
			result["kind"] = "merchant_leave"
			result["finished"] = true
			result["ok"] = true
			return result
	result["reason"] = "no such option '%s' in the %s choice" % [option_id, pending]
	return result
