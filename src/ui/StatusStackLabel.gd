class_name StatusStackLabel
extends Label3D
## BD3a: the stack count over an enemy ("Bleed x3", "Bleed x5 MAX" at the cap) and the detonate cue. A child of an enemy's HP bar,
## signal-driven: it reads `stacks_of` / `max_stacks_of` and the status names from data, and hides while nothing stacks.
## Text and sizes live in data/ui.json `status_stacks`. The count is words, so it does not rely on colour.

const GROUP := &"status_stack_labels"

var _status: StatusEffectManager = null
var _cfg: Dictionary = {}
var _base_height: float = 0.0
## Current rise (world metres) over the base height, eased toward what clears the labels below this one.
var _lift: float = 0.0
## MAP3b: the text's size, worked out when the text changes (not per frame per neighbour), and every live label in one array (no per-frame group query).
var _text_size: Vector2 = Vector2.ZERO
var _size_text: String = ""
static var _live: Array[StatusStackLabel] = []


# ---- Pure rules (unit-tested) ----

## One line, for example "Bleed x3" (and "Bleed x5 MAX" when the stack count has hit its cap).
static func line_text(display_name: String, stacks: int, max_stacks: int, cfg: Dictionary) -> String:
	var text: String = String(cfg["count_format"]) % [display_name, stacks]
	if max_stacks > 0 and stacks >= max_stacks:
		text += String(cfg["max_suffix"])
	return text


## Whether a status shows a count: only once it stacks (`min_stacks`, 2), so a lone Burn shows nothing extra.
static func shows(stacks: int, cfg: Dictionary) -> bool:
	return stacks >= int(cfg["min_stacks"])


## The whole label: one line per stacking status, ordered by id so two statuses never swap places. entries are
## {"id": String, "name": String, "stacks": int, "max": int}.
static func compose(entries: Array, cfg: Dictionary) -> String:
	var shown: Array[Dictionary] = []
	for entry: Variant in entries:
		var row: Dictionary = entry
		if shows(int(row["stacks"]), cfg):
			shown.append(row)
	shown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) < String(b["id"]))
	var lines: Array[String] = []
	for row: Dictionary in shown:
		lines.append(line_text(String(row["name"]), int(row["stacks"]), int(row["max"]), cfg))
	return "\n".join(lines)


## MB1 ux: how far (camera-plane metres) the label of the enemy that is higher on screen must rise to clear the one below it. `dx` and `dy` are
## the camera-plane offset from the lower label to this one (dy >= 0 means this one is the upper), `half_w` and `half_h` the summed half sizes of the
## two texts, `pad` a small gap. 0 when they do not overlap horizontally or this label is already clear. Two neighbours' "Bleed x5 MAX" lines printed over
## each other because enemies a body apart stand within one text height on screen.
static func lift_over(dx: float, dy: float, half_w: float, half_h: float, pad: float) -> float:
	if dy < 0.0 or absf(dx) >= half_w:
		return 0.0
	return maxf(half_h + pad - dy, 0.0)


