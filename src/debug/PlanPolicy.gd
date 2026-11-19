class_name PlanPolicy
extends RefCounted
## The plan-aware bot policy (BD1; wave sim `-Plan`, bot sim `--plan`). It decides, per card slot, whether to cast,
## swap the dead card, or wait. It reads the `condition` blocks of the card data (never a card id), so a new payoff
## card needs no policy change. Pure over plain data: slots are CardSlot objects, the world is a SlotSynergy `view`.
##
## Rules:
##   * A card with a condition is cast as soon as the condition is live.
##   * Otherwise it is held. After HOLD_SECONDS of holding (time with the slot ready and an enemy about) it is cast anyway.
##   * A held payoff whose condition cannot come true soon (nothing in the other slots would set it up within
##     SOON_SECONDS, and no enemy already has the status) is swapped away at once, if the slot has another card.
##   * BD3b-D2, a spender (an effect whose `scale` reads the caster's own stacks, such as Thesis Defense) is held until the stacks are
##     worth spending: at SPEND_AT_STACKS or more, or when any stacks are about to decay (SPEND_DECAY_MARGIN s left). With no stacks
##     and no other slot able to build them soon it is swapped away; after the hold time it is cast anyway.
##   * BD3b-D2, a buff that carries `triggers` (Spiteful Ward) is cast before contact: an enemy within TRIGGER_BUFF_RANGE, or danger
##     about to land, and not while the same slot's last cast is still running.
##   * An unconditional attack is cast when an enemy is inside its preview area; a Utility card when an enemy is near;
##     a Recovery card when HP is low.
##   * Movement is an escape by default (cast when in danger with no dodge charge left). It is spent offensively
##     ("dash in") when another slot's payoff reads a Movement cast (cast_within) and that slot is ready soon.
##   * The dodge itself is not decided here (the sim's own escape logic uses its charges).

const HOLD_SECONDS := 1.5
const SOON_SECONDS := 3.0
const NEAR_ENEMY := 12.0
const RECOVERY_BELOW_HP := 0.7
## "Dash in" only from a gap: closer than this the dash would push through the target, further than FAR it would waste the window.
const DASH_IN_MIN := 2.0
const DASH_IN_MAX := 9.0
## BD3b-D2: a spender fires at this many stacks of what it spends (Charge: 6 of 10), or when they have this many seconds left before decaying.
const SPEND_AT_STACKS := 6
const SPEND_DECAY_MARGIN := 1.0
## BD3b-D2: a triggered buff (Spiteful Ward) goes up when the nearest enemy is this close (m), so its few seconds cover the contact.
const TRIGGER_BUFF_RANGE := 8.0

const CAST := "cast"
const SWAP := "swap"
const WAIT := "wait"

var hold_seconds: float = HOLD_SECONDS
## MAP3b: set by the caller each frame from CardSlotController.swap_locked(): while true the policy never decides SWAP (it casts or waits instead).
var swap_locked: bool = false
## slot type -> {"card": id, "since": game time the hold began}; absent = not holding.
var _holding: Dictionary = {}


## The decision for every slot, as {slot_type: "cast" | "swap" | "wait"}.
## `slots`: slot type -> CardSlot. `view`: SlotSynergy view (now, history, zone_count, origin, enemies...).
## `hp_fraction` 0..1. `in_danger`: something is about to hit the player. `dodge_ready`: a dodge charge is available.
func decide_all(slots: Dictionary, view: Dictionary, hp_fraction: float, in_danger: bool, dodge_ready: bool) -> Dictionary:
	var decisions: Dictionary = {}
	for slot_type: String in CardSlotController.SLOT_TYPE_ORDER:
		var slot: CardSlot = slots.get(slot_type)
		if slot == null:
			continue
		decisions[slot_type] = decide(slot_type, slot, slots, view, hp_fraction, in_danger, dodge_ready)
	return decisions


func decide(slot_type: String, slot: CardSlot, slots: Dictionary, view: Dictionary, hp_fraction: float, in_danger: bool, dodge_ready: bool) -> String:
	if not slot.is_ready():
		_holding.erase(slot_type)
		return WAIT
	var card: Dictionary = CardDatabase.get_card(slot.current_card_id)
	if card.is_empty():
		return WAIT
	var enemies: Array = view.get("enemies", [])
	var now: float = float(view.get("now", 0.0))
	if CardSchema.is_curse(card):
		# MAP4-C: a curse is swapped away. With swaps locked (The Micromanager), or a slot holding nothing but curses, it is cast as soon as the slot is ready instead, because
		# casting is the only way the slot moves on (the cooldown starts and the next card is drawn).
		_holding.erase(slot_type)
		return SWAP if (not swap_locked and _has_other_real_card(slot)) else CAST
	if not spender_scale(card).is_empty():
		return _decide_spender(slot_type, slot, card, slots, view, now, enemies)
	if SlotSynergy.conditional_effects(card).size() > 0:
		return _decide_payoff(slot_type, slot, card, slots, view, now, enemies)
	_holding.erase(slot_type)
	match slot_type:
		"attack_single", "attack_aoe":
			return CAST if SlotSynergy.enemy_in_area(card, view) else WAIT
		"utility":
			if has_trigger_buff(card):
				return CAST if _trigger_buff_wanted(slot_type, card, view, in_danger) else WAIT
			return CAST if _nearest_enemy_distance(view) <= NEAR_ENEMY else WAIT
		"recovery":
			return CAST if (hp_fraction < RECOVERY_BELOW_HP and not enemies.is_empty()) else WAIT
		"movement":
			return CAST if _movement_wanted(card, slots, view, in_danger, dodge_ready) else WAIT
	return WAIT


