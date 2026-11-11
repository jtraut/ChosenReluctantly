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
var _staggered: bool = false
var _stagger_total: float = 0.001
var _stagger_left: float = 0.0
var _entering_phase: int = 0
var _fade_left: float = -1.0
var _cfg: Dictionary = {}
var _bars: Dictionary = {}
var _scale: float = 1.0
var _telegraph_active: bool = false
var _mini_bar: MiniBossBar = null
var _subtitle_label: Label = null
## MB1 ux: the subtitle text of the bound boss ("Act 1 Mini-boss"), read once when the bar binds so a later change of act (the Act 2 screen
## opens while this bar fades out) can never rewrite it. "" for the final boss.
var _subtitle: String = ""


# ---- Pure logic (unit-tested) ----

## "Phase 2 of 3: Getting into it" from the data format (index is 0-based).
static func phase_text(format: String, phase_index: int, count: int, phase_name: String) -> String:
	return format % [phase_index + 1, maxi(count, 1), phase_name]


## The resistance tint for the boss bar: like an enemy bar's (the strongest element's tint), except that equal
## resistance to every listed element (the final boss resists all alike) uses the neutral default tint: "all" has no
## element colour, and the shared `dominant_resistance` would pick whichever key comes first. Alpha 0 = no resistance. `hp_bars` is the `hp_bars` config block.
static func resist_tint(resistances: Dictionary, hp_bars: Dictionary, elements: Array[String] = TierRules.element_ids()) -> Color:
	var best: float = EnemyHpBar.max_resistance(resistances)
	if best <= 0.0:
		return Color(0.0, 0.0, 0.0, 0.0)
	var tints: Dictionary = hp_bars["resistance_tints"]
	var hex: String = String(hp_bars["default_resistance_tint"])
	if not resists_uniformly(resistances, elements):
		hex = String(tints.get(EnemyHpBar.dominant_resistance(resistances), hex))
	var color := Color.html(hex)
	return Color(color.r, color.g, color.b, 1.0)


## True when every element in the game (`elements`, normally `TierRules.element_ids()`) has the same positive
## resistance, a missing key counting as 0 (words: "Resists all elements 50%"). A table that lists fewer elements than
## the game has is "some", so a fire-only golem stops reading "all" the day a second element ships.
static func resists_uniformly(resistances: Dictionary, elements: Array[String] = TierRules.element_ids()) -> bool:
	var best: float = EnemyHpBar.max_resistance(resistances)
	if best <= 0.0 or elements.is_empty():
		return false
	for element: String in elements:
		if not is_equal_approx(float(resistances.get(element, 0.0)), best):
			return false
	return true


## "Resists all elements 50%" / "Resists some elements (up to 50%)", or "" without resistance.
static func resist_text(resistances: Dictionary, cfg: Dictionary, elements: Array[String] = TierRules.element_ids()) -> String:
	var best: float = EnemyHpBar.max_resistance(resistances)
	if best <= 0.0:
		return ""
	var key: String = "resist_all_format" if resists_uniformly(resistances, elements) else "resist_some_format"
	return String(cfg[key]) % roundi(best * 100.0)


## "Armor 50% - Resists all elements 50%": armor first, then resistance; either part is left out at 0. "" with neither.
## `armor_reduction` is the fraction of non-elemental damage armor removes (Health.get_armor_reduction()).
static func defense_text(armor_reduction: float, resistances: Dictionary, cfg: Dictionary, elements: Array[String] = TierRules.element_ids()) -> String:
	var parts: Array[String] = []
	if armor_reduction > 0.0:
		parts.append(String(cfg["armor_format"]) % roundi(armor_reduction * 100.0))
	var resist: String = resist_text(resistances, cfg, elements)
	if resist != "":
		parts.append(resist)
	return String(cfg["defense_joiner"]).join(parts)


## The armor pip colour for the boss bar: alpha 0 = no armor to show.
static func armor_tint(armor_reduction: float, cfg: Dictionary) -> Color:
	if armor_reduction <= 0.0:
		return Color(0.0, 0.0, 0.0, 0.0)
	var color := Color.html(String(cfg["armor_tint"]))
	return Color(color.r, color.g, color.b, 1.0)


## MB1 ux: "Act 1 Mini-boss" under a mini-boss's name (the tier's `name_format`, so one wording is reused), "" for the final boss.
static func subtitle_text(is_mini_boss: bool, act: int, tier_cfg: Dictionary) -> String:
	return MiniBossBar.title_for(tier_cfg, act) if is_mini_boss else ""


