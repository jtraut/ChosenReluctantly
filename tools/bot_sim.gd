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
const SimCasterScript := preload("res://tools/sim_caster.gd")

var _rng := RandomNumberGenerator.new()
## Card shuffles, seeded per room so the whole sim repeats from --seed.
var _card_rng := RandomNumberGenerator.new()
var _issues: Array[String] = []
## Rolling hash of every card used, so two runs of one seed can be compared at a glance.
var _checksum: int = 0
## `--plan`: the card room is driven by PlanPolicy (the plan-aware bot, BD1) instead of random presses. `--deck=<preset>`
## (plan mode only) loads a debug deck from data/debug_decks. Both are off by default and the standard path is untouched.
var _plan: bool = false
var _deck_name: String = ""
var _plan_stats: Dictionary = {"casts": 0, "swaps": 0, "live_casts": 0, "payoff_casts": 0, "dashes": 0, "primed_seen": 0}
var _plan_checksum: int = 0
## `--swap=<old>=<new>` (plan mode with --deck): one copy of card <old> in the preset deck is replaced by <new>, checked against the deck rules.
var _swap_out: String = ""
var _swap_in: String = ""
## SIM1 `--bot-preset=<name>`: validated only (see _read_plan_args).
var _bot_preset: String = ""


func _initialize() -> void:
	var rooms := _rooms_arg()
	var seed_value := _seed_arg()
	if not _read_plan_args():
		quit(2)
		return
	print("Headless bot-sim: %d rooms x %d ticks, seed %d (rerun with --seed=%d to reproduce)" % [rooms, TICKS_PER_ROOM, seed_value, seed_value])
	for room_index in range(rooms):
		_rng.seed = seed_value + room_index
		_card_rng.seed = seed_value + 200000 + room_index
		if _plan:
			await _run_plan_room(room_index)
		else:
			await _run_room(room_index)
		_rng.seed = seed_value + 100000 + room_index
		_run_attack_room(room_index)
	if _issues.is_empty():
		print("Bot-sim OK: no NaN detected across %d rooms (%d ticks each)." % [rooms, TICKS_PER_ROOM])
		print("Bot-sim checksum: %d (same seed and rooms give the same checksum)" % _checksum)
		if _plan:
			print("Bot-sim plan: deck %s | %d casts (%d payoff casts, %d with the condition live), %d dead-card swaps, %d dashes, primed state seen on %d ticks | plan checksum %d" % [
				_deck_name if _deck_name != "" else "(all pool cards)", int(_plan_stats["casts"]), int(_plan_stats["payoff_casts"]), int(_plan_stats["live_casts"]), int(_plan_stats["swaps"]), int(_plan_stats["dashes"]), int(_plan_stats["primed_seen"]), _plan_checksum])
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


## Reads --plan and --deck=<preset>. False (with a message) on a bad value.
func _read_plan_args() -> bool:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--plan":
			_plan = true
		elif arg.begins_with("--deck="):
			_deck_name = arg.substr("--deck=".length())
		elif arg.begins_with("--swap="):
			_swap_out = arg.substr("--swap=".length()).get_slice("=", 0)
			_swap_in = arg.substr("--swap=".length()).get_slice("=", 1)
		elif arg.begins_with("--bot-preset="):
			_bot_preset = arg.substr("--bot-preset=".length())
	# SIM1: the preset is validated like in the wave sim (an unknown name fails). This sim has no aim, movement or enemies to react to, so a
	# preset changes nothing here: the checksum is the same for every preset.
	var loaded: Dictionary = BotSettings.load_named(_bot_preset)
	if not (loaded["problems"] as Array[String]).is_empty():
		push_error("bot-sim: --bot-preset: " + "; ".join(loaded["problems"] as Array[String]))
		return false
	if (loaded["settings"] as BotSettings).is_active():
		print("note: bot preset '%s' has no effect in the bot-sim (no aim or movement here); use the wave sim" % (loaded["settings"] as BotSettings).preset_name)
	if _deck_name != "" and not _plan:
		push_error("bot-sim: --deck needs --plan")
		return false
	if (_swap_out != "" or _swap_in != "") and _deck_name == "":
		push_error("bot-sim: --swap needs --plan and --deck")
		return false
	if _deck_name != "":
		var presets: Dictionary = DebugDecks.read_dir()["presets"]
		if not presets.has(_deck_name):
			push_error("bot-sim: --deck must be one of %s, got '%s'" % [str(presets.keys()), _deck_name])
			return false
		if _swap_out != "" or _swap_in != "":
			var swapped: Array[String] = _swapped_deck(DebugDecks.deck_of(presets[_deck_name], false))
			if swapped.is_empty():
				return false
	return true


