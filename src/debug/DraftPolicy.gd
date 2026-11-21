class_name DraftPolicy
extends RefCounted
## SIM2a-1: the "formulated" bot's draft brain. Pure static functions, no random draws, no scene: a test feeds it plain card and relic
## dictionaries. It scores an offered card (and relic) against the deck's emerging archetype and says when to skip.
##
## It reads the archetype from DATA only, never from a card id or name:
##   provides  what a card puts into the deck's economy: "status:<id>" (it applies that status to enemies), "self:<id>" (to the caster),
##             "slot:<slot_type>" (it is cast from that slot), "tag:<Tag>" (a derived tag, a keyword or the pool tag).
##   needs     what a card wants to be live to pay off: every effect `condition` (target_has_status, cast_within, zone_active,
##             self_stacks_at_least, deck_count_at_least), a `scale` by a status, a buff on a status stat (Primer-style
##             "status_damage_mult.burn"), and a detonate_status.
## A card pays off when the deck provides what it needs; a card primes when the deck needs what it provides.
##
## Score of a card (every weight is in WEIGHTS, one table):
##   needs met (avg over its needs, supply capped) * PAYOFF, or DEAD for a need nothing in the deck can meet (a dead card);
##   primes (demand for what it provides, capped at 1) * PRIMER;
##   tag affinity (mean over its derived tags of the share of the deck carrying that tag) * TAG;
##   status lean: + LEAN for applying the deck's dominant status, OFF_LEAN for a rival status when the deck leans hard;
##   Keystone: + KEYSTONE * how much of the deck already supports it (0 below KEYSTONE_MIN supporters);
##   slot coverage: + COVERAGE per missing unique card of its slot (GDD 4 minimums, capped), DUPLICATE for a card id already held.
## Skip when the best card is below SKIP_BASE + SKIP_PER_CARD * (deck size - the free size, the starter deck's).

const WEIGHTS: Dictionary = {
	"PAYOFF": 1.5,
	"DEAD": -1.5,
	"PRIMER": 1.0,
	"TAG": 1.0,
	"LEAN": 0.8,
	"OFF_LEAN": -0.8,
	"KEYSTONE": 1.0,
	"COVERAGE": 0.7,
	"DUPLICATE": -0.6,
	"SKIP_BASE": 0.8,
	"SKIP_PER_CARD": 0.15,
	# Relics
	"RELIC_BASE": 0.5,
	"RELIC_KEY": 1.5,
	"RELIC_DEAD": -1.0,
	"RELIC_BASIC": 1.0,
	"RELIC_SKIP_BELOW": -0.5,
}
## How many suppliers of a need count as "fully met"; how many deck cards make a status the deck's lean.
const SUPPLY_CAP: int = 3
const DEMAND_CAP: int = 3
const LEAN_MIN: int = 2
const KEYSTONE_MIN: int = 3
const COVERAGE_CAP: int = 2
const BASIC_ATTACK_STAT_PREFIXES: Array[String] = ["attack_interval.", "attack_cooldown."]
const BASIC_ATTACK_ORIGINS: Array[String] = ["light", "heavy"]


# ---- reading a card ----

