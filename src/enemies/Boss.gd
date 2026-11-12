extends Enemy
class_name Boss
## The final boss (Milestone 3c). An Enemy (so waves, rank, resistance, hurtbox and the roster all work as for any
## enemy) with its own brain: a state machine that chases, picks a telegraphed attack from the current phase's weighted
## list, winds it up, lands it and recovers; crosses HP thresholds into new phases through a short invulnerable roar;
## and dies with a slow-motion beat before the run's win screen. Everything numeric comes from data/bosses.json
## (BossConfig); the pure rules are in BossRules. Attack hits go through the shared EffectTemplates (cone, aoe,
## projectile), drawn at the vs-player reach (VfxSizing) so what is shown is what hits.
##
## Fairness rules, all from data and tested: every telegraph is at least rules.min_telegraph seconds; every attack can
## be escaped by walking or by the dodge (BossRules.escape); the final boss cannot be stunned (rank boss, stun multiplier 0); an act-end mini-boss (rank elite) can, and a stun drops its wind-up with no hit.
## Pinning: the boss is not solid to the player (or to other enemies) while it charges and once it is dead. After a
## charge it becomes solid again only once it no longer overlaps the player's body, so a charge can never trap a
## player against a wall. During a phase transition it stands still and stays solid.
##
## For ux: the signals below, `display_name()`, `phase_thresholds()`, `phase_index`, `phase_count()`, `phase_name()`,
## `is_transitioning()`, and `health` (health_changed gives the HP bar). The boss is in the group "boss".

## The boss moved to a new phase (0-based index), after its transition.
signal phase_changed(phase_index: int, phase_name: String)
## A phase transition began (the boss is invulnerable and roaring) / ended. `phase_index` is the phase being entered.
signal transition_started(phase_index: int, duration: float)
signal transition_ended(phase_index: int)
## D16: the boss reels at a phase threshold (its attack is interrupted; it is NOT immune and the player's hits count).
## `stagger_started` fires at the threshold; `stagger_ended` when the roar begins (transition_started follows at once). ux: a "STAGGERED" cue on the bar while
## is_staggered() / between these two signals.
signal stagger_started(next_phase_index: int, duration: float)
signal stagger_ended(next_phase_index: int)
## A wind-up began: which attack, its label and its telegraph time in seconds.
signal attack_telegraphed(attack_id: String, label: String, windup: float)
## An attack landed (or, for a volley, was fired). `hit_player` is true when it damaged the target right away.
signal attack_landed(attack_id: String, hit_player: bool)
## Adds were summoned by a phase.
signal adds_summoned(adds: Array)
## The boss died; the death beat starts now. The body goes `DEATH_FADE`-ishly later, after `beat_seconds` of real time.
signal defeated()

enum State { CHASE, WINDUP, ACTIVE, RECOVER, TRANSITION, DEAD, STAGGER }

const GROUP := "boss"
## The reel at a phase threshold (D16): a pale-blue tint and a backward tilt (radians) that eases back over the stagger.
const STAGGER_COLOR := Color(0.65, 0.85, 1.0)
const STAGGER_TILT := 0.35
## The charge gives up this long after it should have finished (stuck against a wall).
const CHARGE_SLACK := 0.5
const RESTORE_MARGIN := 0.15
const PLAYER_BODY_RADIUS := 0.4
## A frame longer than this counts as this long in the death beat (a debugger stop must not eat it).
const MAX_BEAT_STEP := 0.5
const ADD_RING_MIN := 3.5
const ADD_RING_MAX := 6.0
const ARENA_LIMIT := 18.0

var phase_index: int = 0

var _def: Dictionary = {}
var _phases: Array = []
var _attacks: Dictionary = {}
var _state: State = State.CHASE
var _state_time: float = 0.0
var _attack_id: String = ""
var _attack: Dictionary = {}
var _lock_dir: Vector3 = Vector3(0.0, 0.0, -1.0)
var _lock_point: Vector3 = Vector3.ZERO
var _telegraph_total: float = 0.0
var _rng := RandomNumberGenerator.new()
var _adds: Array[Enemy] = []
var _entering_phase: int = 0
var _transition_left: float = 0.0
var _stagger_left: float = 0.0
var _stagger_tween: Tween = null
var _charge_traveled: float = 0.0
var _charge_last: Vector3 = Vector3.ZERO
var _charge_start: Vector3 = Vector3.ZERO
var _charge_hit: bool = false
var _phased: bool = false
var _restoring: bool = false
var _layer_default: int = 0
var _tele_pool: EffectPool = null
var _tele_parts: Array[PooledEffect] = []
var _tele_gens: Array[int] = []
var _death_left: float = -1.0
var _death_total: float = 0.0
var _death_last_usec: int = 0
var _mesh_scale: Vector3 = Vector3.ONE
var _seeded: bool = false
var _wedges: Dictionary = {}
var _known_max: float = 0.0
var _scripted: Array[String] = []
var _scripted_index: int = 0
var _active_wedge: AttackArcVisual = null
## MB1: the discs of the current multi-disc aoe wind-up (locked when it starts; empty for a single disc).
var _aoe_locked: Array[Vector3] = []
## MB1: where the current blink wind-up will land the boss (locked when the wind-up starts; the marker shows it the whole wind-up).
var _blink_point: Vector3 = Vector3.ZERO
## MB1: the blink marker colour: a cool cyan-white (it was violet, MB1 ux: close to the pink damage telegraph on a blue-grey floor), so it never reads as a damage telegraph (those take the damage type's colour).
static func blink_color() -> Color:
	return VfxConfig.color_of("blink_color")  # data/vfx.json (MAP3b: it was a code constant)


