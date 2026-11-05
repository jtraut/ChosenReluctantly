class_name Bd2aRelicManagerTest
extends GdUnitTestSuite
## BD2-A item 2: RelicManager. Modifier application, the trigger filter, the internal cooldown, every_nth, the recursion
## guard (including the status-origin loop), the signal ux flashes a chip on, and effects run for real through
## EffectTemplates with origin "relic:<id>".

const VALID_DIR := "res://tests/fixtures/relics_valid"
const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"

var _log: RelayLog
var _fired: Array[String] = []


func before_test() -> void:
	BodyFlag.set_collide(false)
	CombatEvents.reset()
	_log = RelayLog.new(CombatEvents)
	_fired = []
	RelicDatabase.load_all(VALID_DIR)


func after_test() -> void:
	_log.stop()
	BodyFlag.reset()
	CombatEvents.reset()
	RelicDatabase.load_all()
	Juice.reset()
	GamePause.reset()
	Engine.time_scale = 1.0


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	return main


func _manager(main: Main, catalog: Dictionary = {}) -> RelicManager:
	var manager := RelicManager.new()
	main.add_child(manager)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	manager.configure(main.player, main, rng, CombatEvents, catalog)
	return manager


## A manager whose effects are only counted ("trigger relic_id:index event"), so a test needs no scene.
func _counting_manager(main: Main, catalog: Dictionary = {}) -> RelicManager:
	var manager := _manager(main, catalog)
	manager.effect_runner = func(trigger: Dictionary, event: Dictionary) -> void:
		_fired.append("%s:%d %s" % [trigger["relic_id"], trigger["index"], event["event"]])
	return manager


func _target(main: Main, hp: float = 100.0, at: Vector3 = Vector3.ZERO) -> RelayTarget:
	var target := RelayTarget.new("enemy", hp)
	main.add_child(target)
	target.global_position = at
	return target


func _burn() -> Dictionary:
	return StatusDatabase.get_status("burn")


func _catalog_of(relics: Array) -> Dictionary:
	var catalog: Dictionary = {}
	for relic: Variant in relics:
		catalog[String((relic as Dictionary)["id"])] = relic
	return catalog


func _hit_relic(id: String, filter: Dictionary, cooldown: float = 0.0, at: String = "player") -> Dictionary:
	return {"id": id, "name": id, "pool": "neutral", "rarity": "tier1", "sources": ["elite"], "flavor_text": "",
			"triggers": [{"event": "hit_landed", "filter": filter, "at": at, "internal_cooldown": cooldown,
			"effects": [{"template": "aoe", "params": {"damage": 1.0, "damage_type": "fire", "radius": 6.0}}]}]}


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


# --- inert and modifiers -----------------------------------------------------------------------

func test_a_manager_without_relics_connects_to_nothing() -> void:
	var main := _spawn_main()
	var before: int = CombatEvents.hit_landed.get_connections().size()
	var manager := _manager(main)
	manager.load_relics([] as Array[String])
	assert_int(manager.listening_count()).is_equal(0)
	assert_int(CombatEvents.hit_landed.get_connections().size()).is_equal(before)
	assert_bool(manager.is_processing()).is_false()
	assert_bool(manager.is_physics_processing()).is_false()


func test_modifiers_are_applied_to_the_player_removed_with_the_relic_and_reapplying_is_harmless() -> void:
	var main := _spawn_main()
	var manager := _manager(main)
	var speed_before: float = main.player.stat_modifiers.apply("move_speed", 10.0)
	var burn_before: float = main.player.stat_modifiers.apply("status_damage_mult.burn", 1.0)
	manager.load_relics(["test_grudge"] as Array[String])
	assert_float(main.player.stat_modifiers.apply("move_speed", 10.0)).is_equal_approx(speed_before * 1.1, 0.0001)
	assert_float(main.player.stat_modifiers.apply("status_damage_mult.burn", 1.0)).is_equal_approx(burn_before * 1.25, 0.0001)
	manager.apply_modifiers()
	manager.apply_modifiers()  # room start applies again; the ids replace themselves
	assert_float(main.player.stat_modifiers.apply("move_speed", 10.0)).is_equal_approx(speed_before * 1.1, 0.0001)
	assert_bool(manager.remove_relic("test_grudge")).is_true()
	assert_bool(manager.remove_relic("test_grudge")).is_false()
	assert_float(main.player.stat_modifiers.apply("move_speed", 10.0)).is_equal_approx(speed_before, 0.0001)
	assert_float(main.player.stat_modifiers.apply("status_damage_mult.burn", 1.0)).is_equal_approx(burn_before, 0.0001)


