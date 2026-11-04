class_name CombatLink
extends RefCounted
## Finds the CombatEvents autoload without naming it as a global identifier, so scripts that also load in a run
## without autoloads (the headless bot-sim is a `-s` SceneTree script) still compile. Null there; callers skip
## the history and the relay when it is null.


static func events() -> CombatEventsRelay:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("CombatEvents") as CombatEventsRelay
	return null
