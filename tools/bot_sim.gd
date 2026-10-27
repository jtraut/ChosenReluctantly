extends SceneTree
## Headless bot-sim stub (per the Milestone 2 kickoff - this grows into a
## real balance tool in a later milestone). Drives a bot through N "rooms",
## each a fresh CardSlotController loaded with the real starter card set,
## randomly using/swapping slots, and checks for NaN creeping into cooldowns
## or health. Run via tools/run_bot_sim.ps1.
##
## This is deliberately not a combat balance simulator yet: cards whose
## effects need targets (cone/aoe/projectile) just find nothing to hit in an
## empty room, which is fine - the thing being stressed here is the card/
## deck/cooldown system itself, not damage numbers.

const DEFAULT_ROOMS := 20
const TICKS_PER_ROOM := 300
const DT := 1.0 / 60.0
const ACT_CHANCE := 0.1
const SWAP_CHANCE := 0.2

var _rng := RandomNumberGenerator.new()
var _issues: Array[String] = []


func _initialize() -> void:
	var rooms := _rooms_arg()
	print("Headless bot-sim: %d rooms x %d ticks" % [rooms, TICKS_PER_ROOM])
	for room_index in range(rooms):
		await _run_room(room_index)
	if _issues.is_empty():
		print("Bot-sim OK: no NaN detected across %d rooms (%d ticks each)." % [rooms, TICKS_PER_ROOM])
		quit(0)
	else:
		print("Bot-sim FAILED - %d issue(s):" % _issues.size())
		for issue: String in _issues:
			print(" - %s" % issue)
		quit(1)


func _rooms_arg() -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--rooms="):
			return int(arg.substr("--rooms=".length()))
	return DEFAULT_ROOMS


func _run_room(room_index: int) -> void:
	var caster := Node3D.new()
	root.add_child(caster)
	# A freshly-added node isn't considered "inside tree" (global_transform/
	# get_world_3d unavailable) until the engine ticks at least once - this
	# only matters at all because bot_sim runs synchronously inside
	# _initialize(), before the main loop has started ticking.
	await process_frame

	var health := Health.new()
	health.name = "Health"
	health.max_health = 30.0
	caster.add_child(health)

	var owned_pools: Array[String] = ["rogue", "fire", "neutral"]
	var controller := CardSlotController.new(caster, caster, "player", StatModifiers.new(), owned_pools)

	for tick in range(TICKS_PER_ROOM):
		controller.advance(DT)
		if _rng.randf() < ACT_CHANCE:
			_act_randomly(controller)
		_check_for_nan(controller, room_index, tick)

	caster.queue_free()


func _act_randomly(controller: CardSlotController) -> void:
	var slot_type := CardSlotController.slot_type_at_index(_rng.randi_range(0, CardSlotController.SLOT_TYPE_ORDER.size() - 1))
	if _rng.randf() < SWAP_CHANCE:
		controller.try_swap(slot_type)
	else:
		controller.try_use(slot_type)


func _check_for_nan(controller: CardSlotController, room_index: int, tick: int) -> void:
	for slot_type: String in CardSlotController.SLOT_TYPE_ORDER:
		var slot: CardSlot = controller.get_slot(slot_type)
		if slot == null:
			continue
		if is_nan(slot.cooldown_remaining) or is_nan(slot.last_cooldown_duration):
			_issues.append("room %d tick %d: NaN cooldown in slot '%s'" % [room_index, tick, slot_type])
	var health: Health = controller.caster.get_node("Health")
	if is_nan(health.current_health):
		_issues.append("room %d tick %d: NaN health" % [room_index, tick])
