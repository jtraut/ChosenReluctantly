class_name EffectCondition
extends RefCounted
## The optional `condition` block of a card effect (sibling of `template` and `params`). When it is false the
## effect is skipped. Pure functions over an EffectContext, so tests need no scene.
##
## Types (BD1-A; the later BUILD_DEPTH 3.2 types are not built and are rejected by validate()):
##   target_has_status {status_id}          a target hit has the status. Per target, in the cone, aoe, projectile,
##                                          zone and apply_status paths. The hits that pass are what the effect
##                                          damages (and what later effects see in last_hits).
##   cast_within {slot_type | tag, seconds} the caster cast a matching card within the last N seconds (checked once
##                                          per cast; the current cast is not in the history yet).
##   zone_active {}                         one of the caster's Zones is alive (checked once per cast).

const TARGET_HAS_STATUS := "target_has_status"
const CAST_WITHIN := "cast_within"
const ZONE_ACTIVE := "zone_active"
const TYPES: Array[String] = [TARGET_HAS_STATUS, CAST_WITHIN, ZONE_ACTIVE]
## Templates that have a target hit path, so a target condition means something there.
const TARGET_TEMPLATES: Array[String] = ["cone", "aoe", "projectile", "zone", "apply_status", "detonate_status"]
## Internal params key under which execute() hands a target condition to the hit path (never written in data).
const PARAM_KEY := "_target_condition"


static func is_target_condition(condition: Dictionary) -> bool:
	return String(condition.get("type", "")) == TARGET_HAS_STATUS


## The cast-time check of a caster condition (cast_within, zone_active). A target condition is true here: it is
## checked per target in the hit path.
static func caster_ok(condition: Dictionary, context: EffectContext) -> bool:
	match String(condition.get("type", "")):
		CAST_WITHIN:
			if context.cast_history == null:
				return false
			return context.cast_history.cast_within(context.now, float(condition["seconds"]), String(condition.get("slot_type", "")), String(condition.get("tag", "")))
		ZONE_ACTIVE:
			if context.caster == null or not is_instance_valid(context.caster):
				return false
			var manager: ZoneManager = ZoneManager.find_in_world(context.spawn_parent)
			return manager != null and manager.live_count_for(context.caster.get_instance_id()) > 0
	return true


## The per-target check: does this hurtbox's owner have the status?
static func target_ok(condition: Dictionary, hurtbox: Hurtbox) -> bool:
	if hurtbox == null or not is_instance_valid(hurtbox) or hurtbox.status_manager == null:
		return false
	return hurtbox.status_manager.has_status(String(condition["status_id"]))


## Keeps only the hurtboxes that meet the condition stored under PARAM_KEY in `params` (all of them when absent).
static func filter_hits(params: Dictionary, hits: Array[Hurtbox]) -> Array[Hurtbox]:
	if not params.has(PARAM_KEY):
		return hits
	var condition: Dictionary = params[PARAM_KEY]
	var kept: Array[Hurtbox] = []
	for hurtbox: Hurtbox in hits:
		if target_ok(condition, hurtbox):
			kept.append(hurtbox)
	return kept


## Problems with an effect's `condition` for an effect of `template_id` (empty = fine).
static func validate(condition: Variant, template_id: String) -> Array[String]:
	var errors: Array[String] = []
	if typeof(condition) != TYPE_DICTIONARY:
		errors.append("'condition' must be an object")
		return errors
	var dict: Dictionary = condition
	var type: String = String(dict["type"]) if typeof(dict.get("type")) == TYPE_STRING else ""
	if not TYPES.has(type):
		errors.append("condition 'type' must be one of %s" % str(TYPES))
		return errors
	var allowed: Array[String] = ["type"]
	match type:
		TARGET_HAS_STATUS:
			allowed.append("status_id")
			if not TARGET_TEMPLATES.has(template_id):
				errors.append("a target_has_status condition needs a template that hits targets (%s), not %s" % [str(TARGET_TEMPLATES), template_id])
			if typeof(dict.get("status_id")) != TYPE_STRING or not StatusDatabase.has_status(String(dict["status_id"])):
				errors.append("target_has_status needs a known 'status_id'")
		CAST_WITHIN:
			allowed.append_array(["slot_type", "tag", "seconds"])
			var has_slot: bool = dict.has("slot_type")
			var has_tag: bool = dict.has("tag")
			if has_slot == has_tag:
				errors.append("cast_within needs exactly one of 'slot_type' or 'tag'")
			if has_slot and (typeof(dict["slot_type"]) != TYPE_STRING or not SlotTypeDatabase.has(String(dict["slot_type"]))):
				errors.append("cast_within 'slot_type' must be one of %s" % str(SlotTypeDatabase.known_ids()))
			if has_tag and (typeof(dict["tag"]) != TYPE_STRING or not CardTags.is_known_tag(String(dict["tag"]))):
				errors.append("cast_within 'tag' must be a derived tag or a keyword (for example Burn, Dash, Primer)")
			if not EffectTemplates.number_in(dict.get("seconds"), 0.0, CastHistory.MAX_SECONDS, false):
				errors.append("cast_within 'seconds' must be a number above 0 and at most %s" % str(CastHistory.MAX_SECONDS))
		ZONE_ACTIVE:
			pass
	for key: Variant in dict.keys():
		if not allowed.has(String(key)):
			errors.append("'%s' is not a known %s param" % [str(key), type])
	return errors
