class_name Map4QaTest
extends GdUnitTestSuite
## MAP4 qa review (2026-11-13): independent checks on the SHIPPED events, curses and relics, and the gaps the triages handed to qa:
## every event step through RunSave.read_state, E1b (the event elite fight) end to end through the controller, a curse cast in the cast history,
## the multi-give-up step with every pick made, the safety floors and greying on shipped data, and RunSession's sticky debug values.

const RUN_MAIN_PATH := "res://scenes/main/RunMain.tscn"
const SAVE_PATH := "user://tests/map4_qa_save.json"


func before_test() -> void:
	RunSession.clear()
	RunSession.forced_event = ""
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	RelicDatabase.load_all()
	CardDatabase.load_all()
	EventDatabase.load_all()
	DirAccess.make_dir_recursive_absolute("user://tests")


func after_test() -> void:
	RunSession.clear()
	RunSession.forced_event = ""
	RunSession.start_curses = []
	RunSession.start_discount = 0.0
	RunSave.delete_save()
	RunSave.reset()
	RunConfig.reset_cache()
	MapConfig.reset_cache()
	ClassPickScreen.reset()
	Juice.reset()
	GamePause.reset()
	get_tree().paused = false


# --- helpers ---------------------------------------------------------------------------------------

func _ctx() -> Dictionary:
	return RunChoices.shipped_context(CharacterDatabase.pools("rogue"))


## A Rogue standing on the first event node of a map drawn with the event weight on (the same construction map4b2_test uses).
func _on_event(first_seed: int = 1, act: int = 1) -> RunState:
	var cfg: Dictionary = MapConfig.get_config().duplicate(true)
	(cfg["types"]["event"] as Dictionary)["weight"] = 12
	for seed_value in range(first_seed, first_seed + 200):
		var map: Dictionary = MapGenerator.generate(seed_value, cfg)
		for entry: Dictionary in (map["nodes"] as Array):
			if String(entry["type"]) != "event":
				continue
			var trail: Array[int] = [int(entry["id"])]
			while int(MapGraph.node(map, trail[0])["room"]) > 1:
				trail.push_front(MapGraph.prev_ids(map, trail[0])[0])
			var state := RunState.new_run(seed_value, CharacterDatabase.full_deck("rogue"), 3, "rogue")
			state.map = map
			state.path = trail
			state.room_index = trail.size() - 1
			state.gold = 100
			state.hp = 30.0
			state.max_hp = 30.0
			state.act = act
			state.acts_total = 3
			for earlier in range(act - 1):
				state.past_acts.append({"map": map.duplicate(true), "path": trail.duplicate()})
			return state
	return null


func _open(event_id: String, state: RunState) -> void:
	state.event_id = event_id
	state.pending = RunState.PENDING_EVENT


## Shipped non-boss relic ids of a tier with no sacrifice cost.
func _plain_relics(tier: String, count: int) -> Array[String]:
	var found: Array[String] = []
	for relic: Dictionary in RelicDatabase.all_relics():
		if String(relic.get("rarity", "")) == tier and not relic.has("sacrifice_cost") and (relic.get("sources", []) as Array).has("elite"):
			found.append(String(relic["id"]))
			if found.size() == count:
				break
	return found


func _option(options: Array, option_id: String) -> Dictionary:
	for option: Variant in options:
		if String((option as Dictionary)["id"]) == option_id:
			return option as Dictionary
	return {}


func _first_enabled(state: RunState, ctx: Dictionary) -> String:
	for option: Dictionary in RunChoices.options(state, ctx):
		if bool(option.get("enabled", false)) and String(option["id"]) != "relic_skip" and not String(option["id"]).ends_with("cancel"):
			return String(option["id"])
	return ""


## Writes `state` to the slot and reads it back through the real validator.
func _roundtrip(state: RunState) -> RunState:
	RunSave.reset()
	RunSave.path = SAVE_PATH
	RunSave.persist_override = true
	assert_bool(RunSave.write(state)).is_true()
	var back: RunState = RunSave.read_state()
	assert_str(RunSave.last_problem).is_empty()
	return back


