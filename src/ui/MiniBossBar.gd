class_name MiniBossBar
extends Control
## BD3a ux (MAP3 playtest carry-over): the named HP bar of a mini-boss, in the boss bar's spot at the top centre (a mini-boss
## room has no boss, so the two never show together). A name row, the boss meter (fill, ghost trail, armor shield and
## resistance diamond like the enemy bars), and the armor / resistance words. No phases and no attack line: those are MB1's.
## It is a child of BossHpBar, which also counts it for the damage numbers' keep-clear band.
##
## It watches the world for an Enemy whose tier is "mini_boss" (a 4 Hz scan, because the tier is applied a moment after the
## enemy spawns and Enemy has no signal for it) and follows the first one alive; when it dies it hands over to the next, if any.
## The name is data: run.json `tiers.mini_boss` `name_format` ("Act %d Mini-boss") and `display_name`, so MB1 can name each one.

const TIER_ID := "mini_boss"
const SCAN_INTERVAL := 0.25

var _enemy: Enemy = null
var _name_label: Label = null
var _meter: BossMeter = null
var _defense_label: Label = null
var _cfg: Dictionary = {}
var _bars: Dictionary = {}
var _scale: float = 1.0
var _fill: float = 1.0
var _ghost: float = 1.0
var _ghost_delay_left: float = 0.0
var _scan_left: float = 0.0


# ---- Pure (unit-tested) ----

## "Act 2 Mini-boss": `name_format` filled with the act when the tier data has one, else `display_name`, else "Mini-boss".
static func title_for(tier_cfg: Dictionary, act: int) -> String:
	var format: String = String(tier_cfg.get("name_format", ""))
	if format != "" and format.contains("%d"):
		return format % maxi(act, 1)
	var plain: String = String(tier_cfg.get("display_name", ""))
	return plain if plain != "" else "Mini-boss"


## True for a live enemy of the mini-boss tier.
static func is_candidate(tier_id: String, dead: bool) -> bool:
	return tier_id == TIER_ID and not dead


## Bottom edge (screen pixels) of the bar while it shows, else 0.
func occupied_bottom() -> float:
	if not visible:
		return 0.0
	return global_position.y + size.y


func current_enemy() -> Enemy:
	return _enemy


func title_text() -> String:
	return _name_label.text if _name_label != null else ""


# ---- Lifecycle ----

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cfg = UiConfig.boss_bar()
	_bars = UiConfig.hp_bars()
	_name_label = _text_label(true)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name_label)
	_meter = BossMeter.new()
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_meter)
	_defense_label = _text_label(false)
	_defense_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_defense_label)
	visible = false
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)


func _text_label(outlined: bool) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if outlined:
		label.add_theme_color_override("font_outline_color", Color.html(String(_cfg["text_outline_color"])))
	return label


func _apply_layout() -> void:
	if _name_label == null:
		return
	var hud_cfg := UiConfig.hud()
	var vp := get_viewport().get_visible_rect().size
	_scale = HudLayout.ui_scale(vp, hud_cfg)
	var rect := HudLayout.boss_bar_rect(vp, hud_cfg)
	var s: float = _scale
	var gap: float = float(_cfg["row_gap"]) * s
	var name_h: float = float(_cfg["name_height"]) * s
	var meter_h: float = float(_cfg["meter_height"]) * s
	var info_h: float = float(_cfg["info_height"]) * s
	position = rect.position
	size = Vector2(rect.size.x, name_h + gap + meter_h + gap + info_h)
	_place(_name_label, 0.0, 0.0, size.x, name_h)
	_name_label.add_theme_color_override("font_color", Color.html(String(_cfg["text_color"])))
	_name_label.add_theme_constant_override("outline_size", maxi(roundi(4.0 * s), 2))
	var y: float = name_h + gap
	_place(_meter, 0.0, y, size.x, meter_h)
	_meter.colors = _bars["colors"]
	_meter.style = _cfg
	_meter.notch_h = 0.0
	_meter.pip = meter_h
	_meter.border = float(_cfg["border"]) * s
	_meter.resist_border = float(_cfg["resist_border"]) * s
	_meter.ui_scale = s
	y += meter_h + gap
	_place(_defense_label, _meter.pip, y, size.x - 2.0 * _meter.pip, info_h)
	_defense_label.add_theme_font_size_override("font_size", roundi(float(_cfg["info_font_size"]) * s))
	_defense_label.add_theme_color_override("font_color", Color.html(String(_cfg["info_color"])))
	_refresh_texts()
	_meter.queue_redraw()