func _ready() -> void:
	super._ready()
	set_process(false)
	add_to_group(GROUP)
	_def = BossConfig.boss(enemy_id).duplicate(true)
	if _def.is_empty():
		push_error("Boss: '%s' has no definition in data/bosses.json; this boss will stand still" % enemy_id)
		set_physics_process(false)
		return
	_phases = _def["phases"]
	_attacks = _def["attacks"]
	_layer_default = collision_layer
	_mesh_scale = body_mesh.scale
	body_radius = float(_def["body_radius"])
	var max_hp: float = float(_def["max_health"])
	health.max_health = max_hp
	health.current_health = max_hp
	health.base_armor = float(_def["armor"])
	var resistance: float = float(_def["resistance"])
	health.resistance_cap = maxf(health.resistance_cap, resistance)
	health.resistances = TierRules.resistances(health.resistances, TierRules.element_ids(), resistance, resistance)
	_known_max = max_hp
	health.hp_floor = BossRules.floor_hp(_phases, 1, max_hp)
	health.health_changed.connect(_on_health_changed)
	health.health_changed.emit(max_hp, max_hp)
	_attack_cooldown_remaining = float(_def["spawn_grace"])
	if not _seeded:
		_rng.seed = 1000003 + maxi(spawn_index, 0)
	if is_mini_boss():
		# MB1: an act-end mini-boss is an elite-rank fight with its own tier id; its death ends the room, never the run.
		tier = "mini_boss"
		if status_manager != null:
			status_manager.rank = "elite"
	else:
		tier = "boss"


# ---- API for the spawner, ux and tests ----

## The HP thresholds are fractions of max HP, so a change of max HP (a scenario, a debug tool) moves the floor with it.
func _on_health_changed(_current: float, maximum: float) -> void:
	if not is_equal_approx(maximum, _known_max) and not _phases.is_empty():
		_known_max = maximum
		health.hp_floor = BossRules.floor_hp(_phases, phase_index + 1, maximum)


## Capture and test tooling only: start in phase `index` (0-based) at the HP that phase begins at.
func debug_set_phase(index: int) -> void:
	phase_index = clampi(index, 0, _phases.size() - 1)
	var enters: float = float((_phases[phase_index] as Dictionary)["enters_at"])
	health.hp_floor = BossRules.floor_hp(_phases, phase_index + 1, health.max_health)
	health.current_health = maxf(health.max_health * enters, health.hp_floor + 1.0) if phase_index > 0 else health.max_health
	health.health_changed.emit(health.current_health, health.max_health)


## Capture and test tooling only: the next attacks are these ids in order (cycling), ignoring weights and distance windows.
func debug_script_attacks(ids: Array[String]) -> void:
	_scripted = ids
	_scripted_index = 0

## Seeds the boss's own attack picks and add placement (the spawner passes the room seed). Never uses the global RNG.
func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value
	_seeded = true


## MB1: true for an act-end mini-boss (bosses.json `mini_boss`), false for the final boss.
func is_mini_boss() -> bool:
	return bool(_def.get("mini_boss", false))


func display_name() -> String:
	return String(_def.get("display_name", enemy_id))


## The HP fractions (of max) at which phases 2..N begin, descending. For the HP bar's pips.
func phase_thresholds() -> Array[float]:
	return BossRules.thresholds(_phases)


func phase_count() -> int:
	return _phases.size()


func phase_name() -> String:
	return String((_phases[phase_index] as Dictionary)["name"]) if phase_index < _phases.size() else ""


## True during the roar (the invulnerable part of a phase change). The stagger before it is is_staggered(); the boss is
## vulnerable then, so ux must not show "Invulnerable" for it.
func is_transitioning() -> bool:
	return _state == State.TRANSITION


## True only while the boss reels (D16): vulnerable, attack interrupted, before the roar.
func is_staggered() -> bool:
	return _state == State.STAGGER


func is_defeated() -> bool:
	return _state == State.DEAD


func state_name() -> String:
	return String(State.keys()[_state])


## The attack being wound up, landed or recovered from ("" while chasing or transitioning).
func current_attack_id() -> String:
	return _attack_id


## Seconds of the current attack's telegraph, and how much is left.
func telegraph_total() -> float:
	return _telegraph_total


func telegraph_left() -> float:
	return maxf(_telegraph_remaining, 0.0)


## MB1: the ground point the current blink wind-up will land on (the marker's centre), or the boss's own position when no blink is winding up.
## A blink is never a threat itself (threat_reach 0, in_threat false, escape_direction zero); the attack it chains into is, once it winds up.
func blink_target() -> Vector3:
	if _state == State.WINDUP and String(_attack.get("kind", "")) == "blink":
		return _blink_point
	return Vector3(global_position.x, 0.0, global_position.z)