func _decide_payoff(slot_type: String, slot: CardSlot, card: Dictionary, slots: Dictionary, view: Dictionary, now: float, enemies: Array) -> String:
	if SlotSynergy.is_live(card, view):
		_holding.erase(slot_type)
		return CAST
	if enemies.is_empty():
		_holding.erase(slot_type)  # nothing to hit: the hold clock only runs in a fight
		return WAIT
	var held: Dictionary = _holding.get(slot_type, {})
	if held.is_empty() or String(held["card"]) != slot.current_card_id or now < float(held["since"]):  # a new room resets the clock
		held = {"card": slot.current_card_id, "since": now}
		_holding[slot_type] = held
	if not swap_locked and not can_pay_off_soon(card, slot_type, slots, view) and _has_other_card(slot):
		_holding.erase(slot_type)
		return SWAP
	if now - float(held["since"]) >= hold_seconds:
		_holding.erase(slot_type)
		return CAST
	return WAIT


## The `scale` block of a spender card (an effect scaled by the caster's own stacks of a status), {} when the card has none.
static func spender_scale(card: Dictionary) -> Dictionary:
	for effect: Variant in card.get("effects", []):
		var scale: Variant = (effect as Dictionary).get("scale")
		if scale is Dictionary and String((scale as Dictionary).get("by", "")) == EffectScale.SELF_STACKS:
			return scale as Dictionary
	return {}


## True when a buff effect of the card carries `triggers` (a buff that reacts while it lasts).
static func has_trigger_buff(card: Dictionary) -> bool:
	return _trigger_buff_duration(card) > 0.0


## The longest duration of the card's triggered buffs (0 when it has none).
static func _trigger_buff_duration(card: Dictionary) -> float:
	var longest: float = 0.0
	for effect: Variant in card.get("effects", []):
		var params: Dictionary = (effect as Dictionary).get("params", {})
		if String((effect as Dictionary).get("template", "")) == "buff" and not (params.get("triggers", []) as Array).is_empty():
			longest = maxf(longest, maxf(float(params.get("duration", 0.0)), 0.001))
	return longest


func _trigger_buff_wanted(slot_type: String, card: Dictionary, view: Dictionary, in_danger: bool) -> bool:
	if (view.get("enemies", []) as Array).is_empty():
		return false
	var history: Variant = view.get("history")
	if history is CastHistory and (history as CastHistory).cast_within(float(view.get("now", 0.0)), _trigger_buff_duration(card), slot_type, ""):
		return false  # still up from the last cast
	return in_danger or _nearest_enemy_distance(view) <= TRIGGER_BUFF_RANGE


func _decide_spender(slot_type: String, slot: CardSlot, card: Dictionary, slots: Dictionary, view: Dictionary, now: float, enemies: Array) -> String:
	if enemies.is_empty():
		_holding.erase(slot_type)
		return WAIT
	var scale: Dictionary = spender_scale(card)
	var status_id: String = String(scale.get("status_id", ""))
	var stacks: int = int((view.get("self_stacks", {}) as Dictionary).get(status_id, 0))
	var decay_left: float = float((view.get("self_decay_left", {}) as Dictionary).get(status_id, INF))
	var in_area: bool = SlotSynergy.enemy_in_area(card, view)
	if stacks > 0 and in_area and (stacks >= mini(SPEND_AT_STACKS, int(scale.get("max", SPEND_AT_STACKS))) or decay_left <= SPEND_DECAY_MARGIN):
		_holding.erase(slot_type)
		return CAST
	var held: Dictionary = _holding.get(slot_type, {})
	if held.is_empty() or String(held["card"]) != slot.current_card_id or now < float(held["since"]):
		held = {"card": slot.current_card_id, "since": now}
		_holding[slot_type] = held
	var builder_soon: bool = _another_card_soon(slots, slot_type, func(card_id: String) -> bool: return CardSummary.status_ids(CardDatabase.get_card(card_id)).has(status_id))
	if stacks == 0 and not builder_soon and not swap_locked and _has_other_card(slot):
		_holding.erase(slot_type)
		return SWAP
	if stacks > 0 and builder_soon:
		return WAIT  # more is coming and the decay rule above bounds the wait
	if now - float(held["since"]) >= hold_seconds and in_area:
		_holding.erase(slot_type)
		return CAST
	return WAIT


