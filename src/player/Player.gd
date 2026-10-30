extends CharacterBody3D
class_name Player
## WASD movement relative to the fixed camera, and continuous mouse-ground aim.

## Emitted once when Health reaches 0. Main, the run system, and UI listen here.
signal player_died()

## Emitted once per damage event this player dealt, from any source (hits, projectiles, DoT
## ticks): the target's root node, HP actually removed, damage type, Health.KIND_*.
## Lifesteal and any future on-damage-dealt effect listen here.
signal damage_dealt(target: Node, amount: float, damage_type: String, kind: StringName)

## Attack timing signals for UI (ids are &"light" / &"heavy"). Forwarded from
## the AttackController. started: swing or wind-up begins; fired: damage
## moment; ready: cooldown finished; cancelled: wind-up aborted (death).
signal attack_started(attack_id: StringName)
signal attack_fired(attack_id: StringName)
signal attack_ready(attack_id: StringName)
signal attack_cancelled(attack_id: StringName)

## True when a pass-through buff starts (the body stops colliding with enemies), false when the last one
## ends, on death, and on leaving the tree. ux: the ghosted-player cue listens here or reads is_pass_through().
signal pass_through_changed(active: bool)

@export var move_speed: float = 6.0
@export var acceleration: float = 24.0
@export var friction: float = 28.0
@export var turn_speed: float = 14.0
@export var gravity: float = 20.0

## Sim and test hook: when >= 0, every Player created afterwards seeds its status RNG and card
## shuffles from this value (see docs/DECISIONS.md, S6-4). -1 (the default) is normal random play.
static var default_rng_seed: int = -1

## Dodge roll tuning, loaded from data/player.json (PlayerConfig) in _ready.
var dodge_speed: float = 20.0
var dodge_duration: float = 0.25
var dodge_cooldown: float = 0.8

## Which character this is (a key of data/characters.json: rogue, wizard). "" = work it out from `owned_pools`, else the
## default (Rogue). Main sets it before _ready in a run, from the run's class. It picks the pools, max HP, body colour,
## light and heavy attack and the starter deck's pools (W1a).
@export var character_id: String = ""
## The pools the cards come from. Empty (the default) = the character's pools from data/characters.json; a test or
## capture can set its own before the player enters the tree.
@export var owned_pools: Array[String] = []

## Input action names per slot index, built once (formatting them each frame allocates strings).
const USE_ACTIONS: Array[StringName] = [&"slot_1", &"slot_2", &"slot_3", &"slot_4", &"slot_5"]
const SWAP_ACTIONS: Array[StringName] = [&"dead_card_swap_1", &"dead_card_swap_2", &"dead_card_swap_3", &"dead_card_swap_4", &"dead_card_swap_5"]
const HIT_FLASH_COLOR := Color(1.0, 0.3, 0.3)
const HIT_FLASH_DURATION := 0.15
const KNOCKBACK_DECAY := 18.0
const DEATH_FLASH_WHITE := Color(1.0, 1.0, 1.0)
const DEATH_FLASH_RED := Color(1.0, 0.1, 0.1)
const DEATH_FLASH_HOLD := 0.08
const DEATH_SHAKE_STRENGTH := 0.45
const DEATH_SHAKE_DURATION := 0.3

var camera: Camera3D = null
var stat_modifiers := StatModifiers.new()
var card_slots: CardSlotController
var attacks: AttackController
## Card slot key model (press / hold / release). Fed from _unhandled_input only, so a UI
## screen that consumes input blocks casting; read by the cast preview.
var cast_input := CastInput.new()
## The held-key ground preview of the previewed card's hit area (child node, built in _ready).
var cast_preview: CastPreview = null

@onready var hurtbox: Hurtbox = $Hurtbox
@onready var health: Health = $Health
@onready var status_manager: StatusEffectManager = $StatusEffectManager
@onready var body_mesh: MeshInstance3D = $BodyMesh

