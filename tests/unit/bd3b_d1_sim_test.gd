class_name Bd3bD1SimTest
extends GdUnitTestSuite
## BD3b-D1: the bot sim's stand-in caster carries a status manager (self-applied Charge exists) and the plan view carries the live
## self_stacks, hp_fraction and deck_card_ids, so Thesis scaling and the hp_below / deck_count_at_least conditions read live values.

const SimCasterScript := preload("res://tools/sim_caster.gd")
const DT := 1.0 / 60.0
const THESIS := "wizard_thesis_defense"


func before_test() -> void:
	CardDatabase.load_all()
	CombatEvents.reset()


func after_test() -> void:
	CombatEvents.reset()


func _caster() -> Node3D:
	var caster: Node3D = auto_free(SimCasterScript.new())
	add_child(caster)
	var health := Health.new()
	health.name = "Health"
	health.max_health = 30.0
	caster.add_child(health)
	return caster


func _controller(caster: Node3D) -> CardSlotController:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var pools: Array[String] = ["wizard", "fire", "neutral"]
	return CardSlotController.new(caster, caster, "player", caster.get("stat_modifiers"), pools, rng)


func _give_charge(caster: Node3D, times: int) -> void:
	var context := EffectContext.new(caster, caster, "player")
	context.origin = "card:test"
	for i in range(times):
		EffectTemplates.execute("apply_status", {"status_id": "charge", "duration": 4.0, "target": "self"}, context)


func test_self_applied_charge_exists_and_stacks_in_the_sim() -> void:
	var caster := _caster()
	_give_charge(caster, 3)
	assert_int(CasterStats.self_stacks(caster, "charge")).is_equal(3)
	var fields: Dictionary = caster.call("live_view_fields", _controller(caster))
	assert_int(int((fields["self_stacks"] as Dictionary).get("charge", 0))).is_equal(3)


func test_sim_charge_decays_when_the_sim_steps() -> void:
	var caster := _caster()
	_give_charge(caster, 2)
	var decay: float = float((StatusDatabase.get_status("charge")["stacking"] as Dictionary)["decay_after"])
	for i in range(int((decay + 0.5) / DT)):
		caster.call("step", DT)
	assert_int(CasterStats.self_stacks(caster, "charge")).is_equal(0)


func test_a_scaled_card_reads_the_live_charge_and_uses_it_up() -> void:
	var caster := _caster()
	var controller := _controller(caster)
	_give_charge(caster, 4)
	var scale: Dictionary = (CardDatabase.get_card(THESIS)["effects"][0] as Dictionary)["scale"]
	var base: float = float(CardDatabase.get_card(THESIS)["effects"][0]["params"]["damage"])
	var context := EffectContext.new(caster, caster, "player")
	context.deck_card_ids = controller.owned_card_ids()
	var scaled: Dictionary = EffectScale.apply(scale, "projectile", {"damage": base}, context)
	assert_float(float(scaled["damage"])).is_equal_approx(base + 4.0 * float(scale["per"]), 0.0001)
	assert_int(CasterStats.self_stacks(caster, "charge")).override_failure_message("consume uses the Charge up").is_equal(0)


func test_hp_below_reads_the_live_hp_in_the_plan_view() -> void:
	var caster := _caster()
	var controller := _controller(caster)
	var card: Dictionary = CardDatabase.get_card("wizard_hostile_feedback")
	var view: Dictionary = {"enemies": []}
	view.merge(caster.call("live_view_fields", controller))
	assert_bool(SlotSynergy.is_live(card, view)).is_false()
	(caster.get_node("Health") as Health).current_health = 5.0
	view.merge(caster.call("live_view_fields", controller), true)
	assert_float(float(view["hp_fraction"])).is_equal_approx(5.0 / 30.0, 0.0001)
	assert_bool(SlotSynergy.is_live(card, view)).is_true()


func test_deck_count_and_self_stacks_conditions_read_the_live_view() -> void:
	var caster := _caster()
	var controller := _controller(caster)
	var deck_card: Dictionary = {"effects": [{"template": "aoe", "params": {"damage": 1.0, "damage_type": "neutral", "radius": 1.0}, "condition": {"type": "deck_count_at_least", "tag": "Projectile", "count": 1}}]}
	var stack_card: Dictionary = {"effects": [{"template": "aoe", "params": {"damage": 1.0, "damage_type": "neutral", "radius": 1.0}, "condition": {"type": "self_stacks_at_least", "status_id": "charge", "count": 2}}]}
	var view: Dictionary = {"enemies": []}
	view.merge(caster.call("live_view_fields", controller))
	var ids: Array = view["deck_card_ids"]
	assert_array(ids).is_not_empty()
	assert_bool(ids.any(func(id: Variant) -> bool: return CardDatabase.has_tag(String(id), "Projectile"))).is_true()
	assert_bool(SlotSynergy.is_live(deck_card, view)).is_true()
	assert_bool(SlotSynergy.is_live(stack_card, view)).is_false()
	_give_charge(caster, 2)
	view.merge(caster.call("live_view_fields", controller), true)
	assert_bool(SlotSynergy.is_live(stack_card, view)).is_true()
