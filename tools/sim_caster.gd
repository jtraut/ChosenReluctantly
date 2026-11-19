extends Node3D
## The bot-sim's stand-in for a player (plan mode only): a Node3D that carries `stat_modifiers`, so buffs and primes
## apply, and a `start_forced_move` that only counts the dash (nothing moves). Without these a bare Node3D caster
## ignores buffs and dashes, and a plan policy would be steering cards that do nothing.
##
## BD3b-D1: it also carries a Hurtbox and a StatusEffectManager (named like the Player's, so `apply_status` with target "self"
## and CasterStats find them), so a self-applied status such as Charge exists in the sim. The loop runs no frames, so the
## manager's own _process never ticks: call `step(delta)` once per simulated tick (it also links the "Health" child when one is added after this node).

var stat_modifiers := StatModifiers.new()
var dashes: int = 0
var hurtbox: Hurtbox = null
var status_manager: StatusEffectManager = null


func _init() -> void:
	status_manager = StatusEffectManager.new()
	status_manager.name = "StatusEffectManager"
	add_child(status_manager)
	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.team = "player"
	hurtbox.status_manager = status_manager
	add_child(hurtbox)


func start_forced_move(_direction: Vector3, _speed: float, _duration: float, _invulnerable: bool = false, _look: Dictionary = {}, _path_hit: Dictionary = {}, _pass_through: bool = false, _origin: String = "") -> void:
	dashes += 1


## Advances the caster's statuses by `delta` seconds (the sim's tick), linking the Health child first when it has appeared.
func step(delta: float) -> void:
	if hurtbox.health == null and has_node("Health"):
		hurtbox.health = get_node("Health") as Health
		status_manager.health = hurtbox.health
	status_manager._process(delta)


## The live facts of the SlotSynergy view the bot sim cannot get from a real Player: the caster's self stacks, its HP fraction
## and the deck's card ids. Merge it into the view so Thesis scaling and `hp_below` / `deck_count_at_least` read live values.
func live_view_fields(controller: CardSlotController) -> Dictionary:
	var self_stacks: Dictionary = {}
	for status_id: Variant in status_manager.active_status_ids():
		self_stacks[String(status_id)] = status_manager.stacks_of(String(status_id))
	return {"self_stacks": self_stacks, "hp_fraction": CasterStats.hp_fraction(self), "deck_card_ids": controller.owned_card_ids()}