func _place(control: Control, x: float, y: float, w: float, h: float) -> void:
	control.position = Vector2(x, y)
	control.size = Vector2(w, h)


func _process(delta: float) -> void:
	_scan_left -= delta
	# A freed object compares equal to null in GDScript, so test validity, not null.
	if visible and (not is_instance_valid(_enemy) or _enemy.health.is_dead()):
		_unbind()
	if not is_instance_valid(_enemy) and _scan_left <= 0.0:
		_scan_left = SCAN_INTERVAL
		_try_bind(_find_candidate())
	if not is_instance_valid(_enemy):
		return
	_ghost_delay_left = maxf(_ghost_delay_left - delta, 0.0)
	_ghost = EnemyHpBar.ghost_step(_ghost, _fill, _ghost_delay_left, delta, float(_bars["ghost_drain_per_sec"]))
	_push_meter()


func _find_candidate() -> Enemy:
	var world: Node = WorldRef.get_world(get_tree())
	if world == null:
		return null
	for child: Node in world.get_children():
		var enemy := child as Enemy
		if enemy != null and not enemy is Boss and is_candidate(enemy.tier, enemy.health.is_dead()):
			return enemy
	return null


func _try_bind(enemy: Enemy) -> void:
	if enemy == null:
		return
	_enemy = enemy
	enemy.health.health_changed.connect(_on_health_changed)
	_fill = EnemyHpBar.fill_ratio(enemy.health.get_current_health(), enemy.health.get_max_health())
	_ghost = _fill
	_ghost_delay_left = 0.0
	_meter.resist_tint = BossHpBar.resist_tint(enemy.health.resistances, _bars)
	_meter.armor_tint = BossHpBar.armor_tint(enemy.health.get_armor_reduction(), _cfg)
	_refresh_texts()
	_push_meter()
	visible = true


func _unbind() -> void:
	if is_instance_valid(_enemy) and _enemy.health.health_changed.is_connected(_on_health_changed):
		_enemy.health.health_changed.disconnect(_on_health_changed)
	_enemy = null
	visible = false


func _on_health_changed(current: float, maximum: float) -> void:
	var new_fill: float = EnemyHpBar.fill_ratio(current, maximum)
	if new_fill < _fill:
		_ghost_delay_left = float(_bars["ghost_delay"])
	_fill = new_fill
	if _fill >= _ghost:
		_ghost = _fill
	_push_meter()


func _push_meter() -> void:
	_meter.fill = _fill
	_meter.ghost = _ghost
	_meter.queue_redraw()


func _refresh_texts() -> void:
	if _name_label == null:
		return
	var act: int = RunSession.current.act if RunSession.current != null else 1
	var title: String = title_for(RunConfig.tier(TIER_ID), act)
	var base: int = roundi(float(_cfg["name_font_size"]) * _scale)
	var low: int = roundi(float(_cfg["name_min_font_size"]) * _scale)
	var fit: Dictionary = TextFit.fit(title, _name_label.get_theme_font("font"), _name_label.size.x, 1, base, low)
	_name_label.text = String(fit["text"])
	_name_label.add_theme_font_size_override("font_size", int(fit["font_size"]))
	if _enemy != null and is_instance_valid(_enemy):
		var text: String = BossHpBar.defense_text(_enemy.health.get_armor_reduction(), _enemy.health.resistances, _cfg)
		var info_base: int = roundi(float(_cfg["info_font_size"]) * _scale)
		var info_low: int = roundi(float(_cfg["info_min_font_size"]) * _scale)
		var info_fit: Dictionary = TextFit.fit(text, _defense_label.get_theme_font("font"), _defense_label.size.x, 1, info_base, info_low)
		_defense_label.text = String(info_fit["text"])
		_defense_label.add_theme_font_size_override("font_size", int(info_fit["font_size"]))
