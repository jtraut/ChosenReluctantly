class_name EffectScale
extends RefCounted
## The optional `scale` block of a card or relic effect (sibling of `template`, `params` and `condition`, BD3b, BUILD_DEPTH 3.2). It adds
## `per` x (a live count, at most `max`) to one numeric param of the effect when the effect runs, so a payoff grows with the board and a
## base number in `params` stays a plain number every other reader (CardDamageRule, CardSummary, CastPreviewShapes) already understands.
## That is also why scaled damage never counts for the CardDamageRule: only the base does.
##
##   {"by": "self_stacks", "status_id": "charge", "per": 1.5, "max": 10, "consume": true, "param": "damage"}
##       count = the caster's stacks of that status on itself. `consume` (default false) removes the status once, when the effect runs.
##   {"by": "deck_count", "tag": "Projectile", "per": 0.5, "max": 6}
##       count = the cards in the run deck with that tag (copies count).
##
##   {"by": "event_amount", "per": 0.1, "param": "damage"}
##       RELIC TRIGGERS ONLY (BD3b-C2, an event that carries an amount: player_damaged, hit_landed). The param becomes per x the event's amount (capped
##       by `max` when given), but never less than the base in `params`, which is the floor (so the base is a small placeholder, like a zone's `length`
##       at event_path). "Deals 10% of the hit back" is per 0.1 with a base of 0.1.
##
## `max` (optional on both forms) caps the COUNT, not the bonus: per 0.5 and max 6 adds at most +3. `param` is optional: it defaults to the
## template's damage (`damage`, or `amount` for a heal) and may only name a non-geometric number (damage, amount), because the cast preview
## draws shapes once per card. The effect must already carry that param (its base).

const SELF_STACKS := "self_stacks"
const DECK_COUNT := "deck_count"
const EVENT_AMOUNT := "event_amount"
const BY: Array[String] = [SELF_STACKS, DECK_COUNT, EVENT_AMOUNT]
## Templates that may scale, and the params each may name (the first is the default).
const PARAMS_BY_TEMPLATE: Dictionary = {
	"projectile": ["damage"], "cone": ["damage"], "aoe": ["damage"], "zone": ["damage"], "dash": ["damage"], "heal": ["amount"],
}
const MAX_PER := 100000.0
const MAX_COUNT := 999


## The param a scale block raises for an effect of `template_id` ("" when the template cannot scale).
static func param_name(scale: Dictionary, template_id: String) -> String:
	var allowed: Array = PARAMS_BY_TEMPLATE.get(template_id, [])
	if allowed.is_empty():
		return ""
	return String(scale.get("param", allowed[0]))


## The live count the block reads, before `max`: the caster's stacks or the deck's tagged cards.
static func raw_count(scale: Dictionary, caster: Node, deck_card_ids: Array) -> int:
	match String(scale.get("by", "")):
		SELF_STACKS:
			return CasterStats.self_stacks(caster, String(scale.get("status_id", "")))
		DECK_COUNT:
			return CasterStats.deck_tag_count(deck_card_ids, String(scale.get("tag", "")))
	return 0


## The counted amount after `max`.
static func capped_count(scale: Dictionary, raw: int) -> int:
	return mini(raw, int(scale["max"])) if scale.has("max") else raw


## What the block adds right now: per x capped count.
static func bonus(scale: Dictionary, caster: Node, deck_card_ids: Array) -> float:
	return float(scale.get("per", 0.0)) * float(capped_count(scale, raw_count(scale, caster, deck_card_ids)))


## `params` with the scaled param raised by the bonus (a copy; the card data is never changed). Run once per effect execution. With
## `consume`, the status is removed from the caster after its stacks were read (reason "consumed"), even the stacks above `max`.
static func apply(scale: Dictionary, template_id: String, params: Dictionary, context: EffectContext) -> Dictionary:
	var param: String = param_name(scale, template_id)
	if param.is_empty() or not params.has(param):
		push_error("EffectScale: effect '%s' cannot scale param '%s'" % [template_id, param])
		return params
	var scaled: Dictionary = params.duplicate()
	if String(scale.get("by", "")) == EVENT_AMOUNT:
		var amount: float = minf(context.event_amount, float(scale["max"])) if scale.has("max") else context.event_amount
		scaled[param] = maxf(float(params[param]), float(scale.get("per", 0.0)) * amount)
		return scaled
	scaled[param] = float(params[param]) + bonus(scale, context.caster, context.deck_card_ids)
	if bool(scale.get("consume", false)) and String(scale.get("by", "")) == SELF_STACKS:
		_consume(context.caster, String(scale["status_id"]))
	return scaled


static func _consume(caster: Node, status_id: String) -> void:
	if caster == null or not is_instance_valid(caster) or not caster.has_node("Hurtbox"):
		return
	var hurtbox := caster.get_node("Hurtbox") as Hurtbox
	if hurtbox != null and hurtbox.status_manager != null:
		hurtbox.status_manager.consume_status(status_id)


