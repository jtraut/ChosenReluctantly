class_name C1eCuesTest
extends GdUnitTestSuite
## C1-e: the readability cues for the C1 cards. Status kinds from data, the ghosted player, heal numbers,
## the Leech drain pulse (both signal orders), the zone burn-down timer, the placed-skill reticle, the dash
## arrowhead, the F3 count lines and the HP-bar Bleed pip.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"
const DEFAULTS := "res://data/settings.json"

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
	for i in range(1, 6):
		TestInput.release(StringName("slot_%d" % i))


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _main() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	_root_main = main
	main.player.card_slots.spawn_parent = main
	main.player.camera = null
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	return main


func _enemy_at(main: Main, offset: Vector3) -> Enemy:
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	main.add_child(enemy)
	enemy.global_position = main.player.global_position + offset
	return enemy


func _cues(main: Main) -> PlayerCues:
	return main.player.get_node("PlayerCues") as PlayerCues


# --- status visual kinds (data-driven) -----------------------------------------------------------

func test_shipped_bleed_regeneration_and_leech_have_valid_visuals() -> void:
	for status_id: String in ["bleed", "regeneration", "leech", "burn", "stun"]:
		var def: Dictionary = StatusDatabase.get_status(status_id)
		assert_bool(def.is_empty()).override_failure_message(status_id).is_false()
		assert_bool(def.has("visual")).override_failure_message("%s has no visual" % status_id).is_true()
		assert_array(StatusDatabase.validate_entry(def)).override_failure_message(status_id).is_empty()
	assert_str(String((StatusDatabase.get_status("bleed")["visual"] as Dictionary)["kind"])).is_equal("drips")
	assert_str(String((StatusDatabase.get_status("regeneration")["visual"] as Dictionary)["kind"])).is_equal("ring")
	assert_str(String((StatusDatabase.get_status("leech")["visual"] as Dictionary)["kind"])).is_equal("orbs")


func test_visual_validation_covers_the_new_kinds() -> void:
	var base: Dictionary = {"effect_type": "damage_over_time", "display_name": "X", "damage_type": "physical", "damage_per_tick": 1.0, "tick_interval": 1.0}
	for kind: String in StatusDatabase.VISUAL_KINDS:
		var entry: Dictionary = base.duplicate()
		var visual: Dictionary = {"kind": kind, "size": 0.2}
		if kind == "stars" or kind == "orbs":
			visual.merge({"count": 2, "orbit_radius": 0.5, "orbit_hz": 1.0})
		entry["visual"] = visual
		assert_array(StatusDatabase.validate_entry(entry)).override_failure_message(kind).is_empty()
	for bad: Dictionary in [{"kind": "sparkles", "size": 0.2}, {"kind": "drips", "size": 0.2, "offset": -1.0}, {"kind": "orbs", "size": 0.2, "height": 9.0}, {"kind": "orbs", "size": 0.2, "count": 0, "orbit_radius": 0.5, "orbit_hz": 1.0}]:
		var entry: Dictionary = base.duplicate()
		entry["visual"] = bad
		assert_array(StatusDatabase.validate_entry(entry)).override_failure_message(str(bad)).is_not_empty()


func test_bleed_cue_starts_ticks_drops_and_ends_with_the_status() -> void:
	var main: Main = _main()
	var enemy: Enemy = _enemy_at(main, Vector3(3, 0, 0))
	await _frames(2)
	var manager: StatusEffectManager = enemy.status_manager
	var pool: EffectPool = EffectPool.for_world(main)
	manager.apply_status("bleed", StatusDatabase.get_status("bleed"), 2.0)
	assert_bool(manager._flames.has("bleed")).is_true()
	assert_bool(pool.is_running(manager._flames["bleed"], int(manager._flame_generations["bleed"]))).is_true()
	var before: int = pool.active_count()
	manager._tick(manager._active["bleed"])  # a Bleed tick adds one falling drop
	assert_int(pool.active_count()).is_equal(before + 1)
	manager.apply_status("bleed", StatusDatabase.get_status("bleed"), 2.0)  # refresh: no second drip
	assert_int(manager._flames.size()).is_equal(1)
	manager._process(3.0)
	assert_bool(manager._flames.has("bleed")).is_false()