## The preset deck with one copy of --swap's old card replaced by its new card; [] (and an error) when the swap is not possible or breaks the deck rules.
func _swapped_deck(deck: Array[String]) -> Array[String]:
	var none: Array[String] = []
	if not deck.has(_swap_out) or not CardDatabase.has_card(_swap_in):
		push_error("bot-sim: --swap needs a card in the deck to take out and a known card to put in (got '%s' and '%s')" % [_swap_out, _swap_in])
		return none
	var problems: Array[String] = DeckRules.can_swap(deck, _swap_out, _swap_in, DeckRules.shipped_config(), DeckRules.slot_map_from_database(), SlotTypeDatabase.known_ids(), DeckRules.slot_names_from_database())
	if not problems.is_empty():
		push_error("bot-sim: --swap %s=%s breaks the deck rules: %s" % [_swap_out, _swap_in, "; ".join(problems)])
		return none
	var result: Array[String] = deck.duplicate()
	result[result.find(_swap_out)] = _swap_in
	return result


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


## --plan: PlanPolicy plays the card slots for one room. The room has a stand-in caster that carries stat modifiers and
## counts dashes, one synthetic enemy two metres ahead that the caster aims at (it counts as Burning for 4 s after any Burn-tag cast, and a Zone counts as up for
## 4 s after any Zone-tag cast, so target and zone conditions get exercised), a rotating "in danger" flag, and the real CombatEvents clock stepped by hand each tick (the
## loop runs no frames, so the autoload's own _process never advances it). Checks: no NaN, the cast history stays bounded,
## primed charges never go negative.
func _run_plan_room(room_index: int) -> void:
	var caster: Node3D = SimCasterScript.new()
	root.add_child(caster)
	await process_frame
	var health := Health.new()
	health.name = "Health"
	health.max_health = 30.0
	caster.add_child(health)
	var relay: CombatEventsRelay = CombatLink.events()
	if relay == null:
		_issues.append("room %d: the CombatEvents autoload is not present at run time in this script (no cast history)" % room_index)
		caster.queue_free()
		return
	relay.reset()
	var pools: Array[String] = ["rogue", "fire", "neutral"]
	var deck: Array[String] = []
	if _deck_name != "":
		var preset: Dictionary = (DebugDecks.read_dir()["presets"] as Dictionary)[_deck_name]
		pools = [RunSession.preset_character(preset), "fire", "neutral"]
		deck = DebugDecks.deck_of(preset, false)
		if _swap_out != "":
			deck = _swapped_deck(deck)
	var controller := CardSlotController.new(caster, caster, "player", caster.stat_modifiers, pools, _card_rng)
	controller.status_rng = RandomNumberGenerator.new()
	controller.status_rng.seed = 7
	if not deck.is_empty():
		controller.set_deck(deck)
	var policy := PlanPolicy.new()
	for tick in range(TICKS_PER_ROOM):
		relay.step(DT)
		controller.advance(DT)
		var now: float = relay.now()
		var burning: bool = relay.history.cast_within(now, 4.0, "", "Burn")
		var view: Dictionary = {"now": now, "history": relay.history, "zone_count": 1 if relay.history.cast_within(now, 4.0, "", "Zone") else 0, "origin": Vector3.ZERO, "forward": Vector3(0, 0, -1),
				"aim_point": Vector3(0, 0, -2), "arena": Rect2(), "enemies": [{"pos": Vector3(0, 0, -2), "statuses": ["burn"] if burning else []}]}
		policy.swap_locked = controller.swap_locked()
		var decisions: Dictionary = policy.decide_all(controller.slots, view, 1.0, (tick / 90) % 3 == 0, false)
		for slot_type: String in CardSlotController.SLOT_TYPE_ORDER:
			var card_id: String = controller.get_slot(slot_type).current_card_id
			var card: Dictionary = CardDatabase.get_card(card_id)
			match String(decisions.get(slot_type, PlanPolicy.WAIT)):
				PlanPolicy.CAST:
					var payoff: bool = not SlotSynergy.conditional_effects(card).is_empty()
					var live: bool = payoff and SlotSynergy.is_live(card, view)
					if controller.try_use(slot_type):
						_plan_stats["casts"] = int(_plan_stats["casts"]) + 1
						_plan_stats["payoff_casts"] = int(_plan_stats["payoff_casts"]) + (1 if payoff else 0)
						_plan_stats["live_casts"] = int(_plan_stats["live_casts"]) + (1 if live else 0)
						_plan_checksum = hash([_plan_checksum, slot_type, card_id, tick])
				PlanPolicy.SWAP:
					if controller.try_swap(slot_type):
						_plan_stats["swaps"] = int(_plan_stats["swaps"]) + 1
						_plan_checksum = hash([_plan_checksum, "swap", slot_type, card_id, tick])
		if not caster.stat_modifiers.primed_state().is_empty():
			_plan_stats["primed_seen"] = int(_plan_stats["primed_seen"]) + 1
		for entry: Dictionary in caster.stat_modifiers.primed_state():
			if int(entry["charges"]) < 0:
				_issues.append("room %d tick %d: negative primed charges" % [room_index, tick])
		if relay.history.size() > CastHistory.MAX_ENTRIES:
			_issues.append("room %d tick %d: the cast history grew past its cap (%d)" % [room_index, tick, relay.history.size()])
		_check_for_nan(controller, room_index, tick)
	_plan_stats["dashes"] = int(_plan_stats["dashes"]) + int(caster.get("dashes"))
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
