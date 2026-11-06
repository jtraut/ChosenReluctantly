class_name RelicRow
extends Control
## The HUD relic row (BD2): one small chip per relic the run holds, under the dodge pips, wrapping at the health panel's width
## (the cap is 20, so up to a few rows). A chip is a dark tile with the relic's two-letter mark and a frame in its pool's
## colour. When a relic's trigger fires its chip lights up and a name tag says which relic it was ("why did that explode?");
## a relic firing in rapid bursts stays steadily lit with an "x3" counter (RelicFlash), it does not strobe.
## Display only. It reads the relic data and listens to signals; it never touches the run, the player or any RNG.
##
## Sources: in a run, the sibling RunController (relics_changed, room_started, relic_triggered; its RelicManager is rebuilt every
## room, so the controller forwards the trigger). In an arena scenario with relics, the RelicManager child of the host.

## The set of relics shown changed (the HUD re-sizes the row).
signal relics_set()
## A held relic fired (the floating relic cue listens; MAP1).
signal triggered(relic_id: String)

var _cfg: Dictionary = {}
var _scale: float = 1.0
var _entries: Array[Dictionary] = []
var _flashes: Dictionary = {}
var _tag_name: String = ""
var _tag_left: float = 0.0
var _controller: RunController = null
var _host: Node = null
var _manager: RelicManager = null
## relic id -> matches counted so far, for relics with an every-Nth trigger (the "2/4" counter).
var _progress: Dictionary = {}


## `{id, name, mark, color}` for a relic id. An id the data does not have still gives a chip.
static func entry_for(relic_id: String) -> Dictionary:
	var relic: Dictionary = RelicDatabase.get_relic(relic_id)
	var relic_name: String = String(relic.get("name", relic_id))
	return {"id": relic_id, "name": relic_name, "mark": RelicFlash.initials(relic_name), "nth": RelicProgress.nth_of(relic_id), "color": PoolDatabase.frame_color_for_pool(String(relic.get("pool", "")))}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false


## Wires the row to a run (`controller` may be null in an arena) and the node that would hold a scenario's RelicManager.
func bind(controller: RunController, host: Node) -> void:
	_controller = controller
	_host = host
	if _controller != null:
		_controller.relics_changed.connect(set_relics)
		_controller.room_started.connect(_on_room_started)
		_controller.relic_triggered.connect(on_trigger)


func _on_room_started(_index: int, _total: int, _room_type: String) -> void:
	var ids: Array[String] = []
	for shown: Dictionary in _controller.owned_relics():
		ids.append(String(shown["relic_id"]))
	set_relics(ids)


func configure(cfg: Dictionary, s: float) -> void:
	_cfg = cfg
	_scale = s
	queue_redraw()


func set_relics(ids: Array[String]) -> void:
	var same: bool = ids.size() == _entries.size()
	if same:
		for i in range(ids.size()):
			if String(_entries[i]["id"]) != ids[i]:
				same = false
				break
	if same:
		return
	_entries.clear()
	for relic_id: String in ids:
		_entries.append(entry_for(relic_id))
	var names: Array[String] = []
	for entry: Dictionary in _entries:
		names.append(String(entry["name"]))
	var marks: Array[String] = RelicFlash.unique_marks(names)  # two relics never share a mark
	for i in range(_entries.size()):
		_entries[i]["mark"] = marks[i]
	_progress.clear()
	for key: Variant in _flashes.keys():
		if not ids.has(String(key)):
			_flashes.erase(key)
	relics_set.emit()
	queue_redraw()


func entries() -> Array[Dictionary]:
	return _entries


