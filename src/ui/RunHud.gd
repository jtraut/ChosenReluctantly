extends CanvasLayer
class_name RunHud
## Placeholder "Room X of Y - Type" indicator (Milestone 3a). Plain Label; ux-designer styles it.
## Shown only in run mode; it listens to the sibling RunController's `room_started`.

@onready var label: Label = $Label


func _ready() -> void:
	var controller := get_parent().get_node_or_null("RunController") as RunController
	if controller != null:
		controller.room_started.connect(_on_room_started.bind(controller))


func _on_room_started(_index: int, _total: int, _room_type: String, controller: RunController) -> void:
	label.text = "%s  -  %s" % [controller.room_label(), controller.room_type_name()]
