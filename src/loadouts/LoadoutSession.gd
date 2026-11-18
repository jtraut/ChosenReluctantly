class_name LoadoutSession
extends RefCounted
## The one place the game gets the player's profile and loadouts from (3d sitting C). Static, like RunSave and CharacterPick: one holder per process.
##
## Isolation (the same bug class as DF1 A item 1): a launch that is headless, a `-s` script, or carries any `RunSave.DEBUG_FLAG_PREFIXES` flag (scenarios,
## sims, `--sim-*`, every debug arg) never reads or writes `user://profile.json` or `user://loadouts.json`: it gets in-memory ones. The only files such a
## launch may touch are the scratch files it names with `--profile-path=` and `--loadouts-path=`. The suite is headless, so it is gated too; a test that wants
## files sets `persist_override = true` plus a `user://tests/...` path, and calls `reset()` afterwards.
##
## What the rest of the game calls:
##   profile()                  the PlayerProfile (runs_finished, is_first_run)
##   store()                    the LoadoutStore (saved loadouts, flags, last used)
##   record_run_finished(state) counts a won or lost run once per RunState
##   start_screen_wanted(state) whether the run-2-and-later start screen should open for this fresh run
##   start_resolved(state)      marks this run's start choice as made (the screen, or a forced loadout, or a debug deck)

## Tests: true/false forces the "real game" part of the decision; null = decide from how the game was launched.
static var persist_override: Variant = null
## The file paths used when real files are allowed (tests point them at user://tests/...; `--profile-path=` and `--loadouts-path=` set them too).
static var profile_path: String = PlayerProfile.DEFAULT_PATH
static var loadouts_path: String = LoadoutStore.DEFAULT_PATH
## True when `--profile-path=` / `--loadouts-path=` named the file: it is used even in a gated launch.
static var profile_path_named: bool = false
static var loadouts_path_named: bool = false
## Set by a launch with debug flags (`apply_args`): no default files for the rest of the process.
static var suppressed: bool = false
## `--runs-finished=N` (-1 = not given).
static var faked_runs: int = -1
## `--loadout=<n>`: LoadoutArgs.NO_SLOT, LoadoutStore.PRESET or a 0-based slot. Sticky for the launch (Try again keeps it).
static var forced_slot: int = LoadoutArgs.NO_SLOT

static var _profile: PlayerProfile = null
static var _store: LoadoutStore = null
static var _counted: RunState = null
static var _resolved: RunState = null


## Reads the launch flags (the first scene of a launch). Returns the problems (the caller refuses the launch, exit 2).
static func apply_args(args: PackedStringArray) -> Array[String]:
	var resolved: Dictionary = LoadoutArgs.resolve(args, DisplayServer.get_name() == "headless", LoadoutArgs.is_script_launch(OS.get_cmdline_args()))
	var errors: Array[String] = []
	errors.assign(resolved["errors"])
	suppressed = RunSave.args_suppress(args)
	if not errors.is_empty():
		return errors
	_profile = null
	_store = null
	faked_runs = int(resolved["runs_finished"])
	forced_slot = int(resolved["slot"])
	profile_path_named = not String(resolved["profile_path"]).is_empty()
	loadouts_path_named = not String(resolved["loadouts_path"]).is_empty()
	if profile_path_named:
		profile_path = String(resolved["profile_path"])
	if loadouts_path_named:
		loadouts_path = String(resolved["loadouts_path"])
	return errors


## True when the default files may be read and written (a real windowed game with no debug flag), or a test forced it on.
static func default_files_allowed() -> bool:
	if persist_override != null:
		return bool(persist_override)
	if suppressed or DisplayServer.get_name() == "headless":
		return false
	return not LoadoutArgs.is_script_launch(OS.get_cmdline_args())


static func reset() -> void:
	persist_override = null
	profile_path = PlayerProfile.DEFAULT_PATH
	loadouts_path = LoadoutStore.DEFAULT_PATH
	profile_path_named = false
	loadouts_path_named = false
	suppressed = false
	faked_runs = -1
	forced_slot = LoadoutArgs.NO_SLOT
	_profile = null
	_store = null
	_counted = null
	_resolved = null


## The profile. In a gated launch: in memory (or the named scratch file), and with `--runs-finished=N` the count is faked and never written.
static func profile() -> PlayerProfile:
	if _profile == null:
		if profile_path_named or default_files_allowed():
			_profile = PlayerProfile.new(profile_path)
		else:
			_profile = PlayerProfile.in_memory()
		if faked_runs >= 0:
			_profile.fake_runs_finished(faked_runs)
	return _profile


## The saved loadouts. In a gated launch: in memory (or the named scratch file).
static func store() -> LoadoutStore:
	if _store == null:
		_store = LoadoutStore.new(loadouts_path) if (loadouts_path_named or default_files_allowed()) else LoadoutStore.in_memory()
	return _store


## Counts a finished run (won or lost), once per RunState: a second call for the same run (a double signal, a scene swap) does nothing. Returns true when it counted.
static func record_run_finished(state: RunState) -> bool:
	if state == null or state == _counted:
		return false
	_counted = state
	profile().record_run_finished()
	return true


# ---- the start screen ----

## True when the start screen should open for `state`: it is the very start of a fresh run (no room played, nothing chosen yet), it is not the first run, no loadout was
## forced (`--loadout`) and no debug deck was asked for, and the choice was not already made for this run.
static func start_screen_wanted(state: RunState) -> bool:
	if state == null or state == _resolved or not is_run_start(state):
		return false
	if forced_slot != LoadoutArgs.NO_SLOT or not RunSession.debug_deck.is_empty() or RunSession.full_deck:
		return false
	return not profile().is_first_run()


## The first moment of a run: act 1, no room played, no reward or choice open except a map run's first node pick.
static func is_run_start(state: RunState) -> bool:
	if state == null or state.is_over() or state.act > 1 or not state.history.is_empty():
		return false
	if not state.map.is_empty():
		return state.pending == RunState.PENDING_NODE and state.path.is_empty()
	return not state.has_pending()


## Marks this run's start choice as made, so a scene rebuilt for the same run does not ask again.
static func start_resolved(state: RunState) -> void:
	_resolved = state