## The live numbers of every scaled effect of `card` for the cast preview and the HUD: [{param, base, bonus, value, count}]. `caster` and
## `deck_card_ids` are the live player and run deck. Nothing is consumed.
static func preview_values(card: Dictionary, caster: Node, deck_card_ids: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for effect: Variant in (card.get("effects", []) as Array):
		if typeof(effect) != TYPE_DICTIONARY or typeof((effect as Dictionary).get("scale")) != TYPE_DICTIONARY:
			continue
		var scale: Dictionary = (effect as Dictionary)["scale"]
		var param: String = param_name(scale, String((effect as Dictionary).get("template", "")))
		var params: Dictionary = (effect as Dictionary).get("params", {})
		if param.is_empty() or not params.has(param):
			continue
		var count: int = capped_count(scale, raw_count(scale, caster, deck_card_ids))
		var added: float = float(scale.get("per", 0.0)) * float(count)
		out.append({"param": param, "base": float(params[param]), "bonus": added, "value": float(params[param]) + added, "count": count})
	return out


## The display words of a scale block ("+1.5 per Charge (max +15), uses up your Charge"), from data/run.json ui.effect.scale.
static func text(scale: Dictionary, words: Dictionary, status_name: String) -> String:
	var per: String = _num(float(scale.get("per", 0.0)))
	var line: String
	if String(scale.get("by", "")) == EVENT_AMOUNT:
		return ""  # relic triggers only: a relic states its rule in its own rule_text
	if String(scale.get("by", "")) == SELF_STACKS:
		line = String(words["self_stacks"]) % [per, status_name]
	else:
		line = String(words["deck_count"]) % [per, String(scale.get("tag", ""))]
	if scale.has("max"):
		line += " " + String(words["max"]) % _num(float(scale["max"]) * float(scale.get("per", 0.0)))
	if bool(scale.get("consume", false)):
		line += ", " + String(words["consume"]) % status_name
	return line


static func _num(value: float) -> String:
	if absf(value - roundf(value)) < 0.0001:
		return str(int(roundf(value)))
	return String.num(value, 2).trim_suffix("0")


## Problems with an effect's `scale` block for an effect of `template_id` carrying `params` (empty = fine).
static func validate(scale: Variant, template_id: String, params: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if typeof(scale) != TYPE_DICTIONARY:
		errors.append("'scale' must be an object")
		return errors
	var dict: Dictionary = scale
	var by: String = String(dict["by"]) if typeof(dict.get("by")) == TYPE_STRING else ""
	if not BY.has(by):
		errors.append("scale 'by' must be one of %s" % str(BY))
		return errors
	var allowed: Array[String] = ["by", "per", "max", "param"]
	var allowed_params: Array = PARAMS_BY_TEMPLATE.get(template_id, [])
	if allowed_params.is_empty():
		errors.append("the %s template cannot carry a scale (only %s)" % [template_id, str(PARAMS_BY_TEMPLATE.keys())])
	else:
		var param: String = String(dict["param"]) if typeof(dict.get("param")) == TYPE_STRING else String(allowed_params[0])
		if dict.has("param") and (typeof(dict["param"]) != TYPE_STRING or not allowed_params.has(param)):
			errors.append("scale 'param' must be one of %s for a %s effect" % [str(allowed_params), template_id])
		elif not params.has(param):
			errors.append("a scale on '%s' needs the effect to have a base '%s' in its params" % [param, param])
	if not EffectTemplates.number_in(dict.get("per"), 0.0, MAX_PER, false):
		errors.append("scale 'per' must be a number above 0")
	if dict.has("max"):
		var cap: Variant = dict["max"]
		if not EffectTemplates.number_in(cap, 0.0, float(MAX_COUNT), false) or float(cap) != floorf(float(cap)):
			errors.append("scale 'max' must be a whole number from 1 to %d" % MAX_COUNT)
	match by:
		SELF_STACKS:
			allowed.append_array(["status_id", "consume"])
			if typeof(dict.get("status_id")) != TYPE_STRING or not StatusDatabase.has_status(String(dict["status_id"])):
				errors.append("scale by self_stacks needs a known 'status_id'")
			if dict.has("consume") and typeof(dict["consume"]) != TYPE_BOOL:
				errors.append("scale 'consume' must be true or false")
		DECK_COUNT:
			allowed.append("tag")
			if typeof(dict.get("tag")) != TYPE_STRING or not CardTags.is_known_tag(String(dict["tag"])):
				errors.append("scale by deck_count 'tag' must be a derived tag or a keyword (for example Projectile, Burn, Primer)")
	for key: Variant in dict.keys():
		if not allowed.has(String(key)):
			errors.append("'%s' is not a known scale key for by %s" % [str(key), by])
	return errors
