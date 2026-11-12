extends SceneTree
## BD3a offer report (the director's "I kept rejecting Fire offers" and "half my relics were Burn" numbers). Pure and headless: it calls the real
## RewardOffer and RelicOffer over many seeds, with no scene and no fights. Run via tools/run_offer_report.ps1 or:
##   godot --headless --path . -s res://tools/offer_report.gd -- --seeds=1000
## Options (after `--`):
##   --seeds=N     how many run seeds to play (default 1000)
##   --offers=N    how many card reward offers one run has (default 18: about the combat rooms and mini-bosses of a three-act run)
##   --lean=X      override rewards.status_lean for this report (D43 = B; default = data/run.json; 0 = off)
##   --class=ID    the character (default rogue)
##   --skip-starter  force rewards.status_lean_skip_starter true (count only cards beyond the starting deck toward the lean)
##   --count-starter force it false (the starting deck counts toward the lean)
##                   With neither switch the report reads the shipped data/run.json value (it used to overwrite it with false).
##   --matrix      the lean-measurement table instead of the full report: lean 0 / 0.1 / 0.25 x starter counted / not counted, neutral and bleed bots, plus bleed-gone at the best setting
##
## Part 1, relics: what a Fire Rogue's elite and relic-room offers can draw from, listing every eligible relic, which are Burn-dependent (keyword
## Burn and not Bleed: Second Wind reads either status, so it is not), and the share by count and by tier weight for each act.
## Part 2, cards: the Fire share, the Bleed-applier share and the Burn-applier share of the card offers, in three phases of the run, for
##   neutral  - never picks anything (the starting deck all run),
##   bleed    - picks a card that applies Bleed when offered, else rejects (3 rejects), at every 4th offer prunes a card that applies Burn (deck minimums allowed),
##   bleed-old  - the same bot under the pre-D47 rule, where a pruned card could be offered again (NOT in the game, shown to size D47's effect).
##                Every other bot plays the real D47 = B rule: a card pruned from the deck is never offered again that run (RunState.removed_cards),
##   burn     - the mirror: picks a Burn applier, prunes a Bleed applier,
## each with the lean off and with the lean on, so the lean's effect shows. "last 5 offers all Bleed" is the share of the last five offers whose three cards all apply Bleed.

const PRUNE_EVERY := 4
const PHASES: Array = [["early (1-6)", 0, 6], ["mid (7-12)", 6, 12], ["late (13+)", 12, 1000]]

var _cards: Array = []
var _pool_defs: Dictionary = {}
var _pools: Array[String] = []
var _rewards: Dictionary = {}
var _slot_of: Dictionary = {}
var _by_id: Dictionary = {}


func _initialize() -> void:
	var seeds: int = 1000
	var offers: int = 18
	var lean_override: float = -1.0
	var character: String = "rogue"
	var skip_starter: Variant = null  # null = the shipped data/run.json value
	var matrix: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = maxi(int(arg.substr(8)), 1)
		elif arg.begins_with("--offers="):
			offers = maxi(int(arg.substr(9)), 1)
		elif arg.begins_with("--lean="):
			lean_override = float(arg.substr(7))
		elif arg.begins_with("--class="):
			character = arg.substr(8)
		elif arg == "--skip-starter":
			skip_starter = true
		elif arg == "--count-starter":
			skip_starter = false
		elif arg == "--matrix":
			matrix = true
	CardDatabase.load_all()
	RelicDatabase.load_all()
	_cards = CardDatabase.all_cards()
	for card: Variant in _cards:
		_by_id[String((card as Dictionary)["id"])] = card
	for pool_id: Variant in PoolDatabase.known_ids():
		_pool_defs[String(pool_id)] = PoolDatabase.get_definition(String(pool_id))
	_pools = CharacterDatabase.pools(character)
	_rewards = (RunConfig.rewards() as Dictionary).duplicate()
	_slot_of = DeckRules.slot_map_from_database()
	if skip_starter != null:
		_rewards["status_lean_skip_starter"] = bool(skip_starter)
	var shipped_lean: float = float(_rewards.get("status_lean", 0.0))
	var lean_on: float = lean_override if lean_override >= 0.0 else shipped_lean
	print("OFFER REPORT: class %s, pools %s, %d seeds, %d card offers per run, shipped status_lean %s (max %s), lean used for the 'on' rows %s, starter not counted toward the lean: %s%s" % [
			character, _pools, seeds, offers, str(shipped_lean), str(_rewards.get("status_lean_max", 3.0)), str(lean_on), str(_rewards.get("status_lean_skip_starter", false)),
			"" if skip_starter == null else " (set from the command line)"])
	if matrix:
		_matrix(seeds, offers, character)
		quit(0)
		return
	_relic_report()
	print("")
	print("CARD OFFERS (share of every offered card; 3 cards per offer)")
	for bot: String in ["neutral", "bleed", "bleed-old", "burn"]:
		for lean: float in [0.0, lean_on]:
			_card_report(bot, lean, seeds, offers, character)
	quit(0)


