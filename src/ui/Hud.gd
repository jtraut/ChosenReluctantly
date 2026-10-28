extends CanvasLayer
class_name Hud
## Bottom HUD: 5 card slot widgets + a health bar. Polls Player each frame -
## no signals to wire up, nothing to keep in sync by hand.

@onready var health_bar: ProgressBar = $Root/HealthPanel/HealthBar
@onready var health_label: Label = $Root/HealthPanel/HealthLabel
@onready var slot_widgets: Array[CardSlotWidget] = [
	$Root/SlotBar/Slot1, $Root/SlotBar/Slot2, $Root/SlotBar/Slot3, $Root/SlotBar/Slot4, $Root/SlotBar/Slot5,
]

@onready var light_meter: AttackMeter = $Root/LightMeter
@onready var heavy_meter: AttackMeter = $Root/HeavyMeter

var player: Player = null


func _ready() -> void:
	_ignore_mouse_recursive($Root)
	for i in range(slot_widgets.size()):
		slot_widgets[i].set_key_hint(str(i + 1))
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)


## Sizes and anchors the HUD from data/ui.json `hud` for the current viewport.
func _apply_layout() -> void:
	var cfg := UiConfig.hud()
	var vp := get_viewport().get_visible_rect().size
	var s := HudLayout.ui_scale(vp, cfg)
	var bar := HudLayout.slot_bar_rect(vp, cfg, slot_widgets.size())
	var slot_bar: HBoxContainer = $Root/SlotBar
	# Anchored bottom-centre; offsets are relative to that anchor point.
	slot_bar.offset_left = bar.position.x - vp.x * 0.5
	slot_bar.offset_right = bar.end.x - vp.x * 0.5
	slot_bar.offset_top = bar.position.y - vp.y
	slot_bar.offset_bottom = bar.end.y - vp.y
	slot_bar.add_theme_constant_override("separation", roundi(float(cfg["slot_gap"]) * s))
	for widget in slot_widgets:
		widget.apply_layout(cfg, s)

	var meters := HudLayout.attack_meter_rects(vp, cfg)
	light_meter.configure(&"light", "LMB", false, cfg, s)
	heavy_meter.configure(&"heavy", "RMB", true, cfg, s)
	for pair in [[light_meter, &"light"], [heavy_meter, &"heavy"]]:
		var m: AttackMeter = pair[0]
		var r: Rect2 = meters[pair[1]]
		m.position = r.position
		m.size = r.size

	var hp := HudLayout.health_rect(vp, cfg)
	var panel: VBoxContainer = $Root/HealthPanel
	panel.offset_left = hp.position.x
	panel.offset_top = hp.position.y
	panel.offset_right = hp.end.x
	panel.offset_bottom = hp.end.y
	panel.add_theme_constant_override("separation", 0)
	health_label.custom_minimum_size = Vector2(hp.size.x, float(cfg["hp_label_height"]) * s)
	health_label.add_theme_font_size_override("font_size", roundi(float(cfg["hp_label_font_size"]) * s))
	health_label.add_theme_color_override("font_color", Color.html(cfg["hp_text_color"]))
	health_label.add_theme_color_override("font_outline_color", Color.html(cfg["hp_text_outline_color"]))
	health_label.add_theme_constant_override("outline_size", maxi(2, roundi(3.0 * s)))
	health_bar.custom_minimum_size = Vector2(hp.size.x, float(cfg["hp_bar_height"]) * s)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.html(cfg["hp_fill_color"])
	var back := StyleBoxFlat.new()
	back.bg_color = Color.html(cfg["hp_back_color"])
	for box in [fill, back]:
		var sb: StyleBoxFlat = box
		sb.border_color = Color.html(cfg["hp_border_color"])
		sb.set_border_width_all(maxi(1, roundi(2.0 * s)))
	health_bar.add_theme_stylebox_override("fill", fill)
	health_bar.add_theme_stylebox_override("background", back)


func set_player(p: Player) -> void:
	player = p
	light_meter.set_player(p)
	heavy_meter.set_player(p)


func _process(_delta: float) -> void:
	if player == null:
		return
	var health := player.health
	health_bar.max_value = health.max_health
	health_bar.value = health.current_health
	health_label.text = "HP %d / %d" % [roundi(health.current_health), roundi(health.max_health)]

	if player.card_slots == null:
		return
	for i in range(CardSlotController.SLOT_TYPE_ORDER.size()):
		var slot_type := CardSlotController.slot_type_at_index(i)
		slot_widgets[i].update_from_slot(player.card_slots.get_slot(slot_type))


## HUD is display only: nothing here may swallow left/right clicks meant for the
## world (attacks). Containers and bars default to STOP/PASS, so set it for all.
func _ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse_recursive(child)
