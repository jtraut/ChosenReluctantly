class_name C1fQaTest
extends GdUnitTestSuite
## C1-f qa additions. These cover gaps the C1-a..e suites left: the nine new cards cast through the real
## slot path (try_use), the text limits on every card, and Leech returning HP from every damage source
## (cone, projectile, zone tick, dash path, DoT tick), all with the real Player.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"
const NEW_CARDS: Array[String] = [
	"rogue_bleed_slash", "rogue_flurry", "fire_fireball", "fire_wall", "rogue_shadow_step",
	"rogue_lunge_strike", "neutral_backward_leap", "neutral_leech", "neutral_regeneration",
]
const NAME_LIMIT := 25
const FLAVOR_LIMIT := 80


func before_test() -> void:
	BodyFlag.set_collide(false)


func after_test() -> void:
	BodyFlag.reset()
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


func _cast(main: Main, card_id: String, aim: Variant = null) -> void:
	var context := EffectContext.new(main.player, main, "player")
	context.rng = main.player.status_rng
	context.aim_point = aim
	for effect: Dictionary in CardDatabase.get_card(card_id)["effects"]:
		EffectTemplates.execute(effect["template"], effect["params"], context)


# --- text limits ----------------------------------------------------------------------------

func test_every_card_name_and_flavor_respects_the_limits_and_the_new_cards_have_both() -> void:
	for card: Dictionary in CardDatabase.all_cards():
		var card_id := String(card["id"])
		assert_int(String(card["name"]).length()).override_failure_message("%s name is %d characters (max %d)" % [card_id, String(card["name"]).length(), NAME_LIMIT]).is_between(1, NAME_LIMIT)
		assert_int(String(card.get("flavor_text", "")).length()).override_failure_message("%s flavor is over %d characters" % [card_id, FLAVOR_LIMIT]).is_less_equal(FLAVOR_LIMIT)
	for card_id in NEW_CARDS:
		assert_int(String(CardDatabase.get_card(card_id).get("flavor_text", "")).length()).override_failure_message("%s has no flavor" % card_id).is_greater(0)


func test_card_names_are_unique() -> void:
	var seen: Dictionary = {}
	for card: Dictionary in CardDatabase.all_cards():
		var shown := String(card["name"])
		assert_bool(seen.has(shown)).override_failure_message("two cards are both named '%s'" % shown).is_false()
		seen[shown] = true


# --- the nine cards through the real slot path ----------------------------------------------

func test_each_new_card_casts_through_its_slot_with_the_cooldown_the_data_implies() -> void:
	var main := _spawn_main()
	_enemy_at(main, Vector3(0.0, 0.0, -2.0))
	await _frames(3)
	var controller: CardSlotController = main.player.card_slots
	for card_id in NEW_CARDS:
		var card := CardDatabase.get_card(card_id)
		var slot_type := String(card["slot_type"])
		var slot := controller.get_slot(slot_type)
		assert_object(slot).override_failure_message("%s: no slot '%s' in the preset deck" % [card_id, slot_type]).is_not_null()
		assert_array(slot.owned_card_ids).override_failure_message("%s is not owned by its slot" % card_id).contains([card_id])
		slot.current_card_id = card_id
		slot.cooldown_remaining = 0.0
		var cast_ids: Array[String] = []
		controller.card_cast.connect(func(_s: String, used: String) -> void: cast_ids.append(used), CONNECT_ONE_SHOT)
		assert_bool(controller.try_use(slot_type)).override_failure_message("%s did not cast" % card_id).is_true()
		assert_array(cast_ids).is_equal([card_id])
		var base: float = float(SlotTypeDatabase.get_definition(slot_type)["base_cooldown"])
		var expected: float = maxf(base + float(card["cooldown_modifier"]), 0.0)
		assert_float(slot.cooldown_remaining).override_failure_message("%s cooldown %.3f, data says %.3f" % [card_id, slot.cooldown_remaining, expected]).is_equal_approx(expected, 0.001)
		assert_bool(is_nan(slot.cooldown_remaining) or is_inf(slot.cooldown_remaining)).is_false()
		# A second press while cooling must not cast.
		assert_bool(controller.try_use(slot_type)).override_failure_message("%s cast again while cooling" % card_id).is_false()
		slot.cooldown_remaining = 0.0
		await _frames(2)
		main.player.global_position = Vector3.ZERO
		main.player.velocity = Vector3.ZERO
	assert_float(main.player.health.current_health).is_greater(0.0)


# --- Leech from every damage source ----------------------------------------------------------

func _leech_player(main: Main) -> void:
	main.player.health.current_health = 5.0
	main.player.status_manager.apply_status("leech", StatusDatabase.get_status("leech"), 30.0)


func test_leech_returns_hp_from_a_cone_hit() -> void:
	var main := _spawn_main()
	_enemy_at(main, Vector3(0.0, 0.0, -1.2))
	await _frames(3)
	_leech_player(main)
	_cast(main, "rogue_quick_slash")
	assert_float(main.player.health.current_health).override_failure_message("a cone hit did not feed Leech").is_greater(5.0)


func test_leech_returns_hp_from_a_projectile_hit() -> void:
	var main := _spawn_main()
	await _frames(2)
	var facing := main.player.get_aim_direction()
	_enemy_at(main, main.player.global_position + facing * 3.0)
	await _frames(3)
	_leech_player(main)
	_cast(main, "neutral_pointy_stick")
	await _frames(40)
	assert_float(main.player.health.current_health).override_failure_message("a projectile hit did not feed Leech").is_greater(5.0)


func test_leech_returns_hp_from_a_zone_tick() -> void:
	var main := _spawn_main()
	var enemy := _enemy_at(main, Vector3(0.0, 0.0, -4.0))
	await _frames(3)
	_leech_player(main)
	_cast(main, "fire_wall", enemy.global_position)
	assert_float(main.player.health.current_health).override_failure_message("a zone tick did not feed Leech").is_greater(5.0)
	assert_float(enemy.health.current_health).is_less(enemy.health.get_max_health())


func test_leech_returns_hp_from_dash_path_damage_and_from_a_bleed_tick() -> void:
	var main := _spawn_main()
	await _frames(2)
	var facing := main.player.get_aim_direction()
	var enemy := _enemy_at(main, main.player.global_position + facing * 2.0)
	await _frames(3)
	_leech_player(main)
	_cast(main, "rogue_lunge_strike")
	for i in range(30):
		await _frames(1)
	var after_dash: float = main.player.health.current_health
	assert_float(after_dash).override_failure_message("dash path damage did not feed Leech").is_greater(5.0)
	# Bleed ticks are credited to whoever applied them.
	enemy.status_manager.apply_status("bleed", StatusDatabase.get_status("bleed"), 5.0, main.player)
	enemy.status_manager._process(float(StatusDatabase.get_status("bleed")["tick_interval"]))
	assert_float(main.player.health.current_health).override_failure_message("a Bleed tick did not feed Leech").is_greater(after_dash)
	assert_float(main.player.health.current_health).is_less_equal(main.player.health.get_max_health())
