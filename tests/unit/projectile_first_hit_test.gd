class_name ProjectileFirstHitTest
extends GdUnitTestSuite
## PL2 item 6: a bolt hits only the first enemy on its line, even when two hurtboxes are entered in the same step.


func _target(parent: Node) -> Hurtbox:
	var health := Health.new()
	health.name = "Health"
	health.max_health = 50.0
	health.current_health = 50.0
	parent.add_child(health)
	var hurtbox := Hurtbox.new()
	hurtbox.team = "enemy"
	parent.add_child(hurtbox)
	hurtbox.health = health
	return hurtbox


func test_second_overlapping_hurtbox_in_the_same_step_is_not_hit() -> void:
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	var shot: Projectile = auto_free((load("res://scenes/effects/Projectile.tscn") as PackedScene).instantiate())
	holder.add_child(shot)
	shot.launch(Vector3.ZERO, Vector3.FORWARD, 5.0, "neutral", 24.0, 12.0, "player")
	var first := _target(holder)
	var second := _target(holder)
	shot._on_area_entered(first)
	shot._on_area_entered(second)
	assert_float(first.health.current_health).is_equal(45.0)
	assert_float(second.health.current_health).is_equal(50.0)
