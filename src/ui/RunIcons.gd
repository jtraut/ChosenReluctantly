class_name RunIcons
extends RefCounted
## One shape per room type and enemy tier, reused everywhere (room indicator, prompt screens, the marker
## above elites and bosses), so the shape carries the meaning when colour does not:
## combat = circle, elite = diamond, rest = plus, boss = star, relic room = hexagon (BD2-B). MAP1 adds merchant = square,
## mini-boss = triangle, curse room = X, buff room = up arrow, so the map reads without colour. Pure geometry, unit-tested.

const SHAPE_CIRCLE := "circle"
const SHAPE_DIAMOND := "diamond"
const SHAPE_PLUS := "plus"
const SHAPE_STAR := "star"
const SHAPE_HEX := "hex"
const SHAPE_SQUARE := "square"
const SHAPE_TRIANGLE := "triangle"
const SHAPE_X := "x"
const SHAPE_ARROW := "arrow"

const BY_ID: Dictionary = {
	"combat": SHAPE_CIRCLE,
	"normal": SHAPE_CIRCLE,
	"elite": SHAPE_DIAMOND,
	"rest": SHAPE_PLUS,
	"boss": SHAPE_STAR,
	"relic_room": SHAPE_HEX,
	"merchant": SHAPE_SQUARE,
	"mini_boss": SHAPE_TRIANGLE,
	"curse_room": SHAPE_X,
	"buff_room": SHAPE_ARROW,
}


## The shape id for a room type or tier id; unknown ids get the circle.
static func shape_for(id: String) -> String:
	return String(BY_ID.get(id, SHAPE_CIRCLE))


## Outline of a shape centred on the origin that fits in a circle of `radius` (y grows downwards).
static func polygon(shape: String, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match shape:
		SHAPE_DIAMOND:
			pts.append_array([Vector2(0, -radius), Vector2(radius * 0.8, 0), Vector2(0, radius), Vector2(-radius * 0.8, 0)])
		SHAPE_PLUS:
			var a := radius * 0.32
			var b := radius * 0.9
			pts.append_array([
				Vector2(-a, -b), Vector2(a, -b), Vector2(a, -a), Vector2(b, -a), Vector2(b, a), Vector2(a, a),
				Vector2(a, b), Vector2(-a, b), Vector2(-a, a), Vector2(-b, a), Vector2(-b, -a), Vector2(-a, -a),
			])
		SHAPE_SQUARE:
			var q := radius * 0.78
			pts.append_array([Vector2(-q, -q), Vector2(q, -q), Vector2(q, q), Vector2(-q, q)])
		SHAPE_TRIANGLE:
			pts.append_array([Vector2(0, -radius), Vector2(radius * 0.95, radius * 0.72), Vector2(-radius * 0.95, radius * 0.72)])
		SHAPE_X:
			for p: Vector2 in polygon(SHAPE_PLUS, radius * 1.1):
				pts.append(p.rotated(PI * 0.25))
		SHAPE_ARROW:
			pts.append_array([
				Vector2(0, -radius), Vector2(radius * 0.92, -radius * 0.02), Vector2(radius * 0.42, -radius * 0.02), Vector2(radius * 0.42, radius * 0.9),
				Vector2(-radius * 0.42, radius * 0.9), Vector2(-radius * 0.42, -radius * 0.02), Vector2(-radius * 0.92, -radius * 0.02),
			])
		SHAPE_HEX:
			for i in 6:
				var angle := -PI * 0.5 + float(i) * TAU / 6.0
				pts.append(Vector2(cos(angle), sin(angle)) * radius * 0.92)
		SHAPE_STAR:
			for i in 10:
				var angle := -PI * 0.5 + float(i) * PI / 5.0
				var r := radius if i % 2 == 0 else radius * 0.45
				pts.append(Vector2(cos(angle), sin(angle)) * r)
		_:
			for i in 14:
				var angle := float(i) * TAU / 14.0
				pts.append(Vector2(cos(angle), sin(angle)) * radius * 0.9)
	return pts


## The colour of a room type: elite and boss take the tier marker colour from data/run.json (so the world marker
## and the HUD never disagree); the rest come from ui.json run_ui.type_colors.
static func color_for(id: String, run_ui: Dictionary, tiers: Dictionary) -> Color:
	var tier: Variant = tiers.get(id)
	if tier is Dictionary and String((tier as Dictionary).get("marker_color", "")).is_valid_html_color():
		return Color.html(String((tier as Dictionary)["marker_color"]))
	var colors: Dictionary = run_ui.get("type_colors", {})
	return Color.html(String(colors.get(id, "#f4ece8")))