## How far from the boss an attack can currently hurt: the sim's bot dodges inside this. 0 while nothing is winding up.
func threat_reach() -> float:
	if _state != State.WINDUP and _state != State.ACTIVE:
		return 0.0
	match String(_attack["kind"]):
		"cone":
			return BossRules.cone_reach(_attack)
		"aoe":
			var farthest: float = 0.0
			for center: Vector3 in _aoe_centers():
				farthest = maxf(farthest, Vector2(center.x - global_position.x, center.z - global_position.z).length())
			return BossRules.aoe_reach(_attack) + farthest
		"volley":
			return float(_attack["shot_range"])
		"charge":
			return float(_attack["distance"]) + BossRules.charge_half_width(_attack)
	return 0.0


## True when a ground point is inside the area the current wind-up (or charge) will hurt.
func in_threat(point: Vector3) -> bool:
	if _state != State.WINDUP and _state != State.ACTIVE:
		return false
	var rel := Vector3(point.x - global_position.x, 0.0, point.z - global_position.z)
	match String(_attack["kind"]):
		"cone":
			if rel.length() > BossRules.cone_reach(_attack):
				return false
			return rel.length() < 0.001 or rad_to_deg(_lock_dir.angle_to(rel)) <= float(_attack["half_angle_degrees"])
		"aoe":
			return BossRules.disc_containing(_aoe_centers(), BossRules.aoe_reach(_attack), point) >= 0
		"volley":
			var half_width: float = BossRules.volley_half_width(_attack)
			for angle: float in BossRules.volley_angles(int(_attack["count"]), float(_attack["spread_degrees"])):
				var dir: Vector3 = _lock_dir.rotated(Vector3.UP, deg_to_rad(angle))
				var along: float = rel.dot(dir)
				if along >= 0.0 and along <= BossRules.MUZZLE + float(_attack["shot_range"]) + half_width and (rel - dir * along).length() <= half_width:
					return true
			return false
		"charge":
			var from_start: Vector3 = Vector3(point.x - _charge_start.x, 0.0, point.z - _charge_start.z)
			var along_lane: float = from_start.dot(_lock_dir)
			var reach: float = BossRules.charge_half_width(_attack)
			return along_lane >= -reach and along_lane <= float(_attack["distance"]) + reach and (from_start - _lock_dir * along_lane).length() <= reach
	return false


## The unit direction (flat) that gets a player standing at `point` out of the current hazard in the fewest metres, or
## zero if it is not in one. Samples 16 directions and keeps the arena in mind. Used by the sim bot and the fairness test.
func escape_direction(point: Vector3) -> Vector3:
	if not in_threat(point):
		return Vector3.ZERO
	var best: Vector3 = Vector3.ZERO
	var best_cost: float = INF
	for step_index in range(16):
		var angle: float = TAU * float(step_index) / 16.0
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var t: float = 0.25
		while t <= 12.0:
			var probe: Vector3 = point + dir * t
			if absf(probe.x) > ARENA_LIMIT + 1.0 or absf(probe.z) > ARENA_LIMIT + 1.0:
				t = INF
				break
			if not in_threat(probe):
				break
			t += 0.25
		if t < best_cost:
			best_cost = t
			best = dir
	return best


func live_adds() -> int:
	var live: Array[Enemy] = []
	for add: Enemy in _adds:
		if is_instance_valid(add) and add.is_inside_tree() and not add.health.is_dead():
			live.append(add)
	_adds = live
	return live.size()


## True while the boss' body does not block the player (a charge and its aftermath while still overlapping, the death).
func is_phased() -> bool:
	return _phased


func begin_spawn_grace(seconds: float) -> void:
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining, seconds)


# ---- The brain ----

func _physics_process(delta: float) -> void:
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, KNOCKBACK_DECAY * delta)
	_immune_popup_cooldown = maxf(_immune_popup_cooldown - delta, 0.0)
	_state_time += delta
	_tick_restore()
	var move := Vector3.ZERO
	if _state == State.DEAD:
		pass
	elif _state == State.STAGGER:
		_tick_stagger(delta)
	elif _state == State.TRANSITION:
		_tick_transition(delta)
	elif is_stunned():
		# MB1: an elite-rank mini-boss can be stunned (the final boss cannot: rank boss, stun multiplier 0). Like any enemy it drops its
		# wind-up or charge with no hit and stands still (knockback only); the next wind-up gets its full telegraph.
		if _state != State.CHASE:
			_cancel_attack()
	elif not _has_live_target():
		if _state != State.CHASE:
			_cancel_attack()
	else:
		match _state:
			State.CHASE:
				move = _tick_chase(delta)
			State.WINDUP:
				_tick_windup(delta)
			State.ACTIVE:
				move = _tick_charge(delta)
			State.RECOVER:
				if _state_time >= float(_attack["recover"]):
					_finish_recover()
				elif _restoring and _overlaps_target():
					move = _step_away()
	velocity.x = move.x + _knockback_velocity.x
	velocity.z = move.z + _knockback_velocity.z
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	GroundClamp.apply(self)


func _phase() -> Dictionary:
	return _phases[phase_index]


func _flat_to_target() -> Vector3:
	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0
	return to_target


func _enter_chase() -> void:
	_state = State.CHASE
	_state_time = 0.0
	_attack_id = ""
	_attack_cooldown_remaining = float(_phase()["attack_gap"])