## {provides: Array[String], needs: Array[String], statuses: Array[String], slot: String, tags: Array[String], keywords: Array[String]}, no duplicates.
static func read_card(card: Dictionary) -> Dictionary:
	var provides: Dictionary = {}
	var needs: Dictionary = {}
	var statuses: Dictionary = {}
	var slot: String = String(card.get("slot_type", ""))
	if slot != "":
		provides["slot:" + slot] = true
	var derived: Array[String] = CardTags.derive(card)
	for tag: String in CardTags.all_tags(card):
		provides["tag:" + tag] = true
	var effects: Variant = card.get("effects", [])
	if typeof(effects) == TYPE_ARRAY:
		for effect_variant: Variant in (effects as Array):
			if typeof(effect_variant) != TYPE_DICTIONARY:
				continue
			var effect: Dictionary = effect_variant
			var template: String = String(effect.get("template", ""))
			var params: Dictionary = effect["params"] if typeof(effect.get("params")) == TYPE_DICTIONARY else {}
			var status_id: String = String(params.get("status_id", ""))
			if status_id != "" and StatusDatabase.has_status(status_id):
				if template == "detonate_status":
					needs["status:" + status_id] = true
				elif String(params.get("target", "")) == "self":
					provides["self:" + status_id] = true
				else:
					provides["status:" + status_id] = true
					statuses[status_id] = true
			if template == "buff":
				var stat_status: String = _status_in_stat(String(params.get("stat", "")))
				if stat_status != "":
					needs["status:" + stat_status] = true
			if typeof(effect.get("scale")) == TYPE_DICTIONARY:
				var scale_status: String = String((effect["scale"] as Dictionary).get("status_id", ""))
				if scale_status != "" and StatusDatabase.has_status(scale_status):
					needs["status:" + scale_status] = true
			if typeof(effect.get("condition")) == TYPE_DICTIONARY:
				var need: String = _need_of_condition(effect["condition"] as Dictionary)
				if need != "":
					needs[need] = true
	var keywords: Array[String] = CardTags.keywords_of(card)
	return {"provides": provides.keys(), "needs": needs.keys(), "statuses": statuses.keys(), "slot": slot, "tags": derived, "keywords": keywords}


## The status id a stat names after its dot ("status_damage_mult.burn" -> "burn"), when it is a known status; else "".
static func _status_in_stat(stat: String) -> String:
	if not stat.contains("."):
		return ""
	var tail: String = stat.get_slice(".", 1)
	if StatusDatabase.has_status(tail) and not stat.begins_with("slot_cooldown") and not stat.begins_with("attack_"):
		return tail
	return ""


## The key an effect condition needs, "" when it needs nothing the deck can supply (hp_below, has_bonus_armor, unknown types).
static func _need_of_condition(condition: Dictionary) -> String:
	match String(condition.get("type", "")):
		EffectCondition.TARGET_HAS_STATUS:
			return "status:" + String(condition.get("status_id", ""))
		EffectCondition.SELF_STACKS_AT_LEAST:
			return "status:" + String(condition.get("status_id", ""))
		EffectCondition.CAST_WITHIN:
			if String(condition.get("slot_type", "")) != "":
				return "slot:" + String(condition["slot_type"])
			if String(condition.get("tag", "")) != "":
				return "tag:" + String(condition["tag"])
		EffectCondition.ZONE_ACTIVE:
			return "tag:" + CardTags.ZONE
		EffectCondition.DECK_COUNT_AT_LEAST:
			return "tag:" + String(condition.get("tag", ""))
	return ""


# ---- the deck's profile ----

## The deck read once: key -> how many cards provide it / need it, the dominant status, unique ids per slot, size.
static func profile(deck: Array[Dictionary]) -> Dictionary:
	var provides: Dictionary = {}
	var needs: Dictionary = {}
	var status_cards: Dictionary = {}
	var tag_cards: Dictionary = {}
	var unique_ids: Dictionary = {}
	var unique_by_slot: Dictionary = {}
	for card: Dictionary in deck:
		var read: Dictionary = read_card(card)
		for key: String in (read["provides"] as Array):
			provides[key] = int(provides.get(key, 0)) + 1
		for key: String in (read["needs"] as Array):
			needs[key] = int(needs.get(key, 0)) + 1
		for status_id: String in (read["statuses"] as Array):
			status_cards[status_id] = int(status_cards.get(status_id, 0)) + 1
		for tag: String in (read["tags"] as Array):
			tag_cards[tag] = int(tag_cards.get(tag, 0)) + 1
		var card_id: String = String(card.get("id", ""))
		if not unique_ids.has(card_id):
			unique_ids[card_id] = true
			var slot: String = String(read["slot"])
			unique_by_slot[slot] = int(unique_by_slot.get(slot, 0)) + 1
	var dominant: String = ""
	var best: int = 0
	var status_keys: Array = status_cards.keys()
	status_keys.sort()  # the same deck always gives the same lean
	for status_id: Variant in status_keys:
		if int(status_cards[status_id]) > best:
			best = int(status_cards[status_id])
			dominant = String(status_id)
	return {"provides": provides, "needs": needs, "status_cards": status_cards, "tag_cards": tag_cards, "unique_ids": unique_ids, "unique_by_slot": unique_by_slot, "size": deck.size(), "dominant": dominant, "dominant_count": best}