func test_two_relics_modifiers_stack_and_an_unknown_or_duplicate_relic_is_refused() -> void:
	var main := _spawn_main()
	var manager := _manager(main)
	assert_bool(manager.add_relic("test_grudge")).is_true()
	assert_bool(manager.add_relic("test_wizard")).is_true()  # +0.5 additive move_speed
	assert_bool(manager.add_relic("test_wizard")).is_false()
	assert_bool(manager.add_relic("no_such_relic")).is_false()
	assert_array(manager.relic_ids()).is_equal(["test_grudge", "test_wizard"])
	var base: float = 10.0
	assert_float(main.player.stat_modifiers.apply("move_speed", base)).is_equal_approx((base + 0.5) * 1.1, 0.0001)


# --- the filter --------------------------------------------------------------------------------

func test_a_trigger_fires_only_when_the_whole_filter_matches() -> void:
	var main := _spawn_main()
	var manager := _counting_manager(main)
	manager.load_relics(["test_pyre"] as Array[String])
	var enemy := _target(main)
	enemy.status_manager.apply_status("bleed", StatusDatabase.get_status("bleed"), 0.3, null, "card:x")
	enemy.status_manager._process(0.4)  # a bleed ending: the wrong status
	assert_array(_fired).is_empty()
	enemy.status_manager.apply_status("burn", _burn(), 5.0, null, "card:x")
	enemy.status_manager.consume_status("burn")  # the wrong reason
	assert_array(_fired).is_empty()
	var ally := RelayTarget.new("player", 100.0)  # the wrong team
	main.add_child(ally)
	ally.status_manager.apply_status("burn", _burn(), 0.5, null, "card:x")
	ally.status_manager._process(0.6)
	assert_array(_fired).is_empty()
	enemy.status_manager.apply_status("burn", _burn(), 0.5, null, "card:x")
	enemy.status_manager._process(0.6)  # the right one
	assert_array(_fired).is_equal(["test_pyre:0 status_ended"])


func test_the_trigger_matches_on_owner_died_too() -> void:
	var main := _spawn_main()
	var manager := _counting_manager(main)
	manager.load_relics(["test_pyre"] as Array[String])
	var enemy := _target(main, 2.0)
	enemy.status_manager.apply_status("burn", _burn(), 5.0, null, "card:x")
	enemy.status_manager._process(1.0)  # the tick kills it
	assert_array(_fired).is_equal(["test_pyre:0 status_ended"])


func test_origin_target_has_status_damage_type_kind_and_min_amount_filters() -> void:
	var main := _spawn_main()
	var relic := _hit_relic("filtered", {"origin": "card:*", "damage_type": "fire", "kind": ["hit", "echo"], "target_has_status": "burn", "min_amount": 3.0, "target_team": "enemy"})
	var manager := _counting_manager(main, _catalog_of([relic]))
	manager.load_relics(["filtered"] as Array[String])
	var enemy := _target(main)
	var hit := func(amount: float, type: String, kind: StringName, origin: String) -> void:
		enemy.hurtbox.receive_damage(amount, type, Vector3.ZERO, null, kind, origin)
	hit.call(5.0, "fire", Health.KIND_HIT, "card:a")
	assert_array(_fired).is_empty()  # not burning yet
	enemy.status_manager.apply_status("burn", _burn(), 30.0, null, "card:a")
	hit.call(5.0, "fire", Health.KIND_HIT, "light")  # wrong origin
	hit.call(5.0, "physical", Health.KIND_HIT, "card:a")  # wrong damage type
	hit.call(5.0, "fire", Health.KIND_DOT, "card:a")  # wrong kind
	hit.call(2.0, "fire", Health.KIND_HIT, "card:a")  # too small
	assert_array(_fired).is_empty()
	hit.call(5.0, "fire", Health.KIND_ECHO, "card:b")
	assert_int(_fired.size()).is_equal(1)


func test_the_card_cast_filter_matches_slot_type_card_and_tag() -> void:
	var main := _spawn_main()
	var relic := {"id": "caster", "name": "c", "pool": "neutral", "rarity": "tier1", "sources": ["elite"], "flavor_text": "",
			"triggers": [{"event": "card_cast", "filter": {"slot_type": "utility", "tag": "Burn"}, "effects": [{"template": "heal", "params": {"amount": 1.0}}]}]}
	var manager := _counting_manager(main, _catalog_of([relic]))
	manager.load_relics(["caster"] as Array[String])
	CombatEvents.card_cast.emit("attack_aoe", "x", ["Burn"] as Array[String])
	CombatEvents.card_cast.emit("utility", "x", ["Area"] as Array[String])
	assert_array(_fired).is_empty()
	CombatEvents.card_cast.emit("utility", "x", ["Area", "Burn"] as Array[String])
	assert_int(_fired.size()).is_equal(1)


# --- internal cooldown and every_nth ----------------------------------------------------------