## Saves at this step, reads the save back, checks it equals the live state, then takes the same next option on both and checks they stay equal.
func _assert_resumes_the_same(state: RunState, ctx: Dictionary, step: String) -> void:
	var back: RunState = _roundtrip(state)
	assert_object(back).override_failure_message("%s: the save was refused: %s" % [step, RunSave.last_problem]).is_not_null()
	if back == null:
		return
	assert_bool(back.equals(state)).override_failure_message("%s: the resumed state differs from the live one" % step).is_true()
	var live_options: Array[Dictionary] = RunChoices.options(state, ctx)
	var resumed_options: Array[Dictionary] = RunChoices.options(back, ctx)
	assert_int(resumed_options.size()).override_failure_message("%s: option count differs after resume" % step).is_equal(live_options.size())
	for i in range(live_options.size()):
		assert_str(String(resumed_options[i]["id"])).is_equal(String(live_options[i]["id"]))
		assert_bool(bool(resumed_options[i]["enabled"])).is_equal(bool(live_options[i]["enabled"]))
	var next: String = _first_enabled(state, ctx)
	assert_str(next).override_failure_message("%s: nothing to take" % step).is_not_empty()
	var live_result: Dictionary = RunChoices.apply(state, next, ctx)
	var resumed_result: Dictionary = RunChoices.apply(back, next, ctx)
	assert_bool(bool(live_result["ok"])).is_equal(bool(resumed_result["ok"]))
	assert_bool(back.equals(state)).override_failure_message("%s: after taking '%s' the resumed run diverged" % [step, next]).is_true()


# --- save and Continue at every event step, through RunSave.read_state ---------------------------------

func test_the_event_choice_screen_resumes_the_same() -> void:
	var state: RunState = _on_event(1)
	_open("exit_interview", state)
	_assert_resumes_the_same(state, _ctx(), "choice screen")


func test_a_pending_event_relic_offer_resumes_the_same() -> void:
	var state: RunState = _on_event(2)
	var ctx: Dictionary = _ctx()
	_open("exit_interview", state)
	var result: Dictionary = RunChoices.apply(state, "event_choice:0", ctx)
	assert_bool(bool(result["ok"])).is_true()
	assert_bool(EventEngine.is_event_offer(state)).is_true()
	assert_int(state.offer.size()).is_equal(3)
	_assert_resumes_the_same(state, ctx, "pending relic offer")


func test_a_pending_event_removal_resumes_the_same() -> void:
	var state: RunState = _on_event(3)
	var ctx: Dictionary = _ctx()
	_open("sympathetic_coworker", state)
	RunChoices.apply(state, "event_choice:1", ctx)
	assert_str(state.pending).is_equal(RunState.PENDING_EVENT_REMOVE)
	_assert_resumes_the_same(state, ctx, "pending removal")


func test_a_pending_event_sacrifice_resumes_the_same_through_read_state() -> void:
	var state: RunState = _on_event(4)
	var ctx: Dictionary = _ctx()
	for id: String in _plain_relics("tier1", 2) + _plain_relics("tier2", 1):
		state.relics.append(id)
	_open("performance_altar", state)
	var result: Dictionary = RunChoices.apply(state, "event_choice:0", ctx)
	assert_bool(bool(result["ok"])).is_true()
	assert_str(state.pending).is_equal(RunState.PENDING_EVENT_SACRIFICE)
	assert_bool(state.event_queue.is_empty()).is_false()
	var back: RunState = _roundtrip(state)
	assert_object(back).override_failure_message("a pending event sacrifice was refused by read_state: " + RunSave.last_problem).is_not_null()
	assert_str(back.pending).is_equal(RunState.PENDING_EVENT_SACRIFICE)
	assert_bool(back.equals(state)).is_true()
	# the sacrifice then completes on the resumed run exactly as on the live one, and the follow-up offer is tier + 1
	var pick: String = _first_enabled(back, ctx)
	assert_bool(pick.begins_with(EventEngine.OPTION_SACRIFICE)).override_failure_message("first option was '%s'" % pick).is_true()
	var live_done: Dictionary = RunChoices.apply(state, pick, ctx)
	var back_done: Dictionary = RunChoices.apply(back, pick, ctx)
	assert_bool(bool(live_done["ok"]) and bool(back_done["ok"])).is_true()
	assert_bool(back.equals(state)).is_true()
	assert_bool(EventEngine.is_event_offer(back)).is_true()
	assert_bool(back.relics_given_up.size() == 1).is_true()


func test_a_pending_sacrifice_followed_by_a_removal_resumes_the_same() -> void:
	var state: RunState = _on_event(5)
	var ctx: Dictionary = _ctx()
	state.relics.append(_plain_relics("tier1", 1)[0])
	_open("performance_altar", state)
	RunChoices.apply(state, "event_choice:1", ctx)  # Restructuring Plan: give up a tier 1 relic, then remove a card
	assert_str(state.pending).is_equal(RunState.PENDING_EVENT_SACRIFICE)
	var pick: String = _first_enabled(state, ctx)
	RunChoices.apply(state, pick, ctx)
	assert_str(state.pending).is_equal(RunState.PENDING_EVENT_REMOVE)
	_assert_resumes_the_same(state, ctx, "removal after a sacrifice")


