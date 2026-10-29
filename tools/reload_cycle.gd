extends Node
## Real scene-reload soak test for Slice 1 (death and game over).
## Loads the real Main scene, then repeatedly: kill the player, wait for
## game_over_ready, restart_arena() (called twice on purpose), and check the
## fresh arena. Also covers a restart issued mid slow-mo and a restart while
## the old scene still has a pending death-beat timer.
##
## Runs as a scene (autoloads like Juice are only resolvable that way).
## Run: powershell -File tools\run_reload_cycle.ps1 [-Cycles 5]
## Exits 0 on success, 1 on any failed check. Engine errors (push_error, script
## errors) are NOT caught here; the wrapper script scans the output for them.

const MAIN_PATH := "res://scenes/main/Main.tscn"
const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const ENEMY_PATH := "res://scenes/enemies/MeleeChaser.tscn"
const SETTLE_FRAMES := 8
const BEAT_TIMEOUT_MSEC := 6000
const TIME_SCALE_GRACE_MSEC := 50

var _failures: Array[String] = []
var _cycles: int = 5
var _lags_ms: Array[float] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cycles="):
			_cycles = maxi(1, int(arg.substr(9)))
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
		print("  FAIL: " + message)


func _main() -> Main:
	return get_tree().current_scene as Main


func _enemy_count(main: Node) -> int:
	var count := 0
	for child in main.get_children():
		if child is Enemy:
			count += 1
	return count


func _frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _snapshot(label: String) -> Dictionary:
	var snap := {
		"label": label,
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"time_scale": Engine.time_scale,
	}
	print("  [%s] orphans=%d objects=%d nodes=%d time_scale=%s" % [label, snap["orphans"], snap["objects"], snap["nodes"], snap["time_scale"]])
	return snap


## Fresh-arena invariants, checked after every (re)load.
func _check_fresh(label: String) -> void:
	var main := _main()
	_check(main != null, "%s: no current_scene Main" % label)
	if main == null:
		return
	var player := main.player
	_check(not main.is_game_over(), "%s: is_game_over() still true" % label)
	_check(not player.is_dead(), "%s: player still dead" % label)
	_check(is_equal_approx(player.health.current_health, player.health.get_max_health()), "%s: HP %s not full" % [label, player.health.current_health])
	_check(player.health.current_health > 0.0, "%s: HP not above 0" % label)
	_check(is_equal_approx(Engine.time_scale, 1.0), "%s: time_scale %s" % [label, Engine.time_scale])
	_check(not get_tree().paused, "%s: tree paused" % label)
	var plan: WavePlan = main.enemy_spawner.plan
	_check(_enemy_count(main) == 0, "%s: %d enemies in a fresh arena (first wave is delayed)" % [label, _enemy_count(main)])
	_check(plan != null and plan.stages_started() == 0, "%s: wave table not reset (stages started)" % label)
	_check(plan != null and plan.stage_wait_left() > float(plan.config["first_wave_delay"]) - 1.5, "%s: wave clock not reset (%s left)" % [label, plan.stage_wait_left() if plan != null else -1.0])
	_check(is_instance_valid(main.camera_rig) and main.camera_rig.camera.current, "%s: no current camera" % label)
	var go: Node = main.get_node_or_null("GameOverScreen")
	_check(go != null and not (go as CanvasLayer).visible, "%s: Game Over screen missing or visible on fresh arena" % label)
	# C1-f: zone and pass-through state must not leak from the previous arena.
	_check(not Enemy.is_player_body_suppressed(), "%s: the static pass-through flag leaked into the new arena" % label)
	_check(not player.is_pass_through(), "%s: new player is already passing through enemies" % label)
	if PlayerConfig.collide_with_enemies():
		_check((player.collision_mask & CollisionLayers.ENEMY_BODY) != 0, "%s: player mask lost the enemy-body bit" % label)
	var zones: Node = main.get_node_or_null(ZoneManager.NODE_NAME)
	_check(zones == null or (zones as ZoneManager).live_count() == 0, "%s: live zones in a fresh arena" % label)


