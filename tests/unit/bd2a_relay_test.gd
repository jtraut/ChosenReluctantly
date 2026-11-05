class_name Bd2aRelayTest
extends GdUnitTestSuite
## BD2-A item 1: the CombatEvents relay. Every event, the origin passed down the damage paths, and a status ending when
## its owner dies (which must fire before the owner is freed).

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"

var _log: RelayLog


func before_test() -> void:
	BodyFlag.set_collide(false)  # enemies parked on the player's path must not block it
	CombatEvents.reset()
	_log = RelayLog.new(CombatEvents)


func after_test() -> void:
	_log.stop()
	BodyFlag.reset()
	CombatEvents.reset()
	Juice.reset()
	GamePause.reset()
	Engine.time_scale = 1.0


func _target(hp: float = 20.0, team: String = "enemy") -> RelayTarget:
	var target := RelayTarget.new(team, hp)
	add_child(target)
	auto_free(target)
	return target


func _burn() -> Dictionary:
	return StatusDatabase.get_status("burn")


# --- hit_landed ------------------------------------------------------------------------------

func test_hit_landed_carries_target_amount_type_kind_origin_and_position() -> void:
	var target := _target()
	target.global_position = Vector3(3, 0, 4)
	target.hurtbox.receive_damage(5.0, "fire", Vector3.ZERO, null, Health.KIND_ECHO, "card:fire_ember")
	var hits := _log.named("hit_landed")
	assert_int(hits.size()).is_equal(1)
	var hit: Dictionary = hits[0]
	assert_object(hit["target"]).is_same(target)
	assert_float(hit["amount"]).is_equal(5.0)
	assert_str(hit["damage_type"]).is_equal("fire")
	assert_that(hit["kind"]).is_equal(Health.KIND_ECHO)
	assert_str(hit["origin"]).is_equal("card:fire_ember")
	assert_vector(hit["position"]).is_equal(Vector3(3, 0, 4))


func test_hit_landed_reports_the_hp_removed_after_mitigation_and_skips_a_fully_resisted_hit() -> void:
	var target := _target(20.0)
	target.health.resistances = {"fire": 0.5}
	target.hurtbox.receive_damage(10.0, "fire", Vector3.ZERO, null, Health.KIND_HIT, "light")
	assert_float(_log.named("hit_landed")[0]["amount"]).is_equal_approx(5.0, 0.001)
	var immune := _target(20.0)
	immune.health.damage_immune = true
	immune.hurtbox.receive_damage(10.0, "fire", Vector3.ZERO, null, Health.KIND_HIT, "light")
	assert_int(_log.named("hit_landed").size()).is_equal(1)  # nothing was taken, nothing is relayed


func test_a_hit_with_no_origin_relays_an_empty_origin() -> void:
	var target := _target()
	target.hurtbox.receive_damage(1.0)
	assert_str(_log.named("hit_landed")[0]["origin"]).is_equal("")


# --- enemy_killed ----------------------------------------------------------------------------

func test_enemy_killed_carries_position_last_origin_and_the_statuses_held() -> void:
	var target := _target(5.0)
	target.global_position = Vector3(1, 0, 2)
	target.status_manager.apply_status("burn", _burn(), 5.0, null, "card:x")
	target.hurtbox.receive_damage(9.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "heavy")
	var kills := _log.named("enemy_killed")
	assert_int(kills.size()).is_equal(1)
	assert_object(kills[0]["target"]).is_same(target)
	assert_vector(kills[0]["position"]).is_equal(Vector3(1, 0, 2))
	assert_str(kills[0]["origin"]).is_equal("heavy")
	assert_array(kills[0]["statuses"]).contains_exactly(["burn"])
	# hit first, then the kill, then the status ends with its owner
	assert_array(_log.names()).is_equal(["status_applied", "hit_landed", "enemy_killed", "status_ended"])


func test_enemy_killed_fires_once_and_not_for_the_player_team() -> void:
	var target := _target(5.0)
	target.hurtbox.receive_damage(9.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "light")
	target.hurtbox.receive_damage(9.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "light")
	assert_int(_log.named("enemy_killed").size()).is_equal(1)
	var player_like := _target(5.0, "player")
	player_like.hurtbox.receive_damage(9.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "enemy")
	assert_int(_log.named("enemy_killed").size()).is_equal(1)
	assert_int(_log.named("hit_landed").size()).is_equal(2)


