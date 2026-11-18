class_name StartScreen
extends CanvasLayer
## PLACEHOLDER start screen (3d sitting C; ux-designer replaces it in sitting D). From run 2 on, before a run: start with the preset deck, a saved loadout, or edit a loadout.
## The last used choice is preselected, so one Enter starts. It pauses the game through GamePause like the class pick, opens after the class pick resolves (also in the scene a
## class change rebuilds), and never opens in headless runs, scripts, scenarios or any launch with a loadout or debug deck forced. All its data is `LoadoutChoices.start_choices`
## and its one action is `RunController.confirm_start_choice(slot)`; both are what ux's screen uses too.

signal opened()
## A start choice was confirmed (the slot, LoadoutStore.PRESET for the preset).
signal confirmed(slot: int)

## Tests: true/false forces the "real game" part of the decision; null = decide from how the game was launched.
static var enabled_override: Variant = null

var _controller: RunController = null
var _choices: Dictionary = {}
var _armed_at_msec: int = 0
var _paused_here: bool = false
var _confirming: bool = false
var _hidden_hud: CanvasLayer = null
var _editor: LoadoutEditorScreen = null
var _root: Control = null
var _column: VBoxContainer = null
var _buttons: Array[Button] = []
var _message_label: Label = null


static func reset() -> void:
	enabled_override = null


## Whether the screen should open for this run state: a real interactive game, and `LoadoutSession.start_screen_wanted` (run 2 or later, a fresh run start, nothing forced).
static func should_open(state: RunState) -> bool:
	if enabled_override != null:
		return bool(enabled_override) and LoadoutSession.start_screen_wanted(state)
	if DisplayServer.get_name() == "headless" or not ClassPickScreen.interactive() or (ClassPickScreen.enabled_override != null and not bool(ClassPickScreen.enabled_override)):
		return false  # a capture or tool that turned the class pick off wants no prompt over its shot
	if RunSession.character_forced and LoadoutSession.faked_runs < 0 and not LoadoutSession.profile_path_named:
		return false  # `--class=` skips the class pick and its start screen too, unless the launch asked for run 2 itself (`--runs-finished=`, `--profile-path=`)
	return LoadoutSession.start_screen_wanted(state)


func _ready() -> void:
	visible = false
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_open_when_wired.call_deferred()


func _exit_tree() -> void:
	_restore_hud()
	if _paused_here and not _confirming:
		_paused_here = false
		GamePause.resume()


func _open_when_wired() -> void:
	var main := get_parent() as Main
	if main == null or main.run_controller == null:
		queue_free()
		return
	_controller = main.run_controller
	var pick := main.get_node_or_null("ClassPickScreen") as ClassPickScreen
	if pick != null and pick.is_open():
		pick.confirmed.connect(_on_pick_confirmed, CONNECT_ONE_SHOT)  # the start screen follows the class pick
		return
	if should_open(_controller.state()):
		open()


func _on_pick_confirmed(_character_id: String) -> void:
	# A different class rebuilds the run in a fresh scene, which opens its own start screen; only the same class carries on here.
	if _controller == null or RunSession.current != _controller.state():
		return
	_open_after_pick.call_deferred()


func _open_after_pick() -> void:
	if _controller != null and should_open(_controller.state()):
		open()


func open() -> void:
	if _controller == null:
		return
	_confirming = false
	_choices = LoadoutChoices.start_choices(_controller.character_id())
	_rebuild()
	visible = true
	_hide_hud()
	_paused_here = GamePause.pause()
	var delay: float = float(UiConfig.run_ui().get("prompt_option_arm_delay", 0.4))
	_armed_at_msec = Time.get_ticks_msec() + roundi(delay * 1000.0)
	_focus_last_used()
	opened.emit()


func is_open() -> bool:
	return visible


func options_armed() -> bool:
	return Time.get_ticks_msec() >= _armed_at_msec


## Skips the arm delay (tests and scripted input).
func disarm() -> void:
	_armed_at_msec = 0


## The model the screen is showing (LoadoutChoices.start_choices).
func choices() -> Dictionary:
	return _choices