## How many deck cards supply a need key; a "status:" need is also met by a self-applied status ("self:").
static func supply(prof: Dictionary, key: String) -> int:
	var provides: Dictionary = prof["provides"]
	var total: int = int(provides.get(key, 0))
	if key.begins_with("status:"):
		total += int(provides.get("self:" + key.substr(7), 0))
	return total


# ---- scoring a card ----

static func score_card(card: Dictionary, prof: Dictionary) -> float:
	var read: Dictionary = read_card(card)
	var score: float = 0.0
	var own_provides: Array = read["provides"]
	# 1. Does the deck meet what the card needs?
	var needs: Array = read["needs"]
	if not needs.is_empty():
		var met: float = 0.0
		var dead: float = 0.0
		for key: String in needs:
			var have: int = supply(prof, key) + (1 if own_provides.has(key) or (key.begins_with("status:") and own_provides.has("self:" + key.substr(7))) else 0)
			if have <= 0:
				dead += 1.0
			else:
				met += float(mini(have, SUPPLY_CAP)) / float(SUPPLY_CAP)
		score += float(WEIGHTS["PAYOFF"]) * met / float(needs.size())
		score += float(WEIGHTS["DEAD"]) * dead / float(needs.size())
	# 2. Does the deck need what the card provides (a primer for its payoffs)?
	var demand: float = 0.0
	var prof_needs: Dictionary = prof["needs"]
	for key: String in own_provides:
		var wanted: int = int(prof_needs.get(key, 0))
		if key.begins_with("self:"):
			wanted += int(prof_needs.get("status:" + key.substr(5), 0))
		demand += float(mini(wanted, DEMAND_CAP)) / float(DEMAND_CAP)
	score += float(WEIGHTS["PRIMER"]) * minf(demand, 1.0)
	# 3. Tag affinity with the deck.
	var tags: Array = read["tags"]
	var size: float = maxf(float(int(prof["size"])), 1.0)
	if not tags.is_empty():
		var share: float = 0.0
		var tag_cards: Dictionary = prof["tag_cards"]
		for tag: String in tags:
			share += float(int(tag_cards.get(tag, 0))) / size
		score += float(WEIGHTS["TAG"]) * share / float(tags.size())
	# 4. Status lean.
	var dominant: String = String(prof["dominant"])
	var statuses: Array = read["statuses"]
	if dominant != "" and not statuses.is_empty():
		var status_cards: Dictionary = prof["status_cards"]
		if statuses.has(dominant) and int(prof["dominant_count"]) >= LEAN_MIN:
			score += float(WEIGHTS["LEAN"])
		elif int(prof["dominant_count"]) > LEAN_MIN:
			var rival_count: int = 0
			for status_id: String in statuses:
				rival_count = maxi(rival_count, int(status_cards.get(status_id, 0)))
			if rival_count * 2 < int(prof["dominant_count"]):
				score += float(WEIGHTS["OFF_LEAN"])
	# 5. Keystone, once the deck leans its way.
	if (read["keywords"] as Array).has("Keystone"):
		var supporters: int = 0
		var provides_map: Dictionary = prof["provides"]
		for key: String in needs:
			supporters += int(provides_map.get(key, 0))
		for status_id: String in statuses:
			supporters += int((prof["status_cards"] as Dictionary).get(status_id, 0))
		for key: String in own_provides:
			if key.begins_with("self:") or key.begins_with("status:"):
				supporters += int(prof_needs.get(key, 0))
		if supporters >= KEYSTONE_MIN:
			score += float(WEIGHTS["KEYSTONE"]) * minf(float(supporters) / float(KEYSTONE_MIN * 2), 1.0)
	# 6. Slot coverage and duplicates (GDD 4: unique-card minimums per slot).
	var card_id: String = String(card.get("id", ""))
	if (prof["unique_ids"] as Dictionary).has(card_id):
		score += float(WEIGHTS["DUPLICATE"])
	else:
		var slot: String = String(read["slot"])
		var wanted_unique: int = DeckRules.min_for_slot(DeckRules.shipped_config(), slot)
		var deficit: int = wanted_unique - int((prof["unique_by_slot"] as Dictionary).get(slot, 0))
		if deficit > 0:
			score += float(WEIGHTS["COVERAGE"]) * float(mini(deficit, COVERAGE_CAP))
	return score