func test_internal_cooldown_blocks_a_second_firing_until_game_time_passes() -> void:
	var main := _spawn_main()
	var relic := _hit_relic("slow", {}, 2.0)
	var manager := _counting_manager(main, _catalog_of([relic]))
	manager.load_relics(["slow"] as Array[String])
	var enemy := _target(main)
	for i in range(5):
		enemy.hurtbox.receive_damage(1.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "light")
	assert_int(_fired.size()).override_failure_message("five hits in one instant fire once").is_equal(1)
	CombatEvents.step(1.9)
	enemy.hurtbox.receive_damage(1.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "light")
	assert_int(_fired.size()).is_equal(1)
	CombatEvents.step(0.2)
	enemy.hurtbox.receive_damage(1.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "light")
	assert_int(_fired.size()).is_equal(2)


func test_every_nth_fires_on_the_nth_matching_event_and_each_multiple() -> void:
	var main := _spawn_main()
	var manager := _counting_manager(main)
	manager.load_relics(["test_spite"] as Array[String])
	var enemy := _target(main)
	for i in range(8):
		enemy.hurtbox.receive_damage(1.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "light")
		if i == 2:
			enemy.hurtbox.receive_damage(1.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "heavy")  # not a light hit: not counted
	assert_int(_fired.size()).is_equal(2)  # the 4th and 8th light hit


func test_the_relic_triggered_signal_names_the_relic_the_trigger_and_the_event() -> void:
	var main := _spawn_main()
	var manager := _counting_manager(main)
	manager.load_relics(["test_pyre"] as Array[String])
	var seen: Array = []
	manager.relic_triggered.connect(func(relic_id: String, index: int, event_id: String) -> void: seen.append([relic_id, index, event_id]))
	var enemy := _target(main)
	enemy.status_manager.apply_status("burn", _burn(), 0.5, null, "card:x")
	enemy.status_manager._process(0.6)
	assert_array(seen).is_equal([["test_pyre", 0, "status_ended"]])


# --- effects for real --------------------------------------------------------------------------

func test_a_pyre_style_trigger_explodes_at_the_event_position_with_a_relic_origin() -> void:
	var main := _spawn_main()
	var manager := _manager(main)
	manager.load_relics(["test_pyre"] as Array[String])
	var burning := _target(main, 100.0, Vector3(8, 0, 8))
	var near := _target(main, 100.0, Vector3(9, 0, 8))  # 1 m from the burning one
	var far := _target(main, 100.0, Vector3(-8, 0, -8))  # nowhere near the burning one (and the player is at the origin)
	await _frames(2)  # the physics server learns the new bodies
	burning.status_manager.apply_status("burn", _burn(), 0.5, null, "card:x")
	burning.status_manager._process(0.6)
	assert_float(near.health.current_health).override_failure_message("the neighbour takes the 4 fire").is_equal_approx(96.0, 0.001)
	assert_float(far.health.current_health).is_equal(100.0)
	var origins: Array[String] = []
	for event: Dictionary in _log.named("hit_landed"):
		origins.append(String(event["origin"]))
	assert_bool(origins.has("relic:test_pyre")).is_true()


func test_a_trigger_aimed_at_the_event_target_applies_its_status_there() -> void:
	var main := _spawn_main()
	var manager := _manager(main)
	manager.load_relics(["test_spite"] as Array[String])
	var enemy := _target(main)
	for i in range(4):
		enemy.hurtbox.receive_damage(1.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "light")
	assert_bool(enemy.status_manager.has_status("burn")).is_true()
	var applied := _log.named("status_applied")
	assert_int(applied.size()).is_equal(1)
	assert_str(applied[0]["origin"]).is_equal("relic:test_spite")


# --- the recursion guard -----------------------------------------------------------------------

func test_a_relics_own_damage_does_not_trigger_relics_by_default() -> void:
	var main := _spawn_main()
	var relic := _hit_relic("echoer", {})
	var manager := _manager(main, _catalog_of([relic]))
	manager.load_relics(["echoer"] as Array[String])
	var a := _target(main, 100.0, Vector3(3, 0, 0))
	var b := _target(main, 100.0, Vector3(3, 0, 1))
	await _frames(2)
	a.hurtbox.receive_damage(1.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "light")
	assert_int(manager.fired_total()).override_failure_message("the explosion's own hits must not fire the relic again").is_equal(1)
	assert_float(b.health.current_health).is_less(100.0)  # it did explode


func test_allow_relic_origin_lets_a_chain_through_but_only_one_level_deep() -> void:
	var main := _spawn_main()
	var relic := _hit_relic("chainer", {"allow_relic_origin": true})
	var manager := _manager(main, _catalog_of([relic]))
	manager.load_relics(["chainer"] as Array[String])
	var a := _target(main, 1000.0, Vector3(3, 0, 0))
	var b := _target(main, 1000.0, Vector3(3, 0, 1))
	await _frames(2)
	a.hurtbox.receive_damage(1.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "light")
	# 1 top-level firing; its explosion hits a and b (2 events), each fires once at chain depth 1; those explosions' hits are blocked.
	assert_int(manager.fired_total()).is_equal(3)


