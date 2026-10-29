class_name BossHpBar
extends CanvasLayer
## Boss HP bar (3c), top centre while a boss lives: the boss's name, a bar with the enemy bars' fill and ghost
## trail, a notch and line at each phase threshold, the phase line ("Phase 2 of 3: Getting into it"), the
## resistance as a diamond plus words, and, while a telegraph runs, its attack label with a draining strip.
## During the roar between phases the bar shows "Invulnerable" (striped, bright frame: not colour alone).
##
## It finds the boss by class (`Boss`) through the SceneTree, so it works in a run and in the capture scenarios, and
## it reads the boss's live state when it binds (a reload mid-fight or mid-roar starts correct). Hidden on the
## boss's death, on the player's death and with no boss. Everything numeric and every word comes from
## data/ui.json (`boss_bar`, `hud`, `hp_bars`) and the boss itself; nothing here knows a boss id.

var _boss: Boss = null
var _root: Control = null
var _name_label: Label = null
var _meter: BossMeter = null
var _phase_label: Label = null
var _resist_label: Label = null
var _attack_strip: BossAttackStrip = null
var _attack_label: Label = null
var _fill: float = 1.0
var _ghost: float = 1.0
var _ghost_delay_left: float = 0.0
var _transitioning: bool = false
var _entering_phase: int = 0
var _fade_left: float = -1.0
var _cfg: Dictionary = {}
var _bars: Dictionary = {}
var _scale: float = 1.0
var _telegraph_active: bool = false


# ---- Pure logic (unit-tested) ----

## "Phase 2 of 3: Getting into it" from the data format (index is 0-based).
static func phase_text(format: String, phase_index: int, count: int, phase_name: String) -> String:
	return format % [phase_index + 1, maxi(count, 1), phase_name]


## The resistance tint for the boss bar: like an enemy bar's (the strongest element's tint), except that equal
## resistance to every listed element (the final boss resists all alike) uses the neutral default tint: "all" has no
## element colour, and the shared `dominant_resistance` would pick whichever key comes first. Alpha 0 = no resistance. `hp_bars` is the `hp_bars` config block.
static func resist_tint(resistances: Dictionary, hp_bars: Dictionary) -> Color:
	var best: float = EnemyHpBar.max_resistance(resistances)
	if best <= 0.0:
		return Color(0.0, 0.0, 0.0, 0.0)
	var tints: Dictionary = hp_bars["resistance_tints"]
	var hex: String = String(hp_bars["default_resistance_tint"])
	if not resists_uniformly(resistances):
		hex = String(tints.get(EnemyHpBar.dominant_resistance(resistances), hex))
	var color := Color.html(hex)
	return Color(color.r, color.g, color.b, 1.0)


## True when every element listed has the same positive resistance (words: "Resists all elements 50%").
static func resists_uniformly(resistances: Dictionary) -> bool:
	var best: float = EnemyHpBar.max_resistance(resistances)
	if best <= 0.0:
		return false
	for key: Variant in resistances:
		if not is_equal_approx(float(resistances[key]), best):
			return false
	return true


## "Resists all elements 50%" / "Resists some elements (up to 50%)", or "" without resistance.
static func resist_text(resistances: Dictionary, cfg: Dictionary) -> String:
	var best: float = EnemyHpBar.max_resistance(resistances)
	if best <= 0.0:
		return ""
	var key: String = "resist_all_format" if resists_uniformly(resistances) else "resist_some_format"
	return String(cfg[key]) % roundi(best * 100.0)


## How many thresholds the boss is past, given the phase it is in (phase 0 = none, phase 2 of 3 = both).
static func crossed_count(phase_index: int, thresholds: Array[float]) -> int:
	return clampi(phase_index, 0, thresholds.size())


# ---- Lifecycle ----

func _ready() -> void:
	layer = 3
	_cfg = UiConfig.boss_bar()
	_bars = UiConfig.hp_bars()
	_build()
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)
	_root.visible = false
	set_process(false)
	get_tree().node_added.connect(_on_node_added)
	for node: Node in get_tree().get_nodes_in_group(Boss.GROUP):
		_try_bind.call_deferred(node)


func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is Boss:
		_try_bind.call_deferred(node)  # its own _ready (health, phases, resistances) has not run yet


func is_showing() -> bool:
	return _root != null and _root.visible


func current_boss() -> Boss:
	return _boss


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_name_label = _text_label(true)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_name_label)
	_meter = BossMeter.new()
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_meter)
	_phase_label = _text_label(false)
	_root.add_child(_phase_label)
	_resist_label = _text_label(false)
	_resist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_resist_label)
	_attack_strip = BossAttackStrip.new()
	_attack_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_attack_strip)
	_attack_label = _text_label(true)
	_attack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_attack_strip.add_child(_attack_label)
	_attack_strip.label = _attack_label
	_attack_label.visible = false


func _text_label(outlined: bool) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if outlined:
		label.add_theme_color_override("font_outline_color", Color.html(String(_cfg["text_outline_color"])))
	return label