func test_regeneration_and_leech_cues_follow_their_status() -> void:
	var main: Main = _main()
	await _frames(2)
	var manager: StatusEffectManager = main.player.status_manager
	manager.apply_status("regeneration", StatusDatabase.get_status("regeneration"), 5.0)
	manager.apply_status("leech", StatusDatabase.get_status("leech"), 5.0)
	assert_bool(manager._flames.has("regeneration")).is_true()
	assert_bool(manager._flames.has("leech")).is_true()
	assert_int((manager._extra_effects["leech"] as Array).size()).is_equal(1)  # 2 orbs: 1 main + 1 extra
	manager._process(6.0)
	assert_bool(manager._flames.is_empty()).is_true()


func test_regeneration_tick_adds_a_mote_only_when_it_heals() -> void:
	var main: Main = _main()
	await _frames(2)
	var player: Player = main.player
	var manager: StatusEffectManager = player.status_manager
	var pool: EffectPool = EffectPool.for_world(main)
	manager.apply_status("regeneration", StatusDatabase.get_status("regeneration"), 5.0)
	var full: int = pool.active_count()
	manager._tick(manager._active["regeneration"])
	assert_int(pool.active_count()).override_failure_message("a tick at full HP draws nothing").is_equal(full)
	player.health.take_damage(10.0)
	manager._tick(manager._active["regeneration"])
	assert_int(pool.active_count()).is_equal(full + 1)


# --- the HP bar pip ---------------------------------------------------------------------------------

func test_bleed_sets_the_second_pip_channel_and_burn_the_first() -> void:
	var main: Main = _main()
	var enemy: Enemy = _enemy_at(main, Vector3(3, 0, 0))
	await _frames(2)
	var bar: Node = enemy.get_node("EnemyHpBar")
	enemy.status_manager.apply_status("bleed", StatusDatabase.get_status("bleed"), 5.0)
	assert_bool(bar.get_instance_shader_parameter("status_flags") == Color(0.0, 1.0, 0.0, 0.0)).is_true()
	enemy.status_manager.apply_status("burn", StatusDatabase.get_status("burn"), 5.0)
	assert_bool(bar.get_instance_shader_parameter("status_flags") == Color(1.0, 1.0, 0.0, 0.0)).is_true()
	enemy.status_manager._process(10.0)
	assert_bool(bar.get_instance_shader_parameter("status_flags") == Color(0.0, 0.0, 0.0, 0.0)).is_true()


# --- ghosted player ------------------------------------------------------------------------------------

func test_pure_cue_rules() -> void:
	assert_float(PlayerCues.ghost_transparency(0.45)).is_equal_approx(0.55, 0.0001)
	assert_float(PlayerCues.ghost_transparency(2.0)).is_equal(0.0)
	assert_float(PlayerCues.heal_between(10.0, 14.0)).is_equal(4.0)
	assert_float(PlayerCues.heal_between(10.0, 6.0)).is_equal(0.0)
	assert_int(PlayerCues.heal_number_value(0.2)).is_equal(0)
	assert_int(PlayerCues.heal_number_value(2.6)).is_equal(3)
	assert_bool(PlayerCues.drain_due(5, 5, 5)).is_true()
	assert_bool(PlayerCues.drain_due(4, 5, 5)).is_false()
	assert_bool(PlayerCues.drain_due(5, 4, 5)).is_false()
	assert_bool(PlayerCues.drain_allowed(1000, 950, 0.1)).is_false()
	assert_bool(PlayerCues.drain_allowed(1100, 1000, 0.1)).is_true()


func test_pass_through_ghosts_the_body_and_survives_a_hit_flash() -> void:
	var main: Main = _main()
	await _frames(2)
	var player: Player = main.player
	var cues: PlayerCues = _cues(main)
	assert_bool(cues.is_ghosted()).is_false()
	player.grant_pass_through(0.5)
	assert_float(player.body_mesh.transparency).is_greater(0.0)
	assert_object(cues._ghost_ring).is_not_null()
	player.health.take_damage(1.0)  # the hit flash tweens the albedo, never the transparency
	assert_float(player.body_mesh.transparency).is_greater(0.0)
	var pool: EffectPool = EffectPool.for_world(main)
	assert_bool(pool.is_running(cues._ghost_ring, cues._ghost_ring_generation)).is_true()
	await get_tree().create_timer(0.8, false).timeout
	await _frames(3)
	assert_bool(player.is_pass_through()).is_false()
	assert_float(player.body_mesh.transparency).is_equal(0.0)
	assert_object(cues._ghost_ring).is_null()


