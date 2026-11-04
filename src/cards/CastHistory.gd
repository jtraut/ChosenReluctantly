class_name CastHistory
extends RefCounted
## A short rolling record of recent card casts (game time, slot type, card id, tags) that effect conditions read
## (`cast_within`). Pure: the clock is passed in, so tests need no scene. Entries older than WINDOW seconds are dropped,
## and at most MAX_ENTRIES are kept, so it never grows. A condition may ask for at most MAX_SECONDS.

const WINDOW := 6.0
const MAX_SECONDS := WINDOW
const MAX_ENTRIES := 32


class Entry extends RefCounted:
	var time: float = 0.0
	var slot_type: String = ""
	var card_id: String = ""
	var tags: Array[String] = []


var _entries: Array[Entry] = []


## Adds a cast at game time `now`, dropping entries that fell out of the window or past the cap.
func record(now: float, slot_type: String, card_id: String, tags: Array[String]) -> void:
	prune(now)
	var entry := Entry.new()
	entry.time = now
	entry.slot_type = slot_type
	entry.card_id = card_id
	entry.tags = tags
	_entries.append(entry)
	while _entries.size() > MAX_ENTRIES:
		_entries.remove_at(0)


func prune(now: float) -> void:
	while not _entries.is_empty() and now - _entries[0].time > WINDOW:
		_entries.remove_at(0)


func clear() -> void:
	_entries.clear()


func size() -> int:
	return _entries.size()


## True when a cast of `slot_type` (if not empty) and carrying `tag` (if not empty) happened within the last
## `seconds` (inclusive) before `now`. With both empty, any cast counts.
func cast_within(now: float, seconds: float, slot_type: String = "", tag: String = "") -> bool:
	for i in range(_entries.size() - 1, -1, -1):
		var entry: Entry = _entries[i]
		if now - entry.time > seconds:
			return false  # entries are in time order, so everything earlier is older still
		if not slot_type.is_empty() and entry.slot_type != slot_type:
			continue
		if not tag.is_empty() and not entry.tags.has(tag):
			continue
		return true
	return false


## The recorded casts, oldest first, as plain dictionaries {time, slot_type, card_id, tags} (for ux and tests).
func snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Entry in _entries:
		result.append({"time": entry.time, "slot_type": entry.slot_type, "card_id": entry.card_id, "tags": entry.tags})
	return result
