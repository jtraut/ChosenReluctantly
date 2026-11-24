extends SceneTree
## BAL1-A shop report: how often each relic is in the first stock of a merchant visit (headless, pure; it calls the real Merchant.draw_stock).
## Request for Quotation's "about 79% of shops" (DECISIONS MAP2) is the number this re-measures. A fresh run (no relics held) opens a visit at
## each of `--seeds` run seeds in each of acts 1 to 3; the share is stocks holding the relic over visits drawn. No game data or code is changed.
##   godot --headless --path . -s res://tools/shop_report.gd -- --seeds=1000 --class=rogue

const NODE_ID := 5


## {relic_id: visits holding it}, plus "_visits" (the visits drawn) for one class and act. Pure: used by the tests.
static func count_stocks(character: String, act: int, seeds: int, ctx: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for run_seed: int in range(1, seeds + 1):
		var state: RunState = RunState.new_run(run_seed, CharacterDatabase.starting_deck(character), 3)
		state.act = act
		var stock: Dictionary = Merchant.draw_stock(state, NODE_ID, 0, ctx, [] as Array[String], [] as Array[String])
		for id: String in (stock["relics"] as Array[String]):
			counts[id] = int(counts.get(id, 0)) + 1
	counts["_visits"] = seeds
	return counts


func _initialize() -> void:
	var seeds: int = 1000
	var characters: Array[String] = ["rogue", "wizard"]
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = maxi(int(arg.substr(8)), 1)
		elif arg.begins_with("--class="):
			characters = [arg.substr(8)]
	CardDatabase.load_all()
	RelicDatabase.load_all()
	for character: String in characters:
		var ctx: Dictionary = RunChoices.shipped_context(CharacterDatabase.pools(character))
		for act: int in [1, 2, 3]:
			var counts: Dictionary = count_stocks(character, act, seeds, ctx)
			var ids: Array = counts.keys().filter(func(k: Variant) -> bool: return String(k) != "_visits")
			ids.sort_custom(func(a: Variant, b: Variant) -> bool: return int(counts[a]) > int(counts[b]))
			var parts: Array[String] = []
			for id: Variant in ids.slice(0, 8):
				parts.append("%s %.1f%%" % [String(id), 100.0 * float(counts[id]) / float(seeds)])
			print("SHOP %s act %d (%d visits, 3 relics each): %s | request_for_quotation %.1f%% | liquidate_assets %.1f%%" % [character, act, seeds, ", ".join(parts), 100.0 * float(counts.get("request_for_quotation", 0)) / float(seeds), 100.0 * float(counts.get("liquidate_assets", 0)) / float(seeds)])
	quit(0)
