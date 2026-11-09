class_name EffectTemplates
extends RefCounted
## The reusable building blocks every card effect is made of. A card never
## gets new code for a new effect - only a new entry in its "effects" array
## naming one of these templates and its params. Element visuals are a
## recolor/rescale of the same template, not a new template.
##
## REQUIRED_PARAMS is the single source of truth for what a template needs;
## CardSchema validates against it directly so the two can't drift apart.

const REQUIRED_PARAMS: Dictionary = {
	"projectile": ["damage", "damage_type", "speed", "max_range", "hit_radius"],
	"cone": ["damage", "damage_type", "range", "half_angle_degrees"],
	"aoe": ["damage", "damage_type", "radius"],
	"dash": ["distance", "speed"],
	"heal": ["amount"],
	"apply_status": ["status_id", "duration"],
	"buff": ["stat", "modifier_type", "value", "duration"],
	"zone": ["shape", "duration", "tick_interval", "damage", "damage_type", "max_range"],
	"pass_through": ["duration"],
	"reduce_cooldown": ["seconds"],
	"detonate_status": ["status_id", "multiplier"],
}

## Optional params, validated by validate_params (CardSchema calls it). Absent = old behaviour.
##   hits (whole number 1..MAX_HITS, default 1) and hit_interval (seconds > 0, required when
##   hits > 1): the effect repeats `hits` times, `hit_interval` apart. Cone and aoe re-query
##   from the caster's pose at each hit; a projectile fires `hits` shots; apply_status re-rolls
##   against the latest hit set, so give it the same hits/hit_interval as the damage effect to
##   roll its chance once per hit.
##   chance (0..1, default 1), apply_status only: rolled per target on the shared seeded RNG.
const MULTI_HIT_TEMPLATES: Array[String] = ["cone", "aoe", "projectile", "apply_status"]
const MAX_HITS := 20
const MAX_HIT_INTERVAL := 5.0
const STATUS_TARGETS: Array[String] = ["last_hits", "self"]

## C1-b2 params (validated by validate_params, which rejects unknown keys for these templates):
##   zone (required above): shape "circle" (+ radius) or "line" (+ length, width); max_range = how far
##     from the caster it may be placed (the aim point is clamped to it); optional knockback_strength,
##     status_id + status_duration (+ status_chance 0..1, default 1) applied each tick.
##   pass_through: duration only. The caster's body stops colliding with enemy bodies.
##   dash (optional, F1): pass_through (bool, default false) = the caster ignores enemy bodies for exactly this move (set on every
##     movement-slot dash card; the dodge is not a card and stays blocked). A move ending inside a body waits to turn solid again.
##   dash (optional): direction_mode "forward" | "away_from_aim"; damage + damage_type + hit_radius
##     (+ knockback_strength) hit each enemy along the path at most once per dash.
##   aoe (optional): max_range places the disc at the aim point clamped to that range (a card version of
##     the targeted_aoe heavy); without it the disc is centred on the caster.
##   projectile (optional, 3c): yaw_degrees turns the shot's direction about the vertical axis (a fan of shots).
##   projectile (optional, BD3a): status_id + status_duration apply that status to the target the shot hits (a knife that cuts); the card's origin
##     is stamped on it, like a card status. Both or neither.
##   dash (optional, BD3a): status_id + status_duration apply that status to every enemy the dash passes through (needs hit_radius, no damage needed).
##   projectile (optional, W1a, code-only): direction (a Vector3, flattened by the caller) replaces the caster's facing; lane false
##     skips the player's hit-area strip (the auto-firing Wizard bolt would flood the effect pool with one per shot).
##   projectile (optional, W1a ux, code-only): look ({"color": Color, "scale": float}) replaces the element look, so one caster's shots
##     can read differently from a card's (the Wizard's light bolt). Cosmetic only.
##   aoe (optional, 3c): vfx false skips the impact visual, for a caller that draws its own at the right reach (the boss).
##   aoe (optional, C1-c): delay (seconds, 0..MAX_AOE_DELAY) locks the disc where it is at cast, shows the shared
##     ground telegraph growing for `delay`, then hits. A caster that dies or is freed in that time cancels the hit.
const ZONE_KEYS: Array[String] = ["shape", "duration", "tick_interval", "damage", "damage_type", "max_range", "radius", "length", "width",
		"knockback_strength", "status_id", "status_duration", "status_chance"]