## A relic fired: light its chip and put its name on the tag.
func on_trigger(relic_id: String, _trigger_index: int = 0, _event_id: String = "") -> void:
	var held: bool = false
	for entry: Dictionary in _entries:
		held = held or String(entry["id"]) == relic_id
	if not held:
		return
	triggered.emit(relic_id)
	var old: Dictionary = _flashes.get(relic_id, RelicFlash.fresh())
	_flashes[relic_id] = RelicFlash.trigger(old, float(_cfg.get("relic_flash_hold", 0.5)), float(_cfg.get("relic_count_window", 1.5)))
	_tag_name = String(entry_for(relic_id)["name"])
	_tag_left = float(_cfg.get("relic_name_hold", 1.6))
	queue_redraw()


func flash_state(relic_id: String) -> Dictionary:
	return _flashes.get(relic_id, RelicFlash.fresh())


func _process(delta: float) -> void:
	if _controller == null:
		_poll_manager()
	var animating: bool = _tag_left > 0.0 or _poll_progress()
	if _tag_left > 0.0:
		_tag_left = maxf(_tag_left - delta, 0.0)
	for key: Variant in _flashes.keys():
		var before: Dictionary = _flashes[key]
		var next: Dictionary = RelicFlash.step(before, delta, float(_cfg.get("relic_flash_release", 0.4)))
		animating = animating or RelicFlash.is_active(before)
		if RelicFlash.is_active(next) or int(next["count"]) > 0:
			_flashes[key] = next
		else:
			_flashes.erase(key)
	if animating:
		queue_redraw()


## Reads the every-Nth counters from the room's manager; true when one changed (so the row redraws).
func _poll_progress() -> bool:
	var changed: bool = false
	var manager: Node = _controller.relic_manager() if _controller != null else _manager
	for entry: Dictionary in _entries:
		if int(entry["nth"]) <= 1:
			continue
		var matches: int = RelicProgress.matches_of(manager, String(entry["id"]))
		if matches != int(_progress.get(String(entry["id"]), RelicProgress.NO_PROGRESS - 1)):
			_progress[String(entry["id"])] = matches
			changed = true
	return changed


## The counter text on a chip ("2/4"), or "" for a relic without one or while the manager can't say.
## Height in pixels of the every-Nth progress pips at UI scale `scale`: tall enough to count at 1024x600 (they were 4 px there).
static func pip_height(scale: float) -> float:
	return maxf(roundf(8.0 * scale), 6.0)


func counter_text(relic_id: String) -> String:
	for entry: Dictionary in _entries:
		if String(entry["id"]) == relic_id:
			return RelicProgress.text(int(_progress.get(relic_id, RelicProgress.NO_PROGRESS)), int(entry["nth"]))
	return ""


## Arena scenarios: find the RelicManager the scenario adds to the host, follow its relic list and its triggers.
func _poll_manager() -> void:
	if _host == null:
		return
	if _manager == null or not is_instance_valid(_manager):
		_manager = _host.get_node_or_null("RelicManager") as RelicManager
		if _manager == null:
			return
		_manager.relic_triggered.connect(on_trigger)
	set_relics(_manager.relic_ids())


## The rectangle of chip `index` in this control's own coordinates.
func chip_rect(index: int) -> Rect2:
	var chip: float = float(_cfg.get("relic_chip_size", 26)) * _scale
	var gap: float = float(_cfg.get("relic_chip_gap", 4)) * _scale
	var columns: int = HudLayout.relic_columns(size.x, chip, gap)
	return Rect2(Vector2(float(index % columns) * (chip + gap), float(index / columns) * (chip + gap)), Vector2(chip, chip))


func chip_font_px() -> int:
	return maxi(roundi(float(_cfg.get("relic_font_size", 12)) * _scale), int(_cfg.get("relic_min_font_size", 10)))


