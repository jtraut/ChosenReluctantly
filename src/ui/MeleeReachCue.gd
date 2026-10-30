class_name MeleeReachCue
extends Node3D
## Rogue melee cue (PL2 item 8): a faint arc on the ground at the true reach of the light attack, so a new player can see
## the light attack is melee and how far it goes. Child of the Player (forward is local -Z, like the real wedge).
##
## Unobtrusive by construction: it shows only while NO enemy is inside the light attack's reach, so in a crowd (where the
## auto-attack is already swinging and flashing) it is gone. It is one thin arc band, no fill, no side edges and no
## pulse, in a pale blue that is not the aim cream, the light yellow or any telegraph colour, so it never reads as the
## heavy's wind-up wedge. A light click while it shows (a whiff) briefly brightens it.
##
## Rogue only without naming the Rogue: it appears only when the player's light attack has shape "arc". The Wizard's
## light is a projectile, so it never shows there. Pure display: no physics bodies, no RNG, no gameplay state.
## Tunables: data/ui.json `melee_cue`.

var _player: Player = null
var _config: Dictionary = {}
var _material := StandardMaterial3D.new()
var _band := MeshInstance3D.new()
var _base_color: Color = Color.WHITE
var _alpha: float = 0.0
var _pulse: float = 0.0
var _armed: bool = false


## Adds the cue under `player`. Returns it, or null when there is no player or no attacks.
static func attach(player: Player) -> MeleeReachCue:
	if player == null or player.attacks == null:
		return null
	var cue := MeleeReachCue.new()
	cue.name = "MeleeReachCue"
	player.add_child(cue)
	cue.setup(player)
	return cue


func setup(player: Player) -> void:
	_player = player
	_config = UiConfig.melee_cue()
	var def: Dictionary = player.attacks.get_def(&"light")
	_armed = bool(_config["enabled"]) and applies_to(String(def.get("shape", "")))
	set_physics_process(_armed)
	if not _armed:
		return
	_base_color = Color.html(String(_config["color"]))
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.render_priority = -1
	_material.albedo_color = Color(_base_color, 0.0)
	_band.mesh = build_band(VfxSizing.cone_reach(float(def["range"])), float(def["half_angle_degrees"]), float(_config["thickness"]))
	_band.material_override = _material
	_band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_band.position.y = float(_config["ground_offset"])
	_band.visible = false
	add_child(_band)
	player.attack_started.connect(_on_attack_started)


# --- pure rules (unit-tested) ------------------------------------------------

## The cue is for melee: only an "arc" light attack gets it (a projectile light does not).
static func applies_to(light_shape: String) -> bool:
	return light_shape == "arc"


## Whether the cue wants to be visible: nothing in reach, the player alive and not mid wind-up.
static func wants_visible(alive: bool, enemy_in_reach: bool, winding_up: bool) -> bool:
	return alive and not enemy_in_reach and not winding_up


## Moves `current` toward 1 (wanted) or 0; `fade_in` / `fade_out` are the seconds a full fade takes.
static func fade_step(current: float, wanted: bool, delta: float, fade_in: float, fade_out: float) -> float:
	var seconds: float = fade_in if wanted else fade_out
	var step: float = delta / maxf(seconds, 0.001)
	return clampf(current + (step if wanted else -step), 0.0, 1.0)


## The drawn alpha for a fade level 0..1 and a whiff pulse 0..1: the base alpha, lifted toward `pulse_alpha` by the pulse.
static func alpha_for(fade: float, pulse: float, base_alpha: float, pulse_alpha: float) -> float:
	return fade * lerpf(base_alpha, pulse_alpha, clampf(pulse, 0.0, 1.0))


## A thin band along the outer arc only, inside `attack_range` (nothing is drawn past the true reach).
static func build_band(attack_range: float, half_angle_degrees: float, thickness: float, segments: int = 24) -> ArrayMesh:
	var half: float = deg_to_rad(half_angle_degrees)
	var inner: float = maxf(attack_range - thickness, 0.0)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in range(segments):
		var a0: float = -half + 2.0 * half * float(i) / float(segments)
		var a1: float = -half + 2.0 * half * float(i + 1) / float(segments)
		var o0 := Vector3(sin(a0), 0.0, -cos(a0))
		var o1 := Vector3(sin(a1), 0.0, -cos(a1))
		vertices.append_array([o0 * inner, o0 * attack_range, o1 * attack_range, o0 * inner, o1 * attack_range, o1 * inner])
	for n in range(vertices.size()):
		normals.append(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var band := ArrayMesh.new()
	band.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return band


# --- runtime -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		return
	var alive: bool = not _player.is_dead()
	var wanted: bool = alive and wants_visible(alive, _enemy_in_reach(), _player.attacks.is_busy())
	_alpha = fade_step(_alpha, wanted, delta, float(_config["fade_in"]), float(_config["fade_out"]))
	_pulse = maxf(_pulse - delta / maxf(float(_config["pulse_duration"]), 0.001), 0.0)
	var drawn: float = alpha_for(_alpha, _pulse, float(_config["alpha"]), float(_config["pulse_alpha"]))
	_band.visible = drawn > 0.003
	_material.albedo_color = Color(_base_color, drawn)


## The same query the auto-attack gate uses (cone at the light's reach, along the body's facing).
func _enemy_in_reach() -> bool:
	var def: Dictionary = _player.attacks.get_def(&"light")
	var hits := MeleeQuery.find_hurtboxes_in_cone(
		_player.get_world_3d().direct_space_state,
		_player.global_position,
		-_player.global_transform.basis.z,
		float(def["range"]),
		float(def["half_angle_degrees"]),
		_player.hurtbox.team if _player.hurtbox != null else "player",
		CollisionLayers.HURTBOX
	)
	return not hits.is_empty()


## A light click with nothing in reach: the cue brightens for a moment ("that is as far as it goes").
func _on_attack_started(attack_id: StringName) -> void:
	if attack_id == &"light" and _alpha > 0.5:
		_pulse = 1.0


## True while any of the cue is drawn (tests).
func is_showing() -> bool:
	return _band.visible
