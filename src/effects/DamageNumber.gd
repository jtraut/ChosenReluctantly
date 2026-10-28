extends Label3D
class_name DamageNumber
## Floating combat text: rises and fades over DURATION, then frees itself.

const RISE_DISTANCE := 1.2
const DURATION := 0.7

var _elapsed: float = 0.0
var _start_pos: Vector3


## Called after global_position is already set to the spawn point - this is
## also where _start_pos is captured, not _ready(), since _ready() runs
## during add_child(), before the caller has had a chance to position us.
func show_amount(amount: float, damage_type: String) -> void:
	text = str(roundi(amount))
	modulate = _color_for(damage_type)
	_start_pos = global_position


## A word instead of a damage number (the IMMUNE popup): smaller, same rise and fade.
func show_text(words: String, color: Color, text_scale: float) -> void:
	text = words
	modulate = color
	scale = Vector3.ONE * text_scale
	_start_pos = global_position


func _process(delta: float) -> void:
	_elapsed += delta
	var t := _elapsed / DURATION
	if t >= 1.0:
		queue_free()
		return
	global_position = _start_pos + Vector3(0.0, RISE_DISTANCE * t, 0.0)
	modulate.a = 1.0 - t


func _color_for(damage_type: String) -> Color:
	match damage_type:
		"fire":
			return Color(1.0, 0.55, 0.15)
		_:
			return Color(1.0, 1.0, 1.0)
