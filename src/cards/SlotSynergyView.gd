class_name SlotSynergyView
extends RefCounted
## The scene side of SlotSynergy: builds the `view` from a live Player (position, facing, aim point, arena, the enemies
## near it with their statuses, the cast history and its Zone count) and returns the per-slot info for the HUD.
## Cached per physics frame, so a HUD that asks every frame runs one physics query per tick.

const SEARCH_RADIUS := 40.0

static var _cache_frame: int = -1
static var _cache_owner: int = 0
static var _cache: Dictionary = {}
static var _text: Dictionary = {}


## {slot_type: slot_info} for every slot of `player` (see SlotSynergy.slot_info). Empty when the player has no slots yet.
static func infos(player: Player) -> Dictionary:
	if player == null or not is_instance_valid(player) or player.card_slots == null:
		return {}
	var frame: int = Engine.get_physics_frames()
	if _cache_frame == frame and _cache_owner == player.get_instance_id():
		return _cache
	if _text.is_empty():
		_text = SlotSynergy.default_text()
	var view: Dictionary = view_for(player)
	var primed: Array[Dictionary] = player.stat_modifiers.primed_state()
	var result: Dictionary = {}
	for slot_type: String in CardSlotController.SLOT_TYPE_ORDER:
		var slot: CardSlot = player.card_slots.get_slot(slot_type)
		if slot == null:
			continue
		result[slot_type] = SlotSynergy.slot_info(slot_type, slot.current_card_id, view, primed, _text)
	_cache = result
	_cache_frame = frame
	_cache_owner = player.get_instance_id()
	return result


## Forgets the cached text and frame (a test that edits run.json strings).
static func reset_cache() -> void:
	_cache_frame = -1
	_cache = {}
	_text = {}


## The SlotSynergy `view` of a live player (one sphere query for the enemies near it).
static func view_for(player: Player) -> Dictionary:
	var relay: CombatEventsRelay = CombatLink.events()
	var zones: int = 0
	if player.is_inside_tree():
		var manager: ZoneManager = ZoneManager.find_in_world(WorldRef.get_world(player.get_tree()))
		if manager != null:
			zones = manager.live_count_for(player.get_instance_id())
	var enemies: Array[Dictionary] = []
	if player.is_inside_tree():
		var team: String = player.hurtbox.team if player.hurtbox != null else "player"
		var space := player.get_world_3d().direct_space_state
		for hurtbox: Hurtbox in MeleeQuery.find_hurtboxes_in_sphere(space, player.global_position, SEARCH_RADIUS, team, CollisionLayers.HURTBOX):
			if hurtbox.status_manager == null:
				continue
			var held: Array = hurtbox.status_manager.active_status_ids()
			var stacks: Dictionary = {}
			for status_id: Variant in held:
				stacks[String(status_id)] = hurtbox.status_manager.stacks_of(String(status_id))
			enemies.append({"pos": hurtbox.global_position, "statuses": held, "stacks": stacks})
	return {
		"now": relay.now() if relay != null else 0.0,
		"history": relay.history if relay != null else null,
		"zone_count": zones,
		"origin": player.global_position,
		"forward": player.get_aim_direction(),
		"aim_point": player.get_aim_point(),
		"arena": player.get_arena_rect(),
		"enemies": enemies,
	}