func test_a_second_hit_in_the_same_death_cannot_kill_twice() -> void:
	# A relay listener that damages the dying target again (what a relic's explosion would do) takes nothing.
	var target := _target(5.0)
	var again := func(hit_target: Node, _amount: float, _type: String, _kind: StringName, _origin: String, _pos: Vector3) -> void:
		(hit_target as RelayTarget).hurtbox.receive_damage(50.0, "fire", Vector3.ZERO, null, Health.KIND_HIT, "relic:test")
	CombatEvents.hit_landed.connect(again)
	target.hurtbox.receive_damage(9.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "light")
	CombatEvents.hit_landed.disconnect(again)
	assert_int(_log.named("enemy_killed").size()).is_equal(1)
	assert_int(_log.named("hit_landed").size()).is_equal(1)


# --- status_applied / status_ended ------------------------------------------------------------

func test_status_applied_fires_once_with_source_origin_and_position_and_not_on_refresh() -> void:
	var target := _target()
	target.global_position = Vector3(2, 0, 0)
	var source := _target(10.0, "player")
	target.status_manager.apply_status("burn", _burn(), 5.0, source, "relic:pyre")
	target.status_manager.apply_status("burn", _burn(), 8.0, source, "relic:pyre")  # a refresh
	var applied := _log.named("status_applied")
	assert_int(applied.size()).is_equal(1)
	assert_object(applied[0]["target"]).is_same(target)
	assert_str(applied[0]["status_id"]).is_equal("burn")
	assert_int(applied[0]["stacks"]).is_equal(1)
	assert_object(applied[0]["source"]).is_same(source)
	assert_str(applied[0]["origin"]).is_equal("relic:pyre")
	assert_vector(applied[0]["position"]).is_equal(Vector3(2, 0, 0))


func test_status_ended_expired_after_the_duration_with_the_applying_origin() -> void:
	var target := _target()
	target.status_manager.apply_status("burn", _burn(), 0.5, null, "card:fire_kindling")
	target.status_manager._process(0.6)
	var ended := _log.named("status_ended")
	assert_int(ended.size()).is_equal(1)
	assert_str(ended[0]["reason"]).is_equal(CombatEventsRelay.STATUS_END_EXPIRED)
	assert_str(ended[0]["status_id"]).is_equal("burn")
	assert_str(ended[0]["origin"]).is_equal("card:fire_kindling")
	assert_bool(target.status_manager.has_status("burn")).is_false()


func test_status_ended_consumed_removes_the_status_and_says_so() -> void:
	var target := _target()
	target.status_manager.apply_status("burn", _burn(), 5.0, null, "light")
	assert_bool(target.status_manager.consume_status("burn")).is_true()
	assert_bool(target.status_manager.consume_status("burn")).is_false()
	assert_bool(target.status_manager.has_status("burn")).is_false()
	var ended := _log.named("status_ended")
	assert_int(ended.size()).is_equal(1)
	assert_str(ended[0]["reason"]).is_equal(CombatEventsRelay.STATUS_END_CONSUMED)


func test_burn_ending_on_death_fires_owner_died_before_the_node_is_freed() -> void:
	var target := _target(2.0)
	var expired: Array[String] = []
	target.status_manager.status_expired.connect(func(status_id: String) -> void: expired.append(status_id))
	target.status_manager.apply_status("burn", _burn(), 5.0, null, "card:fire_kindling")
	target.status_manager._process(1.0)  # the 1 s tick deals 2 and kills it
	assert_bool(target.health.is_dead()).is_true()
	var ended := _log.named("status_ended")
	assert_int(ended.size()).is_equal(1)
	assert_str(ended[0]["reason"]).is_equal(CombatEventsRelay.STATUS_END_OWNER_DIED)
	assert_object(ended[0]["target"]).is_same(target)
	assert_str(ended[0]["origin"]).is_equal("card:fire_kindling")
	assert_bool(ended[0]["died_handler_ran"]).override_failure_message("owner_died must fire before the owner's own died handler").is_false()
	assert_bool(ended[0]["queued_for_free"]).is_false()
	assert_bool(target.died_handler_ran).is_true()  # the owner's handler did run, after
	assert_bool(is_instance_valid(target)).is_true()  # queue_free is deferred: the node was valid for the whole event
	assert_array(expired).is_empty()  # dying never emits status_expired (the existing contract)
	# the kill is credited to the burn
	assert_str(_log.named("hit_landed")[0]["origin"]).is_equal("status:burn")
	assert_str(_log.named("enemy_killed")[0]["origin"]).is_equal("status:burn")


