extends CanvasLayer
class_name RunHud
## "Room X of Y - Type" indicator (Milestone 3a; MAP3 ux: over three acts a first line "Act 2 of 3" and the whole-run room, "Room 14 of 30"): a small dark plate at the top centre with a type icon (a shape,
## so the type never depends on colour), sized and placed by HudLayout.room_indicator_rect from data/ui.json.
## Shown only in run mode; it listens to the sibling RunController's `room_started`.

@onready var panel: PanelContainer = $Panel
@onready var icon: RunTypeIcon = $Panel/Row/Icon
@onready var label: Label = $Panel/Row/Label

var _room_type: String = "combat"
## MAP1: the gold readout (coin, total, a "+N" when a fight pays). Its own layer, above the prompt panels (layer 9), so the "+N" is not dimmed by
## the reward screen it lands behind. Shown only in a map run: gold is earned only there.
var gold_layer: CanvasLayer = null
var gold_badge: GoldBadge = null
var _controller: RunController = null


func _ready() -> void:
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)
	var controller := get_parent().get_node_or_null("RunController") as RunController
	_controller = controller
	_build_gold()
	_apply_layout()
	if controller != null:
		controller.room_started.connect(_on_room_started.bind(controller))
		controller.gold_changed.connect(_on_gold_changed)
		_sync_gold()


func _on_room_started(_index: int, _total: int, room_type: String, controller: RunController) -> void:
	_sync_gold()
	_room_type = room_type
	label.text = indicator_text(controller.act_label(), controller.run_room_label(), controller.room_type_name())
	_apply_layout()  # the plate is taller on a multi-act run


## The plate's text: "Act 2 of 3" on its own line above "Room 14 of 30  -  Type"; a one-act run (empty `act_text`) has the room line only, as before.
static func indicator_text(act_text: String, room_text: String, type_text: String) -> String:
	var line: String = "%s  -  %s" % [room_text, type_text]
	return line if act_text == "" else "%s%s%s" % [act_text, char(10), line]


## True when the run has acts to show (the plate has its extra line).
func _acts_on() -> bool:
	return _controller != null and _controller.act_label() != ""


func _build_gold() -> void:
	gold_layer = CanvasLayer.new()
	gold_layer.name = "GoldLayer"
	gold_layer.layer = 10
	add_child(gold_layer)
	gold_badge = GoldBadge.new()
	gold_badge.name = "Gold"
	gold_layer.add_child(gold_badge)
	gold_badge.visible = false


## Shows the gold readout in a map run, with the run's total; hidden in a straight run.
func _sync_gold() -> void:
	if gold_badge == null:
		return
	var on: bool = _controller != null and _controller.map_on()
	gold_badge.visible = on
	if on:
		gold_badge.set_total(_controller.gold())


## The gold badge sits on layer 10, above the reward panels, so it must step aside for the screens that are not "in the run": the class pick (layer 9)
## and Game Over (layer 10, earlier in the tree).
func _process(_delta: float) -> void:
	if gold_layer == null:
		return
	var host: Node = get_parent()
	var class_pick: CanvasLayer = host.get_node_or_null("ClassPickScreen") as CanvasLayer
	var game_over: CanvasLayer = host.get_node_or_null("GameOverScreen") as CanvasLayer
	gold_layer.visible = not ((class_pick != null and class_pick.visible) or (game_over != null and game_over.visible))


func _on_gold_changed(total: int, delta: int) -> void:
	if gold_badge == null:
		return
	gold_badge.visible = true
	gold_badge.set_total(total)
	gold_badge.show_delta(delta)


func _apply_icon() -> void:
	var tiers: Dictionary = RunConfig.get_config().get("tiers", {})
	icon.shape = RunIcons.shape_for(_room_type)
	icon.color = RunIcons.color_for(_room_type, UiConfig.run_ui(), tiers)


func _apply_layout() -> void:
	var hud_cfg := UiConfig.hud()
	var cfg := UiConfig.run_ui()
	var vp := get_viewport().get_visible_rect().size
	var s := HudLayout.ui_scale(vp, hud_cfg)
	var rect := HudLayout.room_indicator_rect(vp, hud_cfg, _acts_on())
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
	_apply_gold_layout(hud_cfg, vp, s)
	_apply_icon()


func _apply_gold_layout(hud_cfg: Dictionary, vp: Vector2, s: float) -> void:
	if gold_badge == null:
		return
	var map_cfg: Dictionary = UiConfig.map_screen()
	var rect := HudLayout.gold_rect(vp, hud_cfg, map_cfg, _acts_on())
	gold_badge.position = rect.position
	gold_badge.size = rect.size
	gold_badge.custom_minimum_size = rect.size
	gold_badge.configure(roundi(float(map_cfg["hud_gold_font_size"]) * s), float(map_cfg["hud_gold_hold"]), float(map_cfg["hud_gold_rise"]) * s,
		Color.html(String(map_cfg["gold_color"])), Color.WHITE, true)