# --- relics ---------------------------------------------------------------------------------------------

func _burn_dependent(relic: Dictionary) -> bool:
	var keywords: Array = relic.get("keywords", [])
	return keywords.has("Burn") and not keywords.has("Bleed")


func _relic_report() -> void:
	print("")
	print("RELIC OFFERS (a %s's elite and relic-room offers; every tier with weight)" % str(_pools))
	var empty: Array[String] = []
	var tiers: Array[String] = ["tier1", "tier2", "tier3"]
	for source: String in ["elite", "relic_room"]:
		var weights: Dictionary = RelicConfig.tier_weights_for_act(1)
		var eligible: Array[Dictionary] = RelicOffer.eligible(source, weights, empty, empty, _pools, RelicDatabase.all_relics(), tiers)
		var burn: int = 0
		var names: Array[String] = []
		for relic: Dictionary in eligible:
			var dependent: bool = _burn_dependent(relic)
			burn += 1 if dependent else 0
			names.append("%s%s(%s)" % ["*" if dependent else "", String(relic["id"]), String(relic["rarity"]).replace("tier", "t")])
		print("  %-10s eligible %2d, Burn-dependent %2d = %4.1f%% by count. (* = Burn-dependent) %s" % [source, eligible.size(), burn,
				100.0 * float(burn) / float(maxi(eligible.size(), 1)), ", ".join(names)])
	for act: int in [1, 2, 3]:
		var weights: Dictionary = RelicConfig.tier_weights_for_act(act)
		var eligible: Array[Dictionary] = RelicOffer.eligible("elite", weights, empty, empty, _pools, RelicDatabase.all_relics(), tiers)
		var total: float = 0.0
		var burn_weight: float = 0.0
		for relic: Dictionary in eligible:
			var w: float = float(weights.get(String(relic["rarity"]), 0.0))
			total += w
			burn_weight += w if _burn_dependent(relic) else 0.0
		print("  act %d elite offer, tier weights %s: Burn-dependent share of the drawing weight %4.1f%%" % [act, str(weights), 100.0 * burn_weight / maxf(total, 0.0001)])
	var stray: Array[String] = []
	for relic: Dictionary in RelicDatabase.all_relics():
		if _burn_dependent(relic):
			continue
		var text: String = JSON.stringify(relic.get("triggers", [])) + JSON.stringify(relic.get("modifiers", []))
		if text.contains("burn"):
			stray.append(String(relic["id"]))
	print("  audit: relics whose data mentions 'burn' but are not counted Burn-dependent (they read either status): %s" % [stray])


# --- cards ----------------------------------------------------------------------------------------------

func _applies(card_id: String, status_id: String) -> bool:
	return CardSummary.status_ids(_by_id[card_id]).has(status_id)


func _matrix(seeds: int, offers: int, character: String) -> void:
	print("LEAN MATRIX (skip = rewards.status_lean_skip_starter)")
	for lean: float in [0.0, 0.1, 0.25]:
		for skip: bool in [false, true]:
			if lean == 0.0 and skip:
				continue
			_rewards["status_lean_skip_starter"] = skip
			print("--- lean %s, starter %s" % [str(lean), "not counted" if skip else "counted"])
			for bot: String in ["neutral", "bleed"]:
				_card_report(bot, lean, seeds, offers, character)
	_rewards["status_lean_skip_starter"] = true
	print("--- lean 0.25, starter not counted, the pre-D47 rule (a pruned card can come back; NOT in the game)")
	_card_report("bleed-old", 0.25, seeds, offers, character)