## MB1 ux: where an attack sits in a chain, as Vector2i(step, length) with step 1-based; Vector2i.ZERO when it is not part of one. The
## chain is read from the data (`chain` names the attack that follows), so a new combo needs no code. `attacks` is a boss's `attacks` block.
static func chain_step(attacks: Dictionary, attack_id: String) -> Vector2i:
	var head: String = attack_id
	var guard: int = 0
	while guard < 8:
		guard += 1
		var parent: String = ""
		for other: Variant in attacks:
			var def: Variant = attacks[other]
			if def is Dictionary and String((def as Dictionary).get("chain", "")) == head:
				parent = String(other)
				break
		if parent == "":
			break
		head = parent
	var length: int = 1
	var step: int = 1 if head == attack_id else 0
	var cursor: String = head
	guard = 0
	while guard < 8:
		guard += 1
		var node: Variant = attacks.get(cursor)
		var next_id: String = String((node as Dictionary).get("chain", "")) if node is Dictionary else ""
		if next_id == "" or not attacks.has(next_id):
			break
		length += 1
		cursor = next_id
		if cursor == attack_id:
			step = length
	if length < 2 or step == 0:
		return Vector2i.ZERO
	return Vector2i(step, length)


## The attack line text: the attack's label, with "(1/2)" or "(2/2)" when it belongs to a chain, so the second link of a combo reads as coming
## (and as the last one) instead of looking like the first one again. `format` is boss_bar `chain_format` (label, step, length).
static func attack_line(attacks: Dictionary, attack_id: String, label: String, format: String) -> String:
	var step: Vector2i = chain_step(attacks, attack_id)
	if step == Vector2i.ZERO or label == "":
		return label
	return format % [label, step.x, step.y]


## How many thresholds the boss is past, given the phase it is in (phase 0 = none, phase 2 of 3 = both).
static func crossed_count(phase_index: int, thresholds: Array[float]) -> int:
	return clampi(phase_index, 0, thresholds.size())


# ---- Lifecycle ----

const GROUP := &"boss_hp_bar"


## Bottom edge (screen pixels) of the bar block while it shows, else 0. Damage numbers keep below it (DamageNumber).
func occupied_bottom() -> float:
	var mini: float = _mini_bar.occupied_bottom() if _mini_bar != null else 0.0  # BD3a: the mini-boss bar holds the same spot
	if not is_showing():
		return mini
	return maxf(_root.position.y + _root.size.y, mini)


func _ready() -> void:
	layer = 3
	add_to_group(GROUP)
	_cfg = UiConfig.boss_bar()
	_bars = UiConfig.hp_bars()
	_build()
	_apply_layout()
	_mini_bar = MiniBossBar.new()
	_mini_bar.name = "MiniBossBar"
	add_child(_mini_bar)
	get_viewport().size_changed.connect(_apply_layout)
	_root.visible = false
	set_process(false)
	get_tree().node_added.connect(_on_node_added)
	for node: Node in get_tree().get_nodes_in_group(Boss.GROUP):
		_try_bind_id.call_deferred(node.get_instance_id())


func _exit_tree() -> void:
	if get_tree() != null and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is Boss:
		# Deferred by instance id, never by Object: a boss freed before the flush would fail the typed argument
		# conversion itself ("Cannot convert argument 1 from Object to Object"). Its own _ready has not run yet.
		_try_bind_id.call_deferred(node.get_instance_id())


func is_showing() -> bool:
	return _root != null and _root.visible


func current_boss() -> Boss:
	return _boss


## True while the STAGGERED cue is up (the reward window before the roar).
func is_staggered_shown() -> bool:
	return _staggered


## Notches drawn as crossed right now (a stagger counts its notch as crossed at once).
func crossed_notches() -> int:
	return _meter.crossed if _meter != null else 0


## The text on the attack line, or "" while it is hidden.
func attack_line_text() -> String:
	return _attack_label.text if _attack_label != null and _attack_label.visible else ""


## The text on the phase line (phase name, "Hit it now" or "Invulnerable").
func info_line_text() -> String:
	return _phase_label.text if _phase_label != null else ""


