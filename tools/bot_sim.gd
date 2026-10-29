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
## Card shuffles, seeded per room so the whole sim repeats from --seed.
var _card_rng := RandomNumberGenerator.new()
var _issues: Array[String] = []
## Rolling hash of every card used, so two runs of one seed can be compared at a glance.
var _checksum: int = 0


func _initialize() -> void:
	var rooms := _rooms_arg()
	var seed_value := _seed_arg()
	print("Headless bot-sim: %d rooms x %d ticks, seed %d (rerun with --seed=%d to reproduce)" % [rooms, TICKS_PER_ROOM, seed_value, seed_value])
	for room_index in range(rooms):
		_rng.seed = seed_value + room_index
		_card_rng.seed = seed_value + 200000 + room_index
		await _run_room(room_index)
		_rng.seed = seed_value + 100000 + room_index
		_run_attack_room(room_index)
	if _issues.is_empty():
		print("Bot-sim OK: no NaN detected across %d rooms (%d ticks each)." % [rooms, TICKS_PER_ROOM])
		print("Bot-sim checksum: %d (same seed and rooms give the same checksum)" % _checksum)
		quit(0)
	else:
		print("Bot-sim FAILED - %d issue(s):" % _issues.size())
		for issue: String in _issues:
			print(" - %s" % issue)
		quit(1)


func _seed_arg() -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			return int(arg.substr("--seed=".length()))
	return 1


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
	var controller := CardSlotController.new(caster, caster, "player", StatModifiers.new(), owned_pools, _card_rng)
	controller.status_rng = RandomNumberGenerator.new()  # own stream, so the bot's choices stay as they were. Cards with a status chance (Fire Wall) roll on it; without one the zone refuses to apply
	controller.status_rng.seed = 7

	for tick in range(TICKS_PER_ROOM):
		controller.advance(DT)
		if _rng.randf() < ACT_CHANCE:
			_act_randomly(controller)
		_check_for_nan(controller, room_index, tick)

	caster.queue_free()


func _act_randomly(controller: CardSlotController) -> void:
	var slot_type := CardSlotController.slot_type_at_index(_rng.randi_range(0, CardSlotController.SLOT_TYPE_ORDER.size() - 1))
	if _rng.randf() < SWAP_CHANCE:
		if controller.try_swap(slot_type):
			_checksum = hash([_checksum, "swap", slot_type, controller.get_slot(slot_type).current_card_id])
	else:
		var used_before: String = controller.get_slot(slot_type).current_card_id
		if controller.try_use(slot_type):
			_checksum = hash([_checksum, slot_type, used_before])


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


