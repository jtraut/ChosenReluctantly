class_name Slice4QaTest
extends GdUnitTestSuite
## qa additions for Slice 4 (skill visuals and targeting readability): Water as a
## data-only element, real-scene cast soak against the pool cap, caster and enemy
## freed mid-effect, Burn flames across death/free/reload, visual lane vs real hit
## width, behaviour pins for the "visual" commits, data-file validation.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"
const SHOOTER_PATH := "res://scenes/enemies/RangedShooter.tscn"
const WATER_POOLS := "res://tests/fixtures/pools_water/pools.json"
const REAL_POOLS := "res://data/pools.json"


func before_test() -> void:
	BodyFlag.set_collide(false)  # these tests park enemies on the player; solid bodies have c1c_solid_enemies_test
	# Other suites point CardDatabase at fixture folders; use the shipped cards here.
	CardDatabase.load_all()


func after_test() -> void:
	BodyFlag.reset()
	Juice.reset()
	PoolDatabase._table = JsonDataTable.new(REAL_POOLS)


func _spawn_main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	main.player.camera = null
	main.player.rotation = Vector3.ZERO
	return main


func _spawn_enemy(main: Main, path: String, offset: Vector3) -> Enemy:
	var enemy: Enemy = (load(path) as PackedScene).instantiate()
	main.add_child(enemy)
	enemy.global_position = main.player.global_position + offset
	enemy.target = null
	enemy.health.set_max_health(100000.0)
	enemy.health.current_health = 100000.0
	return enemy


func _use_water_pools() -> void:
	PoolDatabase._table = JsonDataTable.new(WATER_POOLS)


# --- Water is data only ---------------------------------------------------------

func test_water_element_is_data_only_end_to_end() -> void:
	_use_water_pools()
	assert_bool(PoolDatabase.has("water")).is_true()
	var water := ElementVisuals.visual_for_damage_type("water")
	assert_object(water["color"]).is_equal(Color.html("#4aa8ff"))
	assert_float(water["scale"]).is_equal(1.5)
	# Fire and unknown types are unaffected.
	assert_object(ElementVisuals.color_for_damage_type("fire")).is_equal(Color.html("#ff6a1f"))
	# A water card passes card validation with no code change.
	var card := {
		"id": "water_splash", "name": "Wet, Technically", "slot_type": "attack_single", "pool": "water",
		"cooldown_modifier": 0.0, "flavor_text": "Damp.",
		"effects": [{"template": "projectile", "params": {"damage": 5, "damage_type": "water", "speed": 9.0, "max_range": 10.0, "hit_radius": 0.3}}],
	}
	assert_array(CardSchema.validate(card)).is_empty()


func test_water_look_recolors_aoe_and_projectile_but_never_resizes_hit_shapes() -> void:
	_use_water_pools()
	var main := _spawn_main()
	await get_tree().process_frame
	var pool := EffectPool.for_world(main)
	var look := ElementVisuals.visual_for_damage_type("water")
	TemplateVfx.aoe(pool, Vector3.ZERO, VfxSizing.aoe_reach(3.0), look)
	var disc_seen := false
	for child in pool.get_children():
		var effect := child as PooledEffect
		if effect.active and effect.mesh == EffectPool.disc_mesh():
			disc_seen = true
			assert_object(effect.color).is_equal(Color.html("#4aa8ff"))
			# Hit-area part: sized by the hit data, NOT by the 1.5 element scale.
			assert_float(effect.base_size).is_equal(VfxSizing.aoe_reach(3.0))
	assert_bool(disc_seen).is_true()
	var instance: Projectile = (load("res://scenes/effects/Projectile.tscn") as PackedScene).instantiate()
	main.add_child(instance)
	instance.set_hit_radius(0.3)
	instance.set_look(look)
	assert_float(instance.hitbox_radius()).is_equal_approx(0.3, 0.0001)
	assert_float(instance.visual_radius()).is_equal_approx(0.3, 0.0001)
	instance.queue_free()


# --- Pool: real cards, real scene, tiny cap ----------------------------------------