func test_every_held_status_ends_with_owner_died() -> void:
	var target := _target(5.0)
	target.status_manager.apply_status("burn", _burn(), 5.0)
	target.status_manager.apply_status("bleed", StatusDatabase.get_status("bleed"), 5.0)
	target.hurtbox.receive_damage(50.0, "physical")
	var ids: Array[String] = []
	for event: Dictionary in _log.named("status_ended"):
		ids.append(String(event["status_id"]))
	ids.sort()
	assert_array(ids).is_equal(["bleed", "burn"])


# --- origin down the real damage paths ----------------------------------------------------------

func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	return main


func _enemy_at(main: Main, offset: Vector3) -> Enemy:
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	main.add_child(enemy)
	enemy.global_position = main.player.global_position + offset
	enemy.health.set_max_health(10000.0)
	enemy.health.heal(10000.0)
	return enemy


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _context(main: Main, origin: String) -> EffectContext:
	var context := EffectContext.new(main.player, main, "player")
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = 11
	context.arena = main.player.get_arena_rect()
	context.origin = origin
	return context


func _origins(event_name: String) -> Array[String]:
	var result: Array[String] = []
	for event: Dictionary in _log.named(event_name):
		result.append(String(event["origin"]))
	return result


func test_cone_aoe_and_projectile_hits_carry_the_effect_contexts_origin() -> void:
	var main := _spawn_main()
	var enemy := _enemy_at(main, Vector3(0, 0, -1.5))
	await _frames(2)
	enemy.set_physics_process(false)
	EffectTemplates.execute("cone", {"damage": 1.0, "damage_type": "physical", "range": 5.0, "half_angle_degrees": 60.0}, _context(main, "card:a"))
	EffectTemplates.execute("aoe", {"damage": 1.0, "damage_type": "fire", "radius": 4.0}, _context(main, "card:b"))
	main.player.rotation.y = 0.0
	EffectTemplates.execute("projectile", {"damage": 1.0, "damage_type": "fire", "speed": 30.0, "max_range": 20.0, "hit_radius": 0.6}, _context(main, "light"))
	await _frames(30)
	assert_array(_origins("hit_landed")).contains(["card:a", "card:b", "light"])


func test_zone_ticks_and_the_statuses_a_zone_applies_carry_the_origin_and_zone_events_fire() -> void:
	var main := _spawn_main()
	var enemy := _enemy_at(main, Vector3(0, 0, -4.0))
	await _frames(2)
	enemy.set_physics_process(false)
	var params: Dictionary = {"shape": "circle", "radius": 2.0, "duration": 1.0, "tick_interval": 0.5, "damage": 1.0, "damage_type": "fire", "max_range": 8.0, "status_id": "burn", "status_duration": 3.0}
	var context := _context(main, "card:fire_wall")
	context.aim_point = enemy.global_position
	EffectTemplates.execute("zone", params, context)
	var started := _log.named("zone_started")
	assert_int(started.size()).is_equal(1)
	assert_str(started[0]["shape"]).is_equal("circle")
	assert_array(_origins("hit_landed")).contains(["card:fire_wall"])
	assert_array(_origins("status_applied")).contains(["card:fire_wall"])
	var manager := ZoneManager.for_world(main)
	manager.set_physics_process(false)
	manager.step(2.0)
	assert_int(_log.named("zone_ended").size()).is_equal(1)
	assert_int(_log.named("zone_ended")[0]["zone_id"]).is_equal(started[0]["zone_id"])


