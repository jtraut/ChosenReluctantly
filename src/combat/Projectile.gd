extends Area3D
class_name Projectile
## Simple travel-and-hit projectile for the "projectile" card effect
## template. Self-contained: once launched it ticks its own travel distance
## and frees itself on hit or at max range, independent of whoever cast it.

@export var hit_radius: float = 0.25
@export var knockback_strength: float = 0.0

var _damage: float = 0.0
var _damage_type: String = "physical"
var _speed: float = 12.0
var _max_range: float = 15.0
var _exclude_team: String = "neutral"
var _traveled: float = 0.0
var _direction: Vector3 = Vector3.FORWARD
## Element look ({"color", "scale"}), set once by set_look(); cached so the
## per-frame trail never does a data lookup.
var _look: Dictionary = {}
var _pool: EffectPool = null
var _trail_timer: float = 0.0

## Seconds between trail puffs (not every frame, so a few shots cannot flood the pool).
const TRAIL_INTERVAL := 0.04

## One material per color, shared by every projectile of that color. The scene's
## own material is a shared SubResource, so editing it would recolor all live shots.
static var _ball_materials: Dictionary = {}


func _ready() -> void:
	collision_layer = CollisionLayers.HITBOX
	collision_mask = CollisionLayers.HURTBOX
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)
	set_hit_radius(hit_radius)


## Sizes the hit sphere and the visible ball from the same number. The shape
## resource is shared by every instance of the scene, so it is duplicated
## before being resized. Call before launch().
func set_hit_radius(radius: float) -> void:
	hit_radius = radius
	var shape_node: CollisionShape3D = get_node("CollisionShape3D")
	var sphere := (shape_node.shape as SphereShape3D).duplicate() as SphereShape3D
	sphere.radius = radius
	shape_node.shape = sphere
	var mesh_node: MeshInstance3D = get_node("Mesh")
	var base_radius: float = (mesh_node.mesh as SphereMesh).radius
	mesh_node.scale = Vector3.ONE * (radius / base_radius)


## Recolors the ball from element data and starts the muzzle flash. Call once,
## before launch(). Cosmetic only: the hit sphere is untouched.
func set_look(look: Dictionary) -> void:
	_look = look
	var color: Color = look["color"]
	if not _ball_materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 2.0
		_ball_materials[color] = material
	(get_node("Mesh") as MeshInstance3D).material_override = _ball_materials[color]
	_pool = EffectPool.for_world(get_parent())


## Radius of the visible ball in world units (mesh radius times node scale).
func visual_radius() -> float:
	var mesh_node: MeshInstance3D = get_node("Mesh")
	return (mesh_node.mesh as SphereMesh).radius * mesh_node.scale.x


## Radius of the hit sphere in world units.
func hitbox_radius() -> float:
	return ((get_node("CollisionShape3D") as CollisionShape3D).shape as SphereShape3D).radius


func launch(origin: Vector3, direction: Vector3, damage: float, damage_type: String, speed: float, max_range: float, exclude_team: String) -> void:
	global_position = origin
	_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	_damage = damage
	_damage_type = damage_type
	_speed = speed
	_max_range = max_range
	_exclude_team = exclude_team
	look_at(global_position + _direction, Vector3.UP)
	if not _look.is_empty():
		TemplateVfx.projectile_muzzle(_pool, origin, _look)


func _physics_process(delta: float) -> void:
	var step := _direction * _speed * delta
	global_position += step
	_traveled += step.length()
	_trail_timer -= delta
	if _trail_timer <= 0.0 and not _look.is_empty():
		_trail_timer = TRAIL_INTERVAL
		TemplateVfx.projectile_trail_puff(_pool, global_position, hit_radius, _look)
	if _traveled >= _max_range:
		_burst()
		queue_free()


func _on_area_entered(area: Area3D) -> void:
	if not (area is Hurtbox):
		return
	var hurtbox: Hurtbox = area
	if hurtbox.team == _exclude_team:
		return
	var knockback := _direction * knockback_strength if knockback_strength > 0.0 else Vector3.ZERO
	hurtbox.receive_damage(_damage, _damage_type, knockback)
	_burst()
	queue_free()


func _burst() -> void:
	if not _look.is_empty() and _pool != null and is_instance_valid(_pool):
		TemplateVfx.projectile_impact(_pool, global_position, _look)
