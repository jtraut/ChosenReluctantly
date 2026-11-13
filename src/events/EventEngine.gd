class_name EventEngine
extends RefCounted
## The event half of a map run's flow (MAP4 sitting B1, BUILD_DEPTH 13). Pure and static over a RunState and the same context Dictionary RunChoices uses
## (its "events" entry, see `shipped_context`), so the draw, the requirements, the generated cost lines and every outcome are testable without a scene.
##
## An event node is a room with no fight. Entering it draws one event (`draw`) and opens the choice `RunState.PENDING_EVENT`: one option per choice of the event,
## each carrying the cost and gain lines generated from its outcomes. Confirming a choice runs its outcomes in list order. `gain_relic` opens an ordinary relic
## offer (RunState.PENDING_RELIC with offer_rarity "event" or "event_noskip"); the outcomes after it wait in `RunState.event_queue` and run when that offer is
## answered (`resume`, called by RunChoices.apply). B1 executes the outcomes in IMPLEMENTED; the others are valid data but are skipped loudly until B2 and C.
##
## Option ids: "event_choice:<index>" (kind "event_choice"). Besides the usual option keys each option has `lines` (the generated text lines),
## `outcome_types` (every outcome type it contains, chance branches included, so a bot never reads event files) and `has_requires`.
## Result kind of `apply`: "event_choice"; `finished` is false when a relic offer was opened. A result sets `event_state_changed` when HP, max HP or gold moved
## (RunController then pushes the state to the live player).

const OPTION_CHOICE := "event_choice"
const IMPLEMENTED: Array[String] = ["lose_hp", "lose_max_hp", "heal", "gain_gold", "lose_gold", "gain_relic"]
const DEFAULT_MIN_MAX_HP := 10
## The relic source an event offer's normal slots draw from (the generic "pick a relic" pool); the reserved slot draws from sources exactly ["event"].
const NORMAL_SOURCE := "relic_room"
const EVENT_SOURCE := "event"
const DRAW_SALT := 0x3E7E47
const OFFER_SALT := 0x3E7


## The event part of a RunChoices context from the shipped data.
static func shipped_context() -> Dictionary:
	var block: Dictionary = RunConfig.get_config().get("events", {})
	return {
		"catalog": EventDatabase.catalog(),
		"min_max_hp": int(block.get("min_max_hp", DEFAULT_MIN_MAX_HP)),
		"ui": (RunConfig.ui().get("event", {}) as Dictionary),
	}


static func owns(pending: String) -> bool:
	return pending == RunState.PENDING_EVENT


## True while the open relic choice (the offer or its give-up step) is an event's relic offer.
static func is_event_offer(state: RunState) -> bool:
	return state.has_relic_choice() and [RunState.OFFER_EVENT, RunState.OFFER_EVENT_NOSKIP].has(state.offer_rarity)


static func catalog_of(ctx: Dictionary) -> Dictionary:
	return (ctx.get("events", {}) as Dictionary).get("catalog", {})


static func _ui(ctx: Dictionary) -> Dictionary:
	return (ctx.get("events", {}) as Dictionary).get("ui", {})


static func min_max_hp(ctx: Dictionary) -> int:
	return int((ctx.get("events", {}) as Dictionary).get("min_max_hp", DEFAULT_MIN_MAX_HP))


## The event the run is on ({} when none).
static func event_of(state: RunState, ctx: Dictionary) -> Dictionary:
	return catalog_of(ctx).get(state.event_id, {})


# --- the draw -----------------------------------------------------------------------------------

## The seeded stream of one event node's draw: the run seed and the room position, so the same node always draws the same event (a resume shows it again).
static func draw_rng(state: RunState) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = ((state.seed_value & RunState.SEED_LIMIT) * 6151 + state.stream_index() * 104729 + DRAW_SALT) & RunState.SEED_LIMIT
	return rng


