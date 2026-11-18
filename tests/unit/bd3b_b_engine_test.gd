class_name Bd3bBEngineTest
extends GdUnitTestSuite
## BD3b sitting B, engine 2: buff triggers (live only while the buff lasts, routed through the relic recursion guard and chain depth), a line
## zone laid along a dash path, and the chain depth a delayed relic-spawned hit carries. Everything here is a fixture: no shipped card or relic
## uses these yet. The data shapes C1 and C2 will write are pinned in bd3b_b_formats_test.gd.

const WARD_SOURCE := "card:fixture_ward"

var _fired: Array[String] = []
var _depths: Array[int] = []


## A caster with a stat stack, like the player (the buff template needs one).
class BuffCaster extends RelayTarget:
	var stat_modifiers := StatModifiers.new()


func before_test() -> void:
	CombatEvents.reset()
	_fired = []
	_depths = []


func after_test() -> void:
	CombatEvents.reset()
	var zones := ZoneManager.find_in_world(self)
	if zones != null:
		remove_child(zones)
		zones.free()


func _caster() -> BuffCaster:
	var caster := BuffCaster.new("player", 100.0)
	add_child(caster)
	auto_free(caster)
	return caster


func _enemy(at: Vector3, hp: float = 1000.0) -> RelayTarget:
	var target := RelayTarget.new("enemy", hp)
	add_child(target)
	auto_free(target)
	target.global_position = at
	return target


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	return rng


func _nova(damage: float = 6.0, radius: float = 2.5) -> Dictionary:
	return {"template": "aoe", "params": {"damage": damage, "damage_type": "neutral", "radius": radius}}


## Spiteful Ward's buff: +25 armor for 4 s; on player_damaged a 6-neutral nova, r2.5, 0.5 s internal cooldown, at the player.
func _ward_params(trigger_overrides: Dictionary = {}, duration: float = 4.0) -> Dictionary:
	var trigger: Dictionary = {"event": "player_damaged", "filter": {}, "at": "player", "internal_cooldown": 0.5, "effects": [_nova()]}
	trigger.merge(trigger_overrides, true)
	return {"stat": "armor", "modifier_type": "additive", "value": 25.0, "duration": duration, "triggers": [trigger]}


## A host whose firings are only counted ("<source>:<index> <event>"), plus the buff applied to `caster` through the real template.
func _warded(caster: BuffCaster, params: Dictionary = {}, count_only: bool = true) -> RelicManager:
	var host := RelicManager.buff_host(caster, self, _rng(), CombatEvents)
	if count_only:
		host.effect_runner = func(trigger: Dictionary, event: Dictionary) -> void:
			_fired.append("%s:%d %s" % [trigger["source"], trigger["index"], event["event"]])
	_cast_buff(caster, params if not params.is_empty() else _ward_params())
	return host


func _cast_buff(caster: BuffCaster, params: Dictionary, origin: String = WARD_SOURCE) -> void:
	var context := EffectContext.new(caster, self, "player")
	context.origin = origin
	context.rng = _rng()
	EffectTemplates.execute("buff", params, context)


func _hurt_player(amount: float = 5.0) -> void:
	CombatEvents.notify_player_damaged(amount, "enemy")


# --- buff triggers: lifetime ---------------------------------------------------------------------

func test_a_buff_trigger_fires_while_the_buff_lasts_and_the_armor_is_on() -> void:
	var caster := _caster()
	var host := _warded(caster)
	assert_float(caster.stat_modifiers.apply("armor", 0.0)).is_equal_approx(25.0, 0.0001)
	assert_bool(host.has_buff_triggers(WARD_SOURCE)).is_true()
	_hurt_player()
	host.flush()
	assert_array(_fired).is_equal(["card:fixture_ward:0 player_damaged"])


