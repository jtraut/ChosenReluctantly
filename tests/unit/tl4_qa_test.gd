class_name Tl4QaTest
extends GdUnitTestSuite
## TL4 qa: the ScriptedInput carry is opt-in, keyed by the script, and never leaks into a plain instance or a different script.


func before_test() -> void:
	ScriptedInput.reset_carry()


func after_test() -> void:
	ScriptedInput.reset_carry()


func _make(presses: Array[Dictionary], carry: bool) -> ScriptedInput:
	var input := ScriptedInput.new()
	input.presses = presses
	input.carry_across_swaps = carry
	return input


func test_a_non_carrying_instance_leaves_nothing_behind() -> void:
	var presses: Array[Dictionary] = [{"at": 0.1, "action": &"dodge", "hold": 0.0}]
	var plain: ScriptedInput = _make(presses, false)
	add_child(plain)
	plain._process(0.5)
	remove_child(plain)
	plain.free()
	var carrier: ScriptedInput = _make(presses, true)
	add_child(carrier)
	assert_float(carrier._elapsed).is_equal(0.0)
	assert_int(carrier._next).is_equal(0)
	remove_child(carrier)
	carrier.free()


func test_a_different_script_does_not_resume_a_carried_position() -> void:
	var first_script: Array[Dictionary] = [{"at": 0.1, "action": &"dodge", "hold": 0.0}]
	var other_script: Array[Dictionary] = [{"at": 0.2, "action": &"dodge", "hold": 0.0}]
	var first: ScriptedInput = _make(first_script, true)
	add_child(first)
	first._process(0.5)
	remove_child(first)
	first.free()
	var other: ScriptedInput = _make(other_script, true)
	add_child(other)
	assert_float(other._elapsed).is_equal(0.0)
	assert_int(other._next).is_equal(0)
	remove_child(other)
	other.free()


func test_a_carrying_instance_resumes_the_same_script() -> void:
	var script: Array[Dictionary] = [{"at": 0.1, "action": &"dodge", "hold": 0.0}, {"at": 5.0, "action": &"dodge", "hold": 0.0}]
	var first: ScriptedInput = _make(script, true)
	add_child(first)
	first._process(0.5)
	remove_child(first)
	first.free()
	var second: ScriptedInput = _make(script, true)
	add_child(second)
	assert_float(second._elapsed).is_equal_approx(0.5, 0.0001)
	assert_int(second._next).is_equal(1)
	remove_child(second)
	second.free()
