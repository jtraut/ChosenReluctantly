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
## MAP3-B: the act-end mini-boss draws from the elite source until MAP3b adds the boss-tier offer (DECISIONS "MAP3 split").
const SOURCE_BY_ROOM: Dictionary = {"elite": "elite", "relic_room": "relic_room", "mini_boss": "elite"}
const OPTION_RELIC := "relic"
const OPTION_SKIP := "relic_skip"
const OPTION_GIVEUP := "giveup"
const OPTION_CANCEL := "giveup_cancel"
## MAP4-B2: the one confirm of a multi-give-up step (a `sacrifice_cost` relic): kind "giveup_confirm". Picking a relic there toggles it; nothing is given up until this.
const OPTION_CONFIRM := "giveup_confirm"
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
		"catalog": catalog, "by_id": by_id, "weights": RelicConfig.tier_weights_for_act(STRAIGHT_RUN_ACT), "tier_weights": RelicConfig.block().get("tier_weights", {}),
		"ui": (RunConfig.ui().get("relic", {}) as Dictionary),
	}


## The tier weights an offer in the run's current act draws from (MAP3-B): the context's own row in act 1 (and for a context with no per-act table), else the
## act's row of `tier_weights`. `act_offset` 1 is the mini-boss's next-act odds.
static func weights_for(state: RunState, relics: Dictionary, act_offset: int = 0) -> Dictionary:
	var act_number: int = state.act + act_offset
	if act_number <= STRAIGHT_RUN_ACT or not relics.has("tier_weights"):
		return relics["weights"]
	var row: Dictionary = RelicConfig.tier_weights_for_act(act_number, relics["tier_weights"])
	return row if not row.is_empty() else relics["weights"]


## True while the open relic choice (the offer or its give-up step) is the mini-boss's boss-relic offer.
static func is_boss_offer(state: RunState) -> bool:
	return state.has_relic_choice() and state.offer_rarity == RelicOffer.BOSS_RARITY


## True while the open relic choice has no skip: the mini-boss's boss-relic offer and an event offer the player has paid for (MAP4-B1).
static func is_noskip_offer(state: RunState) -> bool:
	return is_boss_offer(state) or (state.has_relic_choice() and state.offer_rarity == RunState.OFFER_EVENT_NOSKIP)


static func enabled(ctx: Dictionary) -> bool:
	return ctx.has("relics") and bool((ctx["relics"] as Dictionary).get("enabled", false))


## The seeded stream of one room's relic offer: the same run seed and room always give the same offer.
## `room_index` is the run's `stream_index` (the room index in act 1, so a one-act run is unchanged).
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
	var boss_offer: bool = false
	if room_type == "mini_boss":
		# MAP3b: the act-end mini-boss offers boss-tier relics: pick 1 of `offer_count`, no skip, drawn uniformly among the unowned boss relics of
		# the run's pools. With none left (or none in the data yet) it falls back to the interim elite-tier offer below, skip allowed.
		var boss_rarities: Array[String] = [RelicOffer.BOSS_RARITY]
		ids = RelicOffer.offer(RelicSchema.BOSS_SOURCE, int(relics["offer_count"]), offer_rng(state.seed_value, state.stream_index()), {}, state.relics,
				state.relics_given_up, pools, relics["catalog"], boss_rarities, giveable_count(state, ctx))
		boss_offer = not ids.is_empty()
	if not RunSession.forced_relic_offer.is_empty():
		# --relic-offer (capture tooling): replaces the ids for this one offer only. The mini-boss branch above still ran, so a forced offer
		# at a mini-boss keeps the boss-relic rules (no skip, boss title): `boss_offer` stays as that branch set it.
		ids = RunSession.forced_relic_offer.duplicate()
		RunSession.forced_relic_offer = []
	elif not ids.is_empty():
		pass
	else:
		var weights: Dictionary = weights_for(state, relics, 1 if room_type == "mini_boss" else 0)
		var chest_weights: Dictionary = RunNodes.weights_for_current_room(state, ctx)  # a map's relic stage: its chest size sets the tier odds
		if not chest_weights.is_empty():
			weights = chest_weights
		ids = RelicOffer.offer(String(SOURCE_BY_ROOM[room_type]), int(relics["offer_count"]), offer_rng(state.seed_value, state.stream_index()),
				weights, state.relics, state.relics_given_up, pools, relics["catalog"], RelicOffer.DEFAULT_RARITIES, giveable_count(state, ctx))
	state.pending = RunState.PENDING_NONE
	state.offer = []
	state.relic_incoming = ""
	state.offer_rarity = ""
	if ids.is_empty():
		# Nothing left to offer: the source gives its card offer instead (the relic room acts like a combat room for that).
		return RunChoices.open_for_room(state, "combat" if room_type == "relic_room" else room_type, false, ctx)
	state.offer = ids
	state.offer_rarity = RelicOffer.BOSS_RARITY if boss_offer else ""
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
		"sacrifice_cost": int(relic.get("sacrifice_cost", 0)),
	}