var _attack_visuals: Dictionary = {}
var _bolt_looks: Dictionary = {}
## Seedable RNG for element/status chances on hit (tests and captures set .seed).
var status_rng := RandomNumberGenerator.new()
## Capture/test only: a fixed ground point returned by get_aim_point() instead of the mouse.
var aim_point_override: Variant = null
## Capture/test only: use this class's heavy instead of the one the owned pools name.
var _heavy_class_override: String = ""
## targeted_aoe heavy: attack id -> locked ground target, and its held ground telegraph
## (arrays of PooledEffect and the generations they were handed out for).
var _aoe_targets: Dictionary = {}
var _telegraphs: Dictionary = {}
## Reused every physics frame by _handle_attack (no per-frame Dictionary).
var _manual_attack: Dictionary = {&"light": false, &"heavy": false}
## Attack clicks latched by _unhandled_input until the next physics tick consumes them
## (so a click is never lost to a frame with no physics tick, e.g. during hit-stop).
var _attack_latch: Dictionary = {&"light": false, &"heavy": false}
## Slot indices whose cast was requested (press in press mode, release in release mode),
## waiting for the next physics tick. try_use refuses a slot that is not ready.
var _cast_queue: Array[int] = []
const CAST_QUEUE_LIMIT := 8
## The pool the telegraphs were drawn in, found once at wind-up start (not every frame).
var _telegraph_pool: EffectPool = null
var _telegraph_generations: Dictionary = {}
var _dodge_cooldown_remaining: float = 0.0
## Dodge presses are ignored until this physics frame (set when the game pauses or resumes).
var _dodge_blocked_until_frame: int = -1
var _base_body_color: Color = Color.WHITE
var _knockback_velocity: Vector3 = Vector3.ZERO
## Pass-through buff: how many grants are running, and the collision mask the body had before the first.
var _pass_through_count: int = 0
## Pass-through ended while the body still overlaps an enemy: the masks stay off until it is clear (or the cap
## runs out), so solid bodies never pop the player out of a crowd (and up onto an enemy's head).
var _restore_pending: bool = false
var _restore_wait: float = 0.0
const PASS_THROUGH_RESTORE_CAP := 3.0
const PLAYER_BODY_RADIUS := 0.4
## Overlapping by more than this counts as inside (bodies in contact stand 0.85 apart, so 0.05 of slack).
const CLEAR_MARGIN := -0.05
var _mask_before_pass_through: int = 0
## Damage along a dash path (EffectTemplates dash with `damage`): the spec, the enemies already hit this
## dash (instance ids) and where the last tick sampled from.
var _path_hit: Dictionary = {}
var _path_hit_ids: Dictionary = {}
var _path_prev: Vector3 = Vector3.ZERO
var _dead: bool = false
var _flash_tween: Tween = null

# Generic forced-motion override (dodge roll, and later any Movement-slot
# "dash" card): while active, this drives velocity instead of normal input.
var _forced_move_direction: Vector3 = Vector3.FORWARD
var _forced_move_speed: float = 0.0
var _forced_move_time_remaining: float = 0.0
var _forced_move_invulnerable: bool = false
## Element look for the dash card's trail and end puff; empty (dodge roll) means no trail.
var _forced_move_look: Dictionary = {}
var _forced_move_trail_timer: float = 0.0

## Physics ticks after a pause or resume in which a dodge press is ignored (S6-5); from data/player.json.
var dodge_block_ticks_after_pause: int = 2
const DASH_TRAIL_INTERVAL := 0.04


func _ready() -> void:
	_apply_character()
	health.stat_modifiers = stat_modifiers  # the player's armor reads the `armor` stat (plumbing: base 0, nothing grants it yet)
	var team := hurtbox.team if hurtbox != null else "player"
	var card_rng: RandomNumberGenerator = null
	if default_rng_seed >= 0:
		# Repeatable run (sims, tests): status rolls and card shuffles come from this seed.
		status_rng.seed = default_rng_seed
		card_rng = RandomNumberGenerator.new()
		card_rng.seed = default_rng_seed + 1
	else:
		status_rng.randomize()
	if PlayerConfig.collide_with_enemies():
		# Solid enemies (data/player.json body.collide_with_enemies): the player's body is blocked by enemy bodies.
		# The scene's mask is world only; Enemy adds the player's layer to its own mask under the same flag.
		collision_mask |= CollisionLayers.ENEMY_BODY
		# Never carried by, or standing on the motion of, an enemy body.
		platform_floor_layers = CollisionLayers.WORLD
		platform_wall_layers = CollisionLayers.WORLD
	var dodge_cfg: Dictionary = PlayerConfig.dodge()
	dodge_speed = float(dodge_cfg["speed"])
	dodge_duration = float(dodge_cfg["duration"])
	dodge_cooldown = float(dodge_cfg["cooldown"])
	dodge_block_ticks_after_pause = int(dodge_cfg["block_ticks_after_pause"])
	card_slots = CardSlotController.new(self, WorldRef.get_world(get_tree()), team, stat_modifiers, owned_pools, card_rng)
	card_slots.status_rng = status_rng
	damage_dealt.connect(_on_damage_dealt)
	_setup_attacks()
	cast_preview = CastPreview.new()
	cast_preview.name = "CastPreview"
	add_child(cast_preview)
	cast_preview.setup(self)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	Settings.changed.connect(_on_setting_changed)
	GamePause.paused_changed.connect(_on_pause_changed)
	# The body material lives in the scene as a surface override, so material_override
	# is empty until we take a unique copy here. Every flash (hit, death) tweens this
	# copy; before, nothing was found and none of them ever showed.
	var material: Material = body_mesh.get_active_material(0)
	if material is StandardMaterial3D:
		var unique_material: StandardMaterial3D = (material as StandardMaterial3D).duplicate()
		body_mesh.material_override = unique_material
		apply_body_color()


## Paints the body in the character's placeholder colour (data/characters.json). _ready calls it; a scenario that
## switches `character_id` afterwards calls it again so the look follows the character.
func apply_body_color() -> void:
	var unique_material: Material = body_mesh.material_override
	if unique_material is StandardMaterial3D:
		(unique_material as StandardMaterial3D).albedo_color = CharacterDatabase.body_color(character_id)
		_base_body_color = (unique_material as StandardMaterial3D).albedo_color


