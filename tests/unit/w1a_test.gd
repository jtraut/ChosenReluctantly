class_name W1aTest
extends GdUnitTestSuite
## W1a, a playable Wizard (gameplay half): data/characters.json, the class in run state, the `--class` / `--deck` launch
## rules, the Wizard's ranged light and neutral heavy, class-only reward pools and the minimal Wizard card pool.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const MAIN_SCENE_PATH := "res://scenes/main/Main.tscn"
const CHASER_PATH := "res://scenes/enemies/MeleeChaser.tscn"
const OLD_ROGUE_STARTER: Array[String] = [
	"rogue_quick_slash", "rogue_overhand_whatever", "fire_ember_whatever",
	"fire_fine_burn_then", "rogue_everyone_calm_down", "neutral_shrug_bomb",
	"fire_hot_head", "neutral_deep_sigh", "rogue_not_my_problem",
	"fire_blaze_and_bail", "rogue_ugh_fine_moving", "neutral_backward_leap",
	"neutral_healing_potion", "rogue_nap_time", "neutral_regeneration",
]


func before_test() -> void:
	_reset_statics()


func after_test() -> void:
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


func _frames(count: int = 2) -> void:
	for i in range(count):
		await get_tree().physics_frame


func _spawn_arena(character: String = "") -> Main:
	var main: Main = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	(main.get_node("EnemySpawner") as Node).process_mode = Node.PROCESS_MODE_DISABLED
	if character != "":
		(main.get_node("Player") as Player).character_id = character
	add_child(main)
	auto_free(main)
	return main


func _spawn_run() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _slot_counts(deck: Array[String]) -> Dictionary:
	var per_slot: Dictionary = {}
	for card_id: String in deck:
		var slot_type: String = String(CardDatabase.get_card(card_id)["slot_type"])
		per_slot[slot_type] = int(per_slot.get(slot_type, 0)) + 1
	return per_slot


# ---- characters.json ----

func test_shipped_characters_are_valid_and_listed_rogue_first() -> void:
	assert_array(CharacterDatabase.validate_shipped()).is_empty()
	assert_array(CharacterDatabase.ids()).is_equal(["rogue", "wizard"])
	var list: Array[Dictionary] = CharacterDatabase.list()
	assert_str(String(list[0]["display_name"])).is_equal("Rogue")
	assert_str(String(list[1]["display_name"])).is_equal("Wizard")
	assert_float(float(list[1]["max_hp"])).is_equal(26.0)


func test_rogue_data_is_what_the_hardcoded_values_were() -> void:
	assert_array(CharacterDatabase.pools("rogue")).is_equal(["rogue", "fire", "neutral"])
	assert_array(CharacterDatabase.starting_deck("rogue")).is_equal(OLD_ROGUE_STARTER)
	assert_float(CharacterDatabase.max_hp("rogue")).is_equal(30.0)
	assert_array(RunConfig.starting_deck()).is_equal(OLD_ROGUE_STARTER)
	assert_array(RunConfig.character_pools()).is_equal(["rogue", "fire", "neutral"])
	assert_bool(RunConfig.get_config().has("starting_deck")).is_false()
	assert_bool(RunConfig.get_config().has("character_pools")).is_false()


func test_wizard_starter_is_15_cards_3_per_slot_and_only_its_pools() -> void:
	var deck: Array[String] = CharacterDatabase.starting_deck("wizard")
	assert_int(deck.size()).is_equal(15)
	var per_slot: Dictionary = _slot_counts(deck)
	for slot_type: String in CardSlotController.SLOT_TYPE_ORDER:
		assert_int(int(per_slot.get(slot_type, 0))).override_failure_message("slot " + slot_type).is_equal(3)
	for card_id: String in deck:
		assert_array(CharacterDatabase.pools("wizard")).contains([String(CardDatabase.get_card(card_id)["pool"])])
	assert_str(DeckRules.run_start_block_message(DeckRules.check_shipped(deck))).is_empty()


