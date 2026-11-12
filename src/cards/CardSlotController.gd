class_name CardSlotController
extends RefCounted
## Owns the 5 data-driven card slots for one character and casts a slot's
## revealed card through EffectTemplates when used. Plain RefCounted (like
## CardSlot) - Player owns one directly, no scene-tree wiring needed since
## only Player casts cards in this milestone.

## Emitted after a slot's card was cast (cooldown started, effects run).
signal card_cast(slot_type: String, card_id: String)
## (CombatEvents.card_cast carries the tags too and is the one conditions and relics listen to.)

const SLOT_TYPE_ORDER: Array[String] = ["attack_single", "attack_aoe", "utility", "movement", "recovery"]
const DEFAULT_SWAP_PENALTY := 1.0

var caster: Node3D
var spawn_parent: Node
var caster_team: String
var stat_modifiers: StatModifiers
var slots: Dictionary = {}
## RNG for apply_status chances (the owner's status RNG; Player sets it). Not the shuffle RNG,
## so deck order never depends on how many status rolls happened.
var status_rng: RandomNumberGenerator = null
var _shuffle_rng: RandomNumberGenerator = null
## Per-character slot base cooldowns {slot_type: seconds} (CharacterDatabase.slot_base_cooldowns); a slot not listed uses slot_types.json.
var _base_cooldown_overrides: Dictionary = {}


## `rng` (optional) is shared by every slot's shuffles, so a seeded one makes decks repeat.
func _init(p_caster: Node3D, p_spawn_parent: Node, p_caster_team: String, p_stat_modifiers: StatModifiers, owned_pools: Array[String], rng: RandomNumberGenerator = null, base_cooldown_overrides: Dictionary = {}) -> void:
	_base_cooldown_overrides = base_cooldown_overrides.duplicate()
	caster = p_caster
	spawn_parent = p_spawn_parent
	caster_team = p_caster_team
	stat_modifiers = p_stat_modifiers
	_shuffle_rng = rng
	for slot_type: String in SLOT_TYPE_ORDER:
		var base_cooldown: float = base_cooldown_for(slot_type)
		var owned_card_ids := _owned_card_ids_for_slot(slot_type, owned_pools)
		slots[slot_type] = CardSlot.new(slot_type, base_cooldown, owned_card_ids, DEFAULT_SWAP_PENALTY, rng)


## A slot's base cooldown: the character's override when it has one, else the slot type's data value.
func base_cooldown_for(slot_type: String) -> float:
	if _base_cooldown_overrides.has(slot_type):
		return float(_base_cooldown_overrides[slot_type])
	return float(SlotTypeDatabase.get_definition(slot_type).get("base_cooldown", 1.0))


## Replaces the deck with exactly these card ids (copies allowed), sorted into their slots by each card's
## slot_type. Every slot restarts: fresh shuffle bag, cooldown 0. Unknown ids are skipped with a push_error.
## Returns the ids that were placed. Used by the run system to load RunState.deck; it never looks inside a card.
func set_deck(card_ids: Array[String]) -> Array[String]:
	var placed: Array[String] = []
	var by_slot: Dictionary = {}
	for slot_type: String in SLOT_TYPE_ORDER:
		by_slot[slot_type] = [] as Array[String]
	for card_id: String in card_ids:
		var card_data := CardDatabase.get_card(card_id)
		var slot_type: String = String(card_data.get("slot_type", ""))
		if not by_slot.has(slot_type):
			push_error("CardSlotController.set_deck: unknown card '%s' (skipped)" % card_id)
			continue
		(by_slot[slot_type] as Array[String]).append(card_id)
		placed.append(card_id)
	for slot_type: String in SLOT_TYPE_ORDER:
		slots[slot_type] = CardSlot.new(slot_type, base_cooldown_for(slot_type), by_slot[slot_type] as Array[String], DEFAULT_SWAP_PENALTY, _shuffle_rng)
	return placed


## Every card id in the deck (copies included), across all slots.
func owned_card_ids() -> Array[String]:
	var ids: Array[String] = []
	for slot_type: String in SLOT_TYPE_ORDER:
		ids.append_array((slots[slot_type] as CardSlot).owned_card_ids)
	return ids