## The run-long numbers relic modifiers can scale by (RelicSchema.RUN_STATS), from the RunState. RunController hands the same dictionary to its RelicManager.
static func run_stats(state: RunState) -> Dictionary:
	return {"gold_spent_merchant": state.gold_spent_merchant}


## BD3b-ux (MAP2 carry-over): what a relic whose modifier scales with a run stat (Liquidate Assets, per 50 gold spent) is worth right now, as a line
## ("Now: Damage +4%"). The value is RelicManager.scaled_value, the number the player's stats really hold, never recomputed; the words are the event
## stat names (ui.event.stat_names) and ui.relic.now_format. "" for a relic with no run-scaled modifier (its rule_text already says it all).
static func current_text(relic: Dictionary, stats: Dictionary, ctx: Dictionary) -> String:
	var format: String = String(((ctx.get("relics", {}) as Dictionary).get("ui", {}) as Dictionary).get("now_format", ""))
	if format == "" or not format.contains("%s"):
		return ""
	var parts: Array[String] = []
	for entry: Variant in (relic.get("modifiers", []) as Array):
		if typeof(entry) != TYPE_DICTIONARY or not (entry as Dictionary).has("per_run_stat"):
			continue
		var mod: Dictionary = entry
		parts.append(EventEngine.mod_text({"stat": mod["stat"], "modifier_type": mod["modifier_type"], "value": RelicManager.scaled_value(mod, stats)}, ctx))
	return format % ", ".join(PackedStringArray(parts)) if not parts.is_empty() else ""