## The skip threshold for a deck of this size; `free_size` is the starter deck's.
static func skip_threshold(deck_size: int, free_size: int) -> float:
	return float(WEIGHTS["SKIP_BASE"]) + float(WEIGHTS["SKIP_PER_CARD"]) * float(maxi(0, deck_size - free_size))


## The option id for a PENDING_REWARD choice. `deck_ids` are card ids (looked up here, the only place an id is read).
## Cards are scored in option order and the first best wins a tie. When the skip is disabled the best card is taken even under the threshold.
static func reward_choice(options: Array, deck_ids: Array[String], free_size: int) -> String:
	var deck: Array[Dictionary] = []
	for card_id: String in deck_ids:
		deck.append(CardDatabase.get_card(card_id))
	var prof: Dictionary = profile(deck)
	var skip_id: String = ""
	var best_id: String = ""
	var best_score: float = -INF
	for option: Variant in options:
		var entry: Dictionary = option
		if String(entry.get("kind", "")) == "skip" and bool(entry.get("enabled", true)):
			skip_id = String(entry["id"])
		elif String(entry.get("kind", "")) == "card" and bool(entry.get("enabled", true)):
			var value: float = score_card(CardDatabase.get_card(String(entry["card_id"])), prof)
			if value > best_score:
				best_score = value
				best_id = String(entry["id"])
	if best_id == "":
		return skip_id
	if skip_id != "" and best_score < skip_threshold(deck_ids.size(), free_size):
		return skip_id
	return best_id


# ---- relics ----

## The needs of a relic: statuses its modifiers and triggers name, tags it names as keywords, slots whose cooldown it moves.
static func read_relic(relic: Dictionary) -> Dictionary:
	var needs: Dictionary = {}
	for keyword: Variant in (relic.get("keywords", []) as Array):
		var word: String = String(keyword)
		var status_id: String = word.to_lower()
		if CardTags.STATUS_TAGS.has(status_id):
			needs["status:" + status_id] = true
		else:
			needs["tag:" + word] = true
	for modifier: Variant in (relic.get("modifiers", []) as Array):
		var stat: String = String((modifier as Dictionary).get("stat", ""))
		var stat_status: String = _status_in_stat(stat)
		if stat_status != "":
			needs["status:" + stat_status] = true
		elif stat.begins_with("slot_cooldown."):
			needs["slot:" + stat.get_slice(".", 1)] = true
		elif stat.begins_with("slot_cooldown_skip."):
			needs["slot:" + stat.get_slice(".", 1)] = true
	for trigger: Variant in (relic.get("triggers", []) as Array):
		var filter: Dictionary = (trigger as Dictionary).get("filter", {})
		var filter_status: String = String(filter.get("status_id", ""))
		if filter_status != "" and StatusDatabase.has_status(filter_status):
			needs["status:" + filter_status] = true
	return {"needs": needs.keys(), "basic": _is_basic_attack_relic(relic)}


static func _is_basic_attack_relic(relic: Dictionary) -> bool:
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


## True when one of the deck's cards buffs the light or heavy attack (the deck's plan is its basic attacks).
static func deck_plays_basic_attacks(deck: Array[Dictionary]) -> bool:
	for card: Dictionary in deck:
		for effect: Variant in (card.get("effects", []) as Array):
			var entry: Dictionary = effect
			if String(entry.get("template", "")) != "buff":
				continue
			var stat: String = String((entry.get("params", {}) as Dictionary).get("stat", ""))
			for prefix: String in BASIC_ATTACK_STAT_PREFIXES:
				if stat.begins_with(prefix):
					return true
	return false


