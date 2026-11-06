class_name RunRelics
extends RefCounted
## The relic half of a run's choices (BD2-B). Pure and static over a RunState and the same context Dictionary RunChoices
## uses; the context's "relics" entry (see `shipped_context`) switches it on. Without that entry, or with `enabled` false,
## `open_for_room` is exactly RunChoices.open_for_room, so a run without relics is the run it was.
##
## Where relics are offered (BUILD_DEPTH 4.1, D30 = A): after an elite room (it replaces that room's card offer) and in the
## straight run's relic room. Rest rooms and card reward screens never offer relics. Pick 1 of N or skip; skipping costs
## nothing (it is not a card reject). If no relic is eligible, the elite gives its card offer, and so does the relic room.
##
## At the cap (`relics.max_owned`) the offer still appears: taking a relic first asks which owned relic to give up (boss-tier
## relics can't be). Cancel goes back to the offer and keeps everything. A relic given up is never offered again this run.
##
## Option ids: "relic:<id>" (kind "relic"), "relic_skip" (kind "relic_skip"); in the give-up step "giveup:<id>" (kind "giveup")
## and "giveup_cancel" (kind "back"). Every relic option carries the display keys of `display` (name, tier, pool, rule text,
## flavor) on top of the usual option keys.

## Room types that offer a relic, and the relic `source` each one draws from.
const SOURCE_BY_ROOM: Dictionary = {"elite": "elite", "relic_room": "relic_room"}
const OPTION_RELIC := "relic"
const OPTION_SKIP := "relic_skip"
const OPTION_GIVEUP := "giveup"
const OPTION_CANCEL := "giveup_cancel"
## The straight run is one act. Tier odds come from this act's row (RelicConfig.tier_weights_for_act).
const STRAIGHT_RUN_ACT := 1


## The relic part of a RunChoices context from the shipped data. `RunSession.relic_cap` (a launch flag) overrides the cap.
static func shipped_context() -> Dictionary:
	var catalog: Array = RelicDatabase.all_relics()
	var by_id: Dictionary = {}
	for relic: Variant in catalog:
		by_id[String((relic as Dictionary)["id"])] = relic
	var cap: int = RunSession.relic_cap if RunSession.relic_cap > 0 else RelicConfig.max_owned()
	return {
		"enabled": RelicConfig.enabled(), "max_owned": cap, "offer_count": RelicConfig.offer_count(), "act": STRAIGHT_RUN_ACT,
		"catalog": catalog, "by_id": by_id, "weights": RelicConfig.tier_weights_for_act(STRAIGHT_RUN_ACT),
		"ui": (RunConfig.ui().get("relic", {}) as Dictionary),
	}


static func enabled(ctx: Dictionary) -> bool:
	return ctx.has("relics") and bool((ctx["relics"] as Dictionary).get("enabled", false))


