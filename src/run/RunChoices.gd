class_name RunChoices
extends RefCounted
## The generic choice model of a run (Milestone 3b): after a won room the player faces a list of options, and
## `apply` resolves one. Pure and static over a RunState and a context Dictionary (see `shipped_context`), so
## it is testable without a scene and a level-up screen can reuse it later. It handles card ids, slot types and
## pools only; the one place that looks inside a card is `CardSummary` (display text from the effect params).
##
## Option dict (what the screen draws; every key is always present):
##   id: String        stable key passed back to `apply` ("card:<card_id>", "skip", "heal", "remove_menu", "remove:<card_id>", "back")
##   kind: String      "card" | "remove" | "heal" | "skip" | "back"
##   label: String     the main text (card name, "Rest and heal", ...)
##   detail: String    second line (effect line, "Heal 9 HP (30% of max)", ...)
##   flavor: String    card flavor text, else ""
##   card_id: String   the card, else ""
##   slot_type: String / slot_name: String   the card's slot, else ""
##   count: int        copies owned (remove lists), else 0
##   enabled: bool     false = draw it greyed out and refuse activation
##   reason: String    why it is disabled ("" when enabled)
##   costs_reject: bool  true on the reject option
##   opens_list: bool    true on "Remove a card" in the rest menu (it opens the removal list)
##   amount: float       HP a heal option gives, else 0
##
## Model dict (`model`): {choice: "reward"|"rest"|"rest_remove", title, line, options, rejects_remaining, rejects_max}.

const KINDS: Array[String] = ["card", "remove", "heal", "skip", "back"]


## The shipped databases and data as one context. Tests build their own with fixtures.
static func shipped_context(pools: Array) -> Dictionary:
	var cards: Array = CardDatabase.all_cards()
	var by_id: Dictionary = {}
	for card: Variant in cards:
		by_id[String((card as Dictionary)["id"])] = card
	var pool_defs: Dictionary = {}
	for pool_id: String in PoolDatabase.known_ids():
		pool_defs[pool_id] = PoolDatabase.get_definition(pool_id)
	var slot_base: Dictionary = {}
	for slot_type: String in SlotTypeDatabase.known_ids():
		slot_base[slot_type] = float(SlotTypeDatabase.get_definition(slot_type).get("base_cooldown", 1.0))
	return {
		"cards": cards,
		"by_id": by_id,
		"pools": pools.duplicate(),
		"pool_defs": pool_defs,
		"slot_base": slot_base,
		"rewards": RunConfig.rewards(),
		"heal_fraction": RunConfig.rest_heal_fraction(),
		"rejects_max": RunConfig.rejects_per_run(),
		"ui": RunConfig.ui(),
		"deck_rules": DeckRules.shipped_config(),
		"slot_of": DeckRules.slot_map_from_database(),
		"known_slots": SlotTypeDatabase.known_ids(),
		"slot_names": DeckRules.slot_names_from_database(),
	}


## Opens the choice that follows a room: a card reward after a won fighting room that gives one (never the last
## room), the rest menu in a rest room. Sets `state.pending` / `state.offer`; returns the pending value.
static func open_for_room(state: RunState, room_type: String, is_last_room: bool, ctx: Dictionary) -> String:
	state.pending = RunState.PENDING_NONE
	state.offer = []
	if room_type == "rest":
		state.pending = RunState.PENDING_REST
	elif not is_last_room and (RunConfig.ROOM_TYPES.has(room_type) and ((ctx["rewards"] as Dictionary).get("reward_room_types", []) as Array).has(room_type)):
		var offered: Array[String] = RewardOffer.generate(state.seed_value, state.room_index, state.deck, ctx["cards"], ctx["pools"], ctx["pool_defs"], ctx["rewards"])
		if not offered.is_empty():
			state.offer = offered
			state.pending = RunState.PENDING_REWARD
	return state.pending


