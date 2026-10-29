class_name CardSummary
extends RefCounted
## Generic one-line description of a card, built from its effect templates and params (never from a card id),
## for the reward and rest screens: "12 fire damage (area), Burn 2 damage/s for 5 s. Cooldown 3.3 s". Pure.


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
		line += ("" if line == "" else ". ") + String(_word(text, "cooldown")) % _num(cooldown)
	return line


## Words and units for the effect line. The shipped wording is data/run.json `ui.effect`; these defaults only back a
## test or a mod that gives no text. `statuses` (status id -> its statuses.json entry) lets a status be described by
## its numbers (Leech 40%, Burn 2 damage/s); `shapes` names a template for the player; `dash_modes` names a direction.
const DEFAULT_TEXT: Dictionary = {
	"damage": "%s %s damage",
	"hits": "%s %s damage x %d hits",
	"shape": "%s (%s)",
	"shapes": {"cone": "cone", "aoe": "area", "projectile": "shot", "zone": "zone"},
	"zone": "%s every %s s for %s s (%s)",
	"zone_status": "%d%% chance of %s for %s s",
	"heal": "Heal %s HP",
	"dash": "Dash %s m",
	"dash_modes": {"away_from_aim": " away from your aim"},
	"dash_damage": "%s %s damage",
	"pass_through": "Walk through enemies for %s s",
	"status_plain": "%s for %s s",
	"status_lifesteal": "%s %d%% for %s s",
	"status_damage_over_time": "%s %s damage/s for %s s",
	"status_heal_over_time": "%s %s HP/s for %s s",
	"cooldown": "Cooldown %s s",
	"slot_cooldown": "%s cooldown %s s",
	"for": "for %s s",
}


static func _word(text: Dictionary, key: String) -> Variant:
	return text.get(key, DEFAULT_TEXT[key])


static func _effect_part(template: String, params: Dictionary, text: Dictionary = {}) -> String:
	var hits: int = int(params.get("hits", 1))
	var damage: String = ""
	if params.has("damage"):
		if hits > 1:
			damage = String(_word(text, "hits")) % [_num(float(params["damage"])), String(params.get("damage_type", "")), hits]
		else:
			damage = String(_word(text, "damage")) % [_num(float(params["damage"])), String(params.get("damage_type", ""))]
	match template:
		"cone", "aoe", "projectile":
			return String(_word(text, "shape")) % [damage, _shape_name(template, text)]
		"zone":
			var zone: String = String(_word(text, "zone")) % [damage, _num(float(params.get("tick_interval", 0.0))), _num(float(params.get("duration", 0.0))), _shape_name(template, text)]
			if params.has("status_id"):
				zone += ", " + String(_word(text, "zone_status")) % [roundi(float(params.get("status_chance", 1.0)) * 100.0), _status_name(String(params["status_id"]), text), _num(float(params.get("status_duration", 0.0)))]
			return zone
		"heal":
			return String(_word(text, "heal")) % _num(float(params.get("amount", 0.0)))
		"apply_status":
			return status_text(String(params.get("status_id", "")), float(params.get("duration", 0.0)), text)
		"dash":
			var dash: String = String(_word(text, "dash")) % _num(float(params.get("distance", 0.0)))
			dash += String((_word(text, "dash_modes") as Dictionary).get(String(params.get("direction_mode", "")), ""))
			if params.has("damage"):
				dash += ", " + String(_word(text, "dash_damage")) % [_num(float(params["damage"])), String(params.get("damage_type", ""))]
			return dash
		"buff":
			return buff_text(params, text)
		"pass_through":
			return String(_word(text, "pass_through")) % _num(float(params.get("duration", 0.0)))
	return template.replace("_", " ").capitalize()


static func _shape_name(template: String, text: Dictionary) -> String:
	return String((_word(text, "shapes") as Dictionary).get(template, template.replace("_", " ")))


static func _status_name(status_id: String, text: Dictionary) -> String:
	var entry: Dictionary = (text.get("statuses", {}) as Dictionary).get(status_id, {})
	return String(entry.get("display_name", status_id.replace("_", " ").capitalize()))


## "Leech 40% for 7 s", "Burn 2 damage/s for 5 s", "Regeneration 2 HP/s for 7 s": a status by its numbers, read from
## its entry in `text.statuses` by effect type (never by id). An unknown status reads "Name for 5 s".
static func status_text(status_id: String, duration: float, text: Dictionary = {}) -> String:
	var entry: Dictionary = (text.get("statuses", {}) as Dictionary).get(status_id, {})
	var status_name: String = _status_name(status_id, text)
	var seconds: String = _num(duration)
	var interval: float = float(entry.get("tick_interval", 1.0))
	match String(entry.get("effect_type", "")):
		"lifesteal":
			return String(_word(text, "status_lifesteal")) % [status_name, roundi(float(entry.get("fraction", 0.0)) * 100.0), seconds]
		"damage_over_time":
			return String(_word(text, "status_damage_over_time")) % [status_name, _num(float(entry.get("damage_per_tick", 0.0)) / maxf(interval, 0.01)), seconds]
		"heal_over_time":
			return String(_word(text, "status_heal_over_time")) % [status_name, _num(float(entry.get("heal_per_tick", 0.0)) / maxf(interval, 0.01)), seconds]
	return String(_word(text, "status_plain")) % [status_name, seconds]


## "Attack: Single cooldown -0.5 s for 6 s" from a buff's params. A stat "slot_cooldown.<slot_type>" names the slot
## from `text.slot_names`; any other stat is its id with underscores as spaces ("Move speed +0.2 for 4 s").
## An additive value is signed, a multiplicative one reads "x1.2". Never reads a card id.
static func buff_text(params: Dictionary, text: Dictionary = {}) -> String:
	var stat: String = String(params.get("stat", ""))
	var value: float = float(params.get("value", 0.0))
	var multiplicative: bool = String(params.get("modifier_type", "additive")) == "multiplicative"
	var amount: String = ("x" + _num(value)) if multiplicative else _signed(value)
	var duration: String = String(_word(text, "for")) % _num(float(params.get("duration", 0.0)))
	var head: String
	if stat.begins_with("slot_cooldown.") and not multiplicative:
		var slot_type: String = stat.get_slice(".", 1)
		var slot_name: String = String((text.get("slot_names", {}) as Dictionary).get(slot_type, slot_type.replace("_", " ").capitalize()))
		head = String(_word(text, "slot_cooldown")) % [slot_name, amount]
	else:
		head = "%s %s" % [stat.replace(".", " ").replace("_", " ").capitalize(), amount]
	return "%s %s" % [head, duration]


static func _signed(value: float) -> String:
	return ("+" if value > 0.0 else "") + _num(value)


## 6.0 reads "6", 0.5 reads "0.5" (one decimal at most).
static func _num(value: float) -> String:
	var snapped: float = snappedf(value, 0.1)
	return str(roundi(snapped)) if is_equal_approx(snapped, roundf(snapped)) else str(snapped)


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
