class_name Pl2UxTest
extends GdUnitTestSuite
## PL2 ux half: the pick-screen HUD (item 7), the Rogue melee cue (item 8), card frames in the family colour (item 9).

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const FIRE_CARD := "fire_fireball"
const CLASS_CARD := "rogue_quick_slash"
const NEUTRAL_CARD := "neutral_deep_sigh"


func before_test() -> void:
	_reset_statics()


func after_test() -> void:
	GamePause.resume()
	for child in get_children():
		if child is Main:
			child.queue_free()
	_reset_statics()
	Juice.reset()
	GamePause.reset()


func _reset_statics() -> void:
	RunSession.clear()
	RunSession.full_deck = false
	RunSession.debug_deck = {}
	RunSession.selected_character = ""
	RunSession.character_forced = false
	RunSession.forced_seed = -1
	CharacterPick.reset()
	CharacterPick.persist_override = false
	ClassPickScreen.reset()


func _idle(count: int = 2) -> void:
	for i in range(count):
		await get_tree().process_frame


# ---- item 7: the pick screen hides the HUD behind it ----

func test_the_pick_screen_hides_the_previous_class_hud_and_gives_it_back() -> void:
	ClassPickScreen.enabled_override = true
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _idle(3)
	var screen := main.get_node("ClassPickScreen") as ClassPickScreen
	assert_bool(screen.is_open()).is_true()
	assert_bool(main.hud.visible).override_failure_message("the HUD behind the pick shows another class's numbers").is_false()
	assert_bool(screen.hides_hud()).is_true()
	screen.disarm()
	screen.confirm(main.run_controller.character_id())  # same class: just closes
	assert_bool(screen.is_open()).is_false()
	assert_bool(main.hud.visible).is_true()
	assert_bool(screen.hides_hud()).is_false()


func test_without_a_pick_screen_the_hud_stays_visible() -> void:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	await _idle(3)
	assert_bool(main.hud.visible).is_true()


# ---- item 8: the melee cue ----

func test_melee_cue_applies_only_to_an_arc_light() -> void:
	assert_bool(MeleeReachCue.applies_to("arc")).is_true()
	assert_bool(MeleeReachCue.applies_to("projectile")).is_false()
	assert_bool(MeleeReachCue.applies_to("")).is_false()


func test_melee_cue_hides_with_an_enemy_in_reach_during_a_wind_up_or_when_dead() -> void:
	assert_bool(MeleeReachCue.wants_visible(true, false, false)).is_true()
	assert_bool(MeleeReachCue.wants_visible(true, true, false)).is_false()
	assert_bool(MeleeReachCue.wants_visible(true, false, true)).is_false()
	assert_bool(MeleeReachCue.wants_visible(false, false, false)).is_false()


func test_melee_cue_fades_at_its_own_rates_and_stays_in_range() -> void:
	assert_float(MeleeReachCue.fade_step(0.0, true, 0.1, 0.5, 0.1)).is_equal_approx(0.2, 0.0001)
	assert_float(MeleeReachCue.fade_step(0.5, false, 0.05, 0.5, 0.1)).is_equal_approx(0.0, 0.0001)
	assert_float(MeleeReachCue.fade_step(0.95, true, 1.0, 0.5, 0.1)).is_equal(1.0)
	assert_float(MeleeReachCue.fade_step(0.0, false, 1.0, 0.5, 0.1)).is_equal(0.0)
	assert_float(MeleeReachCue.fade_step(0.4, true, 0.1, 0.0, 0.1)).is_equal(1.0)  # a zero time does not divide by zero


func test_melee_cue_alpha_is_the_base_lifted_by_the_pulse() -> void:
	assert_float(MeleeReachCue.alpha_for(1.0, 0.0, 0.3, 0.75)).is_equal_approx(0.3, 0.0001)
	assert_float(MeleeReachCue.alpha_for(1.0, 1.0, 0.3, 0.75)).is_equal_approx(0.75, 0.0001)
	assert_float(MeleeReachCue.alpha_for(0.0, 1.0, 0.3, 0.75)).is_equal(0.0)
	assert_float(MeleeReachCue.alpha_for(0.5, 5.0, 0.3, 0.75)).is_equal_approx(0.375, 0.0001)


func test_melee_cue_band_stays_inside_the_reach() -> void:
	var mesh := MeleeReachCue.build_band(1.8, 50.0, 0.09)
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_int(vertices.size()).is_greater(0)
	var farthest: float = 0.0
	for v in vertices:
		farthest = maxf(farthest, Vector2(v.x, v.z).length())
	assert_float(farthest).is_less_equal(1.8 + 0.0001)


func test_melee_cue_config_validates_and_a_bad_block_is_reported() -> void:
	assert_array(UiConfig.validate_melee_cue(UiConfig.melee_cue())).is_empty()
	var bad: Dictionary = UiConfig.melee_cue().duplicate()
	bad["alpha"] = 1.5
	bad["color"] = "nope"
	bad["fade_in"] = -1.0
	assert_int(UiConfig.validate_melee_cue(bad).size()).is_equal(3)


func _spawn_main(character: String) -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	(main.get_node("Player") as Player).character_id = character
	add_child(main)
	auto_free(main)
	return main


func test_the_rogue_gets_the_cue_and_the_wizard_does_not() -> void:
	var rogue := _spawn_main("rogue")
	await _idle(2)
	assert_object(rogue.player.get_node_or_null("MeleeReachCue")).is_not_null()
	var wizard := _spawn_main("wizard")
	await _idle(2)
	var cue := wizard.player.get_node_or_null("MeleeReachCue") as MeleeReachCue
	assert_bool(cue == null or not cue.is_physics_processing()).override_failure_message("the Wizard's ranged bolt gets no melee cue").is_true()


