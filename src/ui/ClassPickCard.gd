class_name ClassPickCard
extends Button
## One class on the pick screen (W1a): number key, name, body-colour swatch, HP, description and the attack style with a
## small shape glyph. Generic: it reads one `CharacterDatabase.list()` entry and never a class id. Same highlight rules as
## RunOptionCard (keyboard focus is the one highlight, hover moves it here, a thick outline plus the "Enter: play as"
## line on the screen say "this one"), so the choice is never colour alone: the name, the HP and the attack words are
## always there.

var entry: Dictionary = {}
var character_id: String = ""
var name_label: Label = null
var hp_label: Label = null
var description_label: Label = null
var attack_label: Label = null
var swatch: PanelContainer = null
var number_badge: PanelContainer = null

var _inner: VBoxContainer = null
var _pad: float = 0.0
var _width: float = 0.0
var _shape: String = ""
var _glyph_color: Color = Color.WHITE


## `the_entry`: a CharacterDatabase.list() dict. `attack_text`: the words for the attack style. `shape`: the light attack's
## shape (arc, projectile) for the glyph. `cfg`: UiConfig.class_pick(); `run_cfg`: UiConfig.run_ui(); `s`: pixel scale.
func setup(the_entry: Dictionary, index: int, attack_text: String, shape: String, cfg: Dictionary, run_cfg: Dictionary, s: float) -> void:
	entry = the_entry
	character_id = String(the_entry["id"])
	_shape = shape
	_pad = float(run_cfg["option_pad"]) * s * 1.5
	_width = float(cfg["card_width"]) * s
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	text = ""
	_glyph_color = Color.html(String(run_cfg["option_accent_color"]))
	_apply_styles(run_cfg, s)
	var name_size: int = roundi(float(cfg["name_font_size"]) * s)
	var body_size: int = roundi(float(cfg["body_font_size"]) * s)
	var small_size: int = roundi(float(cfg["small_font_size"]) * s)
	var inner_width: float = _width - 2.0 * _pad
	var text_color := Color.html(String(run_cfg["prompt_text_color"]))

	_inner = VBoxContainer.new()
	_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.add_theme_constant_override("separation", roundi(10.0 * s))
	add_child(_inner)
	_inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inner.offset_left = _pad
	_inner.offset_top = _pad
	_inner.offset_right = -_pad
	_inner.offset_bottom = -_pad

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", roundi(10.0 * s))
	_inner.add_child(head)
	number_badge = _badge(str(index + 1), small_size, run_cfg, s)
	head.add_child(number_badge)
	name_label = _label(String(the_entry["display_name"]), name_size, Color.WHITE, false)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)

	# Body colour swatch (a rounded block, outlined so a dark body still reads) beside the HP.
	var body_row := HBoxContainer.new()
	body_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_row.add_theme_constant_override("separation", roundi(12.0 * s))
	_inner.add_child(body_row)
	swatch = PanelContainer.new()
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var swatch_px: float = float(cfg["swatch_size"]) * s
	swatch.custom_minimum_size = Vector2(swatch_px, swatch_px)
	var swatch_style := StyleBoxFlat.new()
	swatch_style.bg_color = the_entry["body_color"]
	swatch_style.border_color = Color.html(String(cfg["swatch_border_color"]))
	swatch_style.set_border_width_all(maxi(roundi(2.0 * s), 1))
	swatch_style.set_corner_radius_all(roundi(float(cfg["swatch_size"]) * 0.3 * s))
	swatch.add_theme_stylebox_override("panel", swatch_style)
	body_row.add_child(swatch)
	hp_label = _label(String(cfg["hp_format"]) % roundi(float(the_entry["max_hp"])), name_size, Color.html(String(run_cfg["prompt_value_color"])), false)
	hp_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body_row.add_child(hp_label)

	description_label = _label(String(the_entry["description"]), body_size, text_color, true)
	description_label.custom_minimum_size.x = inner_width
	_inner.add_child(description_label)

	var attack_row := HBoxContainer.new()
	attack_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attack_row.add_theme_constant_override("separation", roundi(10.0 * s))
	_inner.add_child(attack_row)
	var glyph := Control.new()
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph_px: float = float(cfg["glyph_size"]) * s
	glyph.custom_minimum_size = Vector2(glyph_px, glyph_px)
	glyph.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	glyph.draw.connect(_draw_glyph.bind(glyph))
	attack_row.add_child(glyph)
	attack_label = _label("%s: %s" % [String(cfg["attack_label"]), attack_text], body_size, Color.html(String(run_cfg["prompt_title_color"])), true)
	attack_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attack_label.custom_minimum_size.x = inner_width - glyph_px - 10.0 * s
	attack_row.add_child(attack_label)

	_inner.minimum_size_changed.connect(_sync_min_size)  # wrapped labels settle after the first layout pass
	mouse_entered.connect(_on_hover)
	_sync_min_size()