func _draw() -> void:
	if _cfg.is_empty() or _entries.is_empty():
		return
	var font: Font = get_theme_default_font()
	var px: int = chip_font_px()
	var frame_w: float = maxf(roundf(float(_cfg.get("relic_frame_width", 3)) * _scale), 2.0)
	var lit: Color = Color.html(String(_cfg.get("relic_flash_color", "#fff3c4")))
	var back: Color = Color.html(String(_cfg.get("relic_chip_color", "#1a1218")))
	var text_color: Color = Color.html(String(_cfg.get("relic_text_color", "#ffffff")))
	for i in range(_entries.size()):
		var entry: Dictionary = _entries[i]
		var rect: Rect2 = chip_rect(i)
		var state: Dictionary = _flashes.get(String(entry["id"]), RelicFlash.fresh())
		var level: float = float(state["level"])
		draw_rect(rect, back.lerp(lit, level * 0.55))
		draw_rect(rect.grow(-frame_w * 0.5), entry["color"], false, frame_w)
		if level > 0.01:
			# The flash is a bright outer ring that grows a little as well as a brighter tile, so it does not rest on colour alone.
			draw_rect(rect.grow(frame_w * (0.5 + level)), Color(lit, level), false, maxf(frame_w * 0.8, 2.0))
		var mark: String = String(entry["mark"])
		var counter_label: String = counter_text(String(entry["id"]))
		var text_size: Vector2 = font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px)
		var mark_mid: float = rect.position.y + rect.size.y * (0.4 if counter_label != "" else 0.5)
		var base := Vector2(rect.position.x + (rect.size.x - text_size.x) * 0.5, mark_mid + (font.get_ascent(px) - font.get_descent(px)) * 0.5)
		draw_string(font, base, mark, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, back if level > 0.6 else text_color)
		if counter_label != "":
			# Progress to the next firing of an every-Nth relic, as N pips along the chip's bottom edge: filled = counted so far (the text is
			# `counter_text`, "2/4"). Pips stay legible at any chip size, where a number would collide with the mark.
			var nth: int = int(entry["nth"])
			var done: int = int(_progress.get(String(entry["id"]), 0)) % nth
			var inner: Rect2 = rect.grow(-frame_w)
			var pip_h: float = pip_height(_scale)
			var gap_px: float = maxf(roundf(1.5 * _scale), 1.0)
			var pip_w: float = (inner.size.x - gap_px * float(nth - 1)) / float(nth)
			draw_rect(Rect2(Vector2(inner.position.x, inner.end.y - pip_h - gap_px), Vector2(inner.size.x, pip_h + gap_px)), Color(back, 0.95))  # a dark strip so the pips read on any frame colour
			for k in range(nth):
				var pip := Rect2(Vector2(inner.position.x + float(k) * (pip_w + gap_px), inner.end.y - pip_h), Vector2(pip_w, pip_h))
				if k < done:
					draw_rect(pip, lit)
				else:
					draw_rect(pip, Color(text_color, 0.5))
		var counter: String = RelicFlash.count_text(state)
		if counter != "":
			var cs: Vector2 = font.get_string_size(counter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px)
			var pill := Rect2(Vector2(rect.end.x - cs.x - 2.0, rect.position.y - cs.y * 0.5), cs + Vector2(4.0, 1.0))
			draw_rect(pill, lit)
			draw_string(font, pill.position + Vector2(2.0, (pill.size.y + font.get_ascent(px) - font.get_descent(px)) * 0.5), counter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, back)
	if _tag_left > 0.0 and _tag_name != "":
		var alpha: float = clampf(_tag_left / 0.4, 0.0, 1.0)
		var ts: Vector2 = font.get_string_size(_tag_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px)
		var rows_h: float = chip_rect(_entries.size() - 1).end.y
		var plate := Rect2(Vector2(0.0, rows_h + 6.0 * _scale), ts + Vector2(10.0, 4.0))
		draw_rect(plate, Color(back, 0.9 * alpha))
		draw_rect(plate, Color(lit, alpha), false, 1.0)
		draw_string(font, plate.position + Vector2(5.0, (plate.size.y + font.get_ascent(px) - font.get_descent(px)) * 0.5), _tag_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, Color(text_color, alpha))