## MB1: recovery is over. An attack with a `chain` hands straight on to the named attack: its own full wind-up, re-aimed at the player, with
## no attack gap. A stun, a phase transition or the boss's death never gets here (each cancels the attack first), so they drop the chain.
func _finish_recover() -> void:
	var next_id: String = BossConfig.chain_of(_attack)
	if next_id != "" and _attacks.has(next_id):
		_begin_windup(next_id)
	else:
		_enter_chase()


func _tick_chase(delta: float) -> Vector3:
	var to_target: Vector3 = _flat_to_target()
	var distance: float = to_target.length()
	if _attack_cooldown_remaining <= 0.0:
		var picked: String = _next_scripted() if not _scripted.is_empty() else BossRules.pick(BossRules.eligible(_phase(), _attacks, distance), _rng)
		if picked != "":
			_begin_windup(picked)
			return Vector3.ZERO
	if distance > 0.01:
		_face_direction(to_target.normalized(), delta)
	if _restoring and _overlaps_target():
		return _step_away()
	if distance > attack_range:
		return to_target.normalized() * float(_phase()["move_speed"])
	return Vector3.ZERO


## While still overlapping the player after a charge: ease away from them, or back along the lane when that would
## push the boss out of the arena (a player pinned against a wall).
func _step_away() -> Vector3:
	var to_target: Vector3 = _flat_to_target()
	var away: Vector3 = -to_target.normalized() if to_target.length() > 0.01 else -_lock_dir
	var ahead: Vector3 = global_position + away * 2.0
	if absf(ahead.x) > ARENA_LIMIT or absf(ahead.z) > ARENA_LIMIT:
		away = -_lock_dir
	return away * float(_phase()["move_speed"])


func _next_scripted() -> String:
	var id: String = _scripted[_scripted_index % _scripted.size()]
	_scripted_index += 1
	return id if _attacks.has(id) else ""


func _begin_windup(attack_id: String) -> void:
	_attack_id = attack_id
	_attack = _attacks[attack_id]
	if not is_equal_approx(damage_scale, 1.0):
		_attack = _attack.duplicate()  # the config's own dictionary is shared by every boss: scale a copy
		_attack["damage"] = float(_attack["damage"]) * damage_scale
	_state = State.WINDUP
	_state_time = 0.0
	_knockback_velocity = Vector3.ZERO  # MB1: leftover push from a hit while recovering must not drag the locked lane off the boss
	var to_target: Vector3 = _flat_to_target()
	_lock_dir = to_target.normalized() if to_target.length() > 0.01 else -global_transform.basis.z
	_lock_point = Vector3(target.global_position.x, 0.0, target.global_position.z)
	_charge_start = Vector3(global_position.x, 0.0, global_position.z)
	global_transform.basis = Basis.looking_at(_lock_dir, Vector3.UP)  # the aim is locked for the whole wind-up
	_aoe_locked = []
	if String(_attack["kind"]) == "aoe" and BossConfig.aoe_count(_attack) > 1:
		# MB1: the discs are rolled once, from the boss's own seeded stream, and locked for the whole wind-up.
		_aoe_locked = BossRules.aoe_centers(_lock_point, BossConfig.aoe_count(_attack), BossConfig.aoe_scatter(_attack), _rng, ARENA_LIMIT, BossConfig.aoe_scatter_min(_attack))
	if String(_attack["kind"]) == "blink":
		# MB1: the landing spot is fixed now, from where the player stands now; the player can walk off it (that is the dodge).
		_blink_point = BossRules.blink_landing(global_position, target.global_position, float(_attack["behind"]), ARENA_LIMIT)
	_telegraph_total = BossRules.windup(_attack, _phase())
	_telegraph_remaining = _telegraph_total
	_set_body_color(TELEGRAPH_COLOR)
	_start_telegraph_visual()
	attack_telegraphed.emit(attack_id, String(_attack["label"]), _telegraph_total)


func _tick_windup(delta: float) -> void:
	_telegraph_remaining -= delta
	var progress: float = 1.0 - maxf(_telegraph_remaining, 0.0) / _telegraph_total
	_update_telegraph_visual(progress)
	if _telegraph_remaining <= 0.0:
		_land_attack()


func _telegraph_color() -> Color:
	return ElementVisuals.visual_for_team(String(_attack["damage_type"]), "enemy")["color"]