func test_wizard_full_deck_is_its_whole_pool_set_and_meets_the_rules() -> void:
	var full: Array[String] = CharacterDatabase.full_deck("wizard")
	assert_array(full).is_equal(RunConfig.cards_in_pools(["wizard", "fire", "neutral"]))
	assert_str(DeckRules.run_start_block_message(DeckRules.check_shipped(full))).is_empty()
	for card_id: String in full:
		assert_str(String(CardDatabase.get_card(card_id)["pool"])).is_not_equal("rogue")
	# Rogue's full deck has no Wizard cards either.
	for card_id: String in CharacterDatabase.full_deck("rogue"):
		assert_str(String(CardDatabase.get_card(card_id)["pool"])).is_not_equal("wizard")


func test_wizard_pool_has_two_utility_and_two_movement_cards_and_no_new_templates() -> void:
	var by_slot: Dictionary = {}
	for card: Variant in CardDatabase.cards_for_pool("wizard"):
		var slot_type: String = String((card as Dictionary)["slot_type"])
		by_slot[slot_type] = int(by_slot.get(slot_type, 0)) + 1
		for effect: Variant in ((card as Dictionary)["effects"] as Array):
			assert_bool(EffectTemplates.is_known_template(String((effect as Dictionary)["template"]))).is_true()
	assert_int(int(by_slot.get("utility", 0))).is_equal(2)
	assert_int(int(by_slot.get("movement", 0))).is_equal(2)
	assert_int(CardDatabase.cards_for_pool("wizard").size()).is_equal(4)


func test_character_validation_rejects_bad_entries() -> void:
	var good: Dictionary = CharacterDatabase.get_entry("wizard").duplicate(true)
	var cases: Array[Dictionary] = [
		{"key": "max_hp", "value": 0},
		{"key": "body_color", "value": "nope"},
		{"key": "pools", "value": ["wizard", "rogue", "fire", "neutral"]},  # two class pools
		{"key": "pools", "value": ["wizard", "ghost", "neutral"]},
		{"key": "class_pool", "value": "fire"},  # not a class pool
		{"key": "attacks", "value": {"light": "wizard", "heavy": "nobody"}},
		{"key": "attacks", "value": {"light": "missing", "heavy": "wizard"}},
		{"key": "starting_deck", "value": ["fire_fireball"]},  # short: breaks the deck rules
		{"key": "starting_deck", "value": ["not_a_card"]},
		{"key": "display_name", "value": ""},
	]
	for c: Dictionary in cases:
		var entry: Dictionary = good.duplicate(true)
		entry[c["key"]] = c["value"]
		assert_array(CharacterDatabase.validate_entry("wizard", entry)).override_failure_message("expected a problem for %s" % str(c)).is_not_empty()
	# A Rogue card in the Wizard's starter is refused by name.
	var mixed: Dictionary = good.duplicate(true)
	(mixed["starting_deck"] as Array)[0] = "rogue_quick_slash"
	var problems: Array[String] = CharacterDatabase.validate_entry("wizard", mixed)
	assert_bool("; ".join(problems).contains("rogue_quick_slash")).is_true()
	assert_array(CharacterDatabase.validate_table({})).is_not_empty()
	assert_array(CharacterDatabase.validate_table({"wizard": good})).is_not_empty()  # no default character


# ---- the class in run state ----

func test_run_state_remembers_the_class_and_round_trips() -> void:
	var state: RunState = RunSession.begin_new_run(5, "wizard")
	assert_str(state.character_id).is_equal("wizard")
	assert_array(state.deck).is_equal(CharacterDatabase.starting_deck("wizard"))
	var back: RunState = RunState.from_json(state.to_json())
	assert_str(back.character_id).is_equal("wizard")
	assert_bool(back.equals(state)).is_true()
	# An old save with no class is a Rogue run; an unknown class falls back loudly (the error is expected).
	var legacy: Dictionary = state.to_dict()
	legacy.erase("character")
	assert_str(RunState.from_dict(legacy).character_id).is_equal("rogue")


