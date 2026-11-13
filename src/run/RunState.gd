class_name RunState
extends RefCounted
## Everything a run carries from room to room (Milestone 3a): HP, deck as card ids, rejects left, the seed,
## the room index and the history of finished rooms. Nothing in here knows what a card does. It converts to
## and from a plain Dictionary (JSON-safe: only strings, whole numbers, floats, arrays), so a save or a
## loadout can reuse it later.
##
## Seeds stay below 2^31 so they survive a JSON round-trip, where every number comes back as a float.

const SEED_LIMIT := 2147483647
## The most acts a run may have (data/map.json `acts` is checked against this).
const MAX_ACTS := 9
const FORMAT_VERSION := 2

## `pending` values: no choice open, a card reward, the rest room menu, the rest room card-removal list.
const PENDING_NONE := ""
const PENDING_REWARD := "reward"
const PENDING_REST := "rest"
const PENDING_REST_REMOVE := "rest_remove"
## BD2-B: a relic offer (pick one or skip) and, at the relic cap, the "give one up" step for the relic being taken.
const PENDING_RELIC := "relic"
const PENDING_RELIC_SWAP := "relic_swap"
## MAP1-B: the pick-next-node choice of a map run (the map screen). Its options come from the map and the path, so it needs no `offer`.
const PENDING_NODE := "node"
## MAP2-B: a merchant visit (the shop screen), its card removal list, and the give-one-up step of a relic bought at the relic cap (`relic_incoming`
## holds the relic being bought). All three need the open `merchant_visit`.
const PENDING_MERCHANT := "merchant"
const PENDING_MERCHANT_REMOVE := "merchant_remove"
const PENDING_MERCHANT_SWAP := "merchant_swap"
const MERCHANT_PENDING: Array[String] = [PENDING_MERCHANT, PENDING_MERCHANT_REMOVE, PENDING_MERCHANT_SWAP]
## MAP4-B1: an event node's choice screen. It needs `event_id`. The relic offer an event choice opens is an ordinary PENDING_RELIC with offer_rarity
## "event" or "event_noskip" (see EventEngine), and the outcomes still to run after it wait in `event_queue`.
const PENDING_EVENT := "event"
## MAP4-B2: an event's "give up a relic" step (`sacrifice_relic` outcome). The outcome sits at the head of `event_queue` (so its params are saved and checked on load).
const PENDING_EVENT_SACRIFICE := "event_sacrifice"
## MAP4-C: an event's "pick a card to remove" step (`remove_card` / `remove_curse`). The outcome sits at the head of `event_queue`, as with the sacrifice.
const PENDING_EVENT_REMOVE := "event_remove"
const PENDING_VALUES: Array[String] = [PENDING_NONE, PENDING_REWARD, PENDING_REST, PENDING_REST_REMOVE, PENDING_RELIC, PENDING_RELIC_SWAP, PENDING_NODE,
		PENDING_MERCHANT, PENDING_MERCHANT_REMOVE, PENDING_MERCHANT_SWAP, PENDING_EVENT, PENDING_EVENT_SACRIFICE, PENDING_EVENT_REMOVE]
## `offer_rarity` values of an event's relic offer: skip allowed ("event") and no skip ("event_noskip", the player has paid for it).
const OFFER_EVENT := "event"
const OFFER_EVENT_NOSKIP := "event_noskip"
## MAP4-C: the relic offer of a rest's Dig (skip allowed; not a save boundary, since nothing was paid).
const OFFER_DIG := "dig"

