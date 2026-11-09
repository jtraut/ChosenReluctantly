class_name ActText
extends RefCounted
## Act and whole-run room wording for the UI (MAP3 ux). Pure functions over numbers and the strings in data/run.json `ui.act`, so no screen
## hardcodes a format and every screen says the same thing: "Act 2 of 3" and "Room 14 of 30". A one-act run has no act label and keeps the
## plain per-room wording it always had.


static func _texts() -> Dictionary:
	return RunConfig.ui().get("act", {})


## "Act 2 of 3", or "" when the run has one act (or none).
static func act_label(act: int, acts_total: int) -> String:
	if acts_total <= 1:
		return ""
	return String(_texts().get("label", "Act %d of %d")) % [act, acts_total]


## "Room 14 of 30" over the whole run. A one-act run reads "Room 5 of 10" as before (the same format, its own numbers).
static func room_label(run_room_number: int, run_room_total: int) -> String:
	return String(_texts().get("run_room_label", "Room %d of %d")) % [run_room_number, run_room_total]


## The room label a choice model should show: the whole-run one on a multi-act run, else the model's own `room_label`.
static func model_room_label(model: Dictionary) -> String:
	if int(model.get("acts_total", 1)) > 1 and int(model.get("run_room_total", 0)) > 0:
		return room_label(int(model.get("run_room_number", 0)), int(model["run_room_total"]))
	return String(model.get("room_label", ""))


## Rooms in one act of a run of `run_room_total` rooms over `acts_total` acts.
static func rooms_per_act(run_room_total: int, acts_total: int) -> int:
	return run_room_total / maxi(acts_total, 1)


## The whole-run room number of act-local room `room` in act `act` (what the map shows for a node).
static func run_room(room: int, act: int, run_room_total: int, acts_total: int) -> int:
	return (maxi(act, 1) - 1) * rooms_per_act(run_room_total, acts_total) + room
