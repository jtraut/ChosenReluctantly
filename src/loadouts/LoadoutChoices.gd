class_name LoadoutChoices
extends RefCounted
## What the start screen shows (3d sitting C): one plain-data model of a class's start choices, built from LoadoutSession's store and the databases. Pure over the store you
## pass (default: the session's), so a test or ux can feed any store. The placeholder screen and ux's (sitting D) draw this and call
## `RunController.confirm_start_choice(slot)` (a slot index, or `LoadoutStore.PRESET`).
##
## Model: {
##   character: String, character_name: String,
##   preset: {slot: PRESET, name: String, deck_size: int},
##   loadouts: Array[{slot, name, deck_size, plan_size, starter_relic, starter_relic_name}]   the usable ones, in slot order
##   flagged: Array[{slot, name, message}]                                                    skipped ones, in slot order, with the checker's reason
##   free_slots: Array[int]                                                                   empty slots a new loadout may take
##   last_used: int                                                                           PRESET or a usable slot: what to preselect (Enter starts it)
##   messages: Array[String]                                                                  every skip or file problem, ready to print
##   rule_problems: Array[String]                                                             problems with data/loadouts.json (empty = fine; then only the preset is offered)
## }


static func start_choices(character_id: String, store: LoadoutStore = null) -> Dictionary:
	var source: LoadoutStore = store if store != null else LoadoutSession.store()
	var rule_problems: Array[String] = LoadoutRules.shipped_problems()
	var loadouts: Array[Dictionary] = []
	var flagged: Array[Dictionary] = []
	var free_slots: Array[int] = []
	if rule_problems.is_empty():
		for i in range(source.slot_count()):
			var entry: Dictionary = source.entry(character_id, i)
			if not entry.is_empty():
				var relic_id: String = String(entry["starter_relic"])
				loadouts.append({"slot": i, "name": String(entry["name"]), "deck_size": (entry["deck"] as Array).size(), "plan_size": (entry["plan"] as Array).size(),
						"starter_relic": relic_id, "starter_relic_name": String(RelicDatabase.get_relic(relic_id).get("name", relic_id)) if not relic_id.is_empty() else ""})
			elif source.is_flagged(character_id, i):
				flagged.append({"slot": i, "name": "", "message": source.flag_message(character_id, i)})
		free_slots = source.free_indices(character_id)
	else:
		for problem: String in rule_problems:
			push_error("LoadoutChoices: " + problem)
	var messages: Array[String] = source.flagged().duplicate()
	messages.append_array(rule_problems)
	return {
		"character": character_id, "character_name": CharacterDatabase.display_name(character_id),
		"preset": {"slot": LoadoutStore.PRESET, "name": _preset_title(), "deck_size": CharacterDatabase.starting_deck(character_id).size()},
		"loadouts": loadouts, "flagged": flagged, "free_slots": free_slots,
		"last_used": source.last_used(character_id) if rule_problems.is_empty() else LoadoutStore.PRESET,
		"messages": messages, "rule_problems": rule_problems,
	}


## The preset row's title, from data/run.json ui.start_screen.preset_title. A missing or empty value is a data error: it is logged and the row falls back to a plain word.
static func _preset_title() -> String:
	var title: Variant = (RunConfig.ui().get("start_screen", {}) as Dictionary).get("preset_title")
	if typeof(title) != TYPE_STRING or String(title).strip_edges().is_empty():
		push_error("LoadoutChoices: data/run.json ui.start_screen.preset_title must be a non-empty string")
		return "Preset"
	return String(title)
