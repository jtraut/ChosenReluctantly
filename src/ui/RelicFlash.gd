class_name RelicFlash
extends RefCounted
## Pure math for a HUD relic chip's trigger flash (BD2). A trigger lights the chip at once and holds it, then it fades.
## A trigger that lands while the chip is still lit refreshes the hold and never drops the level, so a relic firing every
## few frames stays steadily lit instead of strobing; a small counter says how many times it fired in a burst.
## State: {level 0..1, hold_left s, count, count_left s}.


static func fresh() -> Dictionary:
	return {"level": 0.0, "hold_left": 0.0, "count": 0, "count_left": 0.0}


## A trigger now. `hold` is how long the chip stays fully lit; `count_window` how long a burst counts as one.
static func trigger(state: Dictionary, hold: float, count_window: float) -> Dictionary:
	var count: int = int(state.get("count", 0)) if float(state.get("count_left", 0.0)) > 0.0 else 0
	return {"level": 1.0, "hold_left": hold, "count": count + 1, "count_left": count_window}


## One frame of easing: hold, then fade over `release`. The burst counter runs out on its own.
static func step(state: Dictionary, delta: float, release: float) -> Dictionary:
	var level: float = float(state.get("level", 0.0))
	var hold_left: float = float(state.get("hold_left", 0.0))
	var count: int = int(state.get("count", 0))
	var count_left: float = maxf(float(state.get("count_left", 0.0)) - delta, 0.0)
	if hold_left > 0.0:
		hold_left = maxf(hold_left - delta, 0.0)
	else:
		level = 0.0 if release <= 0.0 else maxf(level - delta / release, 0.0)
	if count_left <= 0.0 and level <= 0.0:
		count = 0
	return {"level": level, "hold_left": hold_left, "count": count, "count_left": count_left}


static func is_active(state: Dictionary) -> bool:
	return float(state.get("level", 0.0)) > 0.001 or float(state.get("hold_left", 0.0)) > 0.0


## "x3" for a burst of more than one trigger, else "".
static func count_text(state: Dictionary) -> String:
	var count: int = int(state.get("count", 0))
	return "x%d" % count if count > 1 and is_active(state) else ""


## Two-letter chip mark from a relic name: the first letters of its first two words ("Pyre Insurance" -> "PI"), one word gives
## its first two letters. Anything in brackets is ignored.
static func initials(relic_name: String) -> String:
	var plain: String = relic_name.get_slice("(", 0).strip_edges()
	var words: PackedStringArray = plain.split(" ", false)
	if words.is_empty():
		return "?"
	if words.size() == 1:
		return words[0].substr(0, 2).capitalize() if words[0].length() > 1 else words[0].to_upper()
	return (words[0].substr(0, 1) + words[1].substr(0, 1)).to_upper()


## Marks for a set of relic names that never repeat inside the set: the usual initials, and when two relics would share one, each clashing relic
## tries longer forms from its own words ("Pyre Insurance" and "Pyre Ice" -> "PyIn" and "PyIc") until none is taken. Deterministic.
static func unique_marks(names: Array[String]) -> Array[String]:
	var marks: Array[String] = []
	for relic_name: String in names:
		marks.append(initials(relic_name))
	var counts: Dictionary = {}
	for mark: String in marks:
		counts[mark] = int(counts.get(mark, 0)) + 1
	for i in range(names.size()):
		if int(counts[marks[i]]) <= 1:
			continue
		var words: PackedStringArray = names[i].get_slice("(", 0).strip_edges().split(" ", false)
		if words.size() < 2:
			continue
		var second: String = words[1]
		for length in range(2, second.length() + 1):
			var candidate: String = words[0].substr(0, 1).to_upper() + second.substr(0, length).capitalize()
			if not marks.has(candidate):
				marks[i] = candidate
				break
	return marks