func test_a_buff_trigger_never_fires_after_the_buff_expires() -> void:
	var caster := _caster()
	var host := _warded(caster)
	var ended: Array[String] = []
	host.buff_triggers_ended.connect(func(source: String, reason: String) -> void: ended.append("%s %s" % [source, reason]))
	CombatEvents.step(3.9)
	_hurt_player()
	host.flush()
	assert_int(_fired.size()).override_failure_message("still live at 3.9 s").is_equal(1)
	CombatEvents.step(0.2)  # 4.1 s
	_hurt_player()
	host.flush()
	assert_int(_fired.size()).override_failure_message("expired at 4 s: no second firing").is_equal(1)
	assert_bool(host.has_buff_triggers(WARD_SOURCE)).is_false()
	assert_array(ended).is_equal(["card:fixture_ward expired"])
	assert_int(host.listening_count()).override_failure_message("the relay connection goes with the last trigger").is_equal(0)


func test_a_trigger_matched_before_expiry_does_not_run_if_its_buff_ends_before_the_queue_flushes() -> void:
	var caster := _caster()
	var host := _warded(caster)
	_hurt_player()  # matched and queued
	host.remove_buff_triggers(WARD_SOURCE, "expired")
	host.flush()
	assert_array(_fired).is_empty()


func test_a_buff_trigger_is_gone_after_room_exit() -> void:
	var caster := _caster()
	var host := _warded(caster)
	var before: int = CombatEvents.player_damaged.get_connections().size()
	_hurt_player()
	host.flush()
	assert_int(_fired.size()).is_equal(1)
	# Room exit: the room's nodes (the player and the host under it) leave the tree.
	remove_child(caster)
	assert_bool(host.has_buff_triggers(WARD_SOURCE)).is_false()
	_hurt_player()
	host.flush()
	assert_int(_fired.size()).is_equal(1)
	assert_int(CombatEvents.player_damaged.get_connections().size()).is_equal(before - 1)
	caster.free()


func test_a_buff_trigger_is_gone_after_a_run_reset_and_stays_gone() -> void:
	var caster := _caster()
	var host := _warded(caster)
	var ended: Array[String] = []
	host.buff_triggers_ended.connect(func(source: String, reason: String) -> void: ended.append(reason))
	CombatEvents.reset()  # a run, room or arena loads; the clock goes back to 0
	assert_array(ended).is_equal(["reset"])
	_hurt_player()
	host.flush()
	CombatEvents.step(1.0)  # the clock is below the old expiry again: it must not come back
	_hurt_player()
	host.flush()
	assert_array(_fired).is_empty()


func test_the_expiry_timer_ends_the_triggers_in_a_live_scene_too() -> void:
	var caster := _caster()
	var host := _warded(caster, _ward_params({}, 0.2))
	assert_bool(host.has_buff_triggers(WARD_SOURCE)).is_true()
	await get_tree().create_timer(0.5).timeout
	assert_bool(host.has_buff_triggers(WARD_SOURCE)).is_false()


# --- buff triggers: cooldown, recast, filter ------------------------------------------------------

func test_the_internal_cooldown_holds() -> void:
	var caster := _caster()
	var host := _warded(caster)
	_hurt_player()
	CombatEvents.step(0.3)
	_hurt_player()  # inside the 0.5 s cooldown
	host.flush()
	assert_int(_fired.size()).is_equal(1)
	CombatEvents.step(0.3)  # 0.6 s after the first
	_hurt_player()
	host.flush()
	assert_int(_fired.size()).is_equal(2)


func test_recasting_the_buff_refreshes_it_and_never_doubles_the_triggers() -> void:
	var caster := _caster()
	var host := _warded(caster)
	CombatEvents.step(3.0)
	_cast_buff(caster, _ward_params())  # a second Ward, 3 s in: live until 7 s
	CombatEvents.step(2.0)  # 5 s: the first cast would be over
	_hurt_player()
	host.flush()
	assert_array(_fired).override_failure_message("still live, and one nova per hit, not two").is_equal(["card:fixture_ward:0 player_damaged"])
	CombatEvents.step(2.5)  # 7.5 s
	_hurt_player()
	host.flush()
	assert_int(_fired.size()).is_equal(1)


func test_a_buff_trigger_uses_the_relic_filter_format() -> void:
	var caster := _caster()
	var host := _warded(caster, _ward_params({"filter": {"min_amount": 10.0}}))
	_hurt_player(5.0)
	host.flush()
	assert_array(_fired).is_empty()
	_hurt_player(12.0)
	host.flush()
	assert_int(_fired.size()).is_equal(1)


