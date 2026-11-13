class_name Map4ux2Test
extends GdUnitTestSuite
## MAP4 ux 2: the multi-give-up step driven with simulated ui_* key events through the real RunPromptScreen (focus, toggling, Confirm, Cancel).

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
	for id: String in ["a", "b", "c"]:
		var picked: bool = _picks.has(id)
		var full: bool = not picked and _picks.size() >= COST
		options.append({"id": "giveup:" + id, "kind": "giveup", "label": id.to_upper(), "detail": "Rule.", "selected": picked, "enabled": not full,
				"pool": "neutral", "tier_name": "Tier 1", "reason": "Enough picked." if full else ""})
	options.append({"id": "giveup_confirm", "kind": "giveup_confirm", "label": "Give these up and take it", "enabled": _picks.size() == COST,
			"reason": "" if _picks.size() == COST else "Pick more."})
	options.append({"id": "giveup_cancel", "kind": "back", "label": "Cancel", "enabled": true})
	return {"title": "Give up relics", "subtitle": "", "options": options, "relic": {"choice": "giveup", "incoming": {"name": "Hostile Takeover"}}}


## What the controller does with a pick: toggle it and refill the same screen; Confirm and Cancel just get logged.
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
	var buttons: Array = _screen._option_buttons
	var index: int = buttons.find(owner)
	return "" if index < 0 else String((_screen._options[index] as Dictionary).get("id", ""))


func test_the_step_opens_on_cancel_and_enter_there_gives_nothing_up() -> void:
	await _open()
	assert_str(_focused_id()).is_equal("giveup_cancel")
	await _press(&"ui_accept")
	assert_array(_log).is_equal(["giveup_cancel"])
	assert_array(_picks).is_empty()


func test_up_from_cancel_enters_the_relics_and_the_toggled_relic_keeps_the_focus() -> void:
	await _open()
	await _press(&"ui_up")
	var first: String = _focused_id()
	assert_bool(first.begins_with("giveup:")).override_failure_message("Up from Cancel landed on %s" % first).is_true()
	await _press(&"ui_accept")  # pick
	assert_array(_picks).has_size(1)
	assert_str(_focused_id()).override_failure_message("focus left the relic just picked: %s" % _focused_id()).is_equal(first)
	await _press(&"ui_accept")  # unpick
	assert_array(_picks).is_empty()
	assert_str(_focused_id()).is_equal(first)
	await _press(&"ui_accept")  # pick again
	await _press(&"ui_left")
	var second: String = _focused_id()
	assert_bool(second.begins_with("giveup:") and second != first).is_true()
	await _press(&"ui_accept")
	assert_array(_picks).has_size(COST)
	assert_str(_focused_id()).is_equal(second)  # the last pick keeps the highlight too


func test_confirm_is_reachable_by_keyboard_once_enough_are_picked_and_enter_confirms() -> void:
	await _open()
	await _press(&"ui_up")
	await _press(&"ui_accept")
	await _press(&"ui_left")
	await _press(&"ui_accept")
	assert_array(_picks).has_size(COST)
	await _press(&"ui_down")
	var reached: Array[String] = [_focused_id()]
	await _press(&"ui_left")
	reached.append(_focused_id())
	assert_array(reached).contains(["giveup_confirm"])
	assert_str(_focused_id()).is_equal("giveup_confirm")
	await _press(&"ui_accept")
	assert_array(_log.filter(func(entry: String) -> bool: return entry == "giveup_confirm")).has_size(1)


func test_a_greyed_confirm_can_be_read_but_enter_on_it_does_nothing() -> void:
	await _open()
	await _press(&"ui_up")
	await _press(&"ui_accept")  # one of two picked: Confirm is still off
	await _press(&"ui_down")
	await _press(&"ui_left")
	assert_str(_focused_id()).is_equal("giveup_confirm")
	var logged: int = _log.size()
	await _press(&"ui_accept")
	assert_int(_log.size()).is_equal(logged)
	assert_array(_picks).has_size(1)


func test_cancel_after_picking_reports_cancel_only_and_gives_nothing_up() -> void:
	await _open()
	await _press(&"ui_up")
	await _press(&"ui_accept")
	await _press(&"ui_left")
	await _press(&"ui_accept")
	assert_array(_picks).has_size(COST)
	await _press(&"ui_down")
	await _press(&"ui_right")
	assert_str(_focused_id()).is_equal("giveup_cancel")
	await _press(&"ui_accept")
	assert_str(_log[_log.size() - 1]).is_equal("giveup_cancel")
	assert_array(_log.filter(func(entry: String) -> bool: return entry == "giveup_confirm")).is_empty()