func _start_telegraph_visual() -> void:
	_tele_pool = EffectPool.for_world(get_parent())
	var color: Color = _telegraph_color()
	match String(_attack["kind"]):
		"cone":
			_active_wedge = _wedge_for(_attack_id, color)
			_active_wedge.show_windup(0.0)
		"aoe":
			var disc_parts: Array[PooledEffect] = []
			for disc_center: Vector3 in _aoe_centers():  # MB1: every disc of a multi-disc cast is drawn at once, for the full wind-up
				disc_parts.append_array(TemplateVfx.aoe_telegraph(_tele_pool, disc_center, BossRules.aoe_reach(_attack), color, true, _aoe_locked.size() > 1))
			_hold_parts(disc_parts)
		"volley":
			var half_width_hit: float = float(_attack["hit_radius"])
			var angles: Array[float] = BossRules.volley_angles(int(_attack["count"]), float(_attack["spread_degrees"]))
			var parts: Array[PooledEffect] = []
			for angle: float in angles:
				var dir: Vector3 = _lock_dir.rotated(Vector3.UP, deg_to_rad(angle))
				var lane: PooledEffect = TemplateVfx.enemy_shot_lane(_tele_pool, global_position + dir * BossRules.MUZZLE, dir, float(_attack["shot_range"]), half_width_hit, color, _telegraph_total, true, true)
				if lane != null:
					parts.append(lane)
			parts.append_array(TemplateVfx.boss_volley_gaps(_tele_pool, global_position, _lock_dir, angles, BossRules.volley_half_width(_attack), _telegraph_total))
			_hold_parts(parts)
		"blink":
			_hold_parts(TemplateVfx.blink_marker(_tele_pool, global_position, _blink_point, BossRules.blink_marker_radius(body_radius), blink_color(), _telegraph_total))
		"charge":
			var lane2: PooledEffect = TemplateVfx.enemy_charge_lane(_tele_pool, global_position, _lock_dir, float(_attack["distance"]), float(_attack["hit_radius"]), color, _telegraph_total, true)
			var single: Array[PooledEffect] = []
			if lane2 != null:
				single.append(lane2)
			_hold_parts(single)


## One ground wedge per cone attack, built once on first use (AttackArcVisual.setup adds its meshes, so it runs once).
func _wedge_for(attack_id: String, color: Color) -> AttackArcVisual:
	if not _wedges.has(attack_id):
		var wedge := AttackArcVisual.new()
		wedge.name = "TelegraphWedge_" + attack_id
		add_child(wedge)
		wedge.setup(BossRules.cone_reach(_attack), float(_attack["half_angle_degrees"]), color, AttackArcVisual.BOSS_EDGE_THICKNESS, true)  # MB1 ux: a thick edge on a dark band
		wedge.set_outline_on_top(true)  # adds standing on the cone must not hide its edge
		_wedges[attack_id] = wedge
	return _wedges[attack_id]


func _hold_parts(parts: Array[PooledEffect]) -> void:
	_tele_parts = parts
	_tele_gens = []
	for part: PooledEffect in parts:
		_tele_gens.append(part.generation)


## The discs the current aoe wind-up threatens: the locked scatter (MB1) or the single disc.
func _aoe_centers() -> Array[Vector3]:
	if not _aoe_locked.is_empty():
		return _aoe_locked
	return [_aoe_center()]


func _aoe_center() -> Vector3:
	return _lock_point if String(_attack["place"]) == "target" else Vector3(global_position.x, 0.0, global_position.z)


func _update_telegraph_visual(progress: float) -> void:
	match String(_attack["kind"]):
		"cone":
			if _active_wedge != null:
				_active_wedge.show_windup(progress)
		"aoe", "blink":
			if _tele_pool != null and is_instance_valid(_tele_pool):
				for index in range(_tele_parts.size()):
					if _tele_pool.is_running(_tele_parts[index], _tele_gens[index]):
						_tele_parts[index].set_progress(progress)


func _stop_telegraph_visual() -> void:
	for wedge: Variant in _wedges.values():
		(wedge as AttackArcVisual).hide_now()
	_active_wedge = null
	if _tele_pool != null and is_instance_valid(_tele_pool):
		for index in range(_tele_parts.size()):
			_tele_pool.stop(_tele_parts[index], _tele_gens[index])
	_tele_parts = []
	_tele_gens = []


## Drops whatever is being wound up (the target died, a transition began, the boss died). No hit lands.
func _cancel_attack() -> void:
	_aoe_locked = []
	_stop_telegraph_visual()
	_telegraph_remaining = 0.0
	_set_body_color(_rest_color())
	if _state == State.ACTIVE:
		_end_phasing_soon()
	_state = State.CHASE
	_state_time = 0.0
	_attack_id = ""


func _rest_color() -> Color:
	if _state == State.STAGGER:
		return STAGGER_COLOR
	return TELEGRAPH_COLOR if _state == State.WINDUP else super()


