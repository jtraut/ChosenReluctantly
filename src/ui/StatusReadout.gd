class_name StatusReadout
extends Control
## BD3b-ux: the two rows under the dodge pips that say what the player is carrying right now.
##   COUNTER  every `counter` status on the player (Charge): "Charge 6/10", one segment per stack up to the cap the status manager reports (a relic can
##            raise it), and a thin drain line under the segments for the time left before the stacks decay. It is data-driven: it shows any self status
##            whose data effect_type is "counter", never a status id.
##   TRIGGER  every buff whose triggers are live (Spiteful Ward): a shield shape, the card's name, a bar that drains over the buff's life with the seconds
##            left, and a flash with "xN" each time a trigger fires. The same fire also goes out as `trigger_fired`, so the HUD can float the name at the
##            player (the buff lives 4 s and fires in bursts; the top-left chip alone is far from where the player is looking).
## The row space is reserved even while empty (HudLayout.status_rect), so the relic row below never jumps. Display only: it reads the player's status
## manager and the BuffTriggers host (RelicManager signals plus `live_buff_sources()`), and writes nothing. Text: data/run.json ui.status_readout;
## look: data/ui.json hud status_*.

## A buff trigger of `source` fired. `label` is the display name.
signal trigger_fired(source: String, label: String)

var _cfg: Dictionary = {}
var _scale: float = 1.0
var _player: Player = null
var _host: RelicManager = null
var _counters: Array[Dictionary] = []
## source -> {expires_at: float, duration: float (-1 unknown), flash: Dictionary (RelicFlash state)}
var _triggers: Dictionary = {}


# ---- Pure rules (unit-tested) ----

## The counter rows of a status manager: [{id, name, stacks, max, decay_fraction}] ordered by id. `decay_fraction` is the time left over the
## status's `stacking.decay_after` (1 = just gained, 0 = about to drop), or -1 when the status does not decay.
static func counter_rows(manager: StatusEffectManager) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if manager == null:
		return rows
	var ids: Array = manager.active_status_ids()
	ids.sort()
	for status_id: Variant in ids:
		var id: String = String(status_id)
		var entry: Dictionary = StatusDatabase.get_status(id)
		if String(entry.get("effect_type", "")) != "counter":
			continue
		var decay_after: float = float((entry.get("stacking", {}) as Dictionary).get("decay_after", 0.0))
		rows.append({
			"id": id,
			"name": String(entry.get("display_name", id.replace("_", " ").capitalize())),
			"stacks": manager.stacks_of(id),
			"max": manager.max_stacks_of(id),
			"decay_fraction": decay_fraction(manager.decay_left_of(id), decay_after),
		})
	return rows


## Time left over the decay window, 0..1; -1 for a status with no decay window (`decay_after` 0 or less).
static func decay_fraction(decay_left: float, decay_after: float) -> float:
	if decay_after <= 0.0:
		return -1.0
	return clampf(decay_left / decay_after, 0.0, 1.0)


## "Charge 6/10", with the max word at the cap ("Charge 10/10 MAX"). `texts` is run.json ui.status_readout.
static func counter_label(row: Dictionary, texts: Dictionary) -> String:
	var line: String = String(texts.get("counter_format", "%s %d/%d")) % [String(row["name"]), int(row["stacks"]), int(row["max"])]
	if int(row["max"]) > 0 and int(row["stacks"]) >= int(row["max"]):
		line += String(texts.get("max_suffix", " MAX"))
	return line


## How full the buff's bar is, 0..1. An unknown duration (a buff seen without its start) is a full bar.
static func trigger_fraction(time_left: float, duration: float) -> float:
	if duration <= 0.0:
		return 1.0
	return clampf(time_left / duration, 0.0, 1.0)


## "3.2 s". `texts` is run.json ui.status_readout.
static func seconds_text(time_left: float, texts: Dictionary) -> String:
	return String(texts.get("seconds_format", "%.1f s")) % maxf(time_left, 0.0)