func test_every_shipped_card_cast_repeatedly_stays_within_cap_and_returns_to_idle() -> void:
	var main := _spawn_main()
	_spawn_enemy(main, CHASER_PATH, Vector3(0.0, 0.0, -2.0))
	_spawn_enemy(main, CHASER_PATH, Vector3(1.0, 0.0, -3.0))
	await get_tree().process_frame
	var pool := EffectPool.for_world(main)
	pool.max_effects = 14
	var cards := CardDatabase.all_cards()
	assert_int(cards.size()).is_greater(5)
	var nodes_before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for round_index in range(25):
		for card: Dictionary in cards:
			var context := EffectContext.new(main.player, main, "player")
			context.rng = main.player.status_rng  # as CardSlotController passes it; without one a zone status chance logs an error (C1-f)
			for effect: Dictionary in card["effects"]:
				EffectTemplates.execute(effect["template"], effect["params"], context)
		await get_tree().physics_frame
		assert_int(pool.active_count()).is_less_equal(14)
	assert_int(pool.created_count()).is_less_equal(14)
	# Let every shot fly out and every effect run out. Burn on the live enemies is
	# the only thing still allowed to hold a pool slot.
	main.player.health.heal(1000.0)
	main.player.status_manager._process(10.0)  # Leech and Regeneration (C1-c) run 7 s and hold persistent cues on the player
	for i in range(240):
		await get_tree().physics_frame
	assert_int(pool.get_child_count()).is_less_equal(14)
	assert_int(_count_projectiles(main)).is_equal(0)
	for enemy in main.get_children():
		if enemy is Enemy:
			enemy.free()
	await get_tree().process_frame
	await get_tree().process_frame
	# A Bleed drop (C1-e) is a short transient: one that fell just before the enemies went still has to fade out.
	for i in range(60):
		await get_tree().physics_frame
	assert_int(pool.active_count()).is_equal(0)
	# No node growth beyond the pool itself and the two spawn-time children.
	var growth := Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - nodes_before
	# C1-f: the zone manager (created on the first Fire Wall cast) owns fill, edge and timer meshes for
	# each of its max_live slots plus itself. That set is fixed by the cap, so it is asserted exactly and
	# taken out of the growth figure, instead of widening the general allowance by a guess. (Measured
	# net growth is 16: the two enemies are killed during the loop and their nodes free up.)
	var zones := ZoneManager.for_world(main)
	assert_int(zones.get_child_count()).is_less_equal(3 * ZoneConfig.max_live())
	assert_int(zones.live_count()).is_equal(0)
	var zone_nodes := float(zones.get_child_count() + 1)
	assert_float(growth - zone_nodes).is_less_equal(14.0 + 2.0)


func _count_projectiles(main: Node) -> int:
	var n := 0
	for child in main.get_children():
		if child is Projectile:
			n += 1
	return n


# --- Freed mid-effect --------------------------------------------------------------

func test_caster_freed_right_after_casting_every_template_is_harmless() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var pool := EffectPool.for_world(main)
	for template_id: String in ["cone", "aoe", "projectile", "heal"]:
		var caster := Node3D.new()
		var health := Health.new()
		health.name = "Health"
		health.max_health = 10.0
		caster.add_child(health)
		main.add_child(caster)
		var params: Dictionary = {
			"cone": {"damage": 1.0, "damage_type": "fire", "range": 2.0, "half_angle_degrees": 45.0},
			"aoe": {"damage": 1.0, "damage_type": "fire", "radius": 3.0},
			"projectile": {"damage": 1.0, "damage_type": "fire", "speed": 10.0, "max_range": 6.0, "hit_radius": 0.3},
			"heal": {"amount": 1.0},
		}[template_id]
		health.take_damage(5.0)
		EffectTemplates.execute(template_id, params, EffectContext.new(caster, main, "player"))
		caster.free()
		await get_tree().process_frame
	for i in range(120):
		await get_tree().physics_frame
	assert_int(pool.active_count()).is_equal(0)
	assert_int(_count_projectiles(main)).is_equal(0)


func test_dash_caster_freed_mid_dash_does_not_error() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var pool := EffectPool.for_world(main)
	EffectTemplates.execute("dash", {"distance": 4.0, "speed": 12.0, "invulnerable": false},
			EffectContext.new(main.player, main, "player"))
	await get_tree().physics_frame
	await get_tree().physics_frame
	main.player.free()
	for i in range(60):
		await get_tree().process_frame
	assert_int(pool.active_count()).is_equal(0)


# --- Burn flames: death by own tick, free, reload ----------------------------------

