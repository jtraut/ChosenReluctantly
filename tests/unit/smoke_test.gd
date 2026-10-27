class_name SmokeTest
extends GdUnitTestSuite


func test_framework_is_wired_up() -> void:
	assert_int(2 + 2).is_equal(4)