func test_the_cue_shows_with_nothing_in_reach_after_the_fade_in() -> void:
	var main := _spawn_main("rogue")
	await _idle(2)
	var cue := main.player.get_node("MeleeReachCue") as MeleeReachCue
	for i in range(40):
		await get_tree().physics_frame
	assert_bool(cue.is_showing()).is_true()


# ---- item 9: frames ----

func _slot(ids: Array[String]) -> CardSlot:
	var slot := CardSlot.new("attack_single", 4.0, ids)
	slot.current_card_id = ids[0]
	slot.draw_pile = [ids[1]]
	return slot


func test_slot_widget_frame_and_next_swatch_follow_the_cards_family() -> void:
	var widget: CardSlotWidget = (load("res://scenes/ui/CardSlotWidget.tscn") as PackedScene).instantiate()
	add_child(widget)
	auto_free(widget)
	await _idle(1)
	widget.update_from_slot(_slot([FIRE_CARD, CLASS_CARD]))
	assert_object(widget.frame_color()).is_equal(PoolDatabase.frame_color_for_pool("fire"))
	assert_object(widget.next_color()).is_equal(PoolDatabase.frame_color_for_pool("rogue"))
	widget.update_from_slot(_slot([NEUTRAL_CARD, FIRE_CARD]))
	assert_object(widget.frame_color()).is_equal(PoolDatabase.frame_color_for_pool("neutral"))
	assert_object(widget.next_color()).is_equal(PoolDatabase.frame_color_for_pool("fire"))


func test_slot_widget_frame_is_the_same_ready_or_cooling() -> void:
	var widget: CardSlotWidget = (load("res://scenes/ui/CardSlotWidget.tscn") as PackedScene).instantiate()
	add_child(widget)
	auto_free(widget)
	await _idle(1)
	var slot := _slot([FIRE_CARD, CLASS_CARD])
	widget.update_from_slot(slot)
	assert_bool(widget.is_ready_state()).is_true()
	var ready_color: Color = widget.frame_color()
	slot.cooldown_remaining = 2.0
	slot.last_cooldown_duration = 4.0
	widget.update_from_slot(slot)
	assert_bool(widget.is_ready_state()).is_false()
	assert_object(widget.frame_color()).is_equal(ready_color)
	# The cooling state dims the contents, never the frame overlay.
	assert_float(widget.modulate.r).is_equal(1.0)
	assert_float(widget.name_label.modulate.r).is_equal_approx(float(UiConfig.hud()["slot_cooling_dim"]), 0.0001)


func test_ready_and_cooling_use_different_plates() -> void:
	var cfg: Dictionary = UiConfig.hud()
	assert_str(String(cfg["slot_plate_ready_color"])).is_not_equal(String(cfg["slot_plate_cooling_color"]))
	assert_float(Color.html(String(cfg["slot_plate_cooling_color"])).a).is_greater(Color.html(String(cfg["slot_plate_ready_color"])).a)


func _card(opt: Dictionary, look: RunOptionCard.Look) -> RunOptionCard:
	var card := RunOptionCard.new()
	add_child(card)
	auto_free(card)
	card.setup(opt, look, 268.0, UiConfig.run_ui(), 1.0, {"texts": RunConfig.ui().get("option", {}), "index": 0})
	return card


func test_reward_cards_and_removal_cells_wear_the_family_frame() -> void:
	for look: RunOptionCard.Look in [RunOptionCard.Look.CARD, RunOptionCard.Look.CELL]:
		for pair: Array in [[FIRE_CARD, "fire"], [CLASS_CARD, "rogue"], [NEUTRAL_CARD, "neutral"]]:
			var opt: Dictionary = {"id": "x", "kind": "card", "label": "Name", "detail": "d", "card_id": pair[0], "enabled": true}
			var card := _card(opt, look)
			var normal := card.get_theme_stylebox("normal") as StyleBoxFlat
			assert_object(normal.border_color).is_equal(PoolDatabase.frame_color_for_pool(String(pair[1])))
			assert_int(normal.border_width_left).is_greater_equal(2)
			var focus := card.get_theme_stylebox("focus") as StyleBoxFlat
			# Focus is a ring outside the card in its own colour, so it never covers or blends into the family frame.
			assert_object(focus.border_color).is_not_equal(normal.border_color)
			assert_float(focus.expand_margin_left).is_greater(0.0)


func test_the_reject_option_and_actions_keep_their_own_border() -> void:
	var cfg: Dictionary = UiConfig.run_ui()
	var reject := _card({"id": "skip", "kind": "skip", "label": "Reject", "enabled": true}, RunOptionCard.Look.REJECT)
	assert_object((reject.get_theme_stylebox("normal") as StyleBoxFlat).border_color).is_equal(Color.html(String(cfg["option_reject_border_color"])))
	var heal := _card({"id": "heal", "kind": "heal", "label": "Heal", "enabled": true}, RunOptionCard.Look.ACTION)
	assert_object((heal.get_theme_stylebox("normal") as StyleBoxFlat).border_color).is_equal(Color.html(String(cfg["option_card_border_color"])))


func test_the_focus_ring_width_has_a_floor_and_scales() -> void:
	var cfg: Dictionary = UiConfig.run_ui()
	assert_int(RunOptionCard.focus_ring_width(cfg, 0.1)).is_equal(2)
	assert_int(RunOptionCard.focus_ring_width(cfg, 2.0)).is_equal(roundi(float(cfg["option_focus_width"]) * 2.0))
