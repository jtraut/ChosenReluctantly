extends SceneTree
## Prints a seed's branching map as text (MAP1-A debug helper). Run via tools/run_map_print.ps1 or:
##   godot --headless --path . -s res://tools/map_print.gd -- --seed=7
## Options (after `--`):
##   --seed=N        the run seed (default 1)
##   --sweep=N       generate seeds 1..N instead: prints failures, the attempts histogram and the time taken; exits 1 on any failure
##   --set=a.b.c=JSON  override one config value for this run only (tuning experiments; repeatable), e.g. --set=types.rest.weight=20 --set=types.rest.rooms=[4,9]
##   --from=N        with --sweep: start at seed N (seeds N .. N+sweep-1; default 1)
##   --merchant      turn the merchant on first (data/merchant_on.json merged into the map config, MAP2-B); --set values are applied on top
##   --route=first   also print the `first` route's node ids
## Output: one line per room (cells by column: C combat, E elite, R* relic stage, Rs rest, M merchant, MB mini-boss, BOSS), the edges
## as column pairs, the wave ids, then the path-rule scores (paths, min fights, max elite-like, rests, merchants, relic estimate best and worst).


func _initialize() -> void:
	var seed_value: int = 1
	var sweep: int = 0
	var first_seed: int = 1
	var show_route: bool = false
	var merchant_on: bool = false
	var overrides: Array[String] = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = int(arg.substr(7))
		elif arg.begins_with("--sweep="):
			sweep = int(arg.substr(8))
		elif arg.begins_with("--from="):
			first_seed = int(arg.substr(7))
		elif arg == "--route=first":
			show_route = true
		elif arg == "--merchant":
			merchant_on = true
		elif arg.begins_with("--set="):
			overrides.append(arg.substr(6))
	var cfg: Dictionary = MapConfig.get_config()
	if cfg.is_empty():
		printerr("map_print: data/map.json is invalid: ", "; ".join(MapConfig.load_problems()))
		quit(1)
		return
	if merchant_on:
		var switched: Dictionary = MerchantSwitch.patched_map()
		if (switched["config"] as Dictionary).is_empty():
			printerr("map_print: the merchant patch is invalid: ", "; ".join(switched["problems"]))
			quit(2)
			return
		cfg = switched["config"]
	if not overrides.is_empty():
		cfg = cfg.duplicate(true)
		for item: String in overrides:
			var eq: int = item.find("=")
			var parsed: Variant = JSON.parse_string(item.substr(eq + 1)) if eq > 0 else null
			if eq <= 0 or parsed == null:
				printerr("map_print: bad --set=%s (want path=JSON)" % item)
				quit(2)
				return
			var node: Dictionary = cfg
			var keys: PackedStringArray = item.substr(0, eq).split(".")
			for i in range(keys.size() - 1):
				node = node[keys[i]]
			node[keys[keys.size() - 1]] = parsed
		var problems: Array[String] = MapConfig.validate(cfg)
		if not problems.is_empty():
			printerr("map_print: the overridden config is invalid: ", "; ".join(problems))
			quit(2)
			return
	if sweep > 0:
		quit(_sweep(sweep, cfg, first_seed))
		return
	var result: Dictionary = MapGenerator.build(seed_value, cfg)
	if not bool(result["ok"]):
		printerr(String(result["error"]))
		quit(1)
		return
	var map: Dictionary = result["map"]
	print("seed %d: %d nodes, %d edges, %d attempts (columns 0..%d left to right; rooms top to bottom)" % [seed_value, (map["nodes"] as Array).size(), (map["edges"] as Array).size(), int(result["attempts"]), int(cfg["columns"]) - 1])
	print(MapGraph.to_text(map, int(cfg["columns"])))
	var chest_parts: Array[String] = []
	for entry: Dictionary in (map["nodes"] as Array):
		if entry.has("chest"):
			chest_parts.append("%d (room %d) %s" % [int(entry["id"]), int(entry["room"]), String(entry["chest"])])
	if not chest_parts.is_empty():
		print("chests: ", ", ".join(chest_parts))
	var stats: MapRules.Extremes = MapRules.evaluate(map, cfg)
	print("paths %d | min fights %d (rule >= %d) | max elite-like %d (<= %d) | min rest %d (>= %d) | max rest %d (<= %d) | max merchants %d (<= %d) | relic estimate best %d (in %s) worst %d (<= %d)" % [
		stats.paths, stats.min_fights, int(cfg["path_rules"]["min_fights"]), stats.max_elite_like, int(cfg["path_rules"]["max_elite_like"]),
		stats.min_rest, int(cfg["path_rules"]["min_rest"]), stats.max_rest, int(cfg["path_rules"]["max_rest"]), stats.max_merchants, int(cfg["path_rules"]["max_merchants"]),
		stats.best_relics, str(cfg["path_rules"]["relic_route"]), stats.worst_relics, int(cfg["path_rules"]["ignore_route_max"])])
	var problems: Array[String] = MapRules.check(map, cfg)
	print("rules: ", "all hold" if problems.is_empty() else "; ".join(problems))
	if show_route:
		print("first route: ", MapGraph.first_route(map))
	quit(0 if problems.is_empty() else 1)


func _sweep(count: int, cfg: Dictionary, first_seed: int = 1) -> int:
	var started: int = Time.get_ticks_msec()
	var failures: int = 0
	var histogram: Dictionary = {}
	var worst: int = 0
	for seed_value in range(first_seed, first_seed + count):
		var result: Dictionary = MapGenerator.build(seed_value, cfg)
		if not bool(result["ok"]):
			failures += 1
			printerr("seed %d: %s" % [seed_value, String(result["error"])])
			continue
		var problems: Array[String] = MapRules.check(result["map"], cfg)
		if not problems.is_empty():
			failures += 1
			printerr("seed %d breaks a rule: %s" % [seed_value, "; ".join(problems)])
		var bucket: int = int(result["attempts"])
		worst = maxi(worst, bucket)
		var key: String = "1" if bucket == 1 else ("2-5" if bucket <= 5 else ("6-20" if bucket <= 20 else ("21-60" if bucket <= 60 else "61+")))
		histogram[key] = int(histogram.get(key, 0)) + 1
	print("sweep %d..%d: %d failures, worst attempts %d, attempts histogram %s, %d ms" % [first_seed, first_seed + count - 1, failures, worst, str(histogram), Time.get_ticks_msec() - started])
	return 0 if failures == 0 else 1
