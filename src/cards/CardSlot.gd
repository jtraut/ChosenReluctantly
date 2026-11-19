class_name CardSlot
extends RefCounted
## One of the 5 card slots: a shuffled mini-deck over the cards the player
## owns for this slot type, plus the slot's own cooldown. Pure logic - no
## Node, no scene tree - so it's a plain unit-testable class and the same
## code can drive both real gameplay and the headless bot-sim.
##
## Design calls worth remembering (see docs/DECISIONS.md):
## - Cooldown = (base_cooldown + card's own modifier), then the generic
##   StatModifiers stack is applied on top of that raw value, then floored
##   at MIN_COOLDOWN so a large negative modifier can't create a
##   zero/negative cooldown and infinite-chain the slot.
## - Swapping is blocked while the slot is already on cooldown - "busy" is
##   "busy" whether that's from casting or from a previous swap.
## - Shuffle bag (GDD section 4): every owned card is drawn once per cycle
##   before any repeats, and a new cycle never opens with the card that
##   ended the last one (when the slot has another unique card). The bag is
##   refilled from the owned list the instant it empties, including right
##   after drawing the card that empties it, so preview_card_id() is never
##   stale across the boundary. discard_pile only tracks what was used or
##   swapped away this cycle.
## - A 1-card-deck (or an entirely empty one) never crashes or loops: using
##   or swapping a 1-card deck just hands the same card straight back.

const MIN_COOLDOWN := 0.05

var slot_type: String
var base_cooldown: float
var swap_penalty: float
## 3d: the penalty when the card swapped away is a curse (CardSchema.is_curse); negative = same as swap_penalty. Set by CardSlotController from data/run.json `curses`.
var curse_swap_penalty: float = -1.0
var owned_card_ids: Array[String] = []

var draw_pile: Array[String] = []
var discard_pile: Array[String] = []
var current_card_id: String = ""
var cooldown_remaining: float = 0.0
## The cooldown duration set by the most recent use_card()/swap_card() call,
## purely informational (the HUD divides cooldown_remaining by this to draw
## a sweep/bar) - nothing here reads it back for gameplay logic.
var last_cooldown_duration: float = 0.0

var _rng: RandomNumberGenerator


func _init(
		p_slot_type: String,
		p_base_cooldown: float,
		p_owned_card_ids: Array[String],
		p_swap_penalty: float = 1.0,
		rng: RandomNumberGenerator = null
) -> void:
	slot_type = p_slot_type
	base_cooldown = p_base_cooldown
	swap_penalty = p_swap_penalty
	owned_card_ids = p_owned_card_ids.duplicate()
	_rng = rng if rng != null else RandomNumberGenerator.new()
	_reset_deck()


func has_cards() -> bool:
	return not owned_card_ids.is_empty()


func is_ready() -> bool:
	return cooldown_remaining <= 0.0 and current_card_id != ""


func preview_card_id() -> String:
	if draw_pile.is_empty():
		return ""
	return draw_pile[draw_pile.size() - 1]


func advance(delta: float) -> void:
	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)


## Uses the revealed card (if the slot is ready), draws the next one, and
## starts the slot's cooldown. Returns the card id that was used, or "" if
## the slot wasn't ready.
func use_card(card_cooldown_modifier: float, stat_modifiers: StatModifiers = null) -> String:
	if not is_ready():
		return ""
	var used_card_id := current_card_id
	discard_pile.append(used_card_id)
	_draw_next_card()
	cooldown_remaining = _compute_cooldown(card_cooldown_modifier, stat_modifiers)
	last_cooldown_duration = cooldown_remaining
	return used_card_id