## The display name of a buff source: "card:<id>" is that card's name; anything else is the source with its prefix cut off.
static func source_name(source: String, texts: Dictionary) -> String:
	if source.is_empty():
		return String(texts.get("trigger_fallback", ""))
	var id: String = source.substr(source.find(":") + 1) if source.contains(":") else source
	var card: Dictionary = CardDatabase.get_card(id) if source.begins_with("card:") else {}
	return String(card.get("name", id))


## The rows to draw, at most `max_rows`: counters first, then triggers (each row is {kind, ...}).
static func visible_rows(counters: Array[Dictionary], triggers: Array[Dictionary], max_rows: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row: Dictionary in counters:
		rows.append(row.merged({"kind": "counter"}))
	for row: Dictionary in triggers:
		rows.append(row.merged({"kind": "trigger"}))
	while rows.size() > maxi(max_rows, 0):
		rows.pop_back()
	return rows


# ---- Node ----

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(cfg: Dictionary, s: float) -> void:
	_cfg = cfg
	_scale = s
	queue_redraw()


func set_player(p: Player) -> void:
	_player = p
	_counters.clear()
	_disconnect_host()
	_triggers.clear()


func counters() -> Array[Dictionary]:
	return _counters


## The live buff sources with their rows' data (tests): {source: {expires_at, duration, flash}}.
func triggers() -> Dictionary:
	return _triggers


## The whole readout as it would draw (tests and captures).
func rows() -> Array[Dictionary]:
	return visible_rows(_counters, _trigger_rows(), int(_cfg.get("status_rows", 2)))


func _exit_tree() -> void:
	_disconnect_host()


func _process(delta: float) -> void:
	_poll_host()
	var manager: StatusEffectManager = _player.hurtbox.status_manager if _player != null and is_instance_valid(_player) and _player.hurtbox != null else null
	_counters = counter_rows(manager)
	var release: float = float(_cfg.get("status_flash_release", 0.4))
	var animating: bool = false
	for source: Variant in _triggers.keys():
		var entry: Dictionary = _triggers[source]
		entry["flash"] = RelicFlash.step(entry["flash"], delta, release)
		animating = animating or RelicFlash.is_active(entry["flash"])
	if animating or not _counters.is_empty() or not _triggers.is_empty():
		queue_redraw()
	elif visible:
		queue_redraw()  # one last redraw to clear the rows


## The BuffTriggers host is made on the first buff cast, so the HUD cannot connect at start: look for it every frame, connect once, and rebuild the
## live list from `live_buff_sources()` (robust to a missed signal and to a reset that ended everything).
func _poll_host() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var found: Variant = _player.get_meta(RelicManager.BUFF_HOST_META) if _player.has_meta(RelicManager.BUFF_HOST_META) else null
	var host: RelicManager = found as RelicManager if found is RelicManager and is_instance_valid(found) else null
	if host != _host:
		_disconnect_host()
		_host = host
		if _host != null:
			_host.buff_triggers_started.connect(_on_started)
			_host.buff_triggers_ended.connect(_on_ended)
			_host.buff_trigger_fired.connect(_on_fired)
	if _host == null:
		_triggers.clear()
		return
	var live: Array[String] = _host.live_buff_sources()
	for source: String in live:
		if not _triggers.has(source) or float((_triggers[source] as Dictionary)["expires_at"]) < 0.0:
			# The host's `buff_triggers_started` fires in the frame it is made, before this poll can connect, so a first sight reads the expiry from the host.
			var expires_at: float = _host.buff_expires_at(source)
			var entry: Dictionary = _triggers.get(source, _new_entry(-1.0, -1.0))
			entry["expires_at"] = expires_at
			entry["duration"] = maxf(expires_at - _now(), 0.0) if expires_at >= 0.0 else -1.0
			_triggers[source] = entry
	for source: Variant in _triggers.keys():
		if not live.has(String(source)):
			_triggers.erase(source)


func _disconnect_host() -> void:
	if _host != null and is_instance_valid(_host):
		if _host.buff_triggers_started.is_connected(_on_started):
			_host.buff_triggers_started.disconnect(_on_started)
		if _host.buff_triggers_ended.is_connected(_on_ended):
			_host.buff_triggers_ended.disconnect(_on_ended)
		if _host.buff_trigger_fired.is_connected(_on_fired):
			_host.buff_trigger_fired.disconnect(_on_fired)
	_host = null


static func _new_entry(expires_at: float, duration: float) -> Dictionary:
	return {"expires_at": expires_at, "duration": duration, "flash": RelicFlash.fresh()}


func _now() -> float:
	var relay: CombatEventsRelay = CombatLink.events()
	return relay.now() if relay != null else 0.0


func _on_started(source: String, expires_at: float) -> void:
	var entry: Dictionary = _triggers.get(source, _new_entry(-1.0, -1.0))
	entry["expires_at"] = expires_at
	entry["duration"] = maxf(expires_at - _now(), 0.0)  # a recast refreshes the whole bar
	_triggers[source] = entry


func _on_ended(source: String, _reason: String) -> void:
	_triggers.erase(source)


func _on_fired(source: String, _index: int, _event_id: String) -> void:
	var entry: Dictionary = _triggers.get(source, _new_entry(-1.0, -1.0))
	entry["flash"] = RelicFlash.trigger(entry["flash"], float(_cfg.get("status_flash_hold", 0.5)), float(_cfg.get("status_count_window", 1.5)))
	_triggers[source] = entry
	trigger_fired.emit(source, source_name(source, _texts()))


func _texts() -> Dictionary:
	return RunConfig.ui().get("status_readout", {})


func _trigger_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var texts: Dictionary = _texts()
	var keys: Array = _triggers.keys()
	keys.sort()
	for source: Variant in keys:
		var entry: Dictionary = _triggers[source]
		var time_left: float = float(entry["expires_at"]) - _now() if float(entry["expires_at"]) >= 0.0 else -1.0
		out.append({
			"source": String(source),
			"name": source_name(String(source), texts),
			"time_left": time_left,
			"fraction": trigger_fraction(time_left, float(entry["duration"])),
			"flash": entry["flash"],
		})
	return out


func _draw() -> void:
	if _cfg.is_empty():
		return
	var shown: Array[Dictionary] = rows()
	var s: float = _scale
	var texts: Dictionary = _texts()
	var font: Font = get_theme_default_font()
	var px: int = maxi(roundi(float(_cfg.get("status_font_size", 12)) * s), int(_cfg.get("status_min_font_px", 12)))
	var row_h: float = maxf(float(_cfg.get("status_row_height", 20)) * s, float(px) + 4.0)
	var gap: float = float(maxi(1, roundi(2.0 * s)))
	var outline: int = maxi(2, roundi(2.0 * s))
	var outline_col := Color.html(String(_cfg.get("status_text_outline_color", "#0d080b")))
	var text_col := Color.html(String(_cfg.get("status_text_color", "#ffffff")))
	var back := Color.html(String(_cfg.get("status_back_color", "#1c1218")))
	back.a = 0.85
	var frame := Color.html(String(_cfg.get("status_border_color", "#f4ece8")))
	var thin: float = float(maxi(1, roundi(1.0 * s)))
	var thick: float = float(maxi(2, roundi(2.0 * s)))
	var drain_h: float = float(maxi(2, roundi(float(_cfg.get("status_drain_height", 3)) * s)))
	var label_w: float = float(_cfg.get("status_label_width", 112)) * s
	for i in range(shown.size()):
		var row: Dictionary = shown[i]
		var top: float = float(i) * (row_h + gap)
		var rect := Rect2(0.0, top, size.x, row_h)
		var base_y: float = top + (row_h + font.get_ascent(px) - font.get_descent(px)) * 0.5
		if String(row["kind"]) == "counter":
			_draw_counter(row, rect, label_w, px, base_y, font, texts, back, frame, text_col, outline_col, outline, thin, thick, drain_h)
		else:
			_draw_trigger(row, rect, px, base_y, font, texts, back, frame, text_col, outline_col, outline, thin, thick, drain_h)


func _draw_counter(row: Dictionary, rect: Rect2, label_w: float, px: int, base_y: float, font: Font, texts: Dictionary, back: Color, frame: Color, text_col: Color, outline_col: Color, outline: int, thin: float, thick: float, drain_h: float) -> void:
	var stacks: int = int(row["stacks"])
	var maximum: int = maxi(int(row["max"]), 1)
	var at_max: bool = stacks >= maximum
	var color := Color.html(String(_cfg.get("status_counter_max_color" if at_max else "status_counter_color", "#c79bff")))
	var label: String = counter_label(row, texts)
	if font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x > label_w:
		label = counter_label(row, texts.merged({"max_suffix": ""}, true))  # no room for the MAX word at this size: "15/15" already says it
	draw_string_outline(font, Vector2(0.0, base_y), label, HORIZONTAL_ALIGNMENT_LEFT, label_w, px, outline, outline_col)
	draw_string(font, Vector2(0.0, base_y), label, HORIZONTAL_ALIGNMENT_LEFT, label_w, px, text_col)
	var bar := Rect2(rect.position.x + label_w + 4.0 * _scale, rect.position.y, maxf(rect.size.x - label_w - 4.0 * _scale, 4.0), rect.size.y)
	draw_rect(bar, back)
	var seg_w: float = bar.size.x / float(maximum)
	for k in range(stacks):
		draw_rect(Rect2(bar.position.x + float(k) * seg_w + thin, bar.position.y + thin, maxf(seg_w - thin * 2.0, 1.0), bar.size.y - thin * 2.0 - drain_h), color)
	draw_rect(bar, frame, false, thin)
	var fraction: float = float(row["decay_fraction"])
	if fraction >= 0.0 and stacks > 0:
		var drain := Rect2(bar.position.x, bar.end.y - drain_h, bar.size.x * fraction, drain_h)
		draw_rect(drain, color.lightened(0.6))


func _draw_trigger(row: Dictionary, rect: Rect2, px: int, base_y: float, font: Font, texts: Dictionary, back: Color, frame: Color, text_col: Color, outline_col: Color, outline: int, thin: float, thick: float, drain_h: float) -> void:
	var color := Color.html(String(_cfg.get("status_trigger_color", "#ffb04a")))
	var flash: Dictionary = row["flash"]
	var lit: float = float(flash.get("level", 0.0))
	draw_rect(rect, back)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * float(row["fraction"]), rect.size.y - drain_h)), Color(color, 0.55))
	if lit > 0.0:
		draw_rect(rect, Color(1.0, 1.0, 1.0, 0.45 * lit))  # the fire flash goes under the label, so the name and the xN stay readable
	if float(row["time_left"]) >= 0.0:
		draw_rect(Rect2(rect.position.x, rect.end.y - drain_h, rect.size.x * float(row["fraction"]), drain_h), color)
	# The shield: a shape, so the row is not told apart by colour alone.
	var h: float = rect.size.y - 4.0 * _scale
	var x0: float = rect.position.x + 3.0 * _scale
	var y0: float = rect.position.y + 2.0 * _scale
	var shield := PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 1.0), Vector2(0.0, 0.5)])
	var moved := PackedVector2Array()
	for p: Vector2 in shield:
		moved.append(Vector2(x0 + p.x * h * 0.8, y0 + p.y * h))
	draw_colored_polygon(moved, color.lightened(0.25))
	var text_x: float = x0 + h * 0.8 + 5.0 * _scale
	var label: String = String(row["name"])
	if float(row["time_left"]) >= 0.0:
		label += "  " + seconds_text(float(row["time_left"]), texts)
	var count: String = RelicFlash.count_text(flash)
	if count != "":
		label += "  " + count
	draw_string_outline(font, Vector2(text_x, base_y), label, HORIZONTAL_ALIGNMENT_LEFT, rect.end.x - text_x, px, outline, outline_col)
	draw_string(font, Vector2(text_x, base_y), label, HORIZONTAL_ALIGNMENT_LEFT, rect.end.x - text_x, px, text_col)
	draw_rect(rect, frame, false, thin)
	if lit > 0.0:
		# A trigger fired: a thick frame swells out of the row and fades over status_flash_release.
		draw_rect(rect.grow(thick * (2.0 - lit)), Color(1.0, 1.0, 1.0, lit), false, thick)
