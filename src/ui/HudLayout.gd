class_name HudLayout
extends RefCounted
## Pure HUD rectangle math from data/ui.json `hud`. All values are authored at
## `reference_height` and scaled by viewport height (same rule as Game Over).

static func ui_scale(viewport_size: Vector2, cfg: Dictionary) -> float:
	var ref := float(cfg["reference_height"])
	if ref <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	return viewport_size.y / ref


static func slot_size(viewport_size: Vector2, cfg: Dictionary) -> Vector2:
	var sz: Array = cfg["slot_size"]
	return Vector2(float(sz[0]), float(sz[1])) * ui_scale(viewport_size, cfg)


static func slot_bar_rect(viewport_size: Vector2, cfg: Dictionary, slot_count: int) -> Rect2:
	var s := ui_scale(viewport_size, cfg)
	var slot := slot_size(viewport_size, cfg)
	var gap := float(cfg["slot_gap"]) * s
	var width := slot.x * slot_count + gap * maxi(slot_count - 1, 0)
	var margin := float(cfg["safe_margin"]) * s
	return Rect2(Vector2((viewport_size.x - width) * 0.5, viewport_size.y - margin - slot.y), Vector2(width, slot.y))


static func health_rect(viewport_size: Vector2, cfg: Dictionary) -> Rect2:
	var s := ui_scale(viewport_size, cfg)
	var sz: Array = cfg["health_size"]
	var margin := float(cfg["safe_margin"]) * s
	return Rect2(Vector2(margin, margin), Vector2(float(sz[0]), float(sz[1])) * s)


## The area every HUD rect must stay inside.
static func safe_area(viewport_size: Vector2, cfg: Dictionary) -> Rect2:
	var m := float(cfg["safe_margin"]) * ui_scale(viewport_size, cfg)
	return Rect2(Vector2(m, m), viewport_size - Vector2(m, m) * 2.0)


## Light and heavy attack meter rows, stacked under the health panel (same left
## edge). Returns {&"light": Rect2, &"heavy": Rect2}; each rect spans label + bar.
static func attack_meter_rects(viewport_size: Vector2, cfg: Dictionary) -> Dictionary:
	var s := ui_scale(viewport_size, cfg)
	var hp := health_rect(viewport_size, cfg)
	var light_sz: Array = cfg["light_meter_size"]
	var heavy_sz: Array = cfg["heavy_meter_size"]
	var x := hp.position.x
	var y := hp.end.y + float(cfg["meter_top_gap"]) * s
	var light := Rect2(Vector2(x, y), Vector2(float(light_sz[0]), float(light_sz[1])) * s)
	y = light.end.y + float(cfg["meter_row_gap"]) * s
	var heavy := Rect2(Vector2(x, y), Vector2(float(heavy_sz[0]), float(heavy_sz[1])) * s)
	return {&"light": light, &"heavy": heavy}


## The "Room X of Y - Type" indicator: top right, at the safe margin (3c moved it from the top centre, which the
## boss bar owns). Clear of the health panel and meters (top left), the slots (bottom) and the F3 overlay.
static func room_indicator_rect(viewport_size: Vector2, cfg: Dictionary) -> Rect2:
	var s := ui_scale(viewport_size, cfg)
	var sz: Array = cfg["room_indicator_size"]
	var size := Vector2(float(sz[0]), float(sz[1])) * s
	var margin := float(cfg["safe_margin"]) * s
	return Rect2(Vector2(viewport_size.x - margin - size.x, margin), size)


## The boss HP bar block (name, bar, phase line, attack line): top centre at the safe margin.
static func boss_bar_rect(viewport_size: Vector2, cfg: Dictionary) -> Rect2:
	var s := ui_scale(viewport_size, cfg)
	var sz: Array = cfg["boss_bar_size"]
	var size := Vector2(float(sz[0]), float(sz[1])) * s
	var margin := float(cfg["safe_margin"]) * s
	return Rect2(Vector2((viewport_size.x - size.x) * 0.5, margin), size)


## Top edge (pixels) of the F3 debug overlay: just under the boss bar block. The overlay itself is not scaled,
## so at 1080p and 1440p it sits lower, clear of the scaled HUD pieces above it.
static func debug_overlay_top(viewport_size: Vector2, cfg: Dictionary) -> float:
	return boss_bar_rect(viewport_size, cfg).end.y + float(cfg["debug_overlay_gap"]) * ui_scale(viewport_size, cfg)