## Discards the revealed card for a fresh draw, at the cost of a penalty
## cooldown on the slot. Blocked while the slot is already on cooldown, or
## if there's no revealed card to discard. Returns whether the swap happened.
func swap_card(stat_modifiers: StatModifiers = null) -> bool:
	if cooldown_remaining > 0.0 or current_card_id == "":
		return false
	var penalty: float = current_swap_penalty(stat_modifiers)  # read before the draw replaces the revealed card
	discard_pile.append(current_card_id)
	_draw_next_card()
	cooldown_remaining = penalty
	last_cooldown_duration = penalty
	return true


## What swapping the revealed card away would cost right now: the curse value for a curse, else the ordinary one.
## BD3b-C2: the `swap_penalty_mult.<slot_type>` stat (base 1.0, a relic modifier of -1.0 = free) scales whichever of the two applies.
const SWAP_PENALTY_MULT_PREFIX := "swap_penalty_mult."


func current_swap_penalty(stat_modifiers: StatModifiers = null) -> float:
	var penalty: float = swap_penalty
	if curse_swap_penalty >= 0.0 and current_card_id != "" and CardSchema.is_curse(CardDatabase.get_card(current_card_id)):
		penalty = curse_swap_penalty
	if stat_modifiers != null and stat_modifiers.has_modifier(SWAP_PENALTY_MULT_PREFIX + slot_type):
		penalty = maxf(penalty * stat_modifiers.apply(SWAP_PENALTY_MULT_PREFIX + slot_type, 1.0), 0.0)
	return penalty


## Tooling: makes `card_id` the revealed card by trading places with the current one. False when the slot has no such card in its draw pile.
func reveal_first(card_id: String) -> bool:
	if current_card_id == card_id:
		return true
	var index: int = draw_pile.find(card_id)
	if index < 0:
		return false
	draw_pile[index] = current_card_id
	current_card_id = card_id
	return true


func _reset_deck() -> void:
	draw_pile = owned_card_ids.duplicate()
	_shuffle(draw_pile)
	discard_pile.clear()
	cooldown_remaining = 0.0
	current_card_id = ""
	_draw_next_card()


func _draw_next_card() -> void:
	if draw_pile.is_empty():
		_refill_bag("")
	if draw_pile.is_empty():
		current_card_id = ""
		return
	current_card_id = draw_pile.pop_back()
	# Refill the instant the bag runs dry so preview_card_id() is never stale. The card just
	# drawn is the "last" one of the old cycle, so the new cycle can't open with it.
	if draw_pile.is_empty():
		_refill_bag(current_card_id)


## Starts a new cycle: a full shuffled copy of the owned cards (every copy once). The next card
## drawn (the top, drawn with pop_back) is never `last_card_id` while the slot has another
## unique card to open with.
func _refill_bag(last_card_id: String) -> void:
	draw_pile = owned_card_ids.duplicate()
	discard_pile.clear()
	_shuffle(draw_pile)
	if draw_pile.is_empty() or last_card_id == "":
		return
	var top := draw_pile.size() - 1
	if draw_pile[top] != last_card_id:
		return
	for i in range(top - 1, -1, -1):
		if draw_pile[i] != last_card_id:
			var tmp := draw_pile[i]
			draw_pile[i] = draw_pile[top]
			draw_pile[top] = tmp
			return


func _shuffle(array: Array[String]) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := array[i]
		array[i] = array[j]
		array[j] = tmp


func _compute_cooldown(card_cooldown_modifier: float, stat_modifiers: StatModifiers) -> float:
	# A primed "next cast has no cooldown" (slot_cooldown_skip.<slot> above 0): the shortest cooldown there is.
	if stat_modifiers != null and stat_modifiers.has_modifier(StatModifiers.COOLDOWN_SKIP_PREFIX + slot_type) 			and stat_modifiers.apply(StatModifiers.COOLDOWN_SKIP_PREFIX + slot_type, 0.0) > 0.0:
		return MIN_COOLDOWN
	var raw := base_cooldown + card_cooldown_modifier
	if stat_modifiers != null:
		raw = stat_modifiers.apply("slot_cooldown.%s" % slot_type, raw)
	return maxf(raw, MIN_COOLDOWN)