## The ids of the events whose `acts` include the run's current act, sorted.
static func eligible_ids(state: RunState, ctx: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	var catalog: Dictionary = catalog_of(ctx)
	for key: Variant in catalog.keys():
		for act: Variant in ((catalog[key] as Dictionary).get("acts", []) as Array):
			if int(act) == state.act:
				ids.append(String(key))
				break
	ids.sort()
	return ids


## Draws one event for the current node: `RunSession.forced_event` (`--event=<id>`, used once) if set, else a weighted pick among the eligible events this run has
## not met yet, else (all met) among all eligible ones. Records the event as seen. "" (after a push_error) when nothing is eligible.
static func draw(state: RunState, ctx: Dictionary) -> String:
	var catalog: Dictionary = catalog_of(ctx)
	var picked: String = ""
	if RunSession.forced_event != "":
		var forced: String = RunSession.forced_event
		RunSession.forced_event = ""
		if catalog.has(forced):
			picked = forced
		else:
			push_error("EventEngine: --event=%s is not an event; drawing normally" % forced)
	if picked == "":
		var ids: Array[String] = eligible_ids(state, ctx)
		if ids.is_empty():
			push_error("EventEngine: no event is eligible in act %d; the event room ends with no choice" % state.act)
			return ""
		var fresh: Array[String] = []
		for id: String in ids:
			if not state.events_seen.has(id):
				fresh.append(id)
		var pool: Array[String] = fresh if not fresh.is_empty() else ids
		picked = _weighted(pool, catalog, draw_rng(state))
	if not state.events_seen.has(picked):
		state.events_seen.append(picked)
	return picked


static func _weighted(pool: Array[String], catalog: Dictionary, rng: RandomNumberGenerator) -> String:
	var total: float = 0.0
	for id: String in pool:
		total += float((catalog[id] as Dictionary).get("weight", 1.0))
	var roll: float = rng.randf() * total
	for id: String in pool:
		roll -= float((catalog[id] as Dictionary).get("weight", 1.0))
		if roll < 0.0:
			return id
	return pool[pool.size() - 1]


## Opens the event choice of the node the run is in. Returns the pending value (PENDING_NONE when no event could be drawn, so the room just ends).
static func open_for_room(state: RunState, ctx: Dictionary) -> String:
	state.event_queue = []
	state.event_id = ""
	if not ctx.has("events"):
		return state.pending
	var picked: String = draw(state, ctx)
	if picked == "":
		return state.pending
	state.event_id = picked
	state.offer = []
	state.offer_rarity = ""
	state.relic_incoming = ""
	state.pending = RunState.PENDING_EVENT
	return state.pending


# --- requirements -------------------------------------------------------------------------------

## "" when the requirement is met (or there is none), else the words for why not. B1 knows `gold_at_least`; the other two names are valid data that read
## as unmet ("Not available yet") until their sitting.
static func requirement_reason(requires: Variant, state: RunState, ctx: Dictionary) -> String:
	if typeof(requires) != TYPE_DICTIONARY or (requires as Dictionary).is_empty():
		return ""
	var reasons: Dictionary = _ui(ctx).get("reasons", {})
	if (requires as Dictionary).has("gold_at_least"):
		var needed: int = int((requires as Dictionary)["gold_at_least"])
		if state.gold >= needed:
			return ""
		return String(reasons.get("gold", "Needs %d gold (you have %d)")) % [needed, state.gold]
	return String(reasons.get("unsupported", "Not available yet"))


# --- text ---------------------------------------------------------------------------------------

## Whole HP an HP fraction is worth for this character (at least 1). The shown line and the applied change both come from here.
static func hp_amount(fraction: float, base_hp: float) -> int:
	return maxi(roundi(fraction * base_hp), 1)


## The generated lines for a list of outcomes, in order (the leave line when the list is empty).
static func lines_for(outcomes: Array, state: RunState, ctx: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	for outcome: Variant in outcomes:
		var text: String = _line(outcome as Dictionary, state, ctx)
		if not text.is_empty():
			lines.append(text)
	if lines.is_empty():
		lines.append(String(_ui(ctx).get("leave_line", "")))
	return lines


static func _line(outcome: Dictionary, state: RunState, ctx: Dictionary) -> String:
	var texts: Dictionary = _ui(ctx).get("lines", {})
	match String(outcome["type"]):
		"lose_hp":
			return String(texts.get("lose_hp", "")) % hp_amount(float(outcome["fraction"]), state.max_hp)
		"lose_max_hp":
			return String(texts.get("lose_max_hp", "")) % hp_amount(float(outcome["fraction"]), state.max_hp)
		"heal":
			return String(texts.get("heal", "")) % hp_amount(float(outcome["fraction"]), state.max_hp)
		"gain_gold":
			return String(texts.get("gain_gold", "")) % int(outcome["amount"])
		"lose_gold":
			return String(texts.get("lose_gold", "")) % int(outcome["amount"])
		"gain_relic":
			return _relic_line(outcome, ctx)
		"gain_curse":
			if outcome.has("id"):
				var curse_name: String = String(((ctx.get("by_id", {}) as Dictionary).get(String(outcome["id"]), {}) as Dictionary).get("name", outcome["id"]))
				return String(texts.get("gain_curse", "")) % curse_name
			return String(texts.get("gain_curse_random", ""))
		"remove_curse":
			return String(texts.get("remove_curse", ""))
		"remove_card":
			return String(texts.get("remove_card", ""))
		"sacrifice_relic":
			return String(texts.get("sacrifice_" + String(outcome["select"]), ""))
		"start_fight":
			return String(texts.get("start_fight", ""))
		"chance":
			var win: String = _lowered(", ".join(lines_for(outcome["win"] as Array, state, ctx)) if not (outcome["win"] as Array).is_empty() else "")
			var text: String = String(texts.get("chance", "")) % [roundi(float(outcome["p"]) * 100.0), win]
			if not (outcome["lose"] as Array).is_empty():
				text += ", " + String(texts.get("chance_otherwise", "")) % _lowered(", ".join(lines_for(outcome["lose"] as Array, state, ctx)))
			return text
		"stat_mod":
			var amount_text: String = ""
			if String(outcome["modifier_type"]) == StatModifiers.MULTIPLICATIVE:
				amount_text = ("+" if float(outcome["value"]) >= 0.0 else "") + "%d%%" % roundi(float(outcome["value"]) * 100.0)
			else:
				amount_text = ("+" if float(outcome["value"]) >= 0.0 else "") + str(outcome["value"])
			return String(texts.get("stat_mod", "")) % [String(outcome["stat"]), amount_text]
		"merchant_discount":
			return String(texts.get("merchant_discount", "")) % roundi(float(outcome["fraction"]) * 100.0)
	return ""


static func _relic_line(outcome: Dictionary, ctx: Dictionary) -> String:
	var texts: Dictionary = _ui(ctx).get("lines", {})
	var count: int = int(outcome.get("count", int((ctx.get("relics", {}) as Dictionary).get("offer_count", 3))))
	var tier: Variant = outcome["tier"]
	var line: String = ""
	if typeof(tier) == TYPE_STRING:
		match String(tier):
			"act":
				line = String(texts.get("gain_relic_act", "")) % count
			"next_act":
				line = String(texts.get("gain_relic_next_act", "")) % count
			_:
				line = String(texts.get("gain_relic_plus_one", "")) % count
	else:
		line = String(texts.get("gain_relic_tier", "")) % [int(tier), count]
	if not bool(outcome.get("skip", true)):
		line += " (%s)" % String(texts.get("no_skip", ""))
	return line


static func _lowered(text: String) -> String:
	return text if text.is_empty() else text.substr(0, 1).to_lower() + text.substr(1)


## Every outcome type in a list, chance branches included.
static func outcome_types(outcomes: Array) -> Array[String]:
	var types: Array[String] = []
	for outcome: Variant in outcomes:
		var type_id: String = String((outcome as Dictionary)["type"])
		if not types.has(type_id):
			types.append(type_id)
		if type_id == "chance":
			for branch: String in ["win", "lose"]:
				for inner: String in outcome_types((outcome as Dictionary)[branch] as Array):
					if not types.has(inner):
						types.append(inner)
	return types


static func title_and_line(state: RunState, ctx: Dictionary) -> Dictionary:
	var event: Dictionary = event_of(state, ctx)
	return {"title": String(event.get("name", state.event_id)), "line": String(event.get("flavor", ""))}


# --- options ------------------------------------------------------------------------------------

static func options(state: RunState, ctx: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ui: Dictionary = _ui(ctx)
	var choices: Array = event_of(state, ctx).get("choices", [])
	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var outcomes: Array = choice.get("outcomes", [])
		var option: Dictionary = RunChoices.blank_option("%s:%d" % [OPTION_CHOICE, i], OPTION_CHOICE)
		var lines: Array[String] = lines_for(outcomes, state, ctx)
		option["label"] = String(choice["label"])
		option["lines"] = lines
		option["detail"] = String(ui.get("line_join", "\n")).join(lines)
		option["outcome_types"] = outcome_types(outcomes)
		option["has_requires"] = choice.has("requires")
		var reason: String = requirement_reason(choice.get("requires"), state, ctx)
		if not reason.is_empty():
			option["enabled"] = false
			option["reason"] = reason
		out.append(option)
	return out


## Extra model keys for the event choice: the event itself and the numbers its lines were made from.
static func model_extras(state: RunState, ctx: Dictionary) -> Dictionary:
	var event: Dictionary = event_of(state, ctx)
	return {
		"event": {"id": state.event_id, "name": String(event.get("name", state.event_id)), "flavor": String(event.get("flavor", ""))},
		"gold": state.gold, "hp": state.hp, "max_hp": state.max_hp,
	}


# --- resolving ----------------------------------------------------------------------------------

## Confirms one choice of the open event. Same result dict as RunChoices.apply (`kind` "event_choice"). A disabled or unknown option changes nothing.
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
	if not bool(found["enabled"]):
		result["reason"] = String(found["reason"])
		return result
	var index: int = option_id.get_slice(":", 1).to_int()
	var choice: Dictionary = (event_of(state, ctx)["choices"] as Array)[index]
	state.log_choice("event", state.event_id, float(index))
	state.event_queue = []
	var outcomes: Array = []
	for outcome: Variant in (choice.get("outcomes", []) as Array):
		outcomes.append(EventSchema.normalize_outcome(outcome as Dictionary))
	result["kind"] = "event_choice"
	result["ok"] = true
	_run(state, ctx, outcomes, result)
	return result


## Called by RunChoices.apply when an event's relic offer was just answered (a pick, a swap or a skip): runs the outcomes that waited for it.
static func resume(state: RunState, ctx: Dictionary, result: Dictionary) -> void:
	var waiting: Array = state.event_queue.duplicate(true)
	state.event_queue = []
	_run(state, ctx, waiting, result)


## Runs `outcomes` in order. Stops at a relic offer (the rest waits in the queue, `finished` false); otherwise ends the event (`finished` true).
static func _run(state: RunState, ctx: Dictionary, outcomes: Array, result: Dictionary) -> void:
	var queue: Array = outcomes.duplicate()
	while not queue.is_empty():
		var outcome: Dictionary = queue.pop_front()
		var type_id: String = String(outcome["type"])
		if not IMPLEMENTED.has(type_id):
			push_error("EventEngine: outcome '%s' is not built yet (MAP4 sitting B2 or C); skipped" % type_id)
			continue
		match type_id:
			"lose_hp":
				var loss: float = float(hp_amount(float(outcome["fraction"]), state.max_hp))
				state.hp = minf(state.hp, maxf(state.hp - loss, 1.0))  # never below 1 HP (and never a "loss" that raises HP)
				result["event_state_changed"] = true
			"lose_max_hp":
				var cut: float = float(hp_amount(float(outcome["fraction"]), state.max_hp))
				state.max_hp = minf(state.max_hp, maxf(state.max_hp - cut, float(min_max_hp(ctx))))
				state.hp = minf(state.hp, state.max_hp)
				result["event_state_changed"] = true
			"heal":
				state.hp = minf(state.hp + float(hp_amount(float(outcome["fraction"]), state.max_hp)), state.max_hp)
				result["event_state_changed"] = true
			"gain_gold":
				state.gold += int(outcome["amount"])
				result["event_state_changed"] = true
			"lose_gold":
				state.gold = maxi(state.gold - int(outcome["amount"]), 0)
				result["event_state_changed"] = true
			"gain_relic":
				var rest: Array[Dictionary] = []
				for later: Variant in queue:
					rest.append(later as Dictionary)
				if _open_relic_offer(state, ctx, outcome, rest):
					result["finished"] = false
					return
	finish(state)
	result["finished"] = true


## Ends the event: no event, no waiting outcomes, no open choice.
static func finish(state: RunState) -> void:
	state.event_id = ""
	state.event_queue = []
	RunChoices.close(state)


# --- relic offers -------------------------------------------------------------------------------

static func is_event_only(relic: Variant) -> bool:
	var sources: Array = (relic as Dictionary).get("sources", [])
	return sources.size() == 1 and String(sources[0]) == EVENT_SOURCE


## Opens a relic offer for a `gain_relic` outcome, parking `rest` (the outcomes after it) in the queue. False (nothing opened) when relics are off or none is
## eligible at any tier it may fall to.
static func _open_relic_offer(state: RunState, ctx: Dictionary, outcome: Dictionary, rest: Array[Dictionary]) -> bool:
	if not RunRelics.enabled(ctx):
		return false
	var ids: Array[String] = offer_ids(state, ctx, outcome, rest.size())
	if ids.is_empty():
		return false
	state.event_queue = rest
	state.offer = ids
	state.relic_incoming = ""
	state.offer_rarity = RunState.OFFER_EVENT if bool(outcome.get("skip", true)) else RunState.OFFER_EVENT_NOSKIP
	state.pending = RunState.PENDING_RELIC
	return true


## The relic ids a `gain_relic` outcome offers. Tier modes: `act` (this act's odds), `next_act` (the next act's row; act 3 uses its own, as the table has no
## act 4), a whole number 1-3 (that tier only; when nothing is eligible it falls to the tier below, per offer). One slot is reserved for an event-only relic
## while one is eligible (and the offer has at least 2 slots), placed at a seeded position. `step` (the outcomes still waiting) keeps two offers in one event apart.
static func offer_ids(state: RunState, ctx: Dictionary, outcome: Dictionary, step: int = 0) -> Array[String]:
	var relics: Dictionary = ctx["relics"]
	var count: int = int(outcome.get("count", int(relics["offer_count"])))
	var rows: Array[Dictionary] = []
	var tier: Variant = outcome["tier"]
	if typeof(tier) == TYPE_STRING:
		match String(tier):
			"act":
				rows.append(RunRelics.weights_for(state, relics, 0))
			"next_act":
				rows.append(RunRelics.weights_for(state, relics, 1))
			_:
				push_error("EventEngine: gain_relic tier '%s' is not built yet (MAP4 sitting B2); no offer" % String(tier))
				return [] as Array[String]
	else:
		var tier_keys: Array = RelicConfig.TIER_KEYS
		for level in range(int(tier), 0, -1):
			var row: Dictionary = {}
			for key: Variant in tier_keys:
				row[String(key)] = 0.0
			row[String(tier_keys[level - 1])] = 1.0
			rows.append(row)
	var rng: RandomNumberGenerator = RunRelics.offer_rng(state.seed_value ^ OFFER_SALT, state.stream_index() + 7919 * step)
	for row: Dictionary in rows:
		var ids: Array[String] = _offer_from(state, ctx, row, count, rng)
		if not ids.is_empty():
			return ids
	return [] as Array[String]


static func _offer_from(state: RunState, ctx: Dictionary, weights: Dictionary, count: int, rng: RandomNumberGenerator) -> Array[String]:
	var relics: Dictionary = ctx["relics"]
	var pools: Array[String] = []
	for pool_id: Variant in (ctx.get("pools", []) as Array):
		pools.append(String(pool_id))
	var event_catalog: Array = []
	var normal_catalog: Array = []
	for entry: Variant in (relics["catalog"] as Array):
		if is_event_only(entry):
			event_catalog.append(entry)
		else:
			normal_catalog.append(entry)
	var reserved: Array[String] = []
	if count >= 2:
		reserved = RelicOffer.offer(EVENT_SOURCE, 1, rng, weights, state.relics, state.relics_given_up, pools, event_catalog)
	var excluded: Array[String] = state.relics.duplicate()
	excluded.append_array(reserved)
	var ids: Array[String] = RelicOffer.offer(NORMAL_SOURCE, count - reserved.size(), rng, weights, excluded, state.relics_given_up, pools, normal_catalog)
	for reserved_id: String in reserved:
		ids.insert(rng.randi_range(0, ids.size()), reserved_id)
	return ids
