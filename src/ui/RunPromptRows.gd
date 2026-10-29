class_name RunPromptRows
extends RefCounted
## Pure text for the run prompt screens (room cleared, run won): time formatting and the label/value rows.
## All words come from data/run.json `ui`; nothing here knows a card or an enemy. Unit-tested.

## "m:ss" for a time in seconds (negative and NaN count as 0).
static func format_time(seconds: float) -> String:
	var total: int = 0 if is_nan(seconds) else maxi(roundi(seconds), 0)
	return "%d:%02d" % [floori(float(total) / 60.0), total % 60]


static func hp_text(hp: float, max_hp: float) -> String:
	return "%d / %d" % [roundi(hp), roundi(max_hp)]


## Sum of the recorded room times of a run (RunState.history entries carry `seconds`).
static func total_seconds(history: Array) -> float:
	var total: float = 0.0
	for entry: Variant in history:
		if entry is Dictionary:
			total += float((entry as Dictionary).get("seconds", 0.0))
	return total


## Rows for a cleared room: HP now, the healed amount on a rest room, the time on any other room (a rest room
## is over instantly, so its time would only read "0:00"). Each row is {label, value}.
static func cleared_rows(summary: Dictionary, text: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.append({"label": String(text.get("stat_hp", "HP")), "value": hp_text(float(summary.get("hp", 0.0)), float(summary.get("max_hp", 0.0)))})
	if String(summary.get("type", "")) == "rest":
		rows.append({"label": String(text.get("stat_healed", "Healed")), "value": "+%d" % roundi(float(summary.get("healed", 0.0)))})
	else:
		rows.append({"label": String(text.get("stat_time", "Time")), "value": format_time(float(summary.get("seconds", 0.0)))})
	return rows


## Rows for a won run: rooms cleared, total time, HP left.
static func win_rows(history: Array, rooms_total: int, summary: Dictionary, text: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.append({"label": String(text.get("stat_rooms", "Rooms")), "value": "%d / %d" % [history.size(), rooms_total]})
	rows.append({"label": String(text.get("stat_time", "Time")), "value": format_time(total_seconds(history))})
	rows.append({"label": String(text.get("stat_hp", "HP")), "value": hp_text(float(summary.get("hp", 0.0)), float(summary.get("max_hp", 0.0)))})
	return rows
