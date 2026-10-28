class_name GameOverScreenTest
extends GdUnitTestSuite
## Game Over screen: hidden at start, shown on game_over_ready, Try again is
## focused and calls restart (against a stub, never a real reload).

const SCENE_PATH := "res://scenes/ui/GameOverScreen.tscn"


class StubMain extends Node:
	signal game_over_ready()
	var over: bool = false
	var restarts: int = 0

	func is_game_over() -> bool:
		return over

	func restart_arena() -> void:
		restarts += 1


func _make(stub: StubMain) -> GameOverScreen:
	add_child(stub)
	auto_free(stub)
	var screen: GameOverScreen = (load(SCENE_PATH) as PackedScene).instantiate()
	screen.bind(stub)
	add_child(screen)
	auto_free(screen)
	return screen


func test_hidden_until_game_over_ready() -> void:
	var stub := StubMain.new()
	var screen := _make(stub)
	assert_bool(screen.visible).is_false()
	stub.game_over_ready.emit()
	assert_bool(screen.visible).is_true()


func test_try_again_has_focus_and_calls_restart() -> void:
	var stub := StubMain.new()
	var screen := _make(stub)
	var retries: Array[int] = []
	screen.retry_requested.connect(func() -> void: retries.append(1))
	stub.game_over_ready.emit()
	assert_bool(screen.try_again.has_focus()).is_true()
	screen.try_again.pressed.emit()
	assert_int(stub.restarts).is_equal(1)
	assert_array(retries).has_size(1)


func test_late_built_screen_shows_if_already_over() -> void:
	var stub := StubMain.new()
	stub.over = true
	var screen := _make(stub)
	assert_bool(screen.visible).is_true()


func test_text_comes_from_data_and_scale_math() -> void:
	var stub := StubMain.new()
	var screen := _make(stub)
	assert_str(screen.try_again.text).is_equal(UiConfig.game_over()["button"])
	assert_float(GameOverScreen.ui_scale(1440.0, 720.0)).is_equal(2.0)
	assert_float(GameOverScreen.ui_scale(0.0, 720.0)).is_equal(1.0)
	assert_float(GameOverScreen.ui_scale(720.0, 0.0)).is_equal(1.0)


func test_main_scene_has_screen_above_hud() -> void:
	var main: Main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	auto_free(main)
	var screen := main.get_node("GameOverScreen") as GameOverScreen
	assert_object(screen).is_not_null()
	assert_int(screen.layer).is_greater((main.get_node("Hud") as CanvasLayer).layer)