func test_the_ghost_look_lasts_until_the_player_is_clear_of_enemies() -> void:
	var main: Main = _main()
	var blocker: Enemy = _enemy_at(main, Vector3(0.2, 0, 0))  # standing inside the player
	await _frames(2)
	var player: Player = main.player
	var cues: PlayerCues = _cues(main)
	player.grant_pass_through(0.2)
	assert_bool(cues.is_ghosted()).is_true()
	await get_tree().create_timer(0.6, false).timeout
	await _frames(3)
	# The buff ended, but the body is still inside an enemy, so it is still non-solid and still drawn ghosted.
	assert_bool(player.is_pass_through()).is_true()
	assert_float(player.body_mesh.transparency).is_greater(0.0)
	assert_object(cues._ghost_ring).is_not_null()
	blocker.free()
	await _frames(4)
	assert_bool(player.is_pass_through()).is_false()
	assert_float(player.body_mesh.transparency).is_equal(0.0)
	assert_object(cues._ghost_ring).is_null()


# --- heal numbers ----------------------------------------------------------------------------------------

func test_heals_batch_into_one_plus_number_and_damage_shows_none() -> void:
	var main: Main = _main()
	await _frames(2)
	var player: Player = main.player
	var cues: PlayerCues = _cues(main)
	player.health.take_damage(10.0)
	Juice.reset()
	var live_before: int = Juice._live_numbers.size()
	for i in range(4):  # a Flurry's four Leech heals
		player.health.heal(1.0)
	assert_float(cues._pending_heal).is_equal(4.0)
	await _frames(4)
	assert_float(cues._pending_heal).is_equal(0.0)
	assert_int(Juice._live_numbers.size()).is_equal(live_before + 1)
	var number: DamageNumber = Juice._live_numbers.back()
	assert_str(number.text).is_equal("+4")
	assert_str(number.damage_type).is_equal(Juice.HEAL_TYPE)


func test_a_heal_at_full_hp_shows_nothing() -> void:
	var main: Main = _main()
	await _frames(2)
	var cues: PlayerCues = _cues(main)
	main.player.health.heal(5.0)
	assert_float(cues._pending_heal).is_equal(0.0)


# --- leech drain pulse -------------------------------------------------------------------------------------

func test_drain_pulse_fires_in_either_signal_order_and_is_rate_limited() -> void:
	var main: Main = _main()
	var enemy: Enemy = _enemy_at(main, Vector3(3, 0, 0))
	await _frames(2)
	var cues: PlayerCues = _cues(main)
	var pool: EffectPool = EffectPool.for_world(main)
	# Order the game really produces: the heal first, then the hit.
	var base: int = pool.active_count()
	cues._on_lifesteal_healed(1.0)
	assert_int(pool.active_count()).is_equal(base)  # not yet: the target is not known
	cues._on_damage_dealt(enemy, 3.0, "physical", Health.KIND_HIT)
	assert_int(pool.active_count()).is_equal(base + 2)  # bead and landing flash
	# The other order, after the rate limit has passed.
	cues._last_pulse_msec = -1000000
	var again: int = pool.active_count()
	cues._on_damage_dealt(enemy, 3.0, "physical", Health.KIND_HIT)
	cues._on_lifesteal_healed(1.0)
	assert_int(pool.active_count()).is_equal(again + 2)
	# A second one straight away is held back.
	var held: int = pool.active_count()
	cues._on_lifesteal_healed(1.0)
	cues._on_damage_dealt(enemy, 3.0, "physical", Health.KIND_HIT)
	assert_int(pool.active_count()).is_equal(held)


func test_a_hit_without_a_heal_draws_no_pulse() -> void:
	var main: Main = _main()
	var enemy: Enemy = _enemy_at(main, Vector3(3, 0, 0))
	await _frames(2)
	var cues: PlayerCues = _cues(main)
	var pool: EffectPool = EffectPool.for_world(main)
	var base: int = pool.active_count()
	cues._on_damage_dealt(enemy, 3.0, "physical", Health.KIND_HIT)
	assert_int(pool.active_count()).is_equal(base)


func test_the_real_leech_path_makes_a_pulse_and_a_heal_number() -> void:
	var main: Main = _main()
	var enemy: Enemy = _enemy_at(main, Vector3(2, 0, 0))
	await _frames(2)
	var player: Player = main.player
	player.health.take_damage(10.0)
	player.status_manager.apply_status("leech", StatusDatabase.get_status("leech"), 5.0)
	var pool: EffectPool = EffectPool.for_world(main)
	Juice.reset()
	var base: int = pool.active_count()
	enemy.health.take_damage(8.0, "physical", Vector3.ZERO, player, Health.KIND_HIT)
	assert_int(pool.active_count()).is_greater_equal(base + 2)
	await _frames(4)
	assert_bool(Juice._live_numbers.any(func(n: DamageNumber) -> bool: return n.damage_type == Juice.HEAL_TYPE)).is_true()


