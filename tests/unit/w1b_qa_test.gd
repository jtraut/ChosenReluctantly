class_name W1bQaTest
extends GdUnitTestSuite
## W1b qa additions (qa-owned): the live Ward path through a real player's Health, the Ward-never-permanent
## invariant across all data, and the one-full-volley invariant over every character id.

const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"


func after_test() -> void:
	Juice.reset()
	GamePause.reset()


func _spawn_wizard_arena() -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	(main.get_node("Player") as Player).character_id = "wizard"
	add_child(main)
	auto_free(main)
	return main


## The Ward card, executed by the real buff template on a live Wizard, reduces physical and neutral hits by 25 / (25 + 50)
## through the player's own Health, leaves fire alone, and is gone after its 4 s duration.
func test_live_ward_reduces_player_damage_then_expires() -> void:
	var main: Main = _spawn_wizard_arena()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player: Player = main.player
	assert_float(player.health.get_armor()).is_equal(0.0)
	var ward: Dictionary = CardDatabase.get_card("wizard_ward")
	var effect: Dictionary = (ward["effects"] as Array)[0]
	EffectTemplates.execute(String(effect["template"]), effect["params"], EffectContext.new(player, player))
	assert_float(player.health.get_armor()).is_equal_approx(25.0, 0.001)
	var expected_keep: float = 1.0 - CombatMath.armor_reduction(25.0, ArmorConfig.k(), ArmorConfig.reduction_cap())
	player.health.current_health = player.health.max_health
	player.health.take_damage(15.0, "physical")
	assert_float(player.health.max_health - player.health.current_health).is_equal_approx(15.0 * expected_keep, 0.01)
	assert_float(player.health.last_reduction).is_equal_approx(1.0 - expected_keep, 0.01)
	player.health.current_health = player.health.max_health
	player.health.take_damage(15.0, "neutral")
	assert_float(player.health.max_health - player.health.current_health).is_equal_approx(15.0 * expected_keep, 0.01)
	player.health.current_health = player.health.max_health
	player.health.take_damage(10.0, "fire")  # elemental: armor does not apply, only fire resistance (the Wizard has none)
	assert_float(player.health.max_health - player.health.current_health).is_equal_approx(10.0 * (1.0 - float(player.health.resistances.get("fire", 0.0))), 0.01)
	# The 4 s are real time; the ward has ended after them.
	await TestClock.wait_real(get_tree(), float((effect["params"] as Dictionary)["duration"]) + 0.5)
	assert_float(player.health.get_armor()).is_equal(0.0)
	player.health.current_health = player.health.max_health
	player.health.take_damage(15.0, "physical")
	assert_float(player.health.max_health - player.health.current_health).is_equal_approx(15.0, 0.01)


## No armor buff may outlast the cycle that recasts it, even with every cooldown reduction for that slot stacked on top
## (two copies must never give permanent armor).
func test_every_armor_buff_is_shorter_than_its_fastest_possible_recast() -> void:
	var slot_table := JsonDataTable.new("res://data/slot_types.json")
	var found: int = 0
	for card: Dictionary in CardDatabase.all_cards():
		for effect: Variant in (card["effects"] as Array):
			var params: Dictionary = (effect as Dictionary).get("params", {})
			if String((effect as Dictionary)["template"]) != "buff" or String(params.get("stat", "")) != "armor":
				continue
			found += 1
			var slot_type: String = String(card["slot_type"])
			var cycle: float = float(slot_table.get_entry(slot_type)["base_cooldown"]) + float(card.get("cooldown_modifier", 0.0))
			# Strongest case: every negative slot_cooldown buff for this slot stacks, in every class's cooldown override.
			for other: Dictionary in CardDatabase.all_cards():
				for other_effect: Variant in (other["effects"] as Array):
					var other_params: Dictionary = (other_effect as Dictionary).get("params", {})
					if String(other_params.get("stat", "")) == "slot_cooldown." + slot_type and float(other_params.get("value", 0.0)) < 0.0:
						cycle += float(other_params["value"])
			for id: String in CharacterDatabase.ids():
				var overrides: Dictionary = CharacterDatabase.slot_base_cooldowns(id)
				if overrides.has(slot_type):
					cycle = minf(cycle, float(overrides[slot_type]) + float(card.get("cooldown_modifier", 0.0)))
			assert_float(float(params["duration"])).override_failure_message("%s: armor lasts %s s but can recast every %s s" % [card["id"], params["duration"], cycle]).is_less(cycle)
	assert_int(found).override_failure_message("no armor buff card found (Ward)").is_greater(0)


## Generalises the W1b one-volley pin over every class id in the data (a third class cannot slip past). Phases only scale wind-up time, never the volley's count or damage (data/bosses.json).
func test_every_character_survives_one_full_boss_volley_from_full_hp() -> void:
	var volley: Dictionary = (BossConfig.boss("boss_guardian")["attacks"] as Dictionary)["volley"]
	var full_volley: float = float(volley["count"]) * float(volley["damage"])
	assert_int(CharacterDatabase.ids().size()).is_greater_equal(2)
	for id: String in CharacterDatabase.ids():
		assert_float(CharacterDatabase.max_hp(id)).override_failure_message("%s: %s HP vs a %s volley" % [id, CharacterDatabase.max_hp(id), full_volley]).is_greater(full_volley)
