extends Label3D
class_name DamageNumber
## Floating combat text: rises and fades, then frees itself. Size, outline, colour,
## timing and the anti-spam numbers come from data/ui.json "damage_numbers"
## (UiConfig). A hit right next to a young number of the same type merges into it.

## A merged number's clock is pulled back to at most this fraction of its life.
const MERGE_REFRESH := 0.3

## Every configured number and word popup, for the stack labels that dim under them (a static list: no per-frame group query). Entries are erased on exit.
static var live: Array[DamageNumber] = []

var damage_type: String = ""
## "" (plain), STYLE_ARMOR or STYLE_RESIST: part of the merge key, so a muted armored hit never folds into a plain one.
var style: StringName = &""
var _elapsed: float = 0.0
var _duration: float = 0.8
var _rise: float = 1.2
## Extra screen pixels pushed down when the boss-bar clamp moves this number (a "Bleed detonated" word, so it lands below the emphasised number instead of on it).
var clamp_extra_px: float = 0.0
var _start_pos: Vector3
var _total: float = 0.0
var _base_scale: float = 1.0
var _big_scale: float = 1.35
var _muted_scale: float = 0.85
var _is_word: bool = false
## Shown before the digits ("+" on a heal number: a cue that does not rely on colour).
var _prefix: String = ""
## Shown after the digits (the closing bracket of an armor or resist number).
var _suffix: String = ""
var _emphasized: bool = false


const STYLE_NONE := &""
const STYLE_ARMOR := &"armor"
const STYLE_RESIST := &"resist"


# ---- Pure rules (unit-tested) ----

## The text for a (possibly merged) amount: whole numbers, but a real hit under 1 never reads "0": it shows one
## decimal (0.5), with a floor of 0.1. A total that would round to "1.0" shows "1".
static func display_amount(total: float) -> String:
	if total >= 1.0 or total <= 0.0:
		return str(roundi(total))
	var tenths: float = maxf(snappedf(total, 0.1), 0.1)
	return "1" if tenths >= 1.0 else "%.1f" % tenths


## Which style a hit gets, from the Health channel and the fraction removed: armor and resistance only when the
## reduction is noticeable (`armor_min_reduction` / `resist_min_reduction`, data/ui.json).
static func style_for(channel: StringName, reduction: float, cfg: Dictionary) -> StringName:
	if channel == Health.CHANNEL_ARMOR and reduction >= float(cfg["armor_min_reduction"]):
		return STYLE_ARMOR
	if channel == Health.CHANNEL_RESISTANCE and reduction >= float(cfg["resist_min_reduction"]):
		return STYLE_RESIST
	return STYLE_NONE


## The brackets of a style: armor "[12]" (a plate edge), resisted "<12>" (a point). Empty for a plain number.
static func brackets_for(style_id: StringName, cfg: Dictionary) -> Dictionary:
	match style_id:
		STYLE_ARMOR:
			return {"open": String(cfg["armor_open"]), "close": String(cfg["armor_close"])}
		STYLE_RESIST:
			return {"open": String(cfg["resist_open"]), "close": String(cfg["resist_close"])}
	return {"open": "", "close": ""}


## UX1a: the sideways shift (camera-plane metres) of a styled number: armor to the left of the hit, resisted to the right, plain on it.
static func style_shift(style_id: StringName, spread: float) -> float:
	match style_id:
		STYLE_ARMOR:
			return -spread
		STYLE_RESIST:
			return spread
	return 0.0


## The colour of a styled number: armor is a flat muted grey whatever the type; a resisted number keeps its
## element colour, pulled toward grey by `resist_mute`. Plain numbers use `color_for`.
static func styled_color(style_id: StringName, type: String, cfg: Dictionary) -> Color:
	var plain: Color = color_for(type, float(cfg["color_lighten"]))
	match style_id:
		STYLE_ARMOR:
			return Color.html(String(cfg["armor_color"]))
		STYLE_RESIST:
			return plain.lerp(Color.html(String(cfg["armor_color"])), clampf(float(cfg["resist_mute"]), 0.0, 1.0))
	return plain


## The key a merge compares: type plus style.
func merge_key() -> String:
	return key_for(damage_type, style)