## Fills in the character from data/characters.json: which class this is, its pools (unless a test set its own) and its
## max HP. The body colour is applied where the unique body material is made.
func _apply_character() -> void:
	if character_id == "" and not owned_pools.is_empty():
		character_id = CharacterDatabase.id_for_pools(owned_pools)
	if not CharacterDatabase.has(character_id):
		character_id = CharacterDatabase.DEFAULT_ID
	if owned_pools.is_empty():
		owned_pools = CharacterDatabase.pools(character_id)
	health.max_health = CharacterDatabase.max_hp(character_id)
	health.current_health = health.max_health


func _physics_process(delta: float) -> void:
	if _dead:
		_tick_dead(delta)
		return
	_tick_cooldowns(delta)
	if _restore_pending:
		_tick_restore(delta)
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	card_slots.advance(delta)
	_handle_dodge_input()
	var forced_this_tick := _forced_move_time_remaining > 0.0
	if forced_this_tick:
		_apply_forced_move(delta)
	else:
		_apply_movement(delta)
	_apply_aim(delta)
	_handle_attack(delta)
	_handle_card_slot_input()
	move_and_slide()
	if forced_this_tick and not _path_hit.is_empty():
		_tick_path_hits()
	if forced_this_tick and _forced_move_time_remaining <= 0.0:
		# The forced move is over: stop dead and hand back to normal movement, so it never
		# coasts past its data distance (friction would carry it about twice as far).
		velocity.x = 0.0
		velocity.z = 0.0
		_path_hit = {}


## A key released while the window is out of focus may never reach us, so losing focus
## ends a hold like a pause does (no cast; a fresh press is needed).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_cast_preview()


func _exit_tree() -> void:
	_end_all_pass_through()
	if Settings.changed.is_connected(_on_setting_changed):
		Settings.changed.disconnect(_on_setting_changed)
	if GamePause.paused_changed.is_connected(_on_pause_changed):
		GamePause.paused_changed.disconnect(_on_pause_changed)


func is_dead() -> bool:
	return _dead


## False once dead: gates input, movement, cards, dodge, and light/heavy attacks.
func can_act() -> bool:
	return not _dead


## The character's class: the first owned pool whose kind is "class" (pools.json),
## or "" when it has none. Picks which heavy (data/attacks.json "heavy") it uses.
func character_class_id() -> String:
	if not _heavy_class_override.is_empty():
		return _heavy_class_override
	return _first_pool_of_kind("class")


## The character's element: the first owned pool whose kind is "element" (Fire), or "".
func character_element_id() -> String:
	return _first_pool_of_kind("element")


func _first_pool_of_kind(kind: String) -> String:
	for pool_id: String in owned_pools:
		if PoolDatabase.has(pool_id) and String(PoolDatabase.get_definition(pool_id).get("kind", "")) == kind:
			return pool_id
	return ""


## Capture/test hook: swap to another class's heavy (the Wizard targeted_aoe proof)
## without building the class. Rebuilds the attack controller.
func use_heavy_class(class_id: String) -> void:
	_heavy_class_override = class_id
	_teardown_attacks()
	_setup_attacks()


## Current move speed after StatModifiers (the heavy wind-up slow lives here).
func get_move_speed() -> float:
	return stat_modifiers.apply(AttackController.MOVE_SPEED_STAT, move_speed)


## 0..1 fraction of the attack's cooldown elapsed (1.0 = ready). `attack_id`
## is &"light" or &"heavy". Unknown ids return 0.0.
func get_attack_progress(attack_id: StringName) -> float:
	return attacks.get_progress(attack_id)


func is_attack_ready(attack_id: StringName) -> bool:
	return attacks.is_ready(attack_id)


## Effective cooldown in seconds after StatModifiers.
func get_attack_interval(attack_id: StringName) -> float:
	return attacks.get_interval(attack_id)


func _on_died() -> void:
	if _dead:
		return
	_dead = true
	_forced_move_time_remaining = 0.0
	_forced_move_invulnerable = false
	_forced_move_look = {}
	_path_hit = {}
	_end_all_pass_through()
	attacks.cancel_all()
	cancel_cast_preview()
	if hurtbox != null:
		hurtbox.set_invulnerable(true)
	_play_death_animation()
	player_died.emit()


## Dead bodies only settle: friction on any leftover slide, gravity, no input.
func _tick_dead(delta: float) -> void:
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, friction * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()


## Placeholder death beat (s1-a): the body flashes white then red (so the moment
## of death reads in a still), a red ring and burst pop out of it, the camera
## shakes, and then the body greys out and topples. Primitives only. The beat
## runs in slow-mo, so the flash holds are short in game time.
func _play_death_animation() -> void:
	var config := UiConfig.death_beat()
	var duration: float = config["collapse_duration"]
	var material := body_mesh.material_override
	# The lethal hit's own red-to-base flash tween must not fight the death colors.
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	TemplateVfx.death_cue(EffectPool.for_world(get_parent()), global_position)
	Juice.screen_shake(DEATH_SHAKE_STRENGTH, DEATH_SHAKE_DURATION)
	var topple := create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	topple.tween_property(body_mesh, "rotation_degrees:x", -90.0, duration).set_delay(DEATH_FLASH_HOLD)
	topple.tween_property(body_mesh, "position:y", body_mesh.position.y * 0.5, duration).set_delay(DEATH_FLASH_HOLD)
	if material is StandardMaterial3D:
		var standard := material as StandardMaterial3D
		standard.albedo_color = DEATH_FLASH_WHITE
		var colors := create_tween()
		colors.tween_interval(DEATH_FLASH_HOLD * 0.5)
		colors.tween_property(standard, "albedo_color", DEATH_FLASH_RED, DEATH_FLASH_HOLD * 0.5)
		colors.tween_interval(DEATH_FLASH_HOLD)
		colors.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		colors.tween_property(standard, "albedo_color", Color(0.25, 0.25, 0.25), duration)


