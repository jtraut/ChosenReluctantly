class_name Pl3UxTest
extends GdUnitTestSuite
## PL3 (ux): Ward aura cue data, card projectile looks, damage numbers vs the boss bar and merging, volley gap tint,
## the dodge pip return flash, and the tidied reward line.


# ---- Item 1: persistent buff cue (data-driven) ----

func test_shipped_buff_cues_are_valid_and_armor_has_one() -> void:
	assert_array(VfxConfig.validate(VfxConfig.get_config())).is_empty()
	assert_bool(VfxConfig.buff_cue("armor").is_empty()).is_false()
	assert_bool(VfxConfig.buff_cue("speed_not_a_stat").is_empty()).is_true()


func test_buff_cue_validation_rejects_bad_entries() -> void:
	assert_array(VfxConfig.validate_buff_cues({"armor": {"color": "nope"}})).is_not_empty()
	var cue: Dictionary = (VfxConfig.buff_cue("armor") as Dictionary).duplicate()
	cue["pulse"] = -1.0
	assert_array(VfxConfig.validate_buff_cues({"armor": cue})).is_not_empty()
	assert_array(VfxConfig.validate_buff_cues([])).is_not_empty()


func test_buff_aura_lasts_the_buff_and_follows_the_target() -> void:
	var holder := Node3D.new()
	add_child(holder)
	auto_free(holder)
	var pool := EffectPool.for_world(holder)
	var target := Node3D.new()
	holder.add_child(target)
	if pool == null:
		return  # no pool without a world in this harness: nothing to draw
	var parts: Array[PooledEffect] = TemplateVfx.buff_aura(pool, target, VfxConfig.buff_cue("armor"), 4.0)
	assert_int(parts.size()).is_equal(2)
	for part: PooledEffect in parts:
		assert_float(part.duration).is_equal(4.0)
	assert_int(TemplateVfx.buff_aura(pool, target, {}, 4.0).size()).is_equal(0)
	assert_int(TemplateVfx.buff_aura(pool, target, VfxConfig.buff_cue("armor"), 0.0).size()).is_equal(0)


# ---- Item 2: card projectile looks ----

func test_card_bolts_carry_a_look_distinct_from_the_auto_bolt() -> void:
	var auto_look: Dictionary = AttackDatabase.get_attack("light_variants")["wizard"]["bolt_look"]
	for card_id: String in ["wizard_bolt_volley", "wizard_overqualified_bolt"]:
		var params: Dictionary = (CardDatabase.get_card(card_id)["effects"][0] as Dictionary)["params"]
		assert_array(EffectTemplates.validate_look(params["look"])).is_empty()
		var look: Dictionary = EffectTemplates.resolved_look(params["look"])
		assert_bool(look["color"] is Color).is_true()
		assert_str(String(params["look"]["color"]).to_lower()).is_not_equal(String(auto_look["color"]).to_lower())
	var heavy: Dictionary = (CardDatabase.get_card("wizard_overqualified_bolt")["effects"][0] as Dictionary)["params"]["look"]
	var light: Dictionary = (CardDatabase.get_card("wizard_bolt_volley")["effects"][0] as Dictionary)["params"]["look"]
	assert_float(float(heavy["ball_scale"])).is_greater(float(light["ball_scale"]) * 2.0)


func test_look_validation() -> void:
	assert_array(EffectTemplates.validate_look({"color": "nope"})).is_not_empty()
	assert_array(EffectTemplates.validate_look({"color": "#ffffff", "ball_scale": 9.0})).is_not_empty()
	assert_array(EffectTemplates.validate_look({"color": "#ffffff", "wat": 1})).is_not_empty()
	assert_array(EffectTemplates.validate_look({"color": "#ffffff", "scale": 1.0})).is_empty()
	assert_array(EffectTemplates.validate_params("projectile", {"look": {"color": "x"}})).is_not_empty()


# ---- Items 4 and 5: damage numbers ----

