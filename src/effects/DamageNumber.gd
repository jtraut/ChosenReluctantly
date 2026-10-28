extends Label3D
class_name DamageNumber
## Floating combat text: rises and fades, then frees itself. Size, outline, colour,
## timing and the anti-spam numbers come from data/ui.json "damage_numbers"
## (UiConfig). A hit right next to a young number of the same type merges into it.

## A merged number's clock is pulled back to at most this fraction of its life.
const MERGE_REFRESH := 0.3

var damage_type: String = ""
var _elapsed: float = 0.0
var _duration: float = 0.8
var _rise: float = 1.2
var _start_pos: Vector3
var _total: float = 0.0
var _base_scale: float = 1.0
var _big_scale: float = 1.35
var _is_word: bool = false


# ---- Pure rules (unit-tested) ----

## Index of the entry a new hit should merge into, or -1. An entry is
## {"pos": Vector3, "type": String, "idle": float} (seconds since it was last hit). Only the
## same damage type, on the ground plane within `radius`, idle under `window`; the nearest wins.
static func find_merge_index(entries: Array, pos: Vector3, type: String, radius: float, window: float) -> int:
	var best: int = -1
	var best_dist: float = radius
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		if String(entry["type"]) != type or float(entry["idle"]) >= window:
			continue
		var at: Vector3 = entry["pos"]
		var dist: float = Vector2(at.x - pos.x, at.z - pos.z).length()
		if dist <= best_dist:
			best = i
			best_dist = dist
	return best


## How many of the oldest numbers must go so that one more fits under `cap`.
static func evict_count(live: int, cap: int) -> int:
	return maxi(live - maxi(cap, 1) + 1, 0)


## The colour of a number: the damage type's element colour, lightened toward white so the
## flat outline does the contrast work on any floor.
static func color_for(type: String, lighten: float) -> Color:
	return ElementVisuals.color_for_damage_type(type).lerp(Color.WHITE, clampf(lighten, 0.0, 1.0))


# ---- Lifecycle ----

## Applies the shared style from data. Call right after instantiating.
func configure(cfg: Dictionary) -> void:
	font_size = int(cfg["font_size"])
	pixel_size = float(cfg["pixel_size"])
	outline_size = int(cfg["outline_size"])
	outline_modulate = Color.html(String(cfg["outline_color"]))
	render_priority = int(cfg["render_priority"])
	outline_render_priority = render_priority - 1
	_duration = float(cfg["duration"])
	_rise = float(cfg["rise_distance"])
	_big_scale = float(cfg["big_scale"])


## Called after global_position is already set to the spawn point - this is
## also where _start_pos is captured, not _ready(), since _ready() runs
## during add_child(), before the caller has had a chance to position us.
func show_amount(amount: float, type: String, color: Color, is_big: bool) -> void:
	damage_type = type
	_total = amount
	text = str(roundi(_total))
	modulate = color
	_base_scale = _big_scale if is_big else 1.0
	scale = Vector3.ONE * _base_scale
	_start_pos = global_position


## Adds another hit of the same type into this number and keeps it on screen a little longer.
func merge_hit(amount: float, is_big: bool) -> void:
	_total += amount
	text = str(roundi(_total))
	_elapsed = minf(_elapsed, _duration * MERGE_REFRESH)
	if is_big:
		_base_scale = _big_scale
		scale = Vector3.ONE * _base_scale


## Seconds since this number was spawned or last merged into.
func idle_time() -> float:
	return _elapsed


## A word instead of a damage number (the IMMUNE popup): same style, one priority above the numbers
## so it is never covered by one, and its own scale.
func show_text(words: String, color: Color, text_scale: float) -> void:
	_is_word = true
	text = words
	modulate = color
	scale = Vector3.ONE * text_scale
	render_priority += 1
	outline_render_priority = render_priority - 1
	_start_pos = global_position


func is_word() -> bool:
	return _is_word


func _process(delta: float) -> void:
	_elapsed += delta
	var t := _elapsed / _duration
	if t >= 1.0:
		queue_free()
		return
	global_position = _start_pos + Vector3(0.0, _rise * t, 0.0)
	modulate.a = 1.0 - t * t  # holds, then drops away: easier to read than a linear fade
