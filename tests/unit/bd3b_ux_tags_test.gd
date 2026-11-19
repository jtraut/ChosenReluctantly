class_name Bd3bUxTagsTest
extends GdUnitTestSuite
## BD3b-ux: the pool tag ("Fire", data/pools.json `tag`) stays off every chip row but stays in the full tag line; Liquidate Assets' current value on the
## pause screen's relic list.


func test_the_pool_tag_is_a_real_tag_on_fire_cards_but_never_a_chip() -> void:
	var tags: Array[String] = PoolDatabase.all_pool_tags()
	assert_bool(tags.is_empty()).is_false()
	var checked: int = 0
	for card: Variant in CardDatabase.all_cards():
		var id: String = String((card as Dictionary)["id"])
		var chips: Array[String] = SlotSynergy.chips(id)
		var shown: Array[String] = ChipRow.texts_for(chips)["texts"]
		for tag: String in tags:
			assert_bool(shown.has(tag)).override_failure_message("%s shows the pool tag %s as a chip" % [id, tag]).is_false()
		if chips.has(tags[0]):
			checked += 1
			assert_bool(CardDatabase.has_tag(id, tags[0])).is_true()  # the tag still exists for conditions and relics
			assert_str(LoadoutEditorScreen.detail_chips_text(id)).contains(tags[0])  # and the editor's full line names it
	assert_int(checked).is_greater(0)


func test_hiding_the_pool_tag_keeps_the_other_chips_in_order() -> void:
	var fire_tag: String = PoolDatabase.all_pool_tags()[0]
	var shown: Array[String] = ChipRow.texts_for(["Keystone", "Area", "Burn", fire_tag])["texts"]
	assert_array(shown).is_equal(["Keystone", "Area", "Burn"])


func test_the_chip_filter_is_data_driven() -> void:
	var hud: Dictionary = UiConfig.hud()
	assert_bool(hud.has("chip_hide_pool_tags")).is_true()


# --- Liquidate Assets ---

func _ctx() -> Dictionary:
	return RunChoices.shipped_context(["neutral", "rogue"] as Array[String])


func test_liquidate_assets_shows_its_current_value_from_the_run_stat() -> void:
	var ctx: Dictionary = _ctx()
	var relic: Dictionary = (ctx["relics"]["by_id"] as Dictionary)["liquidate_assets"]
	var mod: Dictionary = (relic["modifiers"] as Array)[0]
	var state := RunState.new()
	state.relics = ["liquidate_assets"] as Array[String]
	for spent: int in [0, int(mod["per"]), int(mod["per"]) * 3 + 7]:
		state.gold_spent_merchant = spent
		var shown: Dictionary = RunRelics.owned_display(state, ctx)[0]
		var steps: int = spent / int(mod["per"])
		var expected_percent: int = roundi(float(mod["value"]) * float(steps) * 100.0)
		assert_str(String(shown["now"])).override_failure_message("spent %d" % spent).is_equal(String(ctx["relics"]["ui"]["now_format"]) % ("Damage +%d%%" % expected_percent))


func test_a_relic_with_a_flat_rule_has_no_now_line_and_the_value_is_the_one_the_manager_applies() -> void:
	var ctx: Dictionary = _ctx()
	var state := RunState.new()
	state.relics = ["liquidate_assets", "pyre_insurance"] as Array[String]
	state.gold_spent_merchant = 200
	var owned: Array[Dictionary] = RunRelics.owned_display(state, ctx)
	assert_str(String(owned[1]["now"])).is_empty()
	var relic: Dictionary = (ctx["relics"]["by_id"] as Dictionary)["liquidate_assets"]
	var applied: float = RelicManager.scaled_value((relic["modifiers"] as Array)[0], RunRelics.run_stats(state))
	assert_str(String(owned[0]["now"])).contains("%d%%" % roundi(applied * 100.0))
	assert_dict(RunRelics.run_stats(state)).is_equal({"gold_spent_merchant": 200})