func _card_report(bot: String, lean: float, seeds: int, offers: int, character: String) -> void:
	var rewards: Dictionary = _rewards.duplicate()
	rewards["status_lean"] = lean
	var starter: Array = CharacterDatabase.starting_deck(character)
	# per phase: [offered cards, fire, bleed appliers, burn appliers]
	var phase_counts: Array = []
	for phase: Array in PHASES:
		phase_counts.append([0, 0, 0, 0])
	var last_all_bleed: int = 0
	var last_sets: int = 0
	var bleed_picked: int = 0
	var burn_in_deck_end: int = 0
	var bleed_in_deck_end: int = 0
	for run_seed in range(1, seeds + 1):
		var deck: Array = CharacterDatabase.starting_deck(character).duplicate()
		var removed: Array[String] = []  # the real D47 rule: ids pruned this run are never offered again (bleed-old plays without it)
		var rejects: int = RunConfig.rejects_per_run()
		for index in range(offers):
			var offered: Array[String] = RewardOffer.generate(run_seed, index, deck, _cards, _pools, _pool_defs, rewards, starter, [] if bot == "bleed-old" else removed, mini(1 + index * 3 / offers, 3))
			for phase_index in range(PHASES.size()):
				var phase: Array = PHASES[phase_index]
				if index < int(phase[1]) or index >= int(phase[2]):
					continue
				var counts: Array = phase_counts[phase_index]
				for id: String in offered:
					counts[0] = int(counts[0]) + 1
					counts[1] = int(counts[1]) + (1 if String((_by_id[id] as Dictionary)["pool"]) == "fire" else 0)
					counts[2] = int(counts[2]) + (1 if _applies(id, "bleed") else 0)
					counts[3] = int(counts[3]) + (1 if _applies(id, "burn") else 0)
			if index >= offers - 5 and not offered.is_empty():
				last_sets += 1
				if offered.all(func(id: String) -> bool: return _applies(id, "bleed")):
					last_all_bleed += 1
			var bleeder: bool = bot == "bleed" or bot == "bleed-old"
			var wanted: String = "bleed" if bleeder else ("burn" if bot == "burn" else "")
			var pruned: String = "burn" if bleeder else ("bleed" if bot == "burn" else "")
			if wanted != "":
				var pick: String = ""
				for id: String in offered:
					if not deck.has(id) and _applies(id, wanted):
						pick = id
						break
				if pick != "":
					deck.append(pick)
					bleed_picked += 1 if wanted == "bleed" else 0
				elif rejects > 0:
					rejects -= 1
				if (index + 1) % PRUNE_EVERY == 0:
					for id: String in deck:
						if _applies(id, pruned) and DeckRules.can_remove(deck, id, DeckRules.shipped_config(), _slot_of, SlotTypeDatabase.known_ids()).is_empty():
							deck.erase(id)
							if not removed.has(id):
								removed.append(id)
							break
		for id: String in deck:
			burn_in_deck_end += 1 if _applies(id, "burn") else 0
			bleed_in_deck_end += 1 if _applies(id, "bleed") else 0
	var line: String = "  %-7s lean %-4s" % [bot, str(lean)]
	for phase_index in range(PHASES.size()):
		var counts: Array = phase_counts[phase_index]
		var n: float = maxf(float(counts[0]), 1.0)
		line += " | %s Fire %4.1f%% Bleed %4.1f%% Burn %4.1f%%" % [String((PHASES[phase_index] as Array)[0]).split(" ")[0], 100.0 * float(counts[1]) / n, 100.0 * float(counts[2]) / n, 100.0 * float(counts[3]) / n]
	line += " | Bleed cards picked %.1f" % (float(bleed_picked) / float(seeds))
	line += " | last 5 offers all Bleed %4.1f%% | deck at end: %.1f Bleed, %.1f Burn cards" % [100.0 * float(last_all_bleed) / maxf(float(last_sets), 1.0), float(bleed_in_deck_end) / float(seeds), float(burn_in_deck_end) / float(seeds)]
	print(line)