func _on_damage_dealt(_target: Node, amount: float, _damage_type: String, _kind: StringName) -> void:
	if status_manager != null:
		status_manager.on_damage_dealt(amount)


func _on_damaged(amount: float, damage_type: String, knockback: Vector3) -> void:
	_knockback_velocity = knockback
	_flash_body(HIT_FLASH_COLOR)
	Juice.on_hit_landed(global_position, amount, damage_type, health.last_kind, health.last_channel, health.last_reduction)


func _flash_body(color: Color) -> void:
	var material := body_mesh.material_override
	if not (material is StandardMaterial3D):
		return
	(material as StandardMaterial3D).albedo_color = color
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(material, "albedo_color", _base_body_color, HIT_FLASH_DURATION)


func _tick_cooldowns(delta: float) -> void:
	_dodge_cooldown_remaining = maxf(_dodge_cooldown_remaining - delta, 0.0)


func _handle_dodge_input() -> void:
	if _forced_move_time_remaining > 0.0 or _dodge_cooldown_remaining > 0.0:
		return
	if Engine.get_physics_frames() <= _dodge_blocked_until_frame:
		return
	if not Input.is_action_just_pressed("dodge"):
		return
	var input_dir := _movement_input_direction()
	var dodge_direction := input_dir if input_dir.length_squared() > 0.0001 else -global_transform.basis.z
	_dodge_cooldown_remaining = dodge_cooldown
	start_forced_move(dodge_direction, dodge_speed, dodge_duration, true)


## Overrides normal movement input for `duration` seconds, driving velocity
## directly along `direction` at `speed`. Used by the dodge roll, and by the
## "dash" card effect template so Movement-slot cards can reuse the same
## motion/invulnerability machinery instead of duplicating it.
## `path_hit` (optional, from the dash template): {damage, damage_type, hit_radius, knockback_strength}
## damages each enemy the body sweeps through, at most once per move.
func start_forced_move(direction: Vector3, speed: float, duration: float, invulnerable: bool = false, vfx_look: Dictionary = {}, path_hit: Dictionary = {}) -> void:
	if _dead:
		return
	_path_hit = path_hit
	_path_hit_ids.clear()
	_path_prev = global_position if is_inside_tree() else Vector3.ZERO
	_forced_move_look = vfx_look
	_forced_move_trail_timer = 0.0
	var flat_direction := direction
	flat_direction.y = 0.0
	if flat_direction.length_squared() < 0.0001:
		flat_direction = -global_transform.basis.z
	_forced_move_direction = flat_direction.normalized()
	_forced_move_speed = speed
	_forced_move_time_remaining = duration
	_forced_move_invulnerable = invulnerable
	if invulnerable and hurtbox != null:
		hurtbox.set_invulnerable(true)


func _apply_forced_move(delta: float) -> void:
	# The last tick only drives for the time that is left, so the move covers exactly
	# speed * duration at any physics rate (no overshoot of up to one tick of travel).
	var drive_scale := clampf(_forced_move_time_remaining / delta, 0.0, 1.0) if delta > 0.0 else 0.0
	velocity.x = _forced_move_direction.x * _forced_move_speed * drive_scale
	velocity.z = _forced_move_direction.z * _forced_move_speed * drive_scale
	velocity.y = 0.0
	_forced_move_time_remaining -= delta
	if not _forced_move_look.is_empty():
		_forced_move_trail_timer -= delta
		if _forced_move_trail_timer <= 0.0:
			_forced_move_trail_timer = DASH_TRAIL_INTERVAL
			TemplateVfx.dash_trail(EffectPool.for_world(get_parent()), global_position, _forced_move_look)
	if _forced_move_time_remaining <= 0.0:
		_forced_move_time_remaining = 0.0
		if not _forced_move_look.is_empty():
			# Where the motion actually stopped (it may have been blocked short of the distance).
			TemplateVfx.dash_end(EffectPool.for_world(get_parent()), global_position, _forced_move_look)
			_forced_move_look = {}
		if _forced_move_invulnerable and hurtbox != null:
			hurtbox.set_invulnerable(false)
		_forced_move_invulnerable = false


