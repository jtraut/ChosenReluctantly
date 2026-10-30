extends Node
## Autoload. Central hook for combat feel: hit-stop, screen shake, and
## damage numbers, so every place that reacts to a hit (Player, Enemy,
## TrainingDummy) calls one thing instead of re-implementing feel per script.

const DAMAGE_NUMBER_SCENE_PATH := "res://scenes/effects/DamageNumber.tscn"
const HEAVY_HIT_THRESHOLD := 10.0
## The merge type of heal numbers (not a damage type: its colour is passed in).
const HEAL_TYPE := "heal"

var _hitstop_resume_msec: int = -1
## Sims set this false: hit-stop and slow-mo then never touch Engine.time_scale, because their end is
## decided by the wall clock (Time.get_ticks_msec) and so would make a seeded run differ between reruns.
var hit_stop_enabled: bool = true
## Pause support (freeze_time / thaw_time): while frozen, time runs at 1.0 for the pause
## screen and the unfinished part of a hit-stop or slow-mo is remembered, not lost.
var _frozen: bool = false
var _frozen_remaining_msec: int = 0
var _frozen_scale: float = 1.0
var _camera_rig: CameraRig = null
## Popups requested so far and the last one's text (tests; no scene needed).
var popup_count: int = 0
var last_popup_text: String = ""
## Live damage numbers, oldest first (merge and cap bookkeeping; cleared on reset).
var _live_numbers: Array[DamageNumber] = []


func _process(_delta: float) -> void:
	if _hitstop_resume_msec >= 0 and Time.get_ticks_msec() >= _hitstop_resume_msec:
		Engine.time_scale = 1.0
		_hitstop_resume_msec = -1


## Autoloads outlive scene reloads: clear timing state and the (soon freed)
## camera rig and put time back to normal. Call before changing scenes.
func reset() -> void:
	_hitstop_resume_msec = -1
	_frozen = false
	_frozen_remaining_msec = 0
	_frozen_scale = 1.0
	_camera_rig = null
	_live_numbers = []
	Engine.time_scale = 1.0


## Slow-motion beat. Same wall-clock mechanism as hit_stop, so it ends on time
## despite the reduced time scale.
func slow_mo(duration_sec: float, time_scale: float) -> void:
	hit_stop(duration_sec, time_scale)


## Pausing: puts Engine.time_scale back to 1.0 (so a pause screen is not in slow-mo) and
## remembers how much of the current hit-stop or slow-mo was left, and at what scale.
## Idempotent. GamePause calls this; thaw_time() undoes it.
func freeze_time() -> void:
	if _frozen:
		return
	_frozen = true
	_frozen_remaining_msec = 0
	if _hitstop_resume_msec >= 0:
		_frozen_remaining_msec = maxi(_hitstop_resume_msec - Time.get_ticks_msec(), 0)
		_frozen_scale = Engine.time_scale
	_hitstop_resume_msec = -1
	Engine.time_scale = 1.0


## Resuming: the unfinished hit-stop or slow-mo continues for exactly the time it had
## left when time was frozen, at the scale it had. Idempotent.
func thaw_time() -> void:
	if not _frozen:
		return
	_frozen = false
	if _frozen_remaining_msec > 0:
		_hitstop_resume_msec = Time.get_ticks_msec() + _frozen_remaining_msec
		Engine.time_scale = _frozen_scale
	_frozen_remaining_msec = 0


func is_time_frozen() -> bool:
	return _frozen


func register_camera_rig(rig: CameraRig) -> void:
	_camera_rig = rig


## A longer hit-stop always wins over a shorter one already running; it
## never "resets" a longer one that's still counting down.
func hit_stop(duration_sec: float, time_scale: float = 0.05) -> void:
	if _frozen or not hit_stop_enabled:
		return  # Nothing hits while paused; never slow the pause screen.
	var resume_at := Time.get_ticks_msec() + int(duration_sec * 1000.0)
	if resume_at > _hitstop_resume_msec:
		_hitstop_resume_msec = resume_at
		Engine.time_scale = time_scale


func screen_shake(strength: float, duration: float) -> void:
	if is_instance_valid(_camera_rig):
		_camera_rig.shake(strength, duration)


