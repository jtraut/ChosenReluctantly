class_name WatchMode
extends RefCounted
## TL2, watch-the-bot mode: the wave sim's whole-run bot (-Run) played in a window, saving screenshots at key moments to a folder
## (--watch-shots=<dir>) and writing a text log the playtester can quote. This class is the pure half (argument parsing, file naming, log
## wording) plus the file output; the moments themselves are chosen in tools/wave_sim.gd, and nothing here runs unless the flag is given,
## so the headless sim is untouched. A debug tool: it never touches the save, profile or loadouts.

const ARG_PREFIX := "--watch-shots="

## The folder every shot and the log go under (one sub-folder per run: "<class>-seed<N>").
var out_dir: String = ""
var run_seed: int = 0
var class_id: String = ""

var _shot_index: int = 0
var _log_path: String = ""


## The directory named by --watch-shots=<dir> in `args`, "" when the flag is absent. An empty value (`--watch-shots=`) is returned as "" too:
## callers treat that as a refusal, see `is_bare`.
static func parse_dir(args: Array) -> String:
	for arg: Variant in args:
		var text: String = String(arg)
		if text.begins_with(ARG_PREFIX):
			return text.substr(ARG_PREFIX.length()).strip_edges()
	return ""


## True when the flag is present but names no folder.
static func is_bare(args: Array) -> bool:
	for arg: Variant in args:
		if String(arg).begins_with(ARG_PREFIX):
			return parse_dir(args) == ""
	return false


## A file-name-safe lower-case word: letters, digits and dashes only, runs of anything else become one dash.
static func slug(text: String) -> String:
	var out: String = ""
	var last_dash: bool = true
	for i: int in range(text.length()):
		var c: String = text.substr(i, 1).to_lower()
		var is_word: bool = (c >= "a" and c <= "z") or (c >= "0" and c <= "9")
		if is_word:
			out += c
			last_dash = false
		elif not last_dash:
			out += "-"
			last_dash = true
	return out.trim_suffix("-")


## "<dir>/<class>-seed<N>/<NN>-<label>.png". `index` counts from 1 and is zero-padded so a folder listing reads in play order; 0 leaves the prefix off (a shot that is overwritten).
static func shot_path(dir: String, class_name_in: String, seed_in: int, index: int, label: String) -> String:
	var name: String = slug(label)
	if name == "":
		name = "shot"
	var prefix: String = "%02d-" % index if index > 0 else ""
	return "%s/%s-seed%d/%s%s.png" % [dir.trim_suffix("/").trim_suffix("\\"), slug(class_name_in), seed_in, prefix, name]


## One option as the log quotes it: "id (label)", plus " [locked]" when it is not enabled.
static func option_text(option: Dictionary) -> String:
	var label: String = String(option.get("label", ""))
	var text: String = String(option.get("id", "?"))
	if label != "":
		text += " (%s)" % label
	if option.has("enabled") and not bool(option["enabled"]):
		text += " [locked]"
	return text


## "a; b; c" of every option, for the offers line.
static func offers_text(options: Array) -> String:
	var parts: Array[String] = []
	for option: Variant in options:
		parts.append(option_text(option as Dictionary))
	return "; ".join(parts)


## "Name x2, Other, ..." of a deck (ids), in first-seen order. `names` maps card id to display name (an id missing from it prints as the id).
static func deck_text(deck: Array[String], names: Dictionary) -> String:
	var order: Array[String] = []
	var counts: Dictionary = {}
	for id: String in deck:
		if not counts.has(id):
			order.append(id)
			counts[id] = 0
		counts[id] = int(counts[id]) + 1
	var parts: Array[String] = []
	for id: String in order:
		var shown: String = String(names.get(id, id))
		parts.append(shown if int(counts[id]) == 1 else "%s x%d" % [shown, int(counts[id])])
	return ", ".join(parts)


## Starts a run's folder and log: `begin` once per run. Clears an old log of the same seed so a rerun does not append to it.
func begin(dir: String, class_name_in: String, seed_in: int) -> void:
	out_dir = dir
	class_id = class_name_in
	run_seed = seed_in
	_shot_index = 0
	var folder: String = "%s/%s-seed%d" % [dir.trim_suffix("/").trim_suffix("\\"), slug(class_name_in), seed_in]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	_log_path = folder + "/log.txt"
	var file: FileAccess = FileAccess.open(_log_path, FileAccess.WRITE)
	if file != null:
		file.close()


## Prints one "WATCH ..." line and appends it to the run's log.txt.
func say(text: String) -> void:
	print("WATCH " + text)
	if _log_path == "":
		return
	var file: FileAccess = FileAccess.open(_log_path, FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(text)
	file.close()


## Saves the current viewport as the next numbered shot (`fixed_name` "" = numbered by order; else that name is overwritten, for "the most crowded so far").
## Await it: it waits for the frame to be drawn. Returns the saved path, "" when the viewport has no image (a headless run).
func shoot(tree: SceneTree, label: String, fixed_name: String = "") -> String:
	await RenderingServer.frame_post_draw
	var image: Image = tree.root.get_viewport().get_texture().get_image()
	if image == null:
		push_error("WatchMode: no image (headless has no renderer; run windowed)")
		return ""
	var path: String
	if fixed_name == "":
		_shot_index += 1
		path = shot_path(out_dir, class_id, run_seed, _shot_index, label)
	else:
		path = shot_path(out_dir, class_id, run_seed, 0, fixed_name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err: Error = image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("WatchMode: failed to save '%s' (error %d)" % [path, err])
		return ""
	return path
