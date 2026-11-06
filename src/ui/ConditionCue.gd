class_name ConditionCue
extends RefCounted
## Short wording for a conditional card (BD1 carry-over): the dim line on a HUD slot that says why the slot is not lit
## ("Needs Burn", "After Move", "Needs zone"), and the note on a reward card that the dodge does not count as a Movement cast (D39 = A).
## Pure functions over a card dictionary and the strings of data/run.json `ui.slot_condition` and `ui.option.dodge_hint`; no scene.


## The distinct short conditions of `card`, joined with ", ". "" for a card with no condition. `texts` is ui.slot_condition.
static func short_text(card: Dictionary, texts: Dictionary) -> String:
	var seen: Array[String] = []
	for effect: Dictionary in SlotSynergy.conditional_effects(card):
		var shown: String = _short(effect["condition"], texts)
		if shown != "" and not seen.has(shown):
			seen.append(shown)
	return ", ".join(seen)


static func _short(condition: Dictionary, texts: Dictionary) -> String:
	match String(condition.get("type", "")):
		EffectCondition.TARGET_HAS_STATUS:
			var status_id: String = String(condition.get("status_id", ""))
			var entry: Dictionary = StatusDatabase.get_status(status_id)
			return String(texts.get("target_has_status", "")) % String(entry.get("display_name", status_id.replace("_", " ").capitalize()))
		EffectCondition.CAST_WITHIN:
			if condition.has("slot_type"):
				var slot_type: String = String(condition["slot_type"])
				var short_names: Dictionary = texts.get("slot_short", {})
				var key: String = InputLabels.slot_key(slot_type)
				if String(texts.get("cast_within_slot_key", "")) != "" and key != "" and key != "?":
					# "After Move (Ctrl)": the player acts on a key, not on a slot name.
					return String(texts["cast_within_slot_key"]) % [String(short_names.get(slot_type, InputLabels.slot_name(slot_type))), key]
				return String(texts.get("cast_within_slot", "")) % String(short_names.get(slot_type, InputLabels.slot_name(slot_type)))
			return String(texts.get("cast_within_tag", "")) % String(condition.get("tag", ""))
		EffectCondition.ZONE_ACTIVE:
			return String(texts.get("zone_active", ""))
	return ""


## True when the card has a condition on a cast of a slot in `dodge_slots` (Movement), and the dodge does not count as such a cast
## (D39 = A, data/player.json dodge.counts_as_movement_cast false): the card then needs the "dodge does not count" note.
static func needs_dodge_note(card: Dictionary, dodge_slots: Array, dodge_counts: bool) -> bool:
	if dodge_counts:
		return false
	for effect: Dictionary in SlotSynergy.conditional_effects(card):
		var condition: Dictionary = effect["condition"]
		if String(condition.get("type", "")) == EffectCondition.CAST_WITHIN and dodge_slots.has(String(condition.get("slot_type", ""))):
			return true
	return false
