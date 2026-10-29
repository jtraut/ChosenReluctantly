class_name CastPreviewShapes
extends RefCounted
## Pure: turns a card's effect list into the ground shapes its cast will really hit, sized
## through VfxSizing from the same params the hit uses (so a preview can never lie about
## its hit area), and placed relative to the caster's FACING (the direction every card
## fires along, Player.get_aim_direction()).
##
## One part per aimed effect, in the card's effect order:
##   cone            size = VfxSizing.cone_reach(range), half_angle_degrees. At the caster.
##   aoe             size = VfxSizing.aoe_reach(radius). Centred on the caster, or placed at the
##                   clamped aim point when the card has max_range (placed: true).
##   zone            circle: size = VfxSizing.zone_circle_reach(radius). line: size = half length,
##                   half_width = half width (VfxSizing.zone_line_*), turned across the cast direction
##                   (shape zone_line). Always placed (placed: true, range = max_range).
##   projectile_lane size = lane LENGTH (VfxSizing.projectile_lane_length: max_range plus the lateral reach), half_width = VfxSizing.projectile_lane_half_width,
##                   start_offset = EffectTemplates.PROJECTILE_MUZZLE_OFFSET in front of the caster.
##   dash_path       size = lane LENGTH (distance), half_width = the dash path marker width. At the caster.
## Heal, buff and apply_status are not aimed: a card with no aimed part gets one small
## "self_ring" (radius from data/cast_preview.json, switch it off with self_ring_enabled).
## Each part also carries damage_type ("" when none) so the visual can take the element colour,
## placed (drawn at the clamped aim point, not at the caster), range (the cap when placed) and
## yaw_offset_degrees (180 for a dash that goes away from the aim). A dash part also shows an arrowhead at its far
## end (CastPreview); `cosmetic_width` is true when its lane is not a hit area (a dash with no path damage), so the
## arrowhead may be wider than the lane.

const CONE := "cone"
const AOE := "aoe"
const PROJECTILE_LANE := "projectile_lane"
const DASH_PATH := "dash_path"
const ZONE_LINE := "zone_line"
const SELF_RING := "self_ring"


static func parts_for_card(card_data: Dictionary, config: Dictionary) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	for effect: Dictionary in card_data.get("effects", []):
		var params: Dictionary = effect.get("params", {})
		match String(effect.get("template", "")):
			"cone":
				parts.append({"shape": CONE, "size": VfxSizing.cone_reach(float(params["range"])),
						"half_angle_degrees": float(params["half_angle_degrees"]), "half_width": 0.0,
						"start_offset": 0.0, "damage_type": String(params.get("damage_type", "physical"))})
			"aoe":
				parts.append({"shape": AOE, "size": VfxSizing.aoe_reach(float(params["radius"])),
						"half_angle_degrees": 0.0, "half_width": 0.0, "start_offset": 0.0,
						"damage_type": String(params.get("damage_type", "physical")),
						"placed": params.has("max_range"), "range": float(params.get("max_range", 0.0))})
			"zone":
				if String(params["shape"]) == ZoneShape.CIRCLE:
					parts.append({"shape": AOE, "size": VfxSizing.zone_circle_reach(float(params["radius"])),
							"half_angle_degrees": 0.0, "half_width": 0.0, "start_offset": 0.0,
							"damage_type": String(params["damage_type"]), "placed": true, "range": float(params["max_range"])})
				else:
					parts.append({"shape": ZONE_LINE, "size": VfxSizing.zone_line_half_length(float(params["length"])),
							"half_angle_degrees": 0.0, "half_width": VfxSizing.zone_line_half_width(float(params["width"])),
							"start_offset": 0.0, "damage_type": String(params["damage_type"]), "placed": true, "range": float(params["max_range"])})
			"projectile":
				parts.append({"shape": PROJECTILE_LANE, "size": VfxSizing.projectile_lane_length(float(params["max_range"]), float(params["hit_radius"])),
						"half_angle_degrees": 0.0, "half_width": VfxSizing.projectile_lane_half_width(float(params["hit_radius"])),
						"start_offset": EffectTemplates.PROJECTILE_MUZZLE_OFFSET, "damage_type": String(params["damage_type"])})
			"dash":
				var away: bool = String(params.get("direction_mode", EffectTemplates.DIRECTION_FORWARD)) == EffectTemplates.DIRECTION_AWAY
				if params.has("damage"):
					# A damaging dash draws the swept hit area: reaching sideways, behind the start and past the end.
					var hit_radius: float = float(params["hit_radius"])
					parts.append({"shape": DASH_PATH, "size": VfxSizing.dash_path_length(float(params["distance"]), hit_radius),
							"half_angle_degrees": 0.0, "half_width": VfxSizing.dash_path_half_width(hit_radius),
							"start_offset": -VfxSizing.lateral_reach(hit_radius), "damage_type": String(params["damage_type"]),
							"yaw_offset_degrees": 180.0 if away else 0.0})
				else:
					parts.append({"shape": DASH_PATH, "size": float(params["distance"]),
							"half_angle_degrees": 0.0, "half_width": VfxConfig.marker("dash_path_half_width"),
							"start_offset": 0.0, "damage_type": String(params.get("damage_type", "")),
							"yaw_offset_degrees": 180.0 if away else 0.0, "cosmetic_width": true})
	if parts.is_empty() and bool(config.get("self_ring_enabled", true)) and not (card_data.get("effects", []) as Array).is_empty():
		parts.append({"shape": SELF_RING, "size": float(config.get("self_ring_radius", 0.9)),
				"half_angle_degrees": 0.0, "half_width": 0.0, "start_offset": 0.0, "damage_type": ""})
	return parts
