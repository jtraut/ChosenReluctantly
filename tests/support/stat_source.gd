class_name StatSource
extends Node3D
## Test double for a status applier with a stat stack (the Player has one): `stat_modifiers` is what the status manager reads
## for status_max_stacks.<id>, status_tick_rate.<id> and status_damage_mult.<id>.

var stat_modifiers := StatModifiers.new()