## Could this payoff's condition come true within SOON_SECONDS? Generic: it looks at the OTHER slots' current cards
## and the enemies, through the same condition fields the engine reads.
func can_pay_off_soon(card: Dictionary, own_slot_type: String, slots: Dictionary, view: Dictionary) -> bool:
	for effect: Dictionary in SlotSynergy.conditional_effects(card):
		var condition: Dictionary = effect["condition"]
		match String(condition.get("type", "")):
			EffectCondition.CAST_WITHIN:
				var wanted_slot: String = String(condition.get("slot_type", ""))
				var wanted_tag: String = String(condition.get("tag", ""))
				for other_type: String in slots:
					if other_type == own_slot_type:
						continue
					if wanted_slot != "" and other_type != wanted_slot:
						continue
					var other: CardSlot = slots[other_type]
					if other == null or other.current_card_id == "" or other.cooldown_remaining > SOON_SECONDS:
						continue
					if wanted_tag == "" or CardDatabase.has_tag(other.current_card_id, wanted_tag):
						return true
			EffectCondition.ZONE_ACTIVE:
				if int(view.get("zone_count", 0)) > 0:
					return true
				if _another_card_soon(slots, own_slot_type, func(card_id: String) -> bool: return CardDatabase.has_tag(card_id, CardTags.ZONE)):
					return true
			EffectCondition.SELF_STACKS_AT_LEAST:
				# Live now, or another slot's card can build the stacks (a card that applies the status to you) before the hold runs out.
				var self_status: String = String(condition.get("status_id", ""))
				if SlotSynergy.condition_live(effect, card, view):
					return true
				if _another_card_soon(slots, own_slot_type, func(card_id: String) -> bool: return CardSummary.status_ids(CardDatabase.get_card(card_id)).has(self_status)):
					return true
			EffectCondition.DECK_COUNT_AT_LEAST:
				# The deck does not change mid-fight: it pays off now or never, so this card is swapped away when it is short.
				if SlotSynergy.condition_live(effect, card, view):
					return true
			EffectCondition.HP_BELOW:
				# Damage is coming whenever enemies are around, so a healthy bot keeps the card and lets the hold clock cast it.
				if not (view.get("enemies", []) as Array).is_empty():
					return true
			EffectCondition.TARGET_HAS_STATUS:
				var status_id: String = String(condition.get("status_id", ""))
				for enemy: Variant in (view.get("enemies", []) as Array):
					if ((enemy as Dictionary).get("statuses", []) as Array).has(status_id):
						return true
				if _another_card_soon(slots, own_slot_type, func(card_id: String) -> bool: return CardSummary.status_ids(CardDatabase.get_card(card_id)).has(status_id)):
					return true
	return false


func _another_card_soon(slots: Dictionary, own_slot_type: String, matches: Callable) -> bool:
	for other_type: String in slots:
		if other_type == own_slot_type:
			continue
		var other: CardSlot = slots[other_type]
		if other != null and other.current_card_id != "" and other.cooldown_remaining <= SOON_SECONDS and bool(matches.call(other.current_card_id)):
			return true
	return false


## True when the slot holds more than one different card, so a swap gets something else.
func _has_other_card(slot: CardSlot) -> bool:
	for card_id: String in slot.owned_card_ids:
		if card_id != slot.current_card_id:
			return true
	return false


## True when the slot holds a card that is not a curse, so swapping a curse away can reach something worth casting.
func _has_other_real_card(slot: CardSlot) -> bool:
	for card_id: String in slot.owned_card_ids:
		if not CardSchema.is_curse(CardDatabase.get_card(card_id)):
			return true
	return false


## Movement as offense: some other slot's current card has a cast_within condition that this card's cast satisfies, that
## slot is ready within a moment, and there is a gap to dash across. Otherwise it stays an escape.
func _movement_wanted(card: Dictionary, slots: Dictionary, view: Dictionary, in_danger: bool, dodge_ready: bool) -> bool:
	if in_danger and not dodge_ready:
		return true
	var distance: float = _nearest_enemy_distance(view)
	if distance < DASH_IN_MIN or distance > DASH_IN_MAX:
		return false
	var movement_tags: Array[String] = CardDatabase.tags_for(String(card.get("id", "")))
	for other_type: String in slots:
		if other_type == "movement":
			continue
		var other: CardSlot = slots[other_type]
		if other == null or other.current_card_id == "" or other.cooldown_remaining > 0.6:
			continue
		for effect: Dictionary in SlotSynergy.conditional_effects(CardDatabase.get_card(other.current_card_id)):
			var condition: Dictionary = effect["condition"]
			if String(condition.get("type", "")) != EffectCondition.CAST_WITHIN:
				continue
			if String(condition.get("slot_type", "")) == "movement" or movement_tags.has(String(condition.get("tag", "-"))):
				return true
	return false


static func _nearest_enemy_distance(view: Dictionary) -> float:
	var origin: Vector3 = view.get("origin", Vector3.ZERO)
	var best: float = INF
	for enemy: Variant in (view.get("enemies", []) as Array):
		var pos: Vector3 = (enemy as Dictionary)["pos"]
		best = minf(best, Vector2(pos.x - origin.x, pos.z - origin.z).length())
	return best