var seed_value: int = 0
## The character (data/characters.json id) this run is played as (W1a). Fixed for the whole run.
var character_id: String = CharacterDatabase.DEFAULT_ID
var room_index: int = 0
## Player HP at the start of the room. -1 means "not set yet": the first room takes the player's own max.
var hp: float = -1.0
var max_hp: float = -1.0
var deck: Array[String] = []
var rejects_remaining: int = 0
## D47 = B: card ids removed from the deck this run (rest room, merchant, any deck-clean). They are never offered again, in card offers or the
## merchant's stock. Ids only, no duplicates. An old save without the key loads as empty. Nothing erases an entry: a removed card can still be
## re-added by a debug path (`--full-deck`, a forced `--run-offer`), and then it simply sits in the deck while staying out of offers.
var removed_cards: Array[String] = []
## D49 = B: status id -> the offer weight multiplier earned by pruning or rejecting cards that apply it (1.0 = untouched; an absent key is 1.0).
## Each prune or reject multiplies by `rewards.prune_reject_factor`, never below `rewards.prune_reject_floor`. Read by RewardOffer.generate.
var offer_weights: Dictionary = {}
## One entry per finished room: {index, type, wave_id, hp_end, seconds}.
var history: Array[Dictionary] = []
## "" while the run is going, then "won" or "lost".
var outcome: String = ""
## The choice waiting for the player after a won room (3b), so a reload mid-choice reopens it instead of
## replaying the room: one of the PENDING_ values, and for a card reward the offered card ids.
var pending: String = PENDING_NONE
## For a card reward the offered card ids; for a relic offer (PENDING_RELIC / PENDING_RELIC_SWAP) the offered relic ids.
var offer: Array[String] = []
## PENDING_RELIC_SWAP only: the offered relic the player chose and must give another relic up to take ("" otherwise). Cancel clears it.
var relic_incoming: String = ""
## MAP3b: what kind of offer the open choice is. "" for a normal one; "boss" for the mini-boss's boss-relic offer (PENDING_RELIC and its swap step:
## pick 1 of the offer, no skip); "rare" or "legendary" for a mini-boss card reward (PENDING_REWARD, the rarity it started at). Cleared when the choice closes.
var offer_rarity: String = ""
## One entry per choice made: {index, kind: pick|reject|heal|remove, card_id, amount}. Picks and removals also
## change `deck`; this is the record the sim and the end screens read.
var choice_log: Array[Dictionary] = []
## The relic ids this run holds, in the order they were taken (BD2). Reset with the run: nothing persists between runs.
var relics: Array[String] = []
## Relic ids the player gave up this run (a swap at the cap, a sacrifice). They are never offered again this run.
var relics_given_up: Array[String] = []
## MAP1-A: the branching map (MapGraph format {nodes, edges}), or {} for a straight run / an old save. Built once at the start of a run.
var map: Dictionary = {}
## The map node ids taken so far, in order (the current node is the last).
var path: Array[int] = []
## Gold earned this run (MAP1-B fills it; the merchant spends it in MAP2).
var gold: int = 0
## Reserved for the passive tree and meta-progression (MAP.md section 5): always 0 for now.
var xp_earned: int = 0
## MAP2-A: card removals bought at the merchant this run (each raises the next removal's price).
var merchant_removals: int = 0
## MAP2-A: gold spent at the merchant this run (a later relic scales with it).
var gold_spent_merchant: int = 0
## MAP2-A: the open merchant visit (see Merchant): {node, relics, cards, sold_relics, sold_cards, rerolls_used}, or {} when none is open.
## It holds the stock, so restoring a save mid-visit gives the same shop.
var merchant_visit: Dictionary = {}
## MAP4-B1: the event drawn for the event node the run is in ("" when none is open), the events this run has met (no repeats until every eligible one
## was seen), and the outcomes of the confirmed choice that still wait for the open event relic offer to be answered (EventSchema outcome dictionaries).
var event_id: String = ""
var events_seen: Array[String] = []
var event_queue: Array[Dictionary] = []
## MAP4-B2: an event's `start_fight` waiting to be fought or being fought: {tier, wave_id} ({} when none). While it is set the room is the event's elite fight (pending is
## none), `event_queue` holds the outcomes that run after the win, and a save restarts the fight (the costs paid before it stay paid).
var event_fight: Dictionary = {}
## MAP4-B2: permanent run modifiers from events (`stat_mod`): [{stat, modifier_type, value}], applied each room through the same StatModifiers path as a relic's.
var run_mods: Array[Dictionary] = []
## MAP4-B2: the fraction off relic and card prices at the NEXT merchant visit (`merchant_discount`); the visit copies it and this resets to 0 (used up by that visit).
var merchant_discount: float = 0.0
## MAP4-B2: the relics picked so far in a multi-give-up step (a `sacrifice_cost` relic being taken or bought: PENDING_RELIC_SWAP / PENDING_MERCHANT_SWAP). Nothing is
## given up until the one confirm; Cancel clears it.
var sacrifice_picks: Array[String] = []
## MAP4-B2: the tier (1-3) of the relic an event just made you give up, for `gain_relic` tier `sacrificed_plus_one`; 0 = none.
var sacrificed_tier: int = 0
## MAP4-C: how many curses this run has removed, on every path (rest, merchant, `remove_curse`, `remove_card` that picked a curse). Capped by data/run.json `curses.max_cleanses`.
var cleanses: int = 0
## MAP3-B: the act the run is in (1-based) and how many acts the run has. `map`, `path` and `room_index` always describe the CURRENT act (room_index
## 0-9 inside it), so everything that reads them keeps working. A finished act's map and path move to `past_acts` ({map, path}, act 1 first), which
## makes `act_map(n)` / `act_path(n)` answer for any act. A one-act run (and every straight run) is act 1 of 1 with no past acts.
var act: int = 1
var acts_total: int = 1
var past_acts: Array[Dictionary] = []

## Rooms of different acts must not share random streams (offers, spawns, gold): `stream_index` is `room_index` in act 1 (so a one-act run is
## byte-identical to before) and counts on by ACT_STRIDE per act.
const ACT_STRIDE := 100
const ACT_SEED_MIX := 2654435
const ACT_SEED_SALT := 0x5EED


## A fresh run: the reject allowance comes from data/run.json (RunConfig), the starter from the caller (the character's).
static func new_run(seed_value_in: int, starting_deck: Array[String], rejects: int, character: String = CharacterDatabase.DEFAULT_ID) -> RunState:
	var state := RunState.new()
	state.character_id = character
	state.seed_value = seed_value_in & SEED_LIMIT
	state.deck = starting_deck.duplicate()
	state.rejects_remaining = rejects
	return state


## The room position that seeds this room's random streams (offers, spawns): `room_index` in act 1, `room_index + ACT_STRIDE * (act - 1)` later.
func stream_index() -> int:
	return room_index + ACT_STRIDE * (act - 1)


## The run seed an act's map, gold and chests are drawn from: the run seed itself in act 1 (a one-act run is unchanged), a mix with the act later.
static func act_seed(run_seed: int, act_number: int) -> int:
	if act_number <= 1:
		return run_seed & SEED_LIMIT
	return ((run_seed & SEED_LIMIT) * ACT_SEED_MIX + act_number * 104729 + ACT_SEED_SALT) & SEED_LIMIT


## This run's seed for the current act (see `act_seed`).
func current_act_seed() -> int:
	return act_seed(seed_value, act)


## The map of act `n` (1-based), {} when there is none yet (a future act, or a straight run).
func act_map(n: int) -> Dictionary:
	if n == act:
		return map
	if n >= 1 and n <= past_acts.size():
		return (past_acts[n - 1] as Dictionary)["map"]
	return {}


## The node ids taken in act `n` ([] when none yet).
func act_path(n: int) -> Array[int]:
	if n == act:
		return path
	var found: Array[int] = []
	if n >= 1 and n <= past_acts.size():
		for id: Variant in ((past_acts[n - 1] as Dictionary)["path"] as Array):
			found.append(int(id))
	return found


