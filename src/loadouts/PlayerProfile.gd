class_name PlayerProfile
extends RefCounted
## The small persisted profile (3d, acceptance 1): `user://profile.json` = {version, runs_finished}. A finished run counts whether it was won or lost.
## Run 1 (runs_finished 0) starts straight away with the preset; from run 2 the start screen shows.
##
## The path is injectable (`PlayerProfile.new(path)`), so tests never touch the real user folder. A missing file reads as 0 runs. A bad or
## outdated file reads as 0 runs too, never crashes, and sets `problem`; the next write keeps the bad file as `<path>.bak` first.
## Sitting C decides who may call `record_run_finished` (scenarios, sims and debug launches never do).

const DEFAULT_PATH := "user://profile.json"
const VERSION := 1

var path: String
## Whole number of finished runs.
var runs_finished: int = 0
## "" when the file was fine or absent; otherwise why it was ignored.
var problem: String = ""
## True after `fake_runs_finished`: the count is in memory only and nothing is ever written (the `--runs-finished=N` debug flag).
var read_only: bool = false

var _backed_up: bool = false


func _init(file_path: String = DEFAULT_PATH) -> void:
	path = file_path


## (Re)reads the file. Never crashes: any problem leaves 0 runs and sets `problem`.
func load_file() -> void:
	runs_finished = 0
	problem = ""
	_backed_up = false
	var read: Dictionary = UserJson.read(path)
	if not bool(read["ok"]):
		problem = "profile ignored: " + String(read["problem"])
		return
	if not bool(read["exists"]):
		return
	var data: Dictionary = read["data"]
	problem = problems_of(data)
	if problem.is_empty():
		runs_finished = int(data["runs_finished"])
	else:
		problem = "profile ignored: " + problem


## What is wrong with a parsed profile; "" when fine.
static func problems_of(data: Dictionary) -> String:
	for key: Variant in data.keys():
		if not ["version", "runs_finished"].has(String(key)):
			return "unknown key '%s'" % str(key)
	if not UserJson.is_whole(data.get("version")):
		return "version must be a whole number"
	if int(data["version"]) != VERSION:
		return "version %d is not the current %d" % [int(data["version"]), VERSION]
	if not UserJson.is_whole(data.get("runs_finished")) or int(data["runs_finished"]) < 0:
		return "runs_finished must be a whole number from 0"
	return ""


func to_dict() -> Dictionary:
	return {"version": VERSION, "runs_finished": runs_finished}


## True until the first run has finished: the preset, no start screen.
func is_first_run() -> bool:
	return runs_finished == 0


## Counts one finished run (won or lost) and writes the file. False when it could not be written (the count still moves in memory).
func record_run_finished() -> bool:
	runs_finished += 1
	return write()


## Debug hook (`--runs-finished=N`): sets the count in memory and turns writing off for this instance.
func fake_runs_finished(count: int) -> void:
	runs_finished = maxi(count, 0)
	read_only = true


func write() -> bool:
	if read_only:
		return false
	if not problem.is_empty() and not _backed_up:
		_backed_up = true
		UserJson.backup(path)
	var ok: bool = UserJson.write(path, to_dict())
	if ok:
		problem = ""
	return ok