## Attack rework (Slice 3b): random clicks, attack-speed modifiers, heavy class, random stuns
## and Burn on a target of random rank. Checks: no NaN or negative timers, the light click
## rate never above ratio x the auto rate, the heavy never faster than its cooldown, the
## wind-up slow always removed when idle and never a root, bosses never stunned, a stun
## never longer than base x rank, and no stuck state after cancel.
func _run_attack_room(room_index: int) -> void:
	var mods := StatModifiers.new()
	if _rng.randf() < 0.5:
		mods.add_modifier("attack_interval.light", "bot_haste", StatModifiers.MULTIPLICATIVE, -_rng.randf_range(0.0, 0.9))
	var heavy_class: String = ["rogue", "wizard"][_rng.randi_range(0, 1)]
	var light: Dictionary = AttackDatabase.get_attack("light")
	var controller := AttackController.new({&"light": light, &"heavy": AttackDatabase.get_heavy(heavy_class)}, mods)
	var fired: Dictionary = {&"light": 0, &"heavy": 0}
	controller.attack_fired.connect(func(attack_id: StringName) -> void: fired[attack_id] = int(fired[attack_id]) + 1)
	var health := Health.new()
	health.max_health = 1000000.0
	health.current_health = 1000000.0
	var manager := StatusEffectManager.new()
	manager.health = health
	var ranks: Array[String] = ["normal", "elite", "boss"]
	manager.rank = ranks[_rng.randi_range(0, 2)]
	var stun_def: Dictionary = StatusDatabase.get_status("stun")
	var burn_def: Dictionary = StatusDatabase.get_status("burn")
	var base_stun := float(stun_def["base_duration"])
	var rank_mult := float((stun_def["rank_multipliers"] as Dictionary)[manager.rank])
	var has_target := _rng.randf() < 0.5
	var target_check := func(_id: StringName) -> bool: return has_target
	var can_act := true
	var ticks := TICKS_PER_ROOM * 4
	for tick in range(ticks):
		var manual := {&"light": _rng.randf() < 0.6, &"heavy": _rng.randf() < 0.1}
		if tick % 97 == 0:
			can_act = _rng.randf() < 0.8
		controller.tick(DT, can_act, manual, target_check)
		if _rng.randf() < 0.05:
			manager.apply_status("stun", stun_def, base_stun)
			if manager.rank == "boss" and manager.is_stunned():
				_issues.append("attack room %d tick %d: boss was stunned" % [room_index, tick])
			if manager.stun_time_remaining() > base_stun * rank_mult + 0.0001:
				_issues.append("attack room %d tick %d: stun %.3f s longer than base x rank" % [room_index, tick, manager.stun_time_remaining()])
		if _rng.randf() < 0.03:
			manager.apply_status("burn", burn_def, 3.0)
		manager._process(DT)
		var slowed := mods.apply(AttackController.MOVE_SPEED_STAT, 6.0)
		if is_nan(slowed) or slowed <= 0.0:
			_issues.append("attack room %d tick %d: move speed %s (rooted or NaN)" % [room_index, tick, str(slowed)])
		for attack_id: StringName in controller.ids():
			var progress := controller.get_progress(attack_id)
			if is_nan(progress) or progress < 0.0 or progress > 1.0:
				_issues.append("attack room %d tick %d: bad progress %s on %s" % [room_index, tick, str(progress), attack_id])
		if is_nan(health.current_health) or is_nan(manager.stun_time_remaining()) or manager.stun_time_remaining() < 0.0:
			_issues.append("attack room %d tick %d: NaN or negative status/health value" % [room_index, tick])
	# Idle for long enough that every wind-up and cooldown has finished: nothing may be stuck.
	controller.tick(DT, false, {}, target_check)
	for i in range(int(3.0 / DT)):
		controller.tick(DT, true, {}, func(_id: StringName) -> bool: return false)
		manager._process(DT)
	for attack_id: StringName in controller.ids():
		if controller.is_winding_up(attack_id) or not controller.is_ready(attack_id):
			_issues.append("attack room %d: %s stuck (winding up or never ready) after 3 s idle" % [room_index, attack_id])
	if absf(mods.apply(AttackController.MOVE_SPEED_STAT, 6.0) - 6.0) > 0.0001:
		_issues.append("attack room %d: wind-up slow still applied while idle" % room_index)
	if manager.is_stunned():
		_issues.append("attack room %d: still stunned after 3 s idle" % room_index)
	var seconds := float(ticks) * DT
	var max_light := seconds / (controller.get_interval(&"light") / float(light["manual_click_max_rate_ratio"])) + 2.0
	if int(fired[&"light"]) > int(max_light):
		_issues.append("attack room %d: light fired %d times in %.0f s, cap is %.0f" % [room_index, int(fired[&"light"]), seconds, max_light])
	var max_heavy := seconds / controller.get_interval(&"heavy") + 2.0
	if int(fired[&"heavy"]) > int(max_heavy):
		_issues.append("attack room %d: heavy fired %d times in %.0f s, cap is %.0f" % [room_index, int(fired[&"heavy"]), seconds, max_heavy])
	_checksum = hash([_checksum, int(fired[&"light"]), int(fired[&"heavy"]), snappedf(health.current_health, 0.001)])
	manager.free()
	health.free()
