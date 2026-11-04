class_name SlotSynergy
extends RefCounted
## What the HUD (and the plan-aware bot) need to know about a slot's current card (BD1): its chips (keywords first,
## then derived tags), its condition as display text, whether that condition is live right now, and its primed state.
## Pure functions over plain data, so tests and the headless sims need no scene. SlotSynergyView builds the `view`
## from a live Player.
##
## `view` (a Dictionary; every key optional, missing = empty/false):
##   now: float                  game time (CombatEvents clock)
##   history: CastHistory        the caster's recent casts
##   zone_count: int             how many Zones of the caster are alive
##   origin: Vector3, forward: Vector3 (flat), aim_point: Variant (Vector3 or null), arena: Rect2
##   enemies: Array[Dictionary]  [{pos: Vector3, statuses: Array}]
##
## Live rule: a card with a condition is live when ANY of its conditional effects has a live condition. cast_within
## and zone_active read the caster; target_has_status is live when any enemy inside that effect's preview area (the
## same shape the hold-to-preview draws, CastPreviewShapes) has the status. A card with no condition is never "live"
## (has_condition is false); the glow is for payoffs.

const PREVIEW_CONFIG: Dictionary = {}


## The effects of `card` that carry a condition, as {template, params, condition}.
static func conditional_effects(card: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var effects: Variant = card.get("effects", [])
	if typeof(effects) != TYPE_ARRAY:
		return result
	for effect: Variant in (effects as Array):
		if typeof(effect) == TYPE_DICTIONARY and typeof((effect as Dictionary).get("condition")) == TYPE_DICTIONARY and not ((effect as Dictionary)["condition"] as Dictionary).is_empty():
			result.append(effect)
	return result


## Chips for a card: authored keywords first, then derived tags (the UI shows the first few).
static func chips(card_id: String) -> Array[String]:
	var tags: Array[String] = CardDatabase.tags_for(card_id)
	var result: Array[String] = []
	for tag: String in tags:
		if KeywordDatabase.has(tag):
			result.append(tag)
	for tag: String in tags:
		if not KeywordDatabase.has(tag):
			result.append(tag)
	return result


## The strings CardSummary needs, from data/run.json ui.effect plus slot and status names.
static func default_text() -> Dictionary:
	var text: Dictionary = (RunConfig.ui().get("effect", {}) as Dictionary).duplicate()
	text["slot_names"] = DeckRules.slot_names_from_database()
	var statuses: Dictionary = {}
	for status_id: Variant in StatusDatabase.known_ids():
		statuses[String(status_id)] = StatusDatabase.get_status(String(status_id))
	text["statuses"] = statuses
	return text


## The condition text of a card ("If the target has Burn"). Several different conditions are joined with ", ".
static func condition_display(card: Dictionary, text: Dictionary) -> String:
	var seen: Array[String] = []
	for effect: Dictionary in conditional_effects(card):
		var shown: String = CardSummary.condition_text(effect["condition"], text)
		if shown != "" and not seen.has(shown):
			seen.append(shown)
	return ", ".join(seen)


## True when the card has a conditional effect and at least one of them is live in `view`.
static func is_live(card: Dictionary, view: Dictionary) -> bool:
	for effect: Dictionary in conditional_effects(card):
		if condition_live(effect, card, view):
			return true
	return false


## One conditional effect's condition, live in `view`? `card` supplies the fallback preview area for an effect that
## has no shape of its own (apply_status).
static func condition_live(effect: Dictionary, card: Dictionary, view: Dictionary) -> bool:
	var condition: Dictionary = effect["condition"]
	match String(condition.get("type", "")):
		EffectCondition.CAST_WITHIN:
			var history: Variant = view.get("history")
			if not (history is CastHistory):
				return false
			return (history as CastHistory).cast_within(float(view.get("now", 0.0)), float(condition.get("seconds", 0.0)), String(condition.get("slot_type", "")), String(condition.get("tag", "")))
		EffectCondition.ZONE_ACTIVE:
			return int(view.get("zone_count", 0)) > 0
		EffectCondition.TARGET_HAS_STATUS:
			var no_ring: Dictionary = {"self_ring_enabled": false}
			var parts: Array[Dictionary] = CastPreviewShapes.parts_for_card({"effects": [{"template": effect.get("template", ""), "params": effect.get("params", {})}]}, no_ring)
			if parts.is_empty():
				parts = CastPreviewShapes.parts_for_card({"effects": card.get("effects", [])}, no_ring)
			for enemy: Variant in (view.get("enemies", []) as Array):
				var statuses: Array = (enemy as Dictionary).get("statuses", [])
				if not statuses.has(String(condition.get("status_id", ""))):
					continue
				for part: Dictionary in parts:
					if part_contains(part, view, (enemy as Dictionary)["pos"]):
						return true
			return false
	return false


## True when any enemy in `view` stands inside the card's preview area (any aimed part). For the bot: "worth casting".
static func enemy_in_area(card: Dictionary, view: Dictionary) -> bool:
	var parts: Array[Dictionary] = CastPreviewShapes.parts_for_card(card, PREVIEW_CONFIG)
	for enemy: Variant in (view.get("enemies", []) as Array):
		for part: Dictionary in parts:
			if part_contains(part, view, (enemy as Dictionary)["pos"]):
				return true
	return false


## Is the ground point `point` inside the preview `part` (a CastPreviewShapes part) for a caster at view.origin facing
## view.forward? The same numbers the preview draws: cone reach and half angle, disc reach (centred on the caster, or on
## the clamped aim point when placed), lanes by start offset, length and half width.
static func part_contains(part: Dictionary, view: Dictionary, point: Vector3) -> bool:
	var origin: Vector3 = view.get("origin", Vector3.ZERO)
	var forward: Vector3 = view.get("forward", Vector3.FORWARD)
	forward = Vector3(forward.x, 0.0, forward.z)
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var lane_forward: Vector3 = forward
	if float(part.get("yaw_offset_degrees", 0.0)) != 0.0:
		lane_forward = forward.rotated(Vector3.UP, deg_to_rad(float(part["yaw_offset_degrees"])))
	var size: float = float(part.get("size", 0.0))
	var rel := Vector3(point.x - origin.x, 0.0, point.z - origin.z)
	match String(part.get("shape", "")):
		CastPreviewShapes.CONE:
			if rel.length() > size:
				return false
			if rel.length() < 0.0001:
				return true
			return rad_to_deg(forward.angle_to(rel)) <= float(part.get("half_angle_degrees", 0.0))
		CastPreviewShapes.AOE:
			var center := origin
			if bool(part.get("placed", false)):
				var placed: Dictionary = AoeTargeting.placement(origin, view.get("aim_point"), forward, float(part.get("range", 0.0)), view.get("arena", Rect2()))
				center = placed["point"]
			return Vector2(point.x - center.x, point.z - center.z).length() <= size
		CastPreviewShapes.SELF_RING:
			return rel.length() <= size
		CastPreviewShapes.PROJECTILE_LANE, CastPreviewShapes.DASH_PATH:
			var along: float = rel.dot(lane_forward) - float(part.get("start_offset", 0.0))
			return along >= 0.0 and along <= size and absf(rel.dot(lane_forward.cross(Vector3.UP))) <= float(part.get("half_width", 0.0))
		CastPreviewShapes.ZONE_LINE:
			var placed_line: Dictionary = AoeTargeting.placement(origin, view.get("aim_point"), forward, float(part.get("range", 0.0)), view.get("arena", Rect2()))
			var center_line: Vector3 = placed_line["point"]
			var cast_dir := Vector3(center_line.x - origin.x, 0.0, center_line.z - origin.z)
			cast_dir = cast_dir.normalized() if cast_dir.length_squared() > 0.0001 else forward
			var offset := Vector3(point.x - center_line.x, 0.0, point.z - center_line.z)
			return absf(offset.dot(cast_dir.cross(Vector3.UP))) <= size and absf(offset.dot(cast_dir)) <= float(part.get("half_width", 0.0))
	return false


## The primed buffs (StatModifiers.primed_state()) that the next cast of this slot's current card would use up.
static func primed_for(slot_type: String, card_id: String, primed_state: Array[Dictionary]) -> Array[Dictionary]:
	var tags: Array[String] = CardDatabase.tags_for(card_id)
	var matching: Array[Dictionary] = []
	for entry: Dictionary in primed_state:
		if StatModifiers.matches_cast(String(entry["stat"]), String(entry["consume_on"]), slot_type, tags):
			matching.append(entry)
	return matching


## Everything the HUD shows for one slot:
##   slot_type, card_id
##   chips        keywords first, then derived tags (all of them; the UI picks how many to draw)
##   keywords     the authored keywords only; keyword_rules maps each to its rule text (data/keywords.json)
##   has_condition, condition_text ("" without one), condition_live
##   primed, primed_time_left (seconds, -1 = no limit), primed_duration (the full window, for a bar), primed_charges
static func slot_info(slot_type: String, card_id: String, view: Dictionary, primed_state: Array[Dictionary], text: Dictionary) -> Dictionary:
	var card: Dictionary = CardDatabase.get_card(card_id)
	var keywords: Array[String] = CardTags.keywords_of(card)
	var rules: Dictionary = {}
	for keyword: String in keywords:
		rules[keyword] = KeywordDatabase.rule_text(keyword)
	var has_condition: bool = not conditional_effects(card).is_empty()
	var matching: Array[Dictionary] = primed_for(slot_type, card_id, primed_state)
	var time_left: float = -1.0
	var duration: float = -1.0
	var charges: int = 0
	for entry: Dictionary in matching:
		charges += int(entry["charges"])
		if float(entry["time_left"]) > time_left:
			time_left = float(entry["time_left"])
			duration = float(entry.get("duration", -1.0))
	return {
		"slot_type": slot_type,
		"card_id": card_id,
		"chips": chips(card_id),
		"keywords": keywords,
		"keyword_rules": rules,
		"has_condition": has_condition,
		"condition_text": condition_display(card, text) if has_condition else "",
		"condition_live": has_condition and is_live(card, view),
		"primed": not matching.is_empty(),
		"primed_time_left": time_left,
		"primed_duration": duration,
		"primed_charges": charges,
	}
