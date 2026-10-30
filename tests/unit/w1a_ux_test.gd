class_name W1aUxTest
extends GdUnitTestSuite
## W1a ux half: the Wizard bolt's own look, the class pick screen (see ClassPickScreen).

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"


func before_test() -> void:
	_reset_statics()


func after_test() -> void:
	_reset_statics()
	Juice.reset()
	GamePause.reset()


func _reset_statics() -> void:
	RunSession.clear()
	RunSession.full_deck = false
	RunSession.debug_deck = {}
	RunSession.selected_character = ""
	RunSession.character_forced = false
	RunSession.forced_seed = -1
	CharacterPick.reset()
	CharacterPick.persist_override = false


func _frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().physics_frame


# ---- the Wizard bolt ----

func test_bolt_look_validation_rejects_a_bad_colour_and_a_bad_scale() -> void:
	var base: Dictionary = AttackDatabase.get_light("wizard").duplicate(true)
	assert_array(AttackDatabase.validate_entry(base)).is_empty()
	var bad_color: Dictionary = base.duplicate(true)
	bad_color["bolt_look"] = {"color": "not-a-color", "scale": 1.0}
	assert_bool(AttackDatabase.validate_entry(bad_color).is_empty()).is_false()
	var bad_scale: Dictionary = base.duplicate(true)
	bad_scale["bolt_look"] = {"color": "#3fd9ff", "scale": 0.0}
	assert_bool(AttackDatabase.validate_entry(bad_scale).is_empty()).is_false()
	var not_object: Dictionary = base.duplicate(true)
	not_object["bolt_look"] = "cyan"
	assert_bool(AttackDatabase.validate_entry(not_object).is_empty()).is_false()


func test_a_light_without_a_bolt_look_still_validates() -> void:
	var plain: Dictionary = AttackDatabase.get_light("wizard").duplicate(true)
	plain.erase("bolt_look")
	assert_array(AttackDatabase.validate_entry(plain)).is_empty()


func test_the_wizard_bolt_has_its_own_look_apart_from_the_card_bolt_and_enemy_shots() -> void:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	(main.get_node("Player") as Player).character_id = "wizard"
	add_child(main)
	auto_free(main)
	await _frames(2)
	main.player.camera = null
	main.player.rotation = Vector3.ZERO
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	enemy.position = main.player.global_position + Vector3(0.0, 0.0, -6.0)
	main.add_child(enemy)
	enemy.target = null
	await _frames(2)
	main.player.aim_point_override = enemy.global_position
	var bolt: Projectile = null
	for i in range(90):
		await get_tree().physics_frame
		for child in main.get_children():
			if child is Projectile:
				bolt = child
		if bolt != null:
			break
	assert_object(bolt).is_not_null()
	var color: Color = bolt._look["color"]
	var card_bolt: Color = ElementVisuals.visual_for_team("neutral", "player")["color"]
	var enemy_shot: Color = ElementVisuals.visual_for_team("neutral", "enemy")["color"]
	assert_bool(color.is_equal_approx(card_bolt)).is_false()
	assert_bool(color.is_equal_approx(enemy_shot)).is_false()
	assert_bool(color.is_equal_approx(ElementVisuals.color_for_damage_type("fire"))).is_false()


func test_the_look_param_replaces_the_element_look_and_an_empty_one_is_ignored() -> void:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	await _frames(2)
	var context := EffectContext.new(main.player, main, "player")
	var params: Dictionary = {"damage": 1.0, "damage_type": "neutral", "speed": 10.0, "max_range": 5.0, "hit_radius": 0.25, "look": {}}
	EffectTemplates.execute("projectile", params, context)
	var plain: Projectile = null
	for child in main.get_children():
		if child is Projectile:
			plain = child
	assert_object(plain).is_not_null()
	assert_bool((plain._look["color"] as Color).is_equal_approx(ElementVisuals.color_for_damage_type("neutral"))).is_true()
	plain.queue_free()
	params["look"] = {"color": Color(0.1, 0.9, 0.2), "scale": 1.5}
	EffectTemplates.execute("projectile", params, context)
	var tinted: Projectile = null
	for child in main.get_children():
		if child is Projectile and child != plain:
			tinted = child
	assert_object(tinted).is_not_null()
	assert_bool((tinted._look["color"] as Color).is_equal_approx(Color(0.1, 0.9, 0.2))).is_true()