func test_the_dash_path_hit_and_dash_ended_carry_the_card() -> void:
	var main := _spawn_main()
	var enemy := _enemy_at(main, Vector3(0, 0, -1.5))
	await _frames(2)
	enemy.set_physics_process(false)
	var start: Vector3 = main.player.global_position
	EffectTemplates.execute("dash", {"distance": 4.0, "speed": 15.0, "damage": 1.0, "damage_type": "physical", "hit_radius": 0.6}, _context(main, "card:rogue_blink"))
	await _frames(40)
	assert_array(_origins("hit_landed")).contains(["card:rogue_blink"])
	var ended := _log.named("dash_ended")
	assert_int(ended.size()).is_equal(1)
	assert_str(ended[0]["card_id"]).is_equal("rogue_blink")
	assert_vector(ended[0]["start"]).is_equal_approx(start, Vector3(0.01, 0.01, 0.01))
	assert_float(ended[0]["start"].distance_to(ended[0]["end"])).is_greater(1.0)


func test_the_dodge_roll_does_not_fire_dash_ended() -> void:
	var main := _spawn_main()
	await _frames(2)
	main.player.start_forced_move(Vector3.FORWARD, 10.0, 0.2, true)  # what the dodge calls: no card behind it
	await _frames(30)
	assert_int(_log.named("dash_ended").size()).is_equal(0)


func test_light_and_heavy_attacks_are_stamped_and_fire_attack_fired_with_the_aim_point() -> void:
	var main := _spawn_main()
	var enemy := _enemy_at(main, Vector3(0, 0, -1.2))
	await _frames(2)
	enemy.set_physics_process(false)
	main.player.aim_point_override = enemy.global_position
	main.player.attacks.set_auto(&"light", true)
	await _frames(20)
	main.player.attacks.set_auto(&"light", false)
	var fired := _log.named("attack_fired")
	assert_bool(fired.is_empty()).is_false()
	assert_str(fired[0]["attack_id"]).is_equal("light")
	assert_vector(fired[0]["aim_point"]).is_equal(enemy.global_position)
	assert_array(_origins("hit_landed")).contains(["light"])
	TestInput.tap(&"attack_heavy")
	await _frames(60)
	var ids: Array[String] = []
	for event: Dictionary in _log.named("attack_fired"):
		ids.append(String(event["attack_id"]))
	assert_array(ids).contains(["heavy"])


func test_enemy_hits_on_the_player_carry_enemy_origin_and_fire_player_damaged() -> void:
	var main := _spawn_main()
	await _frames(2)
	var enemy := _enemy_at(main, Vector3(0, 0, -1.0))
	enemy.set_physics_process(false)
	enemy.rotation.y = PI  # face the player
	var context := EffectContext.new(enemy, main, "enemy")
	context.origin = "enemy"
	EffectTemplates.execute("cone", {"damage": 3.0, "damage_type": "physical", "range": 3.0, "half_angle_degrees": 90.0}, context)
	var damaged := _log.named("player_damaged")
	assert_int(damaged.size()).is_equal(1)
	assert_str(damaged[0]["origin"]).is_equal("enemy")
	assert_float(damaged[0]["amount"]).is_greater(0.0)


func test_a_card_cast_through_the_slot_controller_stamps_card_and_its_id() -> void:
	var main := _spawn_main()
	var enemy := _enemy_at(main, Vector3(0, 0, -1.5))
	await _frames(2)
	enemy.set_physics_process(false)
	var card: Dictionary = {"id": "test_origin_card", "effects": [{"template": "aoe", "params": {"damage": 1.0, "damage_type": "fire", "radius": 4.0}}]}
	main.player.card_slots._cast_card(card)
	assert_array(_origins("hit_landed")).contains(["card:test_origin_card"])


# --- rooms -------------------------------------------------------------------------------------

func test_room_started_and_room_cleared_fire_from_the_run() -> void:
	RunSession.clear()
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	var started := _log.named("room_started")
	assert_int(started.size()).is_equal(1)
	assert_int(started[0]["index"]).is_equal(0)
	assert_str(started[0]["type"]).is_equal("combat")
	main.run_controller._finish_room(0.0)
	var cleared := _log.named("room_cleared")
	assert_int(cleared.size()).is_equal(1)
	assert_int(cleared[0]["index"]).is_equal(0)
	RunSession.clear()