## C1-f: puts the real zone and pass-through paths into the arena that is about to be killed and
## reloaded: a Fire Wall placed through the real template, and a pass-through grant taken while an
## enemy overlaps the player (so the restore is the deferred kind). Casts through the real
## EffectTemplates, not through input, so the soak stays deterministic.
func _arm_zone_and_pass_through(main: Main, label: String) -> void:
	var enemy: Enemy = (load(ENEMY_PATH) as PackedScene).instantiate()
	main.add_child(enemy)
	enemy.global_position = main.player.global_position + Vector3(0.0, 0.0, -0.3)
	await _frames(2)
	var wall: Dictionary = CardDatabase.get_card("fire_wall")
	var context := EffectContext.new(main.player, main, "player")
	context.rng = main.player.status_rng
	for effect: Dictionary in wall["effects"]:
		EffectTemplates.execute(effect["template"], effect["params"], context)
	var zones := ZoneManager.for_world(main)
	_check(zones != null and zones.live_count() >= 1, "%s: Fire Wall did not place a zone" % label)
	main.player.grant_pass_through(30.0)
	_check(main.player.is_pass_through(), "%s: pass-through grant did not start" % label)
	_check(Enemy.is_player_body_suppressed(), "%s: static pass-through flag not set" % label)
	await _frames(2)

func _wait_game_over(main: Main) -> bool:
	var deadline := Time.get_ticks_msec() + BEAT_TIMEOUT_MSEC
	while not main.is_game_over() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return main.is_game_over()


func _kill(main: Main) -> void:
	main.player.health.take_damage(main.player.health.get_max_health() * 2.0, "physical")


func _run() -> void:
	var packed: PackedScene = load(MAIN_PATH)
	var first: Node = packed.instantiate()
	get_tree().root.add_child(first)
	get_tree().current_scene = first
	# The first instance was added before it was current_scene, so its Game Over
	# screen could not find Main in _ready. Bind by hand; every reloaded arena
	# (cycles 1..N) goes through the real reload path and binds itself.
	(first.get_node("GameOverScreen") as GameOverScreen).bind(first)
	await _frames(SETTLE_FRAMES)
	print("Reload cycle soak: %d full cycles + mid-slow-mo + double-call" % _cycles)
	_check_fresh("initial")
	var baseline := _snapshot("baseline")
	var snaps: Array[Dictionary] = []

	for cycle in range(1, _cycles + 1):
		var main := _main()
		var old_id := main.get_instance_id()
		await _arm_zone_and_pass_through(main, "cycle %d" % cycle)
		_kill(main)
		_check(not main.player.is_pass_through(), "cycle %d: pass-through survived the death" % cycle)
		_check(not Enemy.is_player_body_suppressed(), "cycle %d: static pass-through flag survived the death" % cycle)
		_check(main.player.is_dead(), "cycle %d: player not dead after lethal damage" % cycle)
		_check(is_equal_approx(Engine.time_scale, 0.25), "cycle %d: slow-mo not active (time_scale %s)" % [cycle, Engine.time_scale])
		# Hit again while dead: must not die twice or restart anything.
		main.player.health.take_damage(5.0, "physical")
		var reached := await _wait_game_over(main)
		_check(reached, "cycle %d: game_over_ready never fired within %d ms" % [cycle, BEAT_TIMEOUT_MSEC])
		_check((main.get_node("GameOverScreen") as CanvasLayer).visible, "cycle %d: Game Over screen not visible" % cycle)
		# Juice resets time_scale by wall clock in its own _process; the Game Over timer (delta
		# accumulated) can fire a frame earlier than that clock. Measure the lag instead of
		# hiding it: it must stay within TIME_SCALE_GRACE_MSEC and must not grow with the cycle.
		var wait_start := Time.get_ticks_usec()
		while not is_equal_approx(Engine.time_scale, 1.0) and Time.get_ticks_usec() - wait_start < TIME_SCALE_GRACE_MSEC * 1000:
			await get_tree().process_frame
		var lag_ms := float(Time.get_ticks_usec() - wait_start) / 1000.0
		_lags_ms.append(lag_ms)
		print("  [cycle %d] time_scale lag after game_over_ready: %.2f ms" % [cycle, lag_ms])
		_check(is_equal_approx(Engine.time_scale, 1.0), "cycle %d: time_scale %s after beat" % [cycle, Engine.time_scale])
		main.restart_arena()
		main.restart_arena()  # double-call must be ignored
		await _frames(SETTLE_FRAMES)
		_check(_main() != null and _main().get_instance_id() != old_id, "cycle %d: scene was not replaced" % cycle)
		_check(not is_instance_valid(main), "cycle %d: old Main not freed" % cycle)
		_check_fresh("cycle %d" % cycle)
		snaps.append(_snapshot("cycle %d" % cycle))

	# Restart issued mid slow-mo, before game_over_ready.
	var mid := _main()
	var mid_id := mid.get_instance_id()
	await _arm_zone_and_pass_through(mid, "mid-slow-mo")
	_kill(mid)
	await _frames(3)
	_check(is_equal_approx(Engine.time_scale, 0.25), "mid-slow-mo: time_scale %s, expected 0.25" % Engine.time_scale)
	_check(not mid.is_game_over(), "mid-slow-mo: game over announced too early")
	mid.restart_arena()
	await _frames(SETTLE_FRAMES)
	_check(_main().get_instance_id() != mid_id, "mid-slow-mo: scene not replaced")
	_check_fresh("mid-slow-mo restart")
	# Outlive the old beat timer (0.9 s wall clock): nothing should fire on the new scene.
	var wait_until := Time.get_ticks_msec() + 1300
	while Time.get_ticks_msec() < wait_until:
		await get_tree().process_frame
	_check(not _main().is_game_over(), "stale beat timer announced game over on the new arena")
	_check(is_equal_approx(Engine.time_scale, 1.0), "stale beat: time_scale %s" % Engine.time_scale)
	snaps.append(_snapshot("after mid-slow-mo"))

	# Reload while the buff and a zone are live and the player is NOT dead (leaving the tree mid-grant).
	var live := _main()
	var live_id := live.get_instance_id()
	await _arm_zone_and_pass_through(live, "live reload")
	live.restart_arena()
	await _frames(SETTLE_FRAMES)
	_check(_main().get_instance_id() != live_id, "live reload: scene not replaced")
	_check_fresh("live reload")
	snaps.append(_snapshot("after live reload"))

	await _run_mode_soak(snaps)
	await _boss_soak(snaps)

	# Orphan / object growth: compare last full cycle to the first.
	if snaps.size() >= 2:
		var first_cycle: Dictionary = snaps[0]
		var last_cycle: Dictionary = snaps[_cycles - 1]
		_check(int(last_cycle["orphans"]) <= int(first_cycle["orphans"]) + 2, "orphan nodes grew: %d -> %d" % [first_cycle["orphans"], last_cycle["orphans"]])
		_check(int(last_cycle["nodes"]) <= int(first_cycle["nodes"]) + 40, "node count grew: %d -> %d" % [first_cycle["nodes"], last_cycle["nodes"]])
		_check(int(last_cycle["objects"]) <= int(first_cycle["objects"]) + 200, "object count grew: %d -> %d" % [first_cycle["objects"], last_cycle["objects"]])
	print("baseline orphans=%d objects=%d" % [baseline["orphans"], baseline["objects"]])

	if _failures.is_empty():
		print("RELOAD CYCLE OK")
		get_tree().quit(0)
	else:
		print("RELOAD CYCLE FAILED: %d problem(s)" % _failures.size())
		get_tree().quit(1)


