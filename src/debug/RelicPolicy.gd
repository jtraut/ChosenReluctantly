class_name RelicPolicy
extends RefCounted
## The bot's relic choices (BD2-B; wave sim `-Run`). Pure over the choice model's options, so a test can drive it with plain
## dictionaries, and it draws no random numbers (adding relics never shifts the bot's other seeded choices).
##
## Rules: take the first offered relic that matches the deck's archetype, else the first offered; skip only when nothing is
## offered. At the cap, give up the first giveable relic. A relic "matches" when one of its keywords is carried by at least
## MATCH_MIN_CARDS cards of the deck (the deck's tags come from CardTags, so "Burn" is a plan when 3+ cards apply Burn).

const MATCH_MIN_CARDS := 3


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


## The option id to answer a PENDING_RELIC choice with. `options` is the model's option list.
static func offer_choice(options: Array, deck: Array[String]) -> String:
	var counts: Dictionary = tag_counts(deck)
	var first: String = ""
	var skip: String = ""
	for option: Variant in options:
		var entry: Dictionary = option
		if String(entry.get("kind", "")) == "relic" and bool(entry.get("enabled", true)):
			if first == "":
				first = String(entry["id"])
			if matches(entry.get("keywords", []), counts):
				return String(entry["id"])
		elif String(entry.get("kind", "")) == "relic_skip":
			skip = String(entry["id"])
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
