extends RefCounted
class_name SceneSelfCheck
## Catches "empty world" regressions: every node can exist and the console
## stay silent while the player still sees nothing (e.g. a camera aimed at
## the sky). So besides checking that the camera/player/floor/light exist,
## this checks that the camera can actually see the player and the floor.
## Shared by Main's startup check and the headless smoke test.


## Returns one human-readable line per problem; empty means the scene is OK.
## Call after Main has wired the camera rig to the player (end of _ready).
static func find_problems(main: Node) -> Array[String]:
	var problems: Array[String] = []

	var camera: Camera3D = main.get_viewport().get_camera_3d() if main.is_inside_tree() else null
	if camera == null or not camera.current:
		problems.append("no current Camera3D")

	var player := main.get_node_or_null("Player") as Player
	if player == null:
		problems.append("no Player node")
	else:
		if not _has_visible_mesh(player):
			problems.append("Player has no visible mesh")
		if player.health == null or player.health.current_health <= 0.0:
			problems.append("Player health is not above zero")

	var floor_node := main.get_node_or_null("Floor") as GeometryInstance3D
	if floor_node == null or not floor_node.visible:
		problems.append("no visible Floor")

	if main.find_children("*", "Light3D", true, false).is_empty():
		problems.append("no Light3D")

	var spawner := main.get_node_or_null("EnemySpawner") as EnemySpawner
	if spawner == null:
		problems.append("no EnemySpawner")
	else:
		for stage: Dictionary in (WaveConfig.get_config()["stages"] as Array):
			for entry: Dictionary in (stage["spawns"] as Array):
				if EnemyConfig.scene_path_for(String(entry["enemy"])) == "":
					problems.append("wave table names enemy '%s' with no scene" % entry["enemy"])

	if camera != null:
		if -camera.global_basis.z.y >= 0.0:
			problems.append("camera is not looking down at the arena (forward = %s)" % -camera.global_basis.z)
		if player != null and not camera.is_position_in_frustum(player.global_position):
			problems.append("Player is outside the camera's view")
		if floor_node != null and not camera.is_position_in_frustum(floor_node.global_position):
			problems.append("Floor is outside the camera's view")

	return problems


static func _has_visible_mesh(root: Node) -> bool:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.visible and mesh_instance.mesh != null:
			return true
	return false