## Rooms in one act of this run (the room number of the act's last node), 0 for a straight run with no map.
func rooms_per_act() -> int:
	var most: int = 0
	for entry: Variant in (map.get("nodes", []) as Array):
		most = maxi(most, int((entry as Dictionary)["room"]))
	return most


## 1-based room number over the whole run ("Room 14 of 30"): rooms of the finished acts plus this room.
func run_room_number() -> int:
	return (act - 1) * rooms_per_act() + room_index + 1 if not map.is_empty() else room_index + 1


## Rooms in the whole run (acts_total acts of `rooms_per_act`); a straight run has no map, so this is 0 there.
func run_room_total() -> int:
	return acts_total * rooms_per_act()


func has_hp() -> bool:
	return max_hp > 0.0


func is_over() -> bool:
	return outcome != ""


## HP as a 0..1 fraction (1 when HP has not been set yet).
func hp_fraction() -> float:
	if not has_hp():
		return 1.0
	return clampf(hp / max_hp, 0.0, 1.0)


## Records a finished room and leaves `room_index` for the caller to advance.
func record_room(room: Dictionary, hp_end: float, seconds: float) -> void:
	history.append({
		"index": int(room.get("index", room_index)),
		"type": String(room.get("type", "")),
		"wave_id": String(room.get("wave_id", "")),
		"hp_end": hp_end,
		"seconds": seconds,
	})


## Moves a fresh run to room `index` (0-based) for a launch flag or a tool. A map run gets the `first` route's nodes up to and including that
## room as its path (no gold for the skipped rooms), so the position stays consistent. Straight runs only set the index.
func jump_to_room(index: int) -> void:
	room_index = maxi(index, 0)
	if map.is_empty():
		return
	# MAP3-B: room numbers count over the whole run, so a jump past the first act walks the earlier acts' `first` routes (their maps are made now).
	var per_act: int = rooms_per_act()
	var target: int = room_index
	while target >= per_act and act < acts_total:
		path = MapGraph.first_route(map)
		if not RunNodes.advance_act(self):
			break
		target -= per_act
	room_index = target
	var route: Array[int] = MapGraph.first_route(map)
	room_index = mini(room_index, route.size() - 1)
	path = route.slice(0, room_index + 1)
	if pending == PENDING_NODE:
		pending = PENDING_NONE


## Moves a fresh map run onto node `node_id` for a launch flag or a tool (`--run-node`): the path runs back to a room-1 node through each node's first
## predecessor, and the run is in that node's room with no choice open. False (nothing changed) when the run has no map or no such node.
func jump_to_node(node_id: int) -> bool:
	if map.is_empty() or MapGraph.node(map, node_id).is_empty():
		return false
	var trail: Array[int] = [node_id]
	while int(MapGraph.node(map, trail[0]).get("room", 1)) > 1:
		var before: Array[int] = MapGraph.prev_ids(map, trail[0])
		if before.is_empty():
			return false
		trail.push_front(before[0])
	path = trail
	room_index = trail.size() - 1
	pending = PENDING_NONE
	offer = []
	offer_rarity = ""
	return true


func has_pending() -> bool:
	return pending != PENDING_NONE


## True while a merchant screen is open (the shop, its removal list or the give-one-up step).
func has_merchant_choice() -> bool:
	return MERCHANT_PENDING.has(pending)


## True while the open choice is a relic offer or its give-one-up step.
func has_relic_choice() -> bool:
	return pending == PENDING_RELIC or pending == PENDING_RELIC_SWAP


func log_choice(kind: String, card_id: String = "", amount: float = 0.0) -> void:
	choice_log.append({"index": stream_index(), "kind": kind, "card_id": card_id, "amount": amount})


func to_dict() -> Dictionary:
	return {
		"version": FORMAT_VERSION,
		"seed": seed_value,
		"character": character_id,
		"room_index": room_index,
		"hp": hp,
		"max_hp": max_hp,
		"deck": deck.duplicate(),
		"removed_cards": removed_cards.duplicate(),
		"offer_weights": offer_weights.duplicate(),
		"rejects_remaining": rejects_remaining,
		"history": history.duplicate(true),
		"outcome": outcome,
		"pending": pending,
		"offer": offer.duplicate(),
		"relic_incoming": relic_incoming,
		"offer_rarity": offer_rarity,
		"choice_log": choice_log.duplicate(true),
		"relics": relics.duplicate(),
		"relics_given_up": relics_given_up.duplicate(),
		"map": map.duplicate(true),
		"path": path.duplicate(),
		"gold": gold,
		"xp_earned": xp_earned,
		"merchant_removals": merchant_removals,
		"gold_spent_merchant": gold_spent_merchant,
		"merchant_visit": merchant_visit.duplicate(true),
		"event_id": event_id,
		"events_seen": events_seen.duplicate(),
		"event_queue": event_queue.duplicate(true),
		"event_fight": event_fight.duplicate(true),
		"run_mods": run_mods.duplicate(true),
		"merchant_discount": merchant_discount,
		"sacrifice_picks": sacrifice_picks.duplicate(),
		"sacrificed_tier": sacrificed_tier,
		"cleanses": cleanses,
		"act": act,
		"acts_total": acts_total,
		"past_acts": past_acts.duplicate(true),
	}


func to_json() -> String:
	return JSON.stringify(to_dict())


