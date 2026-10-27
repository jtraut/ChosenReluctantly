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
## - The draw pile is reshuffled from the discard pile the instant it would
##   otherwise be empty, including right after drawing the card that empties
##   it - so preview_card_id() is never stale/wrong, even across the
##   reshuffle boundary.
## - A 1-card-deck (or an entirely empty one) never crashes or loops: using
##   or swapping a 1-card deck just hands the same card straight back.

const MIN_COOLDOWN := 0.05

var slot_type: String
var base_cooldown: float
var swap_penalty: float
var owned_card_ids: Array[String] = []

var draw_pile: Array[String] = []
var discard_pile: Array[String] = []
var current_card_id: String = ""
var cooldown_remaining: float = 0.0

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
	return used_card_id


## Discards the revealed card for a fresh draw, at the cost of a penalty
## cooldown on the slot. Blocked while the slot is already on cooldown, or
## if there's no revealed card to discard. Returns whether the swap happened.
func swap_card() -> bool:
	if cooldown_remaining > 0.0 or current_card_id == "":
		return false
	discard_pile.append(current_card_id)
	_draw_next_card()
	cooldown_remaining = swap_penalty
	return true


func _reset_deck() -> void:
	draw_pile = owned_card_ids.duplicate()
	_shuffle(draw_pile)
	discard_pile.clear()
	cooldown_remaining = 0.0
	current_card_id = ""
	_draw_next_card()


func _draw_next_card() -> void:
	_reshuffle_if_needed()
	if draw_pile.is_empty():
		current_card_id = ""
		return
	current_card_id = draw_pile.pop_back()
	_reshuffle_if_needed()


func _reshuffle_if_needed() -> void:
	if draw_pile.is_empty() and not discard_pile.is_empty():
		draw_pile = discard_pile.duplicate()
		discard_pile.clear()
		_shuffle(draw_pile)


func _shuffle(array: Array[String]) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := array[i]
		array[i] = array[j]
		array[j] = tmp


func _compute_cooldown(card_cooldown_modifier: float, stat_modifiers: StatModifiers) -> float:
	var raw := base_cooldown + card_cooldown_modifier
	if stat_modifiers != null:
		raw = stat_modifiers.apply("slot_cooldown.%s" % slot_type, raw)
	return maxf(raw, MIN_COOLDOWN)
