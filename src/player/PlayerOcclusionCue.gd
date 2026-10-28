class_name PlayerOcclusionCue
extends MeshInstance3D
## The "you are behind that crowd" cue (Slice 6b): a silhouette of the player drawn only on the
## pixels where something nearer the camera hides them. It is a second copy of the body mesh
## (a child of BodyMesh, so it moves, tilts and squashes with it) with a shader that reads the
## depth buffer and draws a pixel only if the scene depth there is nearer than the body's own
## surface by more than `depth_bias`. Where the player is visible the body is its own nearest
## surface, so nothing is drawn. It is a 3D object, so it can never cover the HUD.
##
## Colour, alpha, bias and the on/off switch: data/ui.json `player_outline`. Attached by Main
## (like AimIndicator), so Player and its flash code stay untouched.

const SHADER_PATH := "res://src/player/player_occlusion_cue.gdshader"

var _material: ShaderMaterial = null


## Adds the cue under the player's BodyMesh. Returns null when disabled, or there is no body.
static func attach(player: Player) -> PlayerOcclusionCue:
	var config := UiConfig.player_outline()
	if not bool(config["enabled"]) or player == null or player.body_mesh == null or player.body_mesh.mesh == null:
		return null
	var cue := PlayerOcclusionCue.new()
	cue.name = "OcclusionCue"
	cue.mesh = player.body_mesh.mesh
	cue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cue.setup(config)
	player.body_mesh.add_child(cue)
	return cue


func setup(config: Dictionary) -> void:
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER_PATH)
	var color := Color.html(String(config["color"]))
	_material.set_shader_parameter("cue_color", Color(color, float(config["alpha"])))
	_material.set_shader_parameter("depth_bias", float(config["depth_bias"]))
	# Drawn after the opaque pass (which fills the depth texture it reads) and over world props.
	_material.render_priority = 1
	material_override = _material


## The shader parameters currently set, for tests.
func shader_parameter(name_: StringName) -> Variant:
	return _material.get_shader_parameter(name_)