func test_a_buff_without_triggers_makes_no_host_and_costs_nothing() -> void:
	var caster := _caster()
	_cast_buff(caster, {"stat": "armor", "modifier_type": "additive", "value": 25.0, "duration": 4.0})
	assert_object(caster.get_node_or_null(RelicManager.BUFF_HOST_NAME)).is_null()


func test_the_nova_runs_for_real_stamped_as_a_relic_origin() -> void:
	var caster := _caster()
	var near := _enemy(Vector3(1.5, 0, 0))
	var far := _enemy(Vector3(6.0, 0, 0))
	await _frames(2)
	var log := RelayLog.new(CombatEvents)
	var host := _warded(caster, {}, false)
	_hurt_player()
	host.flush()
	log.stop()
	assert_float(near.health.current_health).is_equal_approx(994.0, 0.01)
	assert_float(far.health.current_health).is_equal_approx(1000.0, 0.01)
	var origins: Array = log.named("hit_landed").map(func(e: Dictionary) -> String: return String(e["origin"]))
	assert_array(origins).is_equal(["relic:buff_fixture_ward"])


# --- buff triggers: recursion guard and chain depth -----------------------------------------------

## A host that runs the real effects and records the chain level each firing runs at.
func _real_host(caster: BuffCaster, params: Dictionary) -> RelicManager:
	var host := _warded(caster, params, false)
	host.effect_runner = func(trigger: Dictionary, event: Dictionary) -> void:
		_depths.append(CombatEventsRelay.chain_depth)
		host._run_effects(trigger, event)
	return host


func test_a_buff_nova_does_not_set_off_its_own_trigger_by_default() -> void:
	var caster := _caster()
	var a := _enemy(Vector3(3, 0, 0))
	var b := _enemy(Vector3(3, 0, 1))
	await _frames(2)
	var host := _real_host(caster, _ward_params({"event": "hit_landed", "filter": {}, "at": "player", "internal_cooldown": 0.0, "effects": [_nova(1.0, 6.0)]}))
	a.hurtbox.receive_damage(1.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "light")
	host.flush()
	assert_int(host.fired_total()).override_failure_message("the nova's own hits are relic-origin: the guard ignores them").is_equal(1)
	assert_float(b.health.current_health).is_less(1000.0)


func test_a_buff_trigger_that_opts_in_still_stops_after_one_nested_level() -> void:
	var caster := _caster()
	var a := _enemy(Vector3(3, 0, 0))
	var b := _enemy(Vector3(3, 0, 1))
	await _frames(2)
	var host := _real_host(caster, _ward_params({"event": "hit_landed", "filter": {"allow_relic_origin": true}, "at": "player", "internal_cooldown": 0.0, "effects": [_nova(1.0, 6.0)]}))
	a.hurtbox.receive_damage(1.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "light")
	host.flush()
	# One top-level firing; its nova hits a and b (2 events), each fires once at depth 1 more; those novas' hits are blocked.
	assert_int(host.fired_total()).is_equal(3)
	assert_int(_depths.max()).is_equal(2)
	assert_int(CombatEventsRelay.chain_depth).override_failure_message("the ambient level is restored").is_equal(0)


