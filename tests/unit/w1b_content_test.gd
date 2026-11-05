class_name W1bContentTest
extends GdUnitTestSuite
## W1b content: the Wizard's attack cards, the rebuilt starter, the Wizard presets, the armor wording and the ward.

const NEW_ATTACK_CARDS: Array[String] = ["wizard_bolt_volley", "wizard_overqualified_bolt", "wizard_arcane_nova"]
## BD1-B's new Fire cards by id (qa BD2: was a tag test, which would silently skip a future Keystone or Primer card).
const BD1_FIRE_CARDS: Array[String] = ["fire_fan_the_flames", "fire_kindling", "fire_heat_sink", "fire_slow_burn"]


func test_new_wizard_cards_pass_the_damage_rule_with_margin_over_the_rogue_light() -> void:
	assert_array(CardDamageRule.check_shipped()).is_empty()
	var slot_table := JsonDataTable.new("res://data/slot_types.json")
	var light: Dictionary = AttackDatabase.get_attack("light")
	var light_dps: float = float(light["damage"]) / float(light["interval"])
	for id: String in NEW_ATTACK_CARDS:
		var card: Dictionary = CardDatabase.get_card(id)
		assert_str(String(card["pool"])).is_equal("wizard")
		var cycle: float = CardDamageRule.cycle_cooldown(card, float(slot_table.get_entry(String(card["slot_type"]))["base_cooldown"]))
		var cast: float = CardDamageRule.cast_damage(card, {}, cycle)
		assert_float(cast).override_failure_message(id + " cast").is_greater_equal(1.5 * float(light["damage"]) + 0.5)
		assert_float(cast / cycle).override_failure_message(id + " dps").is_greater(light_dps + 0.2)


func test_wizard_starter_is_all_caster_and_has_the_new_attack_cards() -> void:
	var starter: Array[String] = CharacterDatabase.starting_deck("wizard")
	assert_int(starter.size()).is_equal(15)
	var per_slot: Dictionary = {}
	for id: String in starter:
		var card: Dictionary = CardDatabase.get_card(id)
		per_slot[String(card["slot_type"])] = int(per_slot.get(String(card["slot_type"]), 0)) + 1
		assert_str(String(card["pool"])).is_not_equal("rogue")
		for effect: Variant in (card["effects"] as Array):
			assert_str(String((effect as Dictionary)["template"])).override_failure_message(id + " is a cone (melee-flavoured)").is_not_equal("cone")
	for slot_type: String in ["attack_single", "attack_aoe", "utility", "movement", "recovery"]:
		assert_int(int(per_slot.get(slot_type, 0))).override_failure_message(slot_type).is_equal(3)
	for id: String in NEW_ATTACK_CARDS:
		assert_bool(starter.has(id)).is_true()
	assert_bool(DeckRules.check_shipped(starter).is_ok()).is_true()


func test_wizard_presets_exist_and_are_valid() -> void:
	var directory: Dictionary = DebugDecks.read_dir()
	assert_array(directory["problems"].keys()).is_empty()
	for preset_name: String in ["fire-heavy-wizard", "mixed-wizard", "arcane-heavy-wizard"]:
		assert_bool((directory["presets"] as Dictionary).has(preset_name)).override_failure_message(preset_name).is_true()
		assert_str(String(((directory["presets"] as Dictionary)[preset_name] as Dictionary)["class"])).is_equal("wizard")
	var mixed: Dictionary = (directory["presets"] as Dictionary)["mixed-wizard"]
	assert_array(mixed["starter"]).is_equal(CharacterDatabase.starting_deck("wizard"))
	assert_array(mixed["full"]).contains_exactly_in_any_order(CharacterDatabase.full_deck("wizard"))
	var fire_heavy: Array = ((directory["presets"] as Dictionary)["fire-heavy-wizard"] as Dictionary)["starter"]
	for id: String in RunConfig.cards_in_pools(["fire"]):
		if BD1_FIRE_CARDS.has(id):
			continue  # BD1-B's new Fire cards are in the archetype decks, not in the unchanged preset starters
		assert_bool(fire_heavy.has(id)).override_failure_message("fire-heavy-wizard lacks " + id).is_true()


func test_armor_buff_wording_and_the_ward_grants_armor() -> void:
	var ward: Dictionary = CardDatabase.get_card("wizard_ward")
	assert_str(CardSummary.effect_line(ward)).is_equal("+25 armor for 4 s")
	var health := Health.new()
	var mods := StatModifiers.new()
	health.stat_modifiers = mods
	var params: Dictionary = ((ward["effects"] as Array)[0] as Dictionary)["params"]
	mods.add_modifier(String(params["stat"]), "ward", String(params["modifier_type"]), float(params["value"]))
	assert_float(health.get_armor()).is_equal_approx(25.0, 0.001)
	# 25 / (25 + 50) of physical and neutral damage is removed; elemental damage is not.
	assert_float(health.get_armor_reduction()).is_equal_approx(1.0 / 3.0, 0.001)
	health.free()


func test_health_records_the_source_of_the_last_damage_event() -> void:
	var health: Health = auto_free(Health.new())
	health.max_health = 50.0
	health.current_health = 50.0
	var source: Node = auto_free(Node.new())
	health.take_damage(3.0, "physical", Vector3.ZERO, source)
	assert_int(health.last_source_id).is_equal(source.get_instance_id())
	health.take_damage(3.0, "physical")
	assert_int(health.last_source_id).is_equal(0)