## Rebuilds a state; returns null (and pushes an error) when the data is malformed.
static func from_dict(data: Dictionary) -> RunState:
	for key: String in ["seed", "room_index", "hp", "max_hp", "deck", "rejects_remaining", "history"]:
		if not data.has(key):
			push_error("RunState.from_dict: missing '%s'" % key)
			return null
	if typeof(data["deck"]) != TYPE_ARRAY or typeof(data["history"]) != TYPE_ARRAY:
		push_error("RunState.from_dict: 'deck' and 'history' must be arrays")
		return null
	for key: String in ["seed", "room_index", "hp", "max_hp", "rejects_remaining"]:
		if not _is_number(data[key]) or is_nan(float(data[key])) or is_inf(float(data[key])):
			push_error("RunState.from_dict: '%s' must be a number" % key)
			return null
	if typeof(data.get("outcome", "")) != TYPE_STRING:
		push_error("RunState.from_dict: 'outcome' must be a string")
		return null
	var state := RunState.new()
	state.seed_value = int(data["seed"])
	var saved_character: String = _string_of(data.get("character", CharacterDatabase.DEFAULT_ID))
	if CharacterDatabase.has(saved_character):
		state.character_id = saved_character
	else:
		push_error("RunState.from_dict: unknown character '%s'; using '%s'" % [saved_character, CharacterDatabase.DEFAULT_ID])
	state.room_index = int(data["room_index"])
	state.hp = float(data["hp"])
	state.max_hp = float(data["max_hp"])
	state.rejects_remaining = int(data["rejects_remaining"])
	state.outcome = String(data.get("outcome", ""))
	var dropped_choice: bool = false
	var offered_ids: Variant = data.get("offer", [])
	if typeof(offered_ids) == TYPE_ARRAY:
		for offered: Variant in (offered_ids as Array):
			if typeof(offered) == TYPE_STRING and not String(offered).is_empty():
				state.offer.append(String(offered))
			else:
				push_error("RunState.from_dict: 'offer' holds a value that is not an id; dropped")
	elif data.has("offer"):
		push_error("RunState.from_dict: 'offer' must be an array; using none")
	var incoming: Variant = data.get("relic_incoming", "")
	var incoming_id: String = String(incoming) if typeof(incoming) == TYPE_STRING else ""
	var pending_value: Variant = data.get("pending", PENDING_NONE)
	# A choice that cannot be shown (a reward or relic offer with nothing in it, a swap with no valid relic to take) is dropped.
	var shows: bool = typeof(pending_value) == TYPE_STRING and PENDING_VALUES.has(String(pending_value))
	if typeof(pending_value) == TYPE_STRING and String(pending_value) == PENDING_NONE:
		state.offer = []  # a stale offer with no choice open would only confuse the next reward
	if shows and [PENDING_REWARD, PENDING_RELIC, PENDING_RELIC_SWAP].has(String(pending_value)) and state.offer.is_empty():
		shows = false
	if shows and String(pending_value) == PENDING_RELIC_SWAP and (incoming_id.is_empty() or not state.offer.has(incoming_id)):
		shows = false
	if shows and String(pending_value) == PENDING_NODE and (typeof(data.get("map")) != TYPE_DICTIONARY or (data["map"] as Dictionary).is_empty()):
		shows = false  # a node pick needs a map to pick from
	if shows:
		state.pending = String(pending_value)
		if state.pending == PENDING_RELIC_SWAP or state.pending == PENDING_MERCHANT_SWAP:
			state.relic_incoming = incoming_id
		state.offer_rarity = _offer_rarity_for(state.pending, data.get("offer_rarity", ""))
	else:
		# An unknown (or non-string, or an empty reward) pending must not leave a screen that can never close.
		# The choice is dropped. If the room it followed was already won and recorded (the history holds
		# this room), the run moves on to the next room instead of replaying the won room.
		push_error("RunState.from_dict: unknown pending value %s; no choice is open" % str(pending_value))
		state.pending = PENDING_NONE
		state.offer = []
		dropped_choice = true
	var saved_log: Variant = data.get("choice_log", [])
	if typeof(saved_log) != TYPE_ARRAY:
		push_error("RunState.from_dict: 'choice_log' must be an array")
		return null
	for entry: Variant in (saved_log as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			push_error("RunState.from_dict: choice_log entries must be objects")
			return null
		var c: Dictionary = entry
		state.choice_log.append({
			"index": _int_of(c.get("index", 0)),
			"kind": _string_of(c.get("kind", "")),
			"card_id": _string_of(c.get("card_id", "")),
			"amount": _float_of(c.get("amount", 0.0)),
		})
	# Old dicts (before BD2) have no relic lists: they load as empty.
	state.relics = _id_list(data.get("relics", []), "relics")
	state.removed_cards = _id_list(data.get("removed_cards", []), "removed_cards")  # D47: a missing key (an old save) is empty
	state.relics_given_up = _id_list(data.get("relics_given_up", []), "relics_given_up")
	state.offer_weights = _offer_weights_of(data.get("offer_weights", {}))  # D49: a missing key (an old save) is empty
	var relic_problem: String = _relic_problem(state)
	if not relic_problem.is_empty():
		push_error("RunState.from_dict: %s" % relic_problem)
		return null
	_read_map_fields(state, data)
	if not _read_act_fields(state, data):
		return null
	if state.map.is_empty() and state.pending == PENDING_NODE:
		# The map was unreadable (dropped above): a node pick with no map to pick from would be a soft lock.
		push_error("RunState.from_dict: pending 'node' but the map is unusable; no choice is open")
		state.pending = PENDING_NONE
	_read_merchant_fields(state, data)
	_read_run_fields(state, data)
	_read_event_fields(state, data)
	if state.pending == PENDING_EVENT and not _event_choice_fits(state):
		push_error("RunState.from_dict: pending 'event' has no usable event ('%s'); no choice is open" % state.event_id)
		state.pending = PENDING_NONE
		state.event_id = ""
		dropped_choice = true
	if state.pending == PENDING_EVENT_SACRIFICE and not _event_sacrifice_fits(state):
		push_error("RunState.from_dict: pending 'event_sacrifice' has no sacrifice outcome waiting or no relic to give up; no choice is open")
		state.pending = PENDING_NONE
		state.event_queue = []
		dropped_choice = true
	if not state.sacrifice_picks.is_empty() and not _sacrifice_picks_fit(state):
		push_error("RunState.from_dict: 'sacrifice_picks' does not fit the open choice; dropped")
		state.sacrifice_picks = []
	if MERCHANT_PENDING.has(state.pending) and not _merchant_choice_fits(state):
		# A merchant screen with no visit behind it (or a swap for a relic that is not for sale) cannot be shown: drop the choice like any other.
		push_error("RunState.from_dict: pending '%s' has no usable merchant visit; no choice is open" % state.pending)
		state.pending = PENDING_NONE
		state.relic_incoming = ""
		state.merchant_visit = {}
		dropped_choice = true
	for card_id: Variant in (data["deck"] as Array):
		if typeof(card_id) != TYPE_STRING or String(card_id).is_empty():
			push_error("RunState.from_dict: 'deck' holds a value that is not a card id")
			return null
		state.deck.append(String(card_id))
	if state.pending == PENDING_EVENT_REMOVE and not _event_remove_fits(state):
		# The deck is read above on purpose: the check needs it.
		push_error("RunState.from_dict: pending 'event_remove' has no removal outcome waiting or nothing it may remove; no choice is open")
		state.pending = PENDING_NONE
		state.event_queue = []
		dropped_choice = true
	for entry: Variant in (data["history"] as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			push_error("RunState.from_dict: history entries must be objects")
			return null
		var e: Dictionary = entry
		state.history.append({
			"index": _int_of(e.get("index", 0)),
			"type": _string_of(e.get("type", "")),
			"wave_id": _string_of(e.get("wave_id", "")),
			"hp_end": _float_of(e.get("hp_end", 0.0)),
			"seconds": _float_of(e.get("seconds", 0.0)),
		})
	if not state.map.is_empty() and not RunNodes.consistent(state):
		# A map run whose path and room index disagree cannot be followed: say so and fall back to the straight run (no map, no path).
		push_error("RunState.from_dict: the path (%d nodes) does not fit room index %d; the map is dropped and the run is straight" % [state.path.size(), state.room_index])
		state.map = {}
		state.path = []
		state.act = 1
		state.acts_total = 1
		state.past_acts = []
		if state.pending == PENDING_NODE:
			state.pending = PENDING_NONE
	elif dropped_choice and not state.map.is_empty():
		# A map run that lost an unreadable choice reopens the pick-next-node choice instead of guessing the next room.
		state.pending = PENDING_NODE
	elif dropped_choice and not state.history.is_empty() and int((state.history[state.history.size() - 1] as Dictionary)["index"]) == state.room_index:
		state.room_index += 1
	return state


## MAP3b: the saved `offer_rarity` when it fits the open choice ("boss" for a relic offer, a card rarity for a reward), else "" (loudly, if it was set).
static func _offer_rarity_for(pending_value: String, saved: Variant) -> String:
	if typeof(saved) == TYPE_STRING and String(saved).is_empty():
		return ""
	var fits: bool = typeof(saved) == TYPE_STRING and (
			([PENDING_RELIC, PENDING_RELIC_SWAP].has(pending_value) and String(saved) == "boss")
			or ([PENDING_RELIC, PENDING_RELIC_SWAP].has(pending_value) and [OFFER_EVENT, OFFER_EVENT_NOSKIP, OFFER_DIG].has(String(saved)))
			or (pending_value == PENDING_REWARD and ["rare", "legendary"].has(String(saved))))
	if not fits:
		push_error("RunState.from_dict: offer_rarity %s does not fit the open choice '%s'; using a normal offer" % [str(saved), pending_value])
		return ""
	return String(saved)


## True when a merchant pending value has what it needs: an open visit, and for the swap an incoming relic that is in stock, unsold and not owned.
static func _merchant_choice_fits(state: RunState) -> bool:
	if state.merchant_visit.is_empty():
		return false
	if state.pending == PENDING_MERCHANT_SWAP:
		var incoming: String = state.relic_incoming
		return (state.merchant_visit["relics"] as Array).has(incoming) and not (state.merchant_visit["sold_relics"] as Array).has(incoming) and not state.relics.has(incoming)
	return true


## The map, path, gold and xp of saved data. Old dicts (before MAP1) have none of these keys and load as a straight run. A malformed
## map is dropped loudly (no map, no path) and a bad number falls back to 0, so a damaged save can't crash the loader.
static func _read_map_fields(state: RunState, data: Dictionary) -> void:
	if data.has("map"):
		var problems: Array[String] = []
		state.map = MapGraph.normalize(data["map"], problems)
		if not problems.is_empty():
			push_error("RunState.from_dict: 'map' is malformed (%s); no map" % "; ".join(problems))
	state.gold = _whole_or_zero(data.get("gold", 0), "gold")
	if state.gold < 0:
		push_error("RunState.from_dict: 'gold' cannot be negative; using 0")
		state.gold = 0
	state.xp_earned = maxi(_whole_or_zero(data.get("xp_earned", 0), "xp_earned"), 0)
	var saved_path: Variant = data.get("path", [])
	if typeof(saved_path) != TYPE_ARRAY:
		push_error("RunState.from_dict: 'path' must be an array; using none")
		return
	for item: Variant in (saved_path as Array):
		var known: bool = (typeof(item) == TYPE_INT or typeof(item) == TYPE_FLOAT) and not state.map.is_empty() and not MapGraph.node(state.map, int(item)).is_empty()
		if not known:
			push_error("RunState.from_dict: 'path' holds a value that is not a node of the map; path dropped")
			state.path = []
			return
		state.path.append(int(item))


## The act fields of saved data (MAP3-B). Old dicts have none and load as act 1 of 1. False (with a push_error) when they are wrong: an act outside
## 1..acts_total, or past acts that are not one well-formed {map, path} per finished act. A run whose map was dropped is a straight run: act 1 of 1.
static func _read_act_fields(state: RunState, data: Dictionary) -> bool:
	var act_value: Variant = data.get("act", 1)
	var total_value: Variant = data.get("acts_total", 1)
	if not _is_whole_number(act_value) or not _is_whole_number(total_value):
		push_error("RunState.from_dict: 'act' and 'acts_total' must be whole numbers")
		return false
	var past: Variant = data.get("past_acts", [])
	if typeof(past) != TYPE_ARRAY:
		push_error("RunState.from_dict: 'past_acts' must be an array")
		return false
	if state.map.is_empty():
		return true  # a straight run (or a damaged map, dropped above): act 1 of 1, nothing kept
	var act_number: int = int(act_value)
	var total: int = int(total_value)
	if total < 1 or total > MAX_ACTS or act_number < 1 or act_number > total or (past as Array).size() != act_number - 1:
		push_error("RunState.from_dict: act %d of %d with %d past acts does not fit" % [act_number, total, (past as Array).size()])
		return false
	for entry: Variant in (past as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			push_error("RunState.from_dict: a past act must be an object {map, path}")
			return false
		var problems: Array[String] = []
		var past_map: Dictionary = MapGraph.normalize((entry as Dictionary).get("map"), problems)
		var past_path: Variant = (entry as Dictionary).get("path")
		if past_map.is_empty() or typeof(past_path) != TYPE_ARRAY:
			push_error("RunState.from_dict: a past act has a bad map or path (%s)" % "; ".join(problems))
			return false
		var ids: Array[int] = []
		for item: Variant in (past_path as Array):
			if not _is_whole_number(item) or MapGraph.node(past_map, int(item)).is_empty():
				push_error("RunState.from_dict: a past act's path holds a value that is not a node of its map")
				return false
			ids.append(int(item))
		state.past_acts.append({"map": past_map, "path": ids})
	state.act = act_number
	state.acts_total = total
	return true


static func _is_whole_number(value: Variant) -> bool:
	return _is_number(value) and not is_nan(float(value)) and not is_inf(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) < 1.0e9


## The merchant fields of saved data. Old dicts (before MAP2) have none and load with no removals, nothing spent and no open visit. A bad
## number falls back to 0 and a malformed visit is dropped, both loudly. The visit is rebuilt with whole numbers and in a fixed key order,
## because a JSON round trip turns every number into a float and `equals` compares the JSON text.
static func _read_merchant_fields(state: RunState, data: Dictionary) -> void:
	state.merchant_removals = maxi(_whole_or_zero(data.get("merchant_removals", 0), "merchant_removals"), 0)
	state.gold_spent_merchant = maxi(_whole_or_zero(data.get("gold_spent_merchant", 0), "gold_spent_merchant"), 0)
	var visit: Variant = data.get("merchant_visit", {})
	if typeof(visit) != TYPE_DICTIONARY:
		push_error("RunState.from_dict: 'merchant_visit' must be an object; no visit is open")
		return
	if (visit as Dictionary).is_empty():
		return
	var v: Dictionary = visit
	for key: String in ["node", "relics", "cards", "sold_relics", "sold_cards", "rerolls_used"]:
		if not v.has(key):
			push_error("RunState.from_dict: 'merchant_visit' is missing '%s'; no visit is open" % key)
			return
	for key: String in ["relics", "cards", "sold_relics", "sold_cards"]:
		if typeof(v[key]) != TYPE_ARRAY:
			push_error("RunState.from_dict: 'merchant_visit.%s' must be an array; no visit is open" % key)
			return
		for item: Variant in (v[key] as Array):
			if typeof(item) != TYPE_STRING or String(item).is_empty():
				push_error("RunState.from_dict: 'merchant_visit.%s' holds a value that is not an id; no visit is open" % key)
				return
	var numbers_ok: bool = (typeof(v["node"]) == TYPE_INT or typeof(v["node"]) == TYPE_FLOAT) and (typeof(v["rerolls_used"]) == TYPE_INT or typeof(v["rerolls_used"]) == TYPE_FLOAT)
	if not numbers_ok or (not state.map.is_empty() and MapGraph.node(state.map, int(v["node"])).is_empty()):
		push_error("RunState.from_dict: 'merchant_visit' has a bad node or reroll count; no visit is open")
		return
	state.merchant_visit = {
		"node": int(v["node"]),
		"relics": _plain_ids(v["relics"]),
		"cards": _plain_ids(v["cards"]),
		"sold_relics": _plain_ids(v["sold_relics"]),
		"sold_cards": _plain_ids(v["sold_cards"]),
		"rerolls_used": maxi(int(v["rerolls_used"]), 0),
	}
	var discount: Variant = v.get("discount", 0.0)  # MAP4-B2: an event's discount this visit holds (absent in old saves and in an undiscounted visit)
	if _is_number(discount) and not is_nan(float(discount)) and not is_inf(float(discount)) and float(discount) > 0.0 and float(discount) < 1.0:
		state.merchant_visit["discount"] = float(discount)
	elif v.has("discount") and not (_is_number(discount) and float(discount) == 0.0):
		push_error("RunState.from_dict: 'merchant_visit.discount' must be a number from 0 to below 1; no discount")


## True when an event pending value has what it needs: an event id the data still has.
static func _event_choice_fits(state: RunState) -> bool:
	return not state.event_id.is_empty() and EventDatabase.has_event(state.event_id)


## The event fields of saved data (MAP4-B1). Old dicts have none and load as no event. Wrong types are rejected loudly and fall back to empty. The queue's
## outcomes are checked with EventSchema and rebuilt with whole numbers (a JSON round trip turns every number into a float and `equals` compares text).
static func _read_event_fields(state: RunState, data: Dictionary) -> void:
	var saved_id: Variant = data.get("event_id", "")
	if typeof(saved_id) == TYPE_STRING:
		state.event_id = String(saved_id)
	else:
		push_error("RunState.from_dict: 'event_id' must be a string; using none")
	state.events_seen = _id_list(data.get("events_seen", []), "events_seen")
	var queue: Variant = data.get("event_queue", [])
	if typeof(queue) != TYPE_ARRAY:
		push_error("RunState.from_dict: 'event_queue' must be an array; using none")
		return
	var rebuilt: Array[Dictionary] = []
	for entry: Variant in (queue as Array):
		var problems: Array[String] = EventSchema.validate_outcome(entry)
		if not problems.is_empty():
			push_error("RunState.from_dict: 'event_queue' holds a bad outcome (%s); queue dropped" % "; ".join(problems))
			return
		rebuilt.append(EventSchema.normalize_outcome(entry as Dictionary))
	if not rebuilt.is_empty() and not ([PENDING_RELIC, PENDING_RELIC_SWAP, PENDING_EVENT_SACRIFICE, PENDING_EVENT_REMOVE].has(state.pending) or not state.event_fight.is_empty()):
		push_error("RunState.from_dict: 'event_queue' has no open event choice or fight to wait for; queue dropped")
		return
	state.event_queue = rebuilt


## True when an event sacrifice step has what it needs: a `sacrifice_relic` outcome at the head of the queue and at least one owned relic it may take.
static func _event_sacrifice_fits(state: RunState) -> bool:
	if state.event_queue.is_empty() or String(state.event_queue[0].get("type", "")) != "sacrifice_relic":
		return false
	return not EventEngine.sacrifice_candidates(state.relics, state.event_queue[0], RelicDatabase.all_relics()).is_empty()


## True when an event removal step has what it needs: a `remove_card` or `remove_curse` outcome at the head of the queue and a card it may take (for a curse: one
## in the deck while the cleanse cap, if any, is not used up).
static func _event_remove_fits(state: RunState) -> bool:
	if state.event_queue.is_empty():
		return false
	var head: String = String(state.event_queue[0].get("type", ""))
	if head == "remove_card":
		return not state.deck.is_empty()
	if head != "remove_curse":
		return false
	var cap: int = RunConfig.max_cleanses()
	if cap >= 0 and state.cleanses >= cap:
		return false
	for card_id: String in state.deck:
		if CardSchema.is_curse(CardDatabase.get_card(card_id)):
			return true
	return false


## True when the saved multi-give-up picks belong to an open give-up step: every pick is an owned relic, none twice, at most the incoming relic's cost.
static func _sacrifice_picks_fit(state: RunState) -> bool:
	if not [PENDING_RELIC_SWAP, PENDING_MERCHANT_SWAP].has(state.pending) or state.relic_incoming.is_empty():
		return false
	for relic_id: String in state.sacrifice_picks:
		if not state.relics.has(relic_id):
			return false
	return state.sacrifice_picks.size() <= RunRelics.cost_in_catalog(state.relic_incoming, RelicDatabase.all_relics())


## The MAP4-B2 run fields of saved data (event fight, run modifiers, merchant discount, give-up picks, sacrificed tier). Old dicts have none and load empty. Wrong
## types are rejected loudly and fall back to empty; run modifiers are rebuilt with floats in a fixed key order (equals compares JSON text).
static func _read_run_fields(state: RunState, data: Dictionary) -> void:
	var fight: Variant = data.get("event_fight", {})
	if typeof(fight) == TYPE_DICTIONARY and not (fight as Dictionary).is_empty():
		var f: Dictionary = fight
		if typeof(f.get("tier")) == TYPE_STRING and EventSchema.FIGHT_TIERS.has(String(f["tier"])) and typeof(f.get("wave_id")) == TYPE_STRING:
			state.event_fight = {"tier": String(f["tier"]), "wave_id": String(f["wave_id"])}
		else:
			push_error("RunState.from_dict: 'event_fight' needs a known tier and a wave_id; no fight is waiting")
	elif typeof(fight) != TYPE_DICTIONARY:
		push_error("RunState.from_dict: 'event_fight' must be an object; no fight is waiting")
	var mods: Variant = data.get("run_mods", [])
	if typeof(mods) == TYPE_ARRAY:
		for entry: Variant in (mods as Array):
			if _run_mod_is_valid(entry):
				var mod: Dictionary = entry
				state.run_mods.append({"stat": String(mod["stat"]), "modifier_type": String(mod["modifier_type"]), "value": float(mod["value"])})
			else:
				push_error("RunState.from_dict: 'run_mods' holds a bad modifier; dropped")
	else:
		push_error("RunState.from_dict: 'run_mods' must be an array; using none")
	var discount: Variant = data.get("merchant_discount", 0.0)
	if _is_number(discount) and not is_nan(float(discount)) and not is_inf(float(discount)) and float(discount) >= 0.0 and float(discount) < 1.0:
		state.merchant_discount = float(discount)
	else:
		push_error("RunState.from_dict: 'merchant_discount' must be a number from 0 to below 1; using 0")
	state.sacrifice_picks = _id_list(data.get("sacrifice_picks", []), "sacrifice_picks")
	var tier: Variant = data.get("sacrificed_tier", 0)
	if _is_whole_number(tier) and int(tier) >= 0 and int(tier) <= 3:
		state.sacrificed_tier = int(tier)
	else:
		push_error("RunState.from_dict: 'sacrificed_tier' must be 0 to 3; using 0")
	var cleansed: Variant = data.get("cleanses", 0)
	if _is_whole_number(cleansed) and int(cleansed) >= 0:
		state.cleanses = int(cleansed)
	else:
		push_error("RunState.from_dict: 'cleanses' must be a whole number from 0; using 0")


static func _run_mod_is_valid(entry: Variant) -> bool:
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	var mod: Dictionary = entry
	return typeof(mod.get("stat")) == TYPE_STRING and not String(mod["stat"]).is_empty() \
			and typeof(mod.get("modifier_type")) == TYPE_STRING and [StatModifiers.ADDITIVE, StatModifiers.MULTIPLICATIVE].has(String(mod["modifier_type"])) \
			and _is_number(mod.get("value")) and not is_nan(float(mod["value"])) and not is_inf(float(mod["value"]))


## Ids kept as they are, duplicates and all (a card id may repeat in a list of sold cards).
static func _plain_ids(value: Variant) -> Array[String]:
	var ids: Array[String] = []
	for item: Variant in (value as Array):
		ids.append(String(item))
	return ids


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _int_of(value: Variant) -> int:
	return int(value) if _is_number(value) and not is_nan(float(value)) and not is_inf(float(value)) else 0


static func _float_of(value: Variant) -> float:
	return float(value) if _is_number(value) and not is_nan(float(value)) and not is_inf(float(value)) else 0.0


static func _string_of(value: Variant) -> String:
	return String(value) if typeof(value) == TYPE_STRING else ""


## "" when the relic lists are sound, else the reason: every id must exist, none may be held and given up at once, and the held ones fit the cap.
static func _relic_problem(state: RunState) -> String:
	for relic_id: String in state.relics:
		if not RelicDatabase.has_relic(relic_id):
			return "relic '%s' does not exist" % relic_id
		if state.relics_given_up.has(relic_id):
			return "relic '%s' is both held and given up" % relic_id
	for relic_id: String in state.relics_given_up:
		if not RelicDatabase.has_relic(relic_id):
			return "given-up relic '%s' does not exist" % relic_id
	if state.relics.size() > RelicConfig.max_owned():
		return "%d relics held, over the cap of %d" % [state.relics.size(), RelicConfig.max_owned()]
	return ""


static func _whole_or_zero(value: Variant, label: String) -> int:
	if (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and not is_nan(float(value)) and not is_inf(float(value)) and absf(float(value)) < 1.0e9:
		return int(value)
	push_error("RunState.from_dict: '%s' must be a number; using 0" % label)
	return 0


## A list of ids from saved data: anything that is not an array of strings is dropped (loudly), duplicates are kept out.
static func _id_list(value: Variant, label: String) -> Array[String]:
	var ids: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		push_error("RunState.from_dict: '%s' must be an array; using none" % label)
		return ids
	for item: Variant in (value as Array):
		if typeof(item) != TYPE_STRING or String(item).is_empty():
			push_error("RunState.from_dict: '%s' holds a value that is not an id; dropped" % label)
			continue
		if not ids.has(String(item)):
			ids.append(String(item))
	return ids


## Notes that a card was removed from the deck (D47 = B): it is never offered again this run. No duplicates.
func record_removal(card_id: String) -> void:
	if not card_id.is_empty() and not removed_cards.has(card_id):
		removed_cards.append(card_id)


## D49 = B: a pruned or rejected card makes the statuses it applies rarer in later offers. `rewards` is the run.json block
## (`prune_reject_factor`, `prune_reject_floor`); a missing or 1.0 factor does nothing. A card with no status changes nothing.
func discount_card_types(card_id: String, rewards: Dictionary) -> void:
	var factor: float = float(rewards.get("prune_reject_factor", 1.0))
	var floor_value: float = float(rewards.get("prune_reject_floor", 0.0))
	if factor >= 1.0 or not CardDatabase.has_card(card_id):
		return
	for status_id: String in CardSummary.status_ids(CardDatabase.get_card(card_id)):
		var current: float = float(offer_weights.get(status_id, 1.0))
		offer_weights[status_id] = minf(current, maxf(current * factor, floor_value))


## Reads a saved `offer_weights`: status id -> a finite number in (0, 1]. Anything else is dropped with an error (the run keeps going).
static func _offer_weights_of(value: Variant) -> Dictionary:
	var out: Dictionary = {}
	if typeof(value) != TYPE_DICTIONARY:
		if value != null:
			push_error("RunState.from_dict: 'offer_weights' must be an object; using none")
		return out
	for key: Variant in (value as Dictionary).keys():
		var entry: Variant = (value as Dictionary)[key]
		if typeof(key) == TYPE_STRING and not String(key).is_empty() and _is_number(entry) and not is_nan(float(entry)) and not is_inf(float(entry)) and float(entry) > 0.0 and float(entry) <= 1.0:
			out[String(key)] = float(entry)
		else:
			push_error("RunState.from_dict: 'offer_weights' entry '%s' is not a status id with a weight in (0, 1]; dropped" % str(key))
	return out


## True when the run holds this relic.
func has_relic(relic_id: String) -> bool:
	return relics.has(relic_id)


## Adds a relic (no duplicates). Returns false when it is already held.
func add_relic(relic_id: String) -> bool:
	if relics.has(relic_id):
		return false
	relics.append(relic_id)
	return true


## Gives a held relic up: it leaves `relics` and joins `relics_given_up`, so it is not offered again. False when not held.
func give_up_relic(relic_id: String) -> bool:
	if not relics.has(relic_id):
		return false
	relics.erase(relic_id)
	if not relics_given_up.has(relic_id):
		relics_given_up.append(relic_id)
	return true


static func from_json(text: String) -> RunState:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("RunState.from_json: not a JSON object")
		return null
	return from_dict(parsed)


## True when both states hold the same values (used by the round-trip test and the soak).
func equals(other: RunState) -> bool:
	return other != null and to_json() == other.to_json()
