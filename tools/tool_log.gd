class_name ToolLog
extends RefCounted
## TL3a: the engine-log redirect for child Godot processes that tests (and tools) spawn, the GDScript twin of tools/sim_log.ps1.
## `--log-file` sends the child's log to <repo>/logs/sim/<name>.log (gitignored), so it adds nothing to user://logs.

static func args(name: String) -> Array[String]:
	var dir: String = ProjectSettings.globalize_path("res://").path_join("logs/sim")
	DirAccess.make_dir_recursive_absolute(dir)
	return ["--log-file", dir.path_join("child-%s.log" % name)]