func test_a_hand_edited_pending_sacrifice_with_a_broken_queue_is_refused_or_repaired_not_crashed_on() -> void:
	var state: RunState = _on_event(4)
	var ctx: Dictionary = _ctx()
	state.relics.append(_plain_relics("tier1", 1)[0])
	_open("performance_altar", state)
	RunChoices.apply(state, "event_choice:0", ctx)
	var data: Dictionary = state.to_dict()
	for bad: Variant in ["nope", 7, [1, 2], [{"type": 5}]]:
		var patched: Dictionary = data.duplicate(true)
		patched["event_queue"] = bad
		RunSave.reset()
		RunSave.path = SAVE_PATH
		RunSave.persist_override = true
		var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		file.store_string(JSON.stringify({"save_version": RunSave.SAVE_VERSION, "run": patched}))
		file.close()
		var back: RunState = RunSave.read_state()  # must return (a state or null) without a script error
		if back != null:
			assert_bool(back.event_queue.all(func(entry: Variant) -> bool: return typeof(entry) == TYPE_DICTIONARY)).is_true()


# --- E1b, the event elite fight, end to end through the real controller -----------------------------

func _spawn() -> Main:
	var main: Main = (load(RUN_MAIN_PATH) as PackedScene).instantiate()
	add_child(main)
	auto_free(main)
	return main


func _frames(count: int = 3) -> void:
	for i in range(count):
		await get_tree().process_frame


func _latest_main(except_id: int) -> Main:
	var found: Main = null
	for child in get_children():
		if child is Main and child.get_instance_id() != except_id and not child.is_queued_for_deletion():
			found = child as Main
	return found


func _win_room(main: Main) -> void:
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
	await _frames(2)


func test_e1b_the_shipped_elite_fight_pays_its_rewards_only_after_the_win() -> void:
	RunSave.reset()
	RunSave.path = SAVE_PATH
	RunSave.persist_override = true
	RunSave.delete_save()
	var state: RunState = _on_event(1, 1)
	RunSession.current = state
	RunSession.forced_event = "exit_interview"
	var main := _spawn()
	await _frames()
	var main_id: int = main.get_instance_id()
	assert_str(state.event_id).is_equal("exit_interview")
	var gold_before: int = state.gold
	var hp_before: float = state.hp
	var relics_before: int = state.relics.size()
	var result: Dictionary = main.run_controller.choose("event_choice:1")  # Demand a rematch
	assert_bool(bool(result["ok"])).is_true()
	assert_bool(main.run_controller.event_fight_active()).is_true()
	assert_int(state.gold).is_equal(gold_before)  # nothing is paid before the win
	assert_bool(state.event_queue.is_empty()).is_false()
	assert_str(String(state.event_fight["wave_id"])).is_not_empty()
	var elite_ids: Array[String] = []
	for entry: Variant in ((RunConfig.get_config()["rooms"] as Dictionary).get("elite", []) as Array):
		elite_ids.append(String((entry as Dictionary)["id"]))
	assert_bool(elite_ids.has(String(state.event_fight["wave_id"]))).override_failure_message("the event fight wave %s is not an elite wave: %s" % [str(state.event_fight["wave_id"]), str(elite_ids)]).is_true()
	assert_bool(RunSave.read_state().equals(state)).override_failure_message("the save at the fight start differs from the live state").is_true()
	var saved: RunState = RunSave.read_state()
	assert_object(saved).override_failure_message("no usable save at the fight's start: " + RunSave.last_problem).is_not_null()
	await _frames()
	var fight: Main = _latest_main(main_id)
	assert_object(fight).is_not_null()
	assert_bool(fight.run_controller.is_cleared()).is_false()
	await _win_room(fight)
	assert_bool(fight.run_controller.is_cleared()).is_true()
	assert_int(state.gold).override_failure_message("the gold comes after the relic pick (outcome order), and no elite-room gold is paid").is_equal(gold_before)
	assert_str(state.pending).is_equal(RunState.PENDING_RELIC)
	assert_str(state.offer_rarity).is_equal(RunState.OFFER_EVENT)  # the next-act row, with a skip
	assert_int(state.offer.size()).is_equal(3)
	assert_float(state.hp).is_equal(hp_before)  # b costs no HP
	var picked: Dictionary = fight.run_controller.pick_relic(state.offer[0])
	assert_bool(bool(picked["ok"]) and bool(picked["finished"])).is_true()
	assert_int(state.relics.size()).is_equal(relics_before + 1)
	assert_int(state.gold).override_failure_message("the event pays exactly 40 gold once the offer is answered").is_equal(gold_before + 40)
	assert_str(state.pending).is_equal(RunState.PENDING_NODE)
	assert_bool(state.event_queue.is_empty() and state.event_fight.is_empty()).is_true()


