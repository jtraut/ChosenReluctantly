class_name ElementVisuals
extends RefCounted
## Looks up an element's effect color and scale from data/pools.json
## ("visual"). A damage type is an element id (fire, later water); physical or
## any unknown type uses the neutral pool's visual. Templates take this color
## and scale as parameters, so a new element is data only.

const FALLBACK_COLOR := Color(1.0, 1.0, 1.0)
const NEUTRAL_ID := "neutral"

static var _validated: bool = false


static func visual_for_damage_type(damage_type: String) -> Dictionary:
	_validate_once()
	var pool_id: String = damage_type
	if not PoolDatabase.has(pool_id) or String(PoolDatabase.get_definition(pool_id).get("kind", "")) != "element":
		pool_id = NEUTRAL_ID
	var visual: Variant = PoolDatabase.get_definition(pool_id).get("visual")
	if typeof(visual) != TYPE_DICTIONARY:
		return {"color": FALLBACK_COLOR, "scale": 1.0}
	var visual_dict: Dictionary = visual
	return {"color": Color.html(String(visual_dict["color"])), "scale": float(visual_dict["scale"])}


## Same as visual_for_damage_type, pulled toward the caster team's tint (data/vfx.json
## "team_tints"). A team without a tint (the player) gets the plain look, so an enemy
## shot never reads as a player physical shot. The cosmetic scale is left alone.
static func visual_for_team(damage_type: String, team: String) -> Dictionary:
	var look: Dictionary = visual_for_damage_type(damage_type)
	var tint: Dictionary = VfxConfig.team_tint(team)
	if tint.is_empty():
		return look
	var is_element: bool = PoolDatabase.has(damage_type) and String(PoolDatabase.get_definition(damage_type).get("kind", "")) == "element"
	var mix: float = float(tint["element_mix"] if is_element else tint["neutral_mix"])
	var base: Color = look["color"]
	return {"color": base.lerp(Color.html(String(tint["color"])), mix), "scale": look["scale"]}


static func color_for_damage_type(damage_type: String) -> Color:
	return visual_for_damage_type(damage_type)["color"]


static func scale_for_damage_type(damage_type: String) -> float:
	return visual_for_damage_type(damage_type)["scale"]


## Fail loudly (once) on bad pool data; lookups still fall back so play continues.
static func _validate_once() -> void:
	if _validated:
		return
	_validated = true
	var errors := PoolDatabase.validate_all()
	if not errors.is_empty():
		push_error("data/pools.json invalid: " + "; ".join(errors))
