class_name StatusStackLabel
extends Label3D
## BD3a: the stack count over an enemy ("Bleed x3", "Bleed x5 MAX" at the cap) and the detonate cue. A child of an enemy's HP bar,
## signal-driven: it reads `stacks_of` / `max_stacks_of` and the status names from data, and hides while nothing stacks.
## Text and sizes live in data/ui.json `status_stacks`. The count is words, so it does not rely on colour.

var _status: StatusEffectManager = null
var _cfg: Dictionary = {}


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
	position = Vector3(0.0, float(_cfg["height"]) if height < 0.0 else height, 0.0)
	visible = false
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