static func model(state: RunState, ctx: Dictionary) -> Dictionary:
	var ui: Dictionary = ctx["ui"]
	var title: String = ""
	var line: String = ""
	match state.pending:
		RunState.PENDING_REWARD:
			title = String((ui["reward"] as Dictionary)["title"])
			line = String((ui["reward"] as Dictionary)["line"])
		RunState.PENDING_REST:
			title = String((ui["rest"] as Dictionary)["title"])
			line = String((ui["rest"] as Dictionary)["line"])
		RunState.PENDING_REST_REMOVE:
			title = String((ui["rest"] as Dictionary)["remove_title"])
			line = String((ui["rest"] as Dictionary)["remove_line"])
	return {
		"choice": state.pending,
		"title": title,
		"line": line,
		"options": options(state, ctx),
		"rejects_remaining": state.rejects_remaining,
		"rejects_max": int(ctx["rejects_max"]),
	}


static func options(state: RunState, ctx: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ui: Dictionary = ctx["ui"]
	match state.pending:
		RunState.PENDING_REWARD:
			for card_id: String in state.offer:
				out.append(card_option("card:" + card_id, "card", card_id, ctx))
			var r: Dictionary = ui["reward"]
			var skip: Dictionary = _blank("skip", "skip")
			skip["label"] = String(r["skip_label"])
			skip["detail"] = String(r["skip_detail"]) % [state.rejects_remaining, int(ctx["rejects_max"])]
			skip["costs_reject"] = true
			if state.rejects_remaining <= 0:
				skip["enabled"] = false
				skip["reason"] = String(r["skip_disabled"])
			out.append(skip)
		RunState.PENDING_REST:
			var t: Dictionary = ui["rest"]
			var heal: Dictionary = _blank("heal", "heal")
			var amount: float = heal_amount(state, float(ctx["heal_fraction"]))
			heal["label"] = String(t["heal_label"])
			heal["amount"] = amount
			if amount > 0.0:
				heal["detail"] = String(t["heal_detail"]) % [roundi(amount), roundi(float(ctx["heal_fraction"]) * 100.0)]
			else:
				heal["detail"] = String(t["heal_full_detail"])
			out.append(heal)
			var menu: Dictionary = _blank("remove_menu", "remove")
			menu["label"] = String(t["remove_label"])
			menu["detail"] = String(t["remove_detail"])
			menu["opens_list"] = true
			if removable_card_ids(state, ctx).is_empty():
				menu["enabled"] = false
				menu["reason"] = String(t["remove_none"])
			out.append(menu)
		RunState.PENDING_REST_REMOVE:
			for card_id: String in unique_deck_ids(state, ctx):
				var option: Dictionary = card_option("remove:" + card_id, "remove", card_id, ctx)
				option["count"] = state.deck.count(card_id)
				var problems: Array[String] = removal_problems(state, card_id, ctx)
				if not problems.is_empty():
					option["enabled"] = false
					option["reason"] = "; ".join(problems)
				out.append(option)
			var back: Dictionary = _blank("back", "back")
			back["label"] = String((ui["rest"] as Dictionary)["back_label"])
			out.append(back)
	return out


## Resolves one option. Returns {ok, kind, card_id, amount, finished}: `finished` is true when the whole choice
## is done (the caller moves on), false when the screen should rebuild from `model` (the rest removal list, Back).
## A disabled or unknown option changes nothing and returns ok = false with a `reason`.
static func apply(state: RunState, option_id: String, ctx: Dictionary) -> Dictionary:
	var result: Dictionary = {"ok": false, "kind": "", "card_id": "", "amount": 0.0, "finished": false, "reason": ""}
	var found: Dictionary = {}
	for option: Dictionary in options(state, ctx):
		if String(option["id"]) == option_id:
			found = option
			break
	if found.is_empty():
		result["reason"] = "no such option '%s' in the %s choice" % [option_id, state.pending]
		return result
	if not bool(found["enabled"]):
		result["reason"] = String(found["reason"])
		return result
	result["kind"] = String(found["kind"])
	result["card_id"] = String(found["card_id"])
	match option_id.get_slice(":", 0):
		"card":
			state.deck.append(String(found["card_id"]))
			state.log_choice("pick", String(found["card_id"]))
			_close(state)
			result["finished"] = true
		"skip":
			state.rejects_remaining -= 1
			state.log_choice("reject")
			_close(state)
			result["finished"] = true
		"heal":
			var amount: float = float(found["amount"])
			state.hp = minf(state.hp + amount, state.max_hp)
			state.log_choice("heal", "", amount)
			result["amount"] = amount
			_close(state)
			result["finished"] = true
		"remove_menu":
			state.pending = RunState.PENDING_REST_REMOVE
		"remove":
			state.deck.remove_at(state.deck.find(String(found["card_id"])))
			state.log_choice("remove", String(found["card_id"]))
			_close(state)
			result["finished"] = true
		"back":
			state.pending = RunState.PENDING_REST
	result["ok"] = true
	return result


static func _close(state: RunState) -> void:
	state.pending = RunState.PENDING_NONE
	state.offer = []


## HP a rest would heal now (0 at full HP).
static func heal_amount(state: RunState, fraction: float) -> float:
	if not state.has_hp():
		return 0.0
	return maxf(minf(state.max_hp * fraction, state.max_hp - state.hp), 0.0)


## Deck-rule shortfalls that removing one copy of the card would cause (empty = allowed).
static func removal_problems(state: RunState, card_id: String, ctx: Dictionary) -> Array[String]:
	return DeckRules.can_remove(state.deck, card_id, ctx["deck_rules"], ctx["slot_of"], ctx["known_slots"], ctx["slot_names"])


static func removable_card_ids(state: RunState, ctx: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for card_id: String in unique_deck_ids(state, ctx):
		if removal_problems(state, card_id, ctx).is_empty():
			out.append(card_id)
	return out


## Distinct deck ids, in slot order then name, for the removal list.
static func unique_deck_ids(state: RunState, ctx: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for card_id: String in state.deck:
		if not ids.has(card_id):
			ids.append(card_id)
	var order: Array = (ctx["known_slots"] as Array)
	var by_id: Dictionary = ctx["by_id"]
	ids.sort_custom(func(a: String, b: String) -> bool:
		var sa: int = order.find(String((by_id.get(a, {}) as Dictionary).get("slot_type", "")))
		var sb: int = order.find(String((by_id.get(b, {}) as Dictionary).get("slot_type", "")))
		if sa != sb:
			return sa < sb
		return String((by_id.get(a, {}) as Dictionary).get("name", a)) < String((by_id.get(b, {}) as Dictionary).get("name", b)))
	return ids


static func card_option(option_id: String, kind: String, card_id: String, ctx: Dictionary) -> Dictionary:
	var option: Dictionary = _blank(option_id, kind)
	var card: Dictionary = (ctx["by_id"] as Dictionary).get(card_id, {})
	var slot_type: String = String(card.get("slot_type", ""))
	option["card_id"] = card_id
	option["label"] = String(card.get("name", card_id))
	option["flavor"] = String(card.get("flavor_text", ""))
	option["slot_type"] = slot_type
	option["slot_name"] = String((ctx["slot_names"] as Dictionary).get(slot_type, slot_type))
	var effect_text: Dictionary = ((ctx["ui"] as Dictionary).get("effect", {}) as Dictionary).duplicate()
	effect_text["slot_names"] = ctx["slot_names"]
	option["detail"] = CardSummary.effect_line(card, float((ctx["slot_base"] as Dictionary).get(slot_type, -1.0)), effect_text)
	return option


static func _blank(option_id: String, kind: String) -> Dictionary:
	return {
		"id": option_id, "kind": kind, "label": "", "detail": "", "flavor": "", "card_id": "",
		"slot_type": "", "slot_name": "", "count": 0, "enabled": true, "reason": "",
		"costs_reject": false, "opens_list": false, "amount": 0.0,
	}