func test_new_runs_default_to_the_rogue_and_follow_the_selection() -> void:
	assert_str(RunSession.begin_new_run(1).character_id).is_equal("rogue")
	RunSession.selected_character = "wizard"
	assert_str(RunSession.begin_new_run(1).character_id).is_equal("wizard")
	RunSession.full_deck = true
	assert_array(RunSession.begin_new_run(1).deck).is_equal(CharacterDatabase.full_deck("wizard"))


func test_last_pick_is_remembered_in_memory_and_in_a_file_only_when_persisting() -> void:
	assert_str(CharacterPick.last_pick()).is_equal("rogue")
	assert_bool(CharacterPick.remember("wizard")).is_true()
	assert_str(CharacterPick.last_pick()).is_equal("wizard")
	assert_str(RunSession.chosen_character()).is_equal("wizard")  # preselected
	assert_str(CharacterPick.preselected()).is_equal("wizard")
	assert_bool(CharacterPick.remember("ghost")).is_false()  # push_error expected
	# Persistence: a temp file, never the player's.
	var temp: String = "user://test_last_class_w1a.json"
	CharacterPick.reset()
	CharacterPick.path = temp
	CharacterPick.persist_override = true
	CharacterPick.remember("wizard")
	assert_bool(FileAccess.file_exists(temp)).is_true()
	CharacterPick.reset()
	CharacterPick.path = temp
	CharacterPick.persist_override = true
	assert_str(CharacterPick.last_pick()).is_equal("wizard")
	DirAccess.remove_absolute(temp)
	CharacterPick.reset()
	CharacterPick.path = temp
	CharacterPick.persist_override = true
	assert_str(CharacterPick.last_pick()).is_equal("rogue")  # no file: the default
	CharacterPick.persist_override = false
	assert_bool(FileAccess.file_exists(temp)).is_false()


func test_a_run_main_launch_plays_the_selected_class() -> void:
	RunSession.selected_character = "wizard"
	var main: Main = _spawn_run()
	await get_tree().process_frame
	var player: Player = main.player
	assert_str(player.character_id).is_equal("wizard")
	assert_str(main.run_controller.character_id()).is_equal("wizard")
	assert_array(player.owned_pools).is_equal(["wizard", "fire", "neutral"])
	assert_float(player.health.max_health).is_equal(26.0)
	assert_float(RunSession.current.max_hp).is_equal(26.0)
	assert_array(player.card_slots.owned_card_ids()).contains_exactly_in_any_order(CharacterDatabase.starting_deck("wizard"))
	assert_str(String(player.attacks.get_def(&"light")["shape"])).is_equal("projectile")


func test_the_arena_and_a_plain_run_stay_the_rogue() -> void:
	var arena: Main = _spawn_arena()
	await get_tree().process_frame
	assert_str(arena.player.character_id).is_equal("rogue")
	assert_array(arena.player.owned_pools).is_equal(["rogue", "fire", "neutral"])
	assert_float(arena.player.health.max_health).is_equal(30.0)
	assert_str(String(arena.player.attacks.get_def(&"light")["shape"])).is_equal("arc")
	assert_str(String(arena.player.attacks.get_def(&"heavy")["shape"])).is_equal("arc")
	var run: Main = _spawn_run()
	await get_tree().process_frame
	assert_str(run.player.character_id).is_equal("rogue")
	assert_array(run.player.card_slots.owned_card_ids()).contains_exactly_in_any_order(OLD_ROGUE_STARTER)


func test_try_again_keeps_the_class() -> void:
	var state: RunState = RunSession.begin_new_run(9, "wizard")
	var main: Main = _spawn_run()
	await get_tree().process_frame
	assert_str(main.run_controller.character_id()).is_equal("wizard")
	main.restart_arena()
	assert_str(RunSession.current.character_id).is_equal("wizard")
	assert_int(RunSession.current.seed_value).is_not_equal(state.seed_value)