# --- safety floors and greying on the shipped events -------------------------------------------------

func test_lose_hp_never_kills_and_lose_max_hp_keeps_its_floor_on_shipped_events() -> void:
	var ctx: Dictionary = _ctx()
	var low: RunState = _on_event(1)
	low.hp = 3.0
	_open("exit_interview", low)
	RunChoices.apply(low, "event_choice:0", ctx)  # lose 20% HP
	assert_float(low.hp).is_greater_equal(1.0)
	var tiny: RunState = _on_event(1)
	tiny.max_hp = 11.0
	tiny.hp = 11.0
	_open("complacency_trap", tiny)
	var before_max: float = tiny.max_hp
	RunChoices.apply(tiny, "event_choice:0", ctx)  # lose 10% max HP, Recovery -20%
	assert_float(tiny.max_hp).is_greater_equal(10.0)
	assert_float(tiny.max_hp).is_less_equal(before_max)
	assert_float(tiny.hp).is_less_equal(tiny.max_hp)
	var floor_state: RunState = _on_event(1)
	floor_state.max_hp = 10.0
	floor_state.hp = 10.0
	_open("complacency_trap", floor_state)
	RunChoices.apply(floor_state, "event_choice:0", ctx)
	assert_float(floor_state.max_hp).is_equal(10.0)


func test_lose_gold_clamps_at_zero_and_a_gold_requirement_greys_with_its_reason() -> void:
	var ctx: Dictionary = _ctx()
	var poor: RunState = _on_event(1)
	poor.gold = 30
	_open("loyalty_pledge", poor)
	RunChoices.apply(poor, "event_choice:0", ctx)  # pay 50 (or all you have)
	assert_int(poor.gold).is_equal(0)
	var thin: RunState = _on_event(1)
	thin.gold = 39
	_open("broken_vending_machine", thin)
	var vending: Dictionary = _option(RunChoices.options(thin, ctx), "event_choice:0")
	assert_bool(bool(vending["enabled"])).is_false()
	assert_str(String(vending["reason"])).is_not_empty()
	assert_bool(bool(RunChoices.apply(thin, "event_choice:0", ctx)["ok"])).is_false()
	assert_int(thin.gold).is_equal(39)
	thin.gold = 40
	assert_bool(bool(_option(RunChoices.options(thin, ctx), "event_choice:0")["enabled"])).is_true()


func test_relic_and_curse_requirements_grey_with_a_reason_and_the_free_choice_stays_open() -> void:
	var ctx: Dictionary = _ctx()
	var bare: RunState = _on_event(1)
	_open("performance_altar", bare)
	for id: String in ["event_choice:0", "event_choice:1"]:
		var option: Dictionary = _option(RunChoices.options(bare, ctx), id)
		assert_bool(bool(option["enabled"])).override_failure_message("%s was not greyed with no relics" % id).is_false()
		assert_str(String(option["reason"])).is_not_empty()
	assert_bool(bool(_option(RunChoices.options(bare, ctx), "event_choice:2")["enabled"])).is_true()  # leave
	bare.relics.append(_plain_relics("tier2", 1)[0])
	assert_bool(bool(_option(RunChoices.options(bare, ctx), "event_choice:0")["enabled"])).is_true()
	assert_bool(bool(_option(RunChoices.options(bare, ctx), "event_choice:1")["enabled"])).override_failure_message("Restructuring needs a TIER 1 relic").is_false()
	var clean: RunState = _on_event(1)
	_open("sympathetic_coworker", clean)
	assert_bool(bool(_option(RunChoices.options(clean, ctx), "event_choice:0")["enabled"])).is_false()  # needs a curse
	clean.deck.append("curse_property_damage")
	assert_bool(bool(_option(RunChoices.options(clean, ctx), "event_choice:0")["enabled"])).is_true()


func test_a_boss_relic_alone_does_not_open_the_altar() -> void:
	var boss: String = ""
	for relic: Dictionary in RelicDatabase.all_relics():
		if String(relic.get("rarity", "")) == "boss":
			boss = String(relic["id"])
			break
	assert_str(boss).is_not_empty()
	var state: RunState = _on_event(1)
	state.relics.append(boss)
	_open("performance_altar", state)
	var ctx: Dictionary = _ctx()
	assert_bool(bool(_option(RunChoices.options(state, ctx), "event_choice:0")["enabled"])).override_failure_message("a boss relic can be sacrificed").is_false()
	_open("internal_audit", state)
	assert_bool(bool(_option(RunChoices.options(state, ctx), "event_choice:0")["enabled"])).is_false()