func _land_attack() -> void:
	_stop_telegraph_visual()
	_set_body_color(_rest_color())
	_telegraph_remaining = 0.0
	var kind: String = String(_attack["kind"])
	var hit_player: bool = false
	var pool: EffectPool = EffectPool.for_world(get_parent())
	var context := EffectContext.new(self, WorldRef.get_world(get_tree()), hurtbox.team if hurtbox != null else "enemy")
	context.origin = "enemy"
	var color: Color = _telegraph_color()
	match kind:
		"cone":
			EffectTemplates.execute("cone", {
				"damage": float(_attack["damage"]), "damage_type": String(_attack["damage_type"]), "range": float(_attack["range"]),
				"half_angle_degrees": float(_attack["half_angle_degrees"]), "knockback_strength": float(_attack["knockback"]), "vfx": false,
			}, context)
			hit_player = not context.last_hits.is_empty()
			TemplateVfx.cone_sweep(pool, global_position, atan2(-_lock_dir.x, -_lock_dir.z), BossRules.cone_reach(_attack), float(_attack["half_angle_degrees"]), color, true)
		"aoe" when not _aoe_locked.is_empty():
			hit_player = _land_multi_aoe(pool)
		"aoe":
			var center: Vector3 = _aoe_center()
			EffectTemplates.execute("aoe", {
				"damage": float(_attack["damage"]), "damage_type": String(_attack["damage_type"]), "radius": float(_attack["radius"]),
				"center": center, "knockback_strength": float(_attack["knockback"]), "vfx": false,
			}, context)
			hit_player = not context.last_hits.is_empty()
			TemplateVfx.aoe(pool, center, BossRules.aoe_reach(_attack), ElementVisuals.visual_for_team(String(_attack["damage_type"]), "enemy"))
		"volley":
			for angle: float in BossRules.volley_angles(int(_attack["count"]), float(_attack["spread_degrees"])):
				EffectTemplates.execute("projectile", {
					"damage": float(_attack["damage"]), "damage_type": String(_attack["damage_type"]), "speed": float(_attack["speed"]),
					"max_range": float(_attack["shot_range"]), "hit_radius": float(_attack["hit_radius"]),
					"knockback_strength": float(_attack["knockback"]), "yaw_degrees": angle,
				}, context)
		"blink":
			_blink_now(pool)
		"charge":
			_state = State.ACTIVE
			_state_time = 0.0
			_charge_traveled = 0.0
			_charge_last = global_position
			_charge_hit = false
			_set_phased(true)
			_restoring = false
			attack_landed.emit(_attack_id, false)
			return
	Juice.screen_shake(float(_attack["shake"]), float(_attack["shake_duration"]))
	if hit_player:
		Juice.hit_stop(float(_attack["hit_stop"]), 0.05)
	attack_landed.emit(_attack_id, hit_player)
	_state = State.RECOVER
	_state_time = 0.0


## MB1: the teleport of a blink. The marker was locked at wind-up start; if the player stands on it by now (or it would not clear them), the
## landing slides to the boss's side of the player (BossRules.blink_landing). No damage; faces the player on arrival.
func _blink_now(pool: EffectPool) -> void:
	var from: Vector3 = global_position
	var spot: Vector3 = _blink_point
	if _has_live_target() and Vector2(spot.x - target.global_position.x, spot.z - target.global_position.z).length() < BossRules.BLINK_MIN_GAP:
		# Re-resolve from the boss's side of the player: the line is the same, only the side flips.
		spot = BossRules.blink_landing(target.global_position * 2.0 - from, target.global_position, float(_attack["behind"]), ARENA_LIMIT)
	var look: Dictionary = {"color": blink_color(), "scale": 1.5}
	TemplateVfx.dash_start(pool, from, look)
	global_position = Vector3(spot.x, global_position.y, spot.z)
	velocity = Vector3.ZERO
	_knockback_velocity = Vector3.ZERO
	TemplateVfx.dash_end(pool, global_position, look)
	if _has_live_target():
		var face: Vector3 = _flat_to_target()
		if face.length() > 0.01:
			global_transform.basis = Basis.looking_at(face.normalized(), Vector3.UP)
	_blink_point = global_position


## MB1: lands every disc of a multi-disc aoe at once. Each hurtbox is damaged at most once per cast, by the first disc that holds it.
## Returns true when something was hit.
func _land_multi_aoe(pool: EffectPool) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var team: String = hurtbox.team if hurtbox != null else "enemy"
	var reach: float = BossRules.aoe_reach(_attack)
	var hit: Array[Hurtbox] = []
	var look: Dictionary = ElementVisuals.visual_for_team(String(_attack["damage_type"]), "enemy")
	for center: Vector3 in _aoe_centers():
		for victim: Hurtbox in MeleeQuery.find_hurtboxes_in_sphere(space, center, float(_attack["radius"]), team, CollisionLayers.HURTBOX):
			if hit.has(victim):
				continue
			hit.append(victim)
			victim.receive_damage(float(_attack["damage"]), String(_attack["damage_type"]),
					EffectTemplates.knockback_from(center, victim.global_position, float(_attack["knockback"])), self, Health.KIND_HIT, "enemy")
		TemplateVfx.aoe(pool, center, reach, look)
	_aoe_locked = []
	return not hit.is_empty()


## The charge: runs along the locked lane at speed, hurting the target once when the swept sphere touches it.
func _tick_charge(_delta: float) -> Vector3:
	var speed: float = float(_attack["speed"])
	var distance: float = float(_attack["distance"])
	_charge_traveled += global_position.distance_to(_charge_last)
	_charge_last = global_position
	if not _charge_hit:
		_charge_hit = _charge_sweep()
	if _charge_traveled >= distance or _state_time >= distance / speed + CHARGE_SLACK:
		_end_charge()
		return Vector3.ZERO
	return _lock_dir * speed


func _charge_sweep() -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var hits := MeleeQuery.find_hurtboxes_in_sphere(space, Vector3(global_position.x, 0.0, global_position.z), float(_attack["hit_radius"]), "enemy", CollisionLayers.HURTBOX)
	if hits.is_empty():
		return false
	for hurtbox_hit: Hurtbox in hits:
		hurtbox_hit.receive_damage(float(_attack["damage"]), String(_attack["damage_type"]),
				EffectTemplates.knockback_from(global_position - _lock_dir * 0.5, hurtbox_hit.global_position, float(_attack["knockback"])), self, Health.KIND_HIT, "enemy")
	Juice.screen_shake(float(_attack["shake"]), float(_attack["shake_duration"]))
	Juice.hit_stop(float(_attack["hit_stop"]), 0.05)
	attack_landed.emit(_attack_id, true)
	return true


