extends Node
## PL3 item 13: what one Fan of regrets volley costs the Wizard, measured on the real boss and real pellets.
## For each boss phase (wind-up 0.75 s in phase 1, 0.64 s in phase 3) and each distance, the boss winds up a volley at a
## Wizard with real HP (no card, no dodge), and at the start of the wind-up (aim now locked on where the Wizard stood) the
## Wizard is placed either where it stood (the centre lane: "stands still"), in the gap between two lanes, or one lane
## width off the fan. Logs the HP lost, the pellets that hit, and the gap geometry. Prints PROBE lines.
## godot --headless --fixed-fps 60 --path . res://tools/VolleyProbe.tscn
const BOSS_PATH := "res://scenes/enemies/BossGuardian.tscn"
const DISTANCES: Array[float] = [4.0, 6.0, 8.0, 10.0, 12.0]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Juice.hit_stop_enabled = false
	var main: Main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	main.get_node("EnemySpawner").process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	await get_tree().physics_frame
	var player: Player = main.player
	player.character_id = "wizard"
	player.camera = null
	player.attacks.set_auto(&"light", false)
	player.attacks.set_auto(&"heavy", false)
	player.health.max_health = CharacterDatabase.max_hp("wizard")
	var volley: Dictionary = BossConfig.boss("boss_guardian")["attacks"]["volley"]
	var damage: float = float(volley["damage"])
	var count: int = int(volley["count"])
	var spread: float = float(volley["spread_degrees"])
	var half_width: float = BossRules.volley_half_width(volley)
	var step: float = spread / float(count - 1)
	print("PROBE volley: %d pellets x %.1f damage = %.1f if all hit; Wizard HP %.1f; lane spacing %.1f deg; pellet speed %.1f m/s, hit half-width vs player %.2f m; Wizard move speed %.1f m/s" % [
		count, damage, damage * count, player.health.max_health, step, float(volley["speed"]), half_width, player.get_move_speed()])
	var rules: Dictionary = (BossConfig.get_config()["rules"] as Dictionary)
	for phase: int in [0, 2]:
		var windup: float = float(volley["windup"]) * float(((BossConfig.boss("boss_guardian")["phases"] as Array)[phase] as Dictionary)["windup_scale"])
		for distance: float in DISTANCES:
			var gap_free: float = 2.0 * distance * tan(deg_to_rad(step * 0.5)) - 2.0 * half_width
			var lateral_to_gap: float = distance * tan(deg_to_rad(step * 0.5))
			var line: String = "PROBE phase %d windup %.2f s, %4.1f m: free gap %5.2f m, lateral move to its middle %.2f m (%.2f s of walking)" % [phase + 1, windup, distance, gap_free, lateral_to_gap, lateral_to_gap / player.get_move_speed()]
			for placement: Array in [["stand still (centre lane)", 0.0], ["gap between lanes", step * 0.5], ["one lane past the fan", spread * 0.5 + step]]:
				var result: Dictionary = await _trial(main, player, phase, distance, deg_to_rad(float(placement[1])))
				line += " | %s: %.1f HP (%d pellets)" % [placement[0], float(result["hp"]), int(result["pellets"])]
			print(line)
	get_tree().quit()


func _trial(main: Main, player: Player, phase: int, distance: float, shift: float) -> Dictionary:
	player.global_position = Vector3(0.0, 0.2, 12.0)
	player.velocity = Vector3.ZERO
	player.health.damage_immune = false
	player.health.heal(player.health.get_max_health())
	player.health.max_health = player.health.max_health  # real HP, not the arena's
	var boss: Boss = (load(BOSS_PATH) as PackedScene).instantiate()
	boss.position = player.global_position + Vector3(0.0, 0.0, -distance)
	boss.target = player
	boss.spawn_index = 0
	main.add_child(boss)
	boss.set_seed(7)
	await get_tree().physics_frame
	boss.debug_set_phase(phase)
	boss.begin_spawn_grace(99.0)  # it only throws the volley this trial asks for
	var hp_before: float = player.health.current_health
	var pellets: Array[int] = [0]
	var counter: Callable = func(_amount: float, _type: String, _knockback: Vector3) -> void: pellets[0] += 1
	player.health.damaged.connect(counter)
	boss.attack_landed.connect(func(_id: String, _hit: bool) -> void: boss.set_physics_process(false))  # one volley only: no chase, no smash after it
	boss._begin_windup("volley")  # aim locks on the player where it stands now
	var rel: Vector3 = (player.global_position - boss.global_position)
	player.global_position = boss.global_position + rel.rotated(Vector3.UP, shift)  # then the Wizard sidesteps by `shift`
	player.velocity = Vector3.ZERO
	for i in range(210):
		await get_tree().physics_frame
		if player.health.current_health <= 0.0:
			break
	player.health.damaged.disconnect(counter)
	var lost: float = hp_before - maxf(player.health.current_health, 0.0)
	boss.queue_free()
	for child in main.get_children():
		if child is Projectile:
			child.queue_free()
	await get_tree().physics_frame
	return {"hp": lost, "pellets": pellets[0]}