func test_a_buff_trigger_and_a_relic_share_one_chain_depth_cap() -> void:
	var caster := _caster()
	var a := _enemy(Vector3(3, 0, 0))
	var b := _enemy(Vector3(3, 0, 1))
	await _frames(2)
	var host := _real_host(caster, _ward_params({"event": "hit_landed", "filter": {"allow_relic_origin": true}, "at": "player", "internal_cooldown": 0.0, "effects": [_nova(1.0, 6.0)]}))
	var relic: Dictionary = {"id": "fixture_echo", "name": "e", "pool": "neutral", "rarity": "tier1", "sources": ["elite"], "flavor_text": "",
			"triggers": [{"event": "hit_landed", "filter": {"allow_relic_origin": true}, "at": "player", "effects": [_nova(1.0, 6.0)]}]}
	var manager := RelicManager.new()
	add_child(manager)
	auto_free(manager)
	manager.configure(caster, self, _rng(), CombatEvents, {"fixture_echo": relic})
	manager.effect_runner = func(trigger: Dictionary, event: Dictionary) -> void:
		_depths.append(CombatEventsRelay.chain_depth)
		manager._run_effects(trigger, event)
	manager.load_relics(["fixture_echo"] as Array[String])
	a.hurtbox.receive_damage(1.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "light")
	for round_index in range(6):  # flush both until nothing is left
		host.flush()
		manager.flush()
	assert_int(_depths.max()).override_failure_message("no firing may run deeper than 2: the cap is shared by both managers").is_equal(2)
	var total: int = host.fired_total() + manager.fired_total()
	for round_index in range(6):
		host.flush()
		manager.flush()
	assert_int(host.fired_total() + manager.fired_total()).override_failure_message("nothing left over, nothing looping").is_equal(total)
	assert_int(b.health.current_health as int).is_less(1000)


func test_a_buff_trigger_is_not_set_off_by_a_relic_without_opting_in() -> void:
	var caster := _caster()
	var a := _enemy(Vector3(3, 0, 0))
	await _frames(2)
	var host := _real_host(caster, _ward_params({"event": "hit_landed", "filter": {}, "at": "player", "internal_cooldown": 0.0, "effects": [_nova(1.0, 6.0)]}))
	# A relic-origin hit (a relic's own damage) must not fire a buff trigger that did not opt in.
	a.hurtbox.receive_damage(1.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "relic:some_relic")
	host.flush()
	assert_int(host.fired_total()).is_equal(0)


# --- the line zone along a dash path --------------------------------------------------------------

func _exit_strategy() -> Dictionary:
	return {"id": "fixture_exit", "name": "Exit", "pool": "fire", "rarity": "tier1", "sources": ["elite"], "flavor_text": "", "rule_text": "x",
			"triggers": [{"event": "dash_ended", "filter": {}, "at": "event_path", "effects": [{"template": "zone", "params": {
					"shape": "line", "length": 1.0, "width": 1.0, "duration": 2.0, "tick_interval": 0.5, "damage": 2.0, "damage_type": "fire", "max_range": 1.0}}]}]}


func _line_manager(caster: Node3D) -> RelicManager:
	var manager := RelicManager.new()
	add_child(manager)
	auto_free(manager)
	manager.configure(caster, self, _rng(), CombatEvents, {"fixture_exit": _exit_strategy()})
	manager.load_relics(["fixture_exit"] as Array[String])
	return manager


func _dash(manager: RelicManager, start: Vector3, end: Vector3) -> void:
	CombatEvents.notify_dash_ended(start, end, "fixture_dash")
	manager.flush()


func _hp_lost(target: RelayTarget) -> float:
	return 1000.0 - target.health.current_health


func test_the_line_runs_from_the_dash_start_to_the_dash_end() -> void:
	var caster := _caster()
	var on_start := _enemy(Vector3(-3.5, 0, 0))
	var on_middle := _enemy(Vector3(0, 0, 0))
	var on_end := _enemy(Vector3(3.5, 0, 0))
	var beside := _enemy(Vector3(0, 0, 3))
	var before := _enemy(Vector3(-8, 0, 0))
	var beyond := _enemy(Vector3(8, 0, 0))
	await _frames(2)
	var manager := _line_manager(caster)
	_dash(manager, Vector3(-4, 0, 0), Vector3(4, 0, 0))
	assert_float(_hp_lost(on_start)).is_equal_approx(2.0, 0.01)
	assert_float(_hp_lost(on_middle)).is_equal_approx(2.0, 0.01)
	assert_float(_hp_lost(on_end)).is_equal_approx(2.0, 0.01)
	assert_float(_hp_lost(beside)).override_failure_message("the line is as wide as its width, not a wall across the path").is_equal(0.0)
	assert_float(_hp_lost(before)).is_equal(0.0)
	assert_float(_hp_lost(beyond)).is_equal(0.0)