func _end_charge() -> void:
	if not _charge_hit:
		attack_landed.emit(_attack_id, false)
		Juice.screen_shake(float(_attack["shake"]) * 0.5, float(_attack["shake_duration"]))
	_end_phasing_soon()
	_state = State.RECOVER
	_state_time = 0.0


# ---- Solidity (the pinning rule) ----

func _set_phased(on: bool) -> void:
	_phased = on
	if on:
		collision_layer = 0
		collision_mask = _default_collision_mask & ~(CollisionLayers.PLAYER_BODY | CollisionLayers.ENEMY_BODY)
	else:
		collision_layer = _layer_default
		collision_mask = (_default_collision_mask & ~CollisionLayers.PLAYER_BODY) if Enemy.is_player_body_suppressed() else _default_collision_mask


## After a charge (or a transition): become solid again as soon as the player's body is clear of ours.
func _end_phasing_soon() -> void:
	_restoring = true


## Solid again only when the player's body is clear of ours (never on top of them: a boss that turned solid there
## would eject the player, maybe through a wall). Until then it stays non-solid, so nobody is ever blocked or pinned.
func _tick_restore() -> void:
	if _phased and (collision_mask & CollisionLayers.PLAYER_BODY) != 0:
		_set_phased(true)  # something (the pass-through buff ending) put the player bit back: take it out again
	if not _restoring or _state == State.DEAD:
		return
	if _overlaps_target():
		return
	_restoring = false
	_set_phased(false)


func _overlaps_target() -> bool:
	if not _has_live_target():
		return false
	return _flat_to_target().length() < body_radius + PLAYER_BODY_RADIUS + RESTORE_MARGIN


# ---- Damage, phases, death ----

func _on_damaged(amount: float, damage_type: String, knockback: Vector3) -> void:
	# MB1: a boss that takes knockback (the duelist) must not slide while a wind-up or charge is locked: the charge lane and its telegraph are
	# anchored where the wind-up began, so a shove would put the real dash off the drawn lane. Hits push it while it chases or recovers.
	if _state != State.WINDUP and _state != State.ACTIVE:
		_knockback_velocity = knockback * float(_def.get("knockback_taken", 0.0))
	_flash_body(HIT_FLASH_COLOR)
	Juice.on_hit_landed(global_position + Vector3(0.0, 1.5, 0.0), amount, damage_type, health.last_kind, health.last_channel, health.last_reduction)
	if is_transitioning() or is_staggered() or _state == State.DEAD or phase_index + 1 >= _phases.size():
		return
	if health.current_health <= health.hp_floor + 0.001:
		_begin_transition(phase_index + 1)


## A phase threshold was reached. First the stagger (D16): the current attack is dropped, the boss reels, and the floor
## that held it at the threshold is lowered to the floor of the threshold after it, so hits during the stagger are real
## damage (a hit can still never carry it past the following threshold; that one is held for the transition after).
## Then the roar. A stagger of 0 in data goes straight to the roar.
func _begin_transition(next_index: int) -> void:
	_cancel_attack()
	_entering_phase = next_index
	var stagger: float = BossConfig.stagger_seconds(_def)
	if stagger <= 0.0:
		_begin_roar()
		return
	_state = State.STAGGER
	_state_time = 0.0
	_stagger_left = stagger
	# The stagger into the LAST phase keeps a 1 HP floor (floor_hp is 0 there): the boss can't die in it and skip
	# the final phase and its adds. The roar sets the real floor (0) afterwards.
	health.hp_floor = maxf(BossRules.floor_hp(_phases, next_index + 1, health.max_health), 1.0)
	_start_reel(stagger)
	stagger_started.emit(next_index, stagger)


func _tick_stagger(delta: float) -> void:
	_stagger_left -= delta
	if _stagger_left <= 0.0:
		_stop_reel()
		stagger_ended.emit(_entering_phase)
		_begin_roar()


