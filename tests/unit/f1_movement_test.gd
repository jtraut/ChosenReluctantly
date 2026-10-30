class_name F1MovementTest
extends GdUnitTestSuite
## F1 gameplay: every movement-slot card that moves the player passes through enemy bodies while it moves
## (data flag "pass_through" on the dash params), the dodge stays blocked, and the Reluctant Lunge hits a whole line.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"


func after_test() -> void:
	PlayerConfig.reload()
	Enemy.set_player_body_suppressed(false)
	Juice.reset()
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


func _enemy_at(main: Main, position: Vector3) -> Enemy:
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	enemy.position = position
	main.add_child(enemy)
	return enemy


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _settle(player: Player) -> void:
	for i in range(30):
		await _frames(1)
		if player.is_on_floor() and absf(player.global_position.y) < 0.05:
			return


func _cast(card_id: String, main: Main) -> void:
	var card := CardDatabase.get_card(card_id)
	var context := EffectContext.new(main.player, main, "player")
	for effect: Dictionary in card["effects"]:
		EffectTemplates.execute(effect["template"], effect["params"], context)


## Casts `card_id` toward the player's facing with an enemy every `spacing` metres from `first`; returns
## {"travelled", "damage": [per enemy], "overlap": bool, "pass": bool at the end}.
func _run_line(card_id: String, count: int, first: float, spacing: float) -> Dictionary:
	var main := _spawn_main()
	var player := main.player
	await _settle(player)
	var facing := player.get_aim_direction()
	var enemies: Array[Enemy] = []
	for i in range(count):
		enemies.append(_enemy_at(main, player.global_position + facing * (first + spacing * i)))
	await _frames(3)
	var before: Array[float] = []
	for enemy: Enemy in enemies:
		before.append(enemy.health.current_health)
	var start := player.global_position
	_cast(card_id, main)
	var max_y := 0.0
	for i in range(60):
		await _frames(1)
		max_y = maxf(max_y, player.global_position.y)
	var damage: Array[float] = []
	for i in range(count):
		damage.append(before[i] - enemies[i].health.current_health if is_instance_valid(enemies[i]) else before[i])
	return {"travelled": (player.global_position - start).dot(facing), "damage": damage, "max_y": max_y,
			"pass": player.is_pass_through(), "overlap": Enemy.any_body_overlaps(player.global_position, Player.PLAYER_BODY_RADIUS)}


# --- data -------------------------------------------------------------------------------------

func test_every_movement_card_that_dashes_sets_the_pass_through_flag() -> void:
	var seen: int = 0
	for card: Dictionary in CardDatabase.all_cards():
		if String(card["slot_type"]) != "movement":
			continue
		for effect: Dictionary in card["effects"]:
			if String(effect["template"]) == "dash":
				seen += 1
				assert_bool(bool((effect["params"] as Dictionary).get("pass_through", false))).override_failure_message("%s dashes without pass_through" % String(card["id"])).is_true()
	assert_int(seen).override_failure_message("expected the 6 dashing movement cards").is_equal(6)


func test_the_pass_through_param_must_be_a_bool() -> void:
	var ok: Array[String] = EffectTemplates.validate_params("dash", {"distance": 3.0, "speed": 10.0, "pass_through": true})
	assert_array(ok).is_empty()
	var bad: Array[String] = EffectTemplates.validate_params("dash", {"distance": 3.0, "speed": 10.0, "pass_through": 1})
	assert_array(bad).is_not_empty()


func test_the_wall_of_mild_fire_is_one_and_a_half_times_bigger() -> void:
	var params: Dictionary = (CardDatabase.get_card("fire_wall")["effects"][0] as Dictionary)["params"]
	assert_float(float(params["length"])).is_equal_approx(7.5, 0.001)
	assert_float(float(params["width"])).is_equal_approx(1.8, 0.001)


# --- behaviour --------------------------------------------------------------------------------

func test_lunge_on_a_line_of_three() -> void:
	var result: Dictionary = await _run_line("rogue_lunge_strike", 3, 1.5, 1.0)
	print("F1 LUNGE line of 3: ", result)
	assert_array(result["damage"] as Array).override_failure_message("every enemy on the line is hit once").is_equal([8.0, 8.0, 8.0])
	assert_float(float(result["travelled"])).override_failure_message("the full 3 m").is_equal_approx(3.0, 0.2)
	assert_float(float(result["max_y"])).is_less(0.3)


func test_each_dashing_movement_card_goes_through_a_body_and_ends_free() -> void:
	for card_id: String in ["fire_blaze_and_bail", "neutral_backward_leap", "rogue_ugh_fine_moving", "wizard_sideways_blink", "wizard_tactical_hover"]:
		# Forward dashes run into the enemy; the away_from_aim ones run away from it, so put the enemy behind.
		var away: bool = String(((CardDatabase.get_card(card_id)["effects"] as Array).back() as Dictionary)["params"].get("direction_mode", "")) == "away_from_aim"
		var main := _spawn_main()
		var player := main.player
		await _settle(player)
		var facing := player.get_aim_direction()
		var dir := -facing if away else facing
		_enemy_at(main, player.global_position + dir * 2.0)
		await _frames(3)
		var start := player.global_position
		_cast(card_id, main)
		for i in range(60):
			await _frames(1)
		var distance: float = float(((CardDatabase.get_card(card_id)["effects"] as Array).back() as Dictionary)["params"]["distance"])
		assert_float((player.global_position - start).dot(dir)).override_failure_message("%s was blocked by the body" % card_id).is_equal_approx(distance, 0.25)
		assert_bool(player.is_pass_through()).override_failure_message("%s left pass-through on" % card_id).is_false()
		assert_bool(Enemy.any_body_overlaps(player.global_position, Player.PLAYER_BODY_RADIUS)).override_failure_message("%s ended in a body" % card_id).is_false()
		main.queue_free()
		await _frames(2)