func test_the_line_follows_a_diagonal_and_a_backwards_dash() -> void:
	var caster := _caster()
	var along_a := _enemy(Vector3(1, 0, 1))
	var along_b := _enemy(Vector3(2.4, 0, 2.4))
	var across := _enemy(Vector3(3, 0, 0))  # same distance from the middle, but off the path
	var past := _enemy(Vector3(5, 0, 5))
	await _frames(2)
	var manager := _line_manager(caster)
	_dash(manager, Vector3(3, 0, 3), Vector3(0, 0, 0))  # backwards, along (1, 0, 1)
	assert_float(_hp_lost(along_a)).is_equal_approx(2.0, 0.01)
	assert_float(_hp_lost(along_b)).is_equal_approx(2.0, 0.01)
	assert_float(_hp_lost(across)).is_equal(0.0)
	assert_float(_hp_lost(past)).is_equal(0.0)


func test_the_line_zone_is_2_seconds_of_ticks_every_half_second_at_the_path_midpoint() -> void:
	var caster := _caster()
	var victim := _enemy(Vector3(0, 0, 0))
	await _frames(2)
	var manager := _line_manager(caster)
	_dash(manager, Vector3(-4, 0, 0), Vector3(4, 0, 0))
	var zones := ZoneManager.find_in_world(self)
	assert_object(zones).is_not_null()
	var live: Array[Dictionary] = zones.live_zones()
	assert_int(live.size()).is_equal(1)
	assert_vector(live[0]["center"] as Vector3).is_equal_approx(Vector3.ZERO, Vector3(0.001, 0.001, 0.001))
	assert_float(float(live[0]["half_length"])).is_equal_approx(VfxSizing.zone_line_half_length(8.0), 0.001)
	for i in range(8):
		zones.step(0.5)
	assert_float(_hp_lost(victim)).override_failure_message("4 ticks of 2 over 2 s").is_equal_approx(8.0, 0.01)
	assert_int(zones.live_count()).is_equal(0)


func test_a_dash_that_did_not_move_leaves_no_line() -> void:
	var caster := _caster()
	var manager := _line_manager(caster)
	_dash(manager, Vector3(2, 0, 2), Vector3(2.02, 0, 2))
	assert_object(ZoneManager.find_in_world(self)).is_null()  # none was even made
	assert_int(manager.fired_total()).is_equal(1)


func test_a_long_dash_is_clamped_to_the_longest_line() -> void:
	var params: Dictionary = RelicManager._along_path({"length": 1.0}, Vector3.ZERO, Vector3(40, 0, 0))
	assert_float(float(params["length"])).is_equal(EffectTemplates.MAX_ZONE_LINE_LENGTH)
	assert_vector(params["center"] as Vector3).is_equal_approx(Vector3(20, 0, 0), Vector3(0.001, 0.001, 0.001))


# --- a delayed relic-spawned hit keeps its chain depth ---------------------------------------------

func _hit_relic(effects: Array) -> Dictionary:
	return {"id": "fixture_delayed", "name": "d", "pool": "neutral", "rarity": "tier1", "sources": ["elite"], "flavor_text": "",
			"triggers": [{"event": "hit_landed", "filter": {"allow_relic_origin": true}, "at": "player", "effects": effects}]}


func _delayed_manager(caster: Node3D, effects: Array) -> RelicManager:
	var manager := RelicManager.new()
	add_child(manager)
	auto_free(manager)
	manager.configure(caster, self, _rng(), CombatEvents, {"fixture_delayed": _hit_relic(effects)})
	manager.effect_runner = func(trigger: Dictionary, event: Dictionary) -> void:
		_depths.append(CombatEventsRelay.chain_depth)
		manager._run_effects(trigger, event)
	manager.load_relics(["fixture_delayed"] as Array[String])
	return manager


