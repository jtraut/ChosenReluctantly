class_name EffectTemplatesTest
extends GdUnitTestSuite
## Covers the parts of EffectTemplates that don't need a live physics frame
## (registry, heal, apply_status, buff). cone/aoe/projectile/dash reuse
## MeleeQuery/Projectile/Player.start_forced_move directly and are verified
## via manual playtest against the TrainingDummy - see docs/DECISIONS.md.


func test_registry_knows_all_seven_templates() -> void:
	var expected := ["projectile", "cone", "aoe", "dash", "heal", "apply_status", "buff"]
	for template_id: String in expected:
		assert_bool(EffectTemplates.is_known_template(template_id)).is_true()


func test_unknown_template_is_not_known() -> void:
	assert_bool(EffectTemplates.is_known_template("not_a_real_template")).is_false()


func test_required_params_are_declared_for_cone() -> void:
	var required := EffectTemplates.required_params("cone")
	assert_array(required).contains(["damage", "damage_type", "range", "half_angle_degrees"])


func test_heal_applies_to_casters_health_node() -> void:
	var caster: Node3D = auto_free(Node3D.new())
	var health: Health = auto_free(Health.new())
	health.name = "Health"
	health.max_health = 30.0
	health.current_health = 10.0
	caster.add_child(health)

	var context := EffectContext.new(caster, caster)
	EffectTemplates.execute("heal", {"amount": 12.0}, context)

	assert_float(health.current_health).is_equal_approx(22.0, 0.001)


func test_apply_status_applies_to_last_hits() -> void:
	var caster: Node3D = auto_free(Node3D.new())
	var target_health: Health = auto_free(Health.new())
	target_health.max_health = 20.0
	target_health.current_health = 20.0

	var target_hurtbox: Hurtbox = auto_free(Hurtbox.new())
	var status_manager: StatusEffectManager = auto_free(StatusEffectManager.new())
	status_manager.health = target_health
	target_hurtbox.health = target_health
	target_hurtbox.status_manager = status_manager

	var context := EffectContext.new(caster, caster)
	context.last_hits = [target_hurtbox]
	EffectTemplates.execute("apply_status", {"status_id": "burn", "duration": 2.0}, context)

	assert_bool(status_manager.has_status("burn")).is_true()


func test_buff_adds_a_modifier_to_casters_stat_modifiers() -> void:
	# Uses the real Player class (it declares stat_modifiers) rather than a
	# fake double. Not added to a tree, so get_tree() is null and the
	# buff's timed-expiry scheduling is skipped - fine, this test only
	# checks the modifier was applied, not that it expires.
	var caster: Player = auto_free(Player.new())

	var context := EffectContext.new(caster, caster)
	EffectTemplates.execute("buff", {
		"stat": "slot_cooldown.attack_single",
		"modifier_type": StatModifiers.ADDITIVE,
		"value": -0.5,
		"duration": 5.0,
	}, context)

	assert_float(caster.stat_modifiers.apply("slot_cooldown.attack_single", 2.0)).is_equal_approx(1.5, 0.001)
