class_name DebugDecks
extends RefCounted
## Debug preset decks (T-decks): named decks in data/debug_decks/<name>.json that a launch can start a run with
## (`--deck=<name>`, `--full-deck`, `--list-decks`). Pure logic over plain data, so tests feed it fixtures; only
## `read_dir` touches the disk and the card databases. Nothing here logs: callers print or push_error.
##
## File format: {"name": <file name without .json>, "description": "one line", "full": [card ids, copies allowed],
## "starter": [card ids, a sub-multiset of full]}. Both lists must pass the deck rules (DeckRules) and name real cards.
## There is deliberately no rule-bypass option.
##
## Optional "class": a character id from data/characters.json (default: the default character, the Rogue). A preset is for one class: every card in
## it must come from that class's pools, `--deck` alone starts the run as that class, and `--class` must agree with it.
##
## `--class=<id>` is parsed here too (resolve_launch), because it must be checked against `--deck` before anything starts.

const DEFAULT_DIR := "res://data/debug_decks"
const EXIT_CONTINUE := -1
const EXIT_OK := 0
const EXIT_REFUSED := 2


## Reads every *.json in `dir_path`: {"presets": {name: data} (usable only), "names": [every file name, sorted],
## "problems": {name: [String]} (broken presets), "load_problems": [String]}.
static func read_dir(dir_path: String = DEFAULT_DIR) -> Dictionary:
	var names: Array[String] = []
	var load_problems: Array[String] = []
	var presets: Dictionary = {}
	var problems: Dictionary = {}
	var result: Dictionary = {"presets": presets, "names": names, "problems": problems, "load_problems": load_problems}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		load_problems.append("could not open the debug deck folder '%s'" % dir_path)
		return result
	var file_names: Array[String] = []
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json"):
			file_names.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	file_names.sort()
	var slot_of: Dictionary = DeckRules.slot_map_from_database()
	var slot_names: Dictionary = DeckRules.slot_names_from_database()
	var pool_of: Dictionary = {}
	for card: Variant in CardDatabase.all_cards():
		pool_of[(card as Dictionary)["id"]] = (card as Dictionary).get("pool", "")
	for file_name: String in file_names:
		var preset_name: String = file_name.get_basename()
		names.append(preset_name)
		var file := FileAccess.open(dir_path.path_join(file_name), FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
		if typeof(parsed) != TYPE_DICTIONARY:
			var bad: Array[String] = ["the file is not a JSON object" if file != null else "the file could not be opened"]
			problems[preset_name] = bad
			continue
		var found: Array[String] = validate_preset(preset_name, parsed, slot_of, DeckRules.shipped_config(), SlotTypeDatabase.known_ids(), slot_names, pool_of)
		if found.is_empty():
			presets[preset_name] = parsed
		else:
			problems[preset_name] = found
	return result


## Problems with one preset (empty = valid). `file_name` is the name from the file path. `pool_of` (card id -> pool id,
## optional) turns on the check that every card belongs to the preset's class pools.
static func validate_preset(file_name: String, data: Variant, slot_of: Dictionary, rules: Dictionary, known_slots: Array, slot_names: Dictionary, pool_of: Dictionary = {}) -> Array[String]:
	var errors: Array[String] = []
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("the preset is not a JSON object")
		return errors
	var preset: Dictionary = data
	if typeof(preset.get("name")) != TYPE_STRING or String(preset["name"]) != file_name:
		errors.append("'name' must be the file name '%s' (got %s)" % [file_name, str(preset.get("name"))])
	if typeof(preset.get("description")) != TYPE_STRING or String(preset["description"]).strip_edges().is_empty():
		errors.append("'description' must be a non-empty one-line string")
	var class_id: String = CharacterDatabase.DEFAULT_ID
	if preset.has("class"):
		if typeof(preset["class"]) != TYPE_STRING or not CharacterDatabase.has(String(preset["class"])):
			errors.append("'class' must be a character id from characters.json (got %s)" % str(preset["class"]))
			class_id = ""
		else:
			class_id = String(preset["class"])
	var lists_ok: bool = true
	for key: String in ["full", "starter"]:
		var list: Variant = preset.get(key)
		if typeof(list) != TYPE_ARRAY or (list as Array).is_empty():
			errors.append("'%s' must be a non-empty array of card ids" % key)
			lists_ok = false
			continue
		for card_id: Variant in (list as Array):
			if typeof(card_id) != TYPE_STRING:
				errors.append("%s: entries must be card id strings (got %s)" % [key, str(card_id)])
				lists_ok = false
			elif not slot_of.has(String(card_id)):
				errors.append("%s: invalid card id '%s'" % [key, String(card_id)])
				lists_ok = false
	if not lists_ok:
		return errors
	if class_id != "" and not pool_of.is_empty():
		var allowed: Array[String] = CharacterDatabase.pools(class_id)
		for key: String in ["full", "starter"]:
			for card_id: Variant in (preset[key] as Array):
				var pool: String = str(pool_of.get(String(card_id), ""))
				if not allowed.has(pool):
					errors.append("%s: '%s' is a %s card; a %s deck may only use %s" % [key, str(card_id), pool, class_id, "/".join(allowed)])
					break
	for key: String in ["full", "starter"]:
		var result: DeckCheck = DeckRules.check(preset[key] as Array, rules, slot_of, known_slots, slot_names)
		for problem: String in result.problems:
			errors.append("%s breaks the deck rules: %s" % [key, problem])
	errors.append_array(subset_problems(preset["starter"] as Array, preset["full"] as Array))
	return errors


## Cards that `starter` has more copies of than `full` (empty = starter is a sub-multiset of full).
static func subset_problems(starter: Array, full: Array) -> Array[String]:
	var problems: Array[String] = []
	var have: Dictionary = {}
	for card_id: Variant in full:
		have[card_id] = int(have.get(card_id, 0)) + 1
	var used: Dictionary = {}
	for card_id: Variant in starter:
		used[card_id] = int(used.get(card_id, 0)) + 1
	var ids: Array = used.keys()
	ids.sort()
	for card_id: Variant in ids:
		if int(used[card_id]) > int(have.get(card_id, 0)):
			problems.append("starter is not a subset of full: '%s' is in starter x%d but in full x%d" % [str(card_id), int(used[card_id]), int(have.get(card_id, 0))])
	return problems


## How many cards of each pool a deck holds: {pool_id: count} (copies counted; unknown ids skipped).
static func pool_counts(card_ids: Array) -> Dictionary:
	var counts: Dictionary = {}
	for card_id: Variant in card_ids:
		var pool: String = String(CardDatabase.get_card(String(card_id)).get("pool", ""))
		if pool != "":
			counts[pool] = int(counts.get(pool, 0)) + 1
	return counts


## The `--list-decks` text: a header, then one "name - description" line per preset (broken ones say INVALID and why).
static func list_lines(directory: Dictionary) -> Array[String]:
	var lines: Array[String] = ["Debug decks (use --deck=<name>, add --full-deck for the full list):"]
	var presets: Dictionary = directory["presets"]
	var names: Array[String] = directory["names"]
	var problems: Dictionary = directory["problems"]
	for preset_name: String in names:
		if presets.has(preset_name):
			lines.append("  %s - %s" % [preset_name, String((presets[preset_name] as Dictionary)["description"])])
		else:
			var why: Array = problems.get(preset_name, [])
			lines.append("  %s - INVALID: %s" % [preset_name, "; ".join(PackedStringArray(why))])
	return lines


## Reads the launch args (the user args after `--`) against a read_dir result. Returns
## {"exit": EXIT_CONTINUE | EXIT_OK | EXIT_REFUSED, "lines": [text to print], "errors": [text to push_error], "deck": preset name or "",
## "character": the class the launch fixes ("" = not fixed: a `--class`, else the `--deck` preset's class)}.
## EXIT_OK means print `lines` and quit (--list-decks); EXIT_REFUSED means the launch must not start.
static func resolve_launch(args: PackedStringArray, directory: Dictionary) -> Dictionary:
	var lines: Array[String] = []
	var errors: Array[String] = []
	var result: Dictionary = {"exit": EXIT_CONTINUE, "lines": lines, "errors": errors, "deck": "", "character": ""}
	var requested: Array[String] = []
	var classes: Array[String] = []
	var listing: bool = false
	for arg: String in args:
		if arg == "--list-decks":
			listing = true
		elif arg == "--deck":
			requested.append("")
		elif arg.begins_with("--deck="):
			requested.append(arg.substr(7).strip_edges())
		elif arg == "--class":
			classes.append("")
		elif arg.begins_with("--class="):
			classes.append(arg.substr(8).strip_edges())
	var presets: Dictionary = directory["presets"]
	var names: Array[String] = directory["names"]
	var problems: Dictionary = directory["problems"]
	var load_problems: Array[String] = directory["load_problems"]
	if listing:
		lines.append_array(list_lines(directory))
		for problem: String in load_problems:
			errors.append("--list-decks: " + problem)
		result["exit"] = EXIT_OK if (presets.size() == names.size() and load_problems.is_empty()) else EXIT_REFUSED
		return result
	var valid_names: String = ", ".join(names)
	var valid_classes: String = ", ".join(CharacterDatabase.ids())
	var chosen_class: String = ""
	if classes.size() > 1:
		errors.append("--class was given %d times; give it once (valid classes: %s)" % [classes.size(), valid_classes])
	elif classes.size() == 1:
		if classes[0] == "":
			errors.append("--class needs a name, as --class=<id> (valid classes: %s)" % valid_classes)
		elif not CharacterDatabase.has(classes[0]):
			errors.append("unknown class '%s' (valid classes: %s)" % [classes[0], valid_classes])
		else:
			chosen_class = classes[0]
	if requested.is_empty():
		result["character"] = chosen_class
		if not errors.is_empty():
			result["exit"] = EXIT_REFUSED
		return result
	if requested.size() > 1:
		errors.append("--deck was given %d times; give it once (valid decks: %s)" % [requested.size(), valid_names])
	elif requested[0] == "":
		errors.append("--deck needs a name, as --deck=<name> (valid decks: %s)" % valid_names)
	elif not names.has(requested[0]):
		errors.append("unknown debug deck '%s' (valid decks: %s)" % [requested[0], valid_names])
	elif not presets.has(requested[0]):
		var why: Array = problems.get(requested[0], [])
		for problem: Variant in why:
			errors.append("debug deck '%s' is invalid: %s" % [requested[0], str(problem)])
	else:
		result["deck"] = requested[0]
		var preset_class: String = RunSession.preset_character(presets[requested[0]] as Dictionary)
		if chosen_class != "" and chosen_class != preset_class:
			errors.append("--deck=%s is a %s deck but --class=%s was given; they must agree (drop one of them)" % [requested[0], preset_class, chosen_class])
		else:
			chosen_class = preset_class
	result["character"] = chosen_class
	if not errors.is_empty():
		result["exit"] = EXIT_REFUSED
	return result


## The deck a new run starts with: the preset's `full` or `starter` list.
static func deck_of(preset: Dictionary, full: bool) -> Array[String]:
	var deck: Array[String] = []
	var source: Array = preset["full"] if full else preset["starter"]
	for card_id: Variant in source:
		deck.append(String(card_id))
	return deck