func test_confirm_class_pick_restarts_the_unplayed_run_as_the_new_class_with_the_same_seed() -> void:
	RunSession.begin_new_run(77)
	var main: Main = _spawn_run()
	await get_tree().process_frame
	var controller: RunController = main.run_controller
	var picked: Array[String] = []
	controller.class_picked.connect(func(id: String) -> void: picked.append(id))
	assert_bool(controller.confirm_class_pick("ghost")).is_false()  # push_error expected
	assert_bool(controller.confirm_class_pick("rogue")).is_true()  # same class: nothing restarts
	assert_str(CharacterPick.last_pick()).is_equal("rogue")
	assert_bool(controller.confirm_class_pick("wizard")).is_true()
	assert_array(picked).is_equal(["rogue", "wizard"])
	assert_str(RunSession.current.character_id).is_equal("wizard")
	assert_int(RunSession.current.seed_value).is_equal(77)
	assert_str(CharacterPick.last_pick()).is_equal("wizard")
	assert_str(RunSession.chosen_character()).is_equal("wizard")
	assert_array(RunSession.current.deck).is_equal(CharacterDatabase.starting_deck("wizard"))


func test_a_run_in_progress_keeps_its_class() -> void:
	RunSession.begin_new_run(3)
	var main: Main = _spawn_run()
	await get_tree().process_frame
	RunSession.current.record_room({"index": 0, "type": "combat", "wave_id": "x"}, 20.0, 5.0)
	assert_bool(main.run_controller.confirm_class_pick("wizard")).is_false()  # push_error expected
	assert_str(RunSession.current.character_id).is_equal("rogue")


# ---- launch arguments ----

func _resolve(args: Array) -> Dictionary:
	return DebugDecks.resolve_launch(PackedStringArray(args), DebugDecks.read_dir())


func test_class_arg_sets_the_character_and_combines_with_the_other_args() -> void:
	for args: Array in [["--class=wizard"], ["--class=wizard", "--run-room=8", "--run-seed=3", "--full-deck"], ["--full-deck", "--class=wizard"]]:
		var result: Dictionary = _resolve(args)
		assert_int(int(result["exit"])).is_equal(DebugDecks.EXIT_CONTINUE)
		assert_str(String(result["character"])).is_equal("wizard")
	assert_str(String(_resolve(["--class=rogue"])["character"])).is_equal("rogue")
	assert_str(String(_resolve([])["character"])).is_equal("")
	assert_str(String(_resolve(["--run-seed=1"])["character"])).is_equal("")


func test_bad_class_args_are_refused_with_a_message() -> void:
	for args: Array in [["--class"], ["--class="], ["--class=bard"], ["--class=wizard", "--class=rogue"]]:
		var result: Dictionary = _resolve(args)
		assert_int(int(result["exit"])).override_failure_message(str(args)).is_equal(DebugDecks.EXIT_REFUSED)
		assert_array(result["errors"] as Array).is_not_empty()
	assert_bool("; ".join(_resolve(["--class=bard"])["errors"] as Array).contains("valid classes: rogue, wizard")).is_true()


func test_deck_presets_name_their_class_and_a_mismatch_is_refused() -> void:
	# A Rogue preset starts a Rogue run on its own, accepts --class=rogue and refuses --class=wizard.
	var alone: Dictionary = _resolve(["--deck=fire-heavy-rogue"])
	assert_int(int(alone["exit"])).is_equal(DebugDecks.EXIT_CONTINUE)
	assert_str(String(alone["character"])).is_equal("rogue")
	assert_str(String(_resolve(["--deck=fire-heavy-rogue", "--class=rogue"])["character"])).is_equal("rogue")
	var clash: Dictionary = _resolve(["--deck=fire-heavy-rogue", "--class=wizard"])
	assert_int(int(clash["exit"])).is_equal(DebugDecks.EXIT_REFUSED)
	assert_bool("; ".join(clash["errors"] as Array).contains("must agree")).is_true()