func test_enemy_killed_by_its_own_burn_tick_releases_the_flame() -> void:
	var main := _spawn_main()
	var enemy := _spawn_enemy(main, CHASER_PATH, Vector3(0.0, 0.0, -6.0))
	enemy.health.set_max_health(1.0)
	enemy.health.current_health = 1.0
	await get_tree().process_frame
	var manager: StatusEffectManager = enemy.get_node("StatusEffectManager")
	var pool := EffectPool.for_world(main)
	manager.apply_status("burn", StatusDatabase.get_status("burn"), 5.0)
	assert_int(pool.active_count()).is_equal(1)
	for i in range(120):  # first tick is at 1 s
		await get_tree().physics_frame
		if not is_instance_valid(enemy):
			break
	assert_bool(is_instance_valid(enemy)).is_false()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(pool.active_count()).is_equal(0)


func test_main_freed_while_enemies_burn_leaves_nothing_behind() -> void:
	var nodes_before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for round_index in range(3):
		var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
		(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
		add_child(main)
		await get_tree().process_frame
		var pool := EffectPool.for_world(main)
		for i in range(4):
			var enemy := _spawn_enemy(main, CHASER_PATH, Vector3(float(i), 0.0, -6.0))
			var manager: StatusEffectManager = enemy.get_node("StatusEffectManager")
			manager.apply_status("burn", StatusDatabase.get_status("burn"), 10.0)
		assert_int(pool.active_count()).is_equal(4)
		await get_tree().process_frame
		main.free()
		await get_tree().process_frame
		await get_tree().process_frame
	assert_float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)).is_less_equal(nodes_before + 1.0)


# --- Visual lane vs real hit width -------------------------------------------------

func _shot_hits_enemy_at_lateral_offset(lateral: float, hit_radius: float) -> bool:
	var main := _spawn_main()
	var enemy := _spawn_enemy(main, CHASER_PATH, Vector3(lateral, 0.0, -5.0))
	await get_tree().physics_frame
	var hp := enemy.health.current_health
	EffectTemplates.execute("projectile", {"damage": 5.0, "damage_type": "physical", "speed": 12.0, "max_range": 9.0, "hit_radius": hit_radius},
			EffectContext.new(main.player, main, "player"))
	for i in range(90):
		await get_tree().physics_frame
	var hit := enemy.health.current_health < hp
	main.queue_free()
	await get_tree().process_frame
	return hit


func test_projectile_lane_width_vs_real_lateral_hit_reach_is_pinned() -> void:
	# S4-1 (fixed): shots launch at y = 0 and the hurtbox capsule's lowest sphere centre is
	# 0.45 up, so the true lateral reach is sqrt((r + 0.45)^2 - 0.45^2) = 0.60 for r = 0.3.
	# The lane now draws exactly that. Physical pin: hit at 0.55, miss at 0.65.
	var lane := VfxSizing.projectile_lane_half_width(0.3)
	assert_float(lane).is_equal_approx(0.6, 0.0001)
	assert_bool(await _shot_hits_enemy_at_lateral_offset(0.55, 0.3)).is_true()
	assert_bool(await _shot_hits_enemy_at_lateral_offset(0.65, 0.3)).is_false()
	assert_bool(0.55 < lane and lane < 0.65).override_failure_message("lane must sit between the hit (0.55) and miss (0.65) offsets").is_true()


# --- Behaviour pins for the "visual" commits ---------------------------------------

func test_projectile_hit_radius_now_comes_from_data_for_cards_and_ranged_enemies() -> void:
	# Logged: Flaming Nonsense 0.25 -> 0.3. Not logged by the dev: Enemy.gd has always
	# sent 0.3 but it used to be ignored (scene default 0.25), so ranged enemy shots
	# also grew by 20 percent. Pin both so a later change is deliberate.
	var flaming: Dictionary = CardDatabase.get_card("fire_flaming_nonsense")
	assert_float(float(flaming["effects"][0]["params"]["hit_radius"])).is_equal(0.3)
	# Enemy spawns its shots under current_scene, so this one needs Main as a root child.
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	var shooter := _spawn_enemy(main, SHOOTER_PATH, Vector3(0.0, 0.0, -8.0))
	shooter.target = main.player
	await get_tree().process_frame
	shooter._execute_attack()
	var found: Projectile = null
	for child in main.get_children():
		if child is Projectile:
			found = child
	assert_object(found).is_not_null()
	assert_float(found.hitbox_radius()).is_equal_approx(0.3, 0.0001)
	assert_float(found.visual_radius()).is_equal_approx(0.3, 0.0001)
	get_tree().current_scene = null
	main.free()
	var default_scene: Projectile = auto_free((load("res://scenes/effects/Projectile.tscn") as PackedScene).instantiate())
	assert_float(default_scene.hit_radius).is_equal(0.25)


