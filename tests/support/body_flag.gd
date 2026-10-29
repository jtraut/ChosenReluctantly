class_name BodyFlag
extends RefCounted
## Test helper for data/player.json body.collide_with_enemies (C1-c). Suites written when player and
## enemy bodies passed through each other (enemies parked on top of the player) switch the flag off in
## before_test and call reset() in after_test. The solid case has its own suite (c1c_solid_enemies_test).


static func set_collide(value: bool) -> void:
	var config: Dictionary = PlayerConfig.load_from(PlayerConfig.PATH)
	(config["body"] as Dictionary)["collide_with_enemies"] = value
	PlayerConfig._cache = config


static func reset() -> void:
	PlayerConfig.reload()