func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_name_label = _text_label(true)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_name_label)
	_subtitle_label = _text_label(true)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.visible = false
	_root.add_child(_subtitle_label)
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
	var sub_h: float = (float(_cfg["subtitle_height"]) + float(_cfg["row_gap"])) * s if _subtitle != "" else 0.0
	_root.position = rect.position
	_root.size = Vector2(rect.size.x, rect.size.y + sub_h)  # a mini-boss's subtitle row grows the block, so the damage-number band follows
	var gap: float = float(_cfg["row_gap"]) * s
	var y: float = 0.0
	var name_h: float = float(_cfg["name_height"]) * s
	_place(_name_label, 0.0, y, rect.size.x, name_h)
	_name_label.add_theme_color_override("font_color", Color.html(String(_cfg["text_color"])))
	_name_label.add_theme_constant_override("outline_size", maxi(roundi(4.0 * s), 2))
	y += name_h + gap
	_subtitle_label.visible = _subtitle != ""
	if _subtitle != "":
		_place(_subtitle_label, 0.0, y, rect.size.x, sub_h - gap)
		_subtitle_label.add_theme_color_override("font_color", Color.html(String(RunConfig.tier(MiniBossBar.TIER_ID).get("marker_color", "#ffffff"))).lerp(Color.WHITE, float(_cfg["subtitle_whiten"])))
		_subtitle_label.add_theme_constant_override("outline_size", maxi(roundi(3.0 * s), 2))
		_subtitle_label.add_theme_font_size_override("font_size", roundi(float(_cfg["subtitle_font_size"]) * s))
		_subtitle_label.text = _subtitle
		y += sub_h
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
	var pad: float = _meter.pip
	var phase_w: float = rect.size.x * float(_cfg["phase_width_fraction"])
	if HudLayout.boss_bar_stacked(vp, hud_cfg):
		# Too narrow for both on one row (1024x768): the phase line, then the armor / resistance line on its own row.
		_place(_phase_label, pad, y, rect.size.x - 2.0 * pad, info_h)
		y += info_h + gap
		_place(_resist_label, pad, y, rect.size.x - 2.0 * pad, info_h)
	else:
		_place(_phase_label, pad, y, phase_w - pad, info_h)
		_place(_resist_label, phase_w, y, rect.size.x - phase_w - pad, info_h)
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
	_attack_strip.stagger_color = Color.html(String(_cfg["stagger_color"]))
	_attack_strip.warn_color = Color.html(String(_cfg["warn_color"]))
	_attack_strip.ui_scale = s
	_refresh_phase()
	_refresh_defense()
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

## Deferred entry point: resolves the id, and does nothing when the boss is already gone.
func _try_bind_id(instance_id: int) -> void:
	if not is_instance_id_valid(instance_id):
		return
	var node := instance_from_id(instance_id) as Node
	if node != null and is_instance_valid(node):
		_try_bind(node)


func _try_bind(node: Node) -> void:
	var boss := node as Boss
	if boss == null or not is_instance_valid(boss) or not boss.is_inside_tree() or boss == _boss or boss.is_defeated():
		return
	_unbind()
	_boss = boss
	_subtitle = subtitle_text(boss.is_mini_boss(), ActTint.act_of(get_parent(), RunSession.current.act if RunSession.current != null else 1), RunConfig.tier(MiniBossBar.TIER_ID))
	_apply_layout()
	_attach_stack_label(boss)
	boss.health.health_changed.connect(_on_health_changed)
	boss.phase_changed.connect(_on_phase_changed)
	boss.stagger_started.connect(_on_stagger_started)
	boss.stagger_ended.connect(_on_stagger_ended)
	boss.transition_started.connect(_on_transition_started)
	boss.transition_ended.connect(_on_transition_ended)
	boss.attack_telegraphed.connect(_on_attack_telegraphed)
	boss.attack_landed.connect(_on_attack_landed)
	boss.defeated.connect(_on_defeated)
	boss.tree_exiting.connect(_on_boss_gone)
	_meter.thresholds = boss.phase_thresholds()
	_meter.resist_tint = resist_tint(boss.health.resistances, _bars)
	_refresh_defense()
	_fill = EnemyHpBar.fill_ratio(boss.health.get_current_health(), boss.health.get_max_health())
	_ghost = _fill
	_ghost_delay_left = 0.0
	_transitioning = boss.is_transitioning()
	_staggered = boss.is_staggered() and not _transitioning
	_entering_phase = boss.phase_index + (1 if (_transitioning or _staggered) else 0)
	_telegraph_active = false
	_attack_label.visible = false
	_attack_strip.stagger = false
	if _staggered:
		var total: float = BossConfig.stagger_seconds(BossConfig.boss(boss.enemy_id))
		_show_stagger(total, total)
	_fade_left = -1.0
	_root.modulate.a = 1.0
	_root.visible = true
	_fit_name()
	_refresh_phase()
	_push_meter()
	set_process(true)
	if boss.telegraph_left() > 0.0:
		_start_telegraph(_current_attack_label())


## BD3a: a boss shows its Bleed stack count and the detonate cue like an enemy does (its HP bar is this block, not an EnemyHpBar). One label
## per boss, set above its body.
func _attach_stack_label(boss: Boss) -> void:
	if boss.get_node_or_null("StatusStackLabel") != null or boss.status_manager == null:
		return
	var label := StatusStackLabel.new()
	label.name = "StatusStackLabel"
	boss.add_child(label)
	label.setup(boss.status_manager, TemplateVfx.body_top(boss) + float(UiConfig.status_stacks()["boss_gap"]))


