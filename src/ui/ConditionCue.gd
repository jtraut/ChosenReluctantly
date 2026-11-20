class_name ConditionCue
extends RefCounted
## Short wording for a conditional card (BD1 carry-over): the dim line on a HUD slot that says why the slot is not lit
## ("Needs Burn", "After Move", "Needs zone"), and the note on a reward card that the dodge does not count as a Movement cast (D39 = A).
## Pure functions over a card dictionary and the strings of data/run.json `ui.slot_condition` and `ui.option.dodge_hint`; no scene.


## The distinct short conditions of `card`, joined with ", ". "" for a card with no condition. `texts` is ui.slot_condition.
static func short_text(card: Dictionary, texts: Dictionary) -> String:
	var seen: Array[String] = []
	for effect: Dictionary in SlotSynergy.conditional_effects(card):
		var shown: String = _short(effect["condition"], texts)
		if shown != "" and not seen.has(shown):
			seen.append(shown)
	var payoff: String = detonate_short(card, texts)
	if payoff != "":
		seen.append(payoff)
	return ", ".join(seen)


## MB1 ux (BD3a playtest carry-over): a card that cashes in a status (a `detonate_status` effect, Open a Vein) works with one stack but is the
## point of the build with several, and nothing on the slot said so. The dim line says "Wants Bleed stacks". Read from the effect, never a card id;
## it is words only (no glow), so the slot's LIVE state and the bot's plan, which read conditions, are untouched. "" for any other card.
static func detonate_short(card: Dictionary, texts: Dictionary) -> String:
	var effects: Variant = card.get("effects", [])
	if typeof(effects) != TYPE_ARRAY:
		return ""
	for effect: Variant in (effects as Array):
		if typeof(effect) == TYPE_DICTIONARY and String((effect as Dictionary).get("template", "")) == "detonate_status":
			var params: Variant = (effect as Dictionary).get("params", {})
			var status_id: String = String((params as Dictionary).get("status_id", "")) if params is Dictionary else ""
			var entry: Dictionary = StatusDatabase.get_status(status_id)
			return String(texts.get("detonate_status", "")) % String(entry.get("display_name", status_id.replace("_", " ").capitalize())) if String(texts.get("detonate_status", "")).contains("%s") else ""
	return ""


## DF1 ux (MAP4 playtest): a curse card sits in a slot and nothing said you can swap past it. The dim line reads "Shift+Q swaps" (`swap_key` is the
## slot's dead-card swap key text from InputLabels, so a rebind shows). Words only; "" for any card that is not a curse or when the data has no `curse_swap` line.
## BD3b-0: with `penalty` (seconds, from data/run.json curses.curse_swap_penalty; negative = leave it off) the line reads "Shift+Q swaps (2 s)" from `curse_swap_timed`.
static func curse_swap_text(card: Dictionary, texts: Dictionary, swap_key: String, penalty: float = -1.0) -> String:
	var line: String = String(texts.get("curse_swap", ""))
	if line == "" or not line.contains("%s") or not CardSchema.is_curse(card):
		return ""
	var free: String = String(texts.get("curse_swap_free", ""))
	if penalty >= 0.0 and is_zero_approx(penalty) and free.contains("%s"):
		return free % swap_key  # BD3b-ux: a relic (Filing Cabinet) made this slot's swap free, curse included
	var timed: String = String(texts.get("curse_swap_timed", ""))
	if penalty >= 0.0 and timed.count("%s") == 2:
		return timed % [swap_key, String.num(penalty, 2).trim_suffix("0").trim_suffix(".0").trim_suffix(".")]
	return line % swap_key


## BD3b-ux: "Swap: free" for an ordinary card whose slot swap costs nothing now (`penalty`, from CardSlot.current_swap_penalty(stat_modifiers)) while it
## costs something without the modifiers (`base_penalty`, current_swap_penalty(null)). Never computed here: both come from the slot. "" for a curse (its own
## line, curse_swap_text, says it), for a swap that costs time and for one that was free anyway.
static func swap_free_text(card: Dictionary, texts: Dictionary, penalty: float, base_penalty: float) -> String:
	if CardSchema.is_curse(card) or penalty < 0.0 or not is_zero_approx(penalty) or base_penalty <= 0.0:
		return ""
	return String(texts.get("swap_free", ""))