## Hits every enemy within hit_radius of the body's path since the last tick, once each per dash. The path
## is sampled every hit_radius so a fast dash cannot skip an enemy; the query is the shared sphere query,
## so the hit area is the lane the dash drew (VfxSizing.dash_path_*). A direct hit: hit-stop and shake.
func _tick_path_hits() -> void:
	var radius: float = float(_path_hit["hit_radius"])
	var from: Vector3 = _path_prev
	var to: Vector3 = global_position
	_path_prev = to
	var steps: int = maxi(ceili(from.distance_to(to) / maxf(radius, 0.1)), 1)
	var team: String = hurtbox.team if hurtbox != null else "player"
	var space := get_world_3d().direct_space_state
	for step in range(steps + 1):
		var point: Vector3 = from.lerp(to, float(step) / float(steps))
		for target: Hurtbox in MeleeQuery.find_hurtboxes_in_sphere(space, point, radius, team, CollisionLayers.HURTBOX):
			var id: int = target.get_instance_id()
			if _path_hit_ids.has(id):
				continue
			_path_hit_ids[id] = true
			target.receive_damage(float(_path_hit["damage"]), String(_path_hit["damage_type"]),
					EffectTemplates.knockback_from(global_position, target.global_position, float(_path_hit["knockback_strength"])), self, Health.KIND_HIT)


## Walk through enemies for `duration` seconds: the body stops colliding with enemy bodies (both ways)
## until the last running grant ends, on death, or when the player leaves the tree (reload). Grants
## overlap rather than stack. The timer follows the game's pause and time scale like other buffs.
func grant_pass_through(duration: float) -> void:
	if _dead or not is_inside_tree() or duration <= 0.0:
		return
	_pass_through_count += 1
	if _pass_through_count == 1:
		if _restore_pending:
			_restore_pending = false  # still passing through; the new grant simply continues it
		else:
			_set_pass_through(true)
	get_tree().create_timer(duration, false).timeout.connect(_release_pass_through, CONNECT_ONE_SHOT)


## True while the body passes through enemies, including the short wait after the buff ended while still inside one.
func is_pass_through() -> bool:
	return _pass_through_count > 0 or _restore_pending


func _release_pass_through() -> void:
	if _pass_through_count <= 0:
		return
	_pass_through_count -= 1
	if _pass_through_count == 0:
		if PlayerConfig.collide_with_enemies() and Enemy.any_body_overlaps(global_position, PLAYER_BODY_RADIUS + CLEAR_MARGIN):
			_restore_pending = true
			_restore_wait = 0.0
		else:
			_set_pass_through(false)


func _tick_restore(delta: float) -> void:
	_restore_wait += delta
	if _restore_wait >= PASS_THROUGH_RESTORE_CAP or not Enemy.any_body_overlaps(global_position, PLAYER_BODY_RADIUS + CLEAR_MARGIN):
		_restore_pending = false
		_set_pass_through(false)


func _end_all_pass_through() -> void:
	if _pass_through_count > 0 or _restore_pending:
		_pass_through_count = 0
		_restore_pending = false
		_set_pass_through(false)


func _set_pass_through(active: bool) -> void:
	if active:
		_mask_before_pass_through = collision_mask
		collision_mask = collision_mask & ~CollisionLayers.ENEMY_BODY
	else:
		collision_mask = (collision_mask & ~CollisionLayers.ENEMY_BODY) | (_mask_before_pass_through & CollisionLayers.ENEMY_BODY)
	Enemy.set_player_body_suppressed(active)
	pass_through_changed.emit(active)


func _setup_attacks() -> void:
	var heavy_class: String = _heavy_class_override if not _heavy_class_override.is_empty() else CharacterDatabase.heavy_class(character_id)
	var defs := AttackDatabase.load_valid(heavy_class, CharacterDatabase.light_variant(character_id))
	attacks = AttackController.new(defs, stat_modifiers)
	attacks.attack_started.connect(_on_attack_started)
	attacks.attack_fired.connect(_on_attack_fired)
	attacks.attack_ready.connect(func(attack_id: StringName) -> void: attack_ready.emit(attack_id))
	attacks.attack_cancelled.connect(_on_attack_cancelled)
	for attack_id: StringName in attacks.ids():
		var def := attacks.get_def(attack_id)
		# Only arcs have a wedge on the player; a targeted_aoe draws its disc at the target.
		if String(def["shape"]) != "arc":
			continue
		var visual := AttackArcVisual.new()
		visual.name = "AttackVisual_%s" % attack_id
		add_child(visual)
		visual.setup(VfxSizing.cone_reach(float(def["range"])), float(def["half_angle_degrees"]), Color.html(String(def["color"])))
		_attack_visuals[attack_id] = visual


func _teardown_attacks() -> void:
	if attacks != null:
		attacks.cancel_all()
	for attack_id: StringName in _attack_visuals.keys():
		(_attack_visuals[attack_id] as Node).queue_free()
	_attack_visuals.clear()
	for attack_id: StringName in _telegraphs.keys():
		_stop_telegraph(attack_id)


func _handle_attack(delta: float) -> void:
	_manual_attack[&"light"] = _attack_latch[&"light"]
	_manual_attack[&"heavy"] = _attack_latch[&"heavy"]
	_attack_latch[&"light"] = false
	_attack_latch[&"heavy"] = false
	attacks.tick(delta, can_act(), _manual_attack, _attack_has_target)
	for attack_id: StringName in attacks.ids():
		if attacks.is_winding_up(attack_id) and _attack_visuals.has(attack_id):
			(_attack_visuals[attack_id] as AttackArcVisual).show_windup(attacks.get_windup_progress(attack_id))
		if attacks.is_winding_up(attack_id) and _telegraphs.has(attack_id):
			_update_aoe_telegraph(attack_id, attacks.get_windup_progress(attack_id))


