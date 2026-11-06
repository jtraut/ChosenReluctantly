class_name RelicCueLayer
extends Control
## The floating relic cues (MAP1 ux): when a relic triggers, its name floats up from the point it fired, inside a ring in the relic's pool colour.
## "Why did that explode?" is answered where the player is already looking, not only on the top-left chip.
## Positions: the RelicManager's `relic_triggered` carries no point, so this layer remembers where the last effect owned by "relic:<id>" landed
## (the relay's hit_landed / status_applied carry that origin and a position) and uses it; with none it falls back to the player. No RNG, no
## gameplay state: display only. Rules (merge, cap, stacking, easing): RelicCues.

var _cfg: Dictionary = {}
var _scale: float = 1.0
var _cues: Array[Dictionary] = []
var _spots: Dictionary = {}
var _player_provider: Callable = Callable()
var _relay: CombatEventsRelay = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## `player_provider`: Callable() -> Node3D (the player, for the fallback spot).
func bind(player_provider: Callable) -> void:
	_player_provider = player_provider
	_connect_relay()


func configure(cfg: Dictionary, s: float) -> void:
	_cfg = cfg
	_scale = s


func _connect_relay() -> void:
	var relay: CombatEventsRelay = CombatLink.events()
	if relay == null or relay == _relay:
		return
	_relay = relay
	relay.hit_landed.connect(_on_hit)
	relay.status_applied.connect(_on_status)


func _exit_tree() -> void:
	if _relay != null and is_instance_valid(_relay):
		if _relay.hit_landed.is_connected(_on_hit):
			_relay.hit_landed.disconnect(_on_hit)
		if _relay.status_applied.is_connected(_on_status):
			_relay.status_applied.disconnect(_on_status)


func _on_hit(_target: Node, _amount: float, _damage_type: String, _kind: StringName, origin: String, position: Vector3) -> void:
	_remember(origin, position)


func _on_status(_target: Node, _status_id: String, _stacks: int, _source: Node, origin: String, position: Vector3) -> void:
	_remember(origin, position)


func _remember(origin: String, position: Vector3) -> void:
	if origin.begins_with(RelicManager.ORIGIN_PREFIX):
		_spots[origin.substr(RelicManager.ORIGIN_PREFIX.length())] = {"pos": position, "frame": Engine.get_process_frames()}


## Where a trigger of `relic_id` shows: the last spot its effects landed in the last few frames, else the player's feet, else the origin.
func spot_for(relic_id: String) -> Vector3:
	var known: Variant = _spots.get(relic_id)
	if known is Dictionary and Engine.get_process_frames() - int((known as Dictionary)["frame"]) <= 3:
		return (known as Dictionary)["pos"]
	var player: Node3D = _player_provider.call() as Node3D if _player_provider.is_valid() else null
	return player.global_position if player != null and is_instance_valid(player) else Vector3.ZERO


## A relic fired (RelicRow forwards its trigger signal here).
func on_trigger(relic_id: String) -> void:
	if _cfg.is_empty() or not bool(_cfg.get("relic_cue_enabled", true)):
		return
	var entry: Dictionary = RelicRow.entry_for(relic_id)
	RelicCues.add(_cues, relic_id, String(entry["name"]), spot_for(relic_id), entry["color"], float(_cfg.get("relic_cue_merge_window", 0.6)), float(_cfg.get("relic_cue_merge_radius", 2.5)), int(_cfg.get("relic_cue_max", 6)))
	set_process(true)
	queue_redraw()


func cues() -> Array[Dictionary]:
	return _cues


func _process(delta: float) -> void:
	_cues = RelicCues.step(_cues, delta, float(_cfg.get("relic_cue_life", 1.5)))
	if _cues.is_empty():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _cues.is_empty():
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var font: Font = get_theme_default_font()
	var px: int = maxi(roundi(float(_cfg.get("relic_cue_font_size", 16)) * _scale), int(_cfg.get("relic_cue_min_font_px", 14)))
	var life: float = float(_cfg.get("relic_cue_life", 1.5))
	var fade: float = float(_cfg.get("relic_cue_fade", 0.4))
	var ring_max: float = float(_cfg.get("relic_cue_ring_radius", 36)) * _scale
	var rise: float = float(_cfg.get("relic_cue_rise", 28)) * _scale
	var lit := Color.html(String(_cfg.get("relic_flash_color", "#fff3c4")))
	var back := Color.html(String(_cfg.get("relic_chip_color", "#1a1218")))
	var rects: Array[Rect2] = []
	var anchors: Array[Vector2] = []
	var shown: Array[Dictionary] = []
	for cue: Dictionary in _cues:
		var world: Vector3 = cue["world"]
		if camera.is_position_behind(world):
			continue
		var at: Vector2 = camera.unproject_position(world)
		var text: String = RelicCues.label(cue)
		var size_text: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px)
		var lift: float = rise * clampf(float(cue["age"]) / life, 0.0, 1.0)
		var plate := Rect2(Vector2(at.x - size_text.x * 0.5 - 6.0 * _scale, at.y - ring_max - size_text.y - lift - 4.0 * _scale), size_text + Vector2(12.0, 6.0) * _scale)
		rects.append(plate)
		anchors.append(at)
		shown.append(cue)
	var placed: Array[Rect2] = RelicCues.stack(rects, 4.0 * _scale)
	for i in range(shown.size()):
		var cue: Dictionary = shown[i]
		var ring: Dictionary = RelicCues.ring_state(float(cue["age"]), float(_cfg.get("relic_cue_ring_time", 0.45)))
		var color: Color = cue["color"]
		if float(ring["alpha"]) > 0.0:
			draw_arc(anchors[i], ring_max * float(ring["radius"]), 0.0, TAU, 32, Color(color.lightened(0.3), float(ring["alpha"])), maxf(3.0 * _scale, 2.0), true)
		var alpha: float = RelicCues.label_alpha(float(cue["age"]), life, fade)
		var plate: Rect2 = placed[i]
		draw_rect(plate, Color(back, 0.88 * alpha))
		draw_rect(plate, Color(color.lightened(0.2), alpha), false, maxf(2.0 * _scale, 1.5))
		var text: String = RelicCues.label(cue)
		var base := Vector2(plate.position.x + 6.0 * _scale, plate.position.y + (plate.size.y + font.get_ascent(px) - font.get_descent(px)) * 0.5)
		draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, Color(lit, alpha))