# --- the cleanse counter on every path -------------------------------------------------------------

func test_the_cleanse_counter_counts_event_removals_of_a_curse_but_not_of_an_ordinary_card() -> void:
	var ctx: Dictionary = _ctx()
	var state: RunState = _on_event(1)
	state.deck.append("curse_property_damage")
	state.deck.append("curse_reply_all_storm")
	_open("sympathetic_coworker", state)
	RunChoices.apply(state, "event_choice:0", ctx)  # remove_curse
	assert_str(state.pending).is_equal(RunState.PENDING_EVENT_REMOVE)
	RunChoices.apply(state, "event_remove:curse_property_damage", ctx)
	assert_int(state.cleanses).is_equal(1)
	_open("sympathetic_coworker", state)
	RunChoices.apply(state, "event_choice:1", ctx)  # remove_card, picking the other curse
	RunChoices.apply(state, "event_remove:curse_reply_all_storm", ctx)
	assert_int(state.cleanses).is_equal(2)
	var ordinary: String = ""
	for id: String in state.deck:
		if not RunChoices.is_curse_id(id, ctx) and RunChoices.removal_problems(state, id, ctx).is_empty():
			ordinary = id
			break
	_open("sympathetic_coworker", state)
	RunChoices.apply(state, "event_choice:1", ctx)
	RunChoices.apply(state, "event_remove:" + ordinary, ctx)
	assert_int(state.cleanses).override_failure_message("removing an ordinary card moved the cleanse counter").is_equal(2)


# --- a curse cast and the cast history ---------------------------------------------------------------

func test_a_curse_cast_does_not_enter_the_cast_history_or_fire_card_cast() -> void:
	# DF1-A (flipped from MAP4's "a curse is a real cast"): through the real controller, a curse spends its slot but is no card cast for the build.
	CombatEvents.reset()
	var seen: Array[String] = []
	var listener: Callable = func(slot_type: String, card_id: String, _tags: Array[String]) -> void: seen.append("%s/%s" % [slot_type, card_id])
	CombatEvents.card_cast.connect(listener)
	var caster: Node3D = auto_free(Node3D.new())
	add_child(caster)
	var controller := CardSlotController.new(caster, caster, "player", StatModifiers.new(), ["rogue_bad_influence"] as Array[String])
	controller.set_deck(["curse_mandatory_training", "curse_mandatory_training"] as Array[String])
	var own: Array[String] = []
	controller.card_cast.connect(func(_slot_type: String, card_id: String) -> void: own.append(card_id))
	assert_str(controller.get_slot("utility").current_card_id).is_equal("curse_mandatory_training")
	assert_bool(controller.try_use("utility")).is_true()
	assert_array(own).is_equal(["curse_mandatory_training"])  # the slot's own signal still fires (HUD)
	assert_array(seen).is_empty()
	assert_bool(CombatEvents.history.cast_within(CombatEvents.now(), 4.0, "utility")).override_failure_message("a curse satisfied Peer Review's condition").is_false()
	CombatEvents.card_cast.disconnect(listener)
	# the relay still records an ordinary cast
	CombatEvents.notify_card_cast("utility", "rogue_bad_influence")
	assert_bool(CombatEvents.history.cast_within(CombatEvents.now(), 4.0, "utility")).is_true()
	CombatEvents.reset()


func _curse_slots() -> Array[String]:
	var slots: Array[String] = []
	for card_entry: Variant in CardDatabase.all_cards():
		var card: Dictionary = card_entry as Dictionary
		if CardSchema.is_curse(card) and not slots.has(String(card["slot_type"])):
			slots.append(String(card["slot_type"]))
	return slots


