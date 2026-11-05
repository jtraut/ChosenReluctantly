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


## The dodge pip row: under the RMB meter, same left edge.
static func dodge_rect(viewport_size: Vector2, cfg: Dictionary) -> Rect2:
	var s := ui_scale(viewport_size, cfg)
	var heavy: Rect2 = attack_meter_rects(viewport_size, cfg)[&"heavy"]
	var sz: Array = cfg["dodge_size"]
	return Rect2(Vector2(heavy.position.x, heavy.end.y + float(cfg["meter_row_gap"]) * s), Vector2(float(sz[0]), float(sz[1])) * s)


## The "Room X of Y - Type" indicator: top right, at the safe margin (3c moved it from the top centre, which the
## boss bar owns). Clear of the health panel and meters (top left), the slots (bottom) and the F3 overlay.
static func room_indicator_rect(viewport_size: Vector2, cfg: Dictionary) -> Rect2:
	var s := ui_scale(viewport_size, cfg)
	var sz: Array = cfg["room_indicator_size"]
	var size := Vector2(float(sz[0]), float(sz[1])) * s
	var margin := float(cfg["safe_margin"]) * s
	return Rect2(Vector2(viewport_size.x - margin - size.x, margin), size)


## The boss HP bar block (name, bar, phase line, attack line): top centre at the safe margin. It is centred, and
## its width is the authored width shrunk, if needed, to fit between the player's HUD (health panel and attack
## meters, top left) and the room indicator (top right) with `boss_bar_gap` between: it never overlaps either.
static func boss_bar_rect(viewport_size: Vector2, cfg: Dictionary) -> Rect2:
	var s := ui_scale(viewport_size, cfg)
	var sz: Array = cfg["boss_bar_size"]
	var size := Vector2(float(sz[0]), float(sz[1])) * s
	var margin := float(cfg["safe_margin"]) * s
	var centre: float = viewport_size.x * 0.5
	var left_end: float = health_rect(viewport_size, cfg).end.x
	var meters := attack_meter_rects(viewport_size, cfg)
	for key: StringName in meters:
		left_end = maxf(left_end, (meters[key] as Rect2).end.x)
	var right_start: float = room_indicator_rect(viewport_size, cfg).position.x
	var half: float = minf(centre - left_end, right_start - centre) - float(cfg.get("boss_bar_gap", 8.0)) * s
	size.x = clampf(2.0 * half, 0.0, size.x)
	if boss_bar_stacked_width(size.x / s, cfg):
		size.y += float(cfg["boss_bar_stack_extra"]) * s
	return Rect2(Vector2(centre - size.x * 0.5, margin), size)


## True when the boss bar is too narrow to share one row between the phase line and the armor / resistance line, so
## the latter gets a row of its own (and the block grows by `boss_bar_stack_extra`). `width_ref` is in reference px.
static func boss_bar_stacked_width(width_ref: float, cfg: Dictionary) -> bool:
	return width_ref < float(cfg["boss_bar_stack_below"])


static func boss_bar_stacked(viewport_size: Vector2, cfg: Dictionary) -> bool:
	return boss_bar_stacked_width(boss_bar_rect(viewport_size, cfg).size.x / ui_scale(viewport_size, cfg), cfg)


## Top edge (pixels) of the F3 debug overlay: just under the boss bar block. The overlay itself is not scaled,
## so at 1080p and 1440p it sits lower, clear of the scaled HUD pieces above it.
static func debug_overlay_top(viewport_size: Vector2, cfg: Dictionary) -> float:
	return boss_bar_rect(viewport_size, cfg).end.y + float(cfg["debug_overlay_gap"]) * ui_scale(viewport_size, cfg)


## Width of a key label column: the configured width, grown when the live key text ("Shift+LMB") is wider, so a
## rebound key is never clipped. `font_size` and `pad` are in pixels (already scaled).
static func key_label_width(font: Font, text: String, font_size: int, base_width: float, pad: float) -> float:
	return maxf(base_width, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x + pad)


## Chips per row of the relic row: it is as wide as the health panel and wraps. Always at least one.
static func relic_columns(width: float, chip: float, gap: float) -> int:
	return maxi(int(floorf((width + gap) / maxf(chip + gap, 1.0))), 1)


## The relic row (BD2): under the dodge pips, same left edge and width as the health panel, wrapping to as many rows as
## `count` chips need (the chip pitch is `relic_chip_size` + `relic_chip_gap`). An empty row has no height.
static func relic_row_rect(viewport_size: Vector2, cfg: Dictionary, count: int) -> Rect2:
	var s := ui_scale(viewport_size, cfg)
	var dodge := dodge_rect(viewport_size, cfg)
	var chip: float = float(cfg["relic_chip_size"]) * s
	var gap: float = float(cfg["relic_chip_gap"]) * s
	var width: float = dodge.size.x
	var columns: int = relic_columns(width, chip, gap)
	var rows: int = ceili(float(count) / float(columns)) if count > 0 else 0
	var height: float = float(rows) * chip + float(maxi(rows - 1, 0)) * gap
	return Rect2(Vector2(dodge.position.x, dodge.end.y + float(cfg["relic_row_gap"]) * s), Vector2(width, height))