func test_a_dash_that_ends_inside_a_body_stays_ghosted_until_the_player_steps_out() -> void:
	var main := _spawn_main()
	var player := main.player
	await _settle(player)
	var facing := player.get_aim_direction()
	_enemy_at(main, player.global_position + facing * 4.0)  # exactly where a 4.0 m dash ends
	await _frames(3)
	_cast("rogue_ugh_fine_moving", main)
	await _frames(30)
	assert_bool(Enemy.any_body_overlaps(player.global_position, Player.PLAYER_BODY_RADIUS)).override_failure_message("setup: the dash should end inside the body").is_true()
	assert_bool(player.is_pass_through()).override_failure_message("still free to walk out, not wedged").is_true()
	assert_int(player.collision_mask & CollisionLayers.ENEMY_BODY).is_equal(0)
	# Step sideways out of it (a plain move, no flag): the body turns solid again, free of the enemy.
	var side := facing.cross(Vector3.UP).normalized()
	var start := player.global_position
	player.start_forced_move(side, 6.0, 0.4)
	await _frames(40)
	assert_float(player.global_position.distance_to(start)).is_greater(1.5)
	assert_bool(Enemy.any_body_overlaps(player.global_position, Player.PLAYER_BODY_RADIUS)).is_false()
	assert_bool(player.is_pass_through()).is_false()
	assert_int(player.collision_mask & CollisionLayers.ENEMY_BODY).is_equal(CollisionLayers.ENEMY_BODY)


func test_an_ungrabbed_ghost_turns_solid_again_at_the_restore_cap() -> void:
	var main := _spawn_main()
	var player := main.player
	await _settle(player)
	var facing := player.get_aim_direction()
	_enemy_at(main, player.global_position + facing * 4.0)
	await _frames(3)
	_cast("rogue_ugh_fine_moving", main)
	await _frames(int(Player.PASS_THROUGH_RESTORE_CAP * 60.0) + 40)
	assert_bool(player.is_pass_through()).is_false()
	assert_int(player.collision_mask & CollisionLayers.ENEMY_BODY).is_equal(CollisionLayers.ENEMY_BODY)
	assert_float(player.global_position.y).is_less(0.3)


func test_the_dodge_is_still_blocked_by_a_body() -> void:
	var main := _spawn_main()
	var player := main.player
	await _settle(player)
	var facing := player.get_aim_direction()
	_enemy_at(main, player.global_position + facing * 2.0)
	await _frames(3)
	var start := player.global_position
	player.start_forced_move(facing, 20.0, 0.25, true)
	await _frames(40)
	assert_float((player.global_position - start).dot(facing)).is_less(1.3)


func test_a_dash_without_the_flag_is_still_blocked() -> void:
	var main := _spawn_main()
	var player := main.player
	await _settle(player)
	var facing := player.get_aim_direction()
	_enemy_at(main, player.global_position + facing * 2.0)
	await _frames(3)
	var start := player.global_position
	EffectTemplates.execute("dash", {"distance": 6.0, "speed": 20.0}, EffectContext.new(player, main, "player"))
	await _frames(40)
	assert_float((player.global_position - start).dot(facing)).is_less(1.3)


func test_dying_mid_dash_clears_pass_through() -> void:
	var main := _spawn_main()
	var player := main.player
	await _settle(player)
	_cast("rogue_ugh_fine_moving", main)
	await _frames(2)
	assert_bool(player.is_pass_through()).is_true()
	player.health.take_damage(9999.0)
	await _frames(2)
	assert_bool(player.is_pass_through()).is_false()


func test_boss_spawn_box_top_margin_leaves_the_head_clear_of_the_hud() -> void:
	# At 1024x600 (42.9 px per screen metre) a boss on the box's top edge has its head about 3.1 m above its feet; the HUD meters end
	# near 92 px from the top and the player stands at 300 px, so the ground point may be at most ~1.56 m up the screen.
	var up: float = float(BossConfig.boss("boss_guardian")["spawn"]["screen_up"])
	assert_float(up).is_less_equal(1.56)


func test_the_wall_preview_uses_the_new_footprint() -> void:
	var parts: Array[Dictionary] = CastPreviewShapes.parts_for_card(CardDatabase.get_card("fire_wall"), {})
	assert_int(parts.size()).is_equal(1)
	assert_str(String(parts[0]["shape"])).is_equal(CastPreviewShapes.ZONE_LINE)
	assert_float(float(parts[0]["size"])).is_equal_approx(VfxSizing.zone_line_half_length(7.5), 0.001)
	assert_float(float(parts[0]["half_width"])).is_equal_approx(VfxSizing.zone_line_half_width(1.8), 0.001)