func test_the_listeners_a_curse_cast_would_have_reached_are_exactly_the_known_list() -> void:
	## DF1-A: a curse cast fires no card_cast and enters no cast history (CardSlotController.try_use), so these three listings are what WOULD have fired.
	## The data-side scan stays as a tripwire: if the list of listeners changes, game-lead should look. The runtime check is the test above.
	var slots: Array[String] = _curse_slots()
	assert_array(slots).contains_exactly_in_any_order(["attack_single", "attack_aoe", "utility"])
	var payoffs: Array[String] = []
	for card_entry: Variant in CardDatabase.all_cards():
		var card: Dictionary = card_entry as Dictionary
		for effect: Variant in (card.get("effects", []) as Array):
			var condition: Variant = (effect as Dictionary).get("condition")
			if typeof(condition) == TYPE_DICTIONARY and String((condition as Dictionary).get("type", "")) == "cast_within" and slots.has(String((condition as Dictionary).get("slot_type", ""))):
				payoffs.append(String(card["id"]))
	assert_array(payoffs).is_equal(["wizard_peer_review"])
	var triggered: Array[String] = []
	for relic: Dictionary in RelicDatabase.all_relics():
		for trigger: Variant in (relic.get("triggers", []) as Array):
			if String((trigger as Dictionary).get("event", "")) != "card_cast":
				continue
			var filter: Dictionary = (trigger as Dictionary).get("filter", {}) as Dictionary
			var tag: String = String(filter.get("tag", ""))
			var slot: String = String(filter.get("slot_type", ""))
			var curse_has_tag: bool = false
			for curse_id: String in ["curse_property_damage", "curse_reply_all_storm", "curse_mandatory_training"]:
				if not tag.is_empty() and CardDatabase.has_tag(curse_id, tag):
					curse_has_tag = true
			if (tag.is_empty() and slot.is_empty()) or slots.has(slot) or curse_has_tag:
				triggered.append(String(relic["id"]))
	assert_array(triggered).contains_exactly_in_any_order(["faculty_meeting", "the_ivory_tower", "the_non_compete_clause"])


# --- RunSession's sticky debug values --------------------------------------------------------------

func test_documents_that_run_session_clear_keeps_start_curses_and_start_discount_sticky() -> void:
	# `clear()` only drops the live run (RunSession's doc: "sticky for the launch"). A "Try again" after a --run-curses launch keeps the curses.
	RunSession.start_curses = ["curse_property_damage"]
	RunSession.start_discount = 0.25
	RunSession.clear()
	assert_array(RunSession.start_curses).is_equal(["curse_property_damage"])
	assert_float(RunSession.start_discount).is_equal(0.25)
	var again: RunState = RunSession.begin_new_run(7, "rogue")
	assert_bool(again.deck.has("curse_property_damage")).is_true()
	assert_float(again.merchant_discount).is_equal_approx(0.25, 0.0001)
	RunSession.start_curses = []
	RunSession.start_discount = 0.0
	var clean: RunState = RunSession.begin_new_run(7, "rogue")
	assert_bool(clean.deck.has("curse_property_damage")).is_false()
	assert_float(clean.merchant_discount).is_equal(0.0)


# --- a forced-choice sweep: every choice of every shipped event, from several starting states --------------------------------
# The bots' "first available" policy never takes E1b, E2b, E3b, E6b, E7a/c, E4b or E8b (qa counted 144 sim runs), so this takes every one of them.

## Plays the open event to its end by always taking the first enabled step, saving and reading back at every pending step. Returns the steps used.
func _drive_to_the_end(state: RunState, ctx: Dictionary, label: String) -> int:
	var steps: int = 0
	while steps < 14:
		if not state.event_fight.is_empty():
			EventEngine.fight_won(state, ctx)
			steps += 1
			continue
		var open: bool = [RunState.PENDING_EVENT_SACRIFICE, RunState.PENDING_EVENT_REMOVE, RunState.PENDING_RELIC_SWAP].has(state.pending) or EventEngine.is_event_offer(state)
		if not open:
			break
		var back: RunState = _roundtrip(state)
		assert_object(back).override_failure_message("%s: step %d (%s) was refused on read: %s" % [label, steps, state.pending, RunSave.last_problem]).is_not_null()
		var next: String = _step_option(state, ctx)
		assert_str(next).override_failure_message("%s: step %d (%s) has no enabled option: soft lock" % [label, steps, state.pending]).is_not_empty()
		var result: Dictionary = RunChoices.apply(state, next, ctx)
		assert_bool(bool(result["ok"])).override_failure_message("%s: '%s' refused: %s" % [label, next, str(result.get("reason", ""))]).is_true()
		steps += 1
	assert_bool(steps < 14).override_failure_message("%s: the event did not end in 14 steps" % label).is_true()
	return steps


func _variant_state(kind: String, act: int) -> RunState:
	var state: RunState = _on_event(1 + act, act)
	match kind:
		"poor_low":
			state.gold = 0
			state.hp = 1.0
		"rich_cursed":
			state.gold = 900
			state.deck.append("curse_property_damage")
			state.deck.append("curse_property_damage")
			state.deck.append("curse_mandatory_training")
			for id: String in _plain_relics("tier1", 3) + _plain_relics("tier2", 2) + _plain_relics("tier3", 1):
				state.relics.append(id)
		"relic_rich":
			state.gold = 60
			for id: String in _plain_relics("tier1", 6) + _plain_relics("tier2", 6) + _plain_relics("tier3", 6):
				state.relics.append(id)
		"min_hp":
			state.gold = 45
			state.max_hp = 10.0
			state.hp = 10.0
			state.relics.append(_plain_relics("tier1", 1)[0])
	return state


