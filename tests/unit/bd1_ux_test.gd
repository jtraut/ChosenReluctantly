class_name Bd1UxTest
extends GdUnitTestSuite
## BD1 ux: the slot cues (glow easing, primed numbers), the chip row's fit rule, the HUD slot fed from a live Player,
## the reward offer's chips and rule line, and the card strip's row fit at the supported sizes.

const HUD_SCENE := "res://scenes/ui/Hud.tscn"
const SIZES: Array[Vector2] = [Vector2(1024, 600), Vector2(1280, 720), Vector2(1920, 1080), Vector2(2560, 1440)]


func after_test() -> void:
	Juice.reset()
	SlotSynergyView.reset_cache()


# --- SlotCues: glow easing ---

func test_glow_rises_fast_and_never_overshoots() -> void:
	var state: Dictionary = {"level": 0.0, "hold_left": 0.0}
	for i in range(3):
		state = SlotCues.glow_step(state, true, 0.04, 0.08, 0.3, 0.25)
	assert_float(float(state["level"])).is_equal(1.0)  # three 40 ms steps cover the 80 ms attack
	state = SlotCues.glow_step(state, true, 5.0, 0.08, 0.3, 0.25)
	assert_float(float(state["level"])).is_equal(1.0)


func test_glow_holds_after_the_condition_drops_then_fades() -> void:
	var state: Dictionary = {"level": 1.0, "hold_left": 0.3}
	state = SlotCues.glow_step(state, false, 0.2, 0.08, 0.3, 0.25)
	assert_float(float(state["level"])).is_equal(1.0)  # still inside the 0.3 s hold
	state = SlotCues.glow_step(state, false, 0.2, 0.08, 0.3, 0.25)  # hold runs out here
	assert_float(float(state["level"])).is_equal(1.0)
	state = SlotCues.glow_step(state, false, 0.125, 0.08, 0.3, 0.25)
	assert_float(float(state["level"])).is_equal_approx(0.5, 0.001)
	state = SlotCues.glow_step(state, false, 1.0, 0.08, 0.3, 0.25)
	assert_float(float(state["level"])).is_equal(0.0)


func test_a_condition_flipping_every_frame_keeps_the_glow_lit() -> void:
	var state: Dictionary = {"level": 0.0, "hold_left": 0.0}
	var dark_frames: int = 0
	for i in range(120):
		state = SlotCues.glow_step(state, i % 2 == 0, 1.0 / 60.0, 0.08, 0.3, 0.25)
		if i > 12 and float(state["level"]) < 1.0:
			dark_frames += 1
	assert_int(dark_frames).override_failure_message("the glow dipped while the condition flickered").is_equal(0)


# --- SlotCues: primed marker numbers ---

func test_primed_fraction_drains_and_no_limit_is_a_full_bar() -> void:
	assert_float(SlotCues.primed_fraction(3.0, 3.0)).is_equal(1.0)
	assert_float(SlotCues.primed_fraction(1.5, 3.0)).is_equal(0.5)
	assert_float(SlotCues.primed_fraction(0.0, 3.0)).is_equal(0.0)
	assert_float(SlotCues.primed_fraction(-1.0, -1.0)).is_equal(1.0)  # no time limit
	assert_float(SlotCues.primed_fraction(5.0, 3.0)).is_equal(1.0)  # clamped


func test_charges_show_only_above_one() -> void:
	assert_str(SlotCues.charges_text(0)).is_equal("")
	assert_str(SlotCues.charges_text(1)).is_equal("")
	assert_str(SlotCues.charges_text(2)).is_equal("x2")


# --- ChipRow.fit ---

func _font() -> Font:
	return ThemeDB.fallback_font


func test_chips_are_capped_and_keep_their_order() -> void:
	var texts: Array[String] = ["Keystone", "Area", "Burn", "Zone"]
	var flags: Array[bool] = [true, false, false, false]
	var fitted: Array[Dictionary] = ChipRow.fit(texts, flags, _font(), 12, 1000.0, 3, 4.0, 3.0)
	assert_int(fitted.size()).is_equal(3)
	assert_str(String(fitted[0]["text"])).is_equal("Keystone")
	assert_bool(bool(fitted[0]["keyword"])).is_true()
	assert_bool(bool(fitted[1]["keyword"])).is_false()