## A relic's synergy with the deck: a base value, plus how well the deck supplies what it names (a dead key costs), plus the basic-attack plan.
static func score_relic(relic: Dictionary, prof: Dictionary, basic_plan: bool) -> float:
	var read: Dictionary = read_relic(relic)
	var score: float = float(WEIGHTS["RELIC_BASE"])
	var needs: Array = read["needs"]
	if not needs.is_empty():
		var met: float = 0.0
		var dead: float = 0.0
		for key: String in needs:
			var have: int = supply(prof, key)
			if have <= 0:
				dead += 1.0
			else:
				met += float(mini(have, SUPPLY_CAP)) / float(SUPPLY_CAP)
		score += float(WEIGHTS["RELIC_KEY"]) * met / float(needs.size())
		score += float(WEIGHTS["RELIC_DEAD"]) * dead / float(needs.size())
	if basic_plan and bool(read["basic"]):
		score += float(WEIGHTS["RELIC_BASIC"])
	return score


static func _deck_profile_of_ids(deck_ids: Array[String]) -> Array:
	var deck: Array[Dictionary] = []
	for card_id: String in deck_ids:
		deck.append(CardDatabase.get_card(card_id))
	return [profile(deck), deck_plays_basic_attacks(deck)]


## The option id for a PENDING_RELIC choice: the best-scoring relic (first wins a tie); the skip only when it is offered and every relic scores under RELIC_SKIP_BELOW.
static func relic_choice(options: Array, deck_ids: Array[String]) -> String:
	var both: Array = _deck_profile_of_ids(deck_ids)
	var skip_id: String = ""
	var best_id: String = ""
	var best_score: float = -INF
	for option: Variant in options:
		var entry: Dictionary = option
		if String(entry.get("kind", "")) == "relic" and bool(entry.get("enabled", true)):
			var value: float = score_relic(RelicDatabase.get_relic(String(entry["id"]).get_slice(":", 1)), both[0] as Dictionary, bool(both[1]))
			if value > best_score:
				best_score = value
				best_id = String(entry["id"])
		elif String(entry.get("kind", "")) == "relic_skip":
			skip_id = String(entry["id"])
	if best_id == "":
		return skip_id
	if skip_id != "" and best_score < float(WEIGHTS["RELIC_SKIP_BELOW"]):
		return skip_id
	return best_id


## The option id for a PENDING_RELIC_SWAP choice: the confirm when enabled, else the lowest-scoring giveable relic not yet picked (the cancel when none).
static func giveup_choice(options: Array, deck_ids: Array[String]) -> String:
	var cancel: String = ""
	for option: Variant in options:
		var entry: Dictionary = option
		if String(entry.get("kind", "")) == "giveup_confirm" and bool(entry.get("enabled", false)):
			return String(entry["id"])
	var both: Array = _deck_profile_of_ids(deck_ids)
	var worst_id: String = ""
	var worst_score: float = INF
	for option: Variant in options:
		var entry: Dictionary = option
		if String(entry.get("kind", "")) == "giveup" and bool(entry.get("enabled", true)) and not bool(entry.get("selected", false)):
			var value: float = score_relic(RelicDatabase.get_relic(String(entry["id"]).get_slice(":", 1)), both[0] as Dictionary, bool(both[1]))
			if value < worst_score:
				worst_score = value
				worst_id = String(entry["id"])
		elif String(entry.get("kind", "")) == "back":
			cancel = String(entry["id"])
	return worst_id if worst_id != "" else cancel


# ---- the report ----

## {dominant_status, share, top_tag, top_tag_count}: the status most deck cards apply, and that count over the deck size; the derived tag most cards carry.
static func deck_summary(deck_ids: Array[String]) -> Dictionary:
	var deck: Array[Dictionary] = []
	for card_id: String in deck_ids:
		deck.append(CardDatabase.get_card(card_id))
	var prof: Dictionary = profile(deck)
	var top_tag: String = ""
	var top_count: int = 0
	var tag_keys: Array = (prof["tag_cards"] as Dictionary).keys()
	tag_keys.sort()
	for tag: Variant in tag_keys:
		if int((prof["tag_cards"] as Dictionary)[tag]) > top_count:
			top_count = int((prof["tag_cards"] as Dictionary)[tag])
			top_tag = String(tag)
	var share: float = float(int(prof["dominant_count"])) / maxf(float(deck_ids.size()), 1.0)
	return {"dominant_status": String(prof["dominant"]), "share": share, "top_tag": top_tag, "top_tag_count": top_count}
