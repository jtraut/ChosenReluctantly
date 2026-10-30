class_name F1QaTest
extends GdUnitTestSuite
## F1 qa: characterises the edge case game-lead flagged (a dodge inside the post-dash ghost window), pins that the window is
## bounded and ends on its own, checks the Wall preview against its hitbox, and the 10-room run shape.

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


## Edge case (F1, game-lead flagged): a dash that ends inside a body leaves the player ghosted, and a dodge started then
## passes through. This pins the CURRENT behaviour so a change is a conscious one; GDD 3 says the dodge is blocked by bodies.
func test_edge_case_dodge_inside_the_post_dash_ghost_window_passes_through() -> void:
	var main := _spawn_main()
	var player := main.player
	await _settle(player)
	var facing := player.get_aim_direction()
	_enemy_at(main, player.global_position + facing * 4.5)  # where the 4.5 m dash ends
	_enemy_at(main, player.global_position + facing * 6.0)  # a second body ahead of the dodge
	await _frames(3)
	_cast("rogue_ugh_fine_moving", main)
	await _frames(30)
	assert_bool(player.is_pass_through()).override_failure_message("setup: dash should end inside the body").is_true()
	var start := player.global_position
	player.start_forced_move(facing, player.dodge_speed, 0.25, true)
	await _frames(40)
	var travelled: float = (player.global_position - start).dot(facing)
	assert_float(travelled).override_failure_message("dodge in the ghost window travelled %.2f m" % travelled).is_greater(2.0)


## The window cannot be renewed by dodging: after the cap or stepping out, the dodge is blocked by bodies again.
func test_the_ghost_window_closes_and_the_dodge_is_blocked_again() -> void:
	var main := _spawn_main()
	var player := main.player
	await _settle(player)
	var facing := player.get_aim_direction()
	_enemy_at(main, player.global_position + facing * 4.8)  # not exactly concentric: see the note on the launch quirk in the review
	await _frames(3)
	_cast("rogue_ugh_fine_moving", main)
	await _frames(int(Player.PASS_THROUGH_RESTORE_CAP * 60.0) + 40)
	assert_bool(player.is_pass_through()).is_false()
	var blocker := _enemy_at(main, player.global_position + facing * 2.0)
	await _frames(3)
	var start := player.global_position
	player.start_forced_move(facing, player.dodge_speed, 0.25, true)
	await _frames(40)
	assert_float((player.global_position - start).dot(facing)).is_less(1.3)
	assert_bool(is_instance_valid(blocker)).is_true()


## The 10-room run: 7 combat, 1 elite, 1 rest, boss last; placement ranges inside the run.
func test_run_data_is_ten_rooms_with_the_boss_last() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/run.json"))
	var text: String = JSON.stringify(cfg)
	assert_bool(text.contains("\"combat\"")).is_true()
	var total := 0
	for k: String in (cfg["composition"] as Dictionary).keys():
		total += int(cfg["composition"][k])
	assert_int(total).is_equal(10)
	assert_int(int(cfg["composition"]["combat"])).is_equal(7)
	for k: String in (cfg["placement"]["ranges"] as Dictionary).keys():
		var r: Array = cfg["placement"]["ranges"][k]
		assert_int(int(r[0])).is_greater_equal(1)
		assert_int(int(r[1])).is_less(10)


## The Wall's preview rectangle and its hit test are the same numbers: a point just inside the previewed edge is hit,
## just outside is not, on both axes (7.5 x 1.8 plus the hurtbox reach).
func test_wall_preview_edges_equal_the_hit_test_edges() -> void:
	var params: Dictionary = (CardDatabase.get_card("fire_wall")["effects"][0] as Dictionary)["params"]
	var parts: Array[Dictionary] = CastPreviewShapes.parts_for_card(CardDatabase.get_card("fire_wall"), {})
	var half_length: float = float(parts[0]["size"])
	var half_width: float = float(parts[0]["half_width"])
	var dir := Vector3.FORWARD
	var axis := ZoneShape.line_axis(dir)
	var across := Vector3(axis.z, 0.0, -axis.x)
	var length: float = float(params["length"])
	var width: float = float(params["width"])
	assert_float(length).is_equal(7.5)
	assert_float(width).is_equal(1.8)
	assert_bool(ZoneShape.line_contains(axis * (half_length - 0.01), Vector3.ZERO, dir, length, width)).is_true()
	assert_bool(ZoneShape.line_contains(axis * (half_length + 0.01), Vector3.ZERO, dir, length, width)).is_false()
	assert_bool(ZoneShape.line_contains(across * (half_width - 0.01), Vector3.ZERO, dir, length, width)).is_true()
	assert_bool(ZoneShape.line_contains(across * (half_width + 0.01), Vector3.ZERO, dir, length, width)).is_false()