func test_chips_that_do_not_fit_are_dropped_from_the_end_and_the_first_always_stays() -> void:
	var texts: Array[String] = ["Keystone", "Projectile", "Burn"]
	var flags: Array[bool] = [true, false, false]
	var full: Array[Dictionary] = ChipRow.fit(texts, flags, _font(), 12, 1000.0, 3, 4.0, 3.0)
	var first_width: float = float(full[0]["width"])
	var narrow: Array[Dictionary] = ChipRow.fit(texts, flags, _font(), 12, first_width + 5.0, 3, 4.0, 3.0)
	assert_int(narrow.size()).is_equal(1)
	assert_str(String(narrow[0]["text"])).is_equal("Keystone")
	var tiny: Array[Dictionary] = ChipRow.fit(texts, flags, _font(), 12, 1.0, 3, 4.0, 3.0)
	assert_int(tiny.size()).is_equal(1)  # a chip too wide for the row is still shown, never nothing


func test_texts_for_puts_keywords_first_by_display_name_and_can_keep_only_keywords() -> void:
	var parts: Dictionary = ChipRow.texts_for(["Primer", "Dash", "Buff"])
	assert_array(parts["texts"]).is_equal(["Primer", "Dash", "Buff"] as Array[String])
	assert_array(parts["flags"]).is_equal([true, false, false] as Array[bool])
	var only: Dictionary = ChipRow.texts_for(["Primer", "Dash", "Buff"], true)
	assert_array(only["texts"]).is_equal(["Primer"] as Array[String])


func test_every_keyword_chip_fits_a_slot_at_the_smallest_window() -> void:
	# At 1024x600 the slot is ~125 px wide and the chip font ~10 px. Keystone plus a second chip must show.
	var cfg: Dictionary = UiConfig.hud()
	var s: float = HudLayout.ui_scale(Vector2(1024, 600), cfg)
	var width: float = float((cfg["slot_size"] as Array)[0]) * s - float(cfg["fit_padding"]) * s
	for keyword: Variant in KeywordDatabase.known_ids():
		var texts: Array[String] = [KeywordDatabase.display_name(String(keyword)), "Area"]
		var flags: Array[bool] = [true, false]
		var fitted: Array[Dictionary] = ChipRow.fit(texts, flags, _font(), roundi(float(cfg["chip_font_size"]) * s), width, int(cfg["chip_max"]), float(cfg["chip_pad_x"]) * s, float(cfg["chip_gap"]) * s)
		assert_int(fitted.size()).override_failure_message("%s plus one tag must fit a slot at 1024x600" % keyword).is_greater_equal(2)


# --- the HUD slot on a live Player ---

func _hud_for(vp: Vector2) -> Dictionary:
	var sub := SubViewport.new()
	sub.size = Vector2i(vp)
	sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(sub)
	auto_free(sub)
	var hud: Hud = (load(HUD_SCENE) as PackedScene).instantiate()
	sub.add_child(hud)
	await get_tree().process_frame
	await get_tree().process_frame
	return {"hud": hud, "sub": sub}


func test_the_slot_widget_shows_chips_the_glow_and_the_primed_marker_from_an_info_dict() -> void:
	var made: Dictionary = await _hud_for(Vector2(1280, 720))
	var widget: CardSlotWidget = (made["hud"] as Hud).slot_widgets[0]
	var info: Dictionary = {"chips": ["Keystone", "Area", "Burn"], "condition_live": true, "primed": true, "primed_time_left": 1.5, "primed_duration": 3.0, "primed_charges": 2, "condition_text": "If the target has Burn"}
	widget.update_synergy(info, 0.1)
	assert_int(widget.chip_row.shown().size()).is_greater_equal(2)  # the third chip is dropped if the font makes the row too wide
	assert_str(String(widget.chip_row.shown()[0]["text"])).is_equal("Keystone")
	assert_float(widget.glow_level()).is_equal(1.0)
	assert_bool(widget.is_primed()).is_true()
	assert_float(widget.primed_fraction()).is_equal(0.5)
	assert_int(widget.primed_charges()).is_equal(2)
	# Not live any more: held, then faded; empty info clears everything.
	widget.update_synergy({}, 0.1)
	assert_float(widget.glow_level()).is_equal(1.0)
	widget.update_synergy({}, 1.0)
	widget.update_synergy({}, 1.0)
	assert_float(widget.glow_level()).is_equal(0.0)
	assert_bool(widget.is_primed()).is_false()
	assert_int(widget.chip_row.shown().size()).is_equal(0)