## The relics the run holds (in the order taken), as display dictionaries. Each carries `now` (see current_text) when its numbers move with the run.
static func owned_display(state: RunState, ctx: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var stats: Dictionary = run_stats(state)
	for relic_id: String in state.relics:
		var shown: Dictionary = display(relic_id, ctx)
		var relic: Dictionary = ((ctx.get("relics", {}) as Dictionary).get("by_id", {}) as Dictionary).get(relic_id, {})
		shown["now"] = current_text(relic, stats, ctx)
		if String(shown["now"]) == "":
			shown["now"] = max_hp_text(state, relic_id, ctx)
		result.append(shown)
	return result


## HP1 readout (UX1c): what a max HP relic has given this run so far ("Now: +2 max HP"), from RunState.relic_max_hp (the amount RunMaxHp really added).
## "" for a relic that holds no boost (or before it has given any). Display only.
static func max_hp_text(state: RunState, relic_id: String, ctx: Dictionary) -> String:
	var ui: Dictionary = (ctx.get("relics", {}) as Dictionary).get("ui", {})
	var format: String = String(ui.get("now_format", ""))
	var amount_format: String = String(ui.get("max_hp_now", ""))
	if not state.relic_max_hp.has(relic_id) or format == "" or not format.contains("%s") or amount_format == "" or not amount_format.contains("%d"):
		return ""
	return format % (amount_format % roundi(float(state.relic_max_hp[relic_id])))


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


# --- sacrifice_cost (MAP4-B2, BUILD_DEPTH 13.5) ---------------------------------------------------

## How many relics taking this relic asks you to give up (0 = none): its `sacrifice_cost`.
static func cost_in_catalog(relic_id: String, catalog: Array) -> int:
	for entry: Variant in catalog:
		if String((entry as Dictionary).get("id", "")) == relic_id:
			return int((entry as Dictionary).get("sacrifice_cost", 0))
	return 0


static func cost_for(relic_id: String, ctx: Dictionary) -> int:
	var relic: Dictionary = ((ctx.get("relics", {}) as Dictionary).get("by_id", {}) as Dictionary).get(relic_id, {})
	return int(relic.get("sacrifice_cost", 0))


## How many owned relics may be given up now (the number a `sacrifice_cost` relic is checked against). -1 when the context has no relics, so nothing is filtered.
static func giveable_count(state: RunState, ctx: Dictionary) -> int:
	if not ctx.has("relics"):
		return -1
	return RelicOffer.giveable(state.relics, (ctx["relics"] as Dictionary).get("catalog", [])).size()


## True while the open give-up step belongs to a `sacrifice_cost` relic (pick all, then confirm once) rather than the plain cap swap.
static func is_sacrifice_step(state: RunState, ctx: Dictionary) -> bool:
	return state.pending == RunState.PENDING_RELIC_SWAP and cost_for(state.relic_incoming, ctx) > 0


## True when taking one more relic now needs a give-up first.
static func needs_swap(state: RunState, ctx: Dictionary) -> bool:
	return RelicOffer.needs_swap(state.relics.size(), max_owned(ctx))


# --- the choice model ---------------------------------------------------------------------------

## Title and line of the open relic choice, from `ui.relic`.
static func title_and_line(state: RunState, ctx: Dictionary, room_type: String = "") -> Dictionary:
	var ui: Dictionary = (ctx.get("relics", {}) as Dictionary).get("ui", {})
	if is_sacrifice_step(state, ctx):
		var cost: int = cost_for(state.relic_incoming, ctx)
		return {"title": String(ui.get("sacrifice_title", "")), "line": String(ui.get("sacrifice_line", "")) % [String(display(state.relic_incoming, ctx)["name"]), cost, state.sacrifice_picks.size(), cost]}
	if state.pending == RunState.PENDING_RELIC_SWAP:
		var incoming: Dictionary = display(state.relic_incoming, ctx)
		var line_key: String = "swap_line_one" if (state.relics.size() == 1 and ui.has("swap_line_one")) else "swap_line"  # singular text for a cap of 1
		return {"title": String(ui.get("swap_title", "")), "line": String(ui.get(line_key, "")) % [state.relics.size(), String(incoming["name"])]}
	if is_boss_offer(state) and ui.has("boss_title"):
		return {"title": String(ui.get("boss_title", "")), "line": String(ui.get("boss_line", ""))}
	if state.has_relic_choice() and state.offer_rarity == RunState.OFFER_DIG:
		var rest_ui: Dictionary = (ctx.get("ui", {}) as Dictionary).get("rest", {})
		return {"title": String(rest_ui.get("dig_title", ui.get("title", ""))), "line": String(rest_ui.get("dig_line", ui.get("line", "")))}
	if EventEngine.is_event_offer(state):
		var event_ui: Dictionary = (ctx.get("events", {}) as Dictionary).get("ui", {})
		return {"title": String(event_ui.get("relic_title", ui.get("title", ""))),
				"line": String(event_ui.get("relic_line_noskip" if is_noskip_offer(state) else "relic_line", ui.get("line", "")))}
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
				var cost: int = int(option["sacrifice_cost"])
				if cost > 0 and giveable_count(state, ctx) < cost:
					# A forced offer (or a relic given up since the offer was drawn) can leave a sacrifice relic nobody can pay for: greyed, with the reason.
					option["enabled"] = false
					option["reason"] = String(ui.get("sacrifice_short", "")) % cost
				elif option["needs_swap"] and cost == 0 and giveable_ids(state, ctx).is_empty():
					# At the cap with nothing that can be given up (only boss relics held): a pick would be refused, so the option is disabled
					# and the skip below is the way out. The bot (RelicPolicy) skips disabled options.
					option["enabled"] = false
					option["reason"] = String(ui.get("none_giveable", ""))
				out.append(option)
			# MAP3b: a boss-relic offer has no skip, except when nothing can be taken (at the cap with only boss relics held: a pick would be refused
			# for ever, so the screen could never close). Then the skip is the way out.
			if not is_noskip_offer(state) or not RelicOffer.can_take(state.relics, max_owned(ctx), (ctx.get("relics", {}) as Dictionary).get("catalog", [])):
				var skip: Dictionary = RunChoices.blank_option(OPTION_SKIP, OPTION_SKIP)
				skip["label"] = String(ui.get("skip_label", ""))
				skip["detail"] = String(ui.get("skip_detail", ""))
				out.append(skip)
		RunState.PENDING_RELIC_SWAP:
			var sacrifice: bool = is_sacrifice_step(state, ctx)
			var cost: int = cost_for(state.relic_incoming, ctx)
			for relic_id: String in giveable_ids(state, ctx):
				var option: Dictionary = relic_option(OPTION_GIVEUP + ":" + relic_id, OPTION_GIVEUP, relic_id, ctx)
				if sacrifice:
					option["selected"] = state.sacrifice_picks.has(relic_id)
					if not bool(option["selected"]) and state.sacrifice_picks.size() >= cost:
						option["enabled"] = false
						option["reason"] = String(ui.get("sacrifice_full", ""))
				out.append(option)
			if sacrifice:
				var confirm: Dictionary = RunChoices.blank_option(OPTION_CONFIRM, "giveup_confirm")
				confirm["label"] = String(ui.get("confirm_label", ""))
				if state.sacrifice_picks.size() != cost:
					confirm["enabled"] = false
					confirm["reason"] = String(ui.get("sacrifice_pick_more", "")) % (cost - state.sacrifice_picks.size())
				out.append(confirm)
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
	option["selected"] = false
	return option


## Extra model keys for a relic choice: `relic_choice` ("offer" or "giveup"), the owned and given-up lists, the cap, and in the
## give-up step the relic being taken (`incoming`) and the giveable list (display dictionaries).
static func model_extras(state: RunState, ctx: Dictionary) -> Dictionary:
	var swapping: bool = state.pending == RunState.PENDING_RELIC_SWAP
	var extras: Dictionary = {
		"relic_choice": "giveup" if swapping else "offer",
		"boss_offer": is_boss_offer(state),
			"event_offer": EventEngine.is_event_offer(state),
		"relics_owned": owned_display(state, ctx),
		"relics_given_up": given_up_display(state, ctx),
		"relic_max_owned": max_owned(ctx),
		"incoming": display(state.relic_incoming, ctx) if swapping else {},
		"giveable": [] as Array[Dictionary],
		"sacrifice_cost": cost_for(state.relic_incoming, ctx) if swapping else 0,
		"sacrifice_picks": state.sacrifice_picks.duplicate(),
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
			if not bool(found["enabled"]):
				result["reason"] = String(found["reason"])
				return result
			var take_cost: int = cost_for(relic_id, ctx)
			if take_cost > 0 or needs_swap(state, ctx):
				if giveable_ids(state, ctx).is_empty():
					var ui: Dictionary = (ctx["relics"] as Dictionary).get("ui", {})
					result["reason"] = String(ui.get("none_giveable", ""))
					return result
				state.sacrifice_picks = []
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
			if is_sacrifice_step(state, ctx):
				# MAP4-B2: a sacrifice relic's step toggles a pick; nothing is given up until the confirm.
				if not bool(found["enabled"]):
					result["reason"] = String(found["reason"])
					return result
				if state.sacrifice_picks.has(relic_id):
					state.sacrifice_picks.erase(relic_id)
				else:
					state.sacrifice_picks.append(relic_id)
				result["kind"] = "relic_giveup_pick"
				result["relic_id"] = incoming
			else:
				state.give_up_relic(relic_id)
				state.add_relic(incoming)
				state.log_choice("relic_swap", incoming)
				RunChoices.close(state)
				result["kind"] = "relic_swap"
				result["relic_id"] = incoming
				result["gave_up"] = relic_id
				result["finished"] = true
		OPTION_CONFIRM:
			if not bool(found["enabled"]):
				result["reason"] = String(found["reason"])
				return result
			var taken: String = state.relic_incoming
			var given: Array[String] = state.sacrifice_picks.duplicate()
			for sacrificed: String in given:
				state.give_up_relic(sacrificed)
			state.add_relic(taken)
			state.log_choice("relic_swap", taken)
			RunChoices.close(state)
			result["kind"] = "relic_swap"
			result["relic_id"] = taken
			result["gave_up"] = given[0] if not given.is_empty() else ""
			result["gave_up_all"] = given
			result["finished"] = true
		"back":
			state.pending = RunState.PENDING_RELIC
			state.relic_incoming = ""
			state.sacrifice_picks = []
			result["kind"] = "relic_cancel"
	result["ok"] = true
	return result