func test_every_choice_of_every_shipped_event_finishes_from_every_variant_without_breaking_the_run() -> void:
	var ctx: Dictionary = _ctx()
	var cap: int = RelicConfig.max_owned()
	var played: int = 0
	for event_id: String in EventDatabase.ids():
		var event: Dictionary = EventDatabase.get_event(event_id)
		for act in [1, 3]:
			if not (event["acts"] as Array).any(func(a: Variant) -> bool: return int(a) == act):
				continue
			for kind: String in ["poor_low", "rich_cursed", "relic_rich", "min_hp"]:
				for index in range((event["choices"] as Array).size()):
					var state: RunState = _variant_state(kind, act)
					_open(event_id, state)
					var label: String = "%s act %d %s choice %d" % [event_id, act, kind, index]
					var option: Dictionary = _option(RunChoices.options(state, ctx), "event_choice:%d" % index)
					if not bool(option.get("enabled", false)):
						continue  # greyed with a reason: covered by the greying tests
					var cleanses_before: int = state.cleanses
					var result: Dictionary = RunChoices.apply(state, "event_choice:%d" % index, ctx)
					assert_bool(bool(result["ok"])).override_failure_message(label + ": refused: " + str(result.get("reason", ""))).is_true()
					_drive_to_the_end(state, ctx, label)
					played += 1
					assert_bool(is_nan(state.hp) or state.hp < 1.0 or state.hp > state.max_hp).override_failure_message("%s: hp %s of %s" % [label, str(state.hp), str(state.max_hp)]).is_false()
					assert_float(state.max_hp).override_failure_message(label + ": max HP under the floor").is_greater_equal(minf(10.0, 30.0))
					assert_int(state.gold).override_failure_message(label + ": negative gold").is_greater_equal(0)
					assert_int(state.relics.size()).override_failure_message(label + ": over the relic cap").is_less_equal(cap)
					assert_bool(state.event_queue.is_empty() and state.event_fight.is_empty() and state.sacrifice_picks.is_empty()).override_failure_message(label + ": something is left pending").is_true()
					assert_bool(DeckRules.check_shipped(state.deck).is_ok()).override_failure_message(label + ": the deck broke a minimum").is_true()
					assert_int(state.cleanses).is_greater_equal(cleanses_before)
	assert_int(played).override_failure_message("the sweep played too few cases (%d)" % played).is_greater(100)


## The next option a player would take: in the multi-give-up step, pick tiles until Confirm is enabled, then Confirm; otherwise the first enabled option.
func _step_option(state: RunState, ctx: Dictionary) -> String:
	if state.pending == RunState.PENDING_RELIC_SWAP:
		var options: Array[Dictionary] = RunChoices.options(state, ctx)
		var confirm: Dictionary = _option(options, "giveup_confirm")
		if not confirm.is_empty() and bool(confirm["enabled"]):
			return "giveup_confirm"
		for option: Dictionary in options:
			if String(option["id"]).begins_with("giveup:") and bool(option["enabled"]) and not bool(option.get("selected", false)):
				return String(option["id"])
	return _first_enabled(state, ctx)


# --- The Micromanager with the SHIPPED curse (map4c_test uses fixture curses) ------------------------------------------------

func test_the_micromanager_with_a_shipped_curse_never_bricks_the_slot() -> void:
	var caster: Node3D = auto_free(Node3D.new())
	var owned: Array[String] = ["neutral", "rogue"]
	var modifiers := StatModifiers.new()
	var controller := CardSlotController.new(caster, caster, "player", modifiers, owned, RandomNumberGenerator.new())
	var real: Array[String] = []
	for card: Variant in CardDatabase.cards_for_slot_type("attack_single"):
		if owned.has(String((card as Dictionary)["pool"])) and not CardSchema.is_curse(card as Dictionary) and real.size() < 2:
			real.append(String((card as Dictionary)["id"]))
	assert_int(real.size()).is_equal(2)
	controller.set_deck([real[0], real[1], "curse_property_damage", "curse_property_damage", "curse_property_damage"] as Array[String])
	assert_bool(RelicDatabase.get_relic("the_micromanager").is_empty()).is_false()
	modifiers.add_modifier(CardSlotController.SWAP_LOCKED_STAT, "the_micromanager", StatModifiers.ADDITIVE, 1.0)
	assert_bool(controller.swap_locked()).is_true()
	var slot: CardSlot = controller.get_slot("attack_single")
	var curse_casts: int = 0
	for step in range(40):
		slot.cooldown_remaining = 0.0
		var current: String = slot.current_card_id
		assert_str(current).is_not_empty()
		assert_bool(controller.try_swap("attack_single")).is_false()
		if current == "curse_property_damage":
			assert_bool(controller.try_use("attack_single")).override_failure_message("a shipped curse could not be cast while swaps are locked (step %d)" % step).is_true()
			assert_float(slot.cooldown_remaining).is_greater(0.0)
			curse_casts += 1
		else:
			assert_str(slot.use_card(0.0, modifiers)).is_equal(current)
	assert_int(curse_casts).is_greater(5)