## True when at least one enemy is inside the attack's range and arc, facing
## the current aim direction. Gate for automatic attacks (never whiff).
func _attack_has_target(attack_id: StringName) -> bool:
	if not is_inside_tree():
		return false
	var def := attacks.get_def(attack_id)
	var gate_direction: Vector3 = _projectile_direction() if String(def["shape"]) == "projectile" else -global_transform.basis.z
	var hits := MeleeQuery.find_hurtboxes_in_cone(
		get_world_3d().direct_space_state,
		global_position,
		gate_direction,
		float(def["range"]),
		float(def["half_angle_degrees"]),
		hurtbox.team if hurtbox != null else "player",
		CollisionLayers.HURTBOX
	)
	return not hits.is_empty()


func _on_attack_started(attack_id: StringName) -> void:
	var def := attacks.get_def(attack_id)
	if float(def["wind_up"]) > 0.0:
		if String(def["shape"]) == "targeted_aoe":
			_start_aoe_telegraph(attack_id, def)
		else:
			(_attack_visuals[attack_id] as AttackArcVisual).show_windup(0.0)
	attack_started.emit(attack_id)


func _on_attack_cancelled(attack_id: StringName) -> void:
	if _attack_visuals.has(attack_id):
		(_attack_visuals[attack_id] as AttackArcVisual).hide_now()
	_stop_telegraph(attack_id)
	_aoe_targets.erase(attack_id)
	attack_cancelled.emit(attack_id)


## The disc a targeted_aoe heavy will hit, locked where the mouse was when the
## wind-up began: clamped to max_range and the arena, drawn through the shared pool
## at the real hit reach (VfxSizing), so the telegraph IS the hitbox. Held until the
## swing or a cancel. The player can step away; the disc stays put.
func _start_aoe_telegraph(attack_id: StringName, def: Dictionary) -> void:
	var target: Vector3 = AoeTargeting.clamp_target(global_position, get_aim_point(), get_aim_direction(), float(def["max_range"]), _arena_rect())
	_aoe_targets[attack_id] = target
	var pool := EffectPool.for_world(get_parent())
	_telegraph_pool = pool
	if pool == null:
		return
	var effects: Array[PooledEffect] = TemplateVfx.aoe_telegraph(pool, target, VfxSizing.aoe_reach(float(def["radius"])), Color.html(String(def["color"])))
	var generations: Array[int] = []
	for effect: PooledEffect in effects:
		generations.append(effect.generation)
	_telegraphs[attack_id] = effects
	_telegraph_generations[attack_id] = generations


## Grows the ground telegraph with the wind-up (0..1), skipping any part the pool has
## already recycled for something else.
func _update_aoe_telegraph(attack_id: StringName, progress: float) -> void:
	var pool := _telegraph_pool
	if not is_instance_valid(pool):
		return
	var effects: Array = _telegraphs[attack_id]
	var generations: Array = _telegraph_generations[attack_id]
	for i in range(effects.size()):
		if pool.is_running(effects[i], int(generations[i])):
			(effects[i] as PooledEffect).set_progress(progress)


func _stop_telegraph(attack_id: StringName) -> void:
	if not _telegraphs.has(attack_id):
		return
	var pool := _telegraph_pool if is_instance_valid(_telegraph_pool) else EffectPool.for_world(get_parent())
	if pool != null:
		var effects: Array = _telegraphs[attack_id]
		var generations: Array = _telegraph_generations[attack_id]
		for i in range(effects.size()):
			pool.stop(effects[i], int(generations[i]))
	_telegraphs.erase(attack_id)
	_telegraph_generations.erase(attack_id)


## True while a ground telegraph (targeted_aoe wind-up) is up for this attack.
func has_aoe_telegraph(attack_id: StringName) -> bool:
	return _telegraphs.has(attack_id)


## The telegraph parts in the fixed order [fill, edge, front] (a copy; empty when none).
## Read-only for tests and ux; the Player still owns and stops them.
func get_aoe_telegraph(attack_id: StringName) -> Array[PooledEffect]:
	var parts: Array[PooledEffect] = []
	for effect: PooledEffect in _telegraphs.get(attack_id, []):
		parts.append(effect)
	return parts


## The target a targeted_aoe heavy has locked right now (or Vector3.INF when none).
func get_aoe_target(attack_id: StringName) -> Vector3:
	return _aoe_targets.get(attack_id, Vector3.INF)


## Walkable XZ rectangle from the Floor node (Rect2: x, z, width, depth), or an empty
## Rect2 (unbounded) with an error when the arena has no Floor.
func _arena_rect() -> Rect2:
	var rect := get_arena_rect()
	if not rect.has_area():
		push_error("Player: no Floor node to bound the targeted_aoe heavy; target is unbounded")
	return rect