## A Button ignores its children when it sizes itself: the height of the content becomes its custom minimum.
func _sync_min_size() -> void:
	if _inner != null:
		custom_minimum_size = Vector2(_width, _inner.get_combined_minimum_size().y + 2.0 * _pad)


## Hover moves the one highlight here, so mouse and keys never show two selections.
func _on_hover() -> void:
	if not disabled and is_visible_in_tree():
		grab_focus()


func _label(label_text: String, font_size: int, color: Color, wrap: bool) -> Label:
	var label := Label.new()
	label.text = label_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _badge(badge_text: String, font_size: int, run_cfg: Dictionary, s: float) -> PanelContainer:
	var holder := PanelContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(String(run_cfg["prompt_title_color"]))
	style.set_corner_radius_all(roundi(4.0 * s))
	style.content_margin_left = 7.0 * s
	style.content_margin_right = 7.0 * s
	style.content_margin_top = 1.0 * s
	style.content_margin_bottom = 1.0 * s
	holder.add_theme_stylebox_override("panel", style)
	holder.add_child(_label(badge_text, font_size, Color.html("#1a1218"), false))
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return holder


func _apply_styles(run_cfg: Dictionary, s: float) -> void:
	var radius: int = roundi(8.0 * s)
	var base := StyleBoxFlat.new()
	base.set_corner_radius_all(radius)
	base.set_border_width_all(maxi(roundi(2.0 * s), 1))
	base.bg_color = Color.html(String(run_cfg["option_card_color"]))
	base.border_color = Color.html(String(run_cfg["option_card_border_color"]))
	var hover := base.duplicate() as StyleBoxFlat
	hover.bg_color = Color.html(String(run_cfg["option_card_hover_color"]))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_corner_radius_all(radius)
	focus.set_border_width_all(maxi(roundi(float(run_cfg["option_focus_width"]) * s), 2))
	focus.border_color = Color.html(String(run_cfg["option_focus_color"]))
	add_theme_stylebox_override("normal", base)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	add_theme_stylebox_override("hover_pressed", hover)
	add_theme_stylebox_override("disabled", base)
	add_theme_stylebox_override("focus", focus)


## The attack style as a shape: a wedge for a swing (arc), a dot with a tail for a bolt (projectile); anything else a ring.
func _draw_glyph(glyph: Control) -> void:
	var box: Vector2 = glyph.size
	var r: float = minf(box.x, box.y) * 0.5
	var c: Vector2 = box * 0.5
	match _shape:
		"arc":
			var apex := Vector2(r * 0.2, box.y - r * 0.2)
			var pts := PackedVector2Array([apex])
			for i in range(9):
				var a: float = deg_to_rad(-85.0 + float(i) * 10.0)
				pts.append(apex + Vector2(cos(a), sin(a)) * r * 1.8)
			glyph.draw_colored_polygon(pts, _glyph_color)
		"projectile":
			glyph.draw_line(Vector2(r * 0.1, c.y), Vector2(box.x - r * 0.6, c.y), Color(_glyph_color, 0.45), r * 0.5)
			glyph.draw_circle(Vector2(box.x - r * 0.45, c.y), r * 0.45, _glyph_color)
		_:
			glyph.draw_arc(c, r * 0.7, 0.0, TAU, 20, _glyph_color, maxf(2.0, r * 0.2))