func _apply_layout() -> void:
	if _root == null:
		return
	var hud_cfg := UiConfig.hud()
	var vp := get_viewport().get_visible_rect().size
	_scale = HudLayout.ui_scale(vp, hud_cfg)
	var rect := HudLayout.boss_bar_rect(vp, hud_cfg)
	var s: float = _scale
	_root.position = rect.position
	_root.size = rect.size
	var gap: float = float(_cfg["row_gap"]) * s
	var y: float = 0.0
	var name_h: float = float(_cfg["name_height"]) * s
	_place(_name_label, 0.0, y, rect.size.x, name_h)
	_name_label.add_theme_color_override("font_color", Color.html(String(_cfg["text_color"])))
	_name_label.add_theme_constant_override("outline_size", maxi(roundi(4.0 * s), 2))
	y += name_h + gap
	var meter_h: float = float(_cfg["meter_height"]) * s
	_place(_meter, 0.0, y, rect.size.x, meter_h)
	_meter.colors = _bars["colors"]
	_meter.style = _cfg
	_meter.notch_h = float(_cfg["notch_height"]) * s
	_meter.pip = meter_h - _meter.notch_h
	_meter.border = float(_cfg["border"]) * s
	_meter.resist_border = float(_cfg["resist_border"]) * s
	_meter.ui_scale = s
	y += meter_h + gap
	var info_h: float = float(_cfg["info_height"]) * s
	var half: float = rect.size.x * 0.5
	var pad: float = _meter.pip
	_place(_phase_label, pad, y, half - pad, info_h)
	_place(_resist_label, half, y, half - pad, info_h)
	for label: Label in [_phase_label, _resist_label]:
		label.add_theme_font_size_override("font_size", roundi(float(_cfg["info_font_size"]) * s))
		label.add_theme_color_override("font_color", Color.html(String(_cfg["info_color"])))
	y += info_h + gap
	var attack_h: float = float(_cfg["attack_height"]) * s
	_place(_attack_strip, pad, y, rect.size.x - 2.0 * pad, attack_h)
	_place(_attack_label, 0.0, 0.0, rect.size.x - 2.0 * pad, attack_h - maxf(4.0 * s, 3.0))
	_attack_label.add_theme_font_size_override("font_size", roundi(float(_cfg["attack_font_size"]) * s))
	_attack_label.add_theme_color_override("font_color", Color.html(String(_cfg["text_color"])))
	_attack_label.add_theme_constant_override("outline_size", maxi(roundi(4.0 * s), 2))
	_attack_strip.colors = _bars["colors"]
	_attack_strip.warn_color = Color.html(String(_cfg["warn_color"]))
	_attack_strip.ui_scale = s
	_refresh_phase()
	_fit_name()
	_meter.queue_redraw()
	_attack_strip.queue_redraw()


func _place(control: Control, x: float, y: float, w: float, h: float) -> void:
	control.position = Vector2(x, y)
	control.size = Vector2(w, h)


func _fit_name() -> void:
	if _name_label == null or _boss == null:
		return
	var base: int = roundi(float(_cfg["name_font_size"]) * _scale)
	var low: int = roundi(float(_cfg["name_min_font_size"]) * _scale)
	var fit: Dictionary = TextFit.fit(_boss.display_name(), _name_label.get_theme_font("font"), _name_label.size.x, 1, base, low)
	_name_label.text = String(fit["text"])
	_name_label.add_theme_font_size_override("font_size", int(fit["font_size"]))


# ---- Binding ----

func _try_bind(node: Node) -> void:
	var boss := node as Boss
	if boss == null or not is_instance_valid(boss) or not boss.is_inside_tree() or boss == _boss or boss.is_defeated():
		return
	_unbind()
	_boss = boss
	boss.health.health_changed.connect(_on_health_changed)
	boss.phase_changed.connect(_on_phase_changed)
	boss.transition_started.connect(_on_transition_started)
	boss.transition_ended.connect(_on_transition_ended)
	boss.attack_telegraphed.connect(_on_attack_telegraphed)
	boss.attack_landed.connect(_on_attack_landed)
	boss.defeated.connect(_on_defeated)
	boss.tree_exiting.connect(_on_boss_gone)
	_meter.thresholds = boss.phase_thresholds()
	_meter.resist_tint = resist_tint(boss.health.resistances, _bars)
	_resist_label.text = resist_text(boss.health.resistances, _cfg)
	_fill = EnemyHpBar.fill_ratio(boss.health.get_current_health(), boss.health.get_max_health())
	_ghost = _fill
	_ghost_delay_left = 0.0
	_transitioning = boss.is_transitioning()
	_entering_phase = boss.phase_index + (1 if _transitioning else 0)
	_telegraph_active = false
	_attack_label.visible = false
	_fade_left = -1.0
	_root.modulate.a = 1.0
	_root.visible = true
	_fit_name()
	_refresh_phase()
	_push_meter()
	set_process(true)
	if boss.telegraph_left() > 0.0:
		_start_telegraph(_current_attack_label())