## The visible reel: a backward tilt that eases back and a pale-blue tint, for the stagger's length.
func _start_reel(seconds: float) -> void:
	_set_body_color(STAGGER_COLOR)
	if _stagger_tween != null and _stagger_tween.is_valid():
		_stagger_tween.kill()
	_stagger_tween = create_tween()
	_stagger_tween.tween_property(body_mesh, "rotation:x", -STAGGER_TILT, seconds * 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stagger_tween.tween_property(body_mesh, "rotation:x", 0.0, seconds * 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_reel() -> void:
	if _stagger_tween != null and _stagger_tween.is_valid():
		_stagger_tween.kill()
	_stagger_tween = null
	body_mesh.rotation.x = 0.0


## The roar: invulnerable for `transition.duration` seconds, then the phase changes.
func _begin_roar() -> void:
	_state = State.TRANSITION
	_state_time = 0.0
	var cfg: Dictionary = _def["transition"]
	_transition_left = float(cfg["duration"])
	health.damage_immune = true
	var pool: EffectPool = EffectPool.for_world(get_parent())
	TemplateVfx.boss_roar(pool, global_position, float(cfg["ring_size"]), _transition_left)
	_set_body_color(Color(1.0, 0.95, 0.7))
	Juice.screen_shake(float(cfg["shake"]), float(cfg["shake_duration"]))
	Juice.hit_stop(float(cfg["hit_stop"]), 0.05)
	transition_started.emit(_entering_phase, _transition_left)


func _tick_transition(delta: float) -> void:
	_transition_left -= delta
	if _transition_left <= 0.0:
		_end_transition()


func _end_transition() -> void:
	phase_index = _entering_phase
	health.hp_floor = BossRules.floor_hp(_phases, phase_index + 1, health.max_health)
	health.damage_immune = false
	_set_body_color(_rest_color())
	_state = State.CHASE
	_state_time = 0.0
	_attack_cooldown_remaining = float(_phase()["attack_gap"])
	phase_changed.emit(phase_index, phase_name())
	transition_ended.emit(phase_index)
	if (_phase() as Dictionary).has("summon"):
		var summon: Dictionary = _phase()["summon"]
		_summon(String(summon["enemy"]), int(summon["count"]))
	# Stagger hits may have carried it all the way down to the next threshold; the floor holds it there, so no later hit
	# would announce the crossing. Start that transition now.
	if phase_index + 1 < _phases.size() and health.current_health <= health.hp_floor + 0.001:
		_begin_transition(phase_index + 1)


## Spawns up to `count` of `enemy` around the boss, never more than max_adds_alive at once (BossConfig caps it far
## below the room's max_alive). The boss places and counts them itself; they die with it.
func _summon(enemy: String, count: int) -> void:
	var room: int = maxi(int(_def["max_adds_alive"]) - live_adds(), 0)
	var to_spawn: int = mini(count, room)
	var path: String = EnemyConfig.scene_path_for(enemy)
	if to_spawn <= 0 or path == "" or get_parent() == null:
		return
	var scene: PackedScene = load(path) as PackedScene
	var spawned: Array[Enemy] = []
	for index in range(to_spawn):
		var angle: float = _rng.randf_range(0.0, TAU)
		var ring: float = _rng.randf_range(ADD_RING_MIN, ADD_RING_MAX)
		var spot := Vector3(clampf(global_position.x + cos(angle) * ring, -ARENA_LIMIT, ARENA_LIMIT), 0.0, clampf(global_position.z + sin(angle) * ring, -ARENA_LIMIT, ARENA_LIMIT))
		var add: Enemy = scene.instantiate()
		add.position = (get_parent() as Node3D).to_local(spot)
		get_parent().add_child(add)
		add.global_position = spot
		add.target = target
		add.begin_spawn_grace(1.5)
		_adds.append(add)
		spawned.append(add)
	adds_summoned.emit(spawned)


func _on_died() -> void:
	if _state == State.DEAD:
		return
	_stop_shot_lane()
	_stop_reel()
	_stop_telegraph_visual()
	_telegraph_remaining = 0.0
	_state = State.DEAD
	_attack_id = ""
	_restoring = false
	_set_phased(true)
	for add: Enemy in _adds:
		if is_instance_valid(add):
			add.queue_free()
	_adds = []
	# The fight is won: nothing still in the air may kill the player now.
	if target != null and is_instance_valid(target) and "health" in target:
		((target as Object).get("health") as Health).damage_immune = true
	var cfg: Dictionary = _def["death"]
	Juice.slow_mo(float(cfg["beat_seconds"]), float(cfg["slow_mo_scale"]))
	Juice.screen_shake(float(cfg["shake"]), float(cfg["shake_duration"]))
	TemplateVfx.boss_death(EffectPool.for_world(get_parent()), global_position, body_radius * 5.0)
	_death_total = float(cfg["beat_seconds"])
	_death_left = _death_total
	_death_last_usec = Time.get_ticks_usec()
	if not GamePause.paused_changed.is_connected(_on_pause_changed):
		GamePause.paused_changed.connect(_on_pause_changed)
	set_process(true)
	defeated.emit()


## Time spent paused does not count towards the beat (like Main's own beat).
func _on_pause_changed(_is_paused: bool) -> void:
	_death_last_usec = Time.get_ticks_usec()


func _exit_tree() -> void:
	super()
	if GamePause.paused_changed.is_connected(_on_pause_changed):
		GamePause.paused_changed.disconnect(_on_pause_changed)


## The death beat is counted on the wall clock (not on the time scale the slow-mo changes), like Main's own beat.
## With hit-stop and slow-mo off (the sims) the time scale never changes, so game time is exact and keeps a seeded
## run repeating: a wall-clock beat would be 35 sim seconds at sim speed and vary with the machine.
func _process(delta: float) -> void:
	if _death_left < 0.0:
		set_process(false)
		return
	if Juice.hit_stop_enabled:
		var now: int = Time.get_ticks_usec()
		_death_left -= minf(float(now - _death_last_usec) / 1000000.0, MAX_BEAT_STEP)
		_death_last_usec = now
	else:
		_death_left -= delta
	var progress: float = clampf(1.0 - _death_left / _death_total, 0.0, 1.0)
	_set_body_color(Color(1.0, 0.95, 0.8).lerp(_base_color, 0.0 if progress < 0.7 else (progress - 0.7) / 0.3))
	if progress > 0.6:
		body_mesh.scale = _mesh_scale * lerpf(1.0, 0.0, (progress - 0.6) / 0.4)
	if _death_left <= 0.0:
		_death_left = -1.0
		set_process(false)
		queue_free()
