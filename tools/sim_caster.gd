extends Node3D
## The bot-sim's stand-in for a player (plan mode only): a Node3D that carries `stat_modifiers`, so buffs and primes
## apply, and a `start_forced_move` that only counts the dash (nothing moves). Without these a bare Node3D caster
## ignores buffs and dashes, and a plan policy would be steering cards that do nothing.

var stat_modifiers := StatModifiers.new()
var dashes: int = 0


func start_forced_move(_direction: Vector3, _speed: float, _duration: float, _invulnerable: bool = false, _look: Dictionary = {}, _path_hit: Dictionary = {}, _pass_through: bool = false) -> void:
	dashes += 1