func test_a_projectile_remembers_the_chain_level_it_was_fired_at() -> void:
	var caster := _caster()
	var victim := _enemy(Vector3(2, 0, 0))
	await _frames(2)
	var manager := _delayed_manager(caster, [_nova(1.0, 6.0)])
	for level in [0, 1, 2]:
		_fired.clear()
		var shot: Projectile = (load(EffectTemplates.PROJECTILE_SCENE_PATH) as PackedScene).instantiate()
		add_child(shot)
		shot.origin = "relic:fixture_delayed"
		shot.chain_depth = level
		shot.set_source(caster, Health.KIND_HIT)
		shot.launch(Vector3.ZERO, Vector3.RIGHT, 1.0, "physical", 10.0, 10.0, "player")
		var before: int = manager.fired_total()
		shot._on_area_entered(victim.hurtbox)  # the later hit
		manager.flush()
		var fired: int = manager.fired_total() - before
		# Level 0 (a card's shot): the trigger fires at level 1, and its own hit fires it once more at level 2. Level 1 (a relic's shot): once, at level 2.
		# Level 2: blocked.
		assert_int(fired).override_failure_message("projectile at chain level %d" % level).is_equal(2 - level)
		assert_int(CombatEventsRelay.chain_depth).is_equal(0)
	assert_int(_depths.max()).is_equal(2)


func test_a_relic_spawned_zone_keeps_its_depth_so_its_later_ticks_cannot_restart_the_chain() -> void:
	var caster := _caster()
	var victim := _enemy(Vector3(2, 0, 0))
	await _frames(2)
	var zone_effect: Dictionary = {"template": "zone", "params": {"shape": "circle", "radius": 6.0, "duration": 3.0, "tick_interval": 0.5, "damage": 1.0, "damage_type": "fire", "max_range": 1.0}}
	var manager := _delayed_manager(caster, [zone_effect])
	victim.hurtbox.receive_damage(1.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "light")
	manager.flush()
	var zones := ZoneManager.find_in_world(self)
	var settled: int = -1
	for tick in range(10):
		zones.step(0.5)
		manager.flush()
		if tick == 4:
			settled = manager.fired_total()
	assert_int(_depths.max()).override_failure_message("no zone tick may start a chain at level 1 again").is_equal(2)
	assert_int(manager.fired_total()).override_failure_message("the chain stopped: firing count does not keep growing with ticks").is_equal(settled)
	assert_bool(zones.live_count() <= 3).override_failure_message("one level-1 zone plus the level-2 zones its first tick caused").is_true()


func test_a_delayed_multi_hit_of_a_relic_effect_keeps_the_depth() -> void:
	var caster := _caster()
	var victim := _enemy(Vector3(2, 0, 0))
	await _frames(2)
	var repeated: Dictionary = {"template": "aoe", "params": {"damage": 1.0, "damage_type": "fire", "radius": 6.0, "hits": 3, "hit_interval": 0.1}}
	var manager := _delayed_manager(caster, [repeated])
	victim.hurtbox.receive_damage(1.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "light")
	manager.flush()
	await get_tree().create_timer(0.5).timeout
	manager.flush()
	assert_int(_depths.max()).is_equal(2)
	# 1 top-level firing; its hit 0 fires 1 nested; its two timed hits are level-1 effects too, so they fire 1 nested each: no more than 4.
	assert_int(manager.fired_total()).is_less_equal(4)
	assert_int(CombatEventsRelay.chain_depth).is_equal(0)


# --- the real player ------------------------------------------------------------------------------

func test_spiteful_ward_on_the_real_player_novas_when_hit_and_holds_its_cooldown() -> void:
	BodyFlag.set_collide(false)
	var main: Main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	var player: Player = main.player
	var enemy := RelayTarget.new("enemy", 1000.0)
	main.add_child(enemy)
	enemy.global_position = player.global_position + Vector3(1.5, 0, 0)
	await _frames(3)
	var context := EffectContext.new(player, main, "player")
	context.origin = WARD_SOURCE
	context.rng = _rng()
	EffectTemplates.execute("buff", _ward_params(), context)
	var host: RelicManager = player.get_node(RelicManager.BUFF_HOST_NAME)
	player.hurtbox.receive_damage(10.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "enemy")
	host.flush()
	assert_float(1000.0 - enemy.health.current_health).override_failure_message("the 6-damage nova went off").is_equal_approx(6.0, 0.01)
	player.hurtbox.receive_damage(10.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "enemy")
	host.flush()
	assert_float(1000.0 - enemy.health.current_health).override_failure_message("0.5 s cooldown").is_equal_approx(6.0, 0.01)
	BodyFlag.reset()