## Confirms a choice: LoadoutStore.PRESET or a usable loadout slot. Ignored before the arm delay and while confirming.
func choose(slot: int) -> void:
	if not visible or _confirming or not options_armed() or _controller == null:
		return
	if not _controller.confirm_start_choice(slot):
		return
	confirmed.emit(slot)
	if slot == LoadoutStore.PRESET:
		close()
	else:
		_confirming = true  # the run is rebuilt as a fresh scene (deferred); stay up and dim until it replaces this one


func close() -> void:
	visible = false
	_restore_hud()
	if _paused_here:
		_paused_here = false
		GamePause.resume()


## Opens the bare editor over this screen. When it closes the choices are rebuilt, so a saved loadout shows at once.
func open_editor() -> void:
	if _editor != null or _controller == null:
		return
	_editor = LoadoutEditorScreen.new()
	_editor.setup(_controller.character_id(), LoadoutSession.store())
	_editor.closed.connect(_on_editor_closed)
	add_child(_editor)


func _on_editor_closed() -> void:
	_editor = null
	_choices = LoadoutChoices.start_choices(_controller.character_id())
	_rebuild()
	_focus_last_used()


func _input(event: InputEvent) -> void:
	if not visible or _editor != null:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and (key.keycode == KEY_SPACE or _confirming):
		get_viewport().set_input_as_handled()  # Space is the Movement card key: it must never start a run


func _hide_hud() -> void:
	var main := get_parent() as Main
	if main == null or main.hud == null or _hidden_hud != null or not main.hud.visible:
		return
	_hidden_hud = main.hud
	_hidden_hud.visible = false


func _restore_hud() -> void:
	if _hidden_hud != null and is_instance_valid(_hidden_hud):
		_hidden_hud.visible = true
	_hidden_hud = null


# ---- building ----

func _build() -> void:
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.8)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_column = VBoxContainer.new()
	_column.custom_minimum_size = Vector2(420.0, 0.0)
	center.add_child(_column)


func _rebuild() -> void:
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	_buttons.clear()
	var title := Label.new()
	title.text = "Start a run as %s" % String(_choices["character_name"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_column.add_child(title)
	var preset: Dictionary = _choices["preset"]
	_add_button("%s (%d cards)" % [String(preset["name"]), int(preset["deck_size"])], LoadoutStore.PRESET)
	for loadout: Dictionary in (_choices["loadouts"] as Array):
		var text: String = "Loadout %d: %s (%d cards" % [int(loadout["slot"]) + 1, String(loadout["name"]), int(loadout["deck_size"])]
		if int(loadout["plan_size"]) > 0:
			text += ", plan %d" % int(loadout["plan_size"])
		if not String(loadout["starter_relic"]).is_empty():
			text += ", " + String(loadout["starter_relic_name"])
		_add_button(text + ")", int(loadout["slot"]))
	for skipped: Dictionary in (_choices["flagged"] as Array):
		var label := Label.new()
		label.text = "Loadout %d skipped: %s" % [int(skipped["slot"]) + 1, String(skipped["message"])]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.modulate = Color(1.0, 0.6, 0.5)
		_column.add_child(label)
	var edit := Button.new()
	edit.text = "Edit or create a loadout"
	edit.pressed.connect(open_editor)
	_column.add_child(edit)
	_buttons.append(edit)
	_message_label = Label.new()
	_message_label.text = "\n".join(PackedStringArray(_choices["messages"]))
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.visible = not (_choices["messages"] as Array).is_empty()
	_column.add_child(_message_label)


func _add_button(text: String, slot: int) -> void:
	var button := Button.new()
	button.text = text
	button.set_meta("slot", slot)
	button.pressed.connect(choose.bind(slot))
	_column.add_child(button)
	_buttons.append(button)


## The slots the buttons start, in order (tests).
func choice_slots() -> Array[int]:
	var out: Array[int] = []
	for button in _buttons:
		if button.has_meta("slot"):
			out.append(int(button.get_meta("slot")))
	return out


func _focus_last_used() -> void:
	var wanted: int = int(_choices.get("last_used", LoadoutStore.PRESET))
	for button in _buttons:
		if button.has_meta("slot") and int(button.get_meta("slot")) == wanted:
			button.grab_focus()
			return
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


## The slot that has the focus (tests); LoadoutArgs.NO_SLOT when none does.
func focused_slot() -> int:
	for button in _buttons:
		if button.has_focus() and button.has_meta("slot"):
			return int(button.get_meta("slot"))
	return LoadoutArgs.NO_SLOT