## The same rectangle without the error (an empty Rect2 = unbounded). Used by placed card effects.
func get_arena_rect() -> Rect2:
	var floor_node: CSGBox3D = null
	if get_parent() != null:
		floor_node = get_parent().get_node_or_null("Floor") as CSGBox3D
	if floor_node == null:
		return Rect2()
	var half := Vector2(floor_node.size.x, floor_node.size.z) * 0.5
	var center := Vector2(floor_node.global_position.x, floor_node.global_position.z)
	return Rect2(center - half, half * 2.0)


func _on_attack_fired(attack_id: StringName) -> void:
	var def := attacks.get_def(attack_id)
	var context := EffectContext.new(self, WorldRef.get_world(get_tree()), hurtbox.team if hurtbox != null else "neutral")
	if String(def["shape"]) == "targeted_aoe":
		# The same "aoe" template cards use, centred on the locked target.
		var target: Vector3 = _aoe_targets.get(attack_id, AoeTargeting.clamp_target(global_position, null, get_aim_direction(), float(def["max_range"]), _arena_rect()))
		_stop_telegraph(attack_id)
		_aoe_targets.erase(attack_id)
		EffectTemplates.execute("aoe", {
			"damage": def["damage"],
			"damage_type": def["damage_type"],
			"radius": def["radius"],
			"center": target,
			"knockback_strength": def["knockback"],
		}, context)
	elif String(def["shape"]) == "projectile":
		# The Wizard's light: the shared "projectile" template, flying along the line to the reticle. The damage
		# lands when the bolt arrives, so there is no hit-stop or shake here (the hit itself brings the usual ones).
		EffectTemplates.execute("projectile", {
			"damage": def["damage"],
			"damage_type": def["damage_type"],
			"speed": def["speed"],
			"max_range": def["range"],
			"hit_radius": def["hit_radius"],
			"knockback_strength": def["knockback"],
			"direction": _projectile_direction(),
			"lane": false,
			"look": _bolt_look(attack_id, def),
		}, context)
		attack_fired.emit(attack_id)
		return
	else:
		# Light and heavy arcs are just "cone" effects with no card behind them, so
		# they go through the same EffectTemplates path a Rogue card would.
		EffectTemplates.execute("cone", {
			"damage": def["damage"],
			"damage_type": def["damage_type"],
			"range": def["range"],
			"half_angle_degrees": def["half_angle_degrees"],
			"knockback_strength": def["knockback"],
			"vfx": false,
		}, context)
		(_attack_visuals[attack_id] as AttackArcVisual).flash(float(def["flash_duration"]))
	AttackStatuses.apply_on_hit(def, character_element_id(), context.last_hits, status_rng, self)
	if not context.last_hits.is_empty():
		Juice.hit_stop(float(def["hit_stop_duration"]), float(def["hit_stop_scale"]))
		Juice.screen_shake(float(def["shake_strength"]), float(def["shake_duration"]))
	attack_fired.emit(attack_id)


## The bolt's own look ({"color", "scale"}) from the attack's `bolt_look` data, built once per attack (auto-fire shoots one
## every 0.6 s, so nothing is allocated per shot). Empty when the attack has none: the element look is used.
func _bolt_look(attack_id: StringName, def: Dictionary) -> Dictionary:
	if not _bolt_looks.has(attack_id):
		var data: Variant = def.get("bolt_look")
		if typeof(data) == TYPE_DICTIONARY:
			_bolt_looks[attack_id] = {"color": Color.html(String((data as Dictionary)["color"])), "scale": float((data as Dictionary)["scale"])}
		else:
			_bolt_looks[attack_id] = {}
	return _bolt_looks[attack_id]


## The flat direction a projectile light attack flies and is gated on: from the player to the aim point (the reticle),
## else where the body faces. The body turns toward the reticle a few frames later, so this is what makes the bolt
## fly to the reticle and not to where the body happened to look.
func _projectile_direction() -> Vector3:
	var aim: Variant = get_aim_point()
	if aim != null:
		var to_aim: Vector3 = (aim as Vector3) - global_position
		to_aim.y = 0.0
		if to_aim.length_squared() > 0.0025:
			return to_aim.normalized()
	return get_aim_direction()


## Light/heavy clicks and card slot keys are latched here, not polled, so a UI screen
## that consumes the event (pause or settings, later others) blocks them. Dodge and
## movement still poll Input.
##
## Slot keys use exact_match=true on press: without it, Ctrl+1 would also register as
## a plain "1" press and cast slot_1 as well as swap it. Release does NOT use exact
## match (press 1, press Ctrl, release 1 must still end the hold). The dead-card swap
## (Ctrl+N) acts at once and never casts or changes the preview.
func _unhandled_input(event: InputEvent) -> void:
	if _dead or event is InputEventMouseMotion:
		return
	if event.is_action_pressed(&"attack_light", false):
		_attack_latch[&"light"] = true
	if event.is_action_pressed(&"attack_heavy", false):
		_attack_latch[&"heavy"] = true
	for i in range(CardSlotController.SLOT_TYPE_ORDER.size()):
		if event.is_action_pressed(SWAP_ACTIONS[i], false, true):
			card_slots.try_swap(CardSlotController.slot_type_at_index(i))
		elif event.is_action_pressed(USE_ACTIONS[i], false, true):
			_queue_cast(cast_input.press(i, Settings.casts_on_release()))
		elif event.is_action_released(USE_ACTIONS[i]):
			_queue_cast(cast_input.release(i))