# --- zone timer and look -------------------------------------------------------------------------------------

func test_zone_look_is_data_and_validated() -> void:
	var look: Dictionary = ZoneConfig.look()
	for key: String in ZoneConfig.LOOK_RULES:
		assert_bool(look.has(key)).override_failure_message(key).is_true()
	assert_array(ZoneConfig.validate({"max_live": 6, "look": {"fill_alpha": 0.3}})).is_empty()
	for bad: Dictionary in [{"look": {"fill_alpha": 2.0}}, {"look": {"nope": 1.0}}, {"look": 3}, {"look": {"ending_blink_hz": 0.0}}]:
		var data: Dictionary = {"max_live": 6}
		data.merge(bad)
		assert_array(ZoneConfig.validate(data)).override_failure_message(str(bad)).is_not_empty()


func test_timer_and_blink_math() -> void:
	var look: Dictionary = ZoneConfig.look()
	assert_float(ZoneManager.timer_scale(0.0)).is_equal(1.0)
	assert_float(ZoneManager.timer_scale(0.25)).is_equal_approx(0.75, 0.0001)
	assert_float(ZoneManager.timer_scale(1.5)).is_equal(0.0)
	assert_float(ZoneManager.edge_alpha_at(0.1, 0.4, look)).is_equal(float(look["edge_alpha"]))  # steady early on
	var blinking: Array[float] = []
	for i in range(20):
		blinking.append(ZoneManager.edge_alpha_at(0.9, 3.6 + float(i) * 0.02, look))
	assert_float(blinking.min()).is_less(float(look["edge_alpha"]) * 0.9)
	assert_float(blinking.max()).is_less_equal(float(look["edge_alpha"]) + 0.0001)
	assert_float(ZoneManager.timer_bar_half_width(0.12, 0.2)).is_equal_approx(0.12, 0.0001)
	assert_float(ZoneManager.timer_bar_half_width(0.5, 0.2)).is_equal_approx(0.12, 0.0001)


func test_fire_wall_timer_empties_inside_the_hit_rectangle() -> void:
	var main: Main = _main()
	await _frames(2)
	var card: Dictionary = CardDatabase.get_card("fire_wall")
	var params: Dictionary = {}
	for effect: Dictionary in card["effects"]:
		if effect["template"] == "zone":
			params = effect["params"]
	var manager: ZoneManager = ZoneManager.for_world(main)
	var context := EffectContext.new(main.player, main, "player")
	context.rng = RandomNumberGenerator.new()
	context.aim_point = main.player.global_position + Vector3(0, 0, -5)
	context.arena = main.player.get_arena_rect()
	EffectTemplates.execute("zone", params, context)
	var zones: Array[Dictionary] = manager.live_zones()
	assert_int(zones.size()).is_equal(1)
	var full_length: float = VfxSizing.zone_line_half_length(float(params["length"])) * 2.0
	var zone: ZoneManager.Zone = manager._live[0]
	assert_float(zone.timer.scale.z).is_equal_approx(full_length, 0.001)  # full at the start
	assert_float(zone.timer.scale.x).is_less(VfxSizing.zone_line_half_width(float(params["width"])))
	manager.step(float(params["duration"]) * 0.5)
	assert_float(zone.timer.scale.z).is_equal_approx(full_length * 0.5, 0.01)
	assert_float(float(manager.live_zones()[0]["remaining_fraction"])).is_equal_approx(0.5, 0.01)
	assert_float(zone.fill.scale.z).override_failure_message("the fill (hit area) never shrinks").is_equal_approx(full_length, 0.001)
	manager.step(float(params["duration"]))
	assert_int(manager.live_count()).is_equal(0)
	assert_bool(zone.timer.visible).is_false()


# --- reticle and dash arrow ---------------------------------------------------------------------------------------

func _hold(player: Player, card_id: String) -> void:
	var slot_type: String = CardDatabase.get_card(card_id)["slot_type"]
	player.card_slots.get_slot(slot_type).current_card_id = card_id
	TestInput.press(StringName("slot_%d" % (CardSlotController.SLOT_TYPE_ORDER.find(slot_type) + 1)))