func test_arena_floor_is_still_40_by_40() -> void:
	var main := _spawn_main()
	var floor_node := main.get_node("Floor") as CSGBox3D
	assert_object(floor_node).is_not_null()
	assert_vector(floor_node.size).is_equal(Vector3(40.0, 1.0, 40.0))


func test_hit_queries_do_not_depend_on_visual_sizing() -> void:
	for path in ["res://src/combat/MeleeQuery.gd", "res://src/combat/Hurtbox.gd", "res://src/player/AttackController.gd"]:
		var text := FileAccess.get_file_as_string(path)
		assert_bool(text.contains("VfxSizing") or text.contains("VfxConfig") or text.contains("TemplateVfx")).override_failure_message(
				"%s must not read visual sizing" % path).is_false()


func test_dead_player_hit_again_still_greys_out_and_aim_indicator_stays_hidden() -> void:
	var main := _spawn_main()
	await get_tree().process_frame
	var player := main.player
	var indicator: AimIndicator = main.get_node("AimIndicator")
	indicator.preview_distance = 5.0
	player.health.take_damage(player.health.get_max_health() * 2.0, "physical")
	player.health.take_damage(5.0, "physical")  # the soak does this too
	# Slow-mo (0.25) runs for 0.9 s wall time, then the 0.5 s collapse tween finishes.
	var deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline and not main.is_game_over():
		await get_tree().process_frame
	for i in range(90):
		await get_tree().process_frame
	var color := ((player.body_mesh.material_override) as StandardMaterial3D).albedo_color
	assert_float(color.r).is_equal_approx(0.25, 0.02)
	assert_float(color.g).is_equal_approx(0.25, 0.02)
	assert_bool(indicator.is_showing()).is_false()


func test_aim_indicator_and_pool_do_not_survive_a_freed_arena() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in range(3):
		var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
		(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
		add_child(main)
		await get_tree().process_frame
		EffectPool.for_world(main)
		main.free()
		await get_tree().process_frame
	assert_float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)).is_less_equal(before + 1.0)


# --- Data files and bad fixtures ---------------------------------------------------

func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_bool(typeof(parsed) == TYPE_DICTIONARY).override_failure_message("%s is not a JSON object" % path).is_true()
	return parsed as Dictionary


func test_shipped_vfx_and_ui_aim_data_validate() -> void:
	assert_array(VfxConfig.validate(_load_json("res://data/vfx.json"))).is_empty()
	assert_array(UiConfig.validate_aim(_load_json("res://data/ui.json")["aim"])).is_empty()
	assert_array(PoolDatabase.validate_table(_load_json(REAL_POOLS))).is_empty()
	assert_array(PoolDatabase.validate_table(_load_json(WATER_POOLS))).is_empty()


func test_bad_vfx_marker_and_aim_values_fail_with_a_message() -> void:
	var vfx := _load_json("res://data/vfx.json")
	for bad in [{"projectile_lane_alpha": 1.5}, {"dash_path_duration": 0.0}, {"dash_path_half_width": -1.0},
			{"projectile_lane_alpha": "x"}, {"heal_color": "green"}, {"max_simultaneous": 513}, {"hurtbox_reach_radius": -0.1}]:
		var broken := vfx.duplicate()
		broken.merge(bad, true)
		var errors := VfxConfig.validate(broken)
		assert_array(errors).override_failure_message("expected errors for %s" % [bad]).is_not_empty()
		assert_str(errors[0]).is_not_empty()
	var aim: Dictionary = _load_json("res://data/ui.json")["aim"]
	for bad in [{"dot_count": 100}, {"color": "nope"}, {"enabled": "yes"}, {"dot_alpha_far": 3.0}, {"reticle_radius": -1.0}, {"max_length": null}]:
		var broken_aim := aim.duplicate()
		broken_aim.merge(bad, true)
		assert_array(UiConfig.validate_aim(broken_aim)).override_failure_message("expected errors for %s" % [bad]).is_not_empty()
	var pools := _load_json(REAL_POOLS)
	pools["water"] = {"kind": "element", "display_name": "Water"}  # element without visual
	assert_array(PoolDatabase.validate_table(pools)).is_not_empty()