const DASH_KEYS: Array[String] = ["distance", "speed", "invulnerable", "damage_type", "direction_mode", "damage", "hit_radius", "knockback_strength", "pass_through", "status_id", "status_duration"]
const DASH_DIRECTION_MODES: Array[String] = ["forward", "away_from_aim"]
const DIRECTION_FORWARD := "forward"
const DIRECTION_AWAY := "away_from_aim"
const MAX_ZONE_DURATION := 30.0
const MAX_ZONE_TICKS := 200
const MAX_PLACE_RANGE := 30.0
const MAX_PASS_THROUGH := 30.0
const MAX_AOE_DELAY := 3.0
## aoe (optional, BD1): anchor "caster" locks the disc at the caster's position at cast time (a delayed blast left at
## the start of a blink). Not combinable with max_range (which places the disc at the aim point).
const AOE_ANCHORS: Array[String] = ["caster"]
const ANCHOR_CASTER := "caster"
## buff (optional, BD1): consume_on_cast (a slot type id or a tag) and charges (whole number 1..MAX_BUFF_CHARGES,
## default 1) make it a primed buff: used up by that many matching casts after the one that applied it, or when
## `duration` runs out. See StatModifiers.add_primed_modifier.
const MAX_BUFF_CHARGES := 20
## A status_damage_mult buff (or relic modifier) must keep the factor above zero: value > this floor (base 1.0).
const STATUS_DAMAGE_MULT_FLOOR := -1.0
## BD2-B generic factor stats (base 1.0, read by one code path each; relics and buffs may grant them). Like status_damage_mult,
## a change of -1 or less would make the factor zero or negative, so the validator refuses it.
##   card_damage_mult_vs_status.<status_id>: card hits (origin card:*) deal this factor more to a target holding the status (Health.take_damage).
##   zone_duration_mult: zones the caster places last this factor as long (ZoneManager.spawn).
## And one additive stat: zone_status_chance adds to the chance of a zone's status each tick (ZoneManager.spawn), capped at 1.
const CARD_DAMAGE_VS_STATUS_PREFIX := "card_damage_mult_vs_status."
const ZONE_DURATION_MULT_STAT := "zone_duration_mult"
## MAP2-B: damage_mult scales every hit the owner deals (Health.take_damage), base 1.0 (Liquidate Assets).
const DAMAGE_MULT_STAT := "damage_mult"
const ZONE_STATUS_CHANCE_STAT := "zone_status_chance"
## reduce_cooldown (BD2-B, a new effect type): takes `seconds` off the running cooldown of the caster's `slot_type` slot (never below ready).
const MAX_REDUCE_COOLDOWN := 60.0
## detonate_status (BD3a, a new effect type): every target in last_hits that holds `status_id` (a damage_over_time status) takes its
## remaining ticks x damage per tick x stacks x `multiplier` at once, then loses the status (see StatusEffectManager.detonate_status).
const MAX_DETONATE_MULTIPLIER := 20.0

const PROJECTILE_SCENE_PATH := "res://scenes/effects/Projectile.tscn"
## A shot leaves this far in front of the caster (the cast preview lane starts here too).
const PROJECTILE_MUZZLE_OFFSET := 0.6


static func is_known_template(template_id: String) -> bool:
	return REQUIRED_PARAMS.has(template_id)


static func required_params(template_id: String) -> Array:
	return REQUIRED_PARAMS.get(template_id, [])


