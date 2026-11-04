class_name H3QaTest
extends GdUnitTestSuite
## H3 qa: gaps found in the gameplay-dev and ux suites. Slot keys other than Q cast with Ctrl held, a volley lane's ramp is
## the same at phase 3's shorter wind-up, Boss.in_threat reaches the full lane from the muzzle, boss adds get the telegraph scale
## and the boss itself does not, mashed Space with Ctrl state, and the swap binding really has no ctrl flag.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const DEFAULTS := "res://data/settings.json"

var _original_store: SettingsStore = null
var _main: Main = null


func before_test() -> void:
	CardDatabase.load_all()
	PlayerConfig.reload()
	_original_store = Settings.store
	Settings.use_store(SettingsStore.new(DEFAULTS, "user://tests/never_written_settings.cfg"))


func after_test() -> void:
	DodgeSwitch.reset()
	GamePause.reset()
	Settings.use_store(_original_store)
	if _main != null and is_instance_valid(_main):
		get_tree().current_scene = null
		_main.free()
	_main = null
	Juice.reset()
	for code: Key in [KEY_CTRL, KEY_SHIFT, KEY_E, KEY_F, KEY_R, KEY_SPACE]:
		_key(code, false)


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _make_main() -> Main:
	_main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(_main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	return _main


func _key(code: Key, pressed: bool, shift: bool = false, ctrl: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func test_every_other_slot_key_still_casts_with_ctrl_held() -> void:
	_make_main()
	var player: Player = _main.player
	_main.player.card_slots.spawn_parent = _main
	await _frames(2)
	player.camera = null
	player.attacks.set_auto(&"light", false)
	player.attacks.set_auto(&"heavy", false)
	var slots: Array[String] = ["attack_double", "utility", "recovery"]
	var keys: Array[Key] = [KEY_E, KEY_F, KEY_R]
	var expect_index: Array[int] = [1, 2, 4]
	for n in range(keys.size()):
		_key(KEY_CTRL, true)
		await _frames(1)
		_key(keys[n], true, false, true)
		await _frames(2)
		assert_int(player.cast_input.preview_slot).override_failure_message("%s ignored with Ctrl held" % OS.get_keycode_string(keys[n])).is_equal(expect_index[n])
		_key(keys[n], false, false, true)
		await _frames(2)
		assert_bool(player.cast_input.is_previewing()).is_false()
		_key(KEY_CTRL, false)
		await _frames(1)
	assert_int(slots.size()).is_equal(3)


func test_the_movement_swap_binding_is_ctrl_with_shift_and_no_ctrl_flag() -> void:
	var found: bool = false
	for bound: InputEvent in InputMap.action_get_events(&"dead_card_swap_4"):
		var k := bound as InputEventKey
		assert_object(k).is_not_null()
		assert_int(k.physical_keycode if k.physical_keycode != 0 else k.keycode).is_equal(KEY_CTRL)
		assert_bool(k.shift_pressed).is_true()
		assert_bool(k.ctrl_pressed).is_false()
		found = true
	assert_bool(found).is_true()


func test_the_volley_lane_ramp_is_the_same_at_the_phase_three_windup() -> void:
	BossConfig.reset_cache()
	var boss: Dictionary = BossConfig.boss("boss_guardian")
	var volley: Dictionary = (boss["attacks"] as Dictionary)["volley"]
	var windup: float = BossRules.windup(volley, (boss["phases"] as Array)[2] as Dictionary)
	assert_float(windup).is_equal_approx(0.6375, 0.0001)
	var root := Node3D.new()
	add_child(root)
	var pool: EffectPool = EffectPool.for_world(root)
	var lane: PooledEffect = TemplateVfx.enemy_shot_lane(pool, Vector3.ZERO, Vector3.FORWARD, 16.0, 0.35, Color.WHITE, windup, true, true)
	assert_object(lane).is_not_null()
	assert_float(lane.duration).is_equal_approx(windup, 0.0001)
	assert_float(lane.alpha_to).is_equal(VfxConfig.marker("boss_volley_lane_alpha_end"))
	assert_float(lane.alpha_to).is_greater_equal(0.85)
	assert_float(lane.alpha_to).is_less_equal(1.0)


func test_boss_adds_get_the_telegraph_scale_and_the_boss_windup_does_not() -> void:
	BossConfig.reset_cache()
	BossStagger.disable()
	_make_main()
	var boss: Boss = (load("res://scenes/enemies/BossGuardian.tscn") as PackedScene).instantiate()
	boss.position = Vector3(0.0, 0.0, -9.0)
	boss.target = _main.player
	_main.add_child(boss)
	boss.set_seed(1)
	boss._summon("melee_chaser", 1)
	assert_int(boss.live_adds()).is_equal(1)
	var add: Enemy = boss._adds[0]
	var authored: float = float(EnemyConfig.stats_for("melee_chaser")["telegraph_duration"])
	assert_float(add.telegraph_duration).is_equal_approx(authored * EnemyConfig.telegraph_scale(), 0.0001)
	# The boss's own wind-up comes only from BossRules (phase scale), never the pressure knob.
	var volley: Dictionary = (BossConfig.boss("boss_guardian")["attacks"] as Dictionary)["volley"]
	assert_float(BossRules.windup(volley, (BossConfig.boss("boss_guardian")["phases"] as Array)[0] as Dictionary)).is_equal_approx(0.75 * float(((BossConfig.boss("boss_guardian")["phases"] as Array)[0] as Dictionary).get("windup_scale", 1.0)), 0.0001)


func test_in_threat_covers_the_whole_lane_from_the_muzzle_and_no_further() -> void:
	BossConfig.reset_cache()
	BossStagger.disable()
	_make_main()
	_main.player.camera = null
	_main.player.health.damage_immune = true
	var boss: Boss = (load("res://scenes/enemies/BossGuardian.tscn") as PackedScene).instantiate()
	boss.position = Vector3(0.0, 0.0, -9.0)
	boss.target = _main.player
	_main.add_child(boss)
	boss.set_seed(3)
	boss.debug_script_attacks(["volley"] as Array[String])
	boss.begin_spawn_grace(0.0)
	_main.player.global_position = Vector3(0.0, 0.0, 0.0)
	for i in range(300):
		await get_tree().physics_frame
		if boss.state_name() == "WINDUP":
			break
	assert_str(boss.state_name()).is_equal("WINDUP")
	var attack: Dictionary = (BossConfig.boss("boss_guardian")["attacks"] as Dictionary)["volley"]
	var angles: Array[float] = BossRules.volley_angles(int(attack["count"]), float(attack["spread_degrees"]))
	var dir: Vector3 = boss._lock_dir.rotated(Vector3.UP, deg_to_rad(angles[0]))
	var half: float = BossRules.volley_half_width(attack)
	var end: float = BossRules.MUZZLE + float(attack["shot_range"]) + half
	assert_bool(boss.in_threat(boss.global_position + dir * (end - 0.05))).override_failure_message("lane end not covered").is_true()
	assert_bool(boss.in_threat(boss.global_position + dir * (end + 0.2))).override_failure_message("threat past the lane").is_false()
	assert_bool(boss.in_threat(boss.global_position - dir * 1.0)).override_failure_message("threat behind the boss").is_false()