func test_a_preset_for_the_wizard_is_checked_against_its_pools() -> void:
	var slot_of: Dictionary = DeckRules.slot_map_from_database()
	var pool_of: Dictionary = {}
	for card: Variant in CardDatabase.all_cards():
		pool_of[(card as Dictionary)["id"]] = (card as Dictionary)["pool"]
	var starter: Array = CharacterDatabase.starting_deck("wizard")
	var full: Array = CharacterDatabase.full_deck("wizard")
	var preset: Dictionary = {"name": "t", "description": "d", "class": "wizard", "starter": starter, "full": full}
	var names: Dictionary = DeckRules.slot_names_from_database()
	assert_array(DebugDecks.validate_preset("t", preset, slot_of, DeckRules.shipped_config(), SlotTypeDatabase.known_ids(), names, pool_of)).is_empty()
	# The same lists claimed for the Rogue (no "class") break the pool rule; an unknown class is refused.
	var as_rogue: Dictionary = preset.duplicate(true)
	as_rogue.erase("class")
	assert_array(DebugDecks.validate_preset("t", as_rogue, slot_of, DeckRules.shipped_config(), SlotTypeDatabase.known_ids(), names, pool_of)).is_not_empty()
	var unknown: Dictionary = preset.duplicate(true)
	unknown["class"] = "bard"
	assert_array(DebugDecks.validate_preset("t", unknown, slot_of, DeckRules.shipped_config(), SlotTypeDatabase.known_ids(), names, pool_of)).is_not_empty()


func test_the_shipped_rogue_presets_still_pass_with_the_class_rule() -> void:
	var directory: Dictionary = DebugDecks.read_dir()
	assert_array(directory["names"] as Array).is_not_empty()
	assert_int((directory["presets"] as Dictionary).size()).is_equal((directory["names"] as Array).size())


func test_a_preset_for_another_class_is_not_used_for_this_classs_run() -> void:
	var directory: Dictionary = DebugDecks.read_dir()
	RunSession.debug_deck = (directory["presets"] as Dictionary)["fire-heavy-rogue"]
	var wizard_run: RunState = RunSession.begin_new_run(1, "wizard")
	assert_array(wizard_run.deck).is_equal(CharacterDatabase.starting_deck("wizard"))
	var rogue_run: RunState = RunSession.begin_new_run(1, "rogue")
	assert_array(rogue_run.deck).is_equal(DebugDecks.deck_of(RunSession.debug_deck, false))


# ---- rewards: only the chosen class's pools, both ways ----

func test_offers_for_a_wizard_never_hold_a_rogue_card_and_vice_versa() -> void:
	var cards: Array = CardDatabase.all_cards()
	var defs: Dictionary = {"fire": PoolDatabase.get_definition("fire")}
	for character: String in ["wizard", "rogue"]:
		var forbidden: String = "rogue" if character == "wizard" else "wizard"
		var seen_class_card: bool = false
		for seed_value in range(1, 61):
			var deck: Array[String] = CharacterDatabase.starting_deck(character)
			var offer: Array[String] = RewardOffer.generate(seed_value, seed_value % 6, deck, cards, CharacterDatabase.pools(character), defs, RunConfig.rewards())
			assert_int(offer.size()).is_equal(RunConfig.offer_size())
			for card_id: String in offer:
				var pool: String = String(CardDatabase.get_card(card_id)["pool"])
				assert_str(pool).override_failure_message("%s was offered a %s card %s" % [character, pool, card_id]).is_not_equal(forbidden)
				if pool == character:
					seen_class_card = true
		assert_bool(seen_class_card).override_failure_message("%s never saw one of its own class cards" % character).is_true()


