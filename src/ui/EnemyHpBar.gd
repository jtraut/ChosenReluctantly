extends MeshInstance3D
class_name EnemyHpBar
## World-space enemy HP bar. Add as a child of anything that has Health (and
## optionally StatusEffectManager) siblings; it never checks enemy types.
## One shared QuadMesh + one shared ShaderMaterial for every bar; per-bar state
## goes through instance uniforms. Signal-driven: _process runs only while the
## ghost trail is draining.

const SHADER_PATH := "res://assets/shaders/enemy_hp_bar.gdshader"
const MODE_ALWAYS_ALIVE := "always_alive"
const MODE_AFTER_DAMAGE := "after_damage"

@export var health_path: NodePath = NodePath("../Health")
@export var status_path: NodePath = NodePath("../StatusEffectManager")

static var _shared_mesh: QuadMesh = null
static var _shared_material: ShaderMaterial = null
static var _shared_config: Dictionary = {}

var _health: Health = null
var _status: StatusEffectManager = null
var _mode: String = MODE_ALWAYS_ALIVE
var _fill: float = 1.0
var _ghost: float = 1.0
var _ghost_delay_left: float = 0.0
var _ghost_delay: float = 0.35
var _ghost_speed: float = 1.5
var _ghost_enabled: bool = true
var _was_damaged: bool = false
var _dead: bool = false
var _burn_id: String = "burn"


# ---- Pure logic (unit-tested) ----

## current/maximum clamped to [0, 1]; maximum <= 0 yields 0 (no divide by zero).
static func fill_ratio(current: float, maximum: float) -> float:
	if maximum <= 0.0 or is_nan(current) or is_nan(maximum):
		return 0.0
	return clampf(current / maximum, 0.0, 1.0)


## Whether the bar should be visible. Unknown modes behave as always_alive.
static func should_show(mode: String, is_dead: bool, was_damaged: bool) -> bool:
	if is_dead:
		return false
	if mode == MODE_AFTER_DAMAGE:
		return was_damaged
	return true


## Ghost trail position after `delta`: holds during `delay_left`, then drains
## toward `fill`. Never drops below fill (healing snaps the ghost up).
static func ghost_step(ghost: float, fill: float, delay_left: float, delta: float, speed: float) -> float:
	if ghost <= fill:
		return fill
	if delay_left > 0.0:
		return ghost
	return maxf(ghost - speed * delta, fill)


## Largest resistance value in the dict (0 if none positive).
static func max_resistance(resistances: Dictionary) -> float:
	var best: float = 0.0
	for key: Variant in resistances:
		best = maxf(best, float(resistances[key]))
	return best


## Element id with the highest positive resistance, or "" if none.
static func dominant_resistance(resistances: Dictionary) -> String:
	var best: float = 0.0
	var best_id: String = ""
	for key: Variant in resistances:
		var value: float = float(resistances[key])
		if value > best:
			best = value
			best_id = str(key)
	return best_id


# ---- Node lifecycle ----

func _ready() -> void:
	set_process(false)
	_ensure_shared()
	mesh = _shared_mesh
	material_override = _shared_material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var config: Dictionary = _shared_config
	_mode = str(config["visibility_mode"])
	_ghost_enabled = bool(config["ghost_enabled"])
	_ghost_delay = float(config["ghost_delay"])
	_ghost_speed = float(config["ghost_drain_per_sec"])
	_burn_id = str(config["burn_status_id"])
	position = Vector3(0.0, float(config["y_offset"]), 0.0)
	visible = false

	_health = get_node_or_null(health_path) as Health
	_status = get_node_or_null(status_path) as StatusEffectManager
	if _health != null:
		_health.health_changed.connect(_on_health_changed)
		_health.died.connect(_on_died)
	if _status != null:
		_status.status_applied.connect(_on_status_applied)
		_status.status_expired.connect(_on_status_expired)
	# Sibling Health may not have run its _ready yet; read initial state after.
	_initialize.call_deferred()


func _initialize() -> void:
	if _health == null or not is_instance_valid(_health):
		return
	_dead = _health.is_dead()
	_fill = fill_ratio(_health.get_current_health(), _health.get_max_health())
	_ghost = _fill
	_was_damaged = _fill < 1.0
	_push_fill()
	if max_resistance(_health.resistances) > 0.0:
		var tints: Dictionary = _shared_config["resistance_tints"]
		var tint_hex: String = str(tints.get(dominant_resistance(_health.resistances), _shared_config["default_resistance_tint"]))
		var tint := Color.html(tint_hex)
		set_instance_shader_parameter("resist_tint", Color(tint.r, tint.g, tint.b, 1.0))
	else:
		set_instance_shader_parameter("resist_tint", Color(0.0, 0.0, 0.0, 0.0))
	_set_burning(_status != null and _status.has_status(_burn_id))
	_update_visibility()


func _process(delta: float) -> void:
	_ghost_delay_left = maxf(_ghost_delay_left - delta, 0.0)
	_ghost = ghost_step(_ghost, _fill, _ghost_delay_left, delta, _ghost_speed)
	set_instance_shader_parameter("ghost", _ghost)
	if _ghost <= _fill:
		set_process(false)


# ---- Signal handlers ----

func _on_health_changed(current: float, maximum: float) -> void:
	var new_fill: float = fill_ratio(current, maximum)
	if new_fill < 1.0:
		_was_damaged = true
	var dropped: bool = new_fill < _fill
	_fill = new_fill
	if not _ghost_enabled or _fill >= _ghost:
		_ghost = _fill
		set_process(false)
	elif dropped:
		_ghost_delay_left = _ghost_delay
		set_process(true)
	_push_fill()
	_update_visibility()


func _on_died() -> void:
	_dead = true
	set_process(false)
	_update_visibility()


func _on_status_applied(status_id: String) -> void:
	if status_id == _burn_id:
		_set_burning(true)


func _on_status_expired(status_id: String) -> void:
	if status_id == _burn_id:
		_set_burning(false)


# ---- Helpers ----

func _push_fill() -> void:
	set_instance_shader_parameter("fill", _fill)
	set_instance_shader_parameter("ghost", _ghost)


func _set_burning(on: bool) -> void:
	set_instance_shader_parameter("status_flags", Color(1.0 if on else 0.0, 0.0, 0.0, 0.0))


func _update_visibility() -> void:
	visible = should_show(_mode, _dead, _was_damaged)


static func _ensure_shared() -> void:
	if _shared_material != null:
		return
	_shared_config = UiConfig.hp_bars()
	var c: Dictionary = _shared_config
	var width: float = float(c["width"])
	var height: float = float(c["height"])
	var pip: float = height + 0.04
	var total := Vector2(width + 2.0 * pip, height)
	_shared_mesh = QuadMesh.new()
	_shared_mesh.size = total
	var colors: Dictionary = c["colors"]
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH) as Shader
	mat.render_priority = 10
	mat.set_shader_parameter("total_size", total)
	mat.set_shader_parameter("bar_width", width)
	mat.set_shader_parameter("pip_width", pip)
	mat.set_shader_parameter("border", float(c["border"]))
	mat.set_shader_parameter("resist_border", float(c["resist_border"]))
	mat.set_shader_parameter("fill_color", Color.html(str(colors["fill"])))
	mat.set_shader_parameter("ghost_color", Color.html(str(colors["ghost"])))
	mat.set_shader_parameter("back_color", Color.html(str(colors["back"])))
	mat.set_shader_parameter("frame_color", Color.html(str(colors["frame"])))
	mat.set_shader_parameter("burn_color", Color.html(str(colors["burn"])))
	_shared_material = mat
