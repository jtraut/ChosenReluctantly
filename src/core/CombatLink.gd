class_name CombatLink
extends RefCounted
## Finds the CombatEvents autoload without naming it as a global identifier. The bare name does not compile in a
## script that the headless bot-sim (a `-s` SceneTree script) loads at start-up, before autoloads are registered;
## this lookup happens at run time instead. Null when there is no such node; callers then skip the history and relay.


static func events() -> CombatEventsRelay:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("CombatEvents") as CombatEventsRelay
	return null