func test_the_hud_lights_the_slot_of_a_live_player_whose_condition_is_live() -> void:
	BodyFlag.set_collide(false)
	var main: Main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	add_child(main)
	auto_free(main)
	var player: Player = main.player
	player.card_slots.set_deck(["rogue_drive_by", "fire_fan_the_flames", "fire_kindling", "rogue_momentum", "neutral_healing_potion"] as Array[String])
	player.health.damage_immune = true
	CombatEvents.reset()
	SlotSynergyView.reset_cache()
	player.aim_point_override = player.global_position + Vector3(0.0, 0.0, -5.0)
	var enemy: Enemy = (load("res://scenes/enemies/MeleeChaser.tscn") as PackedScene).instantiate()
	main.add_child(enemy)
	enemy.global_position = player.global_position + Vector3(0.5, 0.0, -1.5)
	enemy.health.set_max_health(5000.0)
	enemy.health.heal(5000.0)
	enemy.status_manager.apply_status("burn", StatusDatabase.get_status("burn"), 0.1)
	for i in range(8):
		await get_tree().physics_frame
	var hud: Hud = main.hud
	assert_object(hud).is_not_null()
	await get_tree().process_frame
	await get_tree().process_frame
	var widget: CardSlotWidget = hud.slot_widgets[1]  # Attack: AoE
	assert_float(widget.glow_level()).override_failure_message("a Burning enemy in Fan the Flames' area must light slot 2").is_greater(0.0)
	assert_array(widget.chip_row.shown().map(func(c: Dictionary) -> String: return String(c["text"]))).contains(["Keystone"])
	BodyFlag.reset()


# --- the card strip's rows fit their slot ---

func test_card_strip_rows_fit_the_slot_with_the_chip_row_at_every_size() -> void:
	var cfg := UiConfig.hud()
	for height: float in [480.0, 540.0, 600.0, 720.0, 1080.0, 1440.0]:
		var vp := Vector2(height * 16.0 / 9.0, height)
		var made: Dictionary = await _hud_for(vp)
		for widget: CardSlotWidget in (made["hud"] as Hud).slot_widgets:
			var wanted: float = widget.custom_minimum_size.y
			assert_float(widget.get_combined_minimum_size().y).override_failure_message("slot rows are taller than the slot at height %.0f: %.1f vs %.1f" % [height, widget.get_combined_minimum_size().y, wanted]).is_less_equal(wanted + (1.0 if height >= 600.0 else 4.0))
		(made["sub"] as SubViewport).queue_free()
	assert_float(float(cfg["slot_size"][1])).is_equal(142.0)


func test_row_fit_scale_is_one_at_the_reference_size_and_shrinks_below_it() -> void:
	var cfg := UiConfig.hud()
	assert_float(CardSlotWidget.row_fit_scale(cfg, 1.0, 2)).is_equal(1.0)
	assert_float(CardSlotWidget.row_fit_scale(cfg, 600.0 / 720.0, 2)).is_less(1.0)
	assert_float(CardSlotWidget.row_fit_scale(cfg, 1.5, 3)).is_less_equal(1.0)


# --- reward offers ---

func test_a_reward_offer_shows_keystone_primer_and_payoff_chips_and_their_rules() -> void:
	var cfg: Dictionary = UiConfig.run_ui()
	var texts: Dictionary = RunConfig.ui()["option"]
	for card_id: String in ["rogue_drive_by", "fire_kindling", "wizard_well_actually"]:
		var card: Dictionary = CardDatabase.get_card(card_id)
		var opt: Dictionary = {"kind": "card", "card_id": card_id, "label": String(card.get("name", card_id)), "detail": "x", "slot_type": String(card.get("slot_type", "")), "enabled": true}
		var button := RunOptionCard.new()
		add_child(button)
		auto_free(button)
		button.setup(opt, RunOptionCard.Look.CARD, 300.0, cfg, 1.0, {"index": -1, "owned": 0, "texts": texts})
		assert_object(button.chip_row).override_failure_message(card_id + " has no chip row").is_not_null()
		var keywords: Array[String] = CardTags.keywords_of(card)
		assert_bool(keywords.is_empty()).is_false()
		var shown: Array = button.chip_row.shown().map(func(c: Dictionary) -> String: return String(c["text"]))
		assert_str(String(shown[0])).starts_with(KeywordDatabase.display_name(keywords[0]))  # BD2 ux: Keystone + Payoff share one chip
		assert_str(button.tooltip_text).contains(KeywordDatabase.rule_text(keywords[0]))
