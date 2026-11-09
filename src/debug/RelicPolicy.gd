class_name RelicPolicy
extends RefCounted
## The bot's relic choices (BD2-B; wave sim `-Run`). Pure over the choice model's options, so a test can drive it with plain
## dictionaries, and it draws no random numbers (adding relics never shifts the bot's other seeded choices).
##
## Rules: take the first offered relic that matches the deck's archetype, else the first offered; skip only when nothing is
## offered. At the cap, give up the first giveable relic. A relic "matches" when one of its keywords is carried by at least
## MATCH_MIN_CARDS cards of the deck (the deck's tags come from CardTags, so "Burn" is a plan when 3+ cards apply Burn).
##
## BD3a: a second plan, the basic-attack one. A deck "plays basic attacks" when one of its cards buffs the light or heavy attack (a buff on an
## attack_interval.* or attack_cooldown.* stat). A relic is a "basic-attack relic" when a modifier changes those stats or a trigger reacts to a
## light or heavy hit. Both are read from data, never from ids. With the plan, such a relic is taken when no keyword match comes first.

const MATCH_MIN_CARDS := 3
const BASIC_ATTACK_STAT_PREFIXES: Array[String] = ["attack_interval.", "attack_cooldown."]
const BASIC_ATTACK_ORIGINS: Array[String] = ["light", "heavy"]


## How many cards of the deck carry each tag (derived tags and keywords).
static func tag_counts(deck: Array[String]) -> Dictionary:
	var counts: Dictionary = {}
	for card_id: String in deck:
		for tag: String in CardDatabase.tags_for(card_id):
			counts[tag] = int(counts.get(tag, 0)) + 1
	return counts


## True when one of the relic's keywords is carried by enough cards of the deck.
static func matches(keywords: Array, counts: Dictionary) -> bool:
	for keyword: Variant in keywords:
		if int(counts.get(String(keyword), 0)) >= MATCH_MIN_CARDS:
			return true
	return false


## True when one of the deck's cards buffs the light or heavy attack (a Keystone like Warm-Up): the deck's plan is its basic attacks.
static func plays_basic_attacks(deck: Array[String]) -> bool:
	for card_id: String in deck:
		for effect: Variant in (CardDatabase.get_card(card_id).get("effects", []) as Array):
			var entry: Dictionary = effect
			if String(entry.get("template", "")) != "buff":
				continue
			var stat: String = String((entry.get("params", {}) as Dictionary).get("stat", ""))
			for prefix: String in BASIC_ATTACK_STAT_PREFIXES:
				if stat.begins_with(prefix):
					return true
	return false


## True when the relic changes the light or heavy attack's timing or reacts to a light or heavy hit (Muscle Memory, Overtime, Spite Knuckles, Heavy Sigh).
static func is_basic_attack_relic(relic: Dictionary) -> bool:
	for modifier: Variant in (relic.get("modifiers", []) as Array):
		var stat: String = String((modifier as Dictionary).get("stat", ""))
		for prefix: String in BASIC_ATTACK_STAT_PREFIXES:
			if stat.begins_with(prefix):
				return true
	for trigger: Variant in (relic.get("triggers", []) as Array):
		var origin: Variant = ((trigger as Dictionary).get("filter", {}) as Dictionary).get("origin")
		if origin == null:
			continue
		var origins: Array = origin if typeof(origin) == TYPE_ARRAY else [origin]
		for entry: Variant in origins:
			if BASIC_ATTACK_ORIGINS.has(str(entry)):
				return true
	return false


## The option id to answer a PENDING_RELIC choice with. `options` is the model's option list.
static func offer_choice(options: Array, deck: Array[String]) -> String:
	var counts: Dictionary = tag_counts(deck)
	var basic_plan: bool = plays_basic_attacks(deck)
	var first: String = ""
	var basic: String = ""
	var skip: String = ""
	for option: Variant in options:
		var entry: Dictionary = option
		if String(entry.get("kind", "")) == "relic" and bool(entry.get("enabled", true)):
			if first == "":
				first = String(entry["id"])
			if matches(entry.get("keywords", []), counts):
				return String(entry["id"])
			if basic == "" and basic_plan and is_basic_attack_relic(RelicDatabase.get_relic(String(entry["id"]))):
				basic = String(entry["id"])
		elif String(entry.get("kind", "")) == "relic_skip":
			skip = String(entry["id"])
	if basic != "":
		return basic
	return first if first != "" else skip


## The option id to answer a PENDING_RELIC_SWAP choice with: the first relic that may be given up (the cancel option when none).
static func giveup_choice(options: Array) -> String:
	var cancel: String = ""
	for option: Variant in options:
		var entry: Dictionary = option
		if String(entry.get("kind", "")) == "giveup" and bool(entry.get("enabled", true)):
			return String(entry["id"])
		elif String(entry.get("kind", "")) == "back":
			cancel = String(entry["id"])
	return cancel