## Shortfalls that removing one copy of `card_id` would cause; empty means allowed (future deck-clean rewards).
func can_remove(card_id: String) -> Array[String]:
	return DeckRules.can_remove(owned_card_ids(), card_id, DeckRules.shipped_config(), DeckRules.slot_map_from_database(), SlotTypeDatabase.known_ids(), DeckRules.slot_names_from_database())


## Shortfalls that swapping `remove_id` for `add_id` would cause; empty means allowed.
func can_swap(remove_id: String, add_id: String) -> Array[String]:
	return DeckRules.can_swap(owned_card_ids(), remove_id, add_id, DeckRules.shipped_config(), DeckRules.slot_map_from_database(), SlotTypeDatabase.known_ids(), DeckRules.slot_names_from_database())


## Unique-card counts and shortfalls for the deck as it stands (see DeckRules).
func deck_check() -> DeckCheck:
	return DeckRules.check_shipped(owned_card_ids())


static func slot_type_at_index(index: int) -> String:
	if index < 0 or index >= SLOT_TYPE_ORDER.size():
		return ""
	return SLOT_TYPE_ORDER[index]


func get_slot(slot_type: String) -> CardSlot:
	return slots.get(slot_type, null)


func advance(delta: float) -> void:
	# Iterating the dictionary directly allocates nothing (values() builds an Array every frame).
	for slot_type: String in slots:
		(slots[slot_type] as CardSlot).advance(delta)
	if stat_modifiers != null:
		stat_modifiers.advance(delta)


func try_use(slot_type: String) -> bool:
	var slot: CardSlot = get_slot(slot_type)
	if slot == null:
		return false
	var card_id := slot.current_card_id
	var card_data := CardDatabase.get_card(card_id)
	if card_data.is_empty():
		return false
	var cooldown_modifier: float = card_data.get("cooldown_modifier", 0.0)
	var used_id := slot.use_card(cooldown_modifier, stat_modifiers)
	if used_id == "":
		return false
	# Primed buffs that exist BEFORE this cast are used up by it, after its effects ran (so the buff is still active while
	# this cast resolves); a buff this very card applies is not in the snapshot, so it never eats its own charge.
	var primed_before: Array[String] = stat_modifiers.primed_ids() if stat_modifiers != null else ([] as Array[String])
	_cast_card(card_data)
	if stat_modifiers != null:
		stat_modifiers.consume_for_cast(slot_type, CardDatabase.tags_for(used_id), primed_before)
	# History after the effects: a card's own conditions never see its own cast.
	var relay := CombatLink.events()
	if relay != null:
		relay.notify_card_cast(slot_type, used_id)
	card_cast.emit(slot_type, used_id)
	return true


## MAP3b: the `dead_card_swap_locked` stat (base 0): above 0 the dead-card swap is refused (The Micromanager).
const SWAP_LOCKED_STAT := "dead_card_swap_locked"


func swap_locked() -> bool:
	return stat_modifiers != null and stat_modifiers.apply(SWAP_LOCKED_STAT, 0.0) > 0.0


func try_swap(slot_type: String) -> bool:
	var slot: CardSlot = get_slot(slot_type)
	if slot == null or swap_locked():
		return false
	return slot.swap_card()


func _cast_card(card_data: Dictionary) -> void:
	var context := EffectContext.new(caster, spawn_parent, caster_team)
	context.origin = "card:" + String(card_data.get("id", ""))
	context.rng = status_rng
	var relay := CombatLink.events()
	if relay != null:
		context.cast_history = relay.history
		context.now = relay.now()
	if caster != null and is_instance_valid(caster) and caster.has_method("get_aim_point"):
		# Placed effects (zone, aoe with max_range) land where the caster aims, clamped by their range.
		context.aim_point = caster.get_aim_point()
		context.arena = caster.get_arena_rect()
	var effects: Array = card_data.get("effects", [])
	for effect: Dictionary in effects:
		EffectTemplates.execute(effect.get("template", ""), effect.get("params", {}), context, effect.get("condition", {}))


func _owned_card_ids_for_slot(slot_type: String, owned_pools: Array[String]) -> Array[String]:
	var ids: Array[String] = []
	for card_data: Dictionary in CardDatabase.cards_for_slot_type(slot_type):
		if owned_pools.has(card_data.get("pool", "")) and CardSchema.rarity_of(card_data) == CardSchema.RARITY_COMMON:  # MAP3b: a pool-filled deck takes only common cards
			ids.append(card_data["id"])
	return ids