## The armor and resistance line plus the armor pip, from the boss's live health (called on bind and on layout).
func _refresh_defense() -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	var reduction: float = _boss.health.get_armor_reduction()
	_meter.armor_tint = armor_tint(reduction, _cfg)
	var base: int = roundi(float(_cfg["info_font_size"]) * _scale)
	var low: int = roundi(float(_cfg["info_min_font_size"]) * _scale)
	var fit: Dictionary = TextFit.fit(defense_text(reduction, _boss.health.resistances, _cfg), _resist_label.get_theme_font("font"), _resist_label.size.x, 1, base, low)
	_resist_label.text = String(fit["text"])
	_resist_label.add_theme_font_size_override("font_size", int(fit["font_size"]))
	_meter.queue_redraw()


func _unbind() -> void:
	if _boss != null and is_instance_valid(_boss):
		_disconnect(_boss.health.health_changed, _on_health_changed)
		_disconnect(_boss.phase_changed, _on_phase_changed)
		_disconnect(_boss.stagger_started, _on_stagger_started)
		_disconnect(_boss.stagger_ended, _on_stagger_ended)
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
	var id: String = _boss.current_attack_id()
	return attack_line(attacks, id, String((attacks.get(id, {}) as Dictionary).get("label", "")), String(_cfg["chain_format"]))


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


func _on_stagger_started(next_phase_index: int, duration: float) -> void:
	_staggered = true
	_entering_phase = next_phase_index
	_stop_telegraph()
	_show_stagger(duration, duration)
	_refresh_phase()
	_push_meter()


func _on_stagger_ended(_next_phase_index: int) -> void:
	_end_stagger()
	_refresh_phase()
	_push_meter()


## The STAGGERED cue goes on the attack line (the boss has no attack running then), with the strip draining over the
## stagger so the window's length reads at a glance.
func _show_stagger(total: float, left: float) -> void:
	_stagger_total = maxf(total, 0.001)
	_stagger_left = left
	_attack_strip.stagger = true
	_attack_label.text = String(_cfg["stagger_text"])
	_attack_label.visible = true
	_attack_strip.progress_left = clampf(left / _stagger_total, 0.0, 1.0)
	_attack_strip.queue_redraw()


func _end_stagger() -> void:
	if not _staggered:
		return
	_staggered = false
	_attack_strip.stagger = false
	_attack_label.visible = false
	_attack_strip.progress_left = 0.0
	_attack_strip.queue_redraw()


func _on_transition_started(phase_index: int, _duration: float) -> void:
	_end_stagger()
	_transitioning = true
	_entering_phase = phase_index
	_stop_telegraph()
	_refresh_phase()
	_push_meter()


func _on_transition_ended(_index: int) -> void:
	_transitioning = false
	_refresh_phase()
	_push_meter()


func _on_attack_telegraphed(attack_id: String, label: String, _windup: float) -> void:
	if _staggered:
		return  # the stagger cue owns the attack line until the roar
	var attacks: Dictionary = BossConfig.boss(_boss.enemy_id).get("attacks", {}) if _boss != null else {}
	_start_telegraph(attack_line(attacks, attack_id, label, String(_cfg["chain_format"])))


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
	_attack_strip.stagger = false
	_attack_label.visible = false
	_attack_strip.progress_left = 0.0
	_attack_strip.queue_redraw()


func _refresh_phase() -> void:
	if _boss == null:
		return
	if _transitioning:
		_phase_label.text = String(_cfg["invulnerable_text"])
		_phase_label.add_theme_color_override("font_color", Color.html(String(_cfg["invuln_color"])))
	elif _staggered:
		_phase_label.text = String(_cfg["stagger_hint_text"])
		_phase_label.add_theme_color_override("font_color", Color.html(String(_cfg["stagger_color"])))
	else:
		_phase_label.text = phase_text(String(_cfg["phase_format"]), _boss.phase_index, _boss.phase_count(), _boss.phase_name())
		_phase_label.add_theme_color_override("font_color", Color.html(String(_cfg["info_color"])))


func _push_meter() -> void:
	_meter.fill = _fill
	_meter.ghost = _ghost
	_meter.invulnerable = _transitioning
	_meter.staggered = _staggered and not _transitioning
	var phase: int = _entering_phase if (_transitioning or _staggered) else (_boss.phase_index if _boss != null else 0)
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
	if _staggered and _boss != null:
		if not _boss.is_staggered():
			_end_stagger()  # a missed signal must not leave the cue up
			_refresh_phase()
		else:
			_stagger_left = maxf(_stagger_left - delta, 0.0)
			_attack_strip.progress_left = clampf(_stagger_left / _stagger_total, 0.0, 1.0)
			_attack_strip.queue_redraw()
			_meter.invuln_phase += delta * float(_cfg["invuln_pulse_hz"])  # the frame pulses
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