func test_placed_skill_shows_range_ring_marker_and_a_link_only_when_clamped() -> void:
	var main: Main = _main()
	await _frames(2)
	var player: Player = main.player
	var preview: CastPreview = player.cast_preview
	_hold(player, "fire_fireball")
	player.aim_point_override = player.global_position + Vector3(0, 0, -30)
	await _frames(3)
	assert_bool(preview._range_node.visible).is_true()
	assert_bool(preview._marker_node.visible).is_true()
	assert_bool(preview._link_node.visible).override_failure_message("clamped: the link to the real cursor shows").is_true()
	var clamped_mesh: Mesh = preview._marker_node.mesh
	var placement: Dictionary = preview.get_state()["placement"]
	assert_bool(placement["clamped"]).is_true()
	assert_float(preview._marker_node.position.distance_to(Vector3(placement["point"].x, preview._marker_node.position.y, placement["point"].z))).is_less(0.01)
	player.aim_point_override = player.global_position + Vector3(0, 0, -3)
	await _frames(3)
	assert_bool(preview._link_node.visible).is_false()
	assert_bool(preview._marker_node.mesh != clamped_mesh).override_failure_message("unclamped uses a different marker shape").is_true()
	TestInput.release(&"slot_2")
	await _frames(3)
	assert_bool(preview._range_node.visible).is_false()
	assert_bool(preview._marker_node.visible).is_false()


func test_an_unplaced_card_shows_no_reticle() -> void:
	var main: Main = _main()
	await _frames(2)
	var player: Player = main.player
	_hold(player, "rogue_overhand_whatever")
	await _frames(3)
	assert_bool(player.cast_preview._range_node.visible).is_false()


func test_dash_previews_carry_an_arrowhead_inside_the_lane() -> void:
	var leap: Array[Dictionary] = CastPreviewShapes.parts_for_card(CardDatabase.get_card("neutral_backward_leap"), CastPreviewConfig.get_config())
	assert_bool(bool(leap[0]["cosmetic_width"])).is_true()
	assert_float(float(leap[0]["yaw_offset_degrees"])).is_equal(180.0)
	var lunge: Array[Dictionary] = CastPreviewShapes.parts_for_card(CardDatabase.get_card("rogue_lunge_strike"), CastPreviewConfig.get_config())
	assert_bool(lunge[0].has("cosmetic_width")).is_false()  # a damaging lane is a hit area: the head stays inside it
	var plain: ArrayMesh = GroundOutlines.build_lane_outline(0.3, 4.0, 0.05)
	var arrow: ArrayMesh = GroundOutlines.build_lane_arrow_outline(0.3, 4.0, 0.05, 0.3, 0.6)
	var plain_vertices: PackedVector3Array = plain.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var arrow_vertices: PackedVector3Array = arrow.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_int(arrow_vertices.size()).is_equal(plain_vertices.size() + 3)
	var tip: Vector3 = arrow_vertices[arrow_vertices.size() - 1]
	assert_float(tip.z).is_equal_approx(-4.0, 0.0001)  # the tip is the far end of the lane
	for v: Vector3 in arrow_vertices:
		assert_float(absf(v.x)).is_less_equal(0.3 + 0.0001)
		assert_float(v.z).is_between(-4.0001, 0.0001)


func test_diamond_marker_mesh_is_a_closed_ring_of_four_strokes() -> void:
	var mesh: ArrayMesh = GroundOutlines.build_diamond_outline(0.5, 0.06)
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_int(vertices.size()).is_equal(24)
	for v: Vector3 in vertices:
		assert_float(absf(v.x) + absf(v.z)).is_less_equal(0.5 + 0.0001)


# --- F3 counts -------------------------------------------------------------------------------------------------------

func test_count_lines_mark_shortfalls_with_text_and_colour() -> void:
	var ok: String = DebugOverlay.count_line("Movement", {"count": 5, "required": 3, "short": 0})
	assert_str(ok).contains("Movement 5/3 ok")
	assert_str(ok).contains(DebugOverlay.OK_COLOR)
	var short: String = DebugOverlay.count_line("Recovery", {"count": 2, "required": 3, "short": 1})
	assert_str(short).contains("Recovery 2/3  SHORT -1")
	assert_str(short).contains(DebugOverlay.SHORT_COLOR)
	assert_str(short).contains("[b]")
	var check := DeckCheck.new()
	check.slots = [{"slot_type": "movement", "display_name": "Movement", "count": 5, "required": 3, "short": 0}]
	check.groups = [{"name": "Attack", "slots": [], "count": 8, "required": 10, "short": 2}]
	var lines: Array[String] = DebugOverlay.count_lines(check)
	assert_int(lines.size()).is_equal(2)
	assert_str(lines[1]).contains("Attack group 8/10  SHORT -2")