func _unbind() -> void:
	if _boss != null and is_instance_valid(_boss):
		_disconnect(_boss.health.health_changed, _on_health_changed)
		_disconnect(_boss.phase_changed, _on_phase_changed)
		_disconnect(_boss.transition_started, _on_transition_started)
		_disconnect(_boss.transition_ended, _on_transition_ended)
		_disconnect(_boss.attack_telegraphed, _on_attack_telegraphed)
		_disconnect(_boss.attack_landed, _on_attack_landed)
		_disconnect(_boss.defeated, _on_defeated)
		_disconnect(_boss.tree_exiting, _on_boss_gone)
	_boss = null


func _disconnect(sig: Signal, callable: Callable) -> void:
	if sig.is_connected(callable):
		sig.disconnect(callable)


## The label of the attack being wound up, from the boss data (used when the bar binds mid-wind-up).
func _current_attack_label() -> String:
	var attacks: Dictionary = BossConfig.boss(_boss.enemy_id).get("attacks", {})
	return String((attacks.get(_boss.current_attack_id(), {}) as Dictionary).get("label", ""))


# ---- Signals ----

func _on_health_changed(current: float, maximum: float) -> void:
	var new_fill: float = EnemyHpBar.fill_ratio(current, maximum)
	var dropped: bool = new_fill < _fill
	_fill = new_fill
	if _fill >= _ghost:
		_ghost = _fill
	elif dropped:
		_ghost_delay_left = float(_bars["ghost_delay"])
	_push_meter()


func _on_phase_changed(_index: int, _name: String) -> void:
	_refresh_phase()
	_push_meter()


func _on_transition_started(phase_index: int, _duration: float) -> void:
	_transitioning = true
	_entering_phase = phase_index
	_stop_telegraph()
	_refresh_phase()
	_push_meter()


func _on_transition_ended(_index: int) -> void:
	_transitioning = false
	_refresh_phase()
	_push_meter()


func _on_attack_telegraphed(_attack_id: String, label: String, _windup: float) -> void:
	_start_telegraph(label)


func _on_attack_landed(_attack_id: String, _hit: bool) -> void:
	_stop_telegraph()


func _on_defeated() -> void:
	_begin_hide()


func _on_boss_gone() -> void:
	_unbind()
	_hide_now()


func _start_telegraph(label: String) -> void:
	_telegraph_active = true
	_attack_label.text = label
	_attack_label.visible = label != ""
	_attack_strip.progress_left = 1.0
	_attack_strip.queue_redraw()


func _stop_telegraph() -> void:
	_telegraph_active = false
	_attack_label.visible = false
	_attack_strip.progress_left = 0.0
	_attack_strip.queue_redraw()


func _refresh_phase() -> void:
	if _boss == null:
		return
	if _transitioning:
		_phase_label.text = String(_cfg["invulnerable_text"])
		_phase_label.add_theme_color_override("font_color", Color.html(String(_cfg["invuln_color"])))
	else:
		_phase_label.text = phase_text(String(_cfg["phase_format"]), _boss.phase_index, _boss.phase_count(), _boss.phase_name())
		_phase_label.add_theme_color_override("font_color", Color.html(String(_cfg["info_color"])))


func _push_meter() -> void:
	_meter.fill = _fill
	_meter.ghost = _ghost
	_meter.invulnerable = _transitioning
	var phase: int = _entering_phase if _transitioning else (_boss.phase_index if _boss != null else 0)
	_meter.crossed = crossed_count(phase, _meter.thresholds)
	_meter.queue_redraw()


func _process(delta: float) -> void:
	if _boss != null and (_game_over() or _boss.is_defeated()):
		_begin_hide()
	if _fade_left >= 0.0:
		_fade_left -= delta / maxf(Engine.time_scale, 0.05)  # real time: the death slow-mo must not stretch the fade
		var total: float = maxf(float(_cfg["fade_out"]), 0.001)
		_root.modulate.a = clampf(_fade_left / total, 0.0, 1.0)
		if _fade_left <= 0.0:
			_hide_now()
		return
	var redraw: bool = false
	_ghost_delay_left = maxf(_ghost_delay_left - delta, 0.0)
	var ghost_after: float = EnemyHpBar.ghost_step(_ghost, _fill, _ghost_delay_left, delta, float(_bars["ghost_drain_per_sec"]))
	if ghost_after != _ghost:
		_ghost = ghost_after
		redraw = true
	if _transitioning:
		_meter.invuln_phase += delta * float(_cfg["invuln_pulse_hz"])
		redraw = true
	if _telegraph_active and _boss != null:
		if _boss.telegraph_left() <= 0.0:
			_stop_telegraph()  # a cancelled attack emits nothing; the strip simply ends
		else:
			_attack_strip.progress_left = _boss.telegraph_left() / maxf(_boss.telegraph_total(), 0.001)
			_attack_strip.queue_redraw()
	if redraw:
		_push_meter()


func _game_over() -> bool:
	var main := get_parent() as Main
	return main != null and (main.is_game_over() or (main.player != null and main.player.is_dead()))


func _begin_hide() -> void:
	if _fade_left < 0.0 and _root.visible:
		_fade_left = float(_cfg["fade_out"])
		_stop_telegraph()


func _hide_now() -> void:
	_fade_left = -1.0
	_root.visible = false
	set_process(false)
