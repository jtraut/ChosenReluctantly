class_name K1KeyHintScanTest
extends GdUnitTestSuite
## K1 (qa): durable scan. No player-facing string in src/*.gd string literals or data/*.json values may hardcode a
## key for a slot, a mouse button, the dodge key or a modifier combo. Those come from InputLabels (live InputMap).
## Allowed by game-lead's ruling: menu digit navigation is positional, not a slot key ("Keys 1-%d highlight...",
## "Keys 1-%d jump to a column...", the class pick "1 / 2 or the arrow keys").

## Each pattern is a regex over one string (a GDScript literal or a JSON string value).
const FORBIDDEN: Array[String] = [
	"[Ss]lot\\s*%d",           # "Slot %d"
	"[Ss]lot\\s+[0-9]",        # "Slot 3"
	"\\b1\\s*-\\s*[45]\\b",    # "1-5", "1-4" as slot keys
	"\\b(Shift|Ctrl|Alt)\\s*\\+",  # a hardcoded modifier combo
	"\\b[LRM]MB\\b",           # mouse button names
	"((\\b(Press|Hit|Tap|Hold|press|hit|tap|hold)\\s+Space\\b)|(\\bSpace\\s+(to|dodges|rolls)\\b)|^Space$)",  # the dodge key (the game-over / pause hints are checked by allowlist below)
	"\\b[Pp]ress\\s+[0-9A-Z]\\b",
	"\\b[Kk]ey\\s+[0-9]\\b",
]

## Exact strings that are allowed, with the reason.
const ALLOWED_EXACT: Array[String] = [
]

## Files that legitimately produce the text.
const SKIP_FILES: Array[String] = [
	"res://src/core/InputLabels.gd",  # the one place "LMB" / "Shift+" are built
	"res://data/input_bindings.json",
]

const POSITIONAL_MENU: Array[String] = [
	"Keys 1-%d highlight, Enter or click confirms",
	"Keys 1-%d jump to a column, Enter confirms",
]


func _files(dir_path: String, ext: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(ext):
			out.append(dir_path.path_join(f))
	for d in DirAccess.get_directories_at(dir_path):
		_files(dir_path.path_join(d), ext, out)


## String literals of a GDScript source, skipping whole-line comments and trailing comments.
func gd_literals(source: String) -> Array[String]:
	var found: Array[String] = []
	var rx := RegEx.new()
	rx.compile("\"(?:[^\"\\\\]|\\\\.)*\"")
	for line in source.split("\n"):
		var stripped := line.strip_edges()
		if stripped.begins_with("#"):
			continue
		for m in rx.search_all(line):
			found.append(m.get_string())
		# (a trailing "# comment" holding quotes would be scanned too; none today, and a hit is a visible false positive)
	return found


func json_strings(value: Variant, out: Array[String]) -> void:
	match typeof(value):
		TYPE_STRING:
			out.append(String(value))
		TYPE_ARRAY:
			for v: Variant in value as Array:
				json_strings(v, out)
		TYPE_DICTIONARY:
			for v: Variant in (value as Dictionary).values():
				json_strings(v, out)


func hits(text: String) -> Array[String]:
	var res: Array[String] = []
	if ALLOWED_EXACT.has(text.trim_prefix("\"").trim_suffix("\"")):
		return res
	for pattern in FORBIDDEN:
		var rx := RegEx.new()
		rx.compile(pattern)
		if rx.search(text) != null:
			res.append(pattern)
	return res


func test_the_scanner_flags_bad_strings_and_passes_good_ones() -> void:
	for bad in ["Slot %d now", "Slot 3", "Press 1-5 to cast", "Shift+Q swaps", "LMB to attack", "Space to dodge", "Key 2"]:
		assert_array(hits(bad)).override_failure_message("scanner missed: " + bad).is_not_empty()
	for good in ["%s now: %s", "Key %s", "%s (%s)", "Recovery (R)", "%s also resumes", POSITIONAL_MENU[0], POSITIONAL_MENU[1], "Room %d of %d"]:
		assert_array(hits(good)).override_failure_message("false positive: " + good).is_empty()
	assert_array(gd_literals("var a := \"Slot %d\"\n# \"Slot 9\"\n")).has_size(1)


func test_no_gd_string_literal_hardcodes_a_slot_or_input_key_hint() -> void:
	var files: Array[String] = []
	_files("res://src", ".gd", files)
	assert_int(files.size()).is_greater(50)
	var problems: Array[String] = []
	for path in files:
		if SKIP_FILES.has(path):
			continue
		for literal in gd_literals(FileAccess.get_file_as_string(path)):
			if not hits(literal).is_empty():
				problems.append("%s: %s" % [path, literal])
	assert_array(problems).override_failure_message("hardcoded key hints in GDScript:\n" + "\n".join(problems)).is_empty()


func test_no_json_value_hardcodes_a_slot_or_input_key_hint() -> void:
	var files: Array[String] = []
	_files("res://data", ".json", files)
	assert_int(files.size()).is_greater(20)
	var problems: Array[String] = []
	for path in files:
		if SKIP_FILES.has(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_bool(parsed != null).override_failure_message("unparseable: " + path).is_true()
		var strings: Array[String] = []
		json_strings(parsed, strings)
		for s in strings:
			if not hits(s).is_empty():
				problems.append("%s: %s" % [path, s])
	assert_array(problems).override_failure_message("hardcoded key hints in JSON:\n" + "\n".join(problems)).is_empty()


func test_the_positional_menu_hints_are_the_only_digit_range_text_and_stay_positional() -> void:
	var texts: Dictionary = RunConfig.ui()["option"]
	assert_str(String(texts["list_hint"])).is_equal(POSITIONAL_MENU[0])
	assert_str(String(texts["remove_list_hint"])).is_equal(POSITIONAL_MENU[1])
