class_name CardSummary
extends RefCounted
## Generic one-line description of a card, built from its effect templates and params (never from a card id),
## for the reward and rest screens: "12 fire damage (aoe), Burn 5 s. Cooldown 3.3 s". Pure.


## `slot_base_cooldown` < 0 skips the cooldown part. `text` (data/run.json ui.effect plus a `slot_names` map) words the
## buff part; without it the built-in defaults below apply.
static func effect_line(card: Dictionary, slot_base_cooldown: float = -1.0, text: Dictionary = {}) -> String:
	var parts: Array[String] = []
	for effect: Variant in (card.get("effects", []) as Array):
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var part: String = _effect_part(String((effect as Dictionary).get("template", "")), (effect as Dictionary).get("params", {}), text)
		if part != "":
			parts.append(part)
	var line: String = ", ".join(parts)
	if slot_base_cooldown >= 0.0:
		var cooldown: float = maxf(slot_base_cooldown + float(card.get("cooldown_modifier", 0.0)), 0.0)
		line += ("" if line == "" else ". ") + "Cooldown %s s" % _num(cooldown)
	return line


static func _effect_part(template: String, params: Dictionary, text: Dictionary = {}) -> String:
	var hits: int = int(params.get("hits", 1))
	var damage: String = ""
	if params.has("damage"):
		damage = "%s%s %s damage" % [_num(float(params["damage"])), (" x%d" % hits) if hits > 1 else "", String(params.get("damage_type", ""))]
	match template:
		"cone", "aoe", "projectile":
			return "%s (%s)" % [damage, template]
		"zone":
			var zone: String = "%s every %s s for %s s (zone)" % [damage, _num(float(params.get("tick_interval", 0.0))), _num(float(params.get("duration", 0.0)))]
			if params.has("status_id"):
				zone += ", may apply %s" % String(params["status_id"]).capitalize()
			return zone
		"heal":
			return "heal %s" % _num(float(params.get("amount", 0.0)))
		"apply_status":
			return "%s %s s" % [String(params.get("status_id", "")).capitalize(), _num(float(params.get("duration", 0.0)))]
		"dash":
			return "dash %s" % _num(float(params.get("distance", 0.0)))
		"buff":
			return buff_text(params, text)
		"pass_through":
			return "pass through enemies %s s" % _num(float(params.get("duration", 0.0)))
	return template


## "Attack: Single cooldown -0.5 s for 6 s" from a buff's params. A stat "slot_cooldown.<slot_type>" names the slot
## from `text.slot_names`; any other stat is its id with underscores as spaces ("Move speed +0.2 for 4 s").
## An additive value is signed, a multiplicative one reads "x1.2". Never reads a card id.
static func buff_text(params: Dictionary, text: Dictionary = {}) -> String:
	var stat: String = String(params.get("stat", ""))
	var value: float = float(params.get("value", 0.0))
	var multiplicative: bool = String(params.get("modifier_type", "additive")) == "multiplicative"
	var amount: String = ("x" + _num(value)) if multiplicative else _signed(value)
	var duration: String = String(text.get("for", "for %s s")) % _num(float(params.get("duration", 0.0)))
	var head: String
	if stat.begins_with("slot_cooldown.") and not multiplicative:
		var slot_type: String = stat.get_slice(".", 1)
		var slot_name: String = String((text.get("slot_names", {}) as Dictionary).get(slot_type, slot_type.replace("_", " ").capitalize()))
		head = String(text.get("slot_cooldown", "%s cooldown %s s")) % [slot_name, amount]
	else:
		head = "%s %s" % [stat.replace(".", " ").replace("_", " ").capitalize(), amount]
	return "%s %s" % [head, duration]


static func _signed(value: float) -> String:
	return ("+" if value > 0.0 else "") + _num(value)


static func _num(value: float) -> String:
	return str(snappedf(value, 0.1))


## Status ids a card can apply (apply_status and zone effects), for the `requires.status_sources` hook.
static func status_ids(card: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for effect: Variant in (card.get("effects", []) as Array):
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var params: Variant = (effect as Dictionary).get("params", {})
		if typeof(params) == TYPE_DICTIONARY and (params as Dictionary).has("status_id"):
			out.append(String((params as Dictionary)["status_id"]))
	return out
