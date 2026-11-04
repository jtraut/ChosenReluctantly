class_name Pl3ToolingTest
extends GdUnitTestSuite
## PL3 capture tooling: --press, --at-boss-attack, and a scenario played as --class.


func test_press_parses_times_and_actions() -> void:
	var parsed: Dictionary = CaptureArgs.parse(PackedStringArray(["--press=0.5:dodge,1.25:dodge"]))
	assert_str(String(parsed["error"])).is_empty()
	var presses: Array[Dictionary] = parsed["presses"]
	assert_int(presses.size()).is_equal(2)
	assert_float(float(presses[1]["at"])).is_equal(1.25)
	assert_str(String(presses[0]["action"])).is_equal("dodge")


func test_press_rejects_bad_values() -> void:
	for bad: String in ["--press=dodge", "--press=0.5:", "--press=-1:dodge", "--press=0.5:no_such_action", "--press=x:dodge"]:
		assert_str(String(CaptureArgs.parse(PackedStringArray([bad]))["error"])).override_failure_message(bad).is_not_empty()


func test_at_boss_attack_needs_a_real_attack() -> void:
	var good: Dictionary = CaptureArgs.parse(PackedStringArray(["--screenshot-after=0.3", "--at-boss-attack=volley"]))
	assert_str(String(good["error"])).is_empty()
	assert_str(String(good["boss_attack"])).is_equal("volley")
	assert_str(String(CaptureArgs.parse(PackedStringArray(["--at-boss-attack=laser"]))["error"])).is_not_empty()
	assert_str(String(CaptureArgs.parse(PackedStringArray(["--screenshot-after=1"]))["boss_attack"])).is_empty()


func test_class_arg_applies_only_to_a_scenario_with_a_known_class() -> void:
	assert_str(Scenario.class_arg(PackedStringArray(["--scenario=hp_bars", "--class=wizard"]))).is_equal("wizard")
	assert_str(Scenario.class_arg(PackedStringArray(["--class=wizard"]))).is_empty()  # the arena without a scenario stays the Rogue
	assert_str(Scenario.class_arg(PackedStringArray(["--scenario=hp_bars"]))).is_empty()


func test_a_scenario_as_the_wizard_has_the_wizards_deck_hp_and_dodge() -> void:
	var main: Main = (load("res://scenes/main/Main.tscn") as PackedScene).instantiate()
	main.get_node("EnemySpawner").process_mode = Node.PROCESS_MODE_DISABLED
	# What Main._choose_character does for `--scenario=... --class=wizard`. `main.player` is @onready (nil until the node is in the
	# tree), so the Player is fetched by path; the class must be set before add_child so it is in place for the Player's _ready.
	(main.get_node("Player") as Player).character_id = "wizard"
	add_child(main)
	auto_free(main)
	main.player.card_slots.set_deck(CharacterDatabase.starting_deck("wizard"))
	assert_int(main.player.dodge_charges_max()).is_equal(CharacterDatabase.dodge_charges("wizard", 2))
	for id: String in main.player.card_slots.owned_card_ids():
		assert_bool(CharacterDatabase.pools("wizard").has(String(CardDatabase.get_card(id).get("pool", "")))).is_true()
