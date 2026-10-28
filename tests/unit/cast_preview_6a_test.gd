class_name CastPreview6aTest
extends GdUnitTestSuite
## Slice 6a: the held-key cast preview. Its size must be the hit size (VfxSizing of the
## same card params) for every aimed shape of every card in /data, and the drawn nodes
## must carry those sizes. Settings are injected (temp path), never the real user file.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const DEFAULTS := "res://data/settings.json"
const AIMED: Array[String] = ["cone", "aoe", "projectile", "dash"]

var _original_store: SettingsStore = null
var _root_main: Main = null


func before_test() -> void:
	CardDatabase.load_all()
	_original_store = Settings.store
	Settings.use_store(SettingsStore.new(DEFAULTS, "user://tests/never_written_settings.cfg"))


func after_test() -> void:
	Settings.use_store(_original_store)
	if _root_main != null and is_instance_valid(_root_main):
		get_tree().current_scene = null
		_root_main.free()
	_root_main = null
	Juice.reset()
	TestInput.release(&"slot_1")
	TestInput.release(&"slot_2")
	TestInput.release(&"slot_3")
	TestInput.release(&"slot_4")
	TestInput.release(&"slot_5")


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _player() -> Player:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	_root_main = main
	main.player.card_slots.spawn_parent = main
	main.player.camera = null
	return main.player


## Forces `card_id` into its slot's revealed position and returns the slot index.
func _reveal(player: Player, card_id: String) -> int:
	var slot_type: String = CardDatabase.get_card(card_id)["slot_type"]
	player.card_slots.get_slot(slot_type).current_card_id = card_id
	return CardSlotController.SLOT_TYPE_ORDER.find(slot_type)


# --- sizes equal hit sizes, for every card in data -------------------------------------------

func test_every_card_in_data_previews_with_the_vfx_sizing_of_its_hit_params() -> void:
	var config := CastPreviewConfig.get_config()
	var checked := 0
	for card: Dictionary in CardDatabase.all_cards():
		var parts := CastPreviewShapes.parts_for_card(card, config)
		var aimed: Array[Dictionary] = []
		for effect: Dictionary in card["effects"]:
			if AIMED.has(String(effect["template"])):
				aimed.append(effect)
		if aimed.is_empty():
			assert_int(parts.size()).override_failure_message("%s: a non-aimed card gets one self ring" % card["id"]).is_equal(1)
			assert_str(parts[0]["shape"]).is_equal("self_ring")
			continue
		assert_int(parts.size()).override_failure_message("%s: one part per aimed effect" % card["id"]).is_equal(aimed.size())
		for i in range(aimed.size()):
			var params: Dictionary = aimed[i]["params"]
			var part: Dictionary = parts[i]
			checked += 1
			match String(aimed[i]["template"]):
				"cone":
					assert_str(part["shape"]).is_equal("cone")
					assert_float(part["size"]).is_equal_approx(VfxSizing.cone_reach(float(params["range"])), 0.0001)
					assert_float(part["half_angle_degrees"]).is_equal_approx(float(params["half_angle_degrees"]), 0.0001)
				"aoe":
					assert_str(part["shape"]).is_equal("aoe")
					assert_float(part["size"]).is_equal_approx(VfxSizing.aoe_reach(float(params["radius"])), 0.0001)
				"projectile":
					assert_str(part["shape"]).is_equal("projectile_lane")
					assert_float(part["size"]).is_equal_approx(float(params["max_range"]), 0.0001)
					assert_float(part["half_width"]).is_equal_approx(VfxSizing.projectile_lane_half_width(float(params["hit_radius"])), 0.0001)
					assert_float(part["start_offset"]).is_equal(EffectTemplates.PROJECTILE_MUZZLE_OFFSET)
				"dash":
					assert_str(part["shape"]).is_equal("dash_path")
					assert_float(part["size"]).is_equal_approx(float(params["distance"]), 0.0001)
					assert_float(part["half_width"]).is_equal(VfxConfig.marker("dash_path_half_width"))
	# The starter set has all four aimed shapes, so this loop must have seen them.
	assert_int(checked).is_greater_equal(4)


func test_preview_reach_is_the_same_distance_the_real_cone_and_aoe_hit_out_to() -> void:
	# A target centre just inside the previewed reach is hit by the real template; just outside is not.
	var player := _player()
	await _frames(2)
	var main := _root_main
	player.attacks.set_auto(&"light", false)
	var cone_card := CardDatabase.get_card("fire_ember_whatever")
	var cone_params: Dictionary = cone_card["effects"][0]["params"]
	var reach: float = CastPreviewShapes.parts_for_card(cone_card, CastPreviewConfig.get_config())[0]["size"]
	var scene: PackedScene = load("res://scenes/enemies/MeleeChaser.tscn")
	for case: Array in [[reach - 0.05, true], [reach + 0.1, false]]:
		var enemy: Enemy = scene.instantiate()
		enemy.position = player.global_position + Vector3(0.0, 0.0, -float(case[0]))
		main.add_child(enemy)
		enemy.target = null
		await _frames(2)
		var before := enemy.health.current_health
		var context := EffectContext.new(player, main, "player")
		EffectTemplates.execute("cone", cone_params, context)
		assert_bool(enemy.health.current_health < before).override_failure_message("cone at %f" % float(case[0])).is_equal(bool(case[1]))
		enemy.free()