## Problems with the optional params of one effect (empty = fine). Required params are
## CardSchema's job; this checks types and ranges of the multi-hit and chance fields.
static func validate_params(template_id: String, params: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var multi: bool = MULTI_HIT_TEMPLATES.has(template_id)
	for key: String in ["hits", "hit_interval"]:
		if params.has(key) and not multi:
			errors.append("'%s' is not supported by the %s template" % [key, template_id])
	if params.has("chance") and template_id != "apply_status":
		errors.append("'chance' is only supported by apply_status")
	var hits: int = 1
	if multi and params.has("hits"):
		var value: Variant = params["hits"]
		if not _is_number(value) or float(value) != floorf(float(value)) or float(value) < 1.0 or float(value) > float(MAX_HITS):
			errors.append("'hits' must be a whole number from 1 to %d" % MAX_HITS)
		else:
			hits = int(value)
	if multi and params.has("hit_interval"):
		var interval: Variant = params["hit_interval"]
		if not _is_number(interval) or is_nan(float(interval)) or float(interval) <= 0.0 or float(interval) > MAX_HIT_INTERVAL:
			errors.append("'hit_interval' must be a number above 0 and at most %s" % str(MAX_HIT_INTERVAL))
	elif multi and hits > 1:
		errors.append("'hit_interval' is required when 'hits' is more than 1")
	if template_id == "apply_status":
		if params.has("chance"):
			var chance: Variant = params["chance"]
			if not _is_number(chance) or is_nan(float(chance)) or float(chance) < 0.0 or float(chance) > 1.0:
				errors.append("'chance' must be a number from 0 to 1")
		if params.has("target") and not (typeof(params["target"]) == TYPE_STRING and STATUS_TARGETS.has(String(params["target"]))):
			errors.append("'target' must be one of %s" % str(STATUS_TARGETS))
		if typeof(params.get("status_id")) == TYPE_STRING and not StatusDatabase.has_status(String(params["status_id"])):
			errors.append("unknown status_id '%s'" % String(params["status_id"]))
	if template_id == "projectile" or template_id == "dash":
		_validate_on_hit_status(template_id, params, errors)
	if params.has("look") and template_id == "projectile" and params["look"] is Dictionary and not (params["look"] as Dictionary).is_empty():
		errors.append_array(validate_look(params["look"]))
	match template_id:
		"zone":
			_validate_zone(params, errors)
		"pass_through":
			_validate_pass_through(params, errors)
		"dash":
			_validate_dash(params, errors)
		"aoe":
			if params.has("max_range") and not _number_in(params["max_range"], 0.0, MAX_PLACE_RANGE, false):
				errors.append("'max_range' must be a number above 0 and at most %s" % str(MAX_PLACE_RANGE))
			if params.has("delay") and not _number_in(params["delay"], 0.0, MAX_AOE_DELAY, false):
				errors.append("'delay' must be a number above 0 and at most %s" % str(MAX_AOE_DELAY))
			if params.has("anchor"):
				if not (typeof(params["anchor"]) == TYPE_STRING and AOE_ANCHORS.has(String(params["anchor"]))):
					errors.append("'anchor' must be one of %s" % str(AOE_ANCHORS))
				elif params.has("max_range"):
					errors.append("'anchor' and 'max_range' cannot be combined (max_range places the disc at the aim point)")
		"buff":
			_validate_buff(params, errors)
		"reduce_cooldown":
			_validate_reduce_cooldown(params, errors)
		"detonate_status":
			_validate_detonate_status(params, errors)
	return errors


## True when `value` is a finite number in (min, max] (or [min, max] when `inclusive_min`).
static func number_in(value: Variant, minimum: float, maximum: float, inclusive_min: bool) -> bool:
	return _number_in(value, minimum, maximum, inclusive_min)


static func _number_in(value: Variant, minimum: float, maximum: float, inclusive_min: bool) -> bool:
	if not _is_number(value):
		return false
	var number: float = float(value)
	if is_nan(number) or is_inf(number) or number > maximum:
		return false
	return number >= minimum if inclusive_min else number > minimum


## True for a stat whose base is 1.0 and which must stay above zero (a "factor" stat).
static func is_factor_stat(stat: String) -> bool:
	return stat.begins_with(StatusEffectManager.STATUS_DAMAGE_MULT_PREFIX) or stat.begins_with(StatusEffectManager.STATUS_TICK_RATE_PREFIX) or stat.begins_with(CARD_DAMAGE_VS_STATUS_PREFIX) or stat == ZONE_DURATION_MULT_STAT or stat == DAMAGE_MULT_STAT


static func _validate_buff(params: Dictionary, errors: Array[String]) -> void:
	if params.has("charges") and not params.has("consume_on_cast"):
		errors.append("'charges' needs 'consume_on_cast'")
	if params.has("consume_on_cast"):
		var consume: Variant = params["consume_on_cast"]
		if typeof(consume) != TYPE_STRING or not (SlotTypeDatabase.has(String(consume)) or CardTags.is_known_tag(String(consume))):
			errors.append("'consume_on_cast' must be a slot type id (%s) or a tag (a derived tag or keyword)" % str(SlotTypeDatabase.known_ids()))
	if params.has("charges"):
		var charges: Variant = params["charges"]
		if not _is_number(charges) or float(charges) != floorf(float(charges)) or float(charges) < 1.0 or float(charges) > float(MAX_BUFF_CHARGES):
			errors.append("'charges' must be a whole number from 1 to %d" % MAX_BUFF_CHARGES)
	var stat: Variant = params.get("stat")
	if typeof(stat) == TYPE_STRING and String(stat).begins_with(StatModifiers.COOLDOWN_SKIP_PREFIX):
		var slot: String = String(stat).substr(StatModifiers.COOLDOWN_SKIP_PREFIX.length())
		if not SlotTypeDatabase.has(slot):
			errors.append("'%s' names an unknown slot type" % String(stat))
		if String(params.get("modifier_type", "")) != StatModifiers.ADDITIVE or not _is_number(params.get("value")) or float(params["value"]) <= 0.0:
			errors.append("a %s buff must be additive with a value above 0" % String(stat))
	if typeof(stat) == TYPE_STRING and is_factor_stat(String(stat)) and _is_number(params.get("value")) and float(params["value"]) <= STATUS_DAMAGE_MULT_FLOOR:
		# The stat's base is 1.0, so a change of -1 or less would make the factor zero or negative.
		errors.append("a %s buff 'value' must be above %s (the factor would be zero or negative)" % [String(stat), str(STATUS_DAMAGE_MULT_FLOOR)])
	if typeof(stat) == TYPE_STRING and String(stat) == ZONE_STATUS_CHANCE_STAT and String(params.get("modifier_type", "")) != StatModifiers.ADDITIVE:
		errors.append("a %s buff must be additive (it adds to the zone's status chance)" % ZONE_STATUS_CHANCE_STAT)
	if typeof(stat) == TYPE_STRING and String(stat).begins_with(CARD_DAMAGE_VS_STATUS_PREFIX) and not StatusDatabase.has_status(String(stat).substr(CARD_DAMAGE_VS_STATUS_PREFIX.length())):
		errors.append("'%s' names an unknown status" % String(stat))


static func _validate_zone(params: Dictionary, errors: Array[String]) -> void:
	for key: Variant in params.keys():
		if not ZONE_KEYS.has(String(key)):
			errors.append("'%s' is not a known zone param" % str(key))
	var shape: String = String(params["shape"]) if typeof(params.get("shape")) == TYPE_STRING else ""
	if not ZoneShape.SHAPES.has(shape):
		errors.append("'shape' must be one of %s" % str(ZoneShape.SHAPES))
	else:
		var wanted: Array[String] = []
		var unwanted: Array[String] = []
		if shape == ZoneShape.CIRCLE:
			wanted.append("radius")
			unwanted.append_array(["length", "width"])
		else:
			wanted.append_array(["length", "width"])
			unwanted.append("radius")
		for key: String in wanted:
			if not params.has(key):
				errors.append("a %s zone needs '%s'" % [shape, key])
			elif not _number_in(params[key], 0.0, 20.0, false):
				errors.append("'%s' must be a number above 0 and at most 20" % key)
		for key: String in unwanted:
			if params.has(key):
				errors.append("'%s' is not used by a %s zone" % [key, shape])
	var duration_ok: bool = params.has("duration") and _number_in(params["duration"], 0.0, MAX_ZONE_DURATION, false)
	if params.has("duration") and not duration_ok:
		errors.append("'duration' must be a number above 0 and at most %s" % str(MAX_ZONE_DURATION))
	if params.has("tick_interval"):
		if not _number_in(params["tick_interval"], 0.0, MAX_ZONE_DURATION, false):
			errors.append("'tick_interval' must be a number above 0 and at most %s" % str(MAX_ZONE_DURATION))
		elif duration_ok and ZoneShape.tick_count(float(params["duration"]), float(params["tick_interval"])) > MAX_ZONE_TICKS:
			errors.append("a zone may tick at most %d times (duration / tick_interval)" % MAX_ZONE_TICKS)
	if params.has("damage") and not _number_in(params["damage"], 0.0, 100000.0, true):
		errors.append("'damage' must be a number from 0 up")
	if params.has("damage_type") and (typeof(params["damage_type"]) != TYPE_STRING or String(params["damage_type"]).is_empty()):
		errors.append("'damage_type' must be a non-empty string")
	if params.has("max_range") and not _number_in(params["max_range"], 0.0, MAX_PLACE_RANGE, false):
		errors.append("'max_range' must be a number above 0 and at most %s" % str(MAX_PLACE_RANGE))
	if params.has("knockback_strength") and not _number_in(params["knockback_strength"], 0.0, 100.0, true):
		errors.append("'knockback_strength' must be a number from 0 to 100")
	var has_status: bool = params.has("status_id")
	if has_status:
		if typeof(params["status_id"]) != TYPE_STRING or not StatusDatabase.has_status(String(params["status_id"])):
			errors.append("unknown status_id '%s'" % str(params["status_id"]))
		if not params.has("status_duration") or not _number_in(params["status_duration"], 0.0, 600.0, false):
			errors.append("a zone with a status needs 'status_duration' above 0 and at most 600")
	else:
		for key: String in ["status_duration", "status_chance"]:
			if params.has(key):
				errors.append("'%s' needs 'status_id'" % key)
	if params.has("status_chance") and not _number_in(params["status_chance"], 0.0, 1.0, true):
		errors.append("'status_chance' must be a number from 0 to 1")
	if _is_number(params.get("damage")) and float(params["damage"]) == 0.0 and not has_status:
		errors.append("a zone with damage 0 needs a status")


## BD3a: the optional on-hit status of a projectile or a dash (`status_id` with `status_duration`, both or neither).
static func _validate_on_hit_status(template_id: String, params: Dictionary, errors: Array[String]) -> void:
	if params.has("status_id") != params.has("status_duration"):
		errors.append("%s: 'status_id' and 'status_duration' go together" % template_id)
		return
	if not params.has("status_id"):
		return
	if typeof(params["status_id"]) != TYPE_STRING or not StatusDatabase.has_status(String(params["status_id"])):
		errors.append("unknown status_id '%s'" % str(params["status_id"]))
	if not _number_in(params["status_duration"], 0.0, 60.0, false):
		errors.append("'status_duration' must be a number above 0 and at most 60")


static func _validate_detonate_status(params: Dictionary, errors: Array[String]) -> void:
	for key: Variant in params.keys():
		if not ["status_id", "multiplier"].has(String(key)):
			errors.append("'%s' is not a known detonate_status param" % str(key))
	if typeof(params.get("status_id")) == TYPE_STRING:
		var status_id: String = String(params["status_id"])
		if not StatusDatabase.has_status(status_id):
			errors.append("unknown status_id '%s'" % status_id)
		elif String(StatusDatabase.get_status(status_id).get("effect_type", "")) != "damage_over_time":
			errors.append("detonate_status needs a damage_over_time status, '%s' is not one" % status_id)
	if params.has("multiplier") and not _number_in(params["multiplier"], 0.0, MAX_DETONATE_MULTIPLIER, false):
		errors.append("'multiplier' must be a number above 0 and at most %s" % str(MAX_DETONATE_MULTIPLIER))


## BD3a: exactly one of `slot_type` (a card slot) or `attack_id` ("light" or "heavy", the basic attack's own cooldown; Muscle Memory).
const REDUCE_COOLDOWN_ATTACKS: Array[String] = ["light", "heavy"]


static func _validate_reduce_cooldown(params: Dictionary, errors: Array[String]) -> void:
	for key: Variant in params.keys():
		if not ["slot_type", "attack_id", "seconds"].has(String(key)):
			errors.append("'%s' is not a known reduce_cooldown param" % str(key))
	if params.has("slot_type") == params.has("attack_id"):
		errors.append("reduce_cooldown needs exactly one of 'slot_type' and 'attack_id'")
	elif params.has("attack_id"):
		if typeof(params["attack_id"]) != TYPE_STRING or not REDUCE_COOLDOWN_ATTACKS.has(String(params["attack_id"])):
			errors.append("'attack_id' must be one of %s" % str(REDUCE_COOLDOWN_ATTACKS))
	elif typeof(params["slot_type"]) != TYPE_STRING or not SlotTypeDatabase.has(String(params["slot_type"])):
		errors.append("'slot_type' must be one of %s" % str(SlotTypeDatabase.known_ids()))
	if params.has("seconds") and not _number_in(params["seconds"], 0.0, MAX_REDUCE_COOLDOWN, false):
		errors.append("'seconds' must be a number above 0 and at most %s" % str(MAX_REDUCE_COOLDOWN))


static func _validate_pass_through(params: Dictionary, errors: Array[String]) -> void:
	for key: Variant in params.keys():
		if String(key) != "duration":
			errors.append("'%s' is not a known pass_through param" % str(key))
	if params.has("duration") and not _number_in(params["duration"], 0.0, MAX_PASS_THROUGH, false):
		errors.append("'duration' must be a number above 0 and at most %s" % str(MAX_PASS_THROUGH))


static func _validate_dash(params: Dictionary, errors: Array[String]) -> void:
	for key: Variant in params.keys():
		if not DASH_KEYS.has(String(key)):
			errors.append("'%s' is not a known dash param" % str(key))
	if params.has("direction_mode") and not (typeof(params["direction_mode"]) == TYPE_STRING and DASH_DIRECTION_MODES.has(String(params["direction_mode"]))):
		errors.append("'direction_mode' must be one of %s" % str(DASH_DIRECTION_MODES))
	if params.has("pass_through") and typeof(params["pass_through"]) != TYPE_BOOL:
		errors.append("'pass_through' must be true or false")
	if params.has("damage"):
		if not _number_in(params["damage"], 0.0, 100000.0, false):
			errors.append("'damage' must be a number above 0")
		if not params.has("hit_radius"):
			errors.append("a dash with 'damage' needs 'hit_radius'")
		if typeof(params.get("damage_type")) != TYPE_STRING or String(params.get("damage_type")).is_empty():
			errors.append("a dash with 'damage' needs a 'damage_type'")
	else:
		for key: String in ["hit_radius", "knockback_strength"]:
			if params.has(key) and not (key == "hit_radius" and params.has("status_id")):
				errors.append("'%s' needs 'damage'" % key)
		if params.has("status_id") and not params.has("hit_radius"):
			errors.append("a dash with 'status_id' needs 'hit_radius'")
	if params.has("hit_radius") and not _number_in(params["hit_radius"], 0.0, 5.0, false):
		errors.append("'hit_radius' must be a number above 0 and at most 5")
	if params.has("knockback_strength") and not _number_in(params["knockback_strength"], 0.0, 100.0, true):
		errors.append("'knockback_strength' must be a number from 0 to 100")


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT


## Runs `fire(hit_index)` now, then once more per extra hit at hit_interval spacing (absolute
## delays from the cast, so two effects with the same hits/hit_interval land on the same
## frame in card order). The timers respect pause and the time scale (hit-stop slows them
## too). A repeat is dropped if the caster is gone, dead, or out of the tree (death, reload).
static func _run_hits(params: Dictionary, context: EffectContext, fire: Callable) -> void:
	fire.call(0)
	var hits: int = int(params.get("hits", 1))
	if hits <= 1 or not context.caster.is_inside_tree():
		return
	var interval: float = float(params["hit_interval"])
	var tree: SceneTree = context.caster.get_tree()
	for index in range(1, hits):
		tree.create_timer(interval * index, false, true).timeout.connect(func() -> void:
			if _caster_active(context):
				fire.call(index))


static func _caster_active(context: EffectContext) -> bool:
	if context.caster == null or not is_instance_valid(context.caster) or not context.caster.is_inside_tree():
		return false
	if context.spawn_parent == null or not is_instance_valid(context.spawn_parent):
		return false
	if context.caster.has_node("Health") and (context.caster.get_node("Health") as Health).is_dead():
		return false
	return true


static func _kind_for(index: int) -> StringName:
	return Health.KIND_HIT if index == 0 else Health.KIND_ECHO


## `condition` is the effect's optional condition block (see EffectCondition). A caster condition (cast_within,
## zone_active) is checked once here and a false one skips the effect. A target condition travels to the hit
## path in a copy of the params (only made when there is one, so unconditioned effects run exactly as before).
static func execute(template_id: String, params: Dictionary, context: EffectContext, condition: Dictionary = {}) -> void:
	if not condition.is_empty():
		if not EffectCondition.caster_ok(condition, context):
			return
		if EffectCondition.is_target_condition(condition):
			params = params.duplicate()
			params[EffectCondition.PARAM_KEY] = condition
	match template_id:
		"cone":
			_execute_cone(params, context)
		"aoe":
			_execute_aoe(params, context)
		"projectile":
			_execute_projectile(params, context)
		"dash":
			_execute_dash(params, context)
		"heal":
			_execute_heal(params, context)
		"apply_status":
			_execute_apply_status(params, context)
		"buff":
			_execute_buff(params, context)
		"zone":
			_execute_zone(params, context)
		"pass_through":
			_execute_pass_through(params, context)
		"reduce_cooldown":
			_execute_reduce_cooldown(params, context)
		"detonate_status":
			_execute_detonate_status(params, context)
		_:
			push_error("EffectTemplates: unknown template '%s'" % template_id)


static func _execute_cone(params: Dictionary, context: EffectContext) -> void:
	_run_hits(params, context, func(index: int) -> void: _cone_hit(params, context, index))


static func _cone_hit(params: Dictionary, context: EffectContext, index: int) -> void:
	var space_state := context.world().direct_space_state
	var forward: Vector3 = -context.caster.global_transform.basis.z
	var hits := MeleeQuery.find_hurtboxes_in_cone(
		space_state,
		context.caster.global_position,
		forward,
		params["range"],
		params["half_angle_degrees"],
		context.caster_team,
		CollisionLayers.HURTBOX
	)
	hits = EffectCondition.filter_hits(params, hits)
	context.last_hits = hits
	if bool(params.get("vfx", true)):
		_play_cone_vfx(params, context, forward)
	var knockback_strength: float = params.get("knockback_strength", 0.0)
	for hurtbox: Hurtbox in hits:
		hurtbox.receive_damage(params["damage"], params["damage_type"], knockback_from(context.caster.global_position, hurtbox.global_position, knockback_strength), context.caster, _kind_for(index), context.origin)


## Ground wedge through the shared EffectPool, sized by VfxSizing (the same
## numbers as the hit query). Pass "vfx": false to skip (the player's basic
## attacks draw their own telegraphed wedge).
static func _play_cone_vfx(params: Dictionary, context: EffectContext, forward: Vector3) -> void:
	var pool := EffectPool.for_world(context.spawn_parent)
	if pool == null or not is_instance_valid(context.caster):
		return
	var color: Color = ElementVisuals.visual_for_team(String(params.get("damage_type", "physical")), context.caster_team)["color"]
	var yaw: float = atan2(-forward.x, -forward.z)
	TemplateVfx.cone_sweep(pool, context.caster.global_position, yaw, VfxSizing.cone_reach(float(params["range"])),
			float(params["half_angle_degrees"]), color, context.caster_team == "enemy")


## Optional code-only param "center" (Vector3) moves the disc off the caster, for
## targeted heavies; cards leave it out and the disc is centred on the caster.
static func _execute_aoe(params: Dictionary, context: EffectContext) -> void:
	var locked: Dictionary = params
	if params.get("anchor", "") == ANCHOR_CASTER and not params.has("center") and context.caster.is_inside_tree():
		# Anchored: the disc stays where the caster stands NOW, even if it blinks away before a delayed hit lands.
		locked = params.duplicate()
		locked["center"] = context.caster.global_position
	elif params.has("max_range") and not params.has("center") and context.caster.is_inside_tree():
		# Placed: the disc lands at the aim point clamped to max_range, locked at cast.
		locked = params.duplicate()
		locked["center"] = context.placement(float(params["max_range"]))["point"]
	var delay: float = float(params.get("delay", 0.0))
	if delay > 0.0 and context.spawn_parent != null and context.spawn_parent.is_inside_tree():
		_telegraphed_aoe(locked, context, delay)
		return
	_run_hits(locked, context, func(index: int) -> void: _aoe_hit(locked, context, index))


## The disc is locked now; the shared ground telegraph (the targeted_aoe heavy's) grows over `delay`, then the
## hits run. The tween lives on the world node, so it survives the caster being freed (and the callback then
## sees an inactive caster and only clears the telegraph).
static func _telegraphed_aoe(locked: Dictionary, context: EffectContext, delay: float) -> void:
	var center: Vector3 = locked.get("center", context.caster.global_position)
	var pool := EffectPool.for_world(context.spawn_parent)
	var parts: Array[PooledEffect] = []
	var generations: Array[int] = []
	if pool != null:
		var look := ElementVisuals.visual_for_team(String(locked.get("damage_type", "physical")), context.caster_team)
		parts = TemplateVfx.aoe_telegraph(pool, center, VfxSizing.aoe_reach(float(locked["radius"])), look["color"])
		for part: PooledEffect in parts:
			generations.append(part.generation)
	var tween := context.spawn_parent.create_tween()
	if pool != null:
		tween.tween_method(func(fraction: float) -> void: _drive_telegraph(pool, parts, generations, fraction), 0.0, 1.0, delay)
	else:
		tween.tween_interval(delay)
	tween.tween_callback(func() -> void:
		_stop_telegraph(pool, parts, generations)
		if _caster_active(context):
			_run_hits(locked, context, func(index: int) -> void: _aoe_hit(locked, context, index)))


static func _drive_telegraph(pool: EffectPool, parts: Array[PooledEffect], generations: Array[int], fraction: float) -> void:
	if not is_instance_valid(pool):
		return
	for i in range(parts.size()):
		if pool.is_running(parts[i], generations[i]):
			parts[i].set_progress(fraction)


static func _stop_telegraph(pool: EffectPool, parts: Array[PooledEffect], generations: Array[int]) -> void:
	if not is_instance_valid(pool):
		return
	for i in range(parts.size()):
		pool.stop(parts[i], generations[i])


static func _aoe_hit(params: Dictionary, context: EffectContext, index: int) -> void:
	var space_state := context.world().direct_space_state
	var center: Vector3 = params.get("center", context.caster.global_position)
	var hits := MeleeQuery.find_hurtboxes_in_sphere(
		space_state,
		center,
		params["radius"],
		context.caster_team,
		CollisionLayers.HURTBOX
	)
	hits = EffectCondition.filter_hits(params, hits)
	context.last_hits = hits
	if bool(params.get("vfx", true)):
		_play_aoe_vfx(params, context, center)
	var knockback_strength: float = params.get("knockback_strength", 0.0)
	for hurtbox: Hurtbox in hits:
		hurtbox.receive_damage(params["damage"], params["damage_type"], knockback_from(center, hurtbox.global_position, knockback_strength), context.caster, _kind_for(index), context.origin)


## Ground disc through the shared EffectPool, sized exactly to the hit radius.
## No-op when there is no pool (caster/spawn_parent not in a tree).
static func _play_aoe_vfx(params: Dictionary, context: EffectContext, center: Variant = null) -> void:
	var pool := EffectPool.for_world(context.spawn_parent)
	if pool == null or not is_instance_valid(context.caster):
		return
	var look := ElementVisuals.visual_for_team(String(params.get("damage_type", "physical")), context.caster_team)
	# The disc and ring are the hit area (VfxSizing); the element "scale" only
	# resizes the cosmetic flash and burst inside TemplateVfx.aoe.
	TemplateVfx.aoe(pool, center if typeof(center) == TYPE_VECTOR3 else context.caster.global_position, VfxSizing.aoe_reach(float(params["radius"])), look)


## Horizontal-only impulse pointing from `origin` toward `target_pos`, scaled
## by `strength`. Zero strength (the common case - most cards have none)
## is a real Vector3.ZERO, not a tiny near-zero vector.
static func knockback_from(origin: Vector3, target_pos: Vector3, strength: float) -> Vector3:
	if strength <= 0.0:
		return Vector3.ZERO
	var away := target_pos - origin
	away.y = 0.0
	if away.length_squared() < 0.0001:
		return Vector3.ZERO
	return away.normalized() * strength


static func _execute_projectile(params: Dictionary, context: EffectContext) -> void:
	_run_hits(params, context, func(index: int) -> void: _projectile_shot(params, context, index))


## A projectile `look` with its colour as a Color: card data writes it as a hex string ("#b6ff4a"), the Wizard's auto bolt
## passes a Color. Optional `ball_scale` resizes the drawn ball only (never the hit radius); `scale` sizes trail and impact.
static func resolved_look(look: Dictionary) -> Dictionary:
	var out: Dictionary = look.duplicate()
	if typeof(out.get("color")) == TYPE_STRING:
		out["color"] = Color.html(String(out["color"]))
	if not out.has("scale"):
		out["scale"] = 1.0
	return out


## Problems with a projectile `look` written in card data: {color: hex, scale?: 0.1..5, ball_scale?: 0.1..5}.
static func validate_look(look: Variant) -> Array[String]:
	var errors: Array[String] = []
	if typeof(look) != TYPE_DICTIONARY:
		errors.append("'look' must be an object ({color, scale, ball_scale})")
		return errors
	var dict: Dictionary = look
	if typeof(dict.get("color")) != TYPE_STRING or not String(dict["color"]).is_valid_html_color():
		errors.append("'look.color' must be a hex color like #b6ff4a")
	for key: String in ["scale", "ball_scale"]:
		if dict.has(key) and not _number_in(dict[key], 0.1, 5.0, true):
			errors.append("'look.%s' must be a number from 0.1 to 5" % key)
	for key: Variant in dict.keys():
		if not ["color", "scale", "ball_scale"].has(String(key)):
			errors.append("'look.%s' is not a known key" % String(key))
	return errors


static func _projectile_shot(params: Dictionary, context: EffectContext, index: int) -> void:
	var scene: PackedScene = load(PROJECTILE_SCENE_PATH)
	var instance: Projectile = scene.instantiate()
	context.spawn_parent.add_child(instance)
	var forward: Vector3 = -context.caster.global_transform.basis.z
	if params.has("direction"):
		forward = (params["direction"] as Vector3).normalized()  # code-only: the Wizard's light flies to the reticle, not where the body faces
	if params.has("yaw_degrees"):
		forward = forward.rotated(Vector3.UP, deg_to_rad(float(params["yaw_degrees"])))  # a fan of shots (boss volley)
	var origin: Vector3 = context.caster.global_position + forward * PROJECTILE_MUZZLE_OFFSET
	instance.set_hit_radius(params["hit_radius"])
	if params.has("look") and not (params["look"] as Dictionary).is_empty():
		instance.set_look(resolved_look(params["look"] as Dictionary))
	else:
		instance.set_look(ElementVisuals.visual_for_team(String(params["damage_type"]), context.caster_team))
	instance.knockback_strength = params.get("knockback_strength", 0.0)
	if params.has(EffectCondition.PARAM_KEY):
		instance.condition = params[EffectCondition.PARAM_KEY]
	instance.set_source(context.caster, _kind_for(index))
	instance.origin = context.origin
	if params.has("status_id"):
		instance.status_id = String(params["status_id"])
		instance.status_duration = float(params["status_duration"])
	# Player shots only: an enemy shot's lane would look like a telegraph it is not.
	if context.caster_team == "player" and bool(params.get("lane", true)):
		TemplateVfx.projectile_lane(_vfx_pool(context), origin, forward, float(params["max_range"]), float(params["hit_radius"]),
				ElementVisuals.visual_for_damage_type(String(params["damage_type"])))
	instance.launch(origin, forward, params["damage"], params["damage_type"], params["speed"], params["max_range"], context.caster_team)
	# Async flight: this effect's damage lands later, so it never populates last_hits.
	context.last_hits = []


## The effect pool, or null when the caster is not in the tree (orphan-node unit
## tests) so visuals are skipped instead of erroring.
static func _vfx_pool(context: EffectContext) -> EffectPool:
	if context.caster == null or not is_instance_valid(context.caster) or not context.caster.is_inside_tree():
		return null
	return EffectPool.for_world(context.spawn_parent)


static func _caster_pos(context: EffectContext) -> Vector3:
	return context.caster.global_position if context.caster.is_inside_tree() else Vector3.ZERO


static func _execute_dash(params: Dictionary, context: EffectContext) -> void:
	if not context.caster.has_method("start_forced_move"):
		return
	var forward: Vector3 = -context.caster.global_transform.basis.z
	if String(params.get("direction_mode", DIRECTION_FORWARD)) == DIRECTION_AWAY:
		forward = -forward
	var speed: float = params["speed"]
	var distance: float = params["distance"]
	var duration: float = distance / speed if speed > 0.0 else 0.0
	var look := ElementVisuals.visual_for_damage_type(String(params.get("damage_type", "physical")))
	var path_hit: Dictionary = {}
	if params.has("damage") or params.has("status_id"):
		path_hit = {"damage": float(params.get("damage", 0.0)), "damage_type": String(params.get("damage_type", "physical")),
				"hit_radius": float(params["hit_radius"]), "knockback_strength": float(params.get("knockback_strength", 0.0)), "origin": context.origin}
		if params.has("status_id"):
			path_hit["status_id"] = String(params["status_id"])
			path_hit["status_duration"] = float(params["status_duration"])
	TemplateVfx.dash_start(_vfx_pool(context), _caster_pos(context), look)
	TemplateVfx.dash_path(_vfx_pool(context), _caster_pos(context), forward, distance, look, float(path_hit["hit_radius"]) if not path_hit.is_empty() else -1.0)
	context.caster.start_forced_move(forward, speed, duration, params.get("invulnerable", false), look, path_hit, bool(params.get("pass_through", false)), context.origin)


static func _execute_heal(params: Dictionary, context: EffectContext) -> void:
	if not context.caster.has_node("Health"):
		return
	var health: Health = context.caster.get_node("Health")
	var was_hurt: bool = health.get_current_health() < health.get_max_health()
	health.heal(params["amount"])
	if was_hurt and not health.is_dead():
		TemplateVfx.heal(_vfx_pool(context), _caster_pos(context))


static func _execute_apply_status(params: Dictionary, context: EffectContext) -> void:
	_run_hits(params, context, func(_index: int) -> void: _apply_status_once(params, context))


static func _apply_status_once(params: Dictionary, context: EffectContext) -> void:
	var status_id: String = params["status_id"]
	var duration: float = params["duration"]
	var status_def := StatusDatabase.get_status(status_id)
	if status_def.is_empty():
		push_error("EffectTemplates: unknown status_id '%s'" % status_id)
		return
	var targets: Array[Hurtbox] = context.last_hits
	if params.get("target", "last_hits") == "self" and context.caster.has_node("Hurtbox"):
		targets = [context.caster.get_node("Hurtbox") as Hurtbox]
	targets = EffectCondition.filter_hits(params, targets)
	var chance: float = float(params.get("chance", 1.0))
	if chance > 0.0 and chance < 1.0 and context.rng == null:
		push_error("EffectTemplates: apply_status '%s' has chance %s but the context has no RNG; not applied" % [status_id, str(chance)])
		return
	for hurtbox: Hurtbox in targets:
		if not is_instance_valid(hurtbox) or hurtbox.status_manager == null:
			continue
		if hurtbox.health != null and hurtbox.health.is_dead():
			continue
		# roll() draws nothing at chance 0 or 1, so chance-less cards leave seeded sequences untouched.
		if AttackStatuses.roll(context.rng, chance):
			hurtbox.status_manager.apply_status(status_id, status_def, duration, context.caster, context.origin)


## BD3a: detonates `status_id` on every living target of the effect (the hits of the effects before it, after a condition filter).
## The damage is credited to the caster with the card's origin, so card bonuses and relics see it as a card hit.
static func _execute_detonate_status(params: Dictionary, context: EffectContext) -> void:
	var status_id: String = String(params["status_id"])
	var multiplier: float = float(params["multiplier"])
	for hurtbox: Hurtbox in EffectCondition.filter_hits(params, context.last_hits):
		if not is_instance_valid(hurtbox) or hurtbox.status_manager == null:
			continue
		hurtbox.status_manager.detonate_status(status_id, multiplier, context.caster, context.origin)


## Counter for unique buff modifier ids (not the clock, so seeded sim runs repeat).
static var _buff_serial: int = 0


static func _execute_buff(params: Dictionary, context: EffectContext) -> void:
	if not ("stat_modifiers" in context.caster):
		return
	var stat_modifiers: StatModifiers = context.caster.stat_modifiers
	var stat: String = params["stat"]
	var modifier_type: String = params["modifier_type"]
	var value: float = params["value"]
	var duration: float = params["duration"]
	TemplateVfx.buff(_vfx_pool(context), _caster_pos(context))
	var cue: Dictionary = VfxConfig.buff_cue(stat)
	if not cue.is_empty() and context.caster is Node3D:
		TemplateVfx.buff_aura(_vfx_pool(context), context.caster as Node3D, cue, duration)
	_buff_serial += 1
	var modifier_id := "buff_%d" % _buff_serial
	if params.has("consume_on_cast"):
		# Primed: StatModifiers ages it (the card controller advances it) and uses it up by matching casts.
		stat_modifiers.add_primed_modifier(stat, modifier_id, modifier_type, value, String(params["consume_on_cast"]), int(params.get("charges", 1)), duration)
		return
	stat_modifiers.add_modifier(stat, modifier_id, modifier_type, value)
	if context.caster.is_inside_tree():
		var tree := context.caster.get_tree()
		tree.create_timer(duration, false).timeout.connect(func() -> void: stat_modifiers.remove_modifier(stat, modifier_id))


## Places a zone at the aim point clamped to max_range (straight ahead when there is no aim point).
static func _execute_zone(params: Dictionary, context: EffectContext) -> void:
	if context.caster == null or not is_instance_valid(context.caster) or not context.caster.is_inside_tree():
		return
	var manager := ZoneManager.for_world(context.spawn_parent)
	if manager == null:
		return
	var placed: Dictionary = context.placement(float(params["max_range"]))
	var origin: Vector3 = placed["origin"]
	var point: Vector3 = placed["point"]
	var cast_dir := Vector3(point.x - origin.x, 0.0, point.z - origin.z)
	if cast_dir.length_squared() < 0.0001:
		cast_dir = -context.caster.global_transform.basis.z
	manager.spawn(params, point, cast_dir.normalized(), context)
	# Zones tick on their own; nothing was hit at cast time as far as later effects are concerned.
	context.last_hits = []


## Lets the caster walk through enemies for `duration` (see Player.grant_pass_through).
static func _execute_pass_through(params: Dictionary, context: EffectContext) -> void:
	if not context.caster.has_method("grant_pass_through"):
		return
	context.caster.grant_pass_through(float(params["duration"]))


## Takes `seconds` off the running cooldown of the caster's `slot_type` slot. A slot that is ready, or a caster with no card slots, is left alone.
static func _execute_reduce_cooldown(params: Dictionary, context: EffectContext) -> void:
	if params.has("attack_id"):
		if context.caster.has_method("reduce_attack_cooldown"):
			context.caster.reduce_attack_cooldown(StringName(String(params["attack_id"])), float(params["seconds"]))
		return
	var controller: Variant = context.caster.get(&"card_slots")
	if not (controller is CardSlotController):
		return
	var slot: CardSlot = (controller as CardSlotController).get_slot(String(params["slot_type"]))
	if slot != null:
		slot.cooldown_remaining = maxf(slot.cooldown_remaining - float(params["seconds"]), 0.0)