## UX1b (pure): the merge key of a hit. An armored number is one flat grey whatever the damage type, so every armored hit on the same spot folds into one
## "[Arm n]": a Bleed tick and a hit used to print two armored numbers on top of each other (different types, so they never merged).
static func key_for(type: String, style_id: StringName) -> String:
	return ("*" if style_id == STYLE_ARMOR else type) + "|" + String(style_id)


## Index of the entry a new hit should merge into, or -1. An entry is
## {"pos": Vector3, "type": String, "idle": float} (seconds since it was last hit). Only the
## same damage type, on the ground plane within `radius`, idle under `window`; the nearest wins.
static func find_merge_index(entries: Array, pos: Vector3, type: String, radius: float, window: float) -> int:
	var best: int = -1
	var best_dist: float = radius
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		if String(entry["type"]) != type or float(entry["idle"]) >= window:
			continue
		var at: Vector3 = entry["pos"]
		var dist: float = Vector2(at.x - pos.x, at.z - pos.z).length()
		if dist <= best_dist:
			best = i
			best_dist = dist
	return best


## How many of the oldest numbers must go so that one more fits under `cap`.
static func evict_count(live: int, cap: int) -> int:
	return maxi(live - maxi(cap, 1) + 1, 0)


## Pure: the screen y a number is drawn at once the boss bar block (down to `limit`) is kept clear: a number that would sit
## inside the block (y < limit) is pushed just below it, so it never hides behind the bar or its text. limit <= 0 = no bar.
static func clamp_below_bar(screen_y: float, limit: float, gap: float) -> float:
	if limit <= 0.0:
		return screen_y
	return maxf(screen_y, limit + gap)


## The colour of a number: the damage type's element colour, lightened toward white so the
## flat outline does the contrast work on any floor.
static func color_for(type: String, lighten: float) -> Color:
	return ElementVisuals.color_for_damage_type(type).lerp(Color.WHITE, clampf(lighten, 0.0, 1.0))


# ---- Lifecycle ----

## Applies the shared style from data. Call right after instantiating.
func configure(cfg: Dictionary) -> void:
	if not live.has(self):
		live.append(self)  # MB1 ux: the status stack labels look for numbers that cover them
	font_size = int(cfg["font_size"])
	pixel_size = float(cfg["pixel_size"])
	outline_size = int(cfg["outline_size"])
	outline_modulate = Color.html(String(cfg["outline_color"]))
	render_priority = int(cfg["render_priority"])
	outline_render_priority = render_priority - 1
	_duration = float(cfg["duration"])
	_rise = float(cfg["rise_distance"])
	_big_scale = float(cfg["big_scale"])
	_muted_scale = float(cfg["muted_scale"])


## Called after global_position is already set to the spawn point - this is
## also where _start_pos is captured, not _ready(), since _ready() runs
## during add_child(), before the caller has had a chance to position us.
func show_amount(amount: float, type: String, color: Color, is_big: bool, prefix: String = "", style_id: StringName = STYLE_NONE, brackets: Dictionary = {}) -> void:
	damage_type = type
	style = style_id
	_prefix = prefix + String(brackets.get("open", ""))
	_suffix = String(brackets.get("close", ""))
	_total = amount
	text = _prefix + display_amount(_total) + _suffix
	modulate = color
	_base_scale = _big_scale if is_big else 1.0
	if style != STYLE_NONE:
		_base_scale *= _muted_scale  # a reduced hit reads smaller as well as greyer
	scale = Vector3.ONE * _base_scale
	_start_pos = global_position if is_inside_tree() else position  # a number built outside the tree (a test) has no global transform yet


## Adds another hit of the same type into this number and keeps it on screen a little longer.
func merge_hit(amount: float, is_big: bool) -> void:
	_total += amount
	text = _prefix + display_amount(_total) + _suffix
	_elapsed = minf(_elapsed, _duration * MERGE_REFRESH)
	if is_big and not _emphasized:
		_base_scale = _big_scale * (_muted_scale if style != STYLE_NONE else 1.0)
		scale = Vector3.ONE * _base_scale


## A status detonation: this number grows to `factor` times its normal size and ends with `mark` ("!"), a shape cue
## that does not rely on colour. Later merges keep the mark.
func emphasize(factor: float, mark: String) -> void:
	_suffix += mark
	_base_scale = maxf(_base_scale, factor)
	_emphasized = true
	scale = Vector3.ONE * _base_scale
	text = _prefix + display_amount(_total) + _suffix
	_elapsed = minf(_elapsed, _duration * MERGE_REFRESH)