# --- the drawn nodes ----------------------------------------------------------------------------

func test_held_key_draws_nodes_sized_to_the_hit_area_and_placed_on_the_facing() -> void:
	var player := _player()
	await _frames(2)
	var slot_index := _reveal(player, "neutral_pointy_stick")
	TestInput.press(StringName("slot_%d" % (slot_index + 1)))
	await _frames(3)
	var state := player.get_preview_state()
	assert_bool(state["active"]).is_true()
	assert_str(state["slot"]).is_equal("attack_single")
	assert_str(state["card_id"]).is_equal("neutral_pointy_stick")
	assert_str(state["shape"]).is_equal("projectile_lane")
	assert_float(state["size"]).is_equal_approx(12.0, 0.0001)
	var fill := player.cast_preview.fill_node(0)
	var pivot := player.cast_preview.pivot_node(0)
	assert_bool(pivot.visible).is_true()
	assert_float(fill.scale.z).is_equal_approx(12.0, 0.0001)
	assert_float(fill.scale.x).is_equal_approx(VfxSizing.projectile_lane_half_width(0.25), 0.0001)
	var forward := player.get_aim_direction()
	var expected := player.global_position + forward * EffectTemplates.PROJECTILE_MUZZLE_OFFSET
	assert_float(pivot.position.x).is_equal_approx(expected.x, 0.001)
	assert_float(pivot.position.z).is_equal_approx(expected.z, 0.001)


func test_cone_and_aoe_nodes_carry_the_reach() -> void:
	var player := _player()
	await _frames(2)
	var cone_index := _reveal(player, "fire_ember_whatever")
	TestInput.press(StringName("slot_%d" % (cone_index + 1)))
	await _frames(3)
	var cone_reach := VfxSizing.cone_reach(1.8)
	assert_float(player.cast_preview.fill_node(0).scale.x).is_equal_approx(cone_reach, 0.0001)
	assert_float(player.get_preview_state()["size"]).is_equal_approx(cone_reach, 0.0001)
	TestInput.release(StringName("slot_%d" % (cone_index + 1)))
	player.card_slots.get_slot("attack_single").cooldown_remaining = 30.0
	await _frames(3)
	var aoe_index := _reveal(player, "fire_fine_burn_then")
	TestInput.press(StringName("slot_%d" % (aoe_index + 1)))
	await _frames(3)
	assert_float(player.cast_preview.fill_node(0).scale.x).is_equal_approx(VfxSizing.aoe_reach(3.2), 0.0001)
	assert_float(player.cast_preview.fill_node(0).scale.z).is_equal_approx(VfxSizing.aoe_reach(3.2), 0.0001)


func test_a_two_shape_card_draws_both_parts() -> void:
	var player := _player()
	await _frames(2)
	var index := _reveal(player, "fire_blaze_and_bail")
	TestInput.press(StringName("slot_%d" % (index + 1)))
	await _frames(3)
	var state := player.get_preview_state()
	assert_array(state["parts"]).has_size(2)
	assert_str(state["parts"][0]["shape"]).is_equal("aoe")
	assert_str(state["parts"][1]["shape"]).is_equal("dash_path")
	assert_float(state["parts"][1]["size"]).is_equal(4.0)
	assert_bool(player.cast_preview.pivot_node(0).visible).is_true()
	assert_bool(player.cast_preview.pivot_node(1).visible).is_true()
	assert_bool(player.cast_preview.pivot_node(2).visible).is_false()


func test_preview_follows_the_aim_live_while_held() -> void:
	var player := _player()
	await _frames(2)
	var index := _reveal(player, "fire_ember_whatever")
	TestInput.press(StringName("slot_%d" % (index + 1)))
	await _frames(2)
	var yaw_before := player.cast_preview.pivot_node(0).rotation.y
	player.rotate_y(0.8)
	await _frames(2)
	assert_float(player.cast_preview.pivot_node(0).rotation.y).is_not_equal(yaw_before)
	var forward := player.get_aim_direction()
	assert_float(player.cast_preview.pivot_node(0).rotation.y).is_equal_approx(atan2(-forward.x, -forward.z), 0.001)


# --- state and lifecycle -------------------------------------------------------------------------