## The one call combat code makes on a hit: shows the number, and adds
## hit-stop/shake if the hit was "heavy" (per HEAVY_HIT_THRESHOLD).
## `kind` (Health.KIND_*): only a direct "hit" gets hit-stop and shake. Follow-up hits of a
## multi-hit ("echo") and status ticks ("dot") show the number only, so a flurry or a
## Bleed cannot chain stutters.
## `channel`/`reduction` (Health.last_channel / last_reduction) pick the armor or resisted number style.
func on_hit_landed(world_pos: Vector3, amount: float, damage_type: String, kind: StringName = Health.KIND_HIT, channel: StringName = Health.CHANNEL_NONE, reduction: float = 0.0) -> void:
	spawn_damage_number(world_pos, amount, damage_type, null, "", channel, reduction)
	if kind != Health.KIND_HIT:
		return
	if amount >= HEAVY_HIT_THRESHOLD:
		hit_stop(0.06, 0.04)
		screen_shake(0.25, 0.18)
	else:
		hit_stop(0.03, 0.2)


## A small floating word at `world_pos` (see UiConfig.popups). `height` is above the point.
func spawn_popup(world_pos: Vector3, words: String, color: Color, text_scale: float, height: float) -> void:
	popup_count += 1
	last_popup_text = words
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or WorldRef.get_world(tree) == null:
		return
	var scene: PackedScene = load(DAMAGE_NUMBER_SCENE_PATH)
	var instance: DamageNumber = scene.instantiate()
	instance.configure(UiConfig.damage_numbers())
	WorldRef.get_world(tree).add_child(instance)
	instance.global_position = world_pos + Vector3(0.0, height, 0.0)
	instance.show_text(words, color, text_scale)


## Shows a damage number, or merges the hit into a young number of the same type right
## next to it (so 12 enemies hit in one swing do not stack a pile of digits), and never
## keeps more than `max_alive` numbers.
## A heal number: "+N" in the heal colour, kept apart from damage numbers (its own merge type "heal"), so a Flurry's
## leech heals fold into one number instead of stacking.
func spawn_heal_number(world_pos: Vector3, amount: float) -> void:
	spawn_damage_number(world_pos, amount, HEAL_TYPE, VfxConfig.heal_color().lerp(Color.WHITE, 0.25), "+")


func spawn_damage_number(world_pos: Vector3, amount: float, damage_type: String, color_override: Variant = null, prefix: String = "", channel: StringName = Health.CHANNEL_NONE, reduction: float = 0.0) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or WorldRef.get_world(tree) == null:
		return
	var cfg: Dictionary = UiConfig.damage_numbers()
	var spot: Vector3 = world_pos + Vector3(0.0, float(cfg["spawn_height"]), 0.0)
	var is_big: bool = amount >= HEAVY_HIT_THRESHOLD
	var style: StringName = DamageNumber.style_for(channel, reduction, cfg)
	_prune_numbers()
	var entries: Array = []
	for live: DamageNumber in _live_numbers:
		entries.append({"pos": live.global_position, "type": live.merge_key(), "idle": live.idle_time()})
	var merge_at: int = DamageNumber.find_merge_index(entries, spot, damage_type + "|" + String(style), float(cfg["merge_radius"]), float(cfg["merge_window"]))
	if merge_at >= 0:
		var merged: DamageNumber = _live_numbers[merge_at]
		merged.merge_hit(amount, is_big)
		# A merged number is the freshest news on screen: send it to the back of the eviction order so
		# a killing blow that just landed in it is never the first one freed at the cap (S5-5).
		_live_numbers.remove_at(merge_at)
		_live_numbers.append(merged)
		return
	for _i in range(DamageNumber.evict_count(_live_numbers.size(), int(cfg["max_alive"]))):
		_live_numbers.pop_front().queue_free()
	var scene: PackedScene = load(DAMAGE_NUMBER_SCENE_PATH)
	var instance: DamageNumber = scene.instantiate()
	instance.configure(cfg)
	WorldRef.get_world(tree).add_child(instance)
	instance.global_position = spot
	var color: Color = color_override if color_override is Color else DamageNumber.styled_color(style, damage_type, cfg)
	instance.show_amount(amount, damage_type, color, is_big, prefix, style, DamageNumber.brackets_for(style, cfg))
	_live_numbers.append(instance)


func _prune_numbers() -> void:
	var kept: Array[DamageNumber] = []
	for live: DamageNumber in _live_numbers:
		if is_instance_valid(live) and not live.is_queued_for_deletion():
			kept.append(live)
	_live_numbers = kept