## True once `emphasize` ran.
func is_emphasized() -> bool:
	return _emphasized


## UX1b: where this number was spawned (before the rise and the boss-bar clamp move it). A new hit merges against this, not against `global_position`:
## the clamp pushes a number down the screen, which moves it away from its enemy on the ground, so the next hit found nothing to merge into and printed
## a second "[Arm 0.5]" on top of the first.
func merge_anchor() -> Vector3:
	return _start_pos


## Seconds since this number was spawned or last merged into.
func idle_time() -> float:
	return _elapsed


## A word instead of a damage number (the IMMUNE popup): same style, one priority above the numbers
## so it is never covered by one, and its own scale.
func show_text(words: String, color: Color, text_scale: float) -> void:
	_is_word = true
	text = words
	modulate = color
	scale = Vector3.ONE * text_scale
	render_priority += 1
	outline_render_priority = render_priority - 1
	_start_pos = global_position if is_inside_tree() else position  # a number built outside the tree (a test) has no global transform yet


func is_word() -> bool:
	return _is_word


func _exit_tree() -> void:
	live.erase(self)


func _process(delta: float) -> void:
	_elapsed += delta
	var t := _elapsed / _duration
	if t >= 1.0:
		queue_free()
		return
	global_position = _start_pos + Vector3(0.0, _rise * t, 0.0)
	_keep_clear_of_boss_bar()
	modulate.a = 1.0 - t * t  # holds, then drops away: easier to read than a linear fade


## UX1b (pure): how far (pixels) a number pinned under the boss bar has drifted down by `life_fraction` (0 to 1) of its life; `drift` is the full-life drift at 720p.
static func clamped_drift_px(life_fraction: float, drift: float, screen_scale: float) -> float:
	return clampf(life_fraction, 0.0, 1.0) * drift * screen_scale


## UX1b: half the on-screen height (pixels) of a Label3D line at `world_pos`: its text height in metres (`font_size` x `pixel_size` x `text_scale`) projected
## along the camera's up axis.
static func half_height_px(camera: Camera3D, world_pos: Vector3, font_px: int, pixel_m: float, text_scale: float) -> float:
	var half_m: float = float(font_px) * pixel_m * text_scale * 0.5
	var top: Vector3 = world_pos + camera.global_transform.basis.y * half_m
	return absf(camera.unproject_position(world_pos).y - camera.unproject_position(top).y)


## Keeps this number out of the boss bar block: same depth, screen position pushed to just under the bar. Numbers are 3D
## text, so a boss near the top of the screen would otherwise have its hits drawn behind the bar and its info text.
func _keep_clear_of_boss_bar() -> void:
	var tree := get_tree()
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if tree == null or camera == null:
		return
	var bar: BossHpBar = tree.get_first_node_in_group(BossHpBar.GROUP) as BossHpBar
	if bar == null:
		return
	var limit: float = bar.occupied_bottom()
	if limit <= 0.0 or camera.is_position_behind(global_position):
		return
	var screen: Vector2 = camera.unproject_position(global_position)
	# UX1b: the label is centred on its position, so the gap is kept from its top edge: the clamp adds half the text's height in pixels, and a number
	# never runs up into the attack banner row under the bar.
	var half_px: float = half_height_px(camera, global_position, font_size, pixel_size, scale.x)
	var wanted: float = clamp_below_bar(screen.y, limit, float(UiConfig.damage_numbers().get("boss_bar_gap", 6.0)) + half_px)
	if wanted <= screen.y:
		return
	wanted += clamp_extra_px
	# UX1b: the clamp pins every number of the boss to one screen row, which took away the rise that kept consecutive hits apart (the "[Arm 0.5]" printed over
	# an older "[Arm 0.5]"). A pinned number now drifts down the screen as it ages instead, so each hit sits a line under the one before.
	if not _is_word:
		wanted += clamped_drift_px(_elapsed / _duration, float(UiConfig.damage_numbers().get("boss_clamp_drift_px", 0.0)), get_viewport().get_visible_rect().size.y / 720.0)
	var depth: float = -(camera.global_transform.affine_inverse() * global_position).z
	global_position = camera.project_position(Vector2(screen.x, wanted), depth)
