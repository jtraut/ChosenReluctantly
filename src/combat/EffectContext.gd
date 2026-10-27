class_name EffectContext
extends RefCounted
## Everything an effect template needs to run a card's effect, plus the
## running result (`last_hits`) later effects in the same card can target -
## e.g. a "cone" effect that damages enemies, followed by an "apply_status"
## effect that burns whatever the cone just hit.

var caster: Node3D
var spawn_parent: Node
var caster_team: String
var last_hits: Array[Hurtbox] = []


func _init(p_caster: Node3D, p_spawn_parent: Node, p_caster_team: String = "neutral") -> void:
	caster = p_caster
	spawn_parent = p_spawn_parent
	caster_team = p_caster_team


## Only called by effects that actually need physics queries (cone/aoe), so a
## caster that isn't in the tree yet (as in a unit test for heal/buff/
## apply_status) never trips a "not inside world" engine error.
func world() -> World3D:
	return caster.get_world_3d()