# --- sacrifice relics are absent from every source while you can't pay (shipped relics) ------------------------------------------

func test_no_shipped_sacrifice_relic_is_offered_anywhere_while_you_cannot_pay() -> void:
	var costs: Dictionary = {}
	for relic: Dictionary in RelicDatabase.all_relics():
		if relic.has("sacrifice_cost"):
			costs[String(relic["id"])] = int(relic["sacrifice_cost"])
	assert_int(costs.size()).is_equal(4)
	var tier1: String = _plain_relics("tier1", 1)[0]
	var rich_holding: Array[String] = _plain_relics("tier1", 2) + _plain_relics("tier2", 1)
	var probes_with_offers: int = 0
	var sacrifice_seen: int = 0
	for character: String in ["rogue", "wizard"]:
		var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools(character))
		for run_seed in range(1, 121):
			for held_count in [0, 1, 3]:
				var state: RunState = RunState.new_run(run_seed, CharacterDatabase.full_deck(character), 3, character)
				state.act = 3
				state.hp = 30.0
				state.max_hp = 30.0
				if held_count == 3:
					for id: String in rich_holding:
						state.relics.append(id)
				elif held_count == 1:
					state.relics.append(tier1)
				var offers: Array[String] = []
				for room_type: String in ["elite", "relic_room", "mini_boss"]:
					var probe: RunState = RunState.from_json(state.to_json())
					RunRelics.open_for_room(probe, room_type, false, ctx)
					offers.append_array(probe.offer)
				if not offers.is_empty():
					probes_with_offers += 1
				var shop: Dictionary = Merchant.draw_stock(state, 5, 0, ctx, [] as Array[String], [] as Array[String])
				for id: Variant in (shop["relics"] as Array):
					offers.append(String(id))
				for tier in [1, 2, 3]:
					offers.append_array(EventEngine.offer_ids(state, ctx, {"type": "gain_relic", "tier": tier, "count": 3}))
				for id: String in offers:
					if costs.has(id) and held_count == 3:
						sacrifice_seen += 1
					if costs.has(id):
						assert_int(held_count).override_failure_message("%s (give up %d) was offered to a %s holding %d eligible relic(s), seed %d" % [id, int(costs[id]), character, held_count, run_seed]).is_greater_equal(int(costs[id]))
	assert_int(probes_with_offers).override_failure_message("the probes produced no offers: the absence check is vacuous").is_greater(300)
	assert_int(sacrifice_seen).override_failure_message("a holder of 3 eligible relics never saw a sacrifice relic in 720 probes: the control is broken").is_greater(0)


# --- a map that cannot be made at an act change (the generator's headroom shrank in MAP4) ----------------------------------------

func test_a_failed_act_map_leaves_the_run_untouched_and_advance_act_reports_false() -> void:
	# RunController then ends the run as a win with a loud error (RunController line ~678), so a seed past max_attempts is a premature win, not a stuck run.
	var cfg: Dictionary = MapConfig.get_config().duplicate(true)
	cfg["max_attempts"] = 1
	var failures: int = 0
	for run_seed in range(1, 40):
		var state: RunState = RunSession.begin_new_run(run_seed, "rogue")
		assert_int(state.acts_total).is_equal(3)
		var before: Dictionary = state.to_dict()
		if RunNodes.advance_act(state, cfg):
			continue
		failures += 1
		assert_int(state.act).is_equal(1)
		assert_bool(state.past_acts.is_empty()).is_true()
		assert_bool(JSON.stringify(state.to_dict()) == JSON.stringify(before)).override_failure_message("a failed advance_act changed the run state").is_true()
	assert_int(failures).override_failure_message("max_attempts 1 never failed; the check proves nothing").is_greater(0)