## The seeded stream of one room's relic offer: the same run seed and room always give the same offer.
static func offer_rng(run_seed: int, room_index: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = (run_seed * 7919 + room_index * 104729 + 31) & RunState.SEED_LIMIT
	return rng


## Opens the choice that follows a room: a relic offer after an elite or relic room when one is eligible, else exactly what
## RunChoices.open_for_room opens (a card reward, the rest menu, nothing). Returns the pending value.
static func open_for_room(state: RunState, room_type: String, is_last_room: bool, ctx: Dictionary) -> String:
	if is_last_room or not enabled(ctx) or not SOURCE_BY_ROOM.has(room_type):
		# A map's relic stage with relics switched off has nothing to offer: it gives a card offer like a combat room (the straight run never makes one then).
		return RunChoices.open_for_room(state, "combat" if room_type == RunConfig.RELIC_ROOM and not is_last_room and not enabled(ctx) else room_type, is_last_room, ctx)
	var relics: Dictionary = ctx["relics"]
	var pools: Array[String] = []
	for pool_id: Variant in (ctx.get("pools", []) as Array):
		pools.append(String(pool_id))
	var ids: Array[String] = []
	if not RunSession.forced_relic_offer.is_empty():
		ids = RunSession.forced_relic_offer.duplicate()  # --relic-offer (capture tooling): used by this one offer only
		RunSession.forced_relic_offer = []
	else:
		var weights: Dictionary = relics["weights"]
		var chest_weights: Dictionary = RunNodes.weights_for_current_room(state, ctx)  # a map's relic stage: its chest size sets the tier odds
		if not chest_weights.is_empty():
			weights = chest_weights
		ids = RelicOffer.offer(String(SOURCE_BY_ROOM[room_type]), int(relics["offer_count"]), offer_rng(state.seed_value, state.room_index),
				weights, state.relics, state.relics_given_up, pools, relics["catalog"])
	state.pending = RunState.PENDING_NONE
	state.offer = []
	state.relic_incoming = ""
	if ids.is_empty():
		# Nothing left to offer: the source gives its card offer instead (the relic room acts like a combat room for that).
		return RunChoices.open_for_room(state, "combat" if room_type == "relic_room" else room_type, false, ctx)
	state.offer = ids
	state.pending = RunState.PENDING_RELIC
	return state.pending


# --- display data -------------------------------------------------------------------------------

## One relic as the UI draws it: {relic_id, name, tier, tier_name, pool, pool_name, rule_text, flavor, keywords, boss, giveable}.
## An id the data no longer has still gives a usable entry (a save must not trap the player).
static func display(relic_id: String, ctx: Dictionary) -> Dictionary:
	var relics: Dictionary = ctx.get("relics", {})
	var relic: Dictionary = (relics.get("by_id", {}) as Dictionary).get(relic_id, {})
	var ui: Dictionary = relics.get("ui", {})
	var tier: String = String(relic.get("rarity", ""))
	var pool: String = String(relic.get("pool", ""))
	var pool_def: Dictionary = (ctx.get("pool_defs", {}) as Dictionary).get(pool, {})
	var keywords: Array[String] = []
	for keyword: Variant in (relic.get("keywords", []) as Array):
		keywords.append(String(keyword))
	return {
		"relic_id": relic_id,
		"name": String(relic.get("name", relic_id)),
		"tier": tier,
		"tier_name": String((ui.get("tier_names", {}) as Dictionary).get(tier, tier)),
		"pool": pool,
		"pool_name": String(pool_def.get("display_name", pool)),
		"rule_text": String(relic.get("rule_text", "")),
		"flavor": String(relic.get("flavor_text", "")),
		"keywords": keywords,
		"boss": tier == RelicOffer.BOSS_RARITY,
		"giveable": relic.is_empty() or RelicOffer.can_give_up(relic),
	}


## The relics the run holds (in the order taken), as display dictionaries.
static func owned_display(state: RunState, ctx: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for relic_id: String in state.relics:
		result.append(display(relic_id, ctx))
	return result


## The relics given up this run, as display dictionaries.
static func given_up_display(state: RunState, ctx: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for relic_id: String in state.relics_given_up:
		result.append(display(relic_id, ctx))
	return result


## The owned relics the player may give up (boss-tier ones may not), in the order owned, as ids.
static func giveable_ids(state: RunState, ctx: Dictionary) -> Array[String]:
	var catalog: Array = (ctx.get("relics", {}) as Dictionary).get("catalog", [])
	return RelicOffer.giveable(state.relics, catalog)


static func max_owned(ctx: Dictionary) -> int:
	return int((ctx.get("relics", {}) as Dictionary).get("max_owned", 20))


## True when taking one more relic now needs a give-up first.
static func needs_swap(state: RunState, ctx: Dictionary) -> bool:
	return RelicOffer.needs_swap(state.relics.size(), max_owned(ctx))


# --- the choice model ---------------------------------------------------------------------------

## Title and line of the open relic choice, from `ui.relic`.
static func title_and_line(state: RunState, ctx: Dictionary, room_type: String = "") -> Dictionary:
	var ui: Dictionary = (ctx.get("relics", {}) as Dictionary).get("ui", {})
	if state.pending == RunState.PENDING_RELIC_SWAP:
		var incoming: Dictionary = display(state.relic_incoming, ctx)
		var line_key: String = "swap_line_one" if (state.relics.size() == 1 and ui.has("swap_line_one")) else "swap_line"  # singular text for a cap of 1
		return {"title": String(ui.get("swap_title", "")), "line": String(ui.get(line_key, "")) % [state.relics.size(), String(incoming["name"])]}
	if room_type == "relic_room":
		return {"title": String(ui.get("room_title", "")), "line": String(ui.get("room_line", ""))}
	return {"title": String(ui.get("title", "")), "line": String(ui.get("line", ""))}


static func options(state: RunState, ctx: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ui: Dictionary = (ctx.get("relics", {}) as Dictionary).get("ui", {})
	match state.pending:
		RunState.PENDING_RELIC:
			for relic_id: String in state.offer:
				var option: Dictionary = relic_option(OPTION_RELIC + ":" + relic_id, OPTION_RELIC, relic_id, ctx)
				option["needs_swap"] = needs_swap(state, ctx)
				out.append(option)
			var skip: Dictionary = RunChoices.blank_option(OPTION_SKIP, OPTION_SKIP)
			skip["label"] = String(ui.get("skip_label", ""))
			skip["detail"] = String(ui.get("skip_detail", ""))
			out.append(skip)
		RunState.PENDING_RELIC_SWAP:
			for relic_id: String in giveable_ids(state, ctx):
				var option: Dictionary = relic_option(OPTION_GIVEUP + ":" + relic_id, OPTION_GIVEUP, relic_id, ctx)
				out.append(option)
			var cancel: Dictionary = RunChoices.blank_option(OPTION_CANCEL, "back")
			cancel["label"] = String(ui.get("cancel_label", ""))
			out.append(cancel)
	return out


## A relic option: the usual option keys (label = name, detail = rule text) plus the keys of `display`, and `needs_swap`.
static func relic_option(option_id: String, kind: String, relic_id: String, ctx: Dictionary) -> Dictionary:
	var shown: Dictionary = display(relic_id, ctx)
	var option: Dictionary = RunChoices.blank_option(option_id, kind)
	option["label"] = String(shown["name"])
	option["detail"] = String(shown["rule_text"])
	option["flavor"] = String(shown["flavor"])
	for key: Variant in shown.keys():
		option[key] = shown[key]
	option["needs_swap"] = false
	return option


## Extra model keys for a relic choice: `relic_choice` ("offer" or "giveup"), the owned and given-up lists, the cap, and in the
## give-up step the relic being taken (`incoming`) and the giveable list (display dictionaries).
static func model_extras(state: RunState, ctx: Dictionary) -> Dictionary:
	var swapping: bool = state.pending == RunState.PENDING_RELIC_SWAP
	var extras: Dictionary = {
		"relic_choice": "giveup" if swapping else "offer",
		"relics_owned": owned_display(state, ctx),
		"relics_given_up": given_up_display(state, ctx),
		"relic_max_owned": max_owned(ctx),
		"incoming": display(state.relic_incoming, ctx) if swapping else {},
		"giveable": [] as Array[Dictionary],
	}
	if swapping:
		var list: Array[Dictionary] = []
		for relic_id: String in giveable_ids(state, ctx):
			list.append(display(relic_id, ctx))
		extras["giveable"] = list
	return extras


# --- resolving ----------------------------------------------------------------------------------

## Resolves one option of a relic choice. Same result dict as RunChoices.apply (`kind`: "relic_pick", "relic_swap",
## "relic_skip", "relic_cancel"; `card_id` is empty, `relic_id` names the relic taken). `gave_up` names the relic given up.
static func apply(state: RunState, option_id: String, ctx: Dictionary) -> Dictionary:
	var result: Dictionary = RunChoices.blank_result()
	var found: Dictionary = {}
	for option: Dictionary in options(state, ctx):
		if String(option["id"]) == option_id:
			found = option
			break
	if found.is_empty():
		result["reason"] = "no such option '%s' in the %s choice" % [option_id, state.pending]
		return result
	var relic_id: String = String(found.get("relic_id", ""))
	match String(found["kind"]):
		OPTION_RELIC:
			if needs_swap(state, ctx):
				if giveable_ids(state, ctx).is_empty():
					var ui: Dictionary = (ctx["relics"] as Dictionary).get("ui", {})
					result["reason"] = String(ui.get("none_giveable", ""))
					return result
				state.pending = RunState.PENDING_RELIC_SWAP
				state.relic_incoming = relic_id
				result["kind"] = "relic_swap_open"
				result["relic_id"] = relic_id
			else:
				state.add_relic(relic_id)
				state.log_choice("relic", relic_id)
				RunChoices.close(state)
				result["kind"] = "relic_pick"
				result["relic_id"] = relic_id
				result["finished"] = true
		OPTION_SKIP:
			state.log_choice("relic_skip")
			RunChoices.close(state)
			result["kind"] = "relic_skip"
			result["finished"] = true
		OPTION_GIVEUP:
			var incoming: String = state.relic_incoming
			state.give_up_relic(relic_id)
			state.add_relic(incoming)
			state.log_choice("relic_swap", incoming)
			RunChoices.close(state)
			result["kind"] = "relic_swap"
			result["relic_id"] = incoming
			result["gave_up"] = relic_id
			result["finished"] = true
		"back":
			state.pending = RunState.PENDING_RELIC
			state.relic_incoming = ""
			result["kind"] = "relic_cancel"
	result["ok"] = true
	return result