## The size in camera-plane metres of a label's text (Label3D.get_aabb is a cube, so it cannot say): a line is `font_size` x `pixel_size` high with a
## little leading, and a glyph averages about 0.55 of that wide. Close enough to tell whether two labels touch.
static func text_size(text: String, font_size: int, pixel_size: float) -> Vector2:
	var line_m: float = float(font_size) * pixel_size
	var lines: PackedStringArray = text.split("
")
	var longest: int = 0
	for line: String in lines:
		longest = maxi(longest, line.length())
	return Vector2(float(longest) * line_m * 0.55, float(maxi(lines.size(), 1)) * line_m * 1.15)


## MB1 ux: whether a damage number's text box touches a stack label's. Offsets are camera-plane metres from the label to the number; the half sizes are
## each text's half width and half height. A neighbour's number rising through the label of the enemy in front used to print over it.
static func covers(dx: float, dy: float, half_w: float, half_h: float) -> bool:
	return absf(dx) < half_w and absf(dy) < half_h


## True for a number that belongs to this label's own enemy: it spawned within `own_radius` of it on the ground (numbers rise straight up) and is not a word popup.
static func is_own_number(flat_distance: float, is_word: bool, own_radius: float) -> bool:
	return not is_word and flat_distance < own_radius


## One step of the label's alpha: down to `dim` (data number_dim_alpha) while a number covers it, back to 1 after, at `speed` alpha per second.
static func alpha_step(current: float, covered: bool, dim: float, speed: float, delta: float) -> float:
	return move_toward(current, dim if covered else 1.0, speed * delta)


## The word shown with a detonation, for example "Bleed detonated".
static func detonate_word(display_name: String, cfg: Dictionary) -> String:
	return String(cfg["detonate_word"]) % display_name


# ---- Lifecycle ----

## Call right after add_child.
func setup(status: StatusEffectManager, height: float = -1.0) -> void:
	_cfg = UiConfig.status_stacks()
	_status = status
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = false
	font_size = int(_cfg["font_size"])
	pixel_size = float(_cfg["pixel_size"])
	outline_size = int(_cfg["outline_size"])
	outline_modulate = Color.html(String(_cfg["outline_color"]))
	render_priority = int(_cfg["render_priority"])
	outline_render_priority = render_priority - 1
	_base_height = float(_cfg["height"]) if height < 0.0 else height
	position = Vector3(0.0, _base_height, 0.0)
	visible = false
	set_process(false)
	add_to_group(GROUP)
	_live.append(self)
	if _status == null:
		return
	_status.status_stacks_changed.connect(_on_stacks_changed)
	_status.status_applied.connect(_on_status_changed)
	_status.status_expired.connect(_on_status_changed)
	_status.status_detonated.connect(_on_detonated)


func refresh() -> void:
	if _status == null or not is_instance_valid(_status):
		return
	var entries: Array = []
	var tint := Color.WHITE
	for id: Variant in _status.active_status_ids():
		var status_id: String = String(id)
		var def: Dictionary = StatusDatabase.get_status(status_id)
		if def.is_empty():
			continue
		var stacks: int = _status.stacks_of(status_id)
		entries.append({"id": status_id, "name": String(def["display_name"]), "stacks": stacks, "max": _status.max_stacks_of(status_id)})
		if shows(stacks, _cfg):
			tint = _status_color(def)
	text = compose(entries, _cfg)
	modulate = tint
	visible = text != ""
	set_process(visible)
	if not visible:
		_lift = 0.0
		position.y = _base_height


## The label's centre without its lift, in the world: the owner's position plus the base height.
func base_world() -> Vector3:
	var host := get_parent() as Node3D
	return (host.global_position if host != null else Vector3.ZERO) + Vector3(0.0, _base_height, 0.0)


func _exit_tree() -> void:
	_live.erase(self)


## The text size, worked out again only when the text changed (not once per frame per neighbour).
func cached_size() -> Vector2:
	if text != _size_text:
		_size_text = text
		_text_size = text_size(text, font_size, pixel_size)
	return _text_size


func current_lift() -> float:
	return _lift


## Eases the label up over any visible label below it on screen (the one that is nearer the camera). Ordering uses the base positions and the amount uses the
## other label's current rise, so a column of three stacks upward and nothing can chase its own tail.
func _process(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null or not visible:
		return
	var mine: Vector3 = base_world()
	var size: Vector2 = cached_size()
	var target: float = 0.0
	var up_in_world: float = maxf(camera.global_transform.basis.y.dot(Vector3.UP), 0.2)
	for other: StatusStackLabel in _live:
		if other == self or not is_instance_valid(other) or not other.visible:
			continue
		var other_base: Vector3 = other.base_world()
		var base_delta: Vector3 = mine - other_base
		if base_delta.dot(camera.global_transform.basis.y) < 0.0:
			continue  # this one is the lower label: it stays put, the other rises
		var lifted_delta: Vector3 = mine - (other_base + Vector3(0.0, other.current_lift(), 0.0))
		var other_size: Vector2 = other.cached_size()
		var rise: float = lift_over(lifted_delta.dot(camera.global_transform.basis.x), lifted_delta.dot(camera.global_transform.basis.y), (size.x + other_size.x) * 0.5, (size.y + other_size.y) * 0.5, float(_cfg["overlap_pad"]))
		target = maxf(target, rise / up_in_world)
	_lift = move_toward(_lift, target, float(_cfg["lift_speed"]) * delta)
	position.y = _base_height + _lift
	modulate.a = alpha_step(modulate.a, _covered_by_number(camera, size), float(_cfg["number_dim_alpha"]), float(_cfg["number_dim_speed"]), delta)


## True while a live damage number (or a "detonated" word) overlaps this label on screen.
func _covered_by_number(camera: Camera3D, size: Vector2) -> bool:
	var mine: Vector3 = global_position
	var own_radius: float = float(_cfg["own_number_radius"])
	for number: DamageNumber in DamageNumber.live:
		if not is_instance_valid(number) or not number.is_inside_tree() or not number.visible:
			continue
		var offset: Vector3 = number.global_position - mine
		# The enemy's own numbers rise straight up through its label while it is hit: they must not dim the stack count that the player reads in
		# between hits. Only a neighbour's numbers (and any word popup) count.
		if is_own_number(Vector2(offset.x, offset.z).length(), number.is_word(), own_radius):
			continue
		var number_size: Vector2 = text_size(number.text, number.font_size, number.pixel_size) * number.scale.x
		if covers(offset.dot(camera.global_transform.basis.x), offset.dot(camera.global_transform.basis.y), (size.x + number_size.x) * 0.5, (size.y + number_size.y) * 0.5):
			return true
	return false


func _on_stacks_changed(_status_id: String, _stacks: int) -> void:
	refresh()


func _on_status_changed(_status_id: String) -> void:
	refresh()


func _status_color(def: Dictionary) -> Color:
	var visual: Variant = def.get("visual")
	if visual is Dictionary and (visual as Dictionary).has("color"):
		return Color.html(String((visual as Dictionary)["color"])).lerp(Color.WHITE, 0.35)
	return ElementVisuals.color_for_damage_type(String(def.get("damage_type", ""))).lerp(Color.WHITE, 0.35)


## The detonate hit reads at a glance: the damage number that just landed is enlarged and ends with "!", a burst ring
## expands round the enemy and a short "<Status> detonated" word rises above it (Juice.on_detonated).
func _on_detonated(status_id: String, amount: float, _stacks: int) -> void:
	refresh()
	var owner_node := get_parent() as Node3D
	if owner_node == null or not owner_node.is_inside_tree():
		return
	var def: Dictionary = StatusDatabase.get_status(status_id)
	var damage_type: String = String(def.get("damage_type", ""))
	var spot: Vector3 = owner_node.global_position
	Juice.on_detonated(spot, amount, damage_type, detonate_word(String(def.get("display_name", status_id)), _cfg), _status_color(def))
	var pool: EffectPool = EffectPool.for_world(owner_node.get_parent())
	if pool != null:
		var look: Dictionary = ElementVisuals.visual_for_damage_type(damage_type)
		var color: Color = look["color"]
		var radius: float = float(_cfg["burst_radius"])
		pool.play(EffectPool.Shape.RING, spot + Vector3(0.0, 0.05, 0.0), radius, TemplateVfx.lighter(color, 0.4), 0.3, 0.3, 1.0, 0.9, 0.0)
		pool.play(EffectPool.Shape.SPHERE, spot + Vector3(0.0, 0.8, 0.0), radius * 0.5, TemplateVfx.lighter(color, 0.6), 0.2, 0.5, 1.8, 0.8, 0.0)
