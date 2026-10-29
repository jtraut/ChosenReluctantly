class_name DeckCheck
extends RefCounted
## Result of DeckRules.check(): unique-card counts per slot and per group, and
## the shortfalls. Plain data so the F3 overlay (and later the real UI) can
## read it without knowing the rules. Copies of a card never raise a count.

## One entry per slot, in slot order: {slot_type, display_name, count, required, short}.
var slots: Array[Dictionary] = []
## One entry per configured group: {name, slots, count, required, short}. Empty when no group exists.
var groups: Array[Dictionary] = []
## Human-readable shortfalls ("Utility needs 5 unique cards, deck has 4"). Empty means the deck passes.
var problems: Array[String] = []


func is_ok() -> bool:
	return problems.is_empty()


## "Movement 4/3" per slot, then "Attack group 8/10" per group (only if groups exist).
## Shortfalls get a trailing "  SHORT" so plain text can flag them.
func summary_lines() -> Array[String]:
	var lines: Array[String] = []
	for entry: Dictionary in slots:
		lines.append(_line(str(entry["display_name"]), entry))
	for entry: Dictionary in groups:
		lines.append(_line("%s group" % str(entry["name"]), entry))
	return lines


func _line(label: String, entry: Dictionary) -> String:
	var text := "%s %d/%d" % [label, int(entry["count"]), int(entry["required"])]
	if int(entry["short"]) > 0:
		text += "  SHORT"
	return text
