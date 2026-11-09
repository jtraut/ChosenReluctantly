class_name CombatEventsRelay
extends Node
## Autoload (named CombatEvents; the class_name is CombatEventsRelay so code that must also compile in a `-s` script
## run without autoloads, like the bot-sim, can type it and find it through CombatLink). A relay for combat events (no game state of its own beyond a short cast history and a game clock), so
## systems that care about what just happened (effect conditions, relics) listen here instead of wiring
## to each other. The events (BUILD_DEPTH 4.3): card_cast, hit_landed, enemy_killed, status_applied, status_ended,
## attack_fired, dash_ended, player_damaged, zone_started/zone_ended, room_started/room_cleared. Emitters call the
## notify_* helpers next to their own signals; nothing that connects to those signals changes.
##
## Origin strings (who caused a hit or a status): "light", "heavy", "card:<id>", "status:<id>", "relic:<id>", "enemy",
## or "" when nobody set one (tests, scenarios).
##
## The clock is game time (this node's _process delta), so it respects pause and hit-stop slow-mo, and a seeded
## sim repeats. `reset()` runs when a scene (run, room, arena) loads and on a restart.

## A card was cast: its slot type, card id, and tags (derived + keywords, see CardTags). Emitted after the card's
## effects ran, next to CardSlotController.card_cast.
signal card_cast(slot_type: String, card_id: String, tags: Array[String])

## A hit took HP off `target`. `amount` is the HP removed after mitigation, `kind` is a Health.KIND_ value, `origin` as above.
signal hit_landed(target: Node, amount: float, damage_type: String, kind: StringName, origin: String, position: Vector3)
## An enemy died. `origin` is the last damage's origin; `statuses` are the status ids it held at death.
signal enemy_killed(target: Node, position: Vector3, origin: String, statuses: Array[String])
## A status began on `target` (a refresh is not a new status). `origin` is who applied it (see above), `source` the applier node or null.
signal status_applied(target: Node, status_id: String, stacks: int, source: Node, origin: String, position: Vector3)
## A status ended on `target`. `reason` is one of the STATUS_END_* values. `owner_died` fires while the node still exists.
signal status_ended(target: Node, status_id: String, reason: String, source: Node, origin: String, position: Vector3)
## The player's light or heavy attack fired (`attack_id` "light" or "heavy"); `aim_point` is the ground point aimed at (or the player's position).
signal attack_fired(attack_id: String, aim_point: Vector3)
## A Movement card's dash finished (the dodge roll is not a card and does not fire this).
signal dash_ended(start: Vector3, end: Vector3, card_id: String)
## The player lost HP.
signal player_damaged(amount: float, origin: String)
signal zone_started(zone_id: int, shape: String, position: Vector3)
signal zone_ended(zone_id: int, shape: String, position: Vector3)
signal room_started(index: int, room_type: String)
signal room_cleared(index: int, room_type: String)

const STATUS_END_EXPIRED := "expired"
const STATUS_END_OWNER_DIED := "owner_died"
const STATUS_END_CONSUMED := "consumed"
## BD3a: a detonate_status effect burst the status and removed it. A death trigger (Pyre Insurance) filters on expired and
## owner_died only, so a detonate cannot chain into a second explosion.
const STATUS_END_DETONATED := "detonated"
const STATUS_END_REASONS: Array[String] = [STATUS_END_EXPIRED, STATUS_END_OWNER_DIED, STATUS_END_CONSUMED, STATUS_END_DETONATED]

var history := CastHistory.new()
var _now: float = 0.0


func _process(delta: float) -> void:
	step(delta)


## Advances the game clock by `delta`. _process calls it every frame; a headless sim that runs ticks without frames (the
## bot-sim) calls it itself, so its casts get real timestamps.
func step(delta: float) -> void:
	_now += delta


## Game seconds since the last reset.
func now() -> float:
	return _now


## Records the cast into the history and emits card_cast. CardSlotController calls this after the effects ran, so
## a card's own conditions never see its own cast.
func notify_card_cast(slot_type: String, card_id: String) -> void:
	var tags: Array[String] = CardDatabase.tags_for(card_id)
	history.record(_now, slot_type, card_id, tags)
	card_cast.emit(slot_type, card_id, tags)


## The player dodged. D39: by default (data/player.json dodge.counts_as_movement_cast false) nothing happens, because the dodge
## is a pure escape and is not a Movement cast. With the flag on it enters the history as a Movement cast (card id "dodge"),
## so cast_within conditions see it. This is the only place the rule lives; Player just reports the dodge.
func notify_dodge() -> void:
	if PlayerConfig.dodge_counts_as_movement_cast():
		history.record(_now, "movement", "dodge", ["Dash"] as Array[String])
		card_cast.emit("movement", "dodge", ["Dash"] as Array[String])


## The team of a combatant node ("player", "enemy", ...), read from its Hurtbox child; "" when it has none.
static func team_of(target: Node) -> String:
	if target == null or not is_instance_valid(target):
		return ""
	var box: Node = target.get_node_or_null("Hurtbox")
	return String((box as Hurtbox).team) if box is Hurtbox else ""


## The node's world position, or ZERO when it is not a Node3D in the tree (unit tests on orphan nodes).
static func position_of(target: Node) -> Vector3:
	var node := target as Node3D
	return node.global_position if node != null and node.is_inside_tree() else Vector3.ZERO


func notify_hit(target: Node, amount: float, damage_type: String, kind: StringName, origin: String) -> void:
	hit_landed.emit(target, amount, damage_type, kind, origin, position_of(target))


## `statuses` is the list of status ids the enemy held when it died (the caller snapshots it).
func notify_enemy_killed(target: Node, origin: String, statuses: Array[String]) -> void:
	enemy_killed.emit(target, position_of(target), origin, statuses)


func notify_status_applied(target: Node, status_id: String, source: Node, origin: String) -> void:
	status_applied.emit(target, status_id, 1, source, origin, position_of(target))


func notify_status_ended(target: Node, status_id: String, reason: String, source: Node, origin: String) -> void:
	status_ended.emit(target, status_id, reason, source, origin, position_of(target))


func notify_attack_fired(attack_id: String, aim_point: Vector3) -> void:
	attack_fired.emit(attack_id, aim_point)


func notify_dash_ended(start: Vector3, end: Vector3, card_id: String) -> void:
	dash_ended.emit(start, end, card_id)


func notify_player_damaged(amount: float, origin: String) -> void:
	player_damaged.emit(amount, origin)


func notify_zone_started(zone_id: int, shape: String, at: Vector3) -> void:
	zone_started.emit(zone_id, shape, at)


func notify_zone_ended(zone_id: int, shape: String, at: Vector3) -> void:
	zone_ended.emit(zone_id, shape, at)


func notify_room_started(index: int, room_type: String) -> void:
	room_started.emit(index, room_type)


func notify_room_cleared(index: int, room_type: String) -> void:
	room_cleared.emit(index, room_type)


func reset() -> void:
	history.clear()
	_now = 0.0
