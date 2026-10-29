extends CanvasLayer
class_name RunHud
## "Room X of Y - Type" indicator (Milestone 3a): a small dark plate at the top centre with a type icon (a shape,
## so the type never depends on colour), sized and placed by HudLayout.room_indicator_rect from data/ui.json.
## Shown only in run mode; it listens to the sibling RunController's `room_started`.

@onready var panel: PanelContainer = $Panel
@onready var icon: RunTypeIcon = $Panel/Row/Icon
@onready var label: Label = $Panel/Row/Label

var _room_type: String = "combat"


func _ready() -> void:
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)
	var controller := get_parent().get_node_or_null("RunController") as RunController
	if controller != null:
		controller.room_started.connect(_on_room_started.bind(controller))


func _on_room_started(_index: int, _total: int, room_type: String, controller: RunController) -> void:
	_room_type = room_type
	label.text = "%s  -  %s" % [controller.room_label(), controller.room_type_name()]
	_apply_icon()


func _apply_icon() -> void:
	var tiers: Dictionary = RunConfig.get_config().get("tiers", {})
	icon.shape = RunIcons.shape_for(_room_type)
	icon.color = RunIcons.color_for(_room_type, UiConfig.run_ui(), tiers)


func _apply_layout() -> void:
	var hud_cfg := UiConfig.hud()
	var cfg := UiConfig.run_ui()
	var vp := get_viewport().get_visible_rect().size
	var s := HudLayout.ui_scale(vp, hud_cfg)
	var rect := HudLayout.room_indicator_rect(vp, hud_cfg)
	panel.position = rect.position
	panel.custom_minimum_size = rect.size
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html(String(cfg["indicator_bg_color"]))
	style.border_color = Color.html(String(cfg["indicator_border_color"]))
	style.set_border_width_all(maxi(roundi(s), 1))
	style.set_corner_radius_all(roundi(6.0 * s))
	style.content_margin_left = 10.0 * s
	style.content_margin_right = 10.0 * s
	panel.add_theme_stylebox_override("panel", style)
	(icon.get_parent() as HBoxContainer).add_theme_constant_override("separation", roundi(10.0 * s))
	var icon_px: float = float(cfg["indicator_icon_size"]) * s
	icon.custom_minimum_size = Vector2(icon_px, icon_px)
	label.add_theme_font_size_override("font_size", roundi(float(cfg["indicator_font_size"]) * s))
	label.add_theme_color_override("font_color", Color.html(String(cfg["indicator_text_color"])))
	_apply_icon()
