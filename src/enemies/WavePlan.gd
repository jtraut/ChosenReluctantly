class_name WavePlan
extends RefCounted
## Runtime state of the wave table (Slice 5a), with no nodes in it so it can be unit
## tested. Each step() call gets the elapsed time and how many enemies are alive and
## returns the enemy ids to spawn right now (at most one per call, spaced by
## spawn_gap). It never returns a spawn that would push `alive` over max_alive:
## blocked spawns stay queued and are not dropped.
##
## Staging: the first stage opens after first_wave_delay + its delay. A stage's
## enemies are queued all at once; the next stage's clock starts when that queue has
## fully spawned, and the stage opens when its delay has passed AND the alive count
## is at or below its until_alive_at_most (default: no gate). After the last stage the
## table loops back to loop_from_stage.

var config: Dictionary
var _rng: RandomNumberGenerator
var _stage_index: int = 0
var _stage_wait: float = 0.0
var _gap_left: float = 0.0
var _pending: Array[String] = []
var _started_stages: int = 0


func _init(wave_config: Dictionary, rng: RandomNumberGenerator = null) -> void:
	config = wave_config
	_rng = rng if rng != null else RandomNumberGenerator.new()
	_stage_wait = float(config["first_wave_delay"]) + float(_stage(0)["delay"])


func max_alive() -> int:
	return int(config["max_alive"])


## Enemies still queued behind the cap or the spawn gap.
func pending_count() -> int:
	return _pending.size()


## How many stages have been opened so far (looping stages count again).
func stages_started() -> int:
	return _started_stages


## Index of the stage that will open next (or is being spawned right now).
func next_stage_index() -> int:
	return _stage_index


## Seconds until the next stage's clock allows it to open.
func stage_wait_left() -> float:
	return _stage_wait


## The enemy id to spawn right now, or "" for none. At most one per call, so the per-frame
## path allocates no array (S5-6). EnemySpawner uses this.
func step_one(delta: float, alive: int) -> String:
	_gap_left = maxf(_gap_left - delta, 0.0)
	if _pending.is_empty():
		_stage_wait = maxf(_stage_wait - delta, 0.0)
		var stage: Dictionary = _stage(_stage_index)
		if _stage_wait <= 0.0 and alive <= int(stage.get("until_alive_at_most", max_alive())):
			_open_stage(stage)
	if _pending.is_empty() or _gap_left > 0.0 or alive >= max_alive():
		return ""
	var enemy_id: String = _pending.pop_front()
	_gap_left = float(config["spawn_gap"])
	if _pending.is_empty():
		_stage_index = _next_index(_stage_index)
		_stage_wait = float(_stage(_stage_index)["delay"])
	return enemy_id


## Same as step_one, as a list (zero or one ids). Allocates; for tests and tools, not per-frame code.
func step(delta: float, alive: int) -> Array[String]:
	var out: Array[String] = []
	var enemy_id: String = step_one(delta, alive)
	if enemy_id != "":
		out.append(enemy_id)
	return out


func _open_stage(stage: Dictionary) -> void:
	_started_stages += 1
	for entry: Dictionary in (stage["spawns"] as Array):
		for i in range(int(entry["count"])):
			_pending.append(String(entry["enemy"]))
	# Shuffle so a stage is not "all chasers, then all shooters" (seeded by the caller's rng).
	for i in range(_pending.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap: String = _pending[i]
		_pending[i] = _pending[j]
		_pending[j] = swap


func _stage(index: int) -> Dictionary:
	return (config["stages"] as Array)[index]


func _next_index(index: int) -> int:
	var next: int = index + 1
	if next >= (config["stages"] as Array).size():
		return int(config["loop_from_stage"])
	return next
