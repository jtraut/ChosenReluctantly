class_name Map4QaUiTest
extends GdUnitTestSuite
## MAP4 qa: the multi-give-up step with every pick made and the rest greyed, then moving focus (the gap map4ux2_test does not cover):
## focus must never be lost or trapped, a greyed tile can be read but does nothing, and a picked tile still unpicks.

const COST: int = 2

var _picks: Array[String] = []
var _log: Array[String] = []
var _screen: RunPromptScreen


func before_test() -> void:
	RunConfig.reset_cache()
	_picks.clear()
	_log.clear()


func _content() -> Dictionary:
	var options: Array[Dictionary] = []
	for id: String in ["a", "b", "c", "d"]:
		var picked: bool = _picks.has(id)
		var full: bool = not picked and _picks.size() >= COST
		options.append({"id": "giveup:" + id, "kind": "giveup", "label": id.to_upper(), "detail": "Rule.", "selected": picked, "enabled": not full,
				"pool": "neutral", "tier_name": "Tier 1", "reason": "Enough picked." if full else ""})
	options.append({"id": "giveup_confirm", "kind": "giveup_confirm", "label": "Give these up and take it", "enabled": _picks.size() == COST,
			"reason": "" if _picks.size() == COST else "Pick more."})
	options.append({"id": "giveup_cancel", "kind": "back", "label": "Cancel", "enabled": true})
	return {"title": "Give up relics", "subtitle": "", "options": options, "relic": {"choice": "giveup", "incoming": {"name": "Hostile Takeover"}}}


func _on_chosen(option_id: String) -> void:
	_log.append(option_id)
	if option_id.begins_with("giveup:"):
		var id: String = option_id.trim_prefix("giveup:")
		if _picks.has(id):
			_picks.erase(id)
		else:
			_picks.append(id)
		_screen.show_content(_content())


func _open() -> void:
	_screen = (load("res://scenes/ui/RunPromptScreen.tscn") as PackedScene).instantiate() as RunPromptScreen
	add_child(_screen)
	auto_free(_screen)
	await get_tree().process_frame
	_screen.option_chosen.connect(_on_chosen)
	_screen.show_content(_content())
	_screen.disarm()
	await get_tree().process_frame


func _press(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_viewport().push_input(event)
	await get_tree().process_frame


func _focused_id() -> String:
	var owner: Control = _screen.get_viewport().gui_get_focus_owner()
	var index: int = (_screen._option_buttons as Array).find(owner)
	return "" if index < 0 else String((_screen._options[index] as Dictionary).get("id", ""))


func test_with_every_pick_made_focus_is_never_lost_and_every_control_stays_reachable() -> void:
	await _open()
	await _press(&"ui_up")
	await _press(&"ui_accept")  # pick the first tile
	await _press(&"ui_left")
	await _press(&"ui_right")
	var first: String = _focused_id()
	for i in range(4):  # walk until a second tile is picked
		if _picks.size() >= COST:
			break
		await _press(&"ui_right")
		if _focused_id().begins_with("giveup:") and not _picks.has(_focused_id().trim_prefix("giveup:")):
			await _press(&"ui_accept")
	assert_array(_picks).has_size(COST)
	var seen: Dictionary = {}
	for action: StringName in [&"ui_left", &"ui_left", &"ui_left", &"ui_left", &"ui_left", &"ui_left", &"ui_right", &"ui_right", &"ui_right", &"ui_right", &"ui_right", &"ui_right", &"ui_down", &"ui_up", &"ui_down", &"ui_left", &"ui_up", &"ui_right"]:
		await _press(action)
		var id: String = _focused_id()
		assert_str(id).override_failure_message("focus was lost after %s (picked %s, first %s)" % [action, str(_picks), first]).is_not_empty()
		seen[id] = true
	for must: String in ["giveup_confirm", "giveup_cancel"]:
		assert_bool(seen.has(must)).override_failure_message("never reached %s; reached %s" % [must, str(seen.keys())]).is_true()
	var greyed: Array[String] = []
	for id: String in ["a", "b", "c", "d"]:
		if not _picks.has(id):
			greyed.append("giveup:" + id)
	assert_bool(greyed.any(func(id: String) -> bool: return seen.has(id))).override_failure_message("a greyed tile can't be read by keyboard: %s" % str(seen.keys())).is_true()


func test_enter_on_a_greyed_tile_does_nothing_and_enter_on_a_picked_tile_unpicks_it_and_reopens_the_rest() -> void:
	await _open()
	await _press(&"ui_up")
	var target_a: String = _focused_id()
	await _press(&"ui_accept")
	var picked_second: bool = false
	for i in range(6):
		await _press(&"ui_right")
		var id: String = _focused_id()
		if id.begins_with("giveup:") and id != target_a and not picked_second:
			await _press(&"ui_accept")
			picked_second = true
			break
	assert_array(_picks).has_size(COST)
	# find a greyed tile by walking, press Enter on it
	var logged: int = _log.size()
	var found_greyed: bool = false
	for i in range(8):
		await _press(&"ui_right")
		var id: String = _focused_id()
		if id.begins_with("giveup:") and not _picks.has(id.trim_prefix("giveup:")):
			found_greyed = true
			await _press(&"ui_accept")
			break
	assert_bool(found_greyed).is_true()
	assert_int(_log.size()).override_failure_message("Enter on a greyed tile was reported: %s" % str(_log)).is_equal(logged)
	assert_array(_picks).has_size(COST)
	# unpick one: the others are enabled again
	var unpicked: String = ""
	for i in range(8):
		await _press(&"ui_left")
		var id: String = _focused_id()
		if id.begins_with("giveup:") and _picks.has(id.trim_prefix("giveup:")):
			unpicked = id
			await _press(&"ui_accept")
			break
	assert_str(unpicked).is_not_empty()
	assert_array(_picks).has_size(COST - 1)
	assert_str(_focused_id()).is_equal(unpicked)
	var enabled_tiles: int = 0
	for option: Dictionary in (_screen._options as Array):
		if String(option["id"]).begins_with("giveup:") and bool(option["enabled"]):
			enabled_tiles += 1
	assert_int(enabled_tiles).is_equal(4)