# ---- Milestone 3a: run mode ----

## Replaces the current scene with a fresh RunMain (a normal launch) on top of whatever RunSession holds.
func _enter_run_main() -> Main:
	var old: Node = get_tree().current_scene
	if old != null:
		get_tree().root.remove_child(old)
		old.queue_free()
	var run_main: Node = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	get_tree().root.add_child(run_main)
	get_tree().current_scene = run_main
	await _frames(SETTLE_FRAMES)
	return run_main as Main


func _check_run_fresh(label: String, expected_room: int) -> void:
	var main := _main()
	_check(main != null and main.run_controller != null, "%s: no run controller" % label)
	if main == null or main.run_controller == null:
		return
	_check(main.run_controller.room_number() == expected_room, "%s: room %d, expected %d" % [label, main.run_controller.room_number(), expected_room])
	_check(not main.is_game_over(), "%s: game over still announced" % label)
	_check(not main.player.is_dead(), "%s: player dead in a new room" % label)
	_check(not main.player.health.damage_immune, "%s: damage immunity leaked into a new room" % label)
	_check(is_equal_approx(Engine.time_scale, 1.0) and not get_tree().paused, "%s: time scale or pause leaked" % label)
	_check(not Enemy.is_player_body_suppressed(), "%s: pass-through flag leaked" % label)
	_check(_enemy_count(main) == 0, "%s: %d enemies in a fresh room" % [label, _enemy_count(main)])
	for slot_type: String in CardSlotController.SLOT_TYPE_ORDER:
		_check(main.player.card_slots.get_slot(slot_type).cooldown_remaining == 0.0, "%s: slot %s cooldown carried over" % [label, slot_type])
	var deck: Array[String] = main.player.card_slots.owned_card_ids()
	deck.sort()
	var state_deck: Array[String] = RunSession.current.deck.duplicate()
	state_deck.sort()
	_check(deck == state_deck, "%s: player deck differs from the RunState deck" % label)
	_check(SceneSelfCheck.find_problems(main).is_empty(), "%s: SceneSelfCheck problems %s" % [label, str(SceneSelfCheck.find_problems(main))])


