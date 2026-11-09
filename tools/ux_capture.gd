extends Node
## UX capture (P-dodge): hosts the real Main in an oversized SubViewport, drives a HUD state, saves one PNG, quits.
## Needs a renderer (not --headless). Run:
##   godot --path . res://tools/UxCapture.tscn -- --size=1024x600 --class=rogue --mode=pips_recharge --out=screenshots/ux/a.png
## Modes: pips (full), pips_recharge (one spent, a pip coming back), pips_empty (all spent), stagger (a boss at its first
## threshold, mid-stagger), continue_pick (the class pick screen with a saved run). The player is made immune and the spawner off, so the shot is only the state being checked.

const BOSS_PATH := "res://scenes/enemies/BossGuardian.tscn"
const HIT_DAMAGE := 30.0  # stagger mode: a typical card hit


func _ready() -> void:
	var size := Vector2i(1280, 720)
	var klass := "rogue"
	var mode := "pips"
	var out := "screenshots/ux/shot.png"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts: PackedStringArray = arg.substr(7).split("x")
			size = Vector2i(parts[0].to_int(), parts[1].to_int())
		elif arg.begins_with("--class="):
			klass = arg.substr(8)
		elif arg.begins_with("--mode="):
			mode = arg.substr(7)
		elif arg.begins_with("--out="):
			out = arg.substr(6)
	var container := SubViewportContainer.new()
	container.stretch = false
	add_child(container)
	var sub := SubViewport.new()
	sub.size = size
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(sub)
	var main: Main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	(main.get_node("Player") as Player).character_id = klass
	sub.add_child(main)
	(main.get_node("GameOverScreen") as GameOverScreen).bind(main)
	main.player.health.damage_immune = true
	main.player.attacks.set_auto(&"light", false)
	main.player.attacks.set_auto(&"heavy", false)
	await _wait(0.4)
	var maximum: int = main.player.dodge_charges_max()
	match mode:
		"pips_recharge":
			main.player.dodge_charges.try_spend(maximum)
			await _wait(0.5)
		"pips_empty":
			for i in range(maximum):
				main.player.dodge_charges.try_spend(maximum)
			await _wait(0.3)
		"stagger":
			var boss: Boss = (load(BOSS_PATH) as PackedScene).instantiate()
			boss.position = main.player.global_position + Vector3(0.0, 0.0, -9.0)
			boss.target = main.player
			boss.spawn_index = 0
			main.add_child(boss)
			await _wait(1.2)
			# A normal-sized hit that crosses the first threshold (a 99999 number would be a capture artefact).
			var thresholds: Array[float] = boss.phase_thresholds()
			boss.health.current_health = boss.health.get_max_health() * thresholds[0] + HIT_DAMAGE * 0.25
			boss.health.take_damage(HIT_DAMAGE, "physical")
			await _wait(0.35)
		"continue_pick":
			# MAP3 ux: the class pick with a saved run (a three-act Wizard run at the map screen after room 14). The fixture goes to user://captures/,
			# never the player's run_save.json. The screen is hosted by the capture (not a Main), so it only draws; Continue itself is tested in the suite.
			RunSession.acts_override = 3
			var saved: RunState = RunSession.begin_new_run(1, "wizard")
			saved.jump_to_room(13)
			saved.max_hp = 30.0
			saved.hp = 22.0
			RunNodes.open(saved)
			RunSave.persist_override = true
			RunSave.path = "user://captures/continue_save.json"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://captures"))
			RunSave.write(saved)
			var screen: ClassPickScreen = (load("res://scenes/ui/ClassPickScreen.tscn") as PackedScene).instantiate()
			sub.add_child(screen)
			screen.open()
			screen.disarm()
			await _wait(0.6)
			RunSession.acts_override = 0
			RunSave.reset()
	await RenderingServer.frame_post_draw
	var image := sub.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	var err := image.save_png(ProjectSettings.globalize_path(out))
	print("UxCapture: saved ", ProjectSettings.globalize_path(out), " err=", err)
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
