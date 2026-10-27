class_name CardSlotControllerTest
extends GdUnitTestSuite
## Loads the real tests/fixtures/cards_valid set (1 attack_single/rogue card,
## 1 recovery/neutral card) rather than data/cards/, which is still empty
## pending the starter-card authoring task.


func before_test() -> void:
	CardDatabase.load_all("res://tests/fixtures/cards_valid")


func test_owned_pools_filter_which_cards_a_slot_gets() -> void:
	var caster: Node3D = auto_free(Node3D.new())
	var owned: Array[String] = ["rogue", "neutral"]
	var controller := CardSlotController.new(caster, caster, "player", StatModifiers.new(), owned)

	assert_bool(controller.get_slot("attack_single").has_cards()).is_true()
	assert_bool(controller.get_slot("recovery").has_cards()).is_true()
	assert_bool(controller.get_slot("attack_aoe").has_cards()).is_false()


func test_a_pool_the_character_does_not_own_is_excluded() -> void:
	var caster: Node3D = auto_free(Node3D.new())
	var owned: Array[String] = ["neutral"]
	var controller := CardSlotController.new(caster, caster, "player", StatModifiers.new(), owned)

	assert_bool(controller.get_slot("attack_single").has_cards()).is_false()
	assert_bool(controller.get_slot("recovery").has_cards()).is_true()


func test_try_use_casts_the_cards_effect_and_starts_cooldown() -> void:
	var caster: Node3D = auto_free(Node3D.new())
	var health: Health = auto_free(Health.new())
	health.name = "Health"
	health.max_health = 30.0
	health.current_health = 10.0
	caster.add_child(health)

	var owned: Array[String] = ["neutral"]
	var controller := CardSlotController.new(caster, caster, "player", StatModifiers.new(), owned)

	var slot := controller.get_slot("recovery")
	assert_bool(slot.is_ready()).is_true()

	var used := controller.try_use("recovery")
	assert_bool(used).is_true()
	assert_float(health.current_health).is_equal_approx(25.0, 0.001)
	assert_bool(slot.is_ready()).is_false()


func test_try_swap_delegates_to_the_slot() -> void:
	var caster: Node3D = auto_free(Node3D.new())
	var owned: Array[String] = ["neutral"]
	var controller := CardSlotController.new(caster, caster, "player", StatModifiers.new(), owned)

	assert_bool(controller.try_swap("recovery")).is_true()
	assert_bool(controller.try_swap("attack_aoe")).is_false()


func test_slot_type_at_index_matches_the_five_keys() -> void:
	assert_str(CardSlotController.slot_type_at_index(0)).is_equal("attack_single")
	assert_str(CardSlotController.slot_type_at_index(4)).is_equal("recovery")
	assert_str(CardSlotController.slot_type_at_index(5)).is_equal("")