func _run_mode_soak(snaps: Array[Dictionary]) -> void:
	print("Run-mode soak: mid-run reload, room transition, death -> Try again, win -> New run")
	RunSession.clear()
	var first_state := RunSession.begin_new_run(555)
	first_state.room_index = 3
	first_state.max_hp = 100.0
	first_state.hp = 60.0
	var main := await _enter_run_main()
	_check_run_fresh("run start (room 4)", 4)
	_check(is_equal_approx(main.player.health.current_health, 60.0), "run start: HP %s, expected the carried 60" % main.player.health.current_health)
	await _arm_zone_and_pass_through(main, "run mid-room")

	# 1. Reload in the middle of a live room: that is "Try again" semantics, a new run with a new seed.
	var seed_before := RunSession.current.seed_value
	var mid_id := main.get_instance_id()
	main.restart_arena()
	await _frames(SETTLE_FRAMES)
	_check(_main().get_instance_id() != mid_id and not is_instance_valid(main), "run mid-reload: scene not replaced")
	_check(RunSession.current != first_state and RunSession.current.seed_value != seed_before, "run mid-reload: the run kept its seed or state")
	_check(RunSession.current.room_index == 0 and RunSession.current.history.is_empty() and RunSession.current.rejects_remaining == 3, "run mid-reload: state leaked into the new run")
	_check_run_fresh("run mid-reload", 1)
	snaps.append(_snapshot("after run mid-reload"))

	# 2. A cleared room continues into the next one with HP and deck carried and cooldowns reset.
	main = _main()
	main.player.health.take_damage(9.0, "physical")
	var hp_carried := main.player.health.current_health
	main.player.card_slots.try_use("attack_single")
	main.run_controller._finish_room(0.0)
	_check(main.run_controller.is_cleared(), "continue: room not cleared")
	var room_id := main.get_instance_id()
	main.run_controller.continue_to_next_room(true)
	await _frames(SETTLE_FRAMES)
	_check(_main().get_instance_id() != room_id, "continue: scene not replaced")
	_check_run_fresh("continue", 2)
	_check(is_equal_approx(_main().player.health.current_health, hp_carried), "continue: HP %s, expected %s" % [_main().player.health.current_health, hp_carried])
	snaps.append(_snapshot("after continue"))

	# 2b. 3b: a reload in the middle of a reward reopens the same offer without replaying (or re-recording) the room.
	main = _main()
	main.run_controller._finish_room(0.0)
	var reward_state: RunState = RunSession.current
	_check(reward_state.pending == RunState.PENDING_REWARD and reward_state.offer.size() == RunConfig.offer_size(), "reward: no offer after a won room (pending '%s')" % reward_state.pending)
	var offer_before: Array[String] = reward_state.offer.duplicate()
	var history_before: int = reward_state.history.size()
	var reward_id := main.get_instance_id()
	main = await _enter_run_main()  # a reload on top of the same RunSession
	_check(main.get_instance_id() != reward_id, "reward reload: scene not replaced")
	_check(RunSession.current == reward_state and reward_state.offer == offer_before, "reward reload: the offer changed or the state was replaced")
	_check(reward_state.history.size() == history_before, "reward reload: the room was recorded twice")
	_check(main.run_controller.is_cleared() and main.run_controller.has_choice(), "reward reload: the choice did not reopen")
	_check(_enemy_count(main) == 0 and main.enemy_spawner.alive_count() == 0, "reward reload: the room was fought again")
	_check((main.get_node("RoomClearedScreen") as RunPromptScreen).is_open(), "reward reload: the reward screen is not open")
	_check(SceneSelfCheck.find_problems(main).is_empty(), "reward reload: SceneSelfCheck problems %s" % str(SceneSelfCheck.find_problems(main)))
	var picked: String = offer_before[0]
	var deck_size_before: int = reward_state.deck.size()
	reward_id = main.get_instance_id()
	_check(bool(main.run_controller.choose("card:" + picked)["ok"]), "reward pick: refused")
	await _frames(SETTLE_FRAMES)
	_check(_main().get_instance_id() != reward_id, "reward pick: the next room did not load")
	_check_run_fresh("reward pick", 3)
	_check(reward_state.deck.size() == deck_size_before + 1 and _main().player.card_slots.owned_card_ids().has(picked), "reward pick: the card is not in the deck")
	snaps.append(_snapshot("after reward pick"))

	# 2c. 3b: Try again from a reward state starts a fresh run with nothing of the reward left over.
	main = _main()
	main.run_controller._finish_room(0.0)
	_check(RunSession.current.has_pending(), "try again from reward: no reward open")
	var reward_seed: int = RunSession.current.seed_value
	var open_state: RunState = RunSession.current
	reward_id = main.get_instance_id()
	main.restart_arena()
	await _frames(SETTLE_FRAMES)
	_check(_main().get_instance_id() != reward_id, "try again from reward: scene not replaced")
	_check(RunSession.current != open_state and RunSession.current.seed_value != reward_seed, "try again from reward: the run kept its state or seed")
	_check(not RunSession.current.has_pending() and RunSession.current.offer.is_empty() and RunSession.current.choice_log.is_empty(), "try again from reward: reward state leaked")
	_check(RunSession.current.rejects_remaining == 3 and RunSession.current.deck == RunConfig.starting_deck(), "try again from reward: rejects or deck leaked")
	_check_run_fresh("try again from reward", 1)
	snaps.append(_snapshot("after try again from reward"))

	# 3. Death, Game Over, Try again: a new run with a new seed.
	main = _main()
	var seed_dead := RunSession.current.seed_value
	_kill(main)
	_check(await _wait_game_over(main), "run death: game_over_ready never fired")
	_check((main.get_node("GameOverScreen") as CanvasLayer).visible, "run death: Game Over screen not visible")
	_check(RunSession.current.outcome == "lost", "run death: outcome %s" % RunSession.current.outcome)
	var dead_id := main.get_instance_id()
	((main.get_node("GameOverScreen") as GameOverScreen).get_node("Root/Center/Column/TryAgain") as Button).pressed.emit()
	await _frames(SETTLE_FRAMES)
	_check(_main().get_instance_id() != dead_id, "run death: Try again did not replace the scene")
	_check(RunSession.current.seed_value != seed_dead and RunSession.current.outcome == "", "run death: Try again kept the old seed or outcome")
	_check_run_fresh("try again", 1)
	_check(is_equal_approx(_main().player.health.current_health, _main().player.health.max_health), "try again: HP not full")
	snaps.append(_snapshot("after try again"))

	# 4. A won run: the last room cleared shows the win screen, "New run" starts a fresh seed.
	var total: int = RunGenerator.generate(RunSession.current.seed_value, RunConfig.get_config()).size()
	RunSession.current.room_index = total - 1  # jump to the boss room: _enter_run_main builds its scene from the state
	var boss_main := await _enter_run_main()
	_check(boss_main.run_controller.is_last_room(), "win: not the last room")
	boss_main.run_controller._finish_room(0.0)
	_check((boss_main.get_node("WinScreen") as CanvasLayer).visible, "win: win screen not visible")
	_check(RunSession.current.outcome == "won", "win: outcome %s" % RunSession.current.outcome)
	var win_seed := RunSession.current.seed_value
	var win_id := boss_main.get_instance_id()
	(boss_main.get_node("WinScreen") as RunPromptScreen).button.pressed.emit()
	await _frames(SETTLE_FRAMES)
	_check(_main().get_instance_id() != win_id, "win: New run did not replace the scene")
	_check(RunSession.current.seed_value != win_seed and RunSession.current.room_index == 0 and RunSession.current.outcome == "", "win: the new run leaked state")
	_check_run_fresh("new run after win", 1)
	snaps.append(_snapshot("after win"))
	RunSession.clear()