## What the held-key preview shows right now, for the HUD and tests:
## {active: bool, slot: slot type id, card_id, shape, size, parts: [{shape, size, half_width,
## half_angle_degrees, start_offset, damage_type}]}. `shape`/`size` are the first part's.
## Shapes: cone, aoe, projectile_lane, dash_path, self_ring (see CastPreviewShapes).
func get_preview_state() -> Dictionary:
	return cast_preview.get_state()


func _queue_cast(slot_index: int) -> void:
	if slot_index != CastInput.NONE and _cast_queue.size() < CAST_QUEUE_LIMIT:
		_cast_queue.append(slot_index)


## Casts the slots whose key presses/releases were latched since the last tick.
func _handle_card_slot_input() -> void:
	if _cast_queue.is_empty():
		return
	for slot_index: int in _cast_queue:
		card_slots.try_use(CardSlotController.slot_type_at_index(slot_index))
	_cast_queue.clear()


## Drops any held preview and pending cast without casting. Called on death, pause, and
## when a screen that takes input opens.
func cancel_cast_preview() -> void:
	cast_input.cancel()
	_cast_queue.clear()
	# A click latched just before a pause, death or focus loss must not fire on resume.
	_attack_latch[&"light"] = false
	_attack_latch[&"heavy"] = false


## Pausing cancels a hold: the key release would arrive while the tree is paused (no
## _unhandled_input), so the preview would otherwise stick. A fresh press is needed after resume.
func _on_pause_changed(_is_paused: bool) -> void:
	cancel_cast_preview()
	# Dodge polls Input, so Space pressed on a focused settings button (ui_accept closes the
	# screen) would roll on the first tick after resume. Ignore dodge for the next ticks.
	_dodge_blocked_until_frame = Engine.get_physics_frames() + dodge_block_ticks_after_pause


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == Settings.CAST_TRIGGER:
		cancel_cast_preview()


func _movement_input_direction() -> Vector3:
	var forward_input := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var right_input := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var basis_forward := Vector3.FORWARD
	var basis_right := Vector3.RIGHT
	if camera != null:
		basis_forward = _flattened(-camera.global_transform.basis.z)
		basis_right = _flattened(camera.global_transform.basis.x)
	var dir := basis_forward * forward_input + basis_right * right_input
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	return dir


func _apply_movement(delta: float) -> void:
	var move_dir := _movement_input_direction()
	var target_velocity := move_dir * get_move_speed()
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if move_dir.length_squared() > 0.0 else friction
	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, rate * delta)

	velocity.x = horizontal_velocity.x + _knockback_velocity.x
	velocity.z = horizontal_velocity.z + _knockback_velocity.z

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta


func _apply_aim(delta: float) -> void:
	if camera == null:
		return
	var aim_point: Variant = _ground_point_under_mouse()
	if aim_point == null:
		return
	var to_aim := (aim_point as Vector3) - global_position
	to_aim.y = 0.0
	if to_aim.length_squared() < 0.0001:
		return
	var target_basis := Basis.looking_at(to_aim, Vector3.UP)
	var current_quat := global_transform.basis.get_rotation_quaternion()
	var target_quat := target_basis.get_rotation_quaternion()
	var blend := 1.0 - exp(-turn_speed * delta)
	var blended := Basis(current_quat.slerp(target_quat, blend))
	global_transform.basis = blended.orthonormalized()


## Read-only, for UI (aim reticle). The ground point under the mouse at the
## player's height, or null when there is no camera/viewport (frozen-aim
## captures, orphan nodes) or the ray misses the plane. Changes nothing.
func get_aim_point() -> Variant:
	if aim_point_override != null:
		return aim_point_override
	if camera == null or not is_inside_tree():
		return null
	return _ground_point_under_mouse()


## Read-only, for UI. The flat unit direction the player FACES, which is the
## direction every card (cone, projectile, dash) actually fires along. It trails
## the mouse a few frames because the body turns with a slerp (turn_speed), so
## draw "where this will go" from this, not from the aim point.
func get_aim_direction() -> Vector3:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3.FORWARD
	return forward.normalized()


## Where a placed skill with range cap `max_range` would land right now, for the reticle: {point (the clamped
## target), range, clamped (the aim point was pulled in), origin, raw (the unclamped wish)}. Read-only.
## A zone or aoe card casts at exactly this point, and the cast preview draws its shape here.
func get_placement(max_range: float) -> Dictionary:
	return AoeTargeting.placement(global_position, get_aim_point(), get_aim_direction(), max_range, get_arena_rect())


func _ground_point_under_mouse() -> Variant:
	var viewport := get_viewport()
	if viewport == null:
		return null
	var mouse_pos := viewport.get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse_pos)
	var ray_dir := camera.project_ray_normal(mouse_pos)
	var ground_plane := Plane(Vector3.UP, global_position.y)
	return ground_plane.intersects_ray(ray_origin, ray_dir)


func _flattened(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized()