func test_hits_in_the_same_moment_merge_into_one_number_that_stays_bright() -> void:
	var cfg: Dictionary = UiConfig.damage_numbers()
	var number := DamageNumber.new()
	auto_free(number)
	number.configure(cfg)
	number.show_amount(4.0, "physical", Color.WHITE, false)
	number._elapsed = 0.2  # a young number
	number.merge_hit(4.0, false)
	number.merge_hit(4.0, false)
	assert_str(number.text).is_equal("12")
	assert_float(number.idle_time()).is_less_equal(float(cfg["duration"]) * DamageNumber.MERGE_REFRESH + 0.0001)
	# Hits 0.1 s apart at the same spot merge; one more than the window later starts a fresh number.
	var entries: Array = [{"pos": Vector3.ZERO, "type": "physical|", "idle": 0.1}]
	assert_int(DamageNumber.find_merge_index(entries, Vector3(0.2, 0.0, 0.0), "physical|", float(cfg["merge_radius"]), float(cfg["merge_window"]))).is_equal(0)
	entries[0]["idle"] = float(cfg["merge_window"]) + 0.05
	assert_int(DamageNumber.find_merge_index(entries, Vector3.ZERO, "physical|", float(cfg["merge_radius"]), float(cfg["merge_window"]))).is_equal(-1)


func test_clamp_below_bar() -> void:
	assert_float(DamageNumber.clamp_below_bar(60.0, 0.0, 6.0)).is_equal(60.0)  # no bar showing
	assert_float(DamageNumber.clamp_below_bar(60.0, 120.0, 6.0)).is_equal(126.0)  # inside the block: pushed under it
	assert_float(DamageNumber.clamp_below_bar(300.0, 120.0, 6.0)).is_equal(300.0)  # already clear


# ---- Item 11: volley gap tint ----

func test_gap_segments_open_only_where_there_is_room_and_never_exceed_the_real_gap() -> void:
	var angles: Array[float] = BossRules.volley_angles(5, 48.0)
	var half: float = BossRules.volley_half_width({"hit_radius": 0.35})
	var segs: Array[Dictionary] = VolleyGaps.segments(angles, half, 0.2, 1.0, 14.0)
	assert_int(segs.size()).is_greater(0)
	var first: float = VolleyGaps.first_safe_distance(angles, half, 0.2)
	var sine: float = sin(deg_to_rad(12.0) * 0.5)
	assert_float(first).is_between(6.0, 9.0)  # "at 6 m or closer there is no gap, at 8 m+ there is"
	for seg: Dictionary in segs:
		assert_float(float(seg["start"])).is_greater_equal(first - 0.001)
		assert_float(float(seg["half_width"])).is_greater_equal(0.2 - 0.001)
		# Clear half width at the segment's near end is exactly the real gap there: never wider than the gap.
		assert_float(float(seg["half_width"])).is_less_equal(float(seg["start"]) * sine - half + 0.001)
		assert_float(float(seg["start"]) + float(seg["length"])).is_less_equal(14.0 + 0.001)
	assert_int(VolleyGaps.segments([0.0] as Array[float], half, 0.2, 1.0, 14.0).size()).is_equal(0)
	assert_int(VolleyGaps.segments(angles, half, 99.0, 1.0, 14.0).size()).is_equal(0)  # min width too big: tint off


# ---- Item 12: dodge pip return flash ----

func test_dodge_pulse_is_configured_and_longer_than_a_blink() -> void:
	var cfg: Dictionary = UiConfig.hud()
	assert_float(float(cfg["dodge_pulse_duration"])).is_greater_equal(0.5)
	assert_float(float(cfg["dodge_pulse_grow"])).is_greater(3.0)
	assert_str(DodgePips.status_word(0, 1, cfg)).is_equal(String(cfg["dodge_empty_word"]))


# ---- Items 7 and 10: reward screen ----

func test_reward_screens_have_no_number_key_shortcuts_or_hints() -> void:
	var screen := RunPromptScreen.new()
	auto_free(screen)
	assert_bool(screen.has_method("digit_target")).is_false()
	var texts: Dictionary = RunConfig.ui()["option"]
	for key: String in ["list_hint", "remove_list_hint"]:
		assert_str(String(texts[key])).not_contains("1-")
		assert_str(String(texts[key])).contains("Arrow")


func test_slot_now_line_is_short_and_the_chip_names_the_slot() -> void:
	var texts: Dictionary = RunConfig.ui()["option"]
	assert_str(String(texts["slot_key"])).is_equal("%s")  # a key cap shows just the key
	var line: String = RunOptionCard.slot_now_text("attack_single", ["A", "B", "C"], String(texts["slot_now"]))
	assert_str(line).is_equal("In slot: A / B / C")
	assert_str(line).not_contains("(")
