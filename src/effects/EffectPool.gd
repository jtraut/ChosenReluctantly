class_name EffectPool
extends Node
## Shared pool of simple primitive effects (ground disc, ground wedge, sphere
## burst). One pool per world (a child of the arena), found or created with
## for_world(). Effects are plain nodes that the pool animates in one _process
## loop and then returns to its free list, so steady state allocates nothing.
##
## Cap: data/vfx.json "max_simultaneous". At the cap the oldest running effect
## is recycled for the new one (the newest cast is always visible).
##
## Effects hold a position and numbers only, never the caster or a target, so
## freeing either mid-effect cannot error. The cheapest particle type is
## "mesh primitives, animated by scale and alpha": no GPUParticles (they need
## a renderer-side process material and are heavier headless). See DECISIONS.

const NODE_NAME := "EffectPool"
const GROUND_OFFSET := 0.05

enum Shape { DISC, WEDGE, SPHERE }

static var _disc_mesh: CylinderMesh = null
static var _sphere_mesh: SphereMesh = null
static var _wedge_meshes: Dictionary = {}

var max_effects: int = 48

var _free: Array[PooledEffect] = []
var _active: Array[PooledEffect] = []
var _created: int = 0


## Finds or creates the pool under `world`. Returns null if `world` is null or
## not in the tree (unit tests that cast cards on orphan nodes get no visuals).
static func for_world(world: Node) -> EffectPool:
	if world == null or not is_instance_valid(world) or not world.is_inside_tree():
		return null
	var existing: Node = world.get_node_or_null(NODE_NAME)
	if existing is EffectPool:
		return existing
	var pool := EffectPool.new()
	pool.name = NODE_NAME
	pool.max_effects = VfxConfig.max_simultaneous()
	world.add_child(pool)
	return pool


static func disc_mesh() -> CylinderMesh:
	if _disc_mesh == null:
		_disc_mesh = CylinderMesh.new()
		_disc_mesh.top_radius = 1.0
		_disc_mesh.bottom_radius = 1.0
		_disc_mesh.height = 0.02
		_disc_mesh.radial_segments = 32
		_disc_mesh.rings = 1
	return _disc_mesh


static func sphere_mesh() -> SphereMesh:
	if _sphere_mesh == null:
		_sphere_mesh = SphereMesh.new()
		_sphere_mesh.radius = 1.0
		_sphere_mesh.height = 2.0
		_sphere_mesh.radial_segments = 12
		_sphere_mesh.rings = 6
	return _sphere_mesh


## Unit-range fan (scale it by the range), cached per half angle (0.1 degree).
static func wedge_mesh(half_angle_degrees: float) -> ArrayMesh:
	var key: int = roundi(half_angle_degrees * 10.0)
	if not _wedge_meshes.has(key):
		_wedge_meshes[key] = AttackArcVisual.build_fan(1.0, half_angle_degrees)
	return _wedge_meshes[key]


func active_count() -> int:
	return _active.size()


func free_count() -> int:
	return _free.size()


## Total nodes ever created; never exceeds max_effects.
func created_count() -> int:
	return _created


## Starts an effect. `size` is the footprint radius for DISC/WEDGE (the hitbox
## number, see VfxSizing) or the sphere radius. `yaw` only matters for WEDGE
## (local -Z is forward). scale_from/scale_to multiply `size` over the life.
func play(shape: Shape, position: Vector3, size: float, color: Color, duration: float,
		scale_from: float = 1.0, scale_to: float = 1.0, alpha_from: float = 0.6, alpha_to: float = 0.0,
		yaw: float = 0.0, half_angle_degrees: float = 0.0) -> PooledEffect:
	var effect: PooledEffect = _acquire()
	if effect == null:
		return null
	match shape:
		Shape.DISC:
			effect.mesh = disc_mesh()
			effect.is_flat = true
		Shape.WEDGE:
			effect.mesh = wedge_mesh(half_angle_degrees)
			effect.is_flat = true
		Shape.SPHERE:
			effect.mesh = sphere_mesh()
			effect.is_flat = false
	var flat: bool = shape != Shape.SPHERE
	effect.position = Vector3(position.x, position.y + (GROUND_OFFSET if flat else 0.0), position.z)
	effect.rotation = Vector3(0.0, yaw, 0.0)
	effect.base_size = size
	effect.color = color
	effect.duration = maxf(duration, 0.01)
	effect.scale_from = scale_from
	effect.scale_to = scale_to
	effect.alpha_from = alpha_from
	effect.alpha_to = alpha_to
	effect.begin()
	_active.append(effect)
	return effect


func _acquire() -> PooledEffect:
	if not _free.is_empty():
		return _free.pop_back()
	if _created < max_effects:
		var fresh := PooledEffect.new()
		add_child(fresh)
		_created += 1
		return fresh
	# At the cap: recycle the oldest running effect (largest age).
	if _active.is_empty():
		return null
	var oldest_index: int = 0
	for i in range(1, _active.size()):
		if _active[i].age > _active[oldest_index].age:
			oldest_index = i
	var oldest: PooledEffect = _active[oldest_index]
	_active.remove_at(oldest_index)
	oldest.finish()
	return oldest


func _process(delta: float) -> void:
	advance(delta)


## Steps all running effects. Public so tests can drive time without a scene loop.
func advance(delta: float) -> void:
	var i: int = _active.size() - 1
	while i >= 0:
		var effect: PooledEffect = _active[i]
		if not effect.step(delta):
			effect.finish()
			_free.append(effect)
			_active[i] = _active[_active.size() - 1]
			_active.pop_back()
		i -= 1
