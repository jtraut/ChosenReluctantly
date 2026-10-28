extends Node
## Autoload "Settings": the one place game code and the settings screen read and change
## player settings. A thin wrapper over SettingsStore (all the logic and validation live
## there, with injectable paths for tests). Reads user://settings.cfg at startup; a bad
## file is reported with push_error and the defaults are used.
##
## UI usage (Slice 6b): Settings.get_string("cast_trigger"), Settings.get_definition(...)
## for the options and labels, Settings.set_value(...), then Settings.save().
## set_value never writes the file; save() does.

signal changed(key: String, value: Variant)

const CAST_TRIGGER := "cast_trigger"
const TRIGGER_RELEASE := "release"
const TRIGGER_PRESS := "press"

var store: SettingsStore = null


func _init() -> void:
	use_store(SettingsStore.new())


func _enter_tree() -> void:
	report_problems(store)


## push_errors every problem found loading `of` (fail loud; the defaults are used anyway).
func report_problems(of: SettingsStore) -> void:
	for problem: String in of.problems:
		push_error("Settings: " + problem)


## Swaps the backing store (tests inject one with temp paths; production uses the default).
func use_store(new_store: SettingsStore) -> void:
	if store != null and store.changed.is_connected(_on_store_changed):
		store.changed.disconnect(_on_store_changed)
	store = new_store
	store.changed.connect(_on_store_changed)


## Back to the real files (defaults + user://settings.cfg).
func use_default_store() -> void:
	use_store(SettingsStore.new())


func _on_store_changed(key: String, value: Variant) -> void:
	changed.emit(key, value)


func get_value(key: String) -> Variant:
	return store.get_value(key)


func get_string(key: String) -> String:
	return store.get_string(key)


func get_bool(key: String) -> bool:
	return store.get_bool(key)


## False for an unknown key or an invalid value; nothing changes then. Memory only.
func set_value(key: String, value: Variant) -> bool:
	return store.set_value(key, value)


func save() -> bool:
	return store.save()


func reset_to_defaults() -> void:
	store.reset_to_defaults()


func keys() -> Array[String]:
	return store.keys()


func get_definition(key: String) -> Dictionary:
	return store.get_definition(key)


## "release" (default: hold shows the preview, release casts) or "press".
func cast_trigger() -> String:
	return store.get_string(CAST_TRIGGER)


func casts_on_release() -> bool:
	return cast_trigger() == TRIGGER_RELEASE