func test_a_status_a_relic_applied_remembers_it_so_a_burn_ending_relic_does_not_loop() -> void:
	var main := _spawn_main()
	var manager := _counting_manager(main)
	manager.load_relics(["test_pyre"] as Array[String])
	var enemy := _target(main)
	# A burn that a relic applied: its end carries the relic origin, so Pyre ignores it.
	enemy.status_manager.apply_status("burn", _burn(), 0.5, null, "relic:test_spite")
	enemy.status_manager._process(0.6)
	assert_array(_fired).is_empty()
	# The same burn from a card: Pyre explodes.
	enemy.status_manager.apply_status("burn", _burn(), 0.5, null, "card:fire_kindling")
	enemy.status_manager._process(0.6)
	assert_int(_fired.size()).is_equal(1)
	# And the loop itself: spite applies burn (relic origin) and pyre explodes into the same target again, over many rounds.
	_fired.clear()
	var manager2 := _manager(main)
	manager2.load_relics(["test_spite", "test_pyre"] as Array[String])
	var looped := _target(main, 100000.0, Vector3(5, 0, 5))
	for round_index in range(12):
		looped.hurtbox.receive_damage(1.0, "physical", Vector3.ZERO, null, Health.KIND_HIT, "light")
		looped.status_manager._process(4.0)  # let any burn run out
	var explosions := 0
	for event: Dictionary in _log.named("hit_landed"):
		if String(event["origin"]) == "relic:test_pyre":
			explosions += 1
	assert_int(explosions).override_failure_message("a relic-applied burn must never set off Pyre").is_equal(0)


func test_a_relic_trigger_that_adds_itself_in_a_loop_is_stopped_by_the_depth_cap() -> void:
	# A zone_started trigger (no origin, so the origin guard cannot help) whose effect starts a zone: a true loop.
	var main := _spawn_main()
	var relic := {"id": "zoner", "name": "z", "pool": "neutral", "rarity": "tier1", "sources": ["elite"], "flavor_text": "",
			"triggers": [{"event": "zone_started", "at": "event_position",
			"effects": [{"template": "zone", "params": {"shape": "circle", "radius": 1.0, "duration": 1.0, "tick_interval": 0.5, "damage": 0.0, "damage_type": "fire", "max_range": 30.0}}]}]}
	var manager := _manager(main, _catalog_of([relic]))
	manager.load_relics(["zoner"] as Array[String])
	var context := EffectContext.new(main.player, main, "player")
	context.arena = main.player.get_arena_rect()
	context.aim_point = Vector3(2, 0, 2)
	EffectTemplates.execute("zone", {"shape": "circle", "radius": 1.0, "duration": 1.0, "tick_interval": 0.5, "damage": 0.0, "damage_type": "fire", "max_range": 30.0}, context)
	# the card's zone (not a relic) fires the relic once; its zone is the chain's 1st level and fires once more; its zone is blocked
	assert_int(manager.fired_total()).is_less_equal(2)
	assert_int(_log.named("zone_started").size()).is_less_equal(3)


# --- lifetime ----------------------------------------------------------------------------------

func test_removing_a_relic_or_freeing_the_manager_stops_its_triggers() -> void:
	var main := _spawn_main()
	var manager := _counting_manager(main)
	manager.load_relics(["test_pyre"] as Array[String])
	assert_int(manager.listening_count()).is_equal(1)
	manager.remove_relic("test_pyre")
	assert_int(manager.listening_count()).is_equal(0)
	manager.add_relic("test_pyre")
	var before: int = CombatEvents.status_ended.get_connections().size()
	manager.free()
	assert_int(CombatEvents.status_ended.get_connections().size()).is_equal(before - 1)


# --- the run ------------------------------------------------------------------------------------

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"


func test_the_run_builds_a_manager_from_the_run_state_only_when_it_holds_relics() -> void:
	RunSession.clear()
	var plain: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(plain)
	auto_free(plain)
	assert_object(plain.run_controller.relic_manager()).is_null()  # no relics: no manager, no connections, nothing changes
	RunSession.clear()
	var state := RunSession.begin_new_run(2)
	state.add_relic("test_grudge")
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	var manager := main.run_controller.relic_manager()
	assert_object(manager).is_not_null()
	assert_array(manager.relic_ids()).is_equal(["test_grudge"])
	assert_float(main.player.stat_modifiers.apply("status_damage_mult.burn", 1.0)).is_equal_approx(1.25, 0.0001)
	RunSession.clear()