## UX1a: the word that marks an element card without colour ("Fire"): the card's pool tag when the pool is an element (data/pools.json `kind` and `tag`),
## "" for a class, neutral or curse card. Read from the pool, never a card id, so a new element needs data only.
static func element_mark_text(card: Dictionary) -> String:
	var pool_id: String = String(card.get("pool", ""))
	if CardSchema.is_curse(card) or not PoolDatabase.has(pool_id) or String(PoolDatabase.get_definition(pool_id).get("kind", "")) != "element":
		return ""
	return PoolDatabase.tag_for_pool(pool_id)


## BD3b-ux: the live value of a scaled card ("+10 per Charge, now +60") as candidates, longest first, so the slot picks the first that fits:
## the long form, then the short "Now +60". `scaled` is EffectScale.preview_values(card, caster, deck) (same order as the card's scaled effects);
## `texts` is ui.slot_condition, `scale_words` is ui.effect.scale. The "uses up your Charge" part stays on the card text; it does not fit a slot.
## Several scaled effects show the first one. [] for a card with no scale.
static func scale_candidates(card: Dictionary, scaled: Array, texts: Dictionary, scale_words: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if scaled.is_empty() or not String(texts.get("scale_now", "")).contains("%s") or scale_words.is_empty():
		return out
	var index: int = 0
	for effect: Variant in (card.get("effects", []) as Array):
		if typeof(effect) != TYPE_DICTIONARY or typeof((effect as Dictionary).get("scale")) != TYPE_DICTIONARY:
			continue
		var block: Dictionary = ((effect as Dictionary)["scale"] as Dictionary).duplicate()
		var param: String = EffectScale.param_name(block, String((effect as Dictionary).get("template", "")))
		if param.is_empty() or not ((effect as Dictionary).get("params", {}) as Dictionary).has(param):
			continue  # preview_values skips these too, so the indexes stay paired
		if index >= scaled.size():
			break
		var now: String = _number(float((scaled[index] as Dictionary).get("bonus", 0.0)))
		block["consume"] = false
		var status_id: String = String(block.get("status_id", ""))
		var status_name: String = String(StatusDatabase.get_status(status_id).get("display_name", status_id.replace("_", " ").capitalize()))
		var per_text: String = EffectScale.text(block, scale_words, status_name)
		if per_text != "":
			out.append(String(texts["scale_now"]) % [per_text, now])
		var unit: String = status_name if String(block.get("by", "")) == EffectScale.SELF_STACKS else String(block.get("tag", ""))
		if String(texts.get("scale_now_mid", "")).count("%s") == 3 and unit != "":
			out.append(String(texts["scale_now_mid"]) % [_number(float(block.get("per", 0.0))), unit, now])
		if String(texts.get("scale_now_short", "")).contains("%s"):
			out.append(String(texts["scale_now_short"]) % now)
		return out
	return out


static func _number(value: float) -> String:
	if absf(value - roundf(value)) < 0.0001:
		return str(int(roundf(value)))
	return String.num(value, 2).trim_suffix("0")


## BD3b-ux: the pills over a slot, most important first, at most `limit` (the slot draws the first one nearest its frame). One place for the priority, since
## four things want that space: (1) the curse swap line (a curse is the dud the player must act on), (2) the live scale value, (3) why a conditional
## card is not lit, (4) "Swap: free". `scale` is scale_candidates (the slot picks which fits); every entry is [{"text": String, "alternatives": Array[String]}].
## UX1a: `swap_ready` (the slot's card is ready to cast) drops "Swap: free", which is only worth saying while the slot is cooling and a swap is the question;
## `swaps_locked` (The Micromanager) drops both swap lines, since a swap is not on offer. The live scale value and the reason tag are unaffected.
static func pill_lines(curse_line: String, scale: Array[String], condition_line: String, free_line: String, limit: int, swap_ready: bool = false, swaps_locked: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if swaps_locked:
		curse_line = ""
		free_line = ""
	elif swap_ready:
		free_line = ""
	if curse_line != "":
		out.append({"kind": "curse", "text": curse_line, "alternatives": [] as Array[String]})
	if not scale.is_empty():
		out.append({"kind": "scale", "text": scale[0], "alternatives": scale.slice(1)})
	if condition_line != "":
		out.append({"kind": "condition", "text": condition_line, "alternatives": [] as Array[String]})
	if free_line != "":
		out.append({"kind": "free", "text": free_line, "alternatives": [] as Array[String]})
	while out.size() > maxi(limit, 0):
		out.pop_back()
	return out


static func _short(condition: Dictionary, texts: Dictionary) -> String:
	match String(condition.get("type", "")):
		EffectCondition.TARGET_HAS_STATUS:
			var status_id: String = String(condition.get("status_id", ""))
			var entry: Dictionary = StatusDatabase.get_status(status_id)
			return String(texts.get("target_has_status", "")) % String(entry.get("display_name", status_id.replace("_", " ").capitalize()))
		EffectCondition.CAST_WITHIN:
			var times: int = int(condition.get("count", 1))  # BD3b-C2 `count` variant: "After 3 Fire casts"; one cast keeps the old wording
			if condition.has("slot_type"):
				var slot_type: String = String(condition["slot_type"])
				var short_names: Dictionary = texts.get("slot_short", {})
				var key: String = InputLabels.slot_key(slot_type)
				if times > 1 and String(texts.get("cast_within_slot_count", "")) != "":
					return String(texts["cast_within_slot_count"]) % [times, String(short_names.get(slot_type, InputLabels.slot_name(slot_type)))]
				if String(texts.get("cast_within_slot_key", "")) != "" and key != "" and key != "?":
					# "After Move (Ctrl)": the player acts on a key, not on a slot name.
					return String(texts["cast_within_slot_key"]) % [String(short_names.get(slot_type, InputLabels.slot_name(slot_type))), key]
				return String(texts.get("cast_within_slot", "")) % String(short_names.get(slot_type, InputLabels.slot_name(slot_type)))
			if times > 1 and String(texts.get("cast_within_tag_count", "")) != "":
				return String(texts["cast_within_tag_count"]) % [times, String(condition.get("tag", ""))]
			return String(texts.get("cast_within_tag", "")) % String(condition.get("tag", ""))
		EffectCondition.ZONE_ACTIVE:
			return String(texts.get("zone_active", ""))
		EffectCondition.SELF_STACKS_AT_LEAST:
			var stack_status: String = String(condition.get("status_id", ""))
			var stack_name: String = String(StatusDatabase.get_status(stack_status).get("display_name", stack_status.replace("_", " ").capitalize()))
			return String(texts.get("self_stacks_at_least", "")) % [int(condition.get("count", 0)), stack_name]
		EffectCondition.DECK_COUNT_AT_LEAST:
			return String(texts.get("deck_count_at_least", "")) % [int(condition.get("count", 0)), String(condition.get("tag", ""))]
		EffectCondition.HP_BELOW:
			return String(texts.get("hp_below", "")) % String.num(roundf(float(condition.get("fraction", 0.0)) * 100.0), 0)
		EffectCondition.HAS_BONUS_ARMOR:
			return String(texts.get("has_bonus_armor", ""))
	return ""


## True when the card has a condition on a cast of a slot in `dodge_slots` (Movement), and the dodge does not count as such a cast
## (D39 = A, data/player.json dodge.counts_as_movement_cast false): the card then needs the "dodge does not count" note.
static func needs_dodge_note(card: Dictionary, dodge_slots: Array, dodge_counts: bool) -> bool:
	if dodge_counts:
		return false
	for effect: Dictionary in SlotSynergy.conditional_effects(card):
		var condition: Dictionary = effect["condition"]
		if String(condition.get("type", "")) == EffectCondition.CAST_WITHIN and dodge_slots.has(String(condition.get("slot_type", ""))):
			return true
	return false