func test_a_wizard_run_in_the_scene_offers_only_wizard_fire_and_neutral_cards() -> void:
	RunSession.selected_character = "wizard"
	RunSession.begin_new_run(21)
	var main: Main = _spawn_run()
	await get_tree().process_frame
	var table: Dictionary = WaveConfig.get_config().duplicate(true)
	table["stages"] = [{"delay": 0.0, "spawns": [{"enemy": "melee_chaser", "count": 1}]}]
	table["first_wave_delay"] = 0.0
	table["finite"] = true
	table["loop_from_stage"] = 0
	main.enemy_spawner.configure_room(table, 1)
	main.enemy_spawner._process(1.0)
	for child in main.get_children():
		if child is Enemy:
			(child as Enemy).health.take_damage(100000.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var offer: Array[String] = RunSession.current.offer
	assert_int(offer.size()).is_equal(RunConfig.offer_size())
	for card_id: String in offer:
		assert_array(["wizard", "fire", "neutral"]).contains([String(CardDatabase.get_card(card_id)["pool"])])


# ---- the Wizard body, HP and attacks ----

func test_wizard_body_is_a_different_colour_with_26_hp_and_the_rogue_unchanged() -> void:
	var wizard_main: Main = _spawn_arena("wizard")
	var rogue_main: Main = _spawn_arena()
	await get_tree().process_frame
	var wizard: Player = wizard_main.player
	var rogue: Player = rogue_main.player
	assert_float(wizard.health.max_health).is_equal(26.0)
	assert_float(wizard.health.current_health).is_equal(26.0)
	assert_float(rogue.health.max_health).is_equal(30.0)
	var wizard_color: Color = (wizard.body_mesh.material_override as StandardMaterial3D).albedo_color
	var rogue_color: Color = (rogue.body_mesh.material_override as StandardMaterial3D).albedo_color
	assert_bool(wizard_color.is_equal_approx(rogue_color)).is_false()
	assert_bool(wizard_color.is_equal_approx(CharacterDatabase.body_color("wizard"))).is_true()
	assert_float(absf(rogue_color.r - 0.2) + absf(rogue_color.g - 0.55) + absf(rogue_color.b - 0.9)).is_less(0.01)  # the scene's blue, to within a hex digit


func test_wizard_light_is_80_percent_of_the_rogues_and_neutral_with_12_m_range() -> void:
	var rogue: Dictionary = AttackDatabase.get_light("default")
	var wizard: Dictionary = AttackDatabase.get_light("wizard")
	assert_str(String(wizard["shape"])).is_equal("projectile")
	assert_bool(bool(wizard["auto"])).is_true()
	assert_str(String(wizard["damage_type"])).is_equal("neutral")
	assert_float(float(wizard["range"])).is_equal(12.0)
	var rogue_dps: float = float(rogue["damage"]) / float(rogue["interval"])
	var wizard_dps: float = float(wizard["damage"]) / float(wizard["interval"])
	assert_float(wizard_dps / rogue_dps).is_equal_approx(0.8, 0.001)
	var clicked_ratio: float = (float(wizard["damage"]) / (float(wizard["interval"]) / float(wizard["manual_click_max_rate_ratio"]))) / (float(rogue["damage"]) / (float(rogue["interval"]) / float(rogue["manual_click_max_rate_ratio"])))
	assert_float(clicked_ratio).is_equal_approx(0.8, 0.001)
	# Rogue's light is untouched, and the plain getter still returns it.
	assert_float(float(rogue["damage"])).is_equal(3.0)
	assert_float(float(AttackDatabase.get_attack("light")["damage"])).is_equal(3.0)


func test_wizard_heavy_is_neutral_so_it_goes_through_armor() -> void:
	var heavy: Dictionary = AttackDatabase.get_heavy("wizard")
	assert_str(String(heavy["damage_type"])).is_equal("neutral")
	assert_bool(ArmorConfig.is_non_elemental("neutral")).is_true()
	assert_float(float(heavy["damage"])).is_equal(8.5)  # numbers unchanged: only the type moved
	assert_float(float(heavy["max_range"])).is_equal(7.0)


func test_a_wizard_player_uses_the_wizard_heavy_and_the_projectile_light() -> void:
	var main: Main = _spawn_arena("wizard")
	await get_tree().process_frame
	assert_str(String(main.player.attacks.get_def(&"heavy")["shape"])).is_equal("targeted_aoe")
	assert_str(main.player.character_class_id()).is_equal("wizard")
	assert_str(main.player.character_element_id()).is_equal("fire")
	# No wedge on the body for a bolt or a targeted disc.
	assert_bool(main.player.get_node_or_null("AttackVisual_light") == null).is_true()


func _aim_and_idle_enemy(main: Main, offset: Vector3) -> Enemy:
	var enemy: Enemy = (load(CHASER_PATH) as PackedScene).instantiate()
	enemy.position = main.player.global_position + offset
	main.add_child(enemy)
	enemy.target = null
	return enemy


func test_the_wizard_bolt_flies_to_the_reticle_not_where_the_body_faces() -> void:
	var main: Main = _spawn_arena("wizard")
	await _frames(2)
	main.player.camera = null
	main.player.rotation = Vector3.ZERO  # faces -Z
	var enemy: Enemy = _aim_and_idle_enemy(main, Vector3(8.0, 0.0, 0.0))  # to the side: the facing line misses it
	await _frames(2)
	main.player.aim_point_override = enemy.global_position
	var start_hp: float = enemy.health.current_health
	var saw_bolt: bool = false
	for i in range(90):
		await get_tree().physics_frame
		for child in main.get_children():
			if child is Projectile:
				saw_bolt = true
		if enemy.health.current_health < start_hp:
			break
	assert_bool(saw_bolt).override_failure_message("no bolt flew").is_true()
	assert_float(enemy.health.current_health).is_less(start_hp)
	# Neutral, 2.4 per bolt: hit armor-free (a plain chaser has none).
	assert_float(start_hp - enemy.health.current_health).is_equal_approx(2.4, 0.01)


func test_the_wizard_bolt_does_not_reach_past_its_12_m_range_and_autofire_needs_a_target_in_range() -> void:
	var main: Main = _spawn_arena("wizard")
	await _frames(2)
	main.player.camera = null
	main.player.rotation = Vector3.ZERO
	var far: Enemy = _aim_and_idle_enemy(main, Vector3(0.0, 0.0, -15.0))
	await _frames(2)
	main.player.aim_point_override = far.global_position
	assert_bool(main.player._attack_has_target(&"light")).is_false()  # outside range: auto-fire stays quiet
	var start_hp: float = far.health.current_health
	TestInput.tap(&"attack_light")  # a click still fires, but the bolt dies at 12 m
	await _frames(120)
	assert_float(far.health.current_health).is_equal(start_hp)
	# Move the enemy inside the range along the aim line: now the gate opens and the auto light fires by itself.
	far.global_position = main.player.global_position + Vector3(0.0, 0.0, -9.0)
	main.player.aim_point_override = far.global_position
	await _frames(1)
	assert_bool(main.player._attack_has_target(&"light")).is_true()
	await _frames(90)
	assert_float(far.health.current_health).is_less(start_hp)


func test_auto_fire_does_not_flood_the_effect_pool_or_recycle_the_heavy_telegraph() -> void:
	var main: Main = _spawn_arena("wizard")
	await _frames(2)
	main.player.camera = null
	main.player.rotation = Vector3.ZERO
	var enemy: Enemy = _aim_and_idle_enemy(main, Vector3(0.0, 0.0, -6.0))
	enemy.health.max_health = 100000.0
	enemy.health.current_health = 100000.0
	await _frames(2)
	main.player.aim_point_override = enemy.global_position
	TestInput.press(&"attack_heavy")
	await _frames(3)
	TestInput.release(&"attack_heavy")
	assert_bool(main.player.has_aoe_telegraph(&"heavy")).is_true()
	var parts: Array[PooledEffect] = main.player.get_aoe_telegraph(&"heavy")
	var pool: EffectPool = EffectPool.for_world(main)
	var generations: Array[int] = []
	for part: PooledEffect in parts:
		generations.append(part.generation)
	# Light bolts fire (auto, and clicked at the click-rate cap) while the heavy winds up; the telegraph parts must outlive them.
	for i in range(20):
		TestInput.tap(&"attack_light")
		await get_tree().physics_frame
		if not main.player.attacks.is_winding_up(&"heavy"):
			break
		for j in range(parts.size()):
			assert_bool(pool.is_running(parts[j], generations[j])).override_failure_message("telegraph part %d recycled" % j).is_true()
