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


## The act-start heal line (D45 = B), for example "You recover 9 HP. Rests are on the map." Empty when nothing healed, which is also the case for
## an act resumed from a save (the summary's `healed` is 0 there), so a resumed act says nothing about a heal that already happened.
static func heal_line(summary: Dictionary) -> String:
	var healed: int = roundi(float(summary.get("healed", 0.0)))
	if healed <= 0:
		return ""
	return String(_texts().get("heal", "You recover %d HP. Rests are on the map.")) % healed


## True when HP after the heal is at or under `ui.act.low_hp_fraction` of max (default 0.5). No max HP counts as not low.
static func is_low_hp(summary: Dictionary) -> bool:
	var max_hp: float = float(summary.get("max_hp", 0.0))
	if max_hp <= 0.0:
		return false
	return float(summary.get("hp", max_hp)) <= max_hp * float(_texts().get("low_hp_fraction", 0.5))


## The summary line, with the low-HP word added when HP is low, so the warning is not carried by the red colour alone ("Low HP: HP 9 of 30, ...").
static func summary_line(summary: Dictionary) -> String:
	var line: String = String(summary.get("line", ""))
	if is_low_hp(summary):
		return "%s: %s" % [String(_texts().get("low_hp_tag", "Low HP")), line]
	return line