func test_state_is_inactive_without_a_hold_and_after_release_cancel_and_in_press_mode() -> void:
	var player := _player()
	await _frames(2)
	assert_bool(player.get_preview_state()["active"]).is_false()
	var index := _reveal(player, "fire_ember_whatever")
	var action := StringName("slot_%d" % (index + 1))
	TestInput.press(action)
	await _frames(2)
	assert_bool(player.get_preview_state()["active"]).is_true()
	TestInput.release(action)
	await _frames(2)
	assert_bool(player.get_preview_state()["active"]).is_false()
	assert_bool(player.cast_preview.pivot_node(0).visible).is_false()
	player.card_slots.get_slot("attack_single").cooldown_remaining = 0.0
	TestInput.press(action)
	await _frames(2)
	player.cancel_cast_preview()
	await _frames(2)
	assert_bool(player.get_preview_state()["active"]).is_false()
	assert_bool(player.cast_preview.pivot_node(0).visible).is_false()
	TestInput.release(action)
	Settings.set_value(Settings.CAST_TRIGGER, Settings.TRIGGER_PRESS)
	TestInput.press(action)
	await _frames(2)
	assert_bool(player.get_preview_state()["active"]).is_false()


func test_switching_keys_switches_the_preview_to_the_new_slot() -> void:
	var player := _player()
	await _frames(2)
	var first := _reveal(player, "fire_ember_whatever")
	var second := _reveal(player, "fire_fine_burn_then")
	TestInput.press(StringName("slot_%d" % (first + 1)))
	await _frames(2)
	assert_str(player.get_preview_state()["shape"]).is_equal("cone")
	TestInput.press(StringName("slot_%d" % (second + 1)))
	await _frames(2)
	var state := player.get_preview_state()
	assert_str(state["slot"]).is_equal("attack_aoe")
	assert_str(state["shape"]).is_equal("aoe")


func test_dead_card_swap_mid_hold_refreshes_the_preview_card() -> void:
	var player := _player()
	await _frames(2)
	var index := _reveal(player, "fire_ember_whatever")
	var slot := player.card_slots.get_slot("attack_single")
	TestInput.press(StringName("slot_%d" % (index + 1)))
	await _frames(2)
	assert_str(player.get_preview_state()["card_id"]).is_equal("fire_ember_whatever")
	assert_bool(slot.swap_card()).is_true()
	var shown := player.get_preview_state()["card_id"] as String
	assert_str(shown).is_equal(slot.current_card_id)


func test_heal_and_buff_cards_show_a_small_self_ring_that_data_can_switch_off() -> void:
	var player := _player()
	await _frames(2)
	var index := _reveal(player, "neutral_healing_potion")
	TestInput.press(StringName("slot_%d" % (index + 1)))
	await _frames(2)
	var state := player.get_preview_state()
	assert_str(state["shape"]).is_equal("self_ring")
	assert_float(state["size"]).is_equal_approx(float(CastPreviewConfig.get_config()["self_ring_radius"]), 0.0001)
	var off := CastPreviewConfig.DEFAULTS.duplicate()
	off["self_ring_enabled"] = false
	assert_array(CastPreviewShapes.parts_for_card(CardDatabase.get_card("neutral_healing_potion"), off)).is_empty()
	assert_array(CastPreviewShapes.parts_for_card(CardDatabase.get_card("fire_hot_head"), CastPreviewConfig.DEFAULTS)).has_size(1)


func test_the_preview_uses_held_nodes_not_the_effect_pool() -> void:
	var player := _player()
	await _frames(2)
	var pool := EffectPool.for_world(_root_main)
	var created_before := pool.created_count()
	var active_before := pool.active_count()
	var index := _reveal(player, "fire_fine_burn_then")
	TestInput.press(StringName("slot_%d" % (index + 1)))
	await _frames(20)
	assert_int(pool.created_count()).is_equal(created_before)
	assert_int(pool.active_count()).is_equal(active_before)


func test_a_dead_player_shows_no_preview() -> void:
	var player := _player()
	await _frames(2)
	var index := _reveal(player, "fire_ember_whatever")
	TestInput.press(StringName("slot_%d" % (index + 1)))
	await _frames(2)
	player.health.take_damage(player.health.get_max_health() * 2.0)
	await _frames(2)
	assert_bool(player.get_preview_state()["active"]).is_false()
	assert_bool(player.cast_preview.pivot_node(0).visible).is_false()


# --- config --------------------------------------------------------------------------------------

func test_config_data_is_valid_and_bad_values_are_rejected() -> void:
	assert_array(CastPreviewConfig.validate(CastPreviewConfig.get_config())).is_empty()
	var bad := CastPreviewConfig.DEFAULTS.duplicate()
	bad["fill_alpha"] = 3.0
	bad["default_color"] = "nope"
	bad["enabled"] = "yes"
	assert_array(CastPreviewConfig.validate(bad)).has_size(3)
