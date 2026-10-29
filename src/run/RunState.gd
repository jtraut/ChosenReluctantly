class_name RunState
extends RefCounted
## Everything a run carries from room to room (Milestone 3a): HP, deck as card ids, rejects left, the seed,
## the room index and the history of finished rooms. Nothing in here knows what a card does. It converts to
## and from a plain Dictionary (JSON-safe: only strings, whole numbers, floats, arrays), so a save or a
## loadout can reuse it later.
##
## Seeds stay below 2^31 so they survive a JSON round-trip, where every number comes back as a float.

const SEED_LIMIT := 2147483647
const FORMAT_VERSION := 1

var seed_value: int = 0
var room_index: int = 0
## Player HP at the start of the room. -1 means "not set yet": the first room takes the player's own max.
var hp: float = -1.0
var max_hp: float = -1.0
var deck: Array[String] = []
var rejects_remaining: int = 0
## One entry per finished room: {index, type, wave_id, hp_end, seconds}.
var history: Array[Dictionary] = []
## "" while the run is going, then "won" or "lost".
var outcome: String = ""


## A fresh run: the starting deck and reject allowance come from data/run.json (RunConfig).
static func new_run(seed_value_in: int, starting_deck: Array[String], rejects: int) -> RunState:
	var state := RunState.new()
	state.seed_value = seed_value_in & SEED_LIMIT
	state.deck = starting_deck.duplicate()
	state.rejects_remaining = rejects
	return state


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


func to_dict() -> Dictionary:
	return {
		"version": FORMAT_VERSION,
		"seed": seed_value,
		"room_index": room_index,
		"hp": hp,
		"max_hp": max_hp,
		"deck": deck.duplicate(),
		"rejects_remaining": rejects_remaining,
		"history": history.duplicate(true),
		"outcome": outcome,
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
	var state := RunState.new()
	state.seed_value = int(data["seed"])
	state.room_index = int(data["room_index"])
	state.hp = float(data["hp"])
	state.max_hp = float(data["max_hp"])
	state.rejects_remaining = int(data["rejects_remaining"])
	state.outcome = String(data.get("outcome", ""))
	for card_id: Variant in (data["deck"] as Array):
		state.deck.append(String(card_id))
	for entry: Variant in (data["history"] as Array):
		if typeof(entry) != TYPE_DICTIONARY:
			push_error("RunState.from_dict: history entries must be objects")
			return null
		var e: Dictionary = entry
		state.history.append({
			"index": int(e.get("index", 0)),
			"type": String(e.get("type", "")),
			"wave_id": String(e.get("wave_id", "")),
			"hp_end": float(e.get("hp_end", 0.0)),
			"seconds": float(e.get("seconds", 0.0)),
		})
	return state


static func from_json(text: String) -> RunState:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("RunState.from_json: not a JSON object")
		return null
	return from_dict(parsed)


## True when both states hold the same values (used by the round-trip test and the soak).
func equals(other: RunState) -> bool:
	return other != null and to_json() == other.to_json()
