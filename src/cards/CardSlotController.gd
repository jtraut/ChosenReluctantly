class_name CardSlotController
extends RefCounted
## Owns the 5 data-driven card slots for one character and casts a slot's
## revealed card through EffectTemplates when used. Plain RefCounted (like
## CardSlot) - Player owns one directly, no scene-tree wiring needed since
## only Player casts cards in this milestone.

## Emitted after a slot's card was cast (cooldown started, effects run).
signal card_cast(slot_type: String, card_id: String)

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


## `rng` (optional) is shared by every slot's shuffles, so a seeded one makes decks repeat.
func _init(p_caster: Node3D, p_spawn_parent: Node, p_caster_team: String, p_stat_modifiers: StatModifiers, owned_pools: Array[String], rng: RandomNumberGenerator = null) -> void:
	caster = p_caster
	spawn_parent = p_spawn_parent
	caster_team = p_caster_team
	stat_modifiers = p_stat_modifiers
	for slot_type: String in SLOT_TYPE_ORDER:
		var definition := SlotTypeDatabase.get_definition(slot_type)
		var base_cooldown: float = definition.get("base_cooldown", 1.0)
		var owned_card_ids := _owned_card_ids_for_slot(slot_type, owned_pools)
		slots[slot_type] = CardSlot.new(slot_type, base_cooldown, owned_card_ids, DEFAULT_SWAP_PENALTY, rng)


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
	_cast_card(card_data)
	card_cast.emit(slot_type, used_id)
	return true


func try_swap(slot_type: String) -> bool:
	var slot: CardSlot = get_slot(slot_type)
	if slot == null:
		return false
	return slot.swap_card()


func _cast_card(card_data: Dictionary) -> void:
	var context := EffectContext.new(caster, spawn_parent, caster_team)
	context.rng = status_rng
	var effects: Array = card_data.get("effects", [])
	for effect: Dictionary in effects:
		EffectTemplates.execute(effect.get("template", ""), effect.get("params", {}), context)


func _owned_card_ids_for_slot(slot_type: String, owned_pools: Array[String]) -> Array[String]:
	var ids: Array[String] = []
	for card_data: Dictionary in CardDatabase.cards_for_slot_type(slot_type):
		if owned_pools.has(card_data.get("pool", "")):
			ids.append(card_data["id"])
	return ids
