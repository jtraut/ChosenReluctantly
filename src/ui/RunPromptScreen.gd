extends CanvasLayer
class_name RunPromptScreen
## Placeholder full-screen prompt with a title, a line and one button (Milestone 3a): the "Room cleared /
## Continue" screen and the run-won screen are two instances (`kind`). Plain Labels and a Button; ux-designer
## styles them. Its root swallows mouse input so clicks never reach the world. Hidden until the sibling
## RunController signals; the button calls back into the controller or Main.

## "cleared": shown on RunController.room_cleared, button = continue. "win": shown on run_won, button = new run.
@export var kind: String = "cleared"

signal confirmed()

@onready var title_label: Label = $Root/Center/Column/Title
@onready var line_label: Label = $Root/Center/Column/Line
@onready var button: Button = $Root/Center/Column/Action

var _controller: RunController = null


func _ready() -> void:
	visible = false
	button.pressed.connect(_on_pressed)
	_controller = get_parent().get_node_or_null("RunController") as RunController
	if _controller == null:
		return
	if kind == "win":
		_controller.run_won.connect(_show_win)
	else:
		_controller.room_cleared.connect(_show_cleared)


func _show_cleared(summary: Dictionary) -> void:
	var text: Dictionary = RunConfig.ui()["room_cleared"]
	title_label.text = String(text["title"])
	var line: String = "HP %d / %d" % [roundi(float(summary["hp"])), roundi(float(summary["max_hp"]))]
	if float(summary["healed"]) > 0.0:
		line = String(text["rest_line"]) % roundi(float(summary["healed"])) + "\n" + line
	line_label.text = line
	button.text = String(text["button"])
	_open()


func _show_win() -> void:
	var text: Dictionary = RunConfig.ui()["win"]
	title_label.text = String(text["title"])
	line_label.text = String(text["line"])
	button.text = String(text["button"])
	_open()


func _open() -> void:
	visible = true
	button.grab_focus()


func _on_pressed() -> void:
	if not visible:
		return
	visible = false
	confirmed.emit()
	if _controller == null:
		return
	if kind == "win":
		(get_parent() as Main).restart_arena()  # a new run with a new seed
	else:
		_controller.continue_to_next_room()