# ---- Milestone 3c: the boss fight ----

## Spawns the boss of a boss room at once (the spawner's first-wave delay skipped) and returns it.
func _spawn_boss_in(main: Main) -> Boss:
	main.enemy_spawner._process(3.0)
	for child in main.get_children():
		if child is Boss:
			return child as Boss
	return null


func _check_boss_gone(label: String) -> void:
	_check(get_tree().get_nodes_in_group(Boss.GROUP).is_empty(), "%s: a Boss from the old scene is still in the tree" % label)
	_check(is_equal_approx(Engine.time_scale, 1.0), "%s: time_scale %s" % [label, Engine.time_scale])
	_check(not _main().player.health.damage_immune, "%s: the old fight's damage immunity leaked onto the new player" % label)
	_check(not Enemy.is_player_body_suppressed(), "%s: pass-through flag leaked" % label)


func _boss_soak(snaps: Array[Dictionary]) -> void:
	print("Boss soak: reload mid-fight, mid-phase-transition, mid-death-beat")
	RunSession.clear()
	var total: int = RunGenerator.generate(RunSession.begin_new_run(777).seed_value, RunConfig.get_config()).size()
	RunSession.current.room_index = total - 1
	var main := await _enter_run_main()
	var boss := _spawn_boss_in(main)
	_check(boss != null, "boss soak: no Boss spawned in the boss room")
	if boss == null:
		return
	_check(main.run_controller.current_boss() == boss, "boss soak: the controller does not expose the boss")
	await _frames(5)
	boss._attack_cooldown_remaining = 0.0
	boss.global_position = main.player.global_position + Vector3(0.0, 0.0, -3.0)
	var waited: int = 0
	while boss.state_name() == "CHASE" and waited < 120:
		await get_tree().physics_frame
		waited += 1
	_check(boss.state_name() != "CHASE", "boss soak: the boss never started an attack")
	# 1. Reload (a fresh scene on the same run) in the middle of a wind-up: the room starts over, nothing of the fight is left.
	var old_id := main.get_instance_id()
	main = await _enter_run_main()
	_check(main.get_instance_id() != old_id, "boss reload mid-fight: scene not replaced")
	await _frames(SETTLE_FRAMES)
	_check_boss_gone("boss reload mid-fight")
	_check_run_fresh("boss reload mid-fight", total)
	var again := _spawn_boss_in(main)
	_check(again != null and again != boss and is_equal_approx(again.health.current_health, again.health.max_health) and again.phase_index == 0, "boss reload mid-fight: the new boss is not fresh")
	snaps.append(_snapshot("after boss mid-fight reload"))

	# 2. Reload during a phase transition (the boss is invulnerable and roaring), through Try again.
	again.health.take_damage(again.health.max_health * 0.8, "physical")
	_check(again.is_transitioning() and again.health.damage_immune, "boss soak: no transition after a big hit")
	old_id = main.get_instance_id()
	main.restart_arena()
	await _frames(SETTLE_FRAMES)
	_check(_main().get_instance_id() != old_id, "boss reload mid-transition: scene not replaced")
	_check_boss_gone("boss reload mid-transition")
	_check(RunSession.current.room_index == 0, "boss reload mid-transition: Try again did not start a new run")
	_check_run_fresh("boss reload mid-transition", 1)
	# Outlive the transition's length: nothing from the old boss may fire into the new scene.
	var until_msec: int = Time.get_ticks_msec() + 1600
	while Time.get_ticks_msec() < until_msec:
		await get_tree().process_frame
	_check_boss_gone("boss reload mid-transition, after the old transition would have ended")
	snaps.append(_snapshot("after boss mid-transition reload"))

	# 3. Reload during the death beat (slow-mo running, the player already protected).
	RunSession.current.room_index = total - 1
	main = await _enter_run_main()
	var dying := _spawn_boss_in(main)
	_check(dying != null, "boss soak: no Boss for the death-beat reload")
	if dying == null:
		return
	await _frames(3)
	dying.health.hp_floor = 0.0
	dying.health.take_damage(dying.health.max_health * 2.0, "physical")
	_check(dying.is_defeated() and main.player.health.damage_immune, "boss soak: the kill did not start the death beat")
	_check(is_equal_approx(Engine.time_scale, 0.25), "boss soak: the death beat has no slow-mo (time_scale %s)" % Engine.time_scale)
	old_id = main.get_instance_id()
	main.restart_arena()
	await _frames(SETTLE_FRAMES)
	_check(_main().get_instance_id() != old_id, "boss reload mid-death-beat: scene not replaced")
	_check_boss_gone("boss reload mid-death-beat")
	until_msec = Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < until_msec:
		await get_tree().process_frame
	_check(not _main().is_game_over() and not _main().run_controller.is_cleared(), "boss reload mid-death-beat: the old beat or win leaked into the new run")
	_check((_main().get_node("WinScreen") as CanvasLayer).visible == false, "boss reload mid-death-beat: a win screen showed in the new run")
	snaps.append(_snapshot("after boss death-beat reload"))
	RunSession.clear()
